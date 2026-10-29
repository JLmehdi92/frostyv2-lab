import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/channel_profile.dart';
import 'package:onset/screens/channel_profile/widgets/profile_header.dart';
import 'package:onset/theme.dart';

ChannelProfile _profile(BroadcasterRole role) => ChannelProfile(
  id: '42',
  login: 'streamer',
  displayName: 'Streamer',
  role: role,
);

void main() {
  late List<String> taps;

  setUp(() => taps = []);

  Future<void> pump(
    WidgetTester tester,
    ChannelProfile? profile, {
    required bool showSubscribe,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: const [FrostyColors.dark]),
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          disableAnimations: true,
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(top: 60),
              child: ProfileHeader(
                login: 'streamer',
                displayName: 'Streamer',
                profile: profile,
                onOpenChannel: () => taps.add('open'),
                showSubscribe: showSubscribe,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  test('a partner or an affiliate offers Subscribe, like Twitch', () {
    for (final role in [BroadcasterRole.partner, BroadcasterRole.affiliate]) {
      expect(
        profileOffersSubscribe(profile: _profile(role), login: 'streamer'),
        isTrue,
      );
      // Signed in as someone else, too.
      expect(
        profileOffersSubscribe(
          profile: _profile(role),
          login: 'streamer',
          viewerLogin: 'viewer',
        ),
        isTrue,
      );
    }
  });

  test('not without subscriptions, unknown, own or unusable', () {
    expect(
      profileOffersSubscribe(
        profile: _profile(BroadcasterRole.none),
        login: 'streamer',
      ),
      isFalse,
    );
    // Not known yet: nothing either.
    expect(profileOffersSubscribe(profile: null, login: 'streamer'), isFalse);
    // The viewer's own channel.
    expect(
      profileOffersSubscribe(
        profile: _profile(BroadcasterRole.partner),
        login: 'streamer',
        viewerLogin: 'Streamer',
      ),
      isFalse,
    );
    // A login twitch.tv would not take is never put in a link.
    expect(
      profileOffersSubscribe(
        profile: _profile(BroadcasterRole.partner),
        login: '../x',
      ),
      isFalse,
    );
  });

  testWidgets('the header shows it when offered', (tester) async {
    await pump(tester, _profile(BroadcasterRole.partner), showSubscribe: true);
    expect(find.text('Subscribe'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await pump(tester, _profile(BroadcasterRole.partner), showSubscribe: false);
    expect(find.text('Subscribe'), findsNothing);
  });
}
