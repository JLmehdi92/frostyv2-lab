import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/models/ivs_stats.dart';
import 'package:onset/screens/channel/video/ivs_player_config.dart';
import 'package:onset/screens/channel/video/ivs_stats_panel.dart';
import 'package:onset/screens/channel/video/latency_controller.dart';
import 'package:onset/screens/channel/video/latency_stats.dart';
import 'package:onset/screens/channel/video/stores/ivs_video_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';

class MockIvsVideoStore extends Mock implements IvsVideoStore {}

void main() {
  late MockIvsVideoStore store;

  setUp(() {
    store = MockIvsVideoStore();
    when(() => store.stats).thenReturn(
      IvsStats.fromEvent({'playbackRate': 1.05, 'bufferedMs': 1700}),
    );
    when(() => store.latencySampler).thenReturn(LatencySampler());
    when(() => store.latencyMs).thenReturn(2200);
    when(() => store.samplesVersion).thenReturn(0);
    when(() => store.streamQuality).thenReturn('Auto');
    when(() => store.playerConfig).thenReturn(
      const IvsPlayerConfig(
        catchUp: LiveCatchUpMode.speedUp,
        buffer: BufferProfile.ultra,
        autoLatency: true,
      ),
    );
    when(() => store.startupMs).thenReturn(900);
    when(() => store.rebufferCount).thenReturn(0);
    when(() => store.liveJumps).thenReturn(0);
    when(() => store.autoLatencyStatus).thenReturn(
      const AutoLatencyStatus(
        phase: AutoLatencyPhase.catchingUp,
        rate: 1.05,
        targetMs: 1300,
      ),
    );
    when(() => store.bufferFallbackUntil).thenReturn(null);
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: IvsStatsPanel(store: store)),
    ),
  );

  String rowText(WidgetTester tester, String label) => tester
      .widget<Text>(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.textSpan?.toPlainText() ?? '').startsWith('$label  '),
        ),
      )
      .textSpan!
      .toPlainText();

  testWidgets('shows what auto latency does, its target and the speed', (
    tester,
  ) async {
    await pump(tester);

    expect(rowText(tester, 'Latency'), 'Latency  2.2s');
    expect(
      rowText(tester, 'Auto latency'),
      'Auto latency  catching up 1.05x · target 1.3s',
    );
    expect(rowText(tester, 'Speed'), 'Speed  1.05x');
    expect(rowText(tester, 'Mode'), 'Mode  Auto · Ultra');
    expect(find.textContaining('Next streams'), findsNothing);
  });

  testWidgets('says when the next streams fall back to standard', (
    tester,
  ) async {
    when(
      () => store.bufferFallbackUntil,
    ).thenReturn(DateTime(2026, 10, 30, 21, 40));

    await pump(tester);

    expect(
      rowText(tester, 'Next streams'),
      'Next streams  Standard until 21:40 (Ultra stalled)',
    );
  });

  testWidgets('says off when auto latency is off', (tester) async {
    when(() => store.autoLatencyStatus).thenReturn(null);

    await pump(tester);

    expect(rowText(tester, 'Auto latency'), 'Auto latency  off');
  });
}
