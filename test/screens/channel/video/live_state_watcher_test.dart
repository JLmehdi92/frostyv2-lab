import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/channel/video/live_state_watcher.dart';
import 'package:onset/services/realtime/twitch_eventsub_client.dart';

void main() {
  late Map<String, StreamController<EventSubTopicEvent>> topics;
  late List<String> cancelled;
  late List<LiveChange> changes;
  late LiveStateWatcher watcher;

  setUp(() {
    topics = {};
    cancelled = [];
    changes = [];
    watcher = LiveStateWatcher(
      broadcasterId: '42',
      onChange: changes.add,
      listen: (topic) {
        expect(topic.condition, {'broadcaster_user_id': '42'});
        final events = StreamController<EventSubTopicEvent>.broadcast();
        topics[topic.type] = events;
        return EventSubHandle.forTesting(
          topic,
          events.stream,
          () => cancelled.add(topic.type),
        );
      },
    );
  });

  test('going live is passed on', () async {
    expect(topics.keys, ['stream.online']);
    topics['stream.online']!.add(const EventSubData({}));
    await pumpEventQueue();
    expect(changes, [LiveChange.online]);
  });

  test('listening again after a gap may have missed it', () async {
    topics['stream.online']!
      ..add(const EventSubListening(afterGap: false))
      ..add(const EventSubListening(afterGap: true));
    await pumpEventQueue();
    expect(changes, [LiveChange.maybeMissed]);
  });

  test('dispose lets the topic go', () {
    watcher.dispose();
    expect(cancelled, ['stream.online']);
  });

  test('refuses an id that is not one', () {
    expect(
      () => LiveStateWatcher(
        listen: (_) => throw StateError('never'),
        broadcasterId: 'x',
        onChange: (_) {},
      ),
      throwsArgumentError,
    );
  });
}
