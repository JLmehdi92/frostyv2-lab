import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/apis/twitch_clip_service.dart';
import 'package:frosty/apis/twitch_hype_train_service.dart';
import 'package:frosty/apis/twitch_vod_service.dart';
import 'package:frosty/models/category.dart';
import 'package:frosty/models/clip.dart';
import 'package:frosty/models/stream.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/clips/widgets/clip_card.dart';
import 'package:frosty/screens/home/top/categories/category_streams.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/vod/widgets/vod_card.dart';
import 'package:frosty/theme.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

class MockAuthStore extends Mock implements AuthStore {}

class MockVodService extends Mock implements TwitchVodService {}

class MockClipService extends Mock implements TwitchClipService {}

class MockHypeTrainService extends Mock implements TwitchHypeTrainService {}

void main() {
  late MockTwitchApi helix;
  late MockVodService vods;
  late MockClipService clips;

  setUpAll(() {
    registerFallbackValue(ClipPeriod.lastWeek);
    registerFallbackValue(ClipSort.top);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    helix = MockTwitchApi();
    vods = MockVodService();
    clips = MockClipService();
    // The live list stays loading: these tests are about the sections.
    when(
      () => helix.getCategory(gameId: any(named: 'gameId')),
    ).thenAnswer((_) => Completer<CategoriesTwitch>().future);
    when(
      () => helix.getStreamsUnderCategory(
        gameId: any(named: 'gameId'),
        cursor: any(named: 'cursor'),
      ),
    ).thenAnswer((_) => Completer<StreamsTwitch>().future);
    when(() => vods.getCategoryVideos(any())).thenAnswer(
      (_) async => VodPage(
        items: [
          Vod(
            id: '9',
            title: 'Heist',
            lengthSeconds: 3600,
            createdAt: DateTime.utc(2026),
            viewCount: 5,
            ownerId: '42',
            ownerLogin: 'streamer',
            ownerDisplayName: 'Streamer',
            gameName: 'Grand Theft Auto V',
          ),
        ],
        hasMore: false,
      ),
    );
    when(
      () => clips.getCategoryClips(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        sort: any(named: 'sort'),
      ),
    ).thenAnswer(
      (_) async => ClipPage(
        items: [
          Clip(
            id: '1',
            slug: 'Slug',
            title: 'Wow',
            viewCount: 1,
            createdAt: DateTime.utc(2026),
            durationSeconds: 30,
            broadcasterId: '43',
            broadcasterLogin: 'other',
            broadcasterDisplayName: 'Other',
            gameName: 'Grand Theft Auto V',
          ),
        ],
        hasMore: false,
      ),
    );
  });

  testWidgets('live first, then the category\'s videos and clips', (
    tester,
  ) async {
    final auth = MockAuthStore();
    when(() => auth.isLoggedIn).thenReturn(false);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SettingsStore>.value(value: SettingsStore.fromJson({})),
          Provider<AuthStore>.value(value: auth),
          Provider<TwitchApi>.value(value: helix),
          Provider<TwitchVodService>.value(value: vods),
          Provider<TwitchClipService>.value(value: clips),
          Provider<TwitchHypeTrainService>.value(value: MockHypeTrainService()),
        ],
        child: MaterialApp(
          theme: ThemeData(extensions: const [FrostyColors.light]),
          home: const CategoryStreams(categoryId: '32982'),
        ),
      ),
    );
    await tester.pump();
    expect(find.widgetWithText(ChoiceChip, 'Live'), findsOneWidget);
    verifyNever(() => vods.getCategoryVideos(any()));

    await tester.tap(find.widgetWithText(ChoiceChip, 'Videos'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(VodCard), findsOneWidget);
    expect(find.text('Streamer'), findsOneWidget);
    verify(() => vods.getCategoryVideos('32982')).called(1);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Clips'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ClipCard), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
