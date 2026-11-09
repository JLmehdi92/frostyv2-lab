import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/apis/twitch_social_service.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/models/onsite_notification.dart';
import 'package:onset/models/recommended_channel.dart';
import 'package:onset/models/whisper_history.dart';
import 'package:onset/screens/notifications/notification_center_screen.dart';
import 'package:onset/screens/notifications/stores/notification_center_store.dart';
import 'package:onset/screens/settings/account/whisper_privacy_settings.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/twitch_notification_settings.dart';
import 'package:onset/widgets/recommendations/recommended_channels.dart';
import 'package:provider/provider.dart';

import '../fixtures/social_payloads.dart';
import 'helpers_lot8c.dart';
import '../helpers/l10n.dart';

void main() {
  for (final (sizeName, size) in frenchScreenSizes) {
    for (final scale in frenchTextScales) {
      final at = '$sizeName, text ×$scale';

      testWidgets('the Twitch notification center, $at', (tester) async {
        final store = NotificationCenterStore(
          fetch: (_) async => OnsiteNotificationPage(
            notifications: [
              OnsiteNotification.fromJson(onsiteNotificationNode())!,
              OnsiteNotification.fromJson(
                onsiteNotificationNode(id: 'n2', isRead: true),
              )!,
            ],
          ),
          markRead: (_) async => ViewerActionOutcome.done,
        );
        await pumpLocalized(
          tester,
          NotificationCenterScreen(
            store: store,
            onOpenChannel: (_) {},
            now: () => DateTime.utc(2026, 11, 8, 21),
          ),
          size: size,
          textScale: scale,
        );
        await tester.pumpAndSettle();
        await expectFrenchThroughout(
          tester,
          'notification center, $at',
          content: const ['Friend is live: Morning run'],
        );
      });

      testWidgets('the empty notification center, $at', (tester) async {
        await pumpLocalized(
          tester,
          NotificationCenterScreen(
            store: NotificationCenterStore(
              fetch: (_) async =>
                  const OnsiteNotificationPage(notifications: []),
              markRead: (_) async => ViewerActionOutcome.done,
            ),
            onOpenChannel: (_) {},
          ),
          size: size,
          textScale: scale,
        );
        await tester.pumpAndSettle();
        await expectFrenchThroughout(tester, 'empty center, $at');
      });

      testWidgets('the whisper privacy and Twitch notification settings, $at',
          (tester) async {
        await pumpLocalized(
          tester,
          Scaffold(
            body: ListView(
              children: [
                WhisperPrivacyGroup(
                  load: () async => const WhisperPrivacy(
                    blockStrangers: true,
                    disabledByParent: true,
                  ),
                  save: (_) async => ViewerActionOutcome.done,
                ),
                TwitchNotificationSettingsGroup(
                  load: () async => const [
                    NotificationCategorySetting(
                      category: 'live',
                      platforms: {
                        NotificationPlatform.push: true,
                        NotificationPlatform.email: false,
                      },
                    ),
                    NotificationCategorySetting(
                      category: 'whispers',
                      platforms: {NotificationPlatform.push: false},
                    ),
                  ],
                  onEdit: () {},
                ),
              ],
            ),
          ),
          size: size,
          textScale: scale,
        );
        await tester.pumpAndSettle();
        await expectFrenchThroughout(tester, 'privacy settings, $at');
      });

      testWidgets('suggestions and not interested, $at', (tester) async {
        final settings = SettingsStore();
        await pumpLocalized(
          tester,
          Provider<SettingsStore>.value(
            value: settings,
            child: Scaffold(
              body: ListView(
                children: [
                  RecommendationsShelf(load: () async => lot8cChannels()),
                  SimilarChannelsSheet(
                    name: 'StreamerWithALongName',
                    load: () async => lot8cChannels(),
                    onOpen: (_) {},
                    onNotInterested: (_) {},
                  ),
                  Builder(
                    builder: (context) => TextButton(
                      key: const ValueKey('go'),
                      onPressed: () => markNotInterested(
                        context,
                        lot8cChannels().last,
                        tellTwitch: (c, r) async => ViewerActionOutcome.done,
                      ),
                      child: const Text('·'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          size: size,
          textScale: scale,
        );
        await tester.pumpAndSettle();
        await expectFrenchThroughout(
          tester,
          'suggestions, $at',
          content: const [
            'StreamerWithALongName',
            'Alpha_Live',
            'beta',
            'Just Chatting',
            'Chess',
          ],
        );
        await tester.tap(find.byKey(const ValueKey('go')));
        await tester.pumpAndSettle();
        await expectFrenchThroughout(
          tester,
          'not interested reasons, $at',
          content: const ['beta'],
        );
        expect(NotInterestedReason.values, hasLength(3));
      });
    }
  }
}
