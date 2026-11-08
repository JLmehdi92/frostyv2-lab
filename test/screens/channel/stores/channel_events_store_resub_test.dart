import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_community_service.dart';
import 'package:onset/apis/twitch_points_service.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/apis/twitch_watch_streak_service.dart';
import 'package:onset/models/community_points.dart';
import 'package:onset/models/resub_notification.dart';
import 'package:onset/models/watch_streak.dart';
import 'package:onset/screens/channel/stores/channel_events_store.dart';
import 'package:onset/services/hermes_client.dart';

class MockPointsService extends Mock implements TwitchPointsService {}

class MockHermesClient extends Mock implements HermesClient {}

class MockWatchStreakService extends Mock implements TwitchWatchStreakService {}

class MockViewerActions extends Mock implements TwitchViewerActionsService {}

class MockCommunity extends Mock implements TwitchCommunityService {}

const _resub = ResubNotification(months: 14, tokenId: 'token-1');

void main() {
  late MockPointsService points;
  late MockHermesClient hermes;
  late MockWatchStreakService streaks;
  late MockViewerActions actions;
  late MockCommunity community;
  late StreamController<HermesEvent> events;

  setUp(() {
    points = MockPointsService();
    hermes = MockHermesClient();
    streaks = MockWatchStreakService();
    actions = MockViewerActions();
    community = MockCommunity();
    events = StreamController<HermesEvent>.broadcast();
    when(() => hermes.events).thenAnswer((_) => events.stream);
    when(() => hermes.subscribeAll(any())).thenAnswer((_) async {});
    when(() => hermes.dispose()).thenReturn(null);
    when(
      () => points.fetchContext(
        userLogin: any(named: 'userLogin'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer((_) async => CommunityPointsContext.empty);
    when(
      () => streaks.getWatchStreak(
        channelId: any(named: 'channelId'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer((_) async => const WatchStreak(value: 3));
    when(
      () => community.getResubNotification(
        channelId: any(named: 'channelId'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer((_) async => _resub);
  });

  tearDown(() => events.close());

  ChannelEventsStore build({String? token = 'webtok'}) => ChannelEventsStore(
    channelId: '42',
    channelLogin: 'streamer',
    client: hermes,
    pointsService: points,
    watchStreakService: streaks,
    viewerActionsService: actions,
    communityService: community,
    tokenProvider: () async => token,
  );

  void shareAnswers(ViewerActionOutcome outcome) => when(
    () => actions.shareResub(
      channelLogin: any(named: 'channelLogin'),
      tokenId: any(named: 'tokenId'),
      message: any(named: 'message'),
      authToken: any(named: 'authToken'),
    ),
  ).thenAnswer((_) async => outcome);

  test('refreshing reads the shareable resub with the web token', () async {
    final store = build();
    await store.refreshWatchStreak();
    await pumpEventQueue();

    expect(store.resubNotification, _resub);
    expect(store.canShareResub, isTrue);
    verify(
      () => community.getResubNotification(channelId: '42', authToken: 'webtok'),
    ).called(1);
  });

  test('signed out, no resub is asked', () async {
    final store = build(token: null);
    await store.refreshWatchStreak();
    await pumpEventQueue();

    expect(store.resubNotification, isNull);
    verifyNever(
      () => community.getResubNotification(
        channelId: any(named: 'channelId'),
        authToken: any(named: 'authToken'),
      ),
    );
  });

  test('a shared resub goes away even if Twitch still lists it', () async {
    shareAnswers(ViewerActionOutcome.done);
    final store = build();
    await store.refreshWatchStreak();
    await pumpEventQueue();

    final outcome = await store.shareResub(message: 'Hi');

    expect(outcome, ViewerActionOutcome.done);
    expect(store.resubNotification, isNull);
    verify(
      () => actions.shareResub(
        channelLogin: 'streamer',
        tokenId: 'token-1',
        message: 'Hi',
        authToken: 'webtok',
      ),
    ).called(1);
  });

  test('a refused share keeps the offer', () async {
    shareAnswers(ViewerActionOutcome.refused);
    final store = build();
    await store.refreshWatchStreak();
    await pumpEventQueue();

    expect(await store.shareResub(), ViewerActionOutcome.refused);
    expect(store.resubNotification, _resub);
  });

  test('nothing is shared without an offer', () async {
    final store = build();

    expect(await store.shareResub(), isNull);
    verifyNever(
      () => actions.shareResub(
        channelLogin: any(named: 'channelLogin'),
        tokenId: any(named: 'tokenId'),
        message: any(named: 'message'),
        authToken: any(named: 'authToken'),
      ),
    );
  });
}
