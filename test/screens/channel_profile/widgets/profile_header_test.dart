import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/channel_profile.dart';
import 'package:frosty/screens/channel_profile/widgets/profile_header.dart';
import 'package:frosty/screens/channel_profile/widgets/profile_live_card.dart';
import 'package:frosty/screens/channel_profile/widgets/profile_parts.dart';
import 'package:frosty/theme.dart';

const _offline = ChannelProfile(
  id: '42',
  login: 'streamer',
  displayName: 'Streamer',
  profileImageUrl: 'https://static-cdn.jtvnw.net/p.png',
  role: BroadcasterRole.partner,
  followers: 12641044,
);

final _live = ChannelProfile(
  id: '42',
  login: 'streamer',
  displayName: 'Streamer',
  profileImageUrl: 'https://static-cdn.jtvnw.net/p.png',
  followers: 1,
  lastBroadcast: const LastBroadcast(title: 'Ranked grind'),
  live: LiveStatus(
    isRerun: false,
    viewers: 27718,
    startedAt: DateTime.now().subtract(
      const Duration(hours: 3, minutes: 12, seconds: 30),
    ),
    gameName: 'Chess',
  ),
);

void main() {
  late List<String> taps;

  setUp(() => taps = []);

  Future<void> pump(
    WidgetTester tester,
    ChannelProfile profile, {
    double width = 390,
    double textScale = 1,
    bool dark = true,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        brightness: dark ? Brightness.dark : Brightness.light,
        extensions: [dark ? FrostyColors.dark : FrostyColors.light],
      ),
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 800),
          textScaler: TextScaler.linear(textScale),
          disableAnimations: true,
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              // Room for the avatar rising over the banner.
              padding: const EdgeInsets.only(top: 60),
              child: SizedBox(
                width: width,
                child: ProfileHeader(
                  login: profile.login,
                  displayName: profile.displayName,
                  profile: profile,
                  onOpenChannel: () => taps.add('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('offline: followers and the role, then Chat', (tester) async {
    for (final dark in [true, false]) {
      await pump(tester, _offline, dark: dark);
      expect(tester.takeException(), isNull);

      expect(find.text('Streamer'), findsOneWidget);
      expect(find.text('12.6m followers · Partner'), findsOneWidget);
      expect(find.text('LIVE'), findsNothing);
      // No offline image nor last broadcast: no card.
      expect(find.byType(ProfileLiveCard), findsNothing);
      expect(
        tester.widget<ProfileAvatar>(find.byType(ProfileAvatar)).live,
        isFalse,
      );
    }
    await tester.tap(find.text('Chat'));
    expect(taps, ['open']);
  });

  testWidgets('live: the ring, the card with viewers and uptime, Watch', (
    tester,
  ) async {
    await pump(tester, _live);

    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('1 follower'), findsOneWidget);
    expect(find.text('Ranked grind'), findsOneWidget);
    expect(find.text('27.7k watching · 3 h 12'), findsOneWidget);
    expect(
      tester.widget<ProfileAvatar>(find.byType(ProfileAvatar)).live,
      isTrue,
    );
    await tester.tap(find.text('Watch'));
    await tester.tap(find.text('Ranked grind'));
    expect(taps, ['open', 'open']);
  });

  testWidgets('a rerun says so', (tester) async {
    await pump(
      tester,
      const ChannelProfile(
        id: '1',
        login: 'a',
        displayName: 'A',
        profileImageUrl: 'https://static-cdn.jtvnw.net/p.png',
        live: LiveStatus(isRerun: true, viewers: 3),
      ),
    );
    expect(find.text('RERUN'), findsOneWidget);
    expect(find.textContaining('Rerun · 3 watching'), findsOneWidget);
  });

  testWidgets('large text fits a 320 dp phone', (tester) async {
    await pump(tester, _live, width: 320, textScale: 1.6);
    expect(tester.takeException(), isNull);
  });
}
