import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/services/notifications/activity_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

ActivityEntry _entry(
  String id, {
  DateTime? at,
  ActivityKind kind = ActivityKind.live,
  bool read = false,
}) => ActivityEntry(
  id: id,
  kind: kind,
  title: 'Title $id',
  body: 'Body $id',
  login: 'login_$id',
  at: at ?? DateTime.utc(2026, 10, 20, 12),
  read: read,
);

void main() {
  late ActivityLog log;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    log = await ActivityLog.load();
  });

  test('starts empty', () {
    expect(log.entries, isEmpty);
  });

  test('keeps entries newest first, across a reload', () async {
    await log.add(_entry('a', at: DateTime.utc(2026, 10, 20, 10)));
    await log.add(_entry('b', at: DateTime.utc(2026, 10, 20, 12)));
    await log.add(_entry('c', at: DateTime.utc(2026, 10, 20, 11)));
    final again = await ActivityLog.load();
    expect(again.entries.map((e) => e.id), ['b', 'c', 'a']);
    final b = again.entries.first;
    expect(b.kind, ActivityKind.live);
    expect(b.title, 'Title b');
    expect(b.body, 'Body b');
    expect(b.login, 'login_b');
    expect(b.at.isAtSameMomentAs(DateTime.utc(2026, 10, 20, 12)), isTrue);
    expect(b.read, isFalse);
  });

  test('an entry already there is not added twice', () async {
    expect(await log.add(_entry('a')), isTrue);
    expect(await log.add(_entry('a')), isFalse);
    expect(log.entries, hasLength(1));
  });

  test('keeps at most the latest ones', () async {
    for (var i = 0; i < ActivityLog.maxEntries + 5; i++) {
      await log.add(
        _entry('$i', at: DateTime.utc(2026).add(Duration(minutes: i))),
      );
    }
    expect(log.entries, hasLength(ActivityLog.maxEntries));
    expect(log.entries.last.id, '5');
  });

  test('unread count, mark one or all as read, remove', () async {
    await log.add(_entry('a'));
    await log.add(_entry('b'));
    await log.add(_entry('c', read: true));
    expect(log.unreadCount, 2);
    await log.markRead('a');
    expect(log.unreadCount, 1);
    await log.markAllRead();
    expect(log.unreadCount, 0);
    await log.remove('b');
    expect(log.entries.map((e) => e.id), unorderedEquals(['a', 'c']));
    await log.clear();
    expect(log.entries, isEmpty);
  });

  test('a damaged entry is skipped, the rest is read', () async {
    SharedPreferences.setMockInitialValues({
      'activity_log': [
        'not json',
        '{"id":"x"}',
        '{"id":"ok","kind":"mention","title":"T","body":"","at":0}',
        '{"id":"odd","kind":"unknown","title":"T","body":"","at":0}',
      ],
    });
    final damaged = await ActivityLog.load();
    expect(damaged.entries.map((e) => e.id), ['ok']);
    expect(damaged.entries.single.kind, ActivityKind.mention);
    expect(damaged.entries.single.login, isNull);
  });

  test('a login that is not a Twitch login is dropped', () {
    final entry = ActivityEntry.fromJson({
      'id': 'e',
      'kind': 'live',
      'title': 'T',
      'body': '',
      'at': 0,
      'login': '../evil',
    });
    expect(entry!.login, isNull);
  });

  test('labels follow Twitch\'s notification categories', () {
    expect(ActivityKind.live.label, 'Live');
    expect(ActivityKind.mention.label, 'Chat Mentions');
    expect(ActivityKind.reminder.label, 'Events');
  });
}
