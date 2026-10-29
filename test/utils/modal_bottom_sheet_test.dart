import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/utils/modal_bottom_sheet.dart';

void main() {
  const videoBottom = 267.0;

  Future<BuildContext> pump(WidgetTester tester, {double? top}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late BuildContext inside;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SheetsUnderVideo(
            top: top,
            child: Builder(
              builder: (context) {
                inside = context;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );
    return inside;
  }

  Widget tall(BuildContext context) => ListView(
    shrinkWrap: true,
    children: [
      for (var i = 0; i < 40; i++) SizedBox(height: 48, child: Text('Row $i')),
    ],
  );

  /// The painted scrim (the one with a colour).
  Rect scrimRect(WidgetTester tester) =>
      tester.getRect(find.byType(AnimatedModalBarrier));

  testWidgets('a tall sheet stops 12 dp under the video', (tester) async {
    final context = await pump(tester, top: videoBottom);
    showModalBottomSheetWithProperFocus<void>(
      context: context,
      isScrollControlled: true,
      builder: tall,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final sheet = tester.getRect(find.byType(BottomSheet));
    expect(sheet.top, closeTo(videoBottom + SheetsUnderVideo.gap, 0.5));
    expect(sheet.bottom, 844);
  });

  testWidgets('the video stays undimmed, a tap on it closes the sheet', (
    tester,
  ) async {
    final context = await pump(tester, top: videoBottom);
    showModalBottomSheetWithProperFocus<void>(
      context: context,
      builder: (_) => const SizedBox(height: 200, child: Text('Sheet')),
    );
    await tester.pumpAndSettle();
    expect(scrimRect(tester).top, videoBottom);

    await tester.tapAt(const Offset(195, 100));
    await tester.pumpAndSettle();
    expect(find.text('Sheet'), findsNothing);
  });

  testWidgets('a sheet opened from it starts under the video too', (
    tester,
  ) async {
    final context = await pump(tester, top: videoBottom);
    showModalBottomSheetWithProperFocus<void>(
      context: context,
      builder: (context) => TextButton(
        onPressed: () => showModalBottomSheetWithProperFocus<void>(
          context: context,
          isScrollControlled: true,
          builder: tall,
        ),
        child: const Text('More'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    final sheets = tester.getRect(find.byType(BottomSheet).last);
    expect(sheets.top, closeTo(videoBottom + SheetsUnderVideo.gap, 0.5));
  });

  testWidgets('with the keyboard up, a sheet keeps room above it', (
    tester,
  ) async {
    final context = await pump(tester, top: videoBottom);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    showModalBottomSheetWithProperFocus<void>(
      context: context,
      isScrollControlled: true,
      // Like the points sheet: it pads itself above the keyboard.
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: tall(context),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final sheet = tester.getRect(find.byType(BottomSheet));
    // It may grow by the keyboard's height (here up to the top of the
    // screen), so the rows above the keyboard keep their room.
    expect(sheet.top, 0);
    expect(sheet.height - 300, greaterThan(500));
  });

  testWidgets('turned to landscape, the sheet forgets the portrait video', (
    tester,
  ) async {
    final context = await pump(tester, top: videoBottom);
    showModalBottomSheetWithProperFocus<void>(
      context: context,
      isScrollControlled: true,
      builder: tall,
    );
    await tester.pumpAndSettle();
    expect(scrimRect(tester).top, videoBottom);

    // The phone turns: the portrait video's edge means nothing any more.
    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(scrimRect(tester).top, 0);
    expect(tester.getRect(find.byType(BottomSheet)).top, lessThan(100));
  });

  testWidgets('an edge past 60 % of the height is not used', (tester) async {
    final context = await pump(tester, top: 600);
    showModalBottomSheetWithProperFocus<void>(
      context: context,
      isScrollControlled: true,
      builder: tall,
    );
    await tester.pumpAndSettle();
    expect(scrimRect(tester).top, 0);
    expect(tester.getRect(find.byType(BottomSheet)).top, lessThan(600));
  });

  testWidgets('without a video sheets open as before', (tester) async {
    final context = await pump(tester);
    showModalBottomSheetWithProperFocus<void>(
      context: context,
      isScrollControlled: true,
      builder: tall,
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(BottomSheet)).top, lessThan(videoBottom));
    expect(scrimRect(tester).top, 0);
  });
}
