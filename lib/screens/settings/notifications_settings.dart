import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/settings/widgets/go_live_setting.dart';
import 'package:frosty/screens/settings/widgets/mention_notification_setting.dart';
import 'package:frosty/screens/settings/widgets/settings_kit.dart';
import 'package:frosty/screens/settings/widgets/settings_page.dart';

/// Settings › Notifications (board Parametres): go-live notices for the
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
              title: 'Channels you follow',
              children: [
                GoLiveSetting(
                  userId: loggedIn ? authStore.user.details?.id : null,
                ),
              ],
            ),
            SettingsGroup(
              title: 'Chat',
              children: [
                MentionNotificationSetting(
                  settingsStore: settingsStore,
                  loggedIn: loggedIn,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
