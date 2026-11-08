import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_points_service.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/apis/twitch_watch_streak_service.dart';
import 'package:onset/models/community_points.dart';
import 'package:onset/models/watch_streak.dart';
import 'package:onset/screens/channel/stores/channel_events_store.dart';
import 'package:onset/services/hermes_client.dart';

class MockPointsService extends Mock implements TwitchPointsService {}

class MockHermesClient extends Mock implements HermesClient {}

class MockWatchStreakService extends Mock implements TwitchWatchStreakService {}

class MockViewerActions extends Mock implements TwitchViewerActionsService {}

void main() {
  late MockPointsService points;
  late MockHermesClient hermes;
  late MockWatchStreakService streaks;
  late StreamController<HermesEvent> events;

  setUp(() {
    points = MockPointsService();
    hermes = MockHermesClient();
    streaks = MockWatchStreakService();
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
  });

  tearDown(() => events.close());

  ChannelEventsStore build({String? token = 'webtok'}) => ChannelEventsStore(
    channelId: '42',
    channelLogin: 'streamer',
    client: hermes,
    pointsService: points,
    watchStreakService: streaks,
    tokenProvider: () async => token,
  );

  Future<WatchStreak?> asked() => streaks.getWatchStreak(
    channelId: any(named: 'channelId'),
    authToken: any(named: 'authToken'),
  );

  void verifyAsked(int times) =>
      times == 0 ? verifyNever(asked) : verify(asked).called(times);

  test('connecting reads the streak with the web token', () async {
    final store = build();
    await store.connect();
    await pumpEventQueue();

    expect(store.watchStreak!.value, 3);
    verify(
      () => streaks.getWatchStreak(channelId: '42', authToken: 'webtok'),
    ).called(1);
    store.dispose();
  });

  test('signed out, nothing is asked', () async {
    final store = build(token: null);
    await store.refreshWatchStreak();

    expect(store.watchStreak, isNull);
    verifyAsked(0);
  });

  test('opening the panel again soon does not ask again', () {
    fakeAsync((async) {
      final store = build();
      unawaited(store.refreshWatchStreak());
      async.flushMicrotasks();
      unawaited(store.refreshWatchStreak());
      async.flushMicrotasks();
      verifyAsked(1);

      // A minute later the panel shows a fresh count.
      async.elapse(const Duration(minutes: 2));
      unawaited(store.refreshWatchStreak());
      async.flushMicrotasks();
      verifyAsked(1);
    });
  });

  test('a failure hides the streak and waits before asking again', () {
    when(
      () => streaks.getWatchStreak(
        channelId: any(named: 'channelId'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer((_) async => null);
    fakeAsync((async) {
      final store = build();
      unawaited(store.refreshWatchStreak());
      async.flushMicrotasks();
      expect(store.watchStreak, isNull);
      verifyAsked(1);

      async.elapse(const Duration(minutes: 5));
      unawaited(store.refreshWatchStreak());
      async.flushMicrotasks();
      verifyAsked(0);

      async.elapse(const Duration(minutes: 6));
      unawaited(store.refreshWatchStreak());
      async.flushMicrotasks();
      verifyAsked(1);
    });
  });

  test('without the service, nothing is asked', () async {
    final store = ChannelEventsStore(
      channelId: '42',
      channelLogin: 'streamer',
      client: hermes,
      pointsService: points,
      tokenProvider: () async => 'webtok',
    );
    await store.refreshWatchStreak();

    expect(store.watchStreak, isNull);
  });

  group('sharing the streak in chat', () {
    late MockViewerActions actions;

    setUp(() {
      actions = MockViewerActions();
      when(
        () => streaks.getWatchStreak(
          channelId: any(named: 'channelId'),
          authToken: any(named: 'authToken'),
        ),
      ).thenAnswer(
        (_) async =>
            const WatchStreak(value: 5, milestoneId: 'm1', canShare: true),
      );
    });

    ChannelEventsStore sharing({String? token = 'webtok'}) =>
        ChannelEventsStore(
          channelId: '42',
          channelLogin: 'streamer',
          client: hermes,
          pointsService: points,
          watchStreakService: streaks,
          viewerActionsService: actions,
          tokenProvider: () async => token,
        );

    test('a share sends the milestone once and hides the offer', () async {
      when(
        () => actions.shareWatchStreak(
          channelId: '42',
          milestoneId: 'm1',
          authToken: 'webtok',
        ),
      ).thenAnswer((_) async => ViewerActionOutcome.done);
      final store = sharing();
      await store.refreshWatchStreak();
      expect(store.canShareWatchStreak, isTrue);

      expect(await store.shareWatchStreak(), ViewerActionOutcome.done);
      expect(store.watchStreak!.canShare, isFalse);
      expect(store.canShareWatchStreak, isFalse);
      expect(await store.shareWatchStreak(), isNull);
      verify(
        () => actions.shareWatchStreak(
          channelId: '42',
          milestoneId: 'm1',
          authToken: 'webtok',
        ),
      ).called(1);
    });

    test('a refusal keeps the offer', () async {
      when(
        () => actions.shareWatchStreak(
          channelId: any(named: 'channelId'),
          milestoneId: any(named: 'milestoneId'),
          authToken: any(named: 'authToken'),
        ),
      ).thenAnswer((_) async => ViewerActionOutcome.refused);
      final store = sharing();
      await store.refreshWatchStreak();

      expect(await store.shareWatchStreak(), ViewerActionOutcome.refused);
      expect(store.watchStreak!.canShare, isTrue);
    });

    test('without the actions service nothing is offered', () async {
      final store = build();
      await store.refreshWatchStreak();
      expect(store.canShareWatchStreak, isFalse);
      expect(await store.shareWatchStreak(), isNull);
    });
  });

  test('a suspended streak read running again says recovered', () {
    final answers = [
      const WatchStreak(value: 6, state: WatchStreakState.suspended),
      const WatchStreak(value: 7),
    ];
    when(
      () => streaks.getWatchStreak(
        channelId: any(named: 'channelId'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer((_) async => answers.removeAt(0));
    fakeAsync((async) {
      final store = build();
      final changes = <WatchStreakChange>[];
      store.watchStreakChanges.listen(changes.add);
      unawaited(store.refreshWatchStreak());
      async.flushMicrotasks();
      expect(changes, isEmpty);

      async.elapse(const Duration(minutes: 2));
      unawaited(store.refreshWatchStreak());
      async.flushMicrotasks();
      expect(changes, [WatchStreakChange.recovered]);
    });
  });

  test('a suspended streak read as none says expired', () {
    final answers = [
      const WatchStreak(value: 6, state: WatchStreakState.suspended),
      const WatchStreak(value: 0, state: WatchStreakState.none),
    ];
    when(
      () => streaks.getWatchStreak(
        channelId: any(named: 'channelId'),
        authToken: any(named: 'authToken'),
      ),
    ).thenAnswer((_) async => answers.removeAt(0));
    fakeAsync((async) {
      final store = build();
      final changes = <WatchStreakChange>[];
      store.watchStreakChanges.listen(changes.add);
      unawaited(store.refreshWatchStreak());
      async.flushMicrotasks();
      async.elapse(const Duration(minutes: 2));
      unawaited(store.refreshWatchStreak());
      async.flushMicrotasks();
      expect(changes, [WatchStreakChange.expired]);
    });
  });
}
