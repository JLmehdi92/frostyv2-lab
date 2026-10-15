import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_points_service.dart';
import 'package:frosty/models/community_points.dart';
import 'package:frosty/screens/channel/stores/channel_events_store.dart';
import 'package:frosty/services/hermes_client.dart';
import 'package:mocktail/mocktail.dart';

class MockPointsService extends Mock implements TwitchPointsService {}

class MockHermesClient extends Mock implements HermesClient {}

const _reward = PointsReward(id: 'r1', title: 'Hydrate', cost: 100);

void main() {
  setUpAll(() {
    registerFallbackValue(_reward);
  });

  late MockPointsService points;
  late MockHermesClient hermes;
  late StreamController<HermesEvent> events;

  setUp(() {
    points = MockPointsService();
    hermes = MockHermesClient();
    events = StreamController<HermesEvent>.broadcast();

    when(() => hermes.events).thenAnswer((_) => events.stream);
    when(() => hermes.subscribeAll(any())).thenAnswer((_) async {});
    when(() => hermes.pause()).thenReturn(null);
    when(() => hermes.resume()).thenAnswer((_) async {});
    when(() => hermes.dispose()).thenReturn(null);
    when(
      () => points.fetchContext(
        userLogin: any(named: 'userLogin'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer((_) async => CommunityPointsContext.empty);
    when(
      () => points.redeemReward(
        channelId: any(named: 'channelId'),
        reward: any(named: 'reward'),
        authToken: any(named: 'authToken'),
        userInput: any(named: 'userInput'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => points.makePrediction(
        eventId: any(named: 'eventId'),
        outcomeId: any(named: 'outcomeId'),
        points: any(named: 'points'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => points.claimBonus(
        channelId: any(named: 'channelId'),
        claimId: any(named: 'claimId'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer((_) async => null);
  });

  tearDown(() => events.close());

  ChannelEventsStore build({
    Future<String?> Function()? tokenProvider,
    String? channelLogin = 'streamer',
    String? viewerId,
  }) => ChannelEventsStore(
    channelId: '42',
    channelLogin: channelLogin,
    viewerId: viewerId,
    client: hermes,
    pointsService: points,
    tokenProvider: tokenProvider,
  );

  void verifyRedeemCalled(int times) => verify(
    () => points.redeemReward(
      channelId: any(named: 'channelId'),
      reward: any(named: 'reward'),
      authToken: any(named: 'authToken'),
      userInput: any(named: 'userInput'),
    ),
  ).called(times);

  test('a malformed celebration is dropped without throwing', () async {
    final store = build();
    await store.connect();

    events.add(
      const HermesEvent(
        topic: 'celebration-events-v1.42',
        type: 'alert_sets_celebration',
        data: {'type': 5, 'area': 1},
      ),
    );
    await pumpEventQueue();

    expect(store.celebration, isNull);
    store.dispose();
  });

  group('a second tap while the token is still being read', () {
    test('cannot redeem twice', () async {
      final token = Completer<String?>();
      final store = build(tokenProvider: () => token.future);

      final first = store.redeemReward(_reward);
      final second = store.redeemReward(_reward);
      token.complete('tok');

      final results = await Future.wait([first, second]);

      expect(results.first.isSuccess, isTrue);
      expect(results.last.rawCode, 'busy');
      verifyRedeemCalled(1);
    });

    test('cannot bet twice', () async {
      final token = Completer<String?>();
      final store = build(tokenProvider: () => token.future);

      Future<PointsActionResult> bet() =>
          store.placePrediction(eventId: 'e', outcomeId: 'o', points: 10);
      final first = bet();
      final second = bet();
      token.complete('tok');

      final results = await Future.wait([first, second]);

      expect(results.first.isSuccess, isTrue);
      expect(results.last.rawCode, 'busy');
      verify(
        () => points.makePrediction(
          eventId: any(named: 'eventId'),
          outcomeId: any(named: 'outcomeId'),
          points: any(named: 'points'),
          authToken: any(named: 'authToken'),
        ),
      ).called(1);
    });

    test('a claim blocks a redeem started behind it', () async {
      when(
        () => points.fetchContext(
          userLogin: any(named: 'userLogin'),
          authToken: any(named: 'authToken'),
        ),
      ).thenAnswer(
        (_) async => const CommunityPointsContext(
          balance: 500,
          availableClaimId: 'chest',
        ),
      );
      var token = Completer<String?>()..complete('tok');
      final store = build(tokenProvider: () => token.future);
      await store.refreshPoints();

      token = Completer<String?>();
      final claim = store.claimBonus();
      final redeem = store.redeemReward(_reward);
      token.complete('tok');

      final results = await Future.wait([claim, redeem]);

      expect(results.first.isSuccess, isTrue);
      expect(results.last.rawCode, 'busy');
      verifyNever(
        () => points.redeemReward(
          channelId: any(named: 'channelId'),
          reward: any(named: 'reward'),
          authToken: any(named: 'authToken'),
          userInput: any(named: 'userInput'),
        ),
      );
      expect(store.pointsActionInFlight, isFalse);
    });
  });
}
