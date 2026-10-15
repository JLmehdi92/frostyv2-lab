import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/onboarding/onboarding_scaffold.dart';

void main() {
  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: OnboardingScaffold(
          header: 'ONSET',
          subtitle:
              'A mobile Twitch client with 7TV, BetterTTV (BTTV), and '
              'FrankerFaceZ (FFZ) support.',
          showLogo: true,
          disclaimer: 'v1.0.0 (1)',
          disclaimerIsMetadata: true,
          content: Center(child: Text('content')),
          buttonText: 'Next',
          route: SizedBox(),
          skipRoute: SizedBox(),
        ),
      ),
    );
    await tester.pump();
  }

  for (final (name, size) in const [
    ('a 390x844 phone', Size(390, 844)),
    ('a landscape phone', Size(844, 390)),
  ]) {
    testWidgets('fits $name without overflowing', (tester) async {
      await pumpAt(tester, size);

      expect(tester.takeException(), isNull);
      expect(find.text('ONSET'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
    });
  }
}
