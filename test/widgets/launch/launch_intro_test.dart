import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/widgets/launch/launch_intro.dart';
import 'package:frosty/widgets/launch/onset_mark.dart';
import 'package:frosty/widgets/motion/staggered_entrance.dart';

const _phone = Size(390, 844);
const _tablet = Size(1280, 854);
const _tabletPortrait = Size(854, 1280);
const _card = Key('card');

Duration _at(double fraction) => LaunchIntro.duration * fraction;

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 24);
  addTearDown(tester.view.reset);
}

Widget _app({bool play = true, bool fromTile = false, GlobalKey? slotKey}) =>
    MaterialApp(
      builder: (context, child) => LaunchIntro(
        play: play,
        fromTile: fromTile,
        slotKey: slotKey,
        child: child!,
      ),
      home: Scaffold(
        body: Stack(
          children: [
            const Center(
              child: StaggeredEntrance(
                key: _card,
                index: 0,
                child: Text('home'),
              ),
            ),
            if (slotKey != null)
              Positioned(
                left: 40,
                top: 60,
                child: SizedBox(key: slotKey, width: 24, height: 24),
              ),
          ],
        ),
      ),
    );

Finder get _overlay => find.byKey(LaunchIntro.overlayKey);
Finder get _tile => find.byKey(LaunchIntro.tileKey);

double _cardOpacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find.descendant(
        of: find.byKey(_card),
        matching: find.byType(FadeTransition),
      ),
    )
    .opacity
    .value;

/// Pumps frame by frame up to [fraction] of the intro, from its start.
Future<void> _pumpTo(WidgetTester tester, double fraction) async {
  await tester.pump();
  await tester.pump(_at(fraction));
}

void main() {
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
  });

  group('when it plays', () {
    testWidgets('a cold start: it covers the home, which builds underneath', (
      tester,
    ) async {
      _setSize(tester, _phone);
      await tester.pumpWidget(_app());
      expect(_overlay, findsOneWidget);
      // The home is built (and loads its data) from the first frame.
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('a warm start: no intro', (tester) async {
      _setSize(tester, _phone);
      await tester.pumpWidget(_app(play: false));
      expect(_overlay, findsNothing);
      expect(_cardOpacity(tester), 0); // The card enters normally.
      await tester.pumpAndSettle();
      expect(_cardOpacity(tester), 1);
    });

    testWidgets('Android "Remove animations": no intro', (tester) async {
      _setSize(tester, _phone);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      await tester.pumpWidget(_app());
      expect(_overlay, findsNothing);
    });

    testWidgets('iOS "Reduce Motion": no intro', (tester) async {
      _setSize(tester, _phone);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(reduceMotion: true);
      await tester.pumpWidget(_app());
      expect(_overlay, findsNothing);
    });

    testWidgets('a screen reader: no intro', (tester) async {
      _setSize(tester, _phone);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      await tester.pumpWidget(_app());
      expect(_overlay, findsNothing);
    });
  });

  group('the sequence', () {
    testWidgets('lasts 1.4 s, then nothing is left running', (tester) async {
      _setSize(tester, _phone);
      await tester.pumpWidget(_app());
      expect(LaunchIntro.duration, const Duration(milliseconds: 1400));

      await _pumpTo(tester, 0.99);
      expect(_overlay, findsOneWidget);
      await tester.pump(_at(0.02));
      await tester.pump();
      expect(_overlay, findsNothing);
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('the dot grows into the tile, past its size, then settles', (
      tester,
    ) async {
      _setSize(tester, _phone);
      await tester.pumpWidget(_app());
      await tester.pump();
      expect(tester.getRect(_tile).width, closeTo(0, 0.01));

      await tester.pump(_at(0.08));
      // The signal: a small dot (0.2 of the tile).
      expect(tester.getRect(_tile).width, closeTo(72 * 0.2, 1));

      var widest = 0.0;
      for (var t = 0.09; t <= 0.26; t += 0.01) {
        await tester.pump(_at(0.01));
        final width = tester.getRect(_tile).width;
        if (width > widest) widest = width;
      }
      expect(widest, greaterThan(74)); // overshoot
      await tester.pump(_at(0.02));
      expect(tester.getRect(_tile).width, closeTo(72, 0.5));
      expect(tester.getCenter(_tile), const Offset(195, 422));
    });

    testWidgets('then the rings, and the name letter by letter', (
      tester,
    ) async {
      _setSize(tester, _phone);
      await tester.pumpWidget(_app());
      await _pumpTo(tester, 0.36);
      expect(find.byKey(LaunchIntro.ringKeys[0]), findsOneWidget);
      expect(find.byKey(LaunchIntro.ringKeys[1]), findsOneWidget);

      for (final letter in ['O', 'N', 'S', 'E', 'T']) {
        expect(find.text(letter), findsOneWidget);
      }
      double alpha(String letter) =>
          tester.widget<Text>(find.text(letter)).style!.color!.a;
      // O leads, T follows.
      expect(alpha('O'), greaterThan(alpha('T')));
      expect(tester.widget<Text>(find.text('O')).style!.fontSize, 34);

      await _pumpTo(tester, 0.2);
      expect(alpha('O'), closeTo(1, 0.01));
      expect(alpha('T'), closeTo(1, 0.01));
    });

    testWidgets('the tile flies to the header slot', (tester) async {
      _setSize(tester, _phone);
      await tester.pumpWidget(_app());
      await _pumpTo(tester, 0.79);
      final rect = tester.getRect(_tile);
      expect(rect.left, closeTo(16, 0.5));
      expect(rect.top, closeTo(24 + 14, 0.5));
      expect(rect.width, closeTo(28, 0.5));
    });

    testWidgets('…or to the real header mark when there is one', (
      tester,
    ) async {
      _setSize(tester, _phone);
      final slotKey = GlobalKey();
      await tester.pumpWidget(_app(slotKey: slotKey));
      await _pumpTo(tester, 0.79);
      final rect = tester.getRect(_tile);
      expect(rect.left, closeTo(40, 0.5));
      expect(rect.top, closeTo(60, 0.5));
      expect(rect.width, closeTo(24, 0.5));
    });

    testWidgets('the home cards enter as the intro uncovers them', (
      tester,
    ) async {
      _setSize(tester, _phone);
      await tester.pumpWidget(_app());
      await _pumpTo(tester, 0.6);
      expect(_cardOpacity(tester), 0);

      await tester.pump(_at(0.15));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_cardOpacity(tester), greaterThan(0));
      await tester.pumpAndSettle();
      expect(_cardOpacity(tester), 1);
    });

    testWidgets('from the native splash tile, Android: no dot, no jump', (
      tester,
    ) async {
      _setSize(tester, _phone);
      await tester.pumpWidget(_app(fromTile: true));
      // The very first frame is the splash's: the full tile, its "ON" shown.
      expect(tester.getRect(_tile).width, closeTo(72, 0.01));
      expect(tester.getCenter(_tile), const Offset(195, 422));
      final mark = tester.widget<OnsetMarkTile>(find.byType(OnsetMarkTile));
      expect(mark.markOpacity, 1);
      expect(mark.markScale, 1);

      // And it is shorter: it starts where the splash left off.
      await tester.pump();
      await tester.pump(_at(0.75));
      await tester.pump();
      expect(_overlay, findsNothing);
    });

    testWidgets('never blurs: gradients and fills only', (tester) async {
      _setSize(tester, _phone);
      await tester.pumpWidget(_app());
      for (var t = 0.0; t < 1; t += 0.1) {
        await tester.pump(_at(0.1));
        expect(find.byType(BackdropFilter), findsNothing);
      }
    });
  });

  group('cut short', () {
    testWidgets('a tap ends it at once', (tester) async {
      _setSize(tester, _phone);
      await tester.pumpWidget(_app());
      await _pumpTo(tester, 0.3);
      await tester.tapAt(const Offset(195, 700));
      await tester.pump();
      expect(_overlay, findsNothing);
      await tester.pumpAndSettle();
      expect(_cardOpacity(tester), 1);
    });

    testWidgets('a deep link ends it (skipAll)', (tester) async {
      _setSize(tester, _phone);
      await tester.pumpWidget(_app());
      await _pumpTo(tester, 0.3);
      LaunchIntro.skipAll();
      await tester.pump();
      expect(_overlay, findsNothing);
    });

    testWidgets('going to the background ends it', (tester) async {
      _setSize(tester, _phone);
      await tester.pumpWidget(_app());
      await _pumpTo(tester, 0.3);
      // Leaving goes through inactive first (a system dialog does too).
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(_overlay, findsNothing);
    });
  });

  group('phone and tablet', () {
    for (final (name, size, letterSize, slot) in [
      ('phone', _phone, 34.0, const Rect.fromLTWH(16, 24 + 14, 28, 28)),
      ('tablet', _tablet, 40.0, const Rect.fromLTWH(28, 24 + 21, 30, 30)),
      (
        'tablet portrait',
        _tabletPortrait,
        40.0,
        const Rect.fromLTWH(28, 24 + 21, 30, 30),
      ),
    ]) {
      testWidgets('$name: centred, laid out without overflow', (tester) async {
        _setSize(tester, size);
        await tester.pumpWidget(_app());
        await tester.pump();
        for (var t = 0.0; t < 0.79; t += 0.05) {
          await tester.pump(_at(0.05));
          expect(tester.takeException(), isNull);
          if ((t - 0.30).abs() < 0.03) {
            expect(tester.getCenter(_tile), size.center(Offset.zero));
            expect(
              tester.widget<Text>(find.text('S')).style!.fontSize,
              letterSize,
            );
          }
        }
        final rect = tester.getRect(_tile);
        expect(rect.left, closeTo(slot.left, 0.5));
        expect(rect.top, closeTo(slot.top, 0.5));
        expect(rect.width, closeTo(slot.width, 0.5));
        await tester.pumpAndSettle();
        expect(_overlay, findsNothing);
      });
    }
  });
}
