import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/channel/video/live_state_watcher.dart';
import 'package:frosty/services/realtime/twitch_eventsub_client.dart';

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

  test('online and offline events are passed on', () async {
    expect(topics.keys, ['stream.online', 'stream.offline']);
    topics['stream.offline']!.add(const EventSubData({}));
    topics['stream.online']!.add(const EventSubData({}));
    await pumpEventQueue();
    expect(changes, [LiveChange.offline, LiveChange.online]);
  });

  test('listening again after a gap may have missed a change, once', () async {
    for (final events in topics.values) {
      events
        ..add(const EventSubListening(afterGap: false))
        ..add(const EventSubListening(afterGap: true));
    }
    await pumpEventQueue();
    expect(changes, [LiveChange.maybeMissed]);
  });

  test('dispose lets both topics go', () {
    watcher.dispose();
    expect(cancelled, ['stream.online', 'stream.offline']);
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
