import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/go_live_setting.dart';
import 'package:onset/screens/settings/widgets/settings_list_switch.dart';
import 'package:onset/widgets/notification_permission_prompt.dart';

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
    if (!await explainUnlessAllowed(context, widget.platform.allowed)) return;
    await _ask();
    if (!_refused) widget.settingsStore.mentionNotifications = true;
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final on = widget.loggedIn && widget.settingsStore.mentionNotifications;
        final error = Theme.of(context).colorScheme.error;
        final l = context.l10n;
        final Widget subtitle;
        if (!widget.loggedIn) {
          subtitle = Text(l.mentionLoggedOut);
        } else if (_refused) {
          subtitle = Text(
            l.notificationsAllowInSystem,
            style: TextStyle(color: error),
          );
        } else if (on && _blocked) {
          subtitle = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.mentionBlocked, style: TextStyle(color: error)),
              TextButton(onPressed: _ask, child: Text(l.mentionAllow)),
            ],
          );
        } else {
          subtitle = Text(l.mentionDetail);
        }
        return SettingsListSwitch(
          title: l.mentionTitle,
          subtitle: subtitle,
          value: on,
          onChanged: widget.loggedIn ? _set : null,
        );
      },
    );
  }
}
