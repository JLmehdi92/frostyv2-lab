import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart' show ObservableList;
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_clip_service.dart';
import 'package:onset/models/clip.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/models/video_collection.dart';
import 'package:onset/screens/channel/chat/widgets/channel_points_sheet.dart';
import 'package:onset/screens/channel_profile/channel_preferences_screen.dart';
import 'package:onset/screens/channel_profile/widgets/profile_collections_tab.dart';
import 'package:onset/screens/clips/my_clips_screen.dart';
import 'package:onset/screens/clips/stores/channel_clips_store.dart';
import 'package:onset/screens/clips/widgets/clip_filter_bar.dart';
import 'package:onset/screens/home/stream_list/stores/stream_list_store.dart';
import 'package:onset/screens/home/stream_list/stream_filter_chips.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/stores/user_store.dart';
import 'package:onset/screens/settings/widgets/chat_bubbles_setting.dart';
import 'package:provider/provider.dart';

import '../helpers/l10n.dart';

class MockClipService extends Mock implements TwitchClipService {}

class MockTwitchApi extends Mock implements TwitchApi {}

class MockAuthStore extends Mock implements AuthStore {}

class MockUserStore extends Mock implements UserStore {}

const _content = ['xQc', 'Speedrun', 'Chill', 'Speedruns'];

void main() {
  late MockClipService clips;
  late MockTwitchApi helix;
  late MockAuthStore auth;
  late SettingsStore settings;

  setUpAll(() {
    registerFallbackValue(ClipPeriod.lastWeek);
    registerFallbackValue(ClipSort.top);
  });

  setUp(() {
    clips = MockClipService();
    helix = MockTwitchApi();
    auth = MockAuthStore();
    final user = MockUserStore();
    when(() => auth.user).thenReturn(user);
    when(() => user.blockedUsers).thenReturn(ObservableList());
    settings = SettingsStore.fromJson({
      'chatBubbleEvents': ['subs', 'raids'],
    });
    when(
      () => clips.getChannelClips(
        login: any(named: 'login'),
        period: any(named: 'period'),
        sort: any(named: 'sort'),
      ),
    ).thenAnswer((_) async => const ClipPage(items: [], hasMore: false));
    when(
      () => clips.getCuratedClips(
        curatorId: any(named: 'curatorId'),
        period: any(named: 'period'),
        sort: any(named: 'sort'),
      ),
    ).thenAnswer((_) async => const ClipPage(items: [], hasMore: false));
  });

  Future<Map<String, Widget Function()>> screens() async {
    final ranged = ChannelClipsStore(
      login: 'xqc',
      clipService: clips,
      clipsBetween: (_, _) async => const [],
    );
    await ranged.selectRange(DateTime(2026, 3, 3), DateTime(2026, 3, 10));
    final list = ListStore(
      authStore: auth,
      settingsStore: settings,
      twitchApi: helix,
      listType: ListType.top,
      loadStreams: false,
    )..tagFilter = 'Speedrun';
    return {
      'the collections tab': () => Scaffold(
        body: ProfileCollectionsTab(
          collections: [
            VideoCollection(
              id: 'a',
              title: 'Speedruns',
              itemCount: 12,
              firstVideoId: '1',
              updatedAt: DateTime.now().subtract(const Duration(days: 2)),
              lengthSeconds: 7200,
            ),
          ],
          onOpen: (_) {},
          onRefresh: () async {},
        ),
      ),
      'the clip filters with dates': () =>
          Scaffold(body: ClipFilterBar(store: ranged)),
      'my clips': () => const MyClipsScreen(login: 'xqc', userId: '7'),
      'the live list filters': () =>
          Scaffold(body: StreamFilterChips(store: list)),
      'the event bubbles sheet': () =>
          Scaffold(body: ChatBubblesSheet(settingsStore: settings)),
      'the event bubbles row': () =>
          Scaffold(body: ChatBubblesSetting(settingsStore: settings)),
      'the channel preferences': () => Scaffold(
        body: ChannelPreferencesScreen(
          channelId: '42',
          name: 'xQc',
          settingsStore: settings,
          loggedIn: false,
        ),
      ),
      'the Bits and gifts': () => const Scaffold(
        body: ViewerTallies(bitsBalance: 1250, giftedHere: 25),
      ),
    };
  }

  Widget providers(Widget app) => MultiProvider(
    providers: [
      Provider<TwitchClipService>.value(value: clips),
      Provider<TwitchApi>.value(value: helix),
    ],
    child: app,
  );

  for (final (sizeName, size) in frenchScreenSizes) {
    for (final scale in frenchTextScales) {
      final at = '$sizeName, text ×$scale';
      testWidgets('lot 6b screens, $at', (tester) async {
        final built = (await tester.runAsync(screens))!;
        for (final MapEntry(key: name, value: build) in built.entries) {
          await pumpLocalized(
            tester,
            build(),
            size: size,
            textScale: scale,
            wrap: providers,
          );
          for (var i = 0; i < 6; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          await expectFrenchThroughout(tester, '$name, $at', content: _content);
        }
      });
    }
  }

  test('the stream fixture keeps its tags', () {
    const stream = StreamTwitch(
      '1',
      'a',
      'A',
      '1',
      'G',
      'T',
      1,
      '',
      '',
      tags: ['Speedrun'],
    );
    expect(stream.tags, ['Speedrun']);
  });
}
