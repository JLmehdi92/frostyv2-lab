import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_clip_service.dart';
import 'package:frosty/apis/twitch_vod_service.dart';
import 'package:frosty/models/clip.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/channel/chat/widgets/chat_link_card.dart';
import 'package:frosty/utils/link_router.dart';
import 'package:frosty/utils/twitch_links.dart';
import 'package:mocktail/mocktail.dart';
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

      expect(first?.title, 'What a play');
      expect(first?.channel, 'Streamer');
      expect(first?.detail, 'Clip · 0:30 · 1.5K views');
      verify(() => clips.getClip('FunnySlug-abc')).called(1);
    });

    test('a failure is not kept, so a later message tries again', () async {
      when(
        () => clips.getClip(any()),
      ).thenThrow(const ClipApiException('down'));
      const link = ClipLink('FunnySlug-abc');

      expect(
        await ChatLinkPreviews.load(link, clips: clips, vods: vods),
        isNull,
      );
      await ChatLinkPreviews.load(link, clips: clips, vods: vods);

      verify(() => clips.getClip('FunnySlug-abc')).called(2);
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

      expect(preview?.detail, 'Video · 1:02:05 · 1 view');
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

    testWidgets('a clip that is gone shows nothing', (tester) async {
      when(() => clips.getClip(any())).thenAnswer((_) async => null);

      await pumpCard(tester);
      await tester.pump();

      expect(find.byType(InkWell), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
