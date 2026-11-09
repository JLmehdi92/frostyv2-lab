import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/models/follow_result.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/screens/channel/channel_info.dart';
import 'package:onset/screens/channel/stores/channel_info_store.dart';
import 'package:onset/widgets/follow/follow_actions.dart';
import 'package:onset/widgets/follow/follow_flow.dart';
import 'package:onset/widgets/twitch_web_page.dart';
import 'package:provider/provider.dart';

import '../../helpers/l10n.dart';

class _MockActions extends Mock implements FollowActions {}

class _MockApi extends Mock implements TwitchApi {}

StreamTwitch _stream(String id, String name) => StreamTwitch(
  id,
  name.toLowerCase(),
  name,
  '509658',
  'Just Chatting',
  'title',
  1200,
  '2026-11-09T00:00:00Z',
  '',
);

void main() {
  late _MockActions actions;
  late ChannelInfoStore info;

  setUp(() {
    actions = _MockActions();
    when(() => actions.canFollowInApp).thenReturn(true);
    when(
      () => actions.suggestionsAfterFollowing(any()),
    ).thenAnswer((_) async => const []);
    info = ChannelInfoStore(
      channelId: '1000',
      api: _MockApi(),
      viewerId: () => '77',
    );
    TwitchWebPage.debugBody = () => const SizedBox(key: ValueKey('web'));
  });

  tearDown(() {
    info.dispose();
    TwitchWebPage.debugBody = null;
  });

  Future<void> pump(WidgetTester tester, {bool? following = false}) async {
    info.following.value = following;
    await pumpLocalized(
      tester,
      Scaffold(
        body: Center(
          child: FollowButton(
            info: info,
            login: 'streamer',
            name: 'Streamer',
            height: 40,
          ),
        ),
      ),
      locale: en,
      wrap: (app) => Provider<FollowActions?>.value(value: actions, child: app),
    );
  }

  testWidgets('a tap follows from ONSET and says so', (tester) async {
    when(
      () => actions.followChannel('1000'),
    ).thenAnswer((_) async => FollowResult.done);
    await pump(tester);

    await tester.tap(find.text('Follow'));
    await tester.pumpAndSettle();

    verify(() => actions.followChannel('1000')).called(1);
    expect(info.following.value, isTrue);
    expect(find.text('Following'), findsOneWidget);
    expect(find.text('You now follow Streamer.'), findsOneWidget);
  });

  testWidgets('an unfollow asks first and does nothing on cancel', (
    tester,
  ) async {
    when(
      () => actions.unfollowChannel('1000'),
    ).thenAnswer((_) async => FollowResult.done);
    await pump(tester, following: true);

    await tester.tap(find.text('Following'));
    await tester.pumpAndSettle();
    expect(find.text('Unfollow Streamer?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    verifyNever(() => actions.unfollowChannel(any()));
    expect(info.following.value, isTrue);

    await tester.tap(find.text('Following'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(FollowFlow.confirmKey));
    await tester.pumpAndSettle();
    verify(() => actions.unfollowChannel('1000')).called(1);
    expect(info.following.value, isFalse);
    expect(find.text('You no longer follow Streamer.'), findsOneWidget);
  });

  testWidgets('a refusal names Twitch’s reason and keeps the state', (
    tester,
  ) async {
    when(
      () => actions.followChannel('1000'),
    ).thenAnswer((_) async => FollowResult.unverifiedEmail);
    await pump(tester);

    await tester.tap(find.text('Follow'));
    await tester.pumpAndSettle();

    expect(
      find.text('Verify your email address on Twitch to follow.'),
      findsOneWidget,
    );
    expect(info.following.value, isFalse);
  });

  testWidgets('an anti-bot refusal opens the channel on twitch.tv', (
    tester,
  ) async {
    when(
      () => actions.followChannel('1000'),
    ).thenAnswer((_) async => FollowResult.integrityRefused);
    await pump(tester);

    await tester.tap(find.text('Follow'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('web')), findsOneWidget);
  });

  testWidgets('without a web token the follow happens on twitch.tv', (
    tester,
  ) async {
    when(() => actions.canFollowInApp).thenReturn(false);
    await pump(tester);

    await tester.tap(find.text('Follow'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('web')), findsOneWidget);
    verifyNever(() => actions.followChannel(any()));
  });

  testWidgets('after a follow, suggested channels and Follow all', (
    tester,
  ) async {
    when(
      () => actions.followChannel(any()),
    ).thenAnswer((_) async => FollowResult.done);
    when(
      () => actions.suggestionsAfterFollowing('1000'),
    ).thenAnswer((_) async => [_stream('1', 'Alpha'), _stream('2', 'Beta')]);
    await pump(tester);

    await tester.tap(find.text('Follow'));
    await tester.pumpAndSettle();

    expect(find.text('You follow Streamer'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);

    await tester.tap(find.byKey(FollowSuggestionsSheet.followAllKey));
    await tester.pumpAndSettle();
    expect(find.text('Follow these 2 channels?'), findsOneWidget);
    await tester.tap(find.byKey(FollowFlow.confirmKey));
    await tester.pumpAndSettle();

    verify(() => actions.followChannel('1')).called(1);
    verify(() => actions.followChannel('2')).called(1);
    expect(find.text('You now follow 2 more channels.'), findsOneWidget);
  });

  testWidgets('Follow all stops at the first refusal and names it', (
    tester,
  ) async {
    when(
      () => actions.followChannel('1000'),
    ).thenAnswer((_) async => FollowResult.done);
    when(
      () => actions.followChannel('1'),
    ).thenAnswer((_) async => FollowResult.done);
    when(
      () => actions.followChannel('2'),
    ).thenAnswer((_) async => FollowResult.tooManyFollows);
    when(() => actions.suggestionsAfterFollowing('1000')).thenAnswer(
      (_) async => [
        _stream('1', 'Alpha'),
        _stream('2', 'Beta'),
        _stream('3', 'Gamma'),
      ],
    );
    await pump(tester);
    await tester.tap(find.text('Follow'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(FollowSuggestionsSheet.followAllKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(FollowFlow.confirmKey));
    await tester.pumpAndSettle();

    verifyNever(() => actions.followChannel('3'));
    expect(
      find.text(
        'You followed 1 channel, then couldn’t follow Beta. You follow too '
        'many channels. Unfollow one, then try again.',
      ),
      findsOneWidget,
    );
  });

  group('following from a prompt or a link', () {
    Future<List<bool?>> run(
      WidgetTester tester, {
      required bool? following,
      required bool confirm,
    }) async {
      final results = <bool?>[];
      await pumpLocalized(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => results.add(
                await FollowFlow.followFromPrompt(
                  context,
                  id: '1000',
                  name: 'Streamer',
                  following: following,
                  confirm: confirm,
                  openOnTwitch: () async {},
                ),
              ),
              child: const Text('go'),
            ),
          ),
        ),
        locale: en,
        wrap: (app) =>
            Provider<FollowActions?>.value(value: actions, child: app),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      return results;
    }

    testWidgets('a link for a followed channel asks nothing', (tester) async {
      final results = await run(tester, following: true, confirm: true);
      expect(find.byKey(FollowFlow.confirmKey), findsNothing);
      expect(results, [null]);
      verifyNever(() => actions.followChannel(any()));
    });

    testWidgets('a confirmed link follow opens the suggestions', (
      tester,
    ) async {
      when(
        () => actions.followChannel('1000'),
      ).thenAnswer((_) async => FollowResult.done);
      when(
        () => actions.suggestionsAfterFollowing('1000'),
      ).thenAnswer((_) async => [_stream('1', 'Alpha')]);
      await run(tester, following: false, confirm: true);
      await tester.tap(find.byKey(FollowFlow.confirmKey));
      await tester.pumpAndSettle();
      verify(() => actions.followChannel('1000')).called(1);
      expect(find.byType(FollowSuggestionsSheet), findsOneWidget);
    });

    testWidgets('a callout follow opens the suggestions too', (tester) async {
      when(
        () => actions.followChannel('1000'),
      ).thenAnswer((_) async => FollowResult.done);
      when(
        () => actions.suggestionsAfterFollowing('1000'),
      ).thenAnswer((_) async => [_stream('1', 'Alpha')]);
      await run(tester, following: false, confirm: false);
      expect(find.byType(FollowSuggestionsSheet), findsOneWidget);
    });
  });
}
