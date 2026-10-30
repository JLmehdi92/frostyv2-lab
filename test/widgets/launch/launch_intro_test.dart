import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/widgets/launch/launch_intro.dart';
import 'package:onset/widgets/launch/onset_mark.dart';
import 'package:onset/widgets/motion/staggered_entrance.dart';

const _phone = Size(390, 844);
const _tablet = Size(1280, 854);
const _tabletPortrait = Size(854, 1280);
const _card = Key('card');
var _homeTaps = 0;

Duration _at(double fraction) => LaunchIntro.duration * fraction;

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 24);
  addTearDown(tester.view.reset);
}

Widget _app({
  bool play = true,
  bool fromTile = false,
  bool holdOnName = false,
  GlobalKey? slotKey,
  bool slotIsMark = false,
  ValueNotifier<Rect?>? splashTile,
  GlobalKey<NavigatorState>? navigatorKey,
}) => MaterialApp(
  navigatorKey: navigatorKey,
  navigatorObservers: [LaunchIntro.navigatorObserver],
  builder: (context, child) => LaunchIntro(
    play: play,
    fromTile: fromTile,
    holdOnName: holdOnName,
    slotKey: slotKey,
    splashTile: splashTile,
    child: child!,
  ),
  home: Scaffold(
    body: Stack(
      children: [
        const Center(
          child: StaggeredEntrance(key: _card, index: 0, child: Text('home')),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 40,
          height: 80,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _homeTaps++,
          ),
        ),
        if (slotKey != null)
          Positioned(
            left: 40,
            top: 60,
            child: slotIsMark
                ? OnsetMarkTile(key: slotKey, size: 24, radius: 6)
                : SizedBox(key: slotKey, width: 24, height: 24),
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
  setUp(() => _homeTaps = 0);

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

    testWidgets('it says it runs while it covers, then not', (tester) async {
      _setSize(tester, _phone);
      expect(LaunchIntro.running.value, isFalse);
      await tester.pumpWidget(_app());
      expect(LaunchIntro.running.value, isTrue);
      await tester.pump();
      await tester.pump(LaunchIntro.duration + const Duration(seconds: 1));
      expect(LaunchIntro.running.value, isFalse);
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
      // The very first frame is the splash's: the full tile, its icon shown.
      expect(tester.getRect(_tile).width, closeTo(72, 0.01));
      expect(tester.getCenter(_tile), const Offset(195, 422));
      final mark = tester.widget<OnsetMarkTile>(find.byType(OnsetMarkTile));
      expect(mark.markOpacity, 1);
      expect(mark.markScale, 1);
      // The splash's bitmap: the icon, whole, with the splash's 20 dp
      // corners.
      expect(mark.radius, 20);
      final image = tester.widget<Image>(
        find.descendant(of: _tile, matching: find.byType(Image)),
      );
      expect(
        (image.image as ExactAssetImage).assetName,
        // The 1.0x variant at this test's pixel ratio of 1.
        'assets/icons/onset_logo_72.png',
      );
      expect(image.opacity, isNull);

      // And it is shorter: it starts where the splash left off.
      await tester.pump();
      await tester.pump(_at(0.75));
      await tester.pump();
      expect(_overlay, findsNothing);
    });

    testWidgets('from the dot: the icon\'s ground grows, then the icon '
        'comes in', (tester) async {
      _setSize(tester, _phone);
      await tester.pumpWidget(_app());
      Finder image() =>
          find.descendant(of: _tile, matching: find.byType(Image));
      final dot = tester.widget<OnsetMarkTile>(
        find.descendant(of: _tile, matching: find.byType(OnsetMarkTile)),
      );
      expect(dot.markOpacity, 0);
      expect(image(), findsNothing);
      await _pumpTo(tester, 0.24);
      final fading = tester.widget<Image>(image());
      expect(fading.opacity!.value, inExclusiveRange(0, 1));
      await tester.pump(_at(0.1));
      expect(tester.widget<Image>(image()).opacity, isNull);
    });

    testWidgets('lands with the header mark\'s own size and corners', (
      tester,
    ) async {
      _setSize(tester, _phone);
      final slot = GlobalKey();
      await tester.pumpWidget(_app(slotKey: slot, slotIsMark: true));
      await _pumpTo(tester, 0.8);
      final rect = tester.getRect(_tile);
      expect(rect, rectMoreOrLessEquals(const Rect.fromLTWH(40, 60, 24, 24)));
      final flying = tester.widget<OnsetMarkTile>(
        find.descendant(of: _tile, matching: find.byType(OnsetMarkTile)),
      );
      expect(flying.radius! * rect.width / 72, closeTo(6, 0.01));
      await tester.pumpAndSettle();
      expect(_overlay, findsNothing);
    });

    testWidgets('a slot that is not a mark keeps its corners', (tester) async {
      _setSize(tester, _phone);
      final slot = GlobalKey();
      await tester.pumpWidget(_app(slotKey: slot));
      await _pumpTo(tester, 0.8);
      final flying = tester.widget<OnsetMarkTile>(
        find.descendant(of: _tile, matching: find.byType(OnsetMarkTile)),
      );
      expect(flying.radius, 20);
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

  group('handing over', () {
    testWidgets('the tile starts exactly where the Android splash drew it', (
      tester,
    ) async {
      _setSize(tester, _phone);
      // A Flutter view stopping above a 48 dp navigation bar: the splash,
      // centred on the whole window, sits 24 dp lower; and this device drew
      // the icon smaller.
      final splash = ValueNotifier<Rect?>(null);
      addTearDown(splash.dispose);
      await tester.pumpWidget(_app(fromTile: true, splashTile: splash));
      splash.value = Rect.fromCenter(
        center: const Offset(195, 446),
        width: 60,
        height: 60,
      );
      await tester.pump();
      final rect = tester.getRect(_tile);
      expect(rect.center.dx, closeTo(195, 0.01));
      expect(rect.center.dy, closeTo(446, 0.01));
      expect(rect.width, closeTo(60, 0.01));
      // The rings leave from it.
      await tester.pump(_at(0.05));
      expect(
        tester.getCenter(find.byKey(LaunchIntro.ringKeys[0])),
        const Offset(195, 446),
      );
      // And it still lands in the header slot.
      await tester.pump(_at(0.5));
      expect(tester.getRect(_tile).width, closeTo(28, 0.5));
    });

    testWidgets('once the app shows through, taps go to it', (tester) async {
      _setSize(tester, _phone);
      await tester.pumpWidget(_app());
      await _pumpTo(tester, 0.3);
      // Covering: a tap only skips.
      await tester.tapAt(const Offset(195, 770));
      expect(_homeTaps, 0);

      await tester.pumpWidget(Container());
      await tester.pumpWidget(_app());
      await _pumpTo(tester, 0.72);
      expect(_overlay, findsOneWidget);
      await tester.tapAt(const Offset(195, 770));
      expect(_homeTaps, 1);
    });

    testWidgets('light status bar over the ground, then the app\'s own', (
      tester,
    ) async {
      _setSize(tester, _phone);
      Finder region() => find.descendant(
        of: _overlay,
        matching: find.byWidgetPredicate(
          (w) => w is AnnotatedRegion<SystemUiOverlayStyle>,
        ),
      );
      await tester.pumpWidget(_app());
      await _pumpTo(tester, 0.3);
      expect(
        tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(region()).value,
        SystemUiOverlayStyle.light,
      );
      await tester.pump(_at(0.5));
      expect(_overlay, findsOneWidget);
      expect(region(), findsNothing);
    });

    testWidgets('a page opening over the home ends it', (tester) async {
      _setSize(tester, _phone);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(navigatorKey: navigator));
      await _pumpTo(tester, 0.3);
      expect(_overlay, findsOneWidget);
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Text('page')),
      );
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

  group('first run: it holds on the name for the onboarding', () {
    testWidgets('no flight: it ends once the name is drawn, on black', (
      tester,
    ) async {
      _setSize(tester, _phone);
      await tester.pumpWidget(_app(holdOnName: true));
      await _pumpTo(tester, 0.5);
      expect(_overlay, findsOneWidget);
      // Still in the middle, at full size: it never leaves for the header.
      expect(tester.getCenter(_tile), const Offset(195, 422));
      expect(tester.getRect(_tile).width, closeTo(72, 0.5));
      await tester.pump(_at(0.1));
      await tester.pump();
      expect(_overlay, findsNothing);
      expect(LaunchIntro.running.value, isFalse);
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('it tells where the tile rests', (tester) async {
      _setSize(tester, _phone);
      final splash = ValueNotifier<Rect?>(null);
      addTearDown(splash.dispose);
      await tester.pumpWidget(
        _app(holdOnName: true, fromTile: true, splashTile: splash),
      );
      splash.value = Rect.fromCenter(
        center: const Offset(195, 446),
        width: 60,
        height: 60,
      );
      await tester.pump();
      await tester.pump(_at(0.4));
      await tester.pump();
      expect(_overlay, findsNothing);
      expect(
        LaunchIntro.restingTile.value,
        Rect.fromCenter(center: const Offset(195, 446), width: 60, height: 60),
      );
    });
  });

  group('landing: the end of the intro, played again', () {
    testWidgets('covers, swaps the page, then flies into the header', (
      tester,
    ) async {
      _setSize(tester, _phone);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(play: false, navigatorKey: navigator));
      await tester.pumpAndSettle();
      var covered = 0;
      final played = LaunchIntro.land(
        from: Rect.fromCenter(
          center: const Offset(195, 422),
          width: 72,
          height: 72,
        ),
        onCovered: () {
          covered++;
          // The caller swaps the page under the ground: that push does not
          // end the landing.
          navigator.currentState!.push(
            PageRouteBuilder<void>(
              transitionDuration: Duration.zero,
              pageBuilder: (_, _, _) => const Text('next'),
            ),
          );
        },
      );
      expect(played, isTrue);
      expect(LaunchIntro.running.value, isTrue);
      expect(LaunchIntro.landing.value, isTrue);
      await tester.pump();
      expect(_overlay, findsOneWidget);
      expect(covered, 0);
      await tester.pump(LaunchIntro.landingDuration * 0.25);
      expect(covered, 1);
      await tester.pump();
      expect(find.text('next'), findsOneWidget);
      expect(_overlay, findsOneWidget);
      await tester.pump(LaunchIntro.landingDuration * 0.55);
      final rect = tester.getRect(_tile);
      expect(rect.left, closeTo(16, 0.5));
      expect(rect.top, closeTo(24 + 14, 0.5));
      await tester.pumpAndSettle();
      expect(_overlay, findsNothing);
      expect(covered, 1);
      expect(LaunchIntro.running.value, isFalse);
      expect(LaunchIntro.landing.value, isFalse);
    });

    testWidgets('lands on the header mark with its corners', (tester) async {
      _setSize(tester, _phone);
      final slot = GlobalKey();
      await tester.pumpWidget(
        _app(play: false, slotKey: slot, slotIsMark: true),
      );
      await tester.pumpAndSettle();
      LaunchIntro.land(
        from: Rect.fromCenter(
          center: const Offset(195, 422),
          width: 72,
          height: 72,
        ),
        onCovered: () {},
      );
      await tester.pump();
      final start = tester.widget<OnsetMarkTile>(
        find.descendant(of: _tile, matching: find.byType(OnsetMarkTile)),
      );
      expect(start.radius, 20);
      await tester.pump(LaunchIntro.landingDuration * 0.8);
      final rect = tester.getRect(_tile);
      expect(rect, rectMoreOrLessEquals(const Rect.fromLTWH(40, 60, 24, 24)));
      final flying = tester.widget<OnsetMarkTile>(
        find.descendant(of: _tile, matching: find.byType(OnsetMarkTile)),
      );
      expect(flying.radius! * rect.width / 72, closeTo(6, 0.01));
      await tester.pumpAndSettle();
      expect(_overlay, findsNothing);
    });

    testWidgets('holds the next page\'s entrances until it uncovers them', (
      tester,
    ) async {
      _setSize(tester, _phone);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(play: false, navigatorKey: navigator));
      await tester.pumpAndSettle();
      LaunchIntro.land(
        from: Rect.fromCenter(
          center: const Offset(195, 422),
          width: 72,
          height: 72,
        ),
        onCovered: () => navigator.currentState!.pushAndRemoveUntil(
          PageRouteBuilder<void>(
            transitionDuration: Duration.zero,
            pageBuilder: (_, _, _) => const Center(
              child: StaggeredEntrance(
                key: Key('next-card'),
                index: 0,
                child: Text('next'),
              ),
            ),
          ),
          (_) => false,
        ),
      );
      await tester.pump();
      await tester.pump(LaunchIntro.landingDuration * 0.3);
      await tester.pump();
      double opacity() => tester
          .widget<FadeTransition>(
            find.descendant(
              of: find.byKey(const Key('next-card')),
              matching: find.byType(FadeTransition),
            ),
          )
          .opacity
          .value;
      expect(opacity(), 0);
      await tester.pumpAndSettle();
      expect(opacity(), 1);
    });

    testWidgets('a tap before the swap still swaps the page', (tester) async {
      _setSize(tester, _phone);
      await tester.pumpWidget(_app(play: false));
      await tester.pumpAndSettle();
      var covered = 0;
      LaunchIntro.land(
        from: Rect.fromCenter(
          center: const Offset(195, 422),
          width: 72,
          height: 72,
        ),
        onCovered: () => covered++,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(195, 300));
      await tester.pump();
      expect(covered, 1);
      expect(_overlay, findsNothing);
      await tester.pumpAndSettle();
      expect(covered, 1);
    });

    testWidgets('reduce motion: it does not play, the caller navigates', (
      tester,
    ) async {
      _setSize(tester, _phone);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      await tester.pumpWidget(_app(play: false));
      await tester.pumpAndSettle();
      var covered = 0;
      expect(
        LaunchIntro.land(
          from: Rect.fromCenter(
            center: const Offset(195, 422),
            width: 72,
            height: 72,
          ),
          onCovered: () => covered++,
        ),
        isFalse,
      );
      await tester.pump();
      expect(_overlay, findsNothing);
      expect(covered, 0);
    });

    testWidgets('no intro mounted: it does not play', (tester) async {
      _setSize(tester, _phone);
      await tester.pumpWidget(const MaterialApp(home: Text('x')));
      expect(LaunchIntro.land(from: Rect.zero, onCovered: () {}), isFalse);
    });

    testWidgets('tablet: from where the tile is, no pop-in', (tester) async {
      _setSize(tester, _tablet);
      await tester.pumpWidget(_app(play: false));
      await tester.pumpAndSettle();
      LaunchIntro.land(
        from: Rect.fromCenter(
          center: const Offset(280, 427),
          width: 72,
          height: 72,
        ),
        appear: false,
        onCovered: () {},
      );
      await tester.pump();
      expect(tester.getCenter(_tile), const Offset(280, 427));
      expect(tester.getRect(_tile).width, closeTo(72, 0.5));
      // It does not leave before the page with the header is in.
      await tester.pump(LaunchIntro.landingFromTileDuration * 0.22);
      expect(tester.getCenter(_tile), const Offset(280, 427));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 70));
        expect(find.byType(BackdropFilter), findsNothing);
      }
      await tester.pumpAndSettle();
      expect(_overlay, findsNothing);
    });
  });

  testWidgets('landing: torn down before the swap, it still swaps once', (
    tester,
  ) async {
    _setSize(tester, _phone);
    await tester.pumpWidget(_app(play: false));
    await tester.pumpAndSettle();
    var covered = 0;
    LaunchIntro.land(
      from: Rect.fromCenter(
        center: const Offset(195, 422),
        width: 72,
        height: 72,
      ),
      onCovered: () => covered++,
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    expect(LaunchIntro.landing.value, isFalse);
    await tester.pump();
    expect(covered, 1);
    expect(LaunchIntro.running.value, isFalse);
  });

  testWidgets('landing: a page opening before the swap ends it, and the '
      'swap follows after that push, once', (tester) async {
    _setSize(tester, _phone);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_app(play: false, navigatorKey: navigator));
    await tester.pumpAndSettle();
    var covered = 0;
    LaunchIntro.land(
      from: Rect.fromCenter(
        center: const Offset(195, 422),
        width: 72,
        height: 72,
      ),
      onCovered: () {
        covered++;
        navigator.currentState!.push(
          PageRouteBuilder<void>(
            transitionDuration: Duration.zero,
            pageBuilder: (_, _, _) => const Text('next'),
          ),
        );
      },
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    // A link opens a page: the landing ends, but the swap must not push
    // from inside that push.
    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Text('link')),
    );
    expect(covered, 0);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(covered, 1);
    expect(find.byKey(LaunchIntro.overlayKey), findsNothing);
    await tester.pumpAndSettle();
    expect(covered, 1);
  });
}
