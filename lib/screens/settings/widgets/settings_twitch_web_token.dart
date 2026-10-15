import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/widgets/frosty_dialog.dart';

/// Lets the user store the twitch.tv web session token (the `auth-token`
/// cookie) that unlocks Twitch's enhanced-broadcast renditions.
///
/// Twitch only offers the 1440p HEVC / AV1 tracks of some streams to an
/// authenticated viewer, and its GQL endpoint rejects tokens minted for
/// Frosty's own client-id — so the web token is the only way to ask for them.
/// Leaving it empty keeps the previous anonymous behaviour.
class SettingsTwitchWebToken extends StatelessWidget {
  final AuthStore authStore;

  const SettingsTwitchWebToken({super.key, required this.authStore});

  Future<void> _edit(BuildContext context) async {
    final controller = TextEditingController(
      text: authStore.twitchWebToken ?? '',
    );

    await showDialog<void>(
      context: context,
      builder: (context) => FrostyDialog(
        title: 'Twitch web token (2K)',
        message:
            'Some streams only offer their 2K (1440p HEVC) quality to a '
            'signed-in viewer. This is normally picked up on its own when you '
            'log in, and refreshed on each launch — you should never need to '
            'touch it. Fill it in by hand only if that fails: paste the value '
            'of the "auth-token" cookie from twitch.tv in a browser. Leave '
            'empty to stay anonymous.',
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: TextField(
            controller: controller,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(labelText: 'auth-token'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await authStore.setTwitchWebToken(controller.text);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();
  }

  /// What the tile says about the token, in the three states that matter to
  /// the user rather than the three the code tracks.
  String _status() {
    if (authStore.webSessionExpired) {
      return 'Twitch session expired — log in again to restore 2K';
    }
    return authStore.twitchWebToken == null
        ? 'Not set — log in to pick it up automatically'
        : 'Active — picked up automatically, 2K requested';
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) => ListTile(
        trailing: const Icon(Icons.edit),
        title: const Text('Twitch web token (2K)'),
        subtitle: Text(_status()),
        onTap: () => _edit(context),
      ),
    );
  }
}
