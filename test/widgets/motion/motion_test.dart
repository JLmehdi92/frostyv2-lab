import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/widgets/motion/haptics.dart';
import 'package:frosty/widgets/motion/motion.dart';
import 'package:frosty/widgets/motion/reduce_motion.dart';

void main() {
  group('motion tokens', () {
    test('standard spring: damping 1.0 over 0.35 s', () {
      final spring = FrostyMotion.springStandard;
      expect(spring.duration, const Duration(milliseconds: 350));
      expect(spring.bounce, closeTo(0, 1e-9));
      expect(spring.mass, 1);
    });

    test('momentum spring: damping 0.8 over 0.4 s', () {
      final spring = FrostyMotion.springMomentum;
      expect(spring.duration, const Duration(milliseconds: 400));
      expect(spring.bounce, closeTo(0.2, 1e-9));
    });

    test('curves match the boards', () {
      expect(FrostyMotion.emphasizedDecelerate, const Cubic(0.05, 0.7, 0.1, 1));
      expect(FrostyMotion.standard, const Cubic(0.2, 0, 0, 1));
      expect(FrostyMotion.emphasizedAccelerate, const Cubic(0.3, 0, 0.8, 0.15));
      // The launch tile's overshoot goes past 1 and settles on it.
      final peak = [
        for (var t = 0.0; t <= 1.0; t += 0.01)
          FrostyMotion.overshoot.transform(t),
      ].reduce((a, b) => a > b ? a : b);
      expect(peak, greaterThan(1.05));
      expect(FrostyMotion.overshoot.transform(1), 1);
    });

    test('press, stagger and reduced-motion values', () {
      expect(FrostyMotion.pressScale, 0.97);
      expect(FrostyMotion.pressDuration, const Duration(milliseconds: 100));
      expect(FrostyMotion.staggerStep, const Duration(milliseconds: 40));
      expect(FrostyMotion.launchStaggerStep, const Duration(milliseconds: 60));
      expect(FrostyMotion.staggerCap, 8);
      expect(FrostyMotion.reducedFade.inMilliseconds, lessThanOrEqualTo(150));
      // Exits are faster than entrances.
      expect(FrostyMotion.exit, lessThan(FrostyMotion.enter));
    });
  });

  group('reduceMotionOf', () {
    Future<bool> probe(WidgetTester tester, {bool disable = false}) async {
      late bool reduced;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: disable),
          child: Builder(
            builder: (context) {
              reduced = reduceMotionOf(context);
              return const SizedBox();
            },
          ),
        ),
      );
      return reduced;
    }

    testWidgets('is off by default', (tester) async {
      expect(await probe(tester), isFalse);
    });

    testWidgets('follows Android "Remove animations"', (tester) async {
      expect(await probe(tester, disable: true), isTrue);
    });

    testWidgets('follows iOS "Reduce Motion"', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      expect(await probe(tester), isTrue);
    });

    testWidgets('motionDuration shortens to a fade when reduced', (
      tester,
    ) async {
      late Duration normal;
      late Duration reduced;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Builder(
            builder: (context) {
              normal = motionDuration(context, FrostyMotion.enter);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              reduced = motionDuration(context, FrostyMotion.enter);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(normal, FrostyMotion.enter);
      expect(reduced, FrostyMotion.reducedFade);
    });
  });

  group('haptics', () {
    late List<String?> calls;

    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'HapticFeedback.vibrate') {
              calls.add(call.arguments as String?);
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    test('map each moment to one predefined effect', () async {
      await Haptics.selection();
      await Haptics.light();
      await Haptics.medium();
      expect(calls, [
        'HapticFeedbackType.selectionClick',
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.mediumImpact',
      ]);
    });
  });
}
