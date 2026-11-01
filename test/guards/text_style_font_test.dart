import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/theme.dart';

/// A button's or a tooltip's `textStyle` replaces the style it would
/// inherit instead of merging with it: a `TextStyle(...)` written there
/// without a `fontFamily` draws its label in the platform's font (Roboto),
/// not the app's Inter, so the label is wider or narrower than the tests
/// measure. Every such style names the app font.
void main() {
  group('the checker', () {
    test('accepts a style with the app font, or a style passed by name', () {
      for (final source in [
        'TextButton.styleFrom(textStyle: const TextStyle(\n'
            '  fontFamily: OnsetTokens.bodyFamily,\n'
            '  fontSize: 14,\n'
            '))',
        'ButtonStyle(textStyle: WidgetStatePropertyAll(TextStyle('
            'fontFamily: OnsetTokens.bodyFamily, fontSize: 13)))',
        'TextButton.styleFrom(textStyle: style)',
        'TextButton.styleFrom(textStyle: SheetText.body.copyWith('
            'fontSize: 13))',
      ]) {
        expect(fontlessTextStyles(source), isEmpty, reason: source);
      }
    });

    test('catches a style without a font family', () {
      for (final source in [
        'TextButton.styleFrom(textStyle: const TextStyle(fontSize: 14))',
        'TextButton.styleFrom(\n  textStyle: TextStyle(\n'
            '    color: Color(0xFF000000),\n    fontSize: size(2),\n  ),\n)',
        'ButtonStyle(textStyle: const WidgetStatePropertyAll(\n'
            '  TextStyle(fontWeight: FontWeight.w700),\n))',
      ]) {
        expect(fontlessTextStyles(source), hasLength(1), reason: source);
      }
    });
  });

  test('every textStyle written in lib/ names the app font', () {
    var looked = 0;
    final problems = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (file.path.contains('${Platform.pathSeparator}l10n')) continue;
      final source = file.readAsStringSync();
      looked += 'textStyle:'.allMatches(source).length;
      for (final line in fontlessTextStyles(source)) {
        problems.add('${file.path}:$line');
      }
    }
    // The check must be looking at the app's button styles.
    expect(looked, greaterThan(20));
    expect(
      problems,
      isEmpty,
      reason:
          'add fontFamily: OnsetTokens.bodyFamily to these textStyles:\n'
          '${problems.join('\n')}',
    );
  });

  testWidgets('a button whose style names the app font draws in Inter', (
    tester,
  ) async {
    final themes = OnsetThemes(colorSchemeSeed: OnsetTokens.accent);
    Future<String?> familyOf(TextStyle style) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: themes.dark,
          home: Scaffold(
            body: TextButton(
              style: TextButton.styleFrom(textStyle: style),
              onPressed: () {},
              child: const Text('Follow'),
            ),
          ),
        ),
      );
      // The label's style animates from the previous one: let it end.
      await tester.pumpAndSettle();
      return DefaultTextStyle.of(
        tester.element(find.text('Follow')),
      ).style.fontFamily;
    }

    // Without a family the theme's font is lost: the reason for the rule.
    expect(await familyOf(const TextStyle(fontSize: 14)), isNot('Inter'));
    expect(
      await familyOf(
        const TextStyle(fontFamily: OnsetTokens.bodyFamily, fontSize: 14),
      ),
      'Inter',
    );
  });
}

final _textStyleArgument = RegExp(
  r'textStyle:\s*(?:const\s+)?(?:WidgetStatePropertyAll\(\s*)?'
  r'(?:const\s+)?TextStyle\(',
);

/// The lines of [source] where a `textStyle:` argument is a `TextStyle(...)`
/// written in place without a `fontFamily`.
List<int> fontlessTextStyles(String source) => [
  for (final match in _textStyleArgument.allMatches(source))
    if (!_arguments(source, match.end).contains('fontFamily'))
      '\n'.allMatches(source.substring(0, match.start)).length + 1,
];

/// The text inside the parentheses opened just before [start].
String _arguments(String source, int start) {
  var depth = 1;
  var index = start;
  while (index < source.length && depth > 0) {
    final char = source[index];
    if (char == '(') depth++;
    if (char == ')') depth--;
    index++;
  }
  return source.substring(start, index - 1);
}
