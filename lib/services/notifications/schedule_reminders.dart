import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:frosty/models/channel_profile.dart';
import 'package:frosty/services/notifications/activity_log.dart';
import 'package:frosty/services/notifications/notice_ids.dart';
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

  String get noticeTitle => "$channelName's stream is starting";

  String get noticeBody {
    final parts = [
      for (final part in [title, category])
        if (part != null && part.trim().isNotEmpty) part.trim(),
    ];
    return parts.isEmpty ? 'Stream' : parts.join(' · ');
  }

  ScheduleReminder movedTo(DateTime at) => ScheduleReminder(
    segmentId: segmentId,
    login: login,
    channelName: channelName,
    startAt: at,
    title: title,
    category: category,
  );

  /// Its Activity entry, at the time it went off.
  ActivityEntry get entry => ActivityEntry(
    id: 'reminder:$segmentId',
    kind: ActivityKind.reminder,
    title: noticeTitle,
    body: noticeBody,
    login: login,
    at: startAt,
  );

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
    final startAt = json['startAt'];
    if (id is! String || login is! String || !_login.hasMatch(login)) {
      return null;
    }
    if (name is! String || startAt is! int) return null;
    final title = json['title'];
    final category = json['category'];
    return ScheduleReminder(
      segmentId: id,
      login: login,
      channelName: name,
      startAt: DateTime.fromMillisecondsSinceEpoch(startAt, isUtc: true),
      title: title is String ? title : null,
      category: category is String ? category : null,
    );
  }
}

/// The notification id of a segment's reminder.
int reminderNoticeId(String segmentId) => stableNoticeId('reminder:$segmentId');

/// What came of a tap on "Remind Me".
enum ReminderResult { set, cleared, refused, failed }

/// The system side of reminders, swappable in tests.
abstract interface class ReminderPlatform {
  /// Asks for the right to notify; true when granted.
  Future<bool> requestPermission();

  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String payload,
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
  }) : _prefs = prefs,
       _now = now ?? DateTime.now {
    _reminders = _read();
  }

  /// The app's reminders, set up at launch (null in tests and before).
  static ScheduleReminders? shared;

  static const _key = 'schedule_reminders';

  final SharedPreferences _prefs;
  final ReminderPlatform platform;
  final DateTime Function() _now;

  late Map<String, ScheduleReminder> _reminders;

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

  Future<void> _schedule(ScheduleReminder reminder) => platform.schedule(
    id: reminderNoticeId(reminder.segmentId),
    at: reminder.startAt,
    title: reminder.noticeTitle,
    body: reminder.noticeBody,
    payload: reminder.login,
  );

  /// Sets [segment]'s reminder, or clears it when set.
  Future<ReminderResult> toggle(
    ScheduleSegment segment, {
    required String login,
    required String channelName,
  }) async {
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
  }

  /// Follows [login]'s schedule as just read: a moved segment's reminder
  /// moves with it, a cancelled one's is dropped.
  Future<void> sync(String login, List<ScheduleSegment> segments) async {
    var changed = false;
    for (final segment in segments) {
      final reminder = _reminders[segment.id];
      if (reminder == null || reminder.login != login) continue;
      try {
        if (!canRemind(segment)) {
          if (segment.isCancelled) {
            await platform.cancel(reminderNoticeId(segment.id));
            _reminders.remove(segment.id);
            changed = true;
          }
        } else if (!segment.startAt.isAtSameMomentAs(reminder.startAt)) {
          final moved = reminder.movedTo(segment.startAt.toUtc());
          await _schedule(moved);
          _reminders[segment.id] = moved;
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
  }

  /// The reminders that went off since last asked (for Activity), now
  /// forgotten.
  Future<List<ActivityEntry>> takeDue() async {
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
    return [for (final reminder in due) reminder.entry];
  }
}

/// Reminders through local notifications (Android and iOS). The alarm is
/// inexact unless exact alarms are already allowed: a few minutes late is
/// fine for a stream start, and asking for exact alarms is not worth it.
class LocalReminderPlatform implements ReminderPlatform {
  const LocalReminderPlatform();

  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'schedule_reminders',
      'Stream reminders',
      channelDescription: 'Scheduled streams you asked to be reminded of',
      groupKey: 'frosty.reminders',
    ),
    iOS: DarwinNotificationDetails(threadIdentifier: 'schedule_reminders'),
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
  }) async {
    final exact =
        Platform.isAndroid &&
        (await _android?.canScheduleExactNotifications() ?? false);
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
      notificationDetails: _details,
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
