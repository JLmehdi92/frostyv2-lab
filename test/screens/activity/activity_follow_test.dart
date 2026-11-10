import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/models/follow_result.dart';
import 'package:onset/screens/activity/activity_screen.dart';
import 'package:onset/screens/activity/stores/activity_store.dart';
import 'package:onset/services/notifications/activity_log.dart';
import 'package:onset/widgets/follow/follow_actions.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/l10n.dart';

class _MockActions extends Mock implements FollowActions {}

final _now = DateTime.utc(2026, 10, 20, 12);

ActivityEntry _entry(
  String id,
  ActivityKind kind, {
  String login = 'streamer',
}) => ActivityEntry(
  id: id,
  kind: kind,
  title: 'Title $id',
  body: '',
  login: login,
  at: _now.subtract(const Duration(minutes: 5)),
  params: const {'name': 'Streamer'},
);

void main() {
  late ActivityStore store;
  late _MockActions actions;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = ActivityStore(log: await ActivityLog.load());
    actions = _MockActions();
    when(() => actions.canFollowInApp).thenReturn(true);
    when(() => actions.isSignedIn).thenReturn(true);
    when(() => actions.connectWebSession()).thenAnswer((_) async => true);
    when(
      () => actions.channelFollowState('streamer'),
    ).thenAnswer((_) async => (id: '1000', following: false));
  });

  Future<void> pump(WidgetTester tester, {FollowActions? follow}) async {
    await pumpLocalized(
      tester,
      Scaffold(
        body: ActivityScreen(
          store: store,
          onOpenChannel: (_) {},
          now: () => _now,
        ),
      ),
      locale: en,
      wrap: (app) => Provider<FollowActions?>.value(value: follow, child: app),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a reminder from a channel the viewer does not follow offers '
      'Follow, and follows from ONSET', (tester) async {
    when(
      () => actions.followChannel('1000'),
    ).thenAnswer((_) async => FollowResult.done);
    await store.addAll([_entry('r', ActivityKind.reminder)]);
    await pump(tester, follow: actions);

    await tester.tap(find.widgetWithText(FilledButton, 'Follow'));
    await tester.pumpAndSettle();

    verify(() => actions.followChannel('1000')).called(1);
    expect(find.text('Following'), findsOneWidget);
    expect(find.text('You now follow Streamer.'), findsOneWidget);
  });

  testWidgets('one lookup per channel, however many rows name it', (
    tester,
  ) async {
    await store.addAll([
      _entry('r', ActivityKind.reminder),
      _entry('m', ActivityKind.mention),
    ]);
    await pump(tester, follow: actions);
    expect(find.widgetWithText(FilledButton, 'Follow'), findsNWidgets(2));
    verify(() => actions.channelFollowState('streamer')).called(1);
  });

  testWidgets('no Follow on a go-live, for a followed channel, or signed '
      'out', (tester) async {
    when(
      () => actions.channelFollowState('followed'),
    ).thenAnswer((_) async => (id: '2', following: true));
    await store.addAll([
      _entry('l', ActivityKind.live),
      _entry('f', ActivityKind.reminder, login: 'followed'),
    ]);
    await pump(tester, follow: actions);
    expect(find.widgetWithText(FilledButton, 'Follow'), findsNothing);
    verifyNever(() => actions.channelFollowState('streamer'));

    await store.addAll([_entry('r', ActivityKind.reminder)]);
    when(() => actions.canFollowInApp).thenReturn(false);
    await pump(tester, follow: actions);
    expect(find.widgetWithText(FilledButton, 'Follow'), findsNothing);
  });
}
