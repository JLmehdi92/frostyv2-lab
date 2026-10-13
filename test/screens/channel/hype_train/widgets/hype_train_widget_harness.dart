import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_hype_train_service.dart';
import 'package:frosty/models/hype_train.dart';
import 'package:frosty/models/hype_train_event.dart';
import 'package:frosty/screens/channel/hype_train/stores/hype_train_store.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_slot.dart';
import 'package:frosty/services/realtime/twitch_realtime_client.dart';
import 'package:mocktail/mocktail.dart';

import '../hype_train_test_data.dart';

class MockService extends Mock implements TwitchHypeTrainService {}

class MockRealtime extends Mock implements TwitchRealtimeClient {}

/// A real store on a mocked service and a scripted realtime topic.
class HtHarness {
  HtHarness({HypeTrainSnapshot snapshot = const HtNoTrain(), String? viewer}) {
    when(() => service.getHypeTrain(any())).thenAnswer((_) async => snapshot);
    when(() => realtime.subscribe(any())).thenAnswer(
      (invocation) => RealtimeTopicSubscription.forTesting(
        invocation.positionalArguments.first as String,
        topic.stream,
        () {},
      ),
    );
    store = HypeTrainStore(
      channelId: '42',
      service: service,
      realtime: realtime,
      viewerId: () => viewer,
    );
  }

  final service = MockService();
  final realtime = MockRealtime();
  final topic = StreamController<RealtimeTopicEvent>.broadcast();
  late final HypeTrainStore store;

  void inject(HypeTrainEvent event) => store.injectEvent(event);

  /// Disposes the store and lets the widget tree drop its timers.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    await tester.pump();
  }
}

/// [HypeTrainSlot] in a phone-width app, optionally RTL or with reduced
/// motion and larger text.
Future<void> pumpSlot(
  WidgetTester tester,
  HypeTrainStore store, {
  TextDirection direction = TextDirection.ltr,
  bool reduceMotion = false,
  double textScale = 1,
  double width = 360,
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Directionality(
        textDirection: direction,
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: reduceMotion,
              textScaler: TextScaler.linear(textScale),
            ),
            child: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: width,
                  child: HypeTrainSlot(store: store, onLearnMore: () {}),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  // The snapshot future and the first frame.
  await tester.pump();
  await tester.pump();
}

HypeTrainExecution liveTrain({
  String id = 'train',
  int level = 7,
  int value = 1540,
  int goal = 4700,
  int total = 16040,
  Duration expiresIn = const Duration(seconds: 16),
  HtVariant? variant,
  HtTreasure? treasure,
  HtCommunity? community,
  HtMythic? mythic,
  HtShared? shared,
  HtAthState athState = HtAthState.none,
}) => train(
  id: id,
  level: level,
  value: value,
  goal: goal,
  total: total,
  variant: variant,
  treasure: treasure,
  community: community,
  shared: shared,
  athState: athState,
).copyWith(expiresAt: clock.now().add(expiresIn), mythic: mythic);

HtProgressionEvent htSmall(
  int total, {
  int level = 7,
  int value = 2000,
  bool isLarge = false,
}) => HtProgressionEvent(
  trainId: 'train',
  sequenceId: total,
  displayName: 'Viewer_1',
  action: HtAction(isLarge ? 'TIER_1_GIFTED_SUB' : 'CHEER'),
  source: isLarge ? HtSource.subs : HtSource.bits,
  quantity: isLarge ? 50 : 100,
  isLarge: isLarge,
  progress: progress(level: level, value: value, goal: 4700, total: total),
);

HtLevelUpEvent htLevelUp(int level, {int value = 470, int total = 20000}) =>
    HtLevelUpEvent(
      timeToExpire: clock.now().add(const Duration(minutes: 5)),
      progress: progress(level: level, value: value, goal: 4700, total: total),
    );
