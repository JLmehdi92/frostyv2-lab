import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/activity/activity_screen.dart';
import 'package:onset/screens/activity/stores/activity_store.dart';
import 'package:onset/screens/home/stores/home_store.dart';
import 'package:onset/screens/whispers/whisper_conversation.dart';
import 'package:onset/screens/whispers/whispers_screen.dart';
import 'package:onset/services/notifications/activity_log.dart';
import 'package:onset/services/notifications/schedule_reminders.dart';
import 'package:onset/services/realtime/twitch_eventsub_client.dart';
import 'package:onset/stores/whisper_store.dart';
import 'package:onset/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/l10n.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

final _now = DateTime.utc(2026, 10, 20, 12);

const _phone = Size(390, 844);
const _tablet = Size(1280, 854);
const _tabletPortrait = Size(854, 1280);

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
    Size size = _phone,
    ThemeMode theme = ThemeMode.dark,
    bool reduceMotion = false,
    Locale? locale,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = await localizedApp(
      tester,
      locale: locale,
      textScale: textScale,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
    );
    final themes = OnsetThemes(colorSchemeSeed: OnsetTokens.accent);
    await tester.pumpWidget(
      MaterialApp(
        locale: app.locale,
        supportedLocales: app.supportedLocales,
        localizationsDelegates: app.delegates,
        theme: themes.light,
        darkTheme: themes.dark,
        themeMode: theme,
        builder: app.builder,
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

  WhisperStore whisperStore(Stream<EventSubTopicEvent> events) {
    final whispers = WhisperStore(
      twitchApi: MockTwitchApi(),
      currentUserId: () => '7',
      listen: (topic) => EventSubHandle.forTesting(topic, events, () {}),
    );
    addTearDown(whispers.dispose);
    return whispers;
  }

  EventSubData whisper(String text, {String id = 'w1'}) => EventSubData({
    'from_user_id': '8',
    'from_user_login': 'friend',
    'from_user_name': 'Friend',
    'to_user_id': '7',
    'whisper_id': id,
    'whisper': {'text': text},
  });

  testWidgets("empty: Twitch's up-to-date message", (tester) async {
    await pump(tester);
    expect(find.text('Hooray! You’re up to date'), findsOneWidget);
    expect(
      find.text(
        'Check back soon for alerts about you and the broadcasters you '
        'follow.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('phone: Notifications and Whispers keep their scroll between '
      'their tabs', (tester) async {
    await store.addAll([
      for (var i = 0; i < 40; i++) _entry('$i', ago: Duration(minutes: i + 1)),
    ]);
    final whispers = whisperStore(const Stream.empty());
    double offset() => tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;

    await pump(tester, whispers: whispers);
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(900);
    await tester.pump();
    expect(offset(), 900);

    await pump(tester, whispers: whispers, tab: ActivityTab.whispers);
    expect(find.byType(WhispersList), findsOneWidget);
    expect(find.text('Title 0'), findsNothing);

    await pump(tester, whispers: whispers);
    expect(find.byType(WhispersList), findsNothing);
    expect(offset(), 900);
    expect(tester.takeException(), isNull);
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
    expect(find.text('Most recent'), findsOneWidget);
    expect(find.text('Earlier'), findsOneWidget);
    expect(find.text('Title a'), findsOneWidget);
    expect(find.text('Body a'), findsOneWidget);
    expect(find.text('1 hour ago • Live'), findsOneWidget);
    expect(find.text('3 days ago • Chat mentions'), findsOneWidget);
    expect(find.textContaining('on this device'), findsOneWidget);
  });

  testWidgets('only older ones: they are the most recent', (tester) async {
    await store.addAll([_entry('a', ago: const Duration(days: 2))]);
    await pump(tester);
    expect(find.text('Most recent'), findsOneWidget);
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
    // The tabs are in the shell's header, with their unread counts.
    expect(
      activityTabBadge(
        ActivityTab.notifications,
        store: store,
        whispers: whispers,
      ),
      2,
    );
    expect(
      activityTabBadge(ActivityTab.whispers, store: store, whispers: whispers),
      0,
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

  testWidgets('in the background, what arrives stays new', (tester) async {
    await pump(tester);
    void moveTo(List<AppLifecycleState> states) {
      for (final state in states) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
    }

    moveTo(const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]);
    await store.addAll([
      ActivityEntry(
        id: 'c',
        kind: ActivityKind.live,
        title: 'Title c',
        body: '',
        at: DateTime.now(),
      ),
    ]);
    await tester.pump();
    expect(store.newCount, 1);

    // Back in front, on Activity: seen.
    moveTo(const [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);
    await tester.pump();
    await tester.pump();
    expect(store.newCount, 0);
  });

  testWidgets('removed at once: the fold is only the look', (tester) async {
    await store.addAll([_entry('a', ago: const Duration(minutes: 5))]);
    await pump(tester);
    await tester.longPress(find.text('Title a'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove notification'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Mid-fold, the list goes (a tab switch, a phone-tablet switch).
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 500));
    expect(store.entries, isEmpty);
    await store.refresh();
    expect(store.entries, isEmpty);
  });

  testWidgets('a long press with reduce motion removes it at once', (
    tester,
  ) async {
    await store.addAll([_entry('a', ago: const Duration(minutes: 5))]);
    await pump(tester, reduceMotion: true);
    await tester.longPress(find.text('Title a'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove notification'));
    await tester.pump();
    await tester.pump();
    expect(store.entries, isEmpty);
    await tester.pumpAndSettle();
    expect(find.text('Title a'), findsNothing);
  });

  testWidgets('unread: the signal dot; read: none', (tester) async {
    await store.addAll([
      _entry('a', ago: const Duration(minutes: 5)),
      _entry('b', ago: const Duration(minutes: 6), read: true),
    ]);
    await pump(tester);
    expect(find.byKey(const ValueKey('activity-unread-dot')), findsOneWidget);
  });

  testWidgets('phone: a whisper opens its conversation alone', (tester) async {
    final events = StreamController<EventSubTopicEvent>.broadcast();
    addTearDown(events.close);
    final whispers = whisperStore(events.stream);
    events.add(whisper('hey'));
    await tester.pump();
    await pump(tester, whispers: whispers, tab: ActivityTab.whispers);
    expect(find.text('Friend'), findsOneWidget);
    await tester.tap(find.text('Friend'));
    await tester.pumpAndSettle();
    expect(find.byType(WhisperConversation), findsOneWidget);
    expect(find.byType(WhispersList), findsNothing);
    expect(whispers.unreadCount, 0);
  });

  group('tablet', () {
    testWidgets('notifications beside the whispers, no tabs', (tester) async {
      final events = StreamController<EventSubTopicEvent>.broadcast();
      addTearDown(events.close);
      final whispers = whisperStore(events.stream);
      events.add(whisper('hey'));
      await tester.pump();
      await store.addAll([
        _entry('a', ago: const Duration(hours: 1)),
        _entry('b', ago: const Duration(days: 3), read: true),
      ]);
      // Whatever the phone's tab, both are on screen.
      await pump(
        tester,
        whispers: whispers,
        tab: ActivityTab.whispers,
        size: _tablet,
      );
      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('Most recent'), findsOneWidget);
      expect(find.text('Earlier'), findsOneWidget);
      expect(find.text('Title a'), findsOneWidget);
      expect(find.text('Whispers'), findsOneWidget);
      expect(find.text('Friend'), findsOneWidget);
      expect(find.text('See all'), findsOneWidget);

      // Mark all as read, with the count.
      expect(find.text('Mark all as read'), findsOneWidget);
      await tester.tap(find.text('Mark all as read'));
      await tester.pump();
      await tester.pump();
      expect(store.unreadCount, 0);
      expect(find.text('Mark all as read'), findsNothing);

      // A whisper opens the whispers on its conversation.
      await tester.tap(find.text('Friend'));
      await tester.pumpAndSettle();
      expect(find.byType(WhispersScreen), findsOneWidget);
      expect(whispers.openUserId, '8');
      await tester.pageBack();
      await tester.pumpAndSettle();

      // See all opens them too.
      await tester.tap(find.text('See all'));
      await tester.pumpAndSettle();
      expect(find.byType(WhispersScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a long press offers removal in a menu', (tester) async {
      await store.addAll([_entry('a', ago: const Duration(minutes: 5))]);
      await pump(tester, size: _tablet);
      await tester.longPress(find.text('Title a'));
      await tester.pumpAndSettle();
      expect(find.byType(PopupMenuItem<bool>), findsOneWidget);
      await tester.tap(find.text('Remove notification'));
      await tester.pumpAndSettle();
      expect(find.text('Title a'), findsNothing);
      expect(store.entries, isEmpty);
    });

    testWidgets('logged out: the notifications alone', (tester) async {
      await store.addAll([_entry('a', ago: const Duration(minutes: 5))]);
      await pump(tester, size: _tablet);
      expect(find.text('Title a'), findsOneWidget);
      expect(find.text('See all'), findsNothing);
    });

    testWidgets("empty: Twitch's up-to-date message", (tester) async {
      await pump(tester, size: _tabletPortrait);
      expect(find.text('Hooray! You’re up to date'), findsOneWidget);
    });
  });

  for (final theme in [ThemeMode.dark, ThemeMode.light]) {
    for (final size in [_phone, _tablet, _tabletPortrait]) {
      testWidgets('lays out at ${size.width}x${size.height} (${theme.name})', (
        tester,
      ) async {
        final events = StreamController<EventSubTopicEvent>.broadcast();
        addTearDown(events.close);
        final whispers = whisperStore(events.stream);
        events.add(whisper('a whisper ' * 20));
        await tester.pump();
        await store.addAll([
          for (var i = 0; i < 12; i++)
            _entry(
              '$i',
              ago: Duration(hours: i * 5),
              kind: ActivityKind.values[i % 3],
              login: i.isEven ? 'streamer' : null,
              read: i > 3,
            ),
        ]);
        await pump(tester, whispers: whispers, size: size, theme: theme);
        expect(tester.takeException(), isNull);
        if (size == _phone) {
          await pump(
            tester,
            whispers: whispers,
            tab: ActivityTab.whispers,
            size: size,
            theme: theme,
          );
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  group('in French', () {
    final french = lookupAppLocalizations(fr);

    for (final (sizeName, size) in frenchScreenSizes) {
      for (final scale in frenchTextScales) {
        testWidgets('empty, then notifications, $sizeName, text ×$scale', (
          tester,
        ) async {
          await pump(tester, size: size, locale: fr, textScale: scale);
          expect(find.text(french.activityEmpty), findsOneWidget);
          await expectFrenchThroughout(tester, 'empty');

          // The titles and bodies are what the notification said (written
          // when it was posted): Twitch names here.
          await store.addAll([
            for (final (id, ago, kind) in [
              ('1', const Duration(minutes: 5), ActivityKind.live),
              ('2', const Duration(hours: 3), ActivityKind.mention),
              ('3', const Duration(days: 9), ActivityKind.reminder),
            ])
              ActivityEntry(
                id: id,
                kind: kind,
                title: 'Streamer$id',
                body: 'Chess',
                login: 'streamer',
                at: _now.subtract(ago),
                read: id == '3',
              ),
          ]);
          await pump(tester, size: size, locale: fr, textScale: scale);
          expect(
            find.textContaining(french.activityKindMention),
            findsOneWidget,
          );
          await expectFrenchThroughout(tester, 'notifications');
        });
      }
    }

    for (final (sizeName, size) in frenchScreenSizes) {
      for (final scale in frenchTextScales) {
        testWidgets('notices posted in English read in French, $sizeName, '
            'text ×$scale', (tester) async {
          final english = lookupAppLocalizations(en);
          final reminder = ScheduleReminder(
            segmentId: 's1',
            login: 'streamer',
            channelName: 'Streamer',
            startAt: _now.subtract(const Duration(days: 2)),
            title: 'Tournoi',
            category: 'Échecs',
          ).entryIn(english);
          await store.addAll([
            ActivityEntry(
              id: 'live',
              kind: ActivityKind.live,
              title: english.notifGoLiveTitle(name: 'Streamer'),
              body: 'Partie classée · Échecs',
              login: 'streamer',
              at: _now.subtract(const Duration(minutes: 5)),
              params: const {
                'name': 'Streamer',
                'title': 'Partie classée',
                'category': 'Échecs',
              },
            ),
            ActivityEntry(
              id: 'mention',
              kind: ActivityKind.mention,
              title: english.notifMentionTitle(
                sender: 'Ami',
                channel: 'Streamer',
              ),
              body: 'salut @viewer',
              login: 'streamer',
              at: _now.subtract(const Duration(hours: 3)),
              params: const {'sender': 'Ami', 'channel': 'Streamer'},
            ),
            reminder,
            // Kept by an older version: its words as they were.
            ActivityEntry(
              id: 'old',
              kind: ActivityKind.live,
              title: 'Oldie is live',
              body: '',
              login: 'oldie',
              at: _now.subtract(const Duration(days: 20)),
            ),
          ]);
          await pump(tester, size: size, locale: fr, textScale: scale);
          await expectFrenchThroughout(
            tester,
            'reworded notices',
            content: const ['Oldie is live'],
          );
          expect(find.text('Streamer est en direct'), findsWidgets);
          expect(find.text('Échecs · Partie classée'), findsWidgets);
          expect(
            find.text('Ami vous mentionne dans le chat de la chaîne Streamer'),
            findsWidgets,
          );
          expect(find.text('Oldie is live'), findsWidgets);
        });
      }
    }
  });
}
