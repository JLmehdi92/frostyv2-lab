import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/channel/video/captions.dart';

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

  group('caption tracks', () {
    test("reads the player's tracks and the selected one", () {
      final tracks = captionTracksFromEvent({
        'type': 'textTracks',
        'list': [
          {'id': 'cc1', 'label': 'English CC', 'language': 'en'},
          {'id': 'cc2', 'label': '', 'language': 'es-419'},
          {'id': 'cc3'},
          'junk',
          {'label': 'no id'},
        ],
        'selected': 'cc2',
      });

      expect(tracks.list.map((t) => t.id), ['cc1', 'cc2', 'cc3']);
      expect(tracks.selected, 'cc2');
      expect(tracks.list[0].name, 'English CC');
      // Without a label: the language, else a numbered name.
      expect(tracks.list[1].name, 'es-419');
      expect(tracks.list[2].name, 'Captions 3');
    });

    test('nothing readable is no track', () {
      expect(captionTracksFromEvent({}).list, isEmpty);
      expect(captionTracksFromEvent({'list': 5}).list, isEmpty);
      expect(captionTracksFromEvent({'list': []}).selected, isNull);
    });
  });

  group('caption style', () {
    testWidgets("the default is Twitch's: white 15 on black", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: CaptionText(text: 'Hi')),
        ),
      );
      final text = tester.widget<Text>(find.text('Hi'));
      expect(text.style?.fontSize, 15);
      expect(text.style?.color, Colors.white);
      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(CaptionText),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect((box.decoration as BoxDecoration).color, Colors.black);
    });

    testWidgets('size and background follow the setting', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CaptionText(
              text: 'Hi',
              size: CaptionSize.large,
              background: CaptionBackground.none,
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(find.text('Hi'));
      expect(text.style?.fontSize, CaptionSize.large.fontSize);
      // No box: an outline keeps the words readable on any picture.
      expect(text.style?.shadows, isNotEmpty);
      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(CaptionText),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect((box.decoration as BoxDecoration).color, isNull);
    });
  });
}

