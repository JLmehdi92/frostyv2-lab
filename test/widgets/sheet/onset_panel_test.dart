import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/sheet/onset_panel.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';

import '../../helpers/live_curves.dart';

void main() {
  // The board ChaineOutilsTablette: 1280 × 854, the video 880 × 495 at the
  // top left, the chat column from 880.
  const screen = Rect.fromLTWH(0, 0, 1280, 854);
  const video = Rect.fromLTWH(0, 0, 880, 495);
  const chat = Rect.fromLTWH(880, 0, 400, 854);

  group('placePanel', () {
    test('the points sit above their pill, inside the chat column', () {
      final placement = placePanel(
        bounds: screen,
        // The 44 dp points pill at the end of the input row.
        anchor: const Rect.fromLTWH(1186, 794, 80, 44),
        size: const Size(384, 562),
        sides: const [PanelSide.above],
        region: chat,
        avoid: video,
        gap: 18,
      )!;
      expect(placement.side, PanelSide.above);
      // Board: left 884, top 214, the nub under the pill.
      expect(placement.rect, const Rect.fromLTWH(884, 214, 384, 562));
      expect(placement.nub, closeTo(1226 - 884, 0.01));
    });

    test('the emote menu sits above the input, in the column', () {
      final placement = placePanel(
        bounds: screen,
        anchor: const Rect.fromLTWH(896, 794, 36, 44),
        size: const Size(376, 372),
        sides: const [PanelSide.above],
        region: chat,
        avoid: video,
        gap: 18,
      )!;
      // Board: left 892, top 404.
      expect(placement.rect, const Rect.fromLTWH(892, 404, 376, 372));
      expect(placement.nub, 22);
    });

    test('the user card goes beside the chat, under the video', () {
      final placement = placePanel(
        bounds: screen,
        // A message near the bottom of the chat column.
        anchor: const Rect.fromLTWH(880, 650, 400, 26),
        size: const Size(384, 344),
        sides: const [PanelSide.left, PanelSide.above],
        region: chat,
        avoid: video,
      )!;
      expect(placement.side, PanelSide.left);
      // Right edge 12 dp from the chat, never over the video.
      expect(placement.rect.right, 868);
      expect(placement.rect.top, greaterThanOrEqualTo(video.bottom));
      expect(placement.rect.bottom, lessThanOrEqualTo(854 - 12));
      expect(placement.nub, inInclusiveRange(20, 344 - 20));
    });

    test('a message high up still gets a card below the video', () {
      final placement = placePanel(
        bounds: screen,
        anchor: const Rect.fromLTWH(880, 100, 400, 26),
        size: const Size(384, 344),
        sides: const [PanelSide.left],
        region: chat,
        avoid: video,
      )!;
      expect(placement.rect.top, greaterThanOrEqualTo(video.bottom));
      expect(placement.rect.bottom, lessThanOrEqualTo(854 - 12));
      // The nub stays on the card, as near the name as it can.
      expect(placement.nub, 20);
    });

    test('no room on any side: null, and the caller shows a sheet', () {
      expect(
        placePanel(
          bounds: const Rect.fromLTWH(0, 0, 390, 844),
          anchor: const Rect.fromLTWH(300, 790, 80, 44),
          size: const Size(384, 562),
          sides: const [PanelSide.above],
        ),
        isNull,
      );
      // A panel that would cover the video is refused.
      expect(
        placePanel(
          bounds: screen,
          anchor: const Rect.fromLTWH(400, 450, 80, 44),
          size: const Size(384, 300),
          sides: const [PanelSide.above],
          avoid: video,
        ),
        isNull,
      );
    });

    test('a column narrower than the panel lets it spill, on screen', () {
      final placement = placePanel(
        bounds: screen,
        anchor: const Rect.fromLTWH(1240, 794, 30, 44),
        size: const Size(376, 372),
        sides: const [PanelSide.above],
        region: const Rect.fromLTWH(1024, 0, 256, 854),
      )!;
      expect(placement.rect.right, lessThanOrEqualTo(1280 - 12));
      expect(placement.rect.left, greaterThanOrEqualTo(12));
    });
  });

  group('showSheetOrPanel', () {
    Future<BuildContext> pump(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      late BuildContext inside;
      final holder = PanelAvoidHolder();
      await tester.pumpWidget(
        MaterialApp(
          theme: const OnsetThemes(colorSchemeSeed: OnsetTokens.accent).dark,
          home: Scaffold(
            body: PanelAvoidScope(
              holder: holder,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    width: size.width * 0.6875,
                    height: size.height * 0.58,
                    child: PanelAvoidTarget(
                      holder: holder,
                      child: const ColoredBox(color: Colors.black),
                    ),
                  ),
                  Positioned.fill(
                    child: Builder(
                      builder: (context) {
                        inside = context;
                        return const SizedBox.expand();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return inside;
    }

    Widget content(BuildContext context) =>
        Text(SheetPresentation.isPanel(context) ? 'in a panel' : 'in a sheet');

    testWidgets('a tablet gets the anchored panel, clear of the video', (
      tester,
    ) async {
      final context = await pump(tester, const Size(1280, 854));
      showSheetOrPanel<void>(
        context: context,
        builder: content,
        size: const Size(384, 344),
        sides: const [PanelSide.left],
        anchor: const Rect.fromLTWH(880, 650, 400, 26),
        region: const Rect.fromLTWH(880, 0, 400, 854),
      );
      await tester.pumpAndSettle();
      expect(find.text('in a panel'), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      final surface = tester.getRect(find.byType(OnsetPanelSurface));
      expect(surface.right, 868);
      expect(surface.top, greaterThanOrEqualTo(854 * 0.58));
      // A tap outside closes it.
      await tester.tapAt(const Offset(1000, 100));
      await tester.pumpAndSettle();
      expect(find.text('in a panel'), findsNothing);
    });

    testWidgets('a phone gets the sheet', (tester) async {
      final context = await pump(tester, const Size(390, 844));
      showSheetOrPanel<void>(
        context: context,
        builder: content,
        size: const Size(384, 344),
        sides: const [PanelSide.left],
        anchor: const Rect.fromLTWH(0, 650, 390, 26),
      );
      await tester.pumpAndSettle();
      expect(find.text('in a sheet'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('reduce motion: the panel only fades in', (tester) async {
      final context = await pump(tester, const Size(1280, 854));
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pump();
      showSheetOrPanel<void>(
        context: context,
        builder: content,
        size: const Size(384, 300),
        sides: const [PanelSide.above],
        anchor: const Rect.fromLTWH(1186, 794, 80, 44),
        region: const Rect.fromLTWH(880, 0, 400, 854),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        find.ancestor(
          of: find.byType(OnsetPanelSurface),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
      await tester.pumpAndSettle();
      expect(find.text('in a panel'), findsOneWidget);
    });

    testWidgets('the keyboard lifts the panel; a resize closes it', (
      tester,
    ) async {
      final context = await pump(tester, const Size(1280, 854));
      showSheetOrPanel<void>(
        context: context,
        builder: content,
        size: const Size(384, 562),
        sides: const [PanelSide.above],
        anchor: const Rect.fromLTWH(1186, 794, 80, 44),
        region: const Rect.fromLTWH(880, 0, 400, 854),
      );
      await tester.pumpAndSettle();
      final before = tester.getRect(find.byType(OnsetPanelSurface));
      tester.view.viewInsets = const FakeViewPadding(bottom: 360);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      final lifted = tester.getRect(find.byType(OnsetPanelSurface));
      expect(lifted.bottom, lessThanOrEqualTo(854 - 360 - 8));
      expect(lifted.left, before.left);
      tester.view.resetViewInsets();
      await tester.pump();
      expect(tester.getRect(find.byType(OnsetPanelSurface)), before);
      // A rotation strands it: it closes.
      tester.view.physicalSize = const Size(854, 1280);
      await tester.pumpAndSettle();
      expect(find.text('in a panel'), findsNothing);
    });

    testWidgets('a panel rebuilt by the keyboard keeps its curves', (
      tester,
    ) async {
      final curves = LiveCurves.track();
      final context = await pump(tester, const Size(1280, 854));
      showSheetOrPanel<void>(
        context: context,
        builder: content,
        size: const Size(384, 300),
        sides: const [PanelSide.above],
        anchor: const Rect.fromLTWH(1186, 794, 80, 44),
        region: const Rect.fromLTWH(880, 0, 400, 854),
      );
      await tester.pumpAndSettle();
      final settled = curves.count;
      addTearDown(tester.view.resetViewInsets);
      for (var i = 1; i <= 10; i++) {
        tester.view.viewInsets = FakeViewPadding(bottom: 30.0 * i);
        await tester.pump();
      }
      expect(curves.count, settled);
    });

    testWidgets('a sheet in the panel tone reports that ground', (
      tester,
    ) async {
      final context = await pump(tester, const Size(390, 844));
      late Color ground;
      showSheetOrPanel<void>(
        context: context,
        builder: (context) {
          ground = SheetPresentation.surfaceOf(context);
          return const Text('sheet');
        },
        size: const Size(384, 344),
        sides: const [PanelSide.left],
        panelSheet: true,
      );
      await tester.pumpAndSettle();
      expect(ground, SheetColors.of(context).panel);
    });
  });

  group('panelClearOfKeyboard', () {
    const media = MediaQueryData(
      size: Size(1280, 854),
      padding: EdgeInsets.only(top: 24),
      viewInsets: EdgeInsets.only(bottom: 400),
    );

    test('without a keyboard nothing moves', () {
      const rect = Rect.fromLTWH(884, 214, 384, 562);
      expect(
        panelClearOfKeyboard(rect, media.copyWith(viewInsets: EdgeInsets.zero)),
        rect,
      );
    });

    test('too tall to lift whole: under the status bar, shortened', () {
      final rect = panelClearOfKeyboard(
        const Rect.fromLTWH(884, 214, 384, 562),
        media,
      );
      expect(rect.top, 32);
      expect(rect.bottom, 854 - 400 - 8);
      expect(rect.left, 884);
    });

    test('a short panel is lifted, keeping its height', () {
      final rect = panelClearOfKeyboard(
        const Rect.fromLTWH(884, 600, 384, 200),
        media,
      );
      expect(rect.height, 200);
      expect(rect.bottom, 854 - 400 - 8);
    });
  });
}
