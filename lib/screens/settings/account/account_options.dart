import 'package:flutter/material.dart';
import 'package:frosty/screens/channel/channel.dart';
import 'package:frosty/screens/settings/account/blocked_users.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/widgets/settings_tile_route.dart';
import 'package:frosty/widgets/frosty_dialog.dart';
import 'package:frosty/widgets/frosty_scrollbar.dart';
import 'package:frosty/widgets/twitch_web_page.dart';

/// Account settings only twitch.tv can change: password, email, phone,
/// two-factor and verification; linked accounts.
const _twitchSettings = [
  (Icons.security_rounded, 'Security and privacy', '/settings/security'),
  (Icons.link_rounded, 'Connections', '/settings/connections'),
];

class AccountOptions extends StatelessWidget {
  final AuthStore authStore;

  const AccountOptions({super.key, required this.authStore});

  Future<void> _showLogoutDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => FrostyDialog(
        title: 'Log out',
        message: 'Are you sure you want to log out?',
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              authStore.logout();
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FrostyScrollbar(
      child: ListView(
        shrinkWrap: true,
        primary: false,
        children: [
          SettingsTileRoute(
            leading: const Icon(Icons.person_rounded),
            title: 'My channel',
            useScaffold: false,
            child: VideoChat(
              userId: authStore.user.details!.id,
              userName: authStore.user.details!.displayName,
              userLogin: authStore.user.details!.login,
            ),
          ),
          SettingsTileRoute(
            leading: const Icon(Icons.block_rounded),
            title: 'Blocked users',
            child: BlockedUsers(authStore: authStore),
          ),
          // Twitch's own pages, signed in (the app has no API for these).
          for (final (icon, title, path) in _twitchSettings)
            ListTile(
              leading: Icon(icon),
              title: Text(title),
              trailing: const Icon(Icons.open_in_new_rounded),
              onTap: () => TwitchWebPage.open(
                context,
                title: title,
                url: Uri.https('www.twitch.tv', path),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Log out'),
            onTap: () => _showLogoutDialog(context),
          ),
        ],
      ),
    );
  }
}
