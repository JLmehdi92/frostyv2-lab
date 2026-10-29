import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/live_indicator.dart';
import 'package:onset/widgets/motion/signal_ping.dart';

Widget _host(Widget child, {bool disableAnimations = false}) => MaterialApp(
  theme: const OnsetThemes(colorSchemeSeed: OnsetTokens.accent).dark,
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Center(child: child),
  ),
);

SignalPingPainter _painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byType(SignalPing),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!
        as SignalPingPainter;

/// Lets [duration] pass frame by frame (an animation only notices its end
/// on a frame).
Future<void> _advance(WidgetTester tester, Duration duration) async {
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < duration; t += step) {
    await tester.pump(step);
  }
}

void main() {
  tearDown(() {
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
  });

  testWidgets('the ripple grows and fades while the app is in front', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const SignalPing()));
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    final start = _painter(tester).progress.value;
    await tester.pump(const Duration(milliseconds: 600));
    expect(_painter(tester).progress.value, isNot(start));
  });

  testWidgets('ripples in short bursts, then rests with no ticker at all', (
    tester,
  ) async {
    const ping = SignalPing();
    await tester.pumpWidget(_host(ping));
    final burst = ping.period * ping.ripples;
    // The burst: frames all along.
    for (var t = Duration.zero; t < burst; t += ping.period ~/ 4) {
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pump(ping.period ~/ 4);
    }
    await _advance(tester, ping.period ~/ 2);
    // The rest: nothing asks for a frame (Home can sit idle).
    for (
      var t = Duration.zero;
      t < ping.rest;
      t += const Duration(seconds: 1)
    ) {
      expect(tester.binding.transientCallbackCount, 0, reason: 'resting $t');
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
  });

  testWidgets('scrolled out of its list, it does not ripple until it is back', (
    tester,
  ) async {
    const ping = SignalPing();
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          controller: controller,
          slivers: const [
            // A hero card at the top of a feed (kept built when scrolled
            // away, like a tablet's).
            SliverToBoxAdapter(
              child: SizedBox(height: 200, child: Center(child: ping)),
            ),
            SliverToBoxAdapter(child: SizedBox(height: 6000)),
          ],
        ),
      ),
    );
    controller.jumpTo(3000);
    await tester.pump();
    // The burst under way ends; the next one finds it out of view.
    await _advance(tester, ping.period * ping.ripples + ping.rest);
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 3; i++) {
      expect(tester.binding.transientCallbackCount, 0, reason: 'round $i');
      await tester.pump(ping.rest);
      await tester.pump(const Duration(milliseconds: 100));
    }

    controller.jumpTo(0);
    await tester.pump();
    await tester.pump(ping.rest);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    // Torn down mid-rest: no timer left behind.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('stops in the background and resumes in front', (tester) async {
    await tester.pumpWidget(_host(const SignalPing()));
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(tester.binding.transientCallbackCount, greaterThan(0));
  });

  testWidgets('stops off-screen (TickerMode)', (tester) async {
    await tester.pumpWidget(
      _host(const TickerMode(enabled: false, child: SignalPing())),
    );
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('reduce motion: a still dot, no ticker', (tester) async {
    await tester.pumpWidget(_host(const SignalPing(), disableAnimations: true));
    expect(tester.binding.transientCallbackCount, 0);
    expect(_painter(tester).progress.value, 0);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('keeps its size: the ripple paints outside its box', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const SignalPing()));
    expect(tester.getSize(find.byType(SignalPing)), const Size(8, 8));
    // Its repaints stay inside their own layer.
    expect(
      find.descendant(
        of: find.byType(SignalPing),
        matching: find.byType(RepaintBoundary),
      ),
      findsOneWidget,
    );
  });

  testWidgets('LiveIndicator is the signal ping in the live colour', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const LiveIndicator(size: 10)));
    final ping = tester.widget<SignalPing>(find.byType(SignalPing));
    expect(ping.size, 10);
    expect(_painter(tester).color, OnsetColors.dark.live);
    expect(tester.getSize(find.byType(LiveIndicator)), const Size(10, 10));
  });
}
