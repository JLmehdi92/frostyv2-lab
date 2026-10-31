import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/utils/context_extensions.dart';

import '../helpers/keyboard_animation.dart';

/// Reads the screen through the context extensions and counts its builds.
class _Probe extends StatelessWidget {
  const _Probe(this.read, this.builds);

  final Object Function(BuildContext context) read;
  final List<Object> builds;

  @override
  Widget build(BuildContext context) {
    builds.add(read(context));
    return const SizedBox.shrink();
  }
}

void main() {
  Future<List<Object>> buildsWhileTheKeyboardOpens(
    WidgetTester tester,
    Object Function(BuildContext context) read,
  ) async {
    tester.view
      ..physicalSize = const Size(1280, 800)
      ..devicePixelRatio = 1
      ..viewPadding = const FakeViewPadding(bottom: 24)
      ..padding = const FakeViewPadding(bottom: 24);
    addTearDown(tester.view.reset);
    final builds = <Object>[];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery.fromView(
          view: tester.view,
          child: _Probe(read, builds),
        ),
      ),
    );
    builds.clear();
    await animateKeyboard(tester);
    return builds;
  }

  // The keyboard changes the view insets on every frame it slides in; a
  // screen reading its orientation or size must not be rebuilt for it.
  for (final (name, read) in <(String, Object Function(BuildContext))>[
    ('isPortrait', (context) => context.isPortrait),
    ('isLandscape', (context) => context.isLandscape),
    ('screenWidth', (context) => context.screenWidth),
    ('screenHeight', (context) => context.screenHeight),
    ('isLargeScreen', (context) => context.isLargeScreen),
    (
      'OrientationUtils',
      (context) => OrientationUtils.getCurrentOrientation(context),
    ),
  ]) {
    testWidgets('$name is not rebuilt by the keyboard', (tester) async {
      expect(await buildsWhileTheKeyboardOpens(tester, read), isEmpty);
    });
  }

  testWidgets('the safe paddings follow the padding only: once, when the '
      'keyboard covers the navigation bar', (tester) async {
    final builds = await buildsWhileTheKeyboardOpens(
      tester,
      (context) => (context.safePaddingTop, context.safePaddingBottom),
    );
    expect(builds, [(0.0, 0.0)]);
  });
}
