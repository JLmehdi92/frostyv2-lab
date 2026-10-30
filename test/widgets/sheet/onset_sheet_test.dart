import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/modal_bottom_sheet.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';

void main() {
  Future<BuildContext> pump(
    WidgetTester tester, {
    Brightness brightness = Brightness.dark,
    double? videoBottom,
    Size size = const Size(390, 844),
    bool reduceMotion = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late BuildContext inside;
    final theme = const OnsetThemes(colorSchemeSeed: OnsetTokens.accent);
    await tester.pumpWidget(
      MaterialApp(
        theme: brightness == Brightness.dark ? theme.dark : theme.light,
        home: MediaQuery(
          data: MediaQueryData(size: size, disableAnimations: reduceMotion),
          child: Scaffold(
            body: SheetsUnderVideo(
              top: videoBottom,
              child: Builder(
                builder: (context) {
                  inside = context;
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      ),
    );
    return inside;
  }

  group('showOnsetSheet', () {
    for (final brightness in Brightness.values) {
      testWidgets('draws the board frame ($brightness)', (tester) async {
        final context = await pump(tester, brightness: brightness);
        showOnsetSheet<void>(
          context: context,
          builder: (_) => const SizedBox(height: 120, child: Text('Body')),
        );
        await tester.pumpAndSettle();
        final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
        final colors = brightness == Brightness.dark
            ? SheetColors.dark
            : SheetColors.light;
        expect(sheet.backgroundColor, colors.sheet);
        expect(sheet.showDragHandle, isFalse);
        expect(
          (sheet.shape! as RoundedRectangleBorder).borderRadius,
          const BorderRadius.vertical(top: Radius.circular(24)),
        );
        // The board's 36 × 4 handle, 8 dp from the top.
        final handle = find.descendant(
          of: find.byType(SheetHandle),
          matching: find.byType(Container),
        );
        expect(tester.getSize(handle), const Size(36, 4));
        expect(
          tester.getTopLeft(handle).dy -
              tester.getTopLeft(find.byType(BottomSheet)).dy,
          8,
        );
        expect(find.text('Body'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a sheet over a sheet is the darker panel tone', (
      tester,
    ) async {
      final context = await pump(tester);
      showOnsetSheet<void>(
        context: context,
        panel: true,
        builder: (_) => const SizedBox(height: 120),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<BottomSheet>(find.byType(BottomSheet)).backgroundColor,
        SheetColors.dark.panel,
      );
    });

    testWidgets('still starts under the video on a phone', (tester) async {
      final context = await pump(tester, videoBottom: 220);
      showOnsetSheet<void>(
        context: context,
        builder: (_) => ListView(
          shrinkWrap: true,
          children: [for (var i = 0; i < 40; i++) const SizedBox(height: 50)],
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byType(BottomSheet)).dy,
        220 + SheetsUnderVideo.gap,
      );
    });
  });

  group('SheetRow', () {
    testWidgets('52 dp, 60 with a second line; a tap runs it', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SheetRow(
                  key: const Key('one'),
                  glyph: SheetGlyphKind.copy,
                  label: 'Copy name',
                  onTap: () => taps++,
                ),
                const SheetRow(
                  key: Key('two'),
                  glyph: SheetGlyphKind.coin,
                  label: 'Channel points',
                  detail: 'Opens the chat on twitch.tv',
                  end: SheetRowEnd.external,
                ),
              ],
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byKey(const Key('one'))).height, 52);
      expect(tester.getSize(find.byKey(const Key('two'))).height, 60);
      await tester.tap(find.text('Copy name'));
      expect(taps, 1);
      expect(find.byType(SheetGlyph), findsNWidgets(3));
    });

    testWidgets('a destructive row reads in the danger colour', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: const OnsetThemes(colorSchemeSeed: OnsetTokens.accent).dark,
          home: Scaffold(
            body: SheetRow(
              glyph: SheetGlyphKind.trash,
              label: 'Delete message',
              danger: true,
              onTap: () {},
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(find.text('Delete message'));
      expect(text.style?.color, SheetColors.dark.danger);
    });
  });

  group('OnsetSwitch', () {
    testWidgets('a 44 × 26 track that toggles and says its state', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      var value = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: StatefulBuilder(
                builder: (context, setState) => OnsetSwitch(
                  value: value,
                  semanticsLabel: 'Slow mode',
                  onChanged: (next) => setState(() => value = next),
                ),
              ),
            ),
          ),
        ),
      );
      final track = find.byWidgetPredicate(
        (w) => w is AnimatedContainer && w.constraints?.maxWidth == 44,
      );
      expect(tester.getSize(track), const Size(44, 26));
      expect(tester.getSize(find.byType(OnsetSwitch)).height, 44);
      expect(
        tester.getSemantics(find.byType(OnsetSwitch)),
        matchesSemantics(
          label: 'Slow mode',
          hasToggledState: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      await tester.tap(find.byType(OnsetSwitch));
      await tester.pumpAndSettle();
      expect(value, isTrue);
      expect(
        tester.getSemantics(find.byType(OnsetSwitch)),
        matchesSemantics(
          label: 'Slow mode',
          hasToggledState: true,
          isToggled: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('disabled, a tap does nothing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: OnsetSwitch(value: true, onChanged: null)),
          ),
        ),
      );
      await tester.tap(find.byType(OnsetSwitch));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the status line shows the running bar, then the answer', (
    tester,
  ) async {
    Widget line({required bool busy, String? message, bool ok = true}) =>
        MaterialApp(
          home: Scaffold(
            body: SheetStatusLine(busy: busy, message: message, ok: ok),
          ),
        );
    await tester.pumpWidget(line(busy: true));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.pumpWidget(line(busy: false, message: 'Done'));
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Done'), findsOneWidget);
    await tester.pumpWidget(line(busy: false, message: 'No', ok: false));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.text('No')).style?.color,
      SheetColors.light.danger,
    );
  });

  testWidgets('the dialog: board card, Cancel and the primary pill', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: const OnsetThemes(colorSchemeSeed: OnsetTokens.accent).dark,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => OnsetDialog(
                  title: 'Clear chat?',
                  message: 'Every message is deleted for everyone.',
                  actions: [
                    SheetButton(
                      label: 'Cancel',
                      tone: SheetButtonTone.text,
                      onPressed: () => Navigator.pop(context),
                    ),
                    SheetButton(
                      label: 'Clear',
                      tone: SheetButtonTone.danger,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final dialog = tester.widget<Dialog>(find.byType(Dialog));
    expect(dialog.backgroundColor, SheetColors.dark.dialog);
    final card = find
        .descendant(of: find.byType(Dialog), matching: find.byType(Material))
        .first;
    expect(tester.getSize(card).width, lessThanOrEqualTo(326));
    final clear = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Clear'),
    );
    expect(
      clear.style?.backgroundColor?.resolve({}),
      SheetColors.dark.dangerFill,
    );
    expect(
      tester.getSize(find.widgetWithText(FilledButton, 'Clear')).height,
      44,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('the dialog names its route for screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => const OnsetDialog(
                  title: 'Clear chat?',
                  message: 'Every message is deleted for everyone.',
                  actions: [],
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final route = find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.namesRoute == true,
    );
    expect(
      tester.getSemantics(route),
      containsSemantics(
        label: 'Clear chat?',
        namesRoute: true,
        scopesRoute: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('the counter counts characters, as the limit does', (
    tester,
  ) async {
    final controller = TextEditingController(text: '😀' * 300);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SheetTextField(
            controller: controller,
            maxLength: 500,
            counter: true,
          ),
        ),
      ),
    );
    expect(find.text('300 / 500'), findsOneWidget);
  });

  testWidgets('choice pills in a Wrap hug their labels, side by side', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: Wrap(
              spacing: 8,
              children: [
                for (final label in ['100', '1K', 'Max'])
                  SheetChoicePill(
                    label: label,
                    selected: label == '1K',
                    onSelected: () {},
                    tabular: true,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    final pills = find.byType(SheetChoicePill);
    expect(pills, findsNWidgets(3));
    final rows = <double>{};
    for (final pill in pills.evaluate()) {
      final box = pill.renderObject! as RenderBox;
      expect(box.size.width, lessThan(100), reason: 'a pill, not a bar');
      expect(box.size.height, 30);
      rows.add(box.localToGlobal(Offset.zero).dy);
    }
    expect(rows, hasLength(1), reason: 'the pills sit side by side');
  });

  testWidgets('a choice pill says when it is selected', (tester) async {
    final semantics = tester.ensureSemantics();
    var picked = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SheetChoicePill(
              label: 'Channel',
              selected: true,
              onSelected: () => picked = true,
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(SheetChoicePill)).height, 30);
    expect(
      tester.getSemantics(find.byType(SheetChoicePill)),
      matchesSemantics(
        label: 'Channel',
        isSelected: true,
        hasSelectedState: true,
        isButton: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    await tester.tap(find.text('Channel'));
    expect(picked, isTrue);
    semantics.dispose();
  });

  test('initial avatars take a stable colour from the name', () {
    expect(InitialAvatar.colorOf('zazou'), InitialAvatar.colorOf('zazou'));
    expect(InitialAvatar.palette, contains(InitialAvatar.colorOf('a')));
    expect(InitialAvatar.colorOf(''), InitialAvatar.palette.first);
  });

  testWidgets('reduce motion still moves the knob, without travel', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Center(child: OnsetSwitch(value: true, onChanged: null)),
          ),
        ),
      ),
    );
    final align = tester.widget<AnimatedAlign>(find.byType(AnimatedAlign));
    expect(align.duration, Duration.zero);
    expect(RendererBinding.instance, isNotNull);
  });
}
