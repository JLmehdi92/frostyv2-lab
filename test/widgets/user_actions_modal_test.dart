import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/models/follow_result.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/widgets/follow/follow_actions.dart';
import 'package:onset/widgets/follow/follow_flow.dart';
import 'package:onset/widgets/twitch_web_page.dart';
import 'package:onset/widgets/user_actions_modal.dart';
import 'package:provider/provider.dart';

import '../helpers/l10n.dart';

class MockAuthStore extends Mock implements AuthStore {}

class _MockActions extends Mock implements FollowActions {}

void main() {
  Future<void> pump(WidgetTester tester, {required bool loggedIn}) {
    final auth = MockAuthStore();
    when(() => auth.isLoggedIn).thenReturn(loggedIn);
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserActionsModal(
            authStore: auth,
            name: 'Streamer',
            userLogin: 'streamer',
            userId: '1',
          ),
        ),
      ),
    );
  }

  testWidgets('a logged-in viewer can follow on twitch.tv', (tester) async {
    await pump(tester, loggedIn: true);
    expect(find.text('Follow Streamer on Twitch'), findsOneWidget);
    expect(find.text('Report Streamer'), findsOneWidget);
  });

  testWidgets('logged out, there is nothing to follow with', (tester) async {
    await pump(tester, loggedIn: false);
    expect(find.text('Follow Streamer on Twitch'), findsNothing);
  });

  group('in-app follow', () {
    late _MockActions actions;

    setUp(() {
      actions = _MockActions();
      when(() => actions.canFollowInApp).thenReturn(true);
    });

    Future<void> pumpWithActions(WidgetTester tester) async {
      final auth = MockAuthStore();
      when(() => auth.isLoggedIn).thenReturn(true);
      await pumpLocalized(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) => UserActionsModal(
                  authStore: auth,
                  name: 'Streamer',
                  userLogin: 'streamer',
                  userId: '1',
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
        locale: en,
        wrap: (app) =>
            Provider<FollowActions?>.value(value: actions, child: app),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('a viewer who does not follow follows from the menu', (
      tester,
    ) async {
      when(() => actions.followsChannel('1')).thenAnswer((_) async => false);
      when(
        () => actions.followChannel('1'),
      ).thenAnswer((_) async => FollowResult.done);
      await pumpWithActions(tester);

      await tester.tap(find.text('Follow Streamer'));
      await tester.pumpAndSettle();

      verify(() => actions.followChannel('1')).called(1);
      expect(find.byType(UserActionsModal), findsNothing);
      expect(find.text('You now follow Streamer.'), findsOneWidget);
    });

    testWidgets('unfollowing asks first and does nothing on cancel', (
      tester,
    ) async {
      when(() => actions.followsChannel('1')).thenAnswer((_) async => true);
      await pumpWithActions(tester);

      await tester.tap(find.text('Unfollow Streamer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      verifyNever(() => actions.unfollowChannel(any()));
      expect(find.byType(UserActionsModal), findsOneWidget);
    });

    testWidgets('an unknown state keeps the twitch.tv row', (tester) async {
      when(() => actions.followsChannel('1')).thenAnswer((_) async => null);
      await pumpWithActions(tester);

      expect(find.text('Follow Streamer on Twitch'), findsOneWidget);
      expect(find.byKey(FollowFlow.confirmKey), findsNothing);
    });
  });

  testWidgets('only twitch.tv pages open', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => TwitchWebPage.open(
              context,
              title: 'x',
              url: Uri.parse('https://evil.example/twitch.tv'),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    expect(find.byType(TwitchWebPage), findsNothing);
  });
}
