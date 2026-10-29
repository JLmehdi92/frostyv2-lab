import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_community_highlights_service.dart';
import 'package:onset/models/community_highlight_event.dart';
import 'package:onset/models/community_highlights.dart';
import 'package:onset/screens/channel/community_highlights/stores/community_highlights_store.dart';
import 'package:onset/services/realtime/twitch_realtime_client.dart';

class MockService extends Mock implements TwitchCommunityHighlightsService {}

class MockRealtime extends Mock implements TwitchRealtimeClient {}

const harnessChannel = '42';
final harnessNow = DateTime.utc(2026, 10, 13, 20);

String pollPayload(
  String type, {
  String id = 'p',
  String status = 'ACTIVE',
  List<int> votes = const [1, 2],
  String owner = harnessChannel,
  DateTime? endedAt,
}) => jsonEncode({
  'type': type,
  'data': {
    'poll': {
      'poll_id': id,
      'owned_by': owner,
      'title': 'Which?',
      'status': status,
      'started_at': harnessNow.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'duration_seconds': 60,
      'choices': [
        for (var i = 0; i < votes.length; i++)
          {
            'choice_id': 'c$i',
            'title': 'C$i',
            'votes': {'total': votes[i]},
            'total_voters': votes[i],
          },
      ],
      'votes': {'total': votes.fold(0, (a, b) => a + b)},
    },
  },
});

String predictionPayload({
  String id = 'e',
  String status = 'ACTIVE',
  DateTime? endedAt,
  String? winner,
}) => jsonEncode({
  'type': 'event-updated',
  'data': {
    'timestamp': clock.now().toIso8601String(),
    'event': {
      'id': id,
      'channel_id': harnessChannel,
      'title': 'Win?',
      'status': status,
      'created_at': harnessNow.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'prediction_window_seconds': 120,
      'winning_outcome_id': winner,
      'outcomes': [
        {'id': 'a', 'title': 'Yes', 'color': 'BLUE', 'total_points': 10},
        {'id': 'b', 'title': 'No', 'color': 'PINK', 'total_points': 5},
      ],
    },
  },
});

String pinPayload(String id, {DateTime? endsAt}) => jsonEncode({
  'type': 'pin-message',
  'data': {
    'id': id,
    'message': {
      'id': 'm-$id',
      'sender': {'id': '7', 'login': 'mod', 'display_name': 'Mod'},
      'content': {'text': 'Rules'},
      'starts_at': harnessNow.millisecondsSinceEpoch ~/ 1000,
      'ends_at': endsAt == null ? null : endsAt.millisecondsSinceEpoch ~/ 1000,
    },
  },
});

String raidPayload(
  String type, {
  String source = harnessChannel,
  int viewers = 5,
  DateTime? createdAt,
}) => jsonEncode({
  'type': type,
  'raid': {
    'id': 'r',
    'source_id': source,
    'target_id': '9',
    'target_login': 'friend',
    'target_display_name': 'Friend',
    'viewer_count': viewers,
    'raid_created_at': (createdAt ?? harnessNow).millisecondsSinceEpoch ~/ 1000,
    'force_raid_now_seconds': 90,
  },
});

PinnedChatMessage pinnedModel(String id, {DateTime? endsAt}) =>
    PinnedChatMessage(
      id: id,
      senderLogin: 'mod',
      senderDisplayName: 'Mod',
      text: 'Rules',
      fragments: const [],
      badges: const [],
      endsAt: endsAt,
    );

class Harness {
  Harness() {
    for (final topic in HighlightTopic.values) {
      topics[topic] = StreamController<RealtimeTopicEvent>.broadcast(
        sync: true,
      );
    }
    when(() => service.getPoll(any())).thenAnswer((_) async => null);
    when(
      () => service.getPredictions(any()),
    ).thenAnswer((_) async => (active: null, locked: null, lastResolved: null));
    when(() => service.getPinned(any())).thenAnswer((_) async => null);
    when(() => realtime.subscribe(any())).thenAnswer((invocation) {
      final name = invocation.positionalArguments.single as String;
      subscribed.add(name);
      final topic = HighlightTopic.values.firstWhere(
        (t) => name == t.topicFor(harnessChannel),
      );
      return RealtimeTopicSubscription.forTesting(
        name,
        topics[topic]!.stream,
        () => cancelled.add(name),
      );
    });
  }

  final service = MockService();
  final realtime = MockRealtime();
  final topics = <HighlightTopic, StreamController<RealtimeTopicEvent>>{};
  final subscribed = <String>[];
  final cancelled = <String>[];
  late CommunityHighlightsStore store;

  /// The raids [CommunityHighlightsStore.onGoAlong] took the viewer along.
  final wentAlong = <OutgoingRaid>[];

  CommunityHighlightsStore create({bool expandNew = false}) =>
      store = CommunityHighlightsStore(
        channelId: harnessChannel,
        service: service,
        realtime: realtime,
        expandNew: expandNew,
        onGoAlong: wentAlong.add,
      );

  void send(HighlightTopic topic, String payload) =>
      topics[topic]!.add(RealtimeMessage(payload));
}
