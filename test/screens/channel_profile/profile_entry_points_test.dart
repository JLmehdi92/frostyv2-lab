import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/apis/twitch_channel_profile_service.dart';
import 'package:frosty/apis/twitch_clip_service.dart';
import 'package:frosty/apis/twitch_vod_service.dart';
import 'package:frosty/models/channel_profile.dart';
import 'package:frosty/models/clip.dart';
import 'package:frosty/models/followed_channel.dart';
import 'package:frosty/models/user.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/channel/video/stream_info_bar.dart';
import 'package:frosty/screens/channel_profile/channel_profile_screen.dart';
import 'package:frosty/screens/home/stream_list/offline_channel_card.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/widgets/user_actions_modal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockProfileService extends Mock implements TwitchChannelProfileService {}

class MockTwitchApi extends Mock implements TwitchApi {}

class MockVodService extends Mock implements TwitchVodService {}

class MockClipService extends Mock implements TwitchClipService {}

class MockAuthStore extends Mock implements AuthStore {}

class _Routes extends NavigatorObserver {
  final names = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      names.add(route.settings.name);
}

void main() {
  late MockTwitchApi helix;
  late MockAuthStore auth;
  late _Routes routes;

  setUpAll(() {
    registerFallbackValue(VodType.archive);
    registerFallbackValue(ClipPeriod.lastWeek);
    registerFallbackValue(ClipSort.top);
  });

  setUp(() {
    helix = MockTwitchApi();
    auth = MockAuthStore();
    routes = _Routes();
    when(() => auth.isLoggedIn).thenReturn(false);
    when(() => helix.getUser(userLogin: any(named: 'userLogin'))).thenAnswer(
      (_) async => const UserTwitch('42', 'streamer', 'Streamer', ''),
    );
  });

  Future<void> pump(WidgetTester tester, Widget child) {
    final profiles = MockProfileService();
    final vods = MockVodService();
    final clips = MockClipService();
    // The profile screen stays loading: these tests only open it.
    when(
      () => profiles.getProfile(any()),
    ).thenAnswer((_) => Completer<ChannelProfile?>().future);
    when(
      () => vods.getChannelVideos(
        login: any(named: 'login'),
        type: any(named: 'type'),
      ),
    ).thenAnswer((_) => Completer<VodPage>().future);
    when(
      () => clips.getChannelClips(
        login: any(named: 'login'),
        period: any(named: 'period'),
        sort: any(named: 'sort'),
      ),
    ).thenAnswer((_) => Completer<ClipPage>().future);
    return tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SettingsStore>.value(value: SettingsStore.fromJson({})),
          Provider<AuthStore>.value(value: auth),
          Provider<TwitchApi>.value(value: helix),
          Provider<TwitchChannelProfileService>.value(value: profiles),
          Provider<TwitchVodService>.value(value: vods),
          Provider<TwitchClipService>.value(value: clips),
        ],
        child: MaterialApp(
          navigatorObservers: [routes],
          home: Scaffold(body: child),
        ),
      ),
    );
  }

  testWidgets('an offline followed channel opens its profile', (tester) async {
    await pump(
      tester,
      OfflineChannelCard(
        channelInfo: FollowedChannel(
          broadcasterId: '42',
          broadcasterLogin: 'streamer',
          broadcasterName: 'Streamer',
          followedAt: DateTime.utc(2026),
        ),
        showPinOption: false,
      ),
    );
    await tester.tap(find.text('Streamer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(routes.names.last, ChannelProfileScreen.routeName);
  });

  testWidgets('the info bar avatar opens the profile only when asked', (
    tester,
  ) async {
    var taps = 0;
    await pump(
      tester,
      StreamInfoBar(displayName: 'Streamer', onTapChannel: () => taps++),
    );
    await tester.tap(find.byTooltip('Channel profile'));
    expect(taps, 1);

    await pump(tester, const StreamInfoBar(displayName: 'Streamer'));
    expect(find.byTooltip('Channel profile'), findsNothing);
  });

  testWidgets('the channel actions offer the profile', (tester) async {
    await pump(
      tester,
      UserActionsModal(
        authStore: auth,
        name: 'Streamer',
        userLogin: 'streamer',
        userId: '42',
      ),
    );
    expect(find.text('Profile'), findsOneWidget);

    await pump(
      tester,
      UserActionsModal(
        authStore: auth,
        name: 'Streamer',
        userLogin: 'streamer',
        userId: '42',
        showProfile: false,
      ),
    );
    expect(find.text('Profile'), findsNothing);
  });
}
