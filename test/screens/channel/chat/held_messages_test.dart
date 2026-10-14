import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/channel/chat/held_messages.dart';
import 'package:frosty/services/realtime/twitch_eventsub_client.dart';

void main() {
  late Map<String, StreamController<EventSubTopicEvent>> topics;
  late List<EventSubTopic> asked;
  late List<String> cancelled;
  late List<String> notices;

  HeldMessageWatcher watch() => HeldMessageWatcher(
    broadcasterId: '42',
    userId: '7',
    onNotice: notices.add,
    listen: (topic) {
      asked.add(topic);
      final events = StreamController<EventSubTopicEvent>.broadcast();
      topics[topic.type] = events;
      return EventSubHandle.forTesting(
        topic,
        events.stream,
        () => cancelled.add(topic.type),
      );
    },
  );

  Map<String, Object?> update(String status, {Object? text = 'hello chat'}) => {
    'broadcaster_user_id': '42',
    'user_id': '7',
    'status': status,
    'message_id': 'm1',
    'message': {'text': text, 'fragments': []},
  };

  setUp(() {
    topics = {};
    asked = [];
    cancelled = [];
    notices = [];
  });

  test('listens to the viewer\'s held messages in the channel', () {
    watch();
    expect(asked.single.type, 'channel.chat.user_message_update');
    expect(asked.single.version, '1');
    expect(asked.single.condition, {
      'broadcaster_user_id': '42',
      'user_id': '7',
    });
  });

  test('says what the moderators decided', () async {
    watch();
    topics['channel.chat.user_message_update']!
      ..add(EventSubData(update('approved')))
      ..add(EventSubData(update('denied')))
      ..add(EventSubData(update('invalid')));
    await pumpEventQueue();

    expect(notices, [
      'Moderators approved your held message: "hello chat"',
      'Moderators denied your held message: "hello chat"',
      'Your held message can no longer be reviewed: "hello chat"',
    ]);
  });

  test('a message is quoted on one short line', () async {
    watch();
    topics['channel.chat.user_message_update']!.add(
      EventSubData(update('approved', text: 'a\nb\u202e${'x' * 200}')),
    );
    await pumpEventQueue();

    final notice = notices.single;
    expect(notice, isNot(contains('\n')));
    expect(notice, isNot(contains('\u202e')));
    expect(notice.length, lessThan(160));
    expect(notice, endsWith('…"'));
  });

  test(
    'other viewers and unknown statuses say nothing, odd text is left out',
    () async {
      watch();
      topics['channel.chat.user_message_update']!
        ..add(EventSubData({...update('approved'), 'user_id': '8'}))
        ..add(EventSubData(update('pending')))
        ..add(EventSubData(update('approved', text: 5)))
        ..add(const EventSubData({'status': 'approved'}))
        ..add(const EventSubListening(afterGap: false));
      await pumpEventQueue();

      expect(notices, ['Moderators approved your held message.']);
    },
  );

  test('refuses ids that are not numeric', () {
    expect(
      () => HeldMessageWatcher(
        broadcasterId: '42&x=1',
        userId: '7',
        onNotice: notices.add,
        listen: (_) => throw StateError('must not listen'),
      ),
      throwsArgumentError,
    );
  });

  test('dispose lets the topic go', () {
    watch().dispose();
    expect(cancelled, ['channel.chat.user_message_update']);
  });
}
