import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_points_service.dart';
import 'package:onset/models/celebration.dart';
import 'package:onset/models/community_points.dart';
import 'package:onset/models/hermes.dart';
import 'package:onset/screens/channel/stores/channel_events_store.dart';
import 'package:onset/services/hermes_client.dart';

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

  group('emote entitlements', () {
    test('a message on the viewer’s subscriptions topic says so', () async {
      final store = build(viewerId: '7');
      final changes = <void>[];
      store.entitlementChanges.listen(changes.add);
      await store.connect();
      verify(
        () => hermes.subscribeAll(
          any(that: contains('user-subscribe-events-v1.7')),
        ),
      ).called(1);

      events.add(
        const HermesEvent(
          topic: 'user-subscribe-events-v1.7',
          type: '',
          data: {'channel_id': '42', 'user_id': '7'},
        ),
      );
      events.add(
        const HermesEvent(
          topic: 'user-subscribe-events-v1.8',
          type: '',
          data: {},
        ),
      );
      await pumpEventQueue();
      expect(changes, hasLength(1));
      store.dispose();
    });

    test('redeeming an emote unlock says so, other rewards do not', () async {
      final store = build(tokenProvider: () async => 'tok');
      final changes = <void>[];
      store.entitlementChanges.listen(changes.add);

      await store.redeemReward(_reward);
      await store.redeemReward(
        const PointsReward(
          id: 'auto',
          title: '',
          cost: 100,
          automaticType: 'RANDOM_SUB_EMOTE_UNLOCK',
        ),
      );
      await pumpEventQueue();
      expect(changes, hasLength(1));

      when(
        () => points.redeemReward(
          channelId: any(named: 'channelId'),
          reward: any(named: 'reward'),
          authToken: any(named: 'authToken'),
          userInput: any(named: 'userInput'),
        ),
      ).thenAnswer((_) async => 'NOT_ENOUGH_POINTS');
      await store.redeemReward(
        const PointsReward(
          id: 'auto',
          title: '',
          cost: 100,
          automaticType: 'CHOSEN_SUB_EMOTE_UNLOCK',
        ),
      );
      await pumpEventQueue();
      expect(changes, hasLength(1));
      store.dispose();
    });
  });

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

  void verifyFetches(int times) => verify(
    () => points.fetchContext(
      userLogin: any(named: 'userLogin'),
      authToken: any(named: 'authToken'),
    ),
  ).called(times);

  void verifyNoFetch() => verifyNever(
    () => points.fetchContext(
      userLogin: any(named: 'userLogin'),
      authToken: any(named: 'authToken'),
    ),
  );

  HermesEvent celebrationEvent({
    String channel = '42',
    String type = 'alert_sets_celebration',
    String? id,
  }) => HermesEvent(
    topic: 'celebration-events-v1.$channel',
    type: type,
    data: {'type': 'FIREWORKS', 'alert_event_id': ?id},
  );

  group('points actions', () {
    test('without a token nothing is sent', () async {
      final store = build(tokenProvider: () async => null);

      final result = await store.redeemReward(_reward);

      expect(result.status, PointsActionStatus.notAuthenticated);
      expect(store.pointsActionInFlight, isFalse);
      verifyNever(
        () => points.redeemReward(
          channelId: any(named: 'channelId'),
          reward: any(named: 'reward'),
          authToken: any(named: 'authToken'),
          userInput: any(named: 'userInput'),
        ),
      );
    });

    test('an empty token counts as none, and so does no provider', () async {
      expect(
        (await build(
          tokenProvider: () async => '',
        ).redeemReward(_reward)).status,
        PointsActionStatus.notAuthenticated,
      );
      expect(
        (await build().redeemReward(_reward)).status,
        PointsActionStatus.notAuthenticated,
      );
    });

    test('a success refreshes the balance and frees the controls', () async {
      final store = build(tokenProvider: () async => 'tok');

      final result = await store.redeemReward(_reward, userInput: 'hi');

      expect(result.isSuccess, isTrue);
      expect(store.pointsActionInFlight, isFalse);
      verify(
        () => points.redeemReward(
          channelId: '42',
          reward: _reward,
          authToken: 'tok',
          userInput: 'hi',
        ),
      ).called(1);
      verify(
        () => points.fetchContext(userLogin: 'streamer', authToken: 'tok'),
      ).called(1);
    });

    test('an integrity refusal blocks that action only, no refresh', () async {
      when(
        () => points.redeemReward(
          channelId: any(named: 'channelId'),
          reward: any(named: 'reward'),
          authToken: any(named: 'authToken'),
          userInput: any(named: 'userInput'),
        ),
      ).thenAnswer((_) async => 'failed integrity check');
      final store = build(tokenProvider: () async => 'tok');

      final result = await store.redeemReward(_reward);

      expect(result.status, PointsActionStatus.integrityRefused);
      expect(store.isIntegrityBlocked(redeemAction), isTrue);
      expect(store.isIntegrityBlocked(claimAction), isFalse);
      expect(store.isIntegrityBlocked(predictAction), isFalse);
      verifyNoFetch();
    });

    test('another refusal neither blocks nor refreshes', () async {
      when(
        () => points.redeemReward(
          channelId: any(named: 'channelId'),
          reward: any(named: 'reward'),
          authToken: any(named: 'authToken'),
          userInput: any(named: 'userInput'),
        ),
      ).thenAnswer((_) async => 'NOT_ENOUGH_POINTS');
      final store = build(tokenProvider: () async => 'tok');

      final result = await store.redeemReward(_reward);

      expect(result.status, PointsActionStatus.unknown);
      expect(result.rawCode, 'NOT_ENOUGH_POINTS');
      expect(store.isIntegrityBlocked(redeemAction), isFalse);
      verifyNoFetch();
    });

    test('a request that throws still frees the controls', () async {
      when(
        () => points.redeemReward(
          channelId: any(named: 'channelId'),
          reward: any(named: 'reward'),
          authToken: any(named: 'authToken'),
          userInput: any(named: 'userInput'),
        ),
      ).thenThrow(StateError('boom'));
      final store = build(tokenProvider: () async => 'tok');

      await expectLater(store.redeemReward(_reward), throwsStateError);

      expect(store.pointsActionInFlight, isFalse);
      when(
        () => points.redeemReward(
          channelId: any(named: 'channelId'),
          reward: any(named: 'reward'),
          authToken: any(named: 'authToken'),
          userInput: any(named: 'userInput'),
        ),
      ).thenAnswer((_) async => null);
      expect((await store.redeemReward(_reward)).isSuccess, isTrue);
    });

    test('the flag is up while a request is in flight', () async {
      final reply = Completer<String?>();
      when(
        () => points.redeemReward(
          channelId: any(named: 'channelId'),
          reward: any(named: 'reward'),
          authToken: any(named: 'authToken'),
          userInput: any(named: 'userInput'),
        ),
      ).thenAnswer((_) => reply.future);
      final store = build(tokenProvider: () async => 'tok');

      final redeem = store.redeemReward(_reward);
      expect(store.pointsActionInFlight, isTrue);
      reply.complete(null);
      await redeem;

      expect(store.pointsActionInFlight, isFalse);
    });

    test('no chest on offer: claiming sends nothing', () async {
      final store = build(tokenProvider: () async => 'tok');

      final result = await store.claimBonus();

      expect(result.rawCode, 'no_claim');
      verifyNever(
        () => points.claimBonus(
          channelId: any(named: 'channelId'),
          claimId: any(named: 'claimId'),
          authToken: any(named: 'authToken'),
        ),
      );
    });

    test('a chest on offer is claimed with its id', () async {
      when(
        () => points.fetchContext(
          userLogin: any(named: 'userLogin'),
          authToken: any(named: 'authToken'),
        ),
      ).thenAnswer(
        (_) async => const CommunityPointsContext(availableClaimId: 'chest'),
      );
      final store = build(tokenProvider: () async => 'tok');
      await store.refreshPoints();

      await store.claimBonus();

      verify(
        () => points.claimBonus(
          channelId: '42',
          claimId: 'chest',
          authToken: 'tok',
        ),
      ).called(1);
    });

    test('a bet passes its ids and stake through', () async {
      final store = build(tokenProvider: () async => 'tok');

      await store.placePrediction(eventId: 'e1', outcomeId: 'o2', points: 250);

      verify(
        () => points.makePrediction(
          eventId: 'e1',
          outcomeId: 'o2',
          points: 250,
          authToken: 'tok',
        ),
      ).called(1);
    });

    test('a refresh without a channel login reads nothing', () async {
      final store = build(channelLogin: null, tokenProvider: () async => 'x');

      await store.refreshPoints();

      verifyNoFetch();
    });
  });

  group('connect', () {
    test('subscribes the channel topics, and the viewer ones', () async {
      final store = build(viewerId: '7');

      await store.connect();

      verify(
        () => hermes.subscribeAll([
          ...HermesTopics.forChannel('42'),
          ...HermesTopics.forViewer('7'),
        ]),
      ).called(1);
      store.dispose();
    });

    test('a signed-out viewer only gets the channel topics', () async {
      final store = build();

      await store.connect();

      verify(
        () => hermes.subscribeAll(HermesTopics.forChannel('42')),
      ).called(1);
      store.dispose();
    });

    test('a second connect does nothing', () async {
      final store = build();

      await store.connect();
      await store.connect();

      verify(() => hermes.subscribeAll(any())).called(1);
      verifyFetches(1);
      store.dispose();
    });
  });

  group('routing', () {
    test('a celebration plays; another type or channel does not', () async {
      final store = build();
      await store.connect();

      events
        ..add(celebrationEvent(type: 'something_else'))
        ..add(celebrationEvent(channel: '99'));
      await pumpEventQueue();
      expect(store.celebration, isNull);

      events.add(celebrationEvent());
      await pumpEventQueue();
      expect(store.celebration?.effect, CelebrationEffect.fireworks);

      store.clearCelebration();
      expect(store.celebration, isNull);
      store.dispose();
    });

    test('a creator goal is kept when it is an object', () async {
      final store = build();
      await store.connect();

      events.add(
        const HermesEvent(
          topic: 'creator-goals-events-v1.42',
          type: 'goal_updated',
          data: {
            'goal': {'id': 'g', 'currentContributions': 3},
          },
        ),
      );
      await pumpEventQueue();
      expect(store.creatorGoal, {'id': 'g', 'currentContributions': 3});

      events.add(
        const HermesEvent(
          topic: 'creator-goals-events-v1.42',
          type: 'goal_updated',
          data: {'goal': 'nope'},
        ),
      );
      await pumpEventQueue();
      expect(store.creatorGoal, {'id': 'g', 'currentContributions': 3});
      store.dispose();
    });

    test("the viewer's own topic refreshes the balance", () {
      fakeAsync((async) {
        final store = build(viewerId: '7');
        unawaited(store.connect());
        async.flushMicrotasks();
        verifyFetches(1);

        events.add(
          const HermesEvent(
            topic: 'community-points-user-v1.7',
            type: 'points-earned',
            data: {},
          ),
        );
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 2));

        verifyFetches(1);
        store.dispose();
      });
    });

    test('a burst of points events costs one request', () {
      fakeAsync((async) {
        final store = build();
        unawaited(store.connect());
        async.flushMicrotasks();
        verifyFetches(1);

        for (var i = 0; i < 5; i++) {
          events.add(
            const HermesEvent(
              topic: 'community-points-channel-v1.42',
              type: 'reward-redeemed',
              data: {},
            ),
          );
          async.flushMicrotasks();
          async.elapse(const Duration(milliseconds: 300));
        }
        verifyNoFetch();

        async.elapse(const Duration(seconds: 2));
        verifyFetches(1);

        events.add(
          const HermesEvent(
            topic: 'predictions-channel-v1.42',
            type: 'event-updated',
            data: {},
          ),
        );
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 2));
        verifyFetches(1);
        store.dispose();
      });
    });
  });

  group('celebrations', () {
    test('the same event plays once', () async {
      final store = build();
      await store.connect();

      events.add(celebrationEvent(id: 'gift-1'));
      await pumpEventQueue();
      expect(store.celebration, isNotNull);
      store.clearCelebration();

      events.add(celebrationEvent(id: 'gift-1'));
      await pumpEventQueue();
      expect(store.celebration, isNull);

      // Without an id there is nothing to de-duplicate on.
      events
        ..add(celebrationEvent())
        ..add(celebrationEvent());
      await pumpEventQueue();
      expect(store.celebration, isNotNull);
      store.dispose();
    });

    test('only the last fifty are remembered', () async {
      final store = build();
      await store.connect();

      Future<bool> plays(String id) async {
        store.clearCelebration();
        events.add(celebrationEvent(id: id));
        await pumpEventQueue();
        return store.celebration != null;
      }

      for (var i = 0; i <= 50; i++) {
        expect(await plays('e$i'), isTrue);
      }

      // e0 was evicted by e50; e2 is still remembered.
      expect(await plays('e0'), isTrue);
      expect(await plays('e2'), isFalse);
      store.dispose();
    });

    test('the preview cycles through every effect, then the sizes', () {
      final store = build();
      final seen = <(CelebrationEffect, CelebrationIntensity)>[];

      for (var i = 0; i < 6; i++) {
        store.playPreviewCelebration();
        final celebration = store.celebration!;
        seen.add((celebration.effect, celebration.intensity));
        expect(celebration.eventId, isNull);
      }

      expect(seen.map((e) => e.$1).take(5).toSet(), hasLength(5));
      expect(seen.take(5).map((e) => e.$2).toSet(), {
        CelebrationIntensity.cool,
      });
      expect(seen.last, (
        CelebrationEffect.fireworks,
        CelebrationIntensity.noice,
      ));
    });
  });

  group('polling', () {
    test('a signed-in viewer is polled every minute', () {
      fakeAsync((async) {
        final store = build(tokenProvider: () async => 'tok');
        unawaited(store.connect());
        async.flushMicrotasks();
        verifyFetches(1);

        async.elapse(const Duration(seconds: 59));
        verifyNoFetch();
        async.elapse(const Duration(seconds: 1));
        verifyFetches(1);
        async.elapse(const Duration(minutes: 2));
        verifyFetches(2);
        store.dispose();
      });
    });

    test('a signed-out viewer is not polled', () {
      fakeAsync((async) {
        final store = build(tokenProvider: () async => null);
        unawaited(store.connect());
        async.flushMicrotasks();
        verifyFetches(1);

        async.elapse(const Duration(minutes: 5));
        verifyNoFetch();
        store.dispose();
      });
    });

    test('without a channel login nothing is polled', () {
      fakeAsync((async) {
        final store = build(channelLogin: null, tokenProvider: () async => 't');
        unawaited(store.connect());
        async.elapse(const Duration(minutes: 5));

        verifyNoFetch();
        store.dispose();
      });
    });
  });

  group('lifecycle', () {
    test('pause stops the socket and every timer', () {
      fakeAsync((async) {
        final store = build(tokenProvider: () async => 'tok');
        unawaited(store.connect());
        async.flushMicrotasks();
        verifyFetches(1);

        events.add(
          const HermesEvent(
            topic: 'community-points-channel-v1.42',
            type: 'reward-redeemed',
            data: {},
          ),
        );
        async.flushMicrotasks();
        store.pause();
        async.elapse(const Duration(minutes: 5));

        verify(() => hermes.pause()).called(1);
        verifyNoFetch();
        store.dispose();
      });
    });

    test('resume reconnects, catches up and polls again', () {
      fakeAsync((async) {
        final store = build(tokenProvider: () async => 'tok');
        unawaited(store.connect());
        async.flushMicrotasks();
        store.pause();
        verifyFetches(1);

        unawaited(store.resume());
        async.flushMicrotasks();
        verify(() => hermes.resume()).called(1);
        verifyFetches(1);

        async.elapse(const Duration(seconds: 60));
        verifyFetches(1);
        store.dispose();
      });
    });

    test('resume before connect does nothing', () async {
      final store = build(tokenProvider: () async => 'tok');

      await store.resume();

      verifyNever(() => hermes.resume());
      verifyNoFetch();
    });

    test('dispose closes the client and ignores later events', () async {
      final store = build();
      await store.connect();

      store.dispose();
      events.add(celebrationEvent());
      await pumpEventQueue();

      verify(() => hermes.dispose()).called(1);
      expect(store.celebration, isNull);
    });
  });
}
