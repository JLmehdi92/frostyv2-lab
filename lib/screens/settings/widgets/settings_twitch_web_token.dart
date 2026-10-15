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
            'signed-in viewer. Paste the value of the "auth-token" cookie '
            'from twitch.tv in a browser to unlock it. Leave empty to stay '
            'anonymous.',
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: TextField(
            controller: controller,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'auth-token',
              border: OutlineInputBorder(),
            ),
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

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) => ListTile(
        trailing: const Icon(Icons.edit),
        title: const Text('Twitch web token (2K)'),
        subtitle: Text(
          authStore.twitchWebToken == null
              ? 'Not set — 2K/HEVC qualities may be unavailable'
              : 'Set — enhanced qualities requested',
        ),
        onTap: () => _edit(context),
      ),
    );
  }
}
