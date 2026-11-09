import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/models/follow_result.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/screens/home/live_feed/live_feed.dart';
import 'package:onset/widgets/follow/follow_actions.dart';
import 'package:onset/widgets/follow/follow_flow.dart';
import 'package:onset/widgets/twitch_web_page.dart';
import 'package:provider/provider.dart';

import '../../../helpers/l10n.dart';

class _MockActions extends Mock implements FollowActions {}

const _stream = StreamTwitch(
  '1000',
  'streamer',
  'Streamer',
  '509658',
  'Just Chatting',
  'title',
  1200,
  '2026-11-09T00:00:00Z',
  '',
);

void main() {
  late _MockActions actions;

  setUp(() {
    actions = _MockActions();
    when(() => actions.canFollowInApp).thenReturn(true);
    TwitchWebPage.debugBody = () => const SizedBox(key: ValueKey('web'));
  });

  tearDown(() => TwitchWebPage.debugBody = null);

  Future<void> pump(WidgetTester tester) => pumpLocalized(
    tester,
    const Scaffold(
      body: Center(child: LiveFeedFollowButton(stream: _stream)),
    ),
    locale: en,
    wrap: (app) => Provider<FollowActions?>.value(value: actions, child: app),
  );

  testWidgets('the feed follows in the app and shows the new state', (
    tester,
  ) async {
    when(() => actions.followsChannel(any())).thenAnswer((_) async => false);
    when(
      () => actions.followChannel(any()),
    ).thenAnswer((_) async => FollowResult.done);
    await pump(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Follow'));
    await tester.pumpAndSettle();

    verify(() => actions.followChannel(_stream.userId)).called(1);
    expect(find.text('Following'), findsOneWidget);
    expect(find.byKey(const ValueKey('web')), findsNothing);
  });

  testWidgets('unfollowing from the feed asks first', (tester) async {
    when(() => actions.followsChannel(any())).thenAnswer((_) async => true);
    when(
      () => actions.unfollowChannel(any()),
    ).thenAnswer((_) async => FollowResult.done);
    await pump(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Following'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(FollowFlow.confirmKey));
    await tester.pumpAndSettle();

    verify(() => actions.unfollowChannel(_stream.userId)).called(1);
    expect(find.text('Follow'), findsOneWidget);
  });

  testWidgets('an unknown state still opens twitch.tv', (tester) async {
    when(() => actions.followsChannel(any())).thenAnswer((_) async => null);
    await pump(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Follow'));
    await tester.pumpAndSettle();

    verifyNever(() => actions.followChannel(any()));
    expect(find.byKey(const ValueKey('web')), findsOneWidget);
  });
}
