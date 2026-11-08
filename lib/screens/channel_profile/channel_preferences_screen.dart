import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';
import 'package:onset/screens/settings/widgets/settings_list_switch.dart';
import 'package:onset/screens/settings/widgets/settings_page.dart';
import 'package:onset/services/go_live/go_live.dart';

class ChannelPreferencesScreen extends StatefulWidget {
  const ChannelPreferencesScreen({
    super.key,
    required this.channelId,
    required this.name,
    required this.settingsStore,
    required this.loggedIn,
    this.goLivePrefs = GoLivePrefs.load,
  });

  final String channelId;
  final String name;
  final SettingsStore settingsStore;
  final bool loggedIn;
  final Future<GoLivePrefs> Function() goLivePrefs;

  static const routeName = '/channel-preferences';

  static Future<void> open(
    BuildContext context, {
    required String channelId,
    required String name,
    required SettingsStore settingsStore,
    required bool loggedIn,
  }) => Navigator.push(
    context,
    MaterialPageRoute(
      settings: const RouteSettings(name: routeName),
      builder: (context) => SettingsScaffold(
        title: context.l10n.channelPrefsTitle,
        body: ChannelPreferencesScreen(
          channelId: channelId,
          name: name,
          settingsStore: settingsStore,
          loggedIn: loggedIn,
        ),
      ),
    ),
  );

  @override
  State<ChannelPreferencesScreen> createState() =>
      _ChannelPreferencesScreenState();
}

class _ChannelPreferencesScreenState extends State<ChannelPreferencesScreen> {
  GoLivePrefs? _goLive;

  @override
  void initState() {
    super.initState();
    if (widget.loggedIn) {
      unawaited(
        widget.goLivePrefs().then((prefs) {
          if (mounted) setState(() => _goLive = prefs);
        }, onError: (Object e) => debugPrint('Go-live prefs failed: $e')),
      );
    }
  }

  List<String> _toggled(List<String> ids, bool include) => [
    for (final id in ids)
      if (id != widget.channelId) id,
    if (include) widget.channelId,
  ];

  Future<void> _setBell(GoLivePrefs prefs, bool on) async {
    try {
      await prefs.setMuted(widget.channelId, !on);
    } catch (e) {
      debugPrint('Bell change failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.goLiveBellFailed)));
      }
    }
    if (mounted) setState(() {});
  }

  Widget _bellGroup(BuildContext context) {
    final l = context.l10n;
    final prefs = _goLive;
    final enabled = prefs != null && prefs.enabled;
    return SettingsGroup(
      title: l.channelPrefsNotifications,
      children: [
        SettingsListSwitch(
          key: const ValueKey('channel-prefs-bell'),
          title: l.channelPrefsBell,
          subtitle: Text(
            !widget.loggedIn
                ? l.channelPrefsBellLoggedOut
                : enabled
                ? l.channelPrefsBellDetail(name: widget.name)
                : l.channelPrefsBellOff,
          ),
          value: enabled && !prefs.muted.contains(widget.channelId),
          onChanged: enabled ? (on) => unawaited(_setBell(prefs, on)) : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final settings = widget.settingsStore;
    return Observer(
      builder: (context) {
        final noticesOn = settings.showUserNotices;
        return SettingsGroupsView(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SettingsNote(l.channelPrefsIntro(name: widget.name)),
            ),
            _bellGroup(context),
            SettingsGroup(
              title: l.channelPrefsChat,
              children: [
                SettingsListSwitch(
                  key: const ValueKey('channel-prefs-notices'),
                  title: l.channelPrefsNotices,
                  subtitle: Text(
                    noticesOn
                        ? l.channelPrefsNoticesDetail
                        : l.channelPrefsNoticesOff,
                  ),
                  value: settings.showsNoticesIn(widget.channelId),
                  onChanged: noticesOn
                      ? (on) => settings.noticesHiddenChannelIds = _toggled(
                          settings.noticesHiddenChannelIds,
                          !on,
                        )
                      : null,
                ),
              ],
            ),
            SettingsGroup(
              title: l.channelPrefsLists,
              children: [
                SettingsListSwitch(
                  key: const ValueKey('channel-prefs-pin'),
                  title: l.channelPrefsPin,
                  subtitle: Text(l.channelPrefsPinDetail),
                  value: settings.pinnedChannelIds.contains(widget.channelId),
                  onChanged: (on) => settings.pinnedChannelIds = _toggled(
                    settings.pinnedChannelIds,
                    on,
                  ),
                ),
                SettingsListSwitch(
                  key: const ValueKey('channel-prefs-hide'),
                  title: l.channelPrefsHide,
                  subtitle: Text(l.channelPrefsHideDetail),
                  value: settings.hiddenChannelIds.contains(widget.channelId),
                  onChanged: (on) => settings.hiddenChannelIds = _toggled(
                    settings.hiddenChannelIds,
                    on,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
