import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/utils/context_extensions.dart';

void main() {
  test('a tablet is large in both orientations; a phone is not', () {
    expect(isLargeScreenSize(const Size(1600, 1067)), isTrue);
    expect(isLargeScreenSize(const Size(1067, 1600)), isTrue);
    expect(isLargeScreenSize(const Size(800, 1280)), isTrue);
    expect(isLargeScreenSize(const Size(360, 740)), isFalse);
    expect(isLargeScreenSize(const Size(740, 360)), isFalse);
  });

  test('a split-screen half under 600 dp keeps the phone layouts', () {
    expect(isLargeScreenSize(const Size(1600, 530)), isFalse);
  });

  testWidgets('context.isLargeScreen reads the window size', (tester) async {
    tester.view
      ..physicalSize = const Size(3200, 2136)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    late bool large;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          large = context.isLargeScreen;
          return const SizedBox();
        },
      ),
    );
    expect(large, isTrue);

    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    await tester.pump();
    expect(large, isFalse);
  });
}
