import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What kind of notification ONSET posted, named after Twitch's own
/// notification categories (lib/l10n/enum_labels.dart names them).
enum ActivityKind { live, mention, reminder }

final _login = RegExp(r'^[a-zA-Z0-9_]{1,25}$');

/// The largest time a [DateTime] holds, in milliseconds either way.
const _maxMs = 8640000000000000;

/// A time kept as milliseconds since the epoch, or null when [ms] is not
/// one a [DateTime] can hold (damaged storage).
DateTime? storedDate(Object? ms, {bool isUtc = false}) =>
    ms is int && ms.abs() <= _maxMs
    ? DateTime.fromMillisecondsSinceEpoch(ms, isUtc: isUtc)
    : null;

/// One notification ONSET posted, kept for the Activity screen.
@immutable
class ActivityEntry {
  const ActivityEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.at,
    this.login,
    this.read = false,
  });

  /// Unique per event: the same event is never listed twice.
  final String id;
  final ActivityKind kind;
  final String title;
  final String body;

  /// The channel it is about (opened on tap), when there is one.
  final String? login;
  final DateTime at;
  final bool read;

  ActivityEntry copyWith({bool? read}) => ActivityEntry(
    id: id,
    kind: kind,
    title: title,
    body: body,
    login: login,
    at: at,
    read: read ?? this.read,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'title': title,
    'body': body,
    'login': ?login,
    'at': at.millisecondsSinceEpoch,
    'read': read,
  };

  /// Null when [json] is not an entry (damaged or from a newer version).
  static ActivityEntry? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final kind = ActivityKind.values.asNameMap()[json['kind']];
    final title = json['title'];
    final body = json['body'];
    final at = storedDate(json['at']);
    if (id is! String || kind == null || title is! String) return null;
    if (body is! String || at == null) return null;
    final login = json['login'];
    return ActivityEntry(
      id: id,
      kind: kind,
      title: title,
      body: body,
      login: login is String && _login.hasMatch(login) ? login : null,
      at: at,
      read: json['read'] == true,
    );
  }
}

/// The notifications ONSET posted on this device (go-live, mentions,
/// reminders), newest first. Kept in plain preferences: the background
/// go-live task (its own isolate) adds to it too, so every change reads
/// the stored list again first.
///
/// Changes to one log run one at a time (the app keeps one: a go-live and
/// a mention at the same moment both land). Across isolates they are not locked: a
/// change of the app and of the background task in the same instant may
/// still drop one entry, which is accepted for a history list.
class ActivityLog {
  ActivityLog(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'activity_log';
  static const _viewedKey = 'activity_viewed_at';

  /// The oldest are dropped beyond this.
  static const maxEntries = 100;

  static Future<ActivityLog> load() async =>
      ActivityLog(await SharedPreferences.getInstance());

  /// Reads again what the other isolate wrote since.
  Future<void> reload() => _prefs.reload();

  List<ActivityEntry> get entries {
    final list = <ActivityEntry>[];
    for (final raw in _prefs.getStringList(_key) ?? const <String>[]) {
      try {
        final entry = ActivityEntry.fromJson(jsonDecode(raw));
        if (entry != null) list.add(entry);
      } on FormatException {
        // A damaged entry is dropped; the others still show.
      }
    }
    return list..sort((a, b) => b.at.compareTo(a.at));
  }

  int get unreadCount => entries.where((e) => !e.read).length;

  /// When the list was last opened: what came after is new (the bell).
  DateTime? get viewedAt => storedDate(_prefs.getInt(_viewedKey));

  Future<void> setViewedAt(DateTime at) =>
      _prefs.setInt(_viewedKey, at.millisecondsSinceEpoch);

  Future<void> _save(List<ActivityEntry> list) {
    list.sort((a, b) => b.at.compareTo(a.at));
    return _prefs.setStringList(_key, [
      for (final entry in list.take(maxEntries)) jsonEncode(entry.toJson()),
    ]);
  }

  /// The last change queued on this log, null when none is running. The
  /// app keeps one log (in its `ActivityStore`), so its changes all go
  /// through this queue.
  Future<void>? _tail;

  /// Runs [change] after the changes queued before it, failures included.
  Future<T> _serial<T>(Future<T> Function() change) {
    final previous = _tail;
    final result = previous == null
        ? Future.sync(change)
        : previous.then((_) => change());
    final tail = result.then<void>((_) {}, onError: (Object _) {});
    _tail = tail;
    unawaited(
      tail.whenComplete(() {
        if (identical(_tail, tail)) _tail = null;
      }),
    );
    return result;
  }

  /// Adds [entry] unless an entry with its id is already there; true when
  /// added.
  Future<bool> add(ActivityEntry entry) => addAll([entry]).then((n) => n > 0);

  /// Adds the [added] not already there; returns how many were added.
  Future<int> addAll(Iterable<ActivityEntry> added) {
    final list = added.toList();
    return _serial(() => _addAll(list));
  }

  Future<int> _addAll(List<ActivityEntry> added) async {
    await reload();
    final list = entries;
    final ids = {for (final entry in list) entry.id};
    var count = 0;
    for (final entry in added) {
      if (ids.add(entry.id)) {
        list.add(entry);
        count++;
      }
    }
    if (count > 0) await _save(list);
    return count;
  }

  Future<void> markRead(String id) => _serial(() async {
    await reload();
    await _save([
      for (final entry in entries)
        entry.id == id ? entry.copyWith(read: true) : entry,
    ]);
  });

  Future<void> markAllRead() => _serial(() async {
    await reload();
    await _save([for (final entry in entries) entry.copyWith(read: true)]);
  });

  Future<void> remove(String id) => _serial(() async {
    await reload();
    await _save([
      for (final entry in entries)
        if (entry.id != id) entry,
    ]);
  });

  Future<void> clear() => _serial(() => _prefs.remove(_key));
}
