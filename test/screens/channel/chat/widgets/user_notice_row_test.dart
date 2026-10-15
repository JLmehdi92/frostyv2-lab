import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/user_notice_presentation.dart';
import 'package:frosty/models/user_notice_text.dart';
import 'package:frosty/screens/channel/chat/widgets/user_notice_row.dart';
import 'package:frosty/theme.dart';

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
  const themes = FrostyThemes(colorSchemeSeed: FrostyTokens.accent);
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
  testWidgets('draws a 4dp green accent bar on the green tint', (tester) async {
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
    expect(border.left.color, const Color(0xFF12A87A));
    expect(decoration.color, FrostyColors.dark.subNoticeBackground);
  });

  testWidgets('uses the light tint in the light theme', (tester) async {
    await _pump(
      tester,
      const UserNoticeRow(
        segments: _segments,
        presentation: NoticePresentation(NoticeLayout.special),
      ),
      brightness: Brightness.light,
    );

    expect(_decoration(tester).color, FrostyColors.light.subNoticeBackground);
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
    expect(bar.color, const Color(0xFF12A87A));
    expect(tester.getSize(find.byType(LinearProgressIndicator)).height, 6);
    expect(
      tester.getSize(find.byType(LinearProgressIndicator)).width,
      lessThanOrEqualTo(75),
    );
    expect(_decoration(tester).color, FrostyColors.dark.subNoticeBackground);
  });
}
