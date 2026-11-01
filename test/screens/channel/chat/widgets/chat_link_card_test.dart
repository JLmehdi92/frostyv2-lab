import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_clip_service.dart';
import 'package:onset/apis/twitch_vod_service.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/clip.dart';
import 'package:onset/models/vod.dart';
import 'package:onset/screens/channel/chat/widgets/chat_link_card.dart';
import 'package:onset/utils/link_router.dart';
import 'package:onset/utils/twitch_links.dart';
import 'package:onset/widgets/skeleton_loader.dart';
import 'package:provider/provider.dart';

class MockClipService extends Mock implements TwitchClipService {}

class MockVodService extends Mock implements TwitchVodService {}

Clip clip({String? thumbnail}) => Clip(
  id: '1',
  slug: 'FunnySlug-abc',
  title: 'What a play',
  viewCount: 1500,
  createdAt: DateTime.utc(2026),
  durationSeconds: 30,
  broadcasterId: '2',
  broadcasterLogin: 'streamer',
  broadcasterDisplayName: 'Streamer',
  thumbnailUrl: thumbnail,
);

void main() {
  late MockClipService clips;
  late MockVodService vods;

  setUp(() {
    ChatLinkPreviews.clear();
    clips = MockClipService();
    vods = MockVodService();
  });

  group('chatPreviewLink', () {
    test('the first clip or video link of a message', () {
      expect(
        chatPreviewLink('look https://clips.twitch.tv/FunnySlug-abc lol')?.link,
        const ClipLink('FunnySlug-abc'),
      );
      expect(
        chatPreviewLink('twitch.tv/videos/123456789!')?.link,
        const VodLink('123456789'),
      );
      final found = chatPreviewLink(
        'twitch.tv/xqc then https://www.twitch.tv/xqc/clip/Other-x',
      )!;
      expect(found.link, const ClipLink('Other-x'));
      expect(found.url, 'https://www.twitch.tv/xqc/clip/Other-x');
    });

    test('channels, other sites and plain text have no card', () {
      expect(chatPreviewLink('https://twitch.tv/xqc'), isNull);
      expect(chatPreviewLink('https://youtube.com/watch?v=1'), isNull);
      expect(chatPreviewLink('hello'), isNull);
      expect(chatPreviewLink(null), isNull);
    });
  });

  group('ChatLinkPreviews', () {
    test('the same clip is asked for once', () async {
      when(() => clips.getClip(any())).thenAnswer((_) async => clip());
      const link = ClipLink('FunnySlug-abc');

      final first = await ChatLinkPreviews.load(link, clips: clips, vods: vods);
      await ChatLinkPreviews.load(link, clips: clips, vods: vods);

      expect(first?.titleIn(L10n.english), 'What a play');
      expect(first?.channel, 'Streamer');
      expect(first?.detailIn(L10n.english), 'Clip · 0:30 · 1.5K views');
      verify(() => clips.getClip('FunnySlug-abc')).called(1);
    });

    test('a failure is kept a minute, then asked for again', () async {
      when(
        () => clips.getClip(any()),
      ).thenThrow(const ClipApiException('down'));
      const link = ClipLink('FunnySlug-abc');
      var now = DateTime.utc(2026, 1, 1, 12);

      await withClock(Clock(() => now), () async {
        expect(
          await ChatLinkPreviews.load(link, clips: clips, vods: vods),
          isNull,
        );
        await ChatLinkPreviews.load(link, clips: clips, vods: vods);
        verify(() => clips.getClip('FunnySlug-abc')).called(1);

        now = now.add(const Duration(seconds: 61));
        await ChatLinkPreviews.load(link, clips: clips, vods: vods);
        verify(() => clips.getClip('FunnySlug-abc')).called(1);
      });
    });

    test('the same clip posted at once is asked for once', () async {
      final pending = Completer<Clip?>();
      when(() => clips.getClip(any())).thenAnswer((_) => pending.future);
      const link = ClipLink('FunnySlug-abc');

      final first = ChatLinkPreviews.load(link, clips: clips, vods: vods);
      final second = ChatLinkPreviews.load(link, clips: clips, vods: vods);
      pending.complete(clip());

      expect((await first)?.titleIn(L10n.english), 'What a play');
      expect((await second)?.titleIn(L10n.english), 'What a play');
      verify(() => clips.getClip('FunnySlug-abc')).called(1);
    });

    test('a video is one entry whatever its start time', () async {
      when(() => vods.getVideo(any())).thenAnswer((_) async => null);

      await ChatLinkPreviews.load(
        const VodLink('9', startAt: Duration(hours: 1)),
        clips: clips,
        vods: vods,
      );
      await ChatLinkPreviews.load(
        const VodLink('9', startAt: Duration(hours: 2)),
        clips: clips,
        vods: vods,
      );

      verify(() => vods.getVideo('9')).called(1);
    });

    test(
      'three at a time; the oldest waiting is dropped when many wait',
      () async {
        final answers = <String, Completer<Clip?>>{};
        when(() => clips.getClip(any())).thenAnswer(
          (invocation) =>
              (answers[invocation.positionalArguments.single as String] =
                      Completer<Clip?>())
                  .future,
        );

        final loads = [
          for (var i = 0; i < 12; i++)
            ChatLinkPreviews.load(ClipLink('Slug$i'), clips: clips, vods: vods),
        ];
        await pumpEventQueue();

        expect(answers.keys, ['Slug0', 'Slug1', 'Slug2']);
        // 9 waited, one too many: the oldest (Slug3) gave up.
        expect(await loads[3], isNull);

        answers['Slug0']!.complete(clip());
        await pumpEventQueue();
        expect(answers.keys, contains('Slug4'));
        expect(answers.keys, isNot(contains('Slug3')));
      },
    );

    test('the most recently used are kept', () async {
      when(() => clips.getClip(any())).thenAnswer(
        (_) async => clip(thumbnail: 'https://static-cdn.jtvnw.net/a.jpg'),
      );
      Future<void> load(String slug) =>
          ChatLinkPreviews.load(ClipLink(slug), clips: clips, vods: vods);

      for (var i = 0; i < 64; i++) {
        await load('Slug$i');
      }
      await load('Slug0');
      await load('Slug64');
      await load('Slug0');
      await load('Slug1');

      verify(() => clips.getClip('Slug0')).called(1);
      verify(() => clips.getClip('Slug1')).called(2);
    });

    test('only the newest previews are kept', () async {
      when(() => clips.getClip(any())).thenAnswer((_) async => clip());
      for (var i = 0; i < 70; i++) {
        await ChatLinkPreviews.load(
          ClipLink('Slug$i'),
          clips: clips,
          vods: vods,
        );
      }
      await ChatLinkPreviews.load(
        const ClipLink('Slug69'),
        clips: clips,
        vods: vods,
      );
      await ChatLinkPreviews.load(
        const ClipLink('Slug0'),
        clips: clips,
        vods: vods,
      );

      verify(() => clips.getClip('Slug69')).called(1);
      verify(() => clips.getClip('Slug0')).called(2);
    });

    test('a video', () async {
      when(() => vods.getVideo(any())).thenAnswer(
        (_) async => Vod(
          id: '9',
          title: 'Marathon',
          lengthSeconds: 3725,
          createdAt: DateTime.utc(2026),
          viewCount: 1,
          ownerId: '2',
          ownerLogin: 'streamer',
          ownerDisplayName: 'Streamer',
          previewThumbnailUrl:
              'https://vod-secure.twitch.tv/_404/404_processing_320x180.png',
        ),
      );

      final preview = await ChatLinkPreviews.load(
        const VodLink('9'),
        clips: clips,
        vods: vods,
      );

      expect(preview?.detailIn(L10n.english), 'Video · 1:02:05 · 1 view');
      expect(preview?.thumbnailUrl, isNull);
    });
  });

  group('ChatLinkCard', () {
    Future<void> pumpCard(WidgetTester tester) => tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<TwitchClipService>.value(value: clips),
          Provider<TwitchVodService>.value(value: vods),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ChatLinkCard(
              link: ClipLink('FunnySlug-abc'),
              url: 'https://clips.twitch.tv/FunnySlug-abc',
            ),
          ),
        ),
      ),
    );

    testWidgets('keeps its height from loading to loaded, and opens the clip', (
      tester,
    ) async {
      final pending = Completer<Clip?>();
      when(() => clips.getClip(any())).thenAnswer((_) => pending.future);
      final opened = <TwitchLink>[];
      LinkRouter.inAppHandler = (link) async {
        opened.add(link);
        return true;
      };
      addTearDown(() => LinkRouter.inAppHandler = null);

      await pumpCard(tester);
      expect(
        tester.getSize(find.byType(ChatLinkCard)).height,
        ChatLinkCard.height,
      );

      pending.complete(clip(thumbnail: 'https://evil.example/x.jpg'));
      await tester.pump();

      expect(find.text('What a play'), findsOneWidget);
      expect(find.text('Streamer'), findsOneWidget);
      expect(
        tester.getSize(find.byType(ChatLinkCard)).height,
        ChatLinkCard.height,
      );
      // A thumbnail off Twitch is not loaded.
      expect(find.byIcon(Icons.movie_outlined), findsOneWidget);

      await tester.tap(find.text('What a play'));
      await tester.pump();
      expect(opened, [const ClipLink('FunnySlug-abc')]);
    });

    testWidgets('a clip that is gone takes no room', (tester) async {
      when(() => clips.getClip(any())).thenAnswer((_) async => null);

      await pumpCard(tester);
      await tester.pump();

      expect(find.byType(InkWell), findsNothing);
      expect(tester.getSize(find.byType(ChatLinkCard)).height, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a known clip draws at once, without a loading frame', (
      tester,
    ) async {
      when(() => clips.getClip(any())).thenAnswer((_) async => clip());
      await ChatLinkPreviews.load(
        const ClipLink('FunnySlug-abc'),
        clips: clips,
        vods: vods,
      );

      await pumpCard(tester);

      expect(find.byType(SkeletonLoader), findsNothing);
      expect(find.text('What a play'), findsOneWidget);
    });

    testWidgets('a card given another link shows that link', (tester) async {
      when(() => clips.getClip('A')).thenAnswer((_) async => clip());
      when(() => clips.getClip('B')).thenAnswer(
        (_) async => Clip(
          id: '3',
          slug: 'B',
          title: 'Another one',
          viewCount: 1,
          createdAt: DateTime.utc(2026),
          durationSeconds: 5,
          broadcasterId: '2',
          broadcasterLogin: 'streamer',
          broadcasterDisplayName: 'Streamer',
        ),
      );
      Widget card(String slug) => MultiProvider(
        providers: [
          Provider<TwitchClipService>.value(value: clips),
          Provider<TwitchVodService>.value(value: vods),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ChatLinkCard(
              link: ClipLink(slug),
              url: 'https://clips.twitch.tv/$slug',
            ),
          ),
        ),
      );

      await tester.pumpWidget(card('A'));
      await tester.pump();
      expect(find.text('What a play'), findsOneWidget);

      await tester.pumpWidget(card('B'));
      await tester.pump();
      expect(find.text('Another one'), findsOneWidget);
      expect(find.text('What a play'), findsNothing);
    });
  });
}
