import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/activity/stores/activity_store.dart';
import 'package:onset/services/notifications/activity_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

ActivityEntry _entry(String id, {int minute = 0}) => ActivityEntry(
  id: id,
  kind: ActivityKind.mention,
  title: 'Title $id',
  body: '',
  at: DateTime.utc(2026, 10, 20, 12, minute),
);

void main() {
  late ActivityLog log;
  late ActivityStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    log = await ActivityLog.load();
    store = ActivityStore(log: log);
  });

  test('adds, counts unread, and marks as read', () async {
    await store.addAll([_entry('a'), _entry('b', minute: 1)]);
    expect(store.entries.map((e) => e.id), ['b', 'a']);
    expect(store.unreadCount, 2);
    await store.markRead('a');
    expect(store.unreadCount, 1);
    await store.markAllRead();
    expect(store.unreadCount, 0);
    await store.remove('b');
    expect(store.entries.map((e) => e.id), ['a']);
  });

  test('the bell counts what came since the list was viewed', () async {
    await store.addAll([_entry('a'), _entry('b', minute: 5)]);
    expect(store.newCount, 2);
    await store.markViewed(at: DateTime.utc(2026, 10, 20, 12, 1));
    expect(store.newCount, 1);
    // Still unread (bold) in the list until opened.
    expect(store.unreadCount, 2);
    await store.markViewed(at: DateTime.utc(2026, 10, 20, 12, 10));
    expect(store.newCount, 0);
    await store.addAll([_entry('c', minute: 11)]);
    expect(store.newCount, 1);
  });

  test('refresh shows what the background task added', () async {
    await store.refresh();
    expect(store.entries, isEmpty);
    // The background task writes through its own log.
    await (await ActivityLog.load()).add(_entry('x'));
    await store.refresh();
    expect(store.entries.single.id, 'x');
  });

  test('a failing log leaves the list as it was', () async {
    await store.addAll([_entry('a')]);
    final broken = ActivityStore(log: _BrokenLog());
    await broken.refresh();
    await broken.addAll([_entry('b')]);
    await broken.markAllRead();
    expect(broken.entries, isEmpty);
  });
}

class _BrokenLog implements ActivityLog {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('storage unavailable');
}
