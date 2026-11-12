import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/theme.dart';

void main() {
  test('themes built for the same accent are identical', () {
    const accent = Color(0xFF9146FF);
    expect(
      identical(
        const OnsetThemes(colorSchemeSeed: accent).dark,
        const OnsetThemes(colorSchemeSeed: accent).dark,
      ),
      isTrue,
    );
    expect(
      identical(
        const OnsetThemes(colorSchemeSeed: accent).light,
        const OnsetThemes(colorSchemeSeed: accent).light,
      ),
      isTrue,
    );
    expect(
      const OnsetThemes(colorSchemeSeed: accent).dark,
      isNot(const OnsetThemes(colorSchemeSeed: Colors.red).dark),
    );
  });

  test('text styles resolved from the same colour are equal', () {
    final a = OnsetTextStyles.resolve(Colors.grey);
    final b = OnsetTextStyles.resolve(Colors.grey);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(OnsetTextStyles.resolve(Colors.blue)));
  });

  test('a copied theme stays equal to its source', () {
    final theme = const OnsetThemes(colorSchemeSeed: Colors.teal).dark;
    expect(
      theme.copyWith(
        extensions: [
          OnsetColors.dark,
          OnsetTextStyles.resolve(OnsetColors.dark.metadata),
        ],
      ),
      theme.copyWith(
        extensions: [
          OnsetColors.dark,
          OnsetTextStyles.resolve(OnsetColors.dark.metadata),
        ],
      ),
    );
  });
}
