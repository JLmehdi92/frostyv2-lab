import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/widgets/live_indicator.dart';
import 'package:frosty/widgets/motion/signal_ping.dart';

Widget _host(Widget child, {bool disableAnimations = false}) => MaterialApp(
  theme: const FrostyThemes(colorSchemeSeed: FrostyTokens.accent).dark,
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
    expect(_painter(tester).color, FrostyColors.dark.live);
    expect(tester.getSize(find.byType(LiveIndicator)), const Size(10, 10));
  });
}
