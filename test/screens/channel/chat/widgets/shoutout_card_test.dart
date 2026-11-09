import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/models/follow_result.dart';
import 'package:onset/models/shoutout_profile.dart';
import 'package:onset/screens/channel/chat/mod_tools/mod_events.dart';
import 'package:onset/screens/channel/chat/widgets/shoutout_card.dart';
import 'package:onset/widgets/follow/follow_actions.dart';
import 'package:onset/widgets/follow/follow_flow.dart';
import 'package:onset/widgets/twitch_web_page.dart';
import 'package:provider/provider.dart';

import '../../../../fixtures/community_gql_payloads.dart';

class _MockActions extends Mock implements FollowActions {}

const _notice = ShoutoutNotice(
  id: 's1',
  targetId: '2',
  targetLogin: 'target',
  targetName: 'Target',
);

void main() {
  Future<void> pump(
    WidgetTester tester,
    ShoutoutProfile? profile, {
    VoidCallback? onViewProfile,
    FollowActions? actions,
  }) async {
    tester.view
      ..physicalSize = const Size(400, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Provider<FollowActions?>.value(
        value: actions,
        child: MaterialApp(
          home: Scaffold(
            body: ShoutoutCard(
              notice: _notice,
              load: () async => profile,
              onViewProfile: onViewProfile ?? () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the channel, its recent categories and Follow', (
    tester,
  ) async {
    await pump(tester, ShoutoutProfile.tryParse(shoutoutResponse));

    expect(find.text('SHOUTOUT'), findsOneWidget);
    expect(find.text('Target'), findsOneWidget);
    expect(find.text('Recent categories'), findsOneWidget);
    expect(find.text('First Game'), findsOneWidget);
    expect(find.text('VALORANT'), findsOneWidget);
    expect(find.text('Follow'), findsOneWidget);
  });

  testWidgets('says Following when the viewer follows', (tester) async {
    await pump(
      tester,
      ShoutoutProfile.tryParse(shoutoutResponse)!.withFollowing(true),
    );

    expect(find.text('Following'), findsOneWidget);
  });

  testWidgets('shows the next scheduled stream', (tester) async {
    await pump(
      tester,
      ShoutoutProfile(
        id: '2',
        login: 'target',
        displayName: 'Target',
        nextStream: ShoutoutSchedule(
          startAt: DateTime(2026, 11, 10, 18),
          title: 'Ranked night',
        ),
      ),
    );

    expect(find.textContaining('Next stream: '), findsOneWidget);
    expect(find.text('Ranked night'), findsOneWidget);
  });

  testWidgets('a failure keeps the name and the buttons', (tester) async {
    var profiles = 0;
    await pump(tester, null, onViewProfile: () => profiles++);

    expect(find.byKey(ShoutoutCard.failedKey), findsOneWidget);
    expect(find.text('Target'), findsOneWidget);
    await tester.tap(find.byKey(ShoutoutCard.profileKey));
    expect(profiles, 1);
    expect(find.byKey(ShoutoutCard.followKey), findsOneWidget);
  });

  group('Follow', () {
    setUp(
      () =>
          TwitchWebPage.debugBody = () => const SizedBox(key: ValueKey('web')),
    );
    tearDown(() => TwitchWebPage.debugBody = null);

    testWidgets('follows from ONSET without opening twitch.tv', (tester) async {
      final actions = _MockActions();
      when(() => actions.canFollowInApp).thenReturn(true);
      when(
        () => actions.followChannel('2'),
      ).thenAnswer((_) async => FollowResult.done);
      await pump(
        tester,
        ShoutoutProfile.tryParse(shoutoutResponse),
        actions: actions,
      );

      await tester.tap(find.byKey(ShoutoutCard.followKey));
      await tester.pumpAndSettle();

      verify(() => actions.followChannel('2')).called(1);
      expect(find.text('Following'), findsOneWidget);
      expect(find.byKey(const ValueKey('web')), findsNothing);
    });

    testWidgets('without a Twitch session it asks before opening twitch.tv', (
      tester,
    ) async {
      await pump(tester, ShoutoutProfile.tryParse(shoutoutResponse));

      await tester.tap(find.byKey(ShoutoutCard.followKey));
      await tester.pumpAndSettle();
      expect(find.text('Follow on twitch.tv?'), findsOneWidget);
      expect(find.byKey(const ValueKey('web')), findsNothing);

      await tester.tap(find.byKey(FollowFlow.confirmKey));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('web')), findsOneWidget);
    });
  });
}
