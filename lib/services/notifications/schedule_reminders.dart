import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/channel_profile.dart';
import 'package:onset/services/notifications/activity_log.dart';
import 'package:onset/services/notifications/notice_ids.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

final _login = RegExp(r'^[a-zA-Z0-9_]{1,25}$');

/// A reminder set on a schedule segment ("Remind Me").
@immutable
class ScheduleReminder {
  const ScheduleReminder({
    required this.segmentId,
    required this.login,
    required this.channelName,
    required this.startAt,
    this.title,
    this.category,
  });

  final String segmentId;
  final String login;
  final String channelName;
  final DateTime startAt;
  final String? title;
  final String? category;

  /// Its notice's title, in [l]'s language.
  String noticeTitleIn(AppLocalizations l) =>
      l.notifReminderTitle(name: channelName);

  /// Its notice's text, in [l]'s language: the stream's title and category
  /// (as the streamer set them), or "Stream" without either.
  String noticeBodyIn(AppLocalizations l) => streamNoticeBody(
    l,
    title: title,
    category: category,
    none: l.notifReminderUntitled,
  );

  ScheduleReminder movedTo(DateTime at) => ScheduleReminder(
    segmentId: segmentId,
    login: login,
    channelName: channelName,
    startAt: at,
    title: title,
    category: category,
  );

  /// Its Activity entry, at the time it went off, worded in [l]'s language
  /// (the one on screen by default) and reworded in the language on screen
  /// from what it says.
  ActivityEntry entryIn([AppLocalizations? l]) {
    final words = l ?? L10n.current;
    return ActivityEntry(
      id: 'reminder:$segmentId',
      kind: ActivityKind.reminder,
      title: noticeTitleIn(words),
      body: noticeBodyIn(words),
      login: login,
      at: startAt,
      params: {
        'name': channelName,
        'title': ?_nonBlank(title),
        'category': ?_nonBlank(category),
      },
    );
  }

  Map<String, Object?> toJson() => {
    'segmentId': segmentId,
    'login': login,
    'channelName': channelName,
    'startAt': startAt.millisecondsSinceEpoch,
    'title': ?title,
    'category': ?category,
  };

  static ScheduleReminder? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['segmentId'];
    final login = json['login'];
    final name = json['channelName'];
    final startAt = storedDate(json['startAt'], isUtc: true);
    if (id is! String || login is! String || !_login.hasMatch(login)) {
      return null;
    }
    if (name is! String || startAt == null) return null;
    final title = json['title'];
    final category = json['category'];
    return ScheduleReminder(
      segmentId: id,
      login: login,
      channelName: name,
      startAt: startAt,
      title: title is String ? title : null,
      category: category is String ? category : null,
    );
  }
}

/// [text] trimmed, or null when blank.
String? _nonBlank(String? text) {
  final trimmed = text?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

/// The notification id of a segment's reminder.
int reminderNoticeId(String segmentId) => stableNoticeId('reminder:$segmentId');

/// What came of a tap on "Remind Me".
enum ReminderResult { set, cleared, refused, failed }

/// The system side of reminders, swappable in tests.
abstract interface class ReminderPlatform {
  /// Asks for the right to notify; true when granted.
  Future<bool> requestPermission();

  /// Schedules a notice; [l] names its channel in the system's settings.
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String payload,
    required AppLocalizations l,
  });

  Future<void> cancel(int id);
}

/// "Remind Me" on a channel's schedule, kept on the device: a local
/// notification at the segment start (Twitch's own reminder is a private
/// mutation and its push comes from Twitch's servers). Kept in plain
/// preferences, so it survives a restart; the scheduled notification is
/// restored by the system after a reboot.
class ScheduleReminders extends ChangeNotifier {
  ScheduleReminders({
    required SharedPreferences prefs,
    required this.platform,
    DateTime Function()? now,
    AppLocalizations Function()? words,
  }) : _prefs = prefs,
       _now = now ?? DateTime.now,
       _words = words ?? (() => L10n.current) {
    _reminders = _read();
  }

  /// The app's reminders, set up at launch (null in tests and before).
  static ScheduleReminders? shared;

  static const _key = 'schedule_reminders';

  final SharedPreferences _prefs;
  final ReminderPlatform platform;
  final DateTime Function() _now;

  /// The language a notice is worded in when it is scheduled (the one on
  /// screen): the system keeps that text, so [reschedule] words them again
  /// when the language changes.
  final AppLocalizations Function() _words;

  late Map<String, ScheduleReminder> _reminders;

  /// The end of the last change queued ([_oneAtATime]), and how many are
  /// queued or running.
  Future<void> _queue = Future<void>.value();
  var _queued = 0;

  /// Runs [task] once every change queued before it has ended: toggling,
  /// following a schedule, handing the due ones to Activity and wording
  /// them again each wait for the alarms between, so one never schedules
  /// a reminder another has just cancelled or moved. With nothing queued
  /// it starts at once.
  Future<T> _oneAtATime<T>(Future<T> Function() task) {
    final result = _queued == 0
        ? Future.sync(task)
        : _queue.then((_) => task());
    _queued++;
    _queue = result
        .then<void>((_) {}, onError: (Object _) {})
        .whenComplete(() => _queued--);
    return result;
  }

  Map<String, ScheduleReminder> _read() {
    final map = <String, ScheduleReminder>{};
    for (final raw in _prefs.getStringList(_key) ?? const <String>[]) {
      try {
        final reminder = ScheduleReminder.fromJson(jsonDecode(raw));
        if (reminder != null) map[reminder.segmentId] = reminder;
      } on FormatException {
        // A damaged reminder is dropped.
      }
    }
    return map;
  }

  Future<void> _save() => _prefs.setStringList(_key, [
    for (final reminder in _reminders.values) jsonEncode(reminder.toJson()),
  ]);

  bool isSet(String segmentId) => _reminders.containsKey(segmentId);

  /// Only a segment still to come and not cancelled can have a reminder.
  bool canRemind(ScheduleSegment segment) =>
      !segment.isCancelled && segment.startAt.isAfter(_now());

  Future<void> _schedule(ScheduleReminder reminder) {
    final l = _words();
    return platform.schedule(
      id: reminderNoticeId(reminder.segmentId),
      at: reminder.startAt,
      title: reminder.noticeTitleIn(l),
      body: reminder.noticeBodyIn(l),
      payload: reminder.login,
      l: l,
    );
  }

  /// Schedules every reminder still to come again, worded in the language
  /// on screen now (called when that language changed: the system keeps
  /// the text a notice was scheduled with). One that fails is left as it
  /// was. Queued with the other changes, and each reminder checked again
  /// around its alarm: one cancelled or moved meanwhile is not put back.
  Future<void> reschedule() => _oneAtATime(() async {
    final now = _now();
    for (final reminder in [..._reminders.values]) {
      if (!reminder.startAt.isAfter(now)) continue;
      // Cancelled or moved since the list was read: its own change set its
      // alarm.
      if (!identical(_reminders[reminder.segmentId], reminder)) continue;
      try {
        await _schedule(reminder);
      } catch (e) {
        debugPrint('Schedule reminder not reworded: $e');
        continue;
      }
      // Changed while its alarm was set: the alarm follows the reminder.
      final current = _reminders[reminder.segmentId];
      if (identical(current, reminder)) continue;
      try {
        if (current == null) {
          await platform.cancel(reminderNoticeId(reminder.segmentId));
        } else {
          await _schedule(current);
        }
      } catch (e) {
        debugPrint('Schedule reminder not reworded: $e');
      }
    }
  });

  /// Sets [segment]'s reminder, or clears it when set.
  Future<ReminderResult> toggle(
    ScheduleSegment segment, {
    required String login,
    required String channelName,
  }) => _oneAtATime(() async {
    try {
      if (isSet(segment.id)) {
        // Cancelled first: "Remind Me" only once nothing will go off.
        await platform.cancel(reminderNoticeId(segment.id));
        _reminders.remove(segment.id);
        await _save();
        notifyListeners();
        return ReminderResult.cleared;
      }
      if (!canRemind(segment) || !_login.hasMatch(login)) {
        return ReminderResult.failed;
      }
      if (!await platform.requestPermission()) return ReminderResult.refused;
      final reminder = ScheduleReminder(
        segmentId: segment.id,
        login: login,
        channelName: channelName,
        startAt: segment.startAt.toUtc(),
        title: segment.title,
        category: segment.categoryName,
      );
      // Scheduled first: "Reminder Set" only once it is.
      await _schedule(reminder);
      _reminders[segment.id] = reminder;
      await _save();
      notifyListeners();
      return ReminderResult.set;
    } catch (e) {
      debugPrint('Schedule reminder failed: $e');
      return ReminderResult.failed;
    }
  });

  /// Follows [login]'s schedule as just read: a segment moved to later
  /// moves its reminder; one cancelled, moved into the past or gone from
  /// the schedule drops it and its alarm. A reminder that went off on time
  /// is left for Activity ([takeDue]).
  Future<void> sync(String login, List<ScheduleSegment> segments) =>
      _oneAtATime(() async {
        final now = _now();
        final read = {for (final segment in segments) segment.id: segment};
        // Beyond the last segment read, a reminder may just not have been read.
        final readUntil = segments
            .map((s) => s.startAt)
            .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
        var changed = false;
        for (final reminder in [..._reminders.values]) {
          if (reminder.login != login) continue;
          final segment = read[reminder.segmentId];
          final bool drop;
          ScheduleReminder? moved;
          if (segment == null) {
            drop =
                reminder.startAt.isAfter(now) &&
                readUntil != null &&
                !reminder.startAt.isAfter(readUntil);
          } else if (segment.isCancelled) {
            drop = true;
          } else if (segment.startAt.isAtSameMomentAs(reminder.startAt)) {
            drop = false;
          } else if (canRemind(segment)) {
            drop = false;
            moved = reminder.movedTo(segment.startAt.toUtc());
          } else {
            // Moved into the past: nothing to remind of any more.
            drop = true;
          }
          try {
            if (drop) {
              await platform.cancel(reminderNoticeId(reminder.segmentId));
              _reminders.remove(reminder.segmentId);
              changed = true;
            } else if (moved != null) {
              await _schedule(moved);
              _reminders[reminder.segmentId] = moved;
              changed = true;
            }
          } catch (e) {
            debugPrint('Schedule reminder sync failed: $e');
          }
        }
        if (changed) {
          await _save();
          notifyListeners();
        }
      });

  /// The reminders that went off since last asked (for Activity), now
  /// forgotten.
  Future<List<ActivityEntry>> takeDue() => _oneAtATime(() async {
    final now = _now();
    final due = [
      for (final reminder in _reminders.values)
        if (!reminder.startAt.isAfter(now)) reminder,
    ];
    if (due.isEmpty) return const [];
    for (final reminder in due) {
      _reminders.remove(reminder.segmentId);
    }
    await _save();
    notifyListeners();
    return [for (final reminder in due) reminder.entryIn(_words())];
  });
}

/// Reminders through local notifications (Android and iOS). The alarm is
/// inexact unless exact alarms are already allowed: a few minutes late is
/// fine for a stream start, and asking for exact alarms is not worth it.
class LocalReminderPlatform implements ReminderPlatform {
  const LocalReminderPlatform();

  static final _plugin = FlutterLocalNotificationsPlugin();

  /// How they show, in [l]'s language: Android names the channel in the
  /// system's settings each time one is scheduled, so it follows the
  /// language.
  @visibleForTesting
  static NotificationDetails detailsFor(AppLocalizations l) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          'schedule_reminders',
          l.notifChannelReminders,
          channelDescription: l.notifChannelRemindersDescription,
          groupKey: 'onset.reminders',
          // Renames the existing channel when the language changed (the
          // default only creates a missing one). Android keeps the viewer's
          // settings of the channel: only its name and description change.
          channelAction: AndroidNotificationChannelAction.update,
        ),
        iOS: const DarwinNotificationDetails(
          threadIdentifier: 'schedule_reminders',
        ),
      );

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      return await _android?.requestNotificationsPermission() ?? false;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, sound: true) ??
        false;
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String payload,
    required AppLocalizations l,
  }) async {
    final exact =
        Platform.isAndroid &&
        (await _android?.canScheduleExactNotifications() ?? false);
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
      notificationDetails: detailsFor(l),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
      payload: payload,
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);
}
