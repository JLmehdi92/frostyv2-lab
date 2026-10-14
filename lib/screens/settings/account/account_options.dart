import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/screens/channel/channel.dart';
import 'package:frosty/screens/onboarding/login_webview.dart';
import 'package:frosty/screens/settings/account/blocked_users.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/widgets/settings_tile_route.dart';
import 'package:frosty/stores/web_session_store.dart';
import 'package:frosty/widgets/frosty_dialog.dart';
import 'package:frosty/widgets/frosty_scrollbar.dart';
import 'package:provider/provider.dart';

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
          const _WebSessionTile(),
          SettingsTileRoute(
            leading: const Icon(Icons.block_rounded),
            title: 'Blocked users',
            child: BlockedUsers(authStore: authStore),
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

/// The twitch.tv session used for account features: connected (and to
/// whom), or how to connect it (logging in again picks it up).
class _WebSessionTile extends StatelessWidget {
  const _WebSessionTile();

  @override
  Widget build(BuildContext context) {
    final session = context.read<WebSessionStore>();
    return Observer(
      builder: (context) {
        if (session.isConnected) {
          return ListTile(
            leading: const Icon(Icons.verified_user_rounded),
            title: const Text('Twitch session'),
            subtitle: Text(
              'Connected as ${session.login}. Used for follows, channel '
              'points, polls and predictions.',
            ),
            trailing: TextButton(
              onPressed: session.disconnect,
              child: const Text('Disconnect'),
            ),
          );
        }
        return ListTile(
          leading: const Icon(Icons.link_rounded),
          title: const Text('Connect Twitch session'),
          subtitle: Text(
            session.error ??
                'Log in again to use follows, channel points, polls and '
                    'predictions. The session stays on this device.',
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const LoginWebView()),
          ),
        );
      },
    );
  }
}
