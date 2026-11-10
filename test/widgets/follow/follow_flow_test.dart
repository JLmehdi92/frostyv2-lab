import 'dart:async';

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

class _PushObserver extends NavigatorObserver {
  _PushObserver(this.pushes);

  final List<Route<dynamic>> pushes;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushes.add(route);
}

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
    when(() => actions.isSignedIn).thenReturn(true);
    when(() => actions.connectWebSession()).thenAnswer((_) async => true);
    when(() => actions.followsChannel(any())).thenAnswer((_) async => false);
    when(() => actions.followsCategory(any())).thenAnswer((_) async => false);
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

  testWidgets('an anti-bot refusal stays in ONSET and asks to wait', (
    tester,
  ) async {
    when(
      () => actions.followChannel('1000'),
    ).thenAnswer((_) async => FollowResult.integrityRefused);
    await pump(tester);

    await tester.tap(find.text('Follow'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('web')), findsNothing);
    expect(
      find.text(
        'Twitch’s anti-bot check refused this again after a second try. '
        'Try again in a few minutes.',
      ),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsNothing);
    expect(info.following.value, isFalse);
  });

  testWidgets('Retry sends the follow again', (tester) async {
    when(
      () => actions.followChannel('1000'),
    ).thenAnswer((_) async => FollowResult.gqlError);
    await pump(tester);

    await tester.tap(find.text('Follow'));
    await tester.pumpAndSettle();
    when(
      () => actions.followChannel('1000'),
    ).thenAnswer((_) async => FollowResult.done);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    verify(() => actions.followChannel('1000')).called(2);
    expect(info.following.value, isTrue);
  });

  for (final (result, text) in const [
    (
      FollowResult.mintTimeout,
      'Twitch’s anti-bot check took too long to answer. Try again.',
    ),
    (
      FollowResult.mintFailed,
      'ONSET couldn’t complete Twitch’s anti-bot check. Try again.',
    ),
    (FollowResult.gqlError, 'Twitch answered with an error. Try again.'),
    (FollowResult.failed, 'Couldn’t reach Twitch. Try again.'),
  ]) {
    testWidgets('${result.name} names its own step', (tester) async {
      when(() => actions.followChannel('1000')).thenAnswer((_) async => result);
      await pump(tester);

      await tester.tap(find.text('Follow'));
      await tester.pumpAndSettle();

      expect(find.text(text), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byKey(const ValueKey('web')), findsNothing);
    });
  }

  testWidgets('without a web token it connects one, then follows natively', (
    tester,
  ) async {
    var connected = false;
    when(() => actions.canFollowInApp).thenAnswer((_) => connected);
    when(() => actions.connectWebSession()).thenAnswer((_) async {
      connected = true;
      return true;
    });
    when(
      () => actions.followChannel('1000'),
    ).thenAnswer((_) async => FollowResult.done);
    await pump(tester);

    await tester.tap(find.text('Follow'));
    await tester.pumpAndSettle();

    verify(() => actions.connectWebSession()).called(1);
    verify(() => actions.followChannel('1000')).called(1);
    expect(info.following.value, isTrue);
    expect(find.byKey(const ValueKey('web')), findsNothing);
  });

  testWidgets('a session it cannot connect asks for an ONSET login', (
    tester,
  ) async {
    when(() => actions.canFollowInApp).thenReturn(false);
    when(() => actions.connectWebSession()).thenAnswer((_) async => false);
    var logins = 0;
    FollowFlow.openLogin = (_) async => logins++;
    addTearDown(() => FollowFlow.openLogin = FollowFlow.defaultOpenLogin);
    await pump(tester);

    await tester.tap(find.text('Follow'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'ONSET has no Twitch web session to send this with. Log in to '
        'connect it.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('web')), findsNothing);
    verifyNever(() => actions.followChannel(any()));

    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(logins, 1);
    expect(find.byKey(const ValueKey('web')), findsNothing);
  });

  testWidgets('a logged-out viewer is asked to log in to ONSET', (
    tester,
  ) async {
    when(() => actions.isSignedIn).thenReturn(false);
    when(() => actions.canFollowInApp).thenReturn(false);
    await pump(tester);

    await tester.tap(find.text('Follow'));
    await tester.pumpAndSettle();

    expect(
      find.text('Log in to ONSET to follow channels and categories.'),
      findsOneWidget,
    );
    expect(find.text('Log in'), findsOneWidget);
    verifyNever(() => actions.connectWebSession());
    expect(find.byKey(const ValueKey('web')), findsNothing);
  });

  testWidgets('a follow waiting on Twitch ignores more taps', (tester) async {
    final answer = Completer<FollowResult>();
    when(() => actions.followChannel('1000')).thenAnswer((_) => answer.future);
    await pump(tester);

    await tester.tap(find.text('Follow'));
    await tester.pump();
    expect(FollowFlow.isPending('1000'), isTrue);
    expect(
      tester
          .widget<AbsorbPointer>(
            find.descendant(
              of: find.byType(FollowPendingGate),
              matching: find.byType(AbsorbPointer),
            ),
          )
          .absorbing,
      isTrue,
    );
    await tester.tap(find.text('Follow'), warnIfMissed: false);
    await tester.pump();

    answer.complete(FollowResult.done);
    await tester.pumpAndSettle();
    verify(() => actions.followChannel('1000')).called(1);
    expect(FollowFlow.isPending('1000'), isFalse);
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

  testWidgets('a signed-in viewer without a web session still gets actions', (
    tester,
  ) async {
    when(() => actions.canFollowInApp).thenReturn(false);
    FollowActions? found;
    await pumpLocalized(
      tester,
      Builder(
        builder: (context) {
          found = FollowFlow.actionsOf(context);
          return const SizedBox();
        },
      ),
      locale: en,
      wrap: (app) => Provider<FollowActions?>.value(value: actions, child: app),
    );
    expect(found, same(actions));
  });

  testWidgets('a state learned after connecting is not followed twice', (
    tester,
  ) async {
    var connected = false;
    when(() => actions.canFollowInApp).thenAnswer((_) => connected);
    when(() => actions.connectWebSession()).thenAnswer((_) async {
      connected = true;
      return true;
    });
    when(() => actions.followsChannel('1000')).thenAnswer((_) async => true);
    await pump(tester, following: null);

    await tester.tap(find.text('Follow'));
    await tester.pumpAndSettle();

    verifyNever(() => actions.followChannel(any()));
    expect(info.following.value, isTrue);
  });

  testWidgets('Retry still works once the button that asked is gone', (
    tester,
  ) async {
    when(
      () => actions.followChannel('1000'),
    ).thenAnswer((_) async => FollowResult.gqlError);
    final shown = ValueNotifier(true);
    info.following.value = false;
    await pumpLocalized(
      tester,
      Scaffold(
        body: ValueListenableBuilder<bool>(
          valueListenable: shown,
          builder: (context, visible, _) => visible
              ? FollowButton(
                  info: info,
                  login: 'streamer',
                  name: 'Streamer',
                  height: 40,
                )
              : const SizedBox(),
        ),
      ),
      locale: en,
      wrap: (app) => Provider<FollowActions?>.value(value: actions, child: app),
    );

    await tester.tap(find.text('Follow'));
    await tester.pumpAndSettle();
    shown.value = false;
    await tester.pump();
    when(
      () => actions.followChannel('1000'),
    ).thenAnswer((_) async => FollowResult.done);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    verify(() => actions.followChannel('1000')).called(2);
    expect(find.text('You now follow Streamer.'), findsOneWidget);
  });

  testWidgets('a session that never connects never leaves ONSET', (
    tester,
  ) async {
    when(() => actions.canFollowInApp).thenReturn(false);
    when(() => actions.connectWebSession()).thenAnswer((_) async => false);
    var logins = 0;
    FollowFlow.openLogin = (_) async => logins++;
    addTearDown(() => FollowFlow.openLogin = FollowFlow.defaultOpenLogin);
    final pushes = <Route<dynamic>>[];
    info.following.value = false;
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
      observer: _PushObserver(pushes),
      wrap: (app) => Provider<FollowActions?>.value(value: actions, child: app),
    );
    final before = pushes.length;

    for (var tap = 0; tap < 2; tap++) {
      await tester.tap(find.text('Follow'));
      await tester.pumpAndSettle();
      expect(find.text('Log in'), findsOneWidget);
    }
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    expect(pushes.length, before);
    expect(logins, 1);
    verifyNever(() => actions.followChannel(any()));
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
