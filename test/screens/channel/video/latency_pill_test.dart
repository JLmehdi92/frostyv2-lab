import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/channel/video/latency_pill.dart';
import 'package:frosty/screens/channel/video/player_controller.dart';
import 'package:frosty/screens/channel/video/stores/ivs_video_store.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fake_player.dart';

class MockIvsVideoStore extends Mock implements IvsVideoStore {}

void main() {
  Future<void> pump(WidgetTester tester, PlayerController store) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: LatencyPill(store: store)),
          ),
        ),
      );

  group('playerLatencyLabel', () {
    test('the latency, or a dash while unknown', () {
      expect(playerLatencyLabel(FakePlayer()), '2.1s');
      expect(playerLatencyLabel(FakePlayer(latency: null)), '—');
    });

    test('the reconnect attempts while the native player recovers', () {
      final ivs = MockIvsVideoStore();
      when(() => ivs.status).thenReturn(IvsPlaybackStatus.reconnecting);
      when(() => ivs.retryAttempt).thenReturn(2);
      when(() => ivs.maxRetryAttempts).thenReturn(5);
      expect(playerLatencyLabel(ivs), '↻ 2/5');

      when(() => ivs.status).thenReturn(IvsPlaybackStatus.playing);
      when(() => ivs.latency).thenReturn('1.9s');
      expect(playerLatencyLabel(ivs), '1.9s');
    });
  });

  testWidgets('follows the latency, 26 dp high (board Chaine)', (tester) async {
    final player = FakePlayer();
    await pump(tester, player);
    expect(find.text('2.1s'), findsOneWidget);
    expect(tester.getSize(find.byType(Container).first).height, 26);
    expect(find.bySemanticsLabel('Latency 2.1s'), findsOneWidget);

    player.latencyText = '3.4s';
    await tester.pump();
    expect(find.text('3.4s'), findsOneWidget);
  });

  testWidgets('a tap opens the IVS video stats', (tester) async {
    final ivs = MockIvsVideoStore();
    when(() => ivs.status).thenReturn(IvsPlaybackStatus.playing);
    when(() => ivs.latency).thenReturn('2.0s');
    await pump(tester, ivs);

    await tester.tap(find.text('2.0s'));
    verify(ivs.toggleStats).called(1);
    expect(find.byTooltip(LatencyPill.tooltipIvs), findsOneWidget);
  });

  testWidgets('other engines only say what it measures', (tester) async {
    await pump(tester, FakePlayer());
    expect(find.byTooltip(LatencyPill.tooltipOther), findsOneWidget);
    await tester.tap(find.text('2.1s'));
    await tester.pump();
  });
}
