import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_points_service.dart';
import 'package:onset/apis/twitch_watch_streak_service.dart';
import 'package:onset/models/community_points.dart';
import 'package:onset/models/watch_streak.dart';
import 'package:onset/screens/channel/stores/channel_events_store.dart';
import 'package:onset/services/hermes_client.dart';

class MockPointsService extends Mock implements TwitchPointsService {}

class MockHermesClient extends Mock implements HermesClient {}

class MockWatchStreakService extends Mock implements TwitchWatchStreakService {}

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
}
