import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/theme.dart';

void main() {
  test('headings, body and numbers all use Inter', () {
    final theme = const FrostyThemes(colorSchemeSeed: FrostyTokens.accent).dark;

    expect(theme.textTheme.bodyMedium?.fontFamily, 'Inter');
    expect(theme.textTheme.headlineSmall?.fontFamily, 'Inter');

    final text = theme.extension<FrostyTextStyles>()!;
    expect(text.metadata.fontFamily, 'Inter');
    // Counters keep fixed-width digits.
    expect(
      text.metadata.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });

  test('heading weights round to a weight Inter ships', () {
    expect(FrostyTokens.displayWeight(600), FontWeight.w600);
    expect(FrostyTokens.displayWeight(650), FontWeight.w700);
    expect(FrostyTokens.displayWeight(700), FontWeight.w700);
    expect(FrostyTokens.displayWeight(50), FontWeight.w100);
    expect(FrostyTokens.displayWeight(1200), FontWeight.w900);
  });
}
