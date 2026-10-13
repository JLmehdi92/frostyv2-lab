import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/onboarding/onboarding_scaffold.dart';

void main() {
  Future<List<Object?>> orientationRequestsAt(
    WidgetTester tester,
    Size size,
  ) async {
    final requests = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          requests.add(call.arguments);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: OnboardingScaffold(header: 'Hi', route: SizedBox()),
      ),
    );
    return requests;
  }

  testWidgets('a phone is held in portrait during onboarding', (tester) async {
    final requests = await orientationRequestsAt(tester, const Size(360, 740));
    expect(requests.last, [
      'DeviceOrientation.portraitUp',
      'DeviceOrientation.portraitDown',
    ]);
  });

  testWidgets('a tablet keeps the orientation it is in', (tester) async {
    final requests = await orientationRequestsAt(
      tester,
      const Size(1600, 1067),
    );
    expect(requests.last, <String>[]);
  });
}
