import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/settings/widgets/go_live_setting.dart';
import 'package:frosty/screens/settings/widgets/settings_list_switch.dart';

/// Turns chat mention notices on or off (Twitch's "Chat Mentions").
class MentionNotificationSetting extends StatefulWidget {
  const MentionNotificationSetting({
    super.key,
    required this.settingsStore,
    required this.loggedIn,
    this.platform = const GoLivePlatform(),
  });

  final SettingsStore settingsStore;

  /// Mentions name the logged-in viewer: nothing to notify when logged out.
  final bool loggedIn;

  /// The right to notify, shared with the go-live notices.
  final GoLivePlatform platform;

  @override
  State<MentionNotificationSetting> createState() =>
      _MentionNotificationSettingState();
}

class _MentionNotificationSettingState
    extends State<MentionNotificationSetting> {
  var _blocked = false;
  var _refused = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final allowed = await widget.platform.allowed().catchError((_) => true);
    if (mounted) setState(() => _blocked = !allowed);
  }

  Future<void> _ask() async {
    final granted = await widget.platform.requestPermission().catchError(
      (_) => false,
    );
    if (!mounted) return;
    setState(() {
      _refused = !granted;
      if (granted) _blocked = false;
    });
  }

  Future<void> _set(bool on) async {
    if (!on) {
      widget.settingsStore.mentionNotifications = false;
      setState(() => _refused = false);
      return;
    }
    await _ask();
    if (!_refused) widget.settingsStore.mentionNotifications = true;
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final on = widget.loggedIn && widget.settingsStore.mentionNotifications;
        final error = Theme.of(context).colorScheme.error;
        final Widget subtitle;
        if (!widget.loggedIn) {
          subtitle = const Text(
            'Log in to be told when someone mentions you in chat.',
          );
        } else if (_refused) {
          subtitle = Text(
            'Allow notifications for this app in the system settings.',
            style: TextStyle(color: error),
          );
        } else if (on && _blocked) {
          subtitle = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notifications are blocked for this app.',
                style: TextStyle(color: error),
              ),
              TextButton(onPressed: _ask, child: const Text('Allow')),
            ],
          );
        } else {
          subtitle = const Text(
            'When someone mentions you in a chat you are watching while '
            'ONSET is in the background or in picture-in-picture.',
          );
        }
        return SettingsListSwitch(
          title: 'Chat mention notifications',
          subtitle: subtitle,
          value: on,
          onChanged: widget.loggedIn ? _set : null,
        );
      },
    );
  }
}
