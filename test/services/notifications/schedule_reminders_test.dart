import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/channel_profile.dart';
import 'package:frosty/services/notifications/activity_log.dart';
import 'package:frosty/services/notifications/schedule_reminders.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeReminderPlatform implements ReminderPlatform {
  var granted = true;
  var fail = false;
  var failCancel = false;
  final scheduled =
      <int, ({DateTime at, String title, String body, String payload})>{};
  final cancelled = <int>[];

  @override
  Future<bool> requestPermission() async => granted;

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (fail) throw StateError('alarm');
    scheduled[id] = (at: at, title: title, body: body, payload: payload);
  }

  @override
  Future<void> cancel(int id) async {
    if (failCancel) throw StateError('alarm');
    cancelled.add(id);
    scheduled.remove(id);
  }
}

final _now = DateTime.utc(2026, 10, 20, 12);

ScheduleSegment _segment(
  String id, {
  Duration inFuture = const Duration(hours: 4),
  bool cancelled = false,
  String? title = 'Ranked',
  String? category = 'Chess',
}) => ScheduleSegment(
  id: id,
  startAt: _now.add(inFuture),
  title: title,
  categoryName: category,
  isCancelled: cancelled,
);

void main() {
  late FakeReminderPlatform platform;
  late ScheduleReminders reminders;

  Future<ScheduleReminders> load() async => ScheduleReminders(
    prefs: await SharedPreferences.getInstance(),
    platform: platform,
    now: () => _now,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    platform = FakeReminderPlatform();
    reminders = await load();
  });

  test('sets a reminder at the segment start, kept across launches', () async {
    final segment = _segment('s1');
    final result = await reminders.toggle(
      segment,
      login: 'streamer',
      channelName: 'Streamer',
    );
    expect(result, ReminderResult.set);
    expect(reminders.isSet('s1'), isTrue);
    final notice = platform.scheduled[reminderNoticeId('s1')]!;
    expect(notice.at, segment.startAt);
    expect(notice.title, "Streamer's stream is starting");
    expect(notice.body, 'Ranked · Chess');
    expect(notice.payload, 'streamer');

    final again = await load();
    expect(again.isSet('s1'), isTrue);
  });

  test('toggling again cancels it', () async {
    final segment = _segment('s1');
    await reminders.toggle(segment, login: 'streamer', channelName: 'S');
    final result = await reminders.toggle(
      segment,
      login: 'streamer',
      channelName: 'S',
    );
    expect(result, ReminderResult.cleared);
    expect(reminders.isSet('s1'), isFalse);
    expect(platform.cancelled, [reminderNoticeId('s1')]);
    expect((await load()).isSet('s1'), isFalse);
  });

  test('a reminder that cannot be cancelled stays set', () async {
    final segment = _segment('s1');
    await reminders.toggle(segment, login: 'a', channelName: 'A');
    platform.failCancel = true;
    final result = await reminders.toggle(
      segment,
      login: 'a',
      channelName: 'A',
    );
    expect(result, ReminderResult.failed);
    expect(reminders.isSet('s1'), isTrue);
  });

  test('tells listeners when a reminder changes', () async {
    var changes = 0;
    reminders.addListener(() => changes++);
    await reminders.toggle(_segment('s1'), login: 'a', channelName: 'A');
    expect(changes, 1);
  });

  test('a refused right sets nothing', () async {
    platform.granted = false;
    final result = await reminders.toggle(
      _segment('s1'),
      login: 'a',
      channelName: 'A',
    );
    expect(result, ReminderResult.refused);
    expect(reminders.isSet('s1'), isFalse);
    expect(platform.scheduled, isEmpty);
  });

  test('a failed schedule sets nothing', () async {
    platform.fail = true;
    final result = await reminders.toggle(
      _segment('s1'),
      login: 'a',
      channelName: 'A',
    );
    expect(result, ReminderResult.failed);
    expect(reminders.isSet('s1'), isFalse);
  });

  test('only a segment still to come and not cancelled can have one', () {
    expect(reminders.canRemind(_segment('a')), isTrue);
    expect(
      reminders.canRemind(_segment('b', inFuture: -const Duration(minutes: 1))),
      isFalse,
    );
    expect(reminders.canRemind(_segment('c', cancelled: true)), isFalse);
  });

  test('a notice without title or category still reads', () async {
    await reminders.toggle(
      _segment('s1', title: null, category: null),
      login: 'a',
      channelName: 'A',
    );
    expect(platform.scheduled.values.single.body, 'Stream');
  });

  test('past reminders are handed to Activity once, then forgotten', () async {
    await reminders.toggle(
      _segment('s1', inFuture: const Duration(minutes: 5)),
      login: 'streamer',
      channelName: 'Streamer',
    );
    await reminders.toggle(_segment('s2'), login: 'b', channelName: 'B');
    final later = ScheduleReminders(
      prefs: await SharedPreferences.getInstance(),
      platform: platform,
      now: () => _now.add(const Duration(hours: 1)),
    );
    final due = await later.takeDue();
    expect(due, hasLength(1));
    final entry = due.single;
    expect(entry.id, 'reminder:s1');
    expect(entry.kind, ActivityKind.reminder);
    expect(entry.title, "Streamer's stream is starting");
    expect(entry.login, 'streamer');
    expect(entry.at, _now.add(const Duration(minutes: 5)));
    expect(later.isSet('s1'), isFalse);
    expect(later.isSet('s2'), isTrue);
    expect(await later.takeDue(), isEmpty);
  });

  test('a moved segment is rescheduled, a cancelled one dropped', () async {
    await reminders.toggle(_segment('s1'), login: 'a', channelName: 'A');
    await reminders.toggle(_segment('s2'), login: 'a', channelName: 'A');
    await reminders.toggle(_segment('s3'), login: 'b', channelName: 'B');
    final moved = _segment('s1', inFuture: const Duration(hours: 6));
    await reminders.sync('a', [moved, _segment('s2', cancelled: true)]);
    expect(platform.scheduled[reminderNoticeId('s1')]!.at, moved.startAt);
    expect(reminders.isSet('s2'), isFalse);
    expect(platform.cancelled, contains(reminderNoticeId('s2')));
    // Another channel's reminders are left alone.
    expect(reminders.isSet('s3'), isTrue);
  });

  test('a damaged stored reminder is dropped', () async {
    SharedPreferences.setMockInitialValues({
      'schedule_reminders': ['nope', '{"segmentId":"x"}'],
    });
    final damaged = await load();
    expect(damaged.isSet('x'), isFalse);
  });

  test('notice ids are stable per segment and avoid the fixed ones', () {
    expect(reminderNoticeId('s1'), reminderNoticeId('s1'));
    expect(reminderNoticeId('s1'), isNot(reminderNoticeId('s2')));
    expect(reminderNoticeId('s1'), greaterThan(1));
  });
}
