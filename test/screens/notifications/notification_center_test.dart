import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/apis/twitch_social_service.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/models/onsite_notification.dart';
import 'package:onset/screens/notifications/notification_center_screen.dart';
import 'package:onset/screens/notifications/stores/notification_center_store.dart';
import 'package:onset/screens/settings/widgets/twitch_notification_settings.dart';

import '../../fixtures/social_payloads.dart';
import '../../helpers/l10n.dart';

OnsiteNotification _n(String id, {bool read = false}) =>
    OnsiteNotification.fromJson(onsiteNotificationNode(id: id, isRead: read))!;

void main() {
  group('store', () {
    test('refreshes, pages without duplicates, and marks all read', () async {
      final cursors = <String?>[];
      final marked = <List<String>>[];
      final store = NotificationCenterStore(
        fetch: (cursor) async {
          cursors.add(cursor);
          return cursor == null
              ? OnsiteNotificationPage(
                  notifications: [_n('a'), _n('b', read: true)],
                  cursor: 'next',
                )
              : OnsiteNotificationPage(notifications: [_n('b'), _n('c')]);
        },
        markRead: (ids) async {
          marked.add(ids);
          return ViewerActionOutcome.done;
        },
      );

      await store.refresh();
      expect(store.unreadCount, 1);
      expect(store.hasMore, isTrue);

      await store.loadMore();
      expect(store.notifications.map((n) => n.id), ['a', 'b', 'c']);
      expect(store.hasMore, isFalse);
      expect(cursors, [null, 'next']);

      expect(await store.markAllRead(), ViewerActionOutcome.done);
      expect(marked, [
        ['a', 'c'],
      ]);
      expect(store.unreadCount, 0);
    });

    test('a refused mark keeps them unread; a failure says so', () async {
      final store = NotificationCenterStore(
        fetch: (_) async => null,
        markRead: (_) async => ViewerActionOutcome.failed,
      );
      await store.refresh();
      expect(store.failed, isTrue);
      expect(await store.markAllRead(), isNull);

      final unread = NotificationCenterStore(
        fetch: (_) async =>
            OnsiteNotificationPage(notifications: [_n('a')]),
        markRead: (_) async => ViewerActionOutcome.integrityRefused,
      );
      await unread.refresh();
      expect(await unread.markAllRead(), ViewerActionOutcome.integrityRefused);
      expect(unread.unreadCount, 1);
    });
  });

  testWidgets('the screen lists notifications and marks them read on tap', (
    tester,
  ) async {
    final opened = <String>[];
    var marked = 0;
    final store = NotificationCenterStore(
      fetch: (_) async => OnsiteNotificationPage(notifications: [_n('a')]),
      markRead: (_) async {
        marked++;
        return ViewerActionOutcome.done;
      },
    );
    await pumpLocalized(
      tester,
      NotificationCenterScreen(
        store: store,
        onOpenChannel: opened.add,
        now: () => DateTime.utc(2026, 11, 8, 21),
      ),
      locale: en,
    );
    await tester.pumpAndSettle();

    expect(find.text('Twitch notifications'), findsOneWidget);
    expect(find.text('Friend is live: Morning run'), findsOneWidget);
    await tester.tap(find.text('Friend is live: Morning run'));
    expect(opened, ['friend']);

    await tester.tap(find.byKey(NotificationCenterScreen.markAllKey));
    await tester.pumpAndSettle();
    expect(marked, 1);
    expect(find.byKey(NotificationCenterScreen.markAllKey), findsNothing);
    expect(find.text('Done.'), findsOneWidget);
  });

  testWidgets('a failure offers to try again', (tester) async {
    final store = NotificationCenterStore(
      fetch: (_) async => null,
      markRead: (_) async => ViewerActionOutcome.done,
    );
    await pumpLocalized(
      tester,
      NotificationCenterScreen(store: store, onOpenChannel: (_) {}),
      locale: en,
    );
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t load your Twitch notifications.'), findsOneWidget);
  });

  testWidgets('the entry hides without a Twitch web session', (tester) async {
    await pumpLocalized(
      tester,
      Scaffold(body: TwitchInboxEntry(onOpenChannel: (_) {})),
      locale: en,
    );
    expect(find.byKey(TwitchInboxEntry.tileKey), findsNothing);
  });

  testWidgets('settings show push and email per category', (tester) async {
    final edits = <int>[];
    final settings = Completer<List<NotificationCategorySetting>?>();
    await pumpLocalized(
      tester,
      Scaffold(
        body: ListView(
          children: [
            TwitchNotificationSettingsGroup(
              load: () => settings.future,
              onEdit: () => edits.add(1),
            ),
          ],
        ),
      ),
      locale: en,
    );
    settings.complete([
      const NotificationCategorySetting(
        category: 'live',
        platforms: {
          NotificationPlatform.push: true,
          NotificationPlatform.email: false,
        },
      ),
      const NotificationCategorySetting(
        category: 'vod_comment_reply',
        platforms: {NotificationPlatform.push: false},
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Live channels'), findsOneWidget);
    expect(find.text('Push on · email off'), findsOneWidget);
    expect(find.text('Vod comment reply'), findsOneWidget);
    expect(find.text('Push off · no email'), findsOneWidget);
    await tester.tap(find.byKey(TwitchNotificationSettingsGroup.editKey));
    expect(edits, [1]);
  });

  testWidgets('unreadable settings keep only the twitch.tv link', (
    tester,
  ) async {
    await pumpLocalized(
      tester,
      Scaffold(
        body: ListView(
          children: [
            TwitchNotificationSettingsGroup(
              load: () async => null,
              onEdit: () {},
            ),
          ],
        ),
      ),
      locale: en,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Couldn’t load your Twitch notification'), findsOneWidget);
    expect(find.byKey(TwitchNotificationSettingsGroup.editKey), findsOneWidget);
  });
}
