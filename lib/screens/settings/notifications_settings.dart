import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/notifications/notification_center_screen.dart';
import 'package:onset/screens/settings/account/account_settings.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/go_live_setting.dart';
import 'package:onset/screens/settings/widgets/mention_notification_setting.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';
import 'package:onset/screens/settings/widgets/settings_page.dart';
import 'package:onset/screens/settings/widgets/twitch_notification_settings.dart';

/// Settings › Notifications: go-live notices for the
/// channels followed, chat mentions. Both were under General before.
class NotificationsSettings extends StatelessWidget {
  final SettingsStore settingsStore;
  final AuthStore authStore;

  const NotificationsSettings({
    super.key,
    required this.settingsStore,
    required this.authStore,
  });

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final loggedIn = authStore.isLoggedIn;
        return SettingsGroupsView(
          children: [
            SettingsGroup(
              title: context.l10n.settingsChannelsYouFollow,
              children: [
                GoLiveSetting(
                  userId: loggedIn ? authStore.user.details?.id : null,
                ),
              ],
            ),
            SettingsGroup(
              title: context.l10n.settingsPageChat,
              children: [
                MentionNotificationSetting(
                  settingsStore: settingsStore,
                  loggedIn: loggedIn,
                ),
              ],
            ),
            if (twitchInboxOf(context) case final inbox?)
              TwitchNotificationSettingsGroup(
                load: () => inbox.service.notificationSettings(
                  userId: inbox.userId,
                  authToken: inbox.token,
                ),
                onEdit: () => openTwitchAccountPage(
                  context,
                  TwitchAccountPage.notifications,
                ),
              ),
          ],
        );
      },
    );
  }
}
