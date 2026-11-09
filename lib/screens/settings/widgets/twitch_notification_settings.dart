import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/onsite_notification.dart';
import 'package:onset/screens/settings/widgets/settings_glyph.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';

class TwitchNotificationSettingsGroup extends StatefulWidget {
  const TwitchNotificationSettingsGroup({
    super.key,
    required this.load,
    required this.onEdit,
  });

  static const editKey = ValueKey('twitch-notification-settings-edit');

  final Future<List<NotificationCategorySetting>?> Function() load;
  final VoidCallback onEdit;

  @override
  State<TwitchNotificationSettingsGroup> createState() =>
      _TwitchNotificationSettingsGroupState();
}

class _TwitchNotificationSettingsGroupState
    extends State<TwitchNotificationSettingsGroup> {
  List<NotificationCategorySetting>? _settings;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    final settings = await widget.load();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final settings = _settings;
    return SettingsGroup(
      title: l.twitchNotificationSettingsTitle,
      children: [
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (settings == null)
          SettingsNote(l.twitchNotificationSettingsUnavailable)
        else
          for (final setting in settings)
            SettingsRow(
              glyph: SettingsGlyphKind.bell,
              title: notificationCategoryLabel(l, setting.category),
              subtitle: Text(
                l.twitchNotificationPlatforms(
                  push: _state(setting, NotificationPlatform.push),
                  email: _state(setting, NotificationPlatform.email),
                ),
              ),
            ),
        SettingsRow(
          key: TwitchNotificationSettingsGroup.editKey,
          glyph: SettingsGlyphKind.link,
          title: l.twitchNotificationSettingsEdit,
          end: SettingsRowEnd.external,
          onTap: widget.onEdit,
        ),
      ],
    );
  }

  static String _state(
    NotificationCategorySetting setting,
    NotificationPlatform platform,
  ) => switch (setting.platforms[platform]) {
    true => 'on',
    false => 'off',
    null => 'none',
  };
}

String notificationCategoryLabel(AppLocalizations l, String category) {
  final key = category.toLowerCase();
  if (key.contains('live') || key.contains('stream_up')) {
    return l.notificationCategoryLive;
  }
  if (key.contains('whisper')) return l.notificationCategoryWhispers;
  final words = key.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
  return words.isEmpty
      ? category
      : '${words[0].toUpperCase()}${words.substring(1)}';
}
