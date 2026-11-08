import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/user_notice_presentation.dart';
import 'package:onset/models/user_notice_text.dart';
import 'package:onset/screens/channel/chat/widgets/user_notice_row.dart';
import 'package:onset/theme.dart';

const _segments = [
  NoticeSegment('ReSubber', bold: true),
  NoticeSegment(' subscribed at Tier 1.'),
];

Future<void> _pump(
  WidgetTester tester,
  Widget row, {
  Brightness brightness = Brightness.dark,
  double fontSize = 14,
}) async {
  const themes = OnsetThemes(colorSchemeSeed: OnsetTokens.accent);
  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.dark ? themes.dark : themes.light,
      home: Scaffold(
        body: DefaultTextStyle(
          style: TextStyle(fontSize: fontSize, color: Colors.white),
          child: Column(children: [row]),
        ),
      ),
    ),
  );
}

BoxDecoration _decoration(WidgetTester tester) =>
    tester.widget<Container>(find.byKey(UserNoticeRow.bodyKey)).decoration!
        as BoxDecoration;

/// The spans of the system line, flattened.
List<TextSpan> _systemSpans(WidgetTester tester) {
  final text = tester.widget<Text>(find.byKey(UserNoticeRow.systemLineKey));
  final spans = <TextSpan>[];
  text.textSpan!.visitChildren((span) {
    if (span is TextSpan && span.text != null) spans.add(span);
    return true;
  });
  return spans;
}

void main() {
  testWidgets('draws a 4dp lime accent bar on the lime tint', (tester) async {
    await _pump(
      tester,
      const UserNoticeRow(
        segments: _segments,
        presentation: NoticePresentation(NoticeLayout.special),
      ),
    );

    final decoration = _decoration(tester);
    final border = decoration.border! as Border;
    expect(border.left.width, 4);
    expect(border.left.color, OnsetTokens.accent);
    expect(decoration.color, const Color(0xFF171B0E));
  });

  testWidgets('a darker lime bar on the light tint in the light theme', (
    tester,
  ) async {
    await _pump(
      tester,
      const UserNoticeRow(
        segments: _segments,
        presentation: NoticePresentation(NoticeLayout.special),
      ),
      brightness: Brightness.light,
    );

    final decoration = _decoration(tester);
    expect((decoration.border! as Border).left.color, const Color(0xFF6B8A00));
    expect(decoration.color, OnsetColors.light.subNoticeBackground);
  });

  testWidgets('a footer sits under the sentence, in its column', (
    tester,
  ) async {
    await _pump(
      tester,
      const UserNoticeRow(
        segments: _segments,
        presentation: NoticePresentation(NoticeLayout.special),
        footer: SizedBox(key: ValueKey('footer'), height: 44, width: 10),
      ),
    );

    final line = tester.getRect(find.byKey(UserNoticeRow.systemLineKey));
    final footer = tester.getRect(find.byKey(const ValueKey('footer')));
    expect(footer.top, line.bottom);
    expect(footer.left, line.left);
    expect(
      tester.getRect(find.byKey(UserNoticeRow.bodyKey)).bottom,
      footer.bottom,
    );
  });

  testWidgets('keeps a 2dp gap above and below the row', (tester) async {
    await _pump(
      tester,
      const UserNoticeRow(
        segments: _segments,
        presentation: NoticePresentation(NoticeLayout.special),
      ),
    );

    final row = tester.getRect(find.byType(UserNoticeRow));
    final body = tester.getRect(find.byKey(UserNoticeRow.bodyKey));
    expect(body.top - row.top, 2);
    expect(row.bottom - body.bottom, 2);
    expect(body.width, row.width);
  });

  testWidgets('a generic row has no tint and an onSurface accent', (
    tester,
  ) async {
    await _pump(
      tester,
      const UserNoticeRow(
        segments: _segments,
        presentation: NoticePresentation(NoticeLayout.generic),
      ),
    );

    final decoration = _decoration(tester);
    expect(decoration.color, isNull);
    final context = tester.element(find.byType(UserNoticeRow));
    expect(
      (decoration.border! as Border).left.color,
      Theme.of(context).colorScheme.onSurface,
    );
  });

  testWidgets('a named sub has no icon', (tester) async {
    await _pump(
      tester,
      const UserNoticeRow(
        segments: _segments,
        presentation: NoticePresentation(NoticeLayout.special),
      ),
    );

    expect(find.byType(Icon), findsNothing);
    // The text starts right after the bar, plus its own 8dp padding.
    final body = tester.getRect(find.byKey(UserNoticeRow.bodyKey));
    final line = tester.getRect(find.byKey(UserNoticeRow.systemLineKey));
    expect(line.left - body.left, 4 + 8);
  });

  testWidgets('an anonymous gift has an 18dp icon, centred', (tester) async {
    await _pump(
      tester,
      const UserNoticeRow(
        segments: _segments,
        presentation: NoticePresentation(
          NoticeLayout.special,
          icon: NoticeGlyph.anonymousGift,
          iconBias: NoticePresentation.centredIconBias,
        ),
        userMessage: Text('a\nfew\nlines\nof\nmessage'),
      ),
    );

    final icon = find.byType(Icon);
    expect(icon, findsOneWidget);
    expect(tester.getSize(icon), const Size(18, 18));

    final body = tester.getRect(find.byKey(UserNoticeRow.bodyKey));
    final iconRect = tester.getRect(icon);
    expect(iconRect.left - body.left, 4 + 8);
    expect(iconRect.center.dy, closeTo(body.center.dy, 0.5));
  });

  testWidgets('other icons sit a little above the middle', (tester) async {
    await _pump(
      tester,
      const UserNoticeRow(
        segments: _segments,
        presentation: NoticePresentation(
          NoticeLayout.generic,
          icon: NoticeGlyph.megaphone,
        ),
        userMessage: Text('a\nfew\nlines\nof\nmessage'),
      ),
    );

    final body = tester.getRect(find.byKey(UserNoticeRow.bodyKey));
    final iconRect = tester.getRect(find.byType(Icon));
    expect(iconRect.center.dy, lessThan(body.center.dy));
    expect(iconRect.top, greaterThan(body.top));
  });

  testWidgets('sets the sentence in w600 and the names in w700', (
    tester,
  ) async {
    await _pump(
      tester,
      const UserNoticeRow(
        segments: _segments,
        presentation: NoticePresentation(NoticeLayout.special),
      ),
    );

    final text = tester.widget<Text>(find.byKey(UserNoticeRow.systemLineKey));
    expect(text.textSpan!.style!.fontWeight, FontWeight.w600);
    final spans = _systemSpans(tester);
    expect(spans.map((s) => s.text), ['ReSubber', ' subscribed at Tier 1.']);
    expect(spans.first.style!.fontWeight, FontWeight.w700);
    expect(spans.last.style?.fontWeight, isNull);
  });

  testWidgets('follows the chat font size', (tester) async {
    await _pump(
      tester,
      const UserNoticeRow(
        segments: _segments,
        presentation: NoticePresentation(NoticeLayout.special),
      ),
      fontSize: 20,
    );

    final text = tester.widget<Text>(find.byKey(UserNoticeRow.systemLineKey));
    expect(text.textSpan!.style!.fontSize, 20);
  });

  testWidgets('pads the sentence 8dp, with 16dp on the right', (tester) async {
    await _pump(
      tester,
      const UserNoticeRow(
        segments: _segments,
        presentation: NoticePresentation(NoticeLayout.special),
      ),
    );

    final body = tester.getRect(find.byKey(UserNoticeRow.bodyKey));
    final line = tester.getRect(find.byKey(UserNoticeRow.systemLineKey));
    expect(line.top - body.top, 8);
    expect(body.bottom - line.bottom, 8);
    expect(body.right - line.right, 16);
    expect(line.height, greaterThanOrEqualTo(24));
  });

  testWidgets('puts the user message 2dp under the sentence', (tester) async {
    await _pump(
      tester,
      const UserNoticeRow(
        segments: _segments,
        presentation: NoticePresentation(NoticeLayout.special),
        userMessage: Text('Kappa 14 months!'),
      ),
    );

    final body = tester.getRect(find.byKey(UserNoticeRow.bodyKey));
    final line = tester.getRect(find.byKey(UserNoticeRow.systemLineKey));
    final message = tester.getRect(find.text('Kappa 14 months!'));
    expect(message.top - line.bottom, 2);
    expect(body.bottom - message.bottom, 8);
    expect(message.left - body.left, 4 + 8);
  });

  testWidgets('shows only the user message when there is no sentence', (
    tester,
  ) async {
    await _pump(
      tester,
      const UserNoticeRow(
        segments: [],
        presentation: NoticePresentation(NoticeLayout.special),
        userMessage: Text('hello'),
      ),
    );

    expect(find.byKey(UserNoticeRow.systemLineKey), findsNothing);
    final body = tester.getRect(find.byKey(UserNoticeRow.bodyKey));
    expect(tester.getRect(find.text('hello')).top - body.top, 8);
  });

  testWidgets('a sponsor colour replaces the accent', (tester) async {
    await _pump(
      tester,
      const UserNoticeRow(
        segments: _segments,
        presentation: NoticePresentation(NoticeLayout.special),
        accentColor: Colors.orange,
      ),
    );

    expect((_decoration(tester).border! as Border).left.color, Colors.orange);
  });

  testWidgets('a sponsor colour tints the row like the lime does', (
    tester,
  ) async {
    const sponsor = Color(0xFFFF7A00);
    const row = UserNoticeRow(
      segments: _segments,
      presentation: NoticePresentation(NoticeLayout.special),
      accentColor: sponsor,
    );

    await _pump(tester, row);
    expect(
      _decoration(tester).color,
      Color.alphaBlend(
        sponsor.withValues(alpha: 0.10),
        OnsetTokens.backgroundDark,
      ),
    );

    await _pump(tester, row, brightness: Brightness.light);
    // Let the app's theme finish moving to the light one.
    await tester.pumpAndSettle();
    expect(
      _decoration(tester).color,
      Color.alphaBlend(
        sponsor.withValues(alpha: 0.08),
        OnsetTokens.backgroundLight,
      ),
    );
  });

  testWidgets('a sub goal row shows its progress', (tester) async {
    await _pump(
      tester,
      const UserNoticeRow(
        segments: _segments,
        presentation: NoticePresentation(NoticeLayout.subGoal),
        goalCurrent: 524,
        goalTarget: 1200,
      ),
    );

    expect(find.text('524/1200'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, closeTo(524 / 1200, 1e-9));
    expect(bar.color, OnsetTokens.accent);
    expect(tester.getSize(find.byType(LinearProgressIndicator)).height, 6);
    expect(
      tester.getSize(find.byType(LinearProgressIndicator)).width,
      lessThanOrEqualTo(75),
    );
    expect(_decoration(tester).color, OnsetColors.dark.subNoticeBackground);
  });

  group('over the video', () {
    testWidgets('a translucent black row, rounded, with the lime bar', (
      tester,
    ) async {
      await _pump(
        tester,
        const UserNoticeRow(
          segments: _segments,
          presentation: NoticePresentation(NoticeLayout.special),
          overlay: true,
        ),
      );

      final decoration = _decoration(tester);
      expect(decoration.color, const Color(0x29000000));
      final border = decoration.border! as Border;
      expect(border.left.width, 4);
      expect(border.left.color, OnsetTokens.accent);

      final clip = tester.widget<ClipRRect>(
        find.ancestor(
          of: find.byKey(UserNoticeRow.bodyKey),
          matching: find.byType(ClipRRect),
        ),
      );
      expect(clip.borderRadius, BorderRadius.circular(6));
    });

    testWidgets('keeps the generic row untinted', (tester) async {
      await _pump(
        tester,
        const UserNoticeRow(
          segments: _segments,
          presentation: NoticePresentation(NoticeLayout.generic),
          overlay: true,
        ),
      );

      expect(_decoration(tester).color, isNull);
    });

    testWidgets('the chat list is not rounded', (tester) async {
      await _pump(
        tester,
        const UserNoticeRow(
          segments: _segments,
          presentation: NoticePresentation(NoticeLayout.special),
        ),
      );

      expect(find.byType(ClipRRect), findsNothing);
    });
  });

  group('bubbles', () {
    testWidgets('a bubble is rounded, ringed and keeps the tint', (
      tester,
    ) async {
      await _pump(
        tester,
        const UserNoticeRow(
          segments: _segments,
          presentation: NoticePresentation(NoticeLayout.special),
          bubble: true,
        ),
      );

      final decoration =
          tester
                  .widget<Container>(find.byKey(UserNoticeRow.bubbleKey))
                  .decoration!
              as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(14));
      expect(decoration.border, isA<Border>());
      expect((decoration.border! as Border).left.width, lessThan(4));
      expect(decoration.color, OnsetColors.dark.subNoticeBackground);
      expect(find.textContaining('subscribed at Tier 1.'), findsOneWidget);
      final bubble = tester.getRect(find.byKey(UserNoticeRow.bubbleKey));
      expect(bubble.left, 8);
    });

    testWidgets('over the video the row stays a row', (tester) async {
      await _pump(
        tester,
        const UserNoticeRow(
          segments: _segments,
          presentation: NoticePresentation(NoticeLayout.special),
          bubble: true,
          overlay: true,
        ),
      );
      expect(find.byKey(UserNoticeRow.bubbleKey), findsNothing);
      expect(find.byKey(UserNoticeRow.bodyKey), findsOneWidget);
    });
  });
}
