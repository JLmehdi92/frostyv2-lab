import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/screens/activity/activity_screen.dart';
import 'package:frosty/screens/activity/stores/activity_store.dart';
import 'package:frosty/screens/home/home_store.dart';
import 'package:frosty/services/notifications/activity_log.dart';
import 'package:frosty/services/realtime/twitch_eventsub_client.dart';
import 'package:frosty/stores/whisper_store.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

final _now = DateTime.utc(2026, 10, 20, 12);

ActivityEntry _entry(
  String id, {
  required Duration ago,
  ActivityKind kind = ActivityKind.live,
  String? login = 'streamer',
  bool read = false,
}) => ActivityEntry(
  id: id,
  kind: kind,
  title: 'Title $id',
  body: 'Body $id',
  login: login,
  at: _now.subtract(ago),
  read: read,
);

void main() {
  late ActivityStore store;
  late List<String> opened;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = ActivityStore(log: await ActivityLog.load());
    opened = [];
  });

  Future<void> pump(
    WidgetTester tester, {
    WhisperStore? whispers,
    ActivityTab tab = ActivityTab.notifications,
    bool active = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActivityScreen(
            store: store,
            whispers: whispers,
            tab: tab,
            active: active,
            onOpenChannel: opened.add,
            now: () => _now,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets("empty: Twitch's up-to-date message", (tester) async {
    await pump(tester);
    expect(find.text("Hooray! You're up to date"), findsOneWidget);
    expect(
      find.text(
        'Check back soon for alerts about you and the broadcasters you '
        'follow.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('most recent and earlier, with their category and time', (
    tester,
  ) async {
    await store.addAll([
      _entry('a', ago: const Duration(hours: 1)),
      _entry(
        'b',
        ago: const Duration(days: 3),
        kind: ActivityKind.mention,
        read: true,
      ),
    ]);
    await pump(tester);
    expect(find.text('Most Recent'), findsOneWidget);
    expect(find.text('Earlier'), findsOneWidget);
    expect(find.text('Title a'), findsOneWidget);
    expect(find.text('Body a'), findsOneWidget);
    expect(find.text('1 hour ago • Live'), findsOneWidget);
    expect(find.text('3 days ago • Chat Mentions'), findsOneWidget);
    expect(find.textContaining('on this device'), findsOneWidget);
  });

  testWidgets('only older ones: they are the most recent', (tester) async {
    await store.addAll([_entry('a', ago: const Duration(days: 2))]);
    await pump(tester);
    expect(find.text('Most Recent'), findsOneWidget);
    expect(find.text('Earlier'), findsNothing);
  });

  testWidgets('mark all as read', (tester) async {
    await store.addAll([
      _entry('a', ago: const Duration(minutes: 5)),
      _entry('b', ago: const Duration(days: 2)),
    ]);
    await pump(tester);
    expect(find.text('Mark all as read'), findsOneWidget);
    await tester.tap(find.text('Mark all as read'));
    await tester.pump();
    await tester.pump();
    expect(store.unreadCount, 0);
    expect(find.text('Mark all as read'), findsNothing);
  });

  testWidgets('opening the list clears the bell, not the unread', (
    tester,
  ) async {
    await store.addAll([_entry('a', ago: const Duration(minutes: 5))]);
    expect(store.newCount, 1);
    await pump(tester);
    expect(store.newCount, 0);
    expect(store.unreadCount, 1);
  });

  testWidgets('a tap opens the channel and marks it read', (tester) async {
    await store.addAll([_entry('a', ago: const Duration(minutes: 5))]);
    await pump(tester);
    await tester.tap(find.text('Title a'));
    await tester.pump();
    await tester.pump();
    expect(opened, ['streamer']);
    expect(store.unreadCount, 0);
  });

  testWidgets('a long press removes it', (tester) async {
    await store.addAll([_entry('a', ago: const Duration(minutes: 5))]);
    await pump(tester);
    await tester.longPress(find.text('Title a'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove notification'));
    await tester.pumpAndSettle();
    expect(find.text('Title a'), findsNothing);
    expect(store.entries, isEmpty);
  });

  testWidgets('with whispers: two tabs with their unread counts', (
    tester,
  ) async {
    final whispers = WhisperStore(
      twitchApi: MockTwitchApi(),
      currentUserId: () => '7',
      listen: (topic) =>
          EventSubHandle.forTesting(topic, const Stream.empty(), () {}),
    );
    addTearDown(whispers.dispose);
    await store.addAll([
      _entry('a', ago: const Duration(minutes: 5)),
      _entry('b', ago: const Duration(minutes: 6)),
    ]);
    // The tabs are in the shell's header.
    expect(
      activityTabLabel(
        ActivityTab.notifications,
        store: store,
        whispers: whispers,
      ),
      'Notifications (2)',
    );
    expect(
      activityTabLabel(ActivityTab.whispers, store: store, whispers: whispers),
      'Whispers',
    );
    await pump(tester, whispers: whispers);
    expect(find.text('Title a'), findsOneWidget);
    await pump(tester, whispers: whispers, tab: ActivityTab.whispers);
    expect(find.textContaining('No whispers yet'), findsOneWidget);
    expect(find.text('Title a'), findsNothing);
  });

  testWidgets('logged out: notifications only, whatever the tab', (
    tester,
  ) async {
    await store.addAll([_entry('a', ago: const Duration(minutes: 5))]);
    await pump(tester, tab: ActivityTab.whispers);
    expect(find.text('Title a'), findsOneWidget);
    expect(find.textContaining('No whispers yet'), findsNothing);
  });

  testWidgets('kept while another section shows: cleared when shown again', (
    tester,
  ) async {
    await pump(tester, active: false);
    await store.addAll([_entry('a', ago: const Duration(minutes: 5))]);
    await tester.pump();
    expect(store.newCount, 1);

    await pump(tester);
    expect(store.newCount, 0);

    // Arriving while it is open: seen at once.
    await store.addAll([
      ActivityEntry(
        id: 'b',
        kind: ActivityKind.live,
        title: 'Title b',
        body: '',
        at: DateTime.now(),
      ),
    ]);
    await tester.pump();
    await tester.pump();
    expect(store.newCount, 0);
    expect(store.unreadCount, 2);
  });
}
