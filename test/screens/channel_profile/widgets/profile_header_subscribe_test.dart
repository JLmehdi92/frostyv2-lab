import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/channel_profile.dart';
import 'package:frosty/screens/channel_profile/widgets/profile_header.dart';

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
    bool canSubscribe = true,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ProfileHeader(
            login: 'streamer',
            displayName: 'Streamer',
            profile: profile,
            onOpenChannel: () => taps.add('open'),
            onShare: () => taps.add('share'),
            onSubscribe: canSubscribe ? () => taps.add('subscribe') : null,
          ),
        ),
      ),
    ),
  );

  testWidgets('a partner or affiliate offers Subscribe, like Twitch', (
    tester,
  ) async {
    for (final role in [BroadcasterRole.partner, BroadcasterRole.affiliate]) {
      await pump(tester, _profile(role));
      expect(find.text('Subscribe'), findsOneWidget);
    }
    await tester.tap(find.text('Subscribe'));
    expect(taps, ['subscribe']);
  });

  testWidgets('a channel without subscriptions does not', (tester) async {
    await pump(tester, _profile(BroadcasterRole.none));
    expect(find.text('Subscribe'), findsNothing);

    // Not known yet: nothing either.
    await pump(tester, null);
    expect(find.text('Subscribe'), findsNothing);
  });

  testWidgets('nor without a way to subscribe', (tester) async {
    await pump(tester, _profile(BroadcasterRole.partner), canSubscribe: false);
    expect(find.text('Subscribe'), findsNothing);
  });
}
