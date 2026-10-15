import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_marquee.dart';

const _duration = Duration(milliseconds: 3000);
final _moving = find.byKey(const ValueKey('ht-marquee'));
final _content = find.byKey(const ValueKey('ht-marquee-content'));

Future<void> pumpMarquee(
  WidgetTester tester,
  String text, {
  TextDirection direction = TextDirection.ltr,
  bool reduceMotion = false,
}) => tester.pumpWidget(
  MaterialApp(
    home: Directionality(
      textDirection: direction,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 300,
          height: 74,
          child: HypeTrainMarquee(
            text: text,
            duration: _duration,
            reduceMotion: reduceMotion,
            style: const TextStyle(fontSize: 24),
          ),
        ),
      ),
    ),
  ),
);

double marqueeX(WidgetTester tester) =>
    tester.widget<Transform>(_moving).transform.getTranslation().x;

void main() {
  testWidgets('it starts past the trailing edge and leaves 42 dp past the '
      'leading edge', (tester) async {
    await pumpMarquee(tester, 'hyyyyypeeee');
    final width = tester.getSize(_content).width;

    expect(marqueeX(tester), 300);
    expect(tester.getTopLeft(_content).dx, 300);

    await tester.pump(_duration ~/ 2);
    expect(marqueeX(tester), closeTo(300 - (300 + width + 42) / 2, 0.5));

    await tester.pump(_duration ~/ 2);
    expect(marqueeX(tester), closeTo(-(width + 42), 0.5));
  });

  testWidgets('a line wider than the banner travels the whole way', (
    tester,
  ) async {
    await pumpMarquee(tester, 'Hype Train success! Hype Train success!');
    final width = tester.getSize(_content).width;
    expect(width, greaterThan(300));

    await tester.pump(_duration);
    expect(tester.getTopRight(_content).dx, closeTo(-42, 0.5));
  });

  testWidgets('right to left it runs the other way', (tester) async {
    await pumpMarquee(tester, 'hyyyyypeeee', direction: TextDirection.rtl);
    final width = tester.getSize(_content).width;

    expect(marqueeX(tester), -300);
    expect(tester.getTopRight(_content).dx, 0);

    await tester.pump(_duration);
    expect(marqueeX(tester), closeTo(width + 42, 0.5));
    expect(tester.getTopLeft(_content).dx, closeTo(342, 0.5));
  });

  testWidgets('reduced motion: still and centred', (tester) async {
    await pumpMarquee(tester, 'hyyyyypeeee', reduceMotion: true);

    expect(_moving, findsNothing);
    expect(tester.getCenter(_content), const Offset(150, 37));
  });
}
