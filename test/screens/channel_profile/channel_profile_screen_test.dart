import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/apis/twitch_channel_profile_service.dart';
import 'package:frosty/apis/twitch_clip_service.dart';
import 'package:frosty/apis/twitch_vod_service.dart';
import 'package:frosty/models/channel_profile.dart';
import 'package:frosty/models/clip.dart';
import 'package:frosty/models/user.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/channel_profile/channel_profile_screen.dart';
import 'package:frosty/screens/channel_profile/widgets/profile_header.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../fixtures/channel_profile_payloads.dart';

class MockProfileService extends Mock implements TwitchChannelProfileService {}

class MockTwitchApi extends Mock implements TwitchApi {}

class MockVodService extends Mock implements TwitchVodService {}

class MockClipService extends Mock implements TwitchClipService {}

void main() {
  late MockProfileService profiles;
  late MockTwitchApi helix;
  late MockVodService vods;
  late MockClipService clips;
  late List<MethodCall> clipboard;

  setUpAll(() {
    registerFallbackValue(VodType.archive);
    registerFallbackValue(ClipPeriod.lastWeek);
    registerFallbackValue(ClipSort.top);
  });

  setUp(() {
    profiles = MockProfileService();
    helix = MockTwitchApi();
    vods = MockVodService();
    clips = MockClipService();
    when(
      () => vods.getChannelVideos(
        login: any(named: 'login'),
        type: any(named: 'type'),
      ),
    ).thenAnswer((_) async => const VodPage(items: [], hasMore: false));
    when(
      () => clips.getChannelClips(
        login: any(named: 'login'),
        period: any(named: 'period'),
        sort: any(named: 'sort'),
      ),
    ).thenAnswer((_) async => const ClipPage(items: [], hasMore: false));
    when(
      () => profiles.getSchedule(any()),
    ).thenAnswer((_) async => ChannelSchedule.empty);
    clipboard = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') clipboard.add(call);
          return null;
        });
  });

  Future<void> pump(
    WidgetTester tester, {
    ProfileTab tab = ProfileTab.home,
    bool fromChannel = false,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SettingsStore>.value(value: SettingsStore.fromJson({})),
          Provider<TwitchChannelProfileService>.value(value: profiles),
          Provider<TwitchApi>.value(value: helix),
          Provider<TwitchVodService>.value(value: vods),
          Provider<TwitchClipService>.value(value: clips),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => ChannelProfileScreen.open(
                  context,
                  login: 'xqc',
                  displayName: 'xQc',
                  initialTab: tab,
                  fromChannel: fromChannel,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  void answerProfile() => when(() => profiles.getProfile(any())).thenAnswer(
    (_) async => ChannelProfile.fromGql(
      (jsonDecode(gqlChannelProfileXqc) as Map)['data']['user'],
    ),
  );

  testWidgets('the header, the five tabs and About', (tester) async {
    answerProfile();
    await pump(tester);

    expect(find.byType(ProfileHeader), findsOneWidget);
    for (final tab in ProfileTab.values) {
      expect(find.widgetWithText(Tab, tab.label), findsOneWidget);
    }
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('Watch'), findsOneWidget);

    await tester.tap(find.widgetWithText(Tab, 'About'));
    await tester.pumpAndSettle();
    expect(find.textContaining('THE BEST AT ABSOLUTELY'), findsOneWidget);
    verifyNever(() => profiles.getSchedule(any()));
  });

  testWidgets('the schedule loads when its tab first shows', (tester) async {
    answerProfile();
    await pump(tester, tab: ProfileTab.schedule);
    verify(() => profiles.getSchedule('xqc')).called(1);
    expect(find.text('No streams scheduled'), findsOneWidget);
  });

  testWidgets('Share copies the channel link', (tester) async {
    answerProfile();
    await pump(tester);
    await tester.tap(find.text('Share'));
    await tester.pump();
    expect(
      (clipboard.single.arguments as Map)['text'],
      'https://www.twitch.tv/xqc',
    );
    expect(find.text('Link copied'), findsOneWidget);
  });

  testWidgets('from the channel screen, Watch goes back to it', (tester) async {
    answerProfile();
    await pump(tester, fromChannel: true);
    await tester.tap(find.text('Watch'));
    await tester.pumpAndSettle();
    expect(find.byType(ChannelProfileScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('a broken profile query still shows the Helix header', (
    tester,
  ) async {
    when(
      () => profiles.getProfile(any()),
    ).thenThrow(const ChannelProfileApiException('schema'));
    when(
      () => helix.getUser(userLogin: any(named: 'userLogin')),
    ).thenAnswer((_) async => const UserTwitch('71092938', 'xqc', 'xQc', ''));
    await pump(tester);

    expect(find.text("Couldn't load this channel's profile"), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.byTooltip('More'), findsOneWidget);
  });

  testWidgets('an unknown channel says so', (tester) async {
    when(() => profiles.getProfile(any())).thenAnswer((_) async => null);
    await pump(tester);
    expect(find.text('Channel not found'), findsOneWidget);
  });

  testWidgets('fits a phone, a landscape phone and the Pad 7', (tester) async {
    answerProfile();
    for (final size in const [
      Size(360, 740),
      Size(800, 360),
      Size(1600, 1067),
    ]) {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const SizedBox());
      await pump(tester);
      expect(tester.takeException(), isNull, reason: '$size');
      // The header scrolls away; the tab bar stays.
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();
      for (final tab in ProfileTab.values) {
        await tester.tap(find.widgetWithText(Tab, tab.label));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$size ${tab.label}');
      }
    }
  });
}
