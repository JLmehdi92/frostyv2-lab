import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_clip_service.dart';
import 'package:onset/apis/twitch_vod_service.dart';
import 'package:onset/models/clip.dart';
import 'package:onset/models/vod.dart';
import 'package:onset/screens/channel/video/live_progress.dart';
import 'package:onset/screens/clips/widgets/channel_clips_tab.dart';
import 'package:onset/screens/vod/channel_videos.dart';
import 'package:onset/screens/vod/vod_resume.dart';
import 'package:onset/screens/vod/widgets/vod_card.dart';
import 'package:onset/theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockVodService extends Mock implements TwitchVodService {}

class MockClipService extends Mock implements TwitchClipService {}

Vod _vod(String id, VodType type) => Vod(
  id: id,
  title: '${type.name} $id',
  lengthSeconds: 3600,
  createdAt: DateTime.utc(2026),
  viewCount: 1,
  ownerId: '42',
  ownerLogin: 'streamer',
  ownerDisplayName: 'Streamer',
  type: type,
);

void main() {
  late MockVodService vods;
  late MockClipService clips;

  setUpAll(() {
    registerFallbackValue(VodType.archive);
    registerFallbackValue(ClipPeriod.lastWeek);
    registerFallbackValue(ClipSort.top);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VodResumeRepository.shared.resetQueue();
    LiveProgressRepository.shared.resetQueue();
    vods = MockVodService();
    clips = MockClipService();
    when(
      () => vods.getChannelVideos(
        login: any(named: 'login'),
        type: any(named: 'type'),
      ),
    ).thenAnswer((invocation) async {
      final type = invocation.namedArguments[#type] as VodType;
      return VodPage(
        items: [for (var i = 0; i < 4; i++) _vod('$i', type)],
        hasMore: false,
      );
    });
    when(
      () => clips.getChannelClips(
        login: any(named: 'login'),
        period: any(named: 'period'),
        sort: any(named: 'sort'),
      ),
    ).thenAnswer((_) async => const ClipPage(items: [], hasMore: false));
  });

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    bool startOnClips = false,
    Brightness brightness = Brightness.dark,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<TwitchApi>.value(value: MockTwitchApi()),
          Provider<TwitchVodService>.value(value: vods),
          Provider<TwitchClipService>.value(value: clips),
        ],
        child: MaterialApp(
          theme: ThemeData(
            brightness: brightness,
            extensions: [
              brightness == Brightness.dark
                  ? OnsetColors.dark
                  : OnsetColors.light,
            ],
          ),
          home: ChannelVideosScreen(
            userLogin: 'streamer',
            displayName: 'Streamer',
            startOnClips: startOnClips,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the channel, "· Videos" and the four tabs', (tester) async {
    await pump(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Streamer · Videos', findRichText: true), findsOneWidget);
    for (final tab in ['Past broadcasts', 'Highlights', 'Uploads', 'Clips']) {
      expect(find.text(tab), findsOneWidget, reason: tab);
    }
    expect(find.text('archive 0'), findsOneWidget);
    expect(tester.widget<VodCard>(find.byType(VodCard).first).tile, isFalse);
  });

  testWidgets('a tab tap and a swipe both change the list', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Highlights'));
    await tester.pumpAndSettle();
    expect(find.text('highlight 0'), findsOneWidget);

    await tester.fling(find.text('highlight 0'), const Offset(-300, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('upload 0'), findsOneWidget);
  });

  testWidgets('a clips link opens on Clips', (tester) async {
    await pump(tester, startOnClips: true);

    expect(find.byType(ChannelClipsTab), findsOneWidget);
    expect(find.text('No clips for this period'), findsOneWidget);
  });

  testWidgets('a tablet lays the videos out in tiles, light theme too', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      for (final size in const [Size(1280, 854), Size(854, 1280)]) {
        await tester.pumpWidget(const SizedBox());
        await pump(tester, size: size, brightness: brightness);

        expect(tester.takeException(), isNull);
        final cards = find.byType(VodCard);
        expect(tester.widget<VodCard>(cards.first).tile, isTrue);
        expect(
          tester.getTopLeft(cards.at(1)).dy,
          tester.getTopLeft(cards.at(0)).dy,
          reason: 'tiles share a row',
        );
      }
    }
  });
}
