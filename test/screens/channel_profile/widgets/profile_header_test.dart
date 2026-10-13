import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/channel_profile.dart';
import 'package:frosty/screens/channel_profile/widgets/profile_header.dart';

const _offline = ChannelProfile(
  id: '42',
  login: 'streamer',
  displayName: 'Streamer',
  profileImageUrl: 'https://static-cdn.jtvnw.net/p.png',
  role: BroadcasterRole.partner,
  followers: 12641044,
);

const _live = ChannelProfile(
  id: '42',
  login: 'streamer',
  displayName: 'Streamer',
  profileImageUrl: 'https://static-cdn.jtvnw.net/p.png',
  followers: 1,
  live: LiveStatus(isRerun: false, viewers: 27718),
);

void main() {
  late List<String> taps;

  setUp(() => taps = []);

  Future<void> pump(
    WidgetTester tester,
    ChannelProfile profile, {
    double width = 360,
    double textScale = 1,
  }) => tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 800),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: width,
              child: ProfileHeader(
                login: profile.login,
                displayName: profile.displayName,
                profile: profile,
                onOpenChannel: () => taps.add('open'),
                onShare: () => taps.add('share'),
                onMore: () => taps.add('more'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('offline: followers, the partner check, and Chat', (
    tester,
  ) async {
    await pump(tester, _offline);

    expect(find.text('Streamer'), findsOneWidget);
    expect(find.text('12.6M followers'), findsOneWidget);
    expect(find.bySemanticsLabel('Verified'), findsOneWidget);
    expect(find.text('LIVE'), findsNothing);

    await tester.tap(find.text('Chat'));
    await tester.tap(find.text('Share'));
    await tester.tap(find.byTooltip('More'));
    expect(taps, ['open', 'share', 'more']);
  });

  testWidgets('live: the badge, viewers and Watch', (tester) async {
    await pump(tester, _live);

    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('1 follower · 27.7K watching'), findsOneWidget);
    expect(find.bySemanticsLabel('Verified'), findsNothing);
    await tester.tap(find.text('Watch'));
    expect(taps, ['open']);
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
  });

  testWidgets('large text fits a 320 dp phone', (tester) async {
    await pump(tester, _live, width: 320, textScale: 1.6);
    expect(tester.takeException(), isNull);
  });
}
