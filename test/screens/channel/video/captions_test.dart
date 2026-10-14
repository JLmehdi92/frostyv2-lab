import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/channel/video/captions.dart';

void main() {
  test('a cue becomes one tidy line for its own length', () {
    final caption = captionFromEvent({
      'text': ' Hello\n  world ',
      'startMs': 1000,
      'endMs': 2500,
    })!;
    expect(caption.text, 'Hello world');
    expect(caption.shownFor, const Duration(milliseconds: 1500));
  });

  test('odd lengths are kept between one and eight seconds', () {
    expect(
      captionFromEvent({'text': 'a', 'startMs': 0, 'endMs': 10})!.shownFor,
      const Duration(seconds: 1),
    );
    expect(
      captionFromEvent({'text': 'a', 'startMs': 0, 'endMs': 60000})!.shownFor,
      kCaptionMaxShown,
    );
    expect(
      captionFromEvent({'text': 'a'})!.shownFor,
      const Duration(seconds: 4),
    );
  });

  test('empty or odd cues show nothing, long ones are cut', () {
    expect(captionFromEvent({'text': '   '}), isNull);
    expect(captionFromEvent({'text': 5}), isNull);
    expect(captionFromEvent({}), isNull);
    expect(captionFromEvent({'text': 'x' * 500})!.text, hasLength(300));
  });

  testWidgets('the line is announced to screen readers', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CaptionText(text: 'Hi')),
      ),
    );
    expect(find.text('Hi'), findsOneWidget);
    final semantics = tester.getSemantics(find.byType(CaptionText));
    expect(semantics.flagsCollection.isLiveRegion, isTrue);
  });
}
