import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/screens/home/shell/onset_shell.dart';
import 'package:frosty/screens/settings/account/account_settings.dart';
import 'package:frosty/screens/settings/settings.dart';
import 'package:frosty/screens/settings/settings_master_detail.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/settings/widgets/go_live_setting.dart';
import 'package:frosty/screens/settings/widgets/settings_glyph.dart';
import 'package:frosty/screens/settings/widgets/settings_kit.dart';
import 'package:frosty/screens/settings/widgets/settings_page.dart';
import 'package:frosty/services/go_live/go_live.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/widgets/motion/staggered_entrance.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The navigation shell's Profile: on a phone the board Moi (the viewer,
/// their account, the settings' sections, logging out) or MoiDeconnecte
/// (logged out); on a tablet the settings themselves, side column and pane
/// (ParametresTablette).
///
/// One state for both layouts: the tablet's page is kept when the window
/// crosses the tablet size and back.
class ProfileTab extends StatefulWidget {
  const ProfileTab({
    super.key,
    required this.settingsStore,
    required this.authStore,
    this.goLivePlatform = const GoLivePlatform(),
  });

  final SettingsStore settingsStore;
  final AuthStore authStore;

  /// Whether go-live notices exist here (Android).
  final GoLivePlatform goLivePlatform;

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _selection = SettingsSelection();

  /// Whether go-live notices are on, for the Notifications row; read again
  /// each time a page over the shell opens or closes (the settings).
  bool? _goLive;

  @override
  void initState() {
    super.initState();
    OnsetShell.routeObserver.addListener(_onRoutes);
    unawaited(_readGoLive());
  }

  void _onRoutes() => unawaited(_readGoLive());

  /// The latest read: an older one finishing after it is dropped.
  var _goLiveRead = 0;

  Future<void> _readGoLive() async {
    final read = ++_goLiveRead;
    try {
      final enabled = (await GoLivePrefs.load()).enabled;
      if (!mounted || read != _goLiveRead) return;
      if (enabled != _goLive) setState(() => _goLive = enabled);
    } catch (e) {
      debugPrint('Profile: go-live state unavailable: ${e.runtimeType}');
    }
  }

  @override
  void dispose() {
    OnsetShell.routeObserver.removeListener(_onRoutes);
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (context.isLargeScreen) {
      return SettingsMasterDetail(
        selection: _selection,
        settingsStore: widget.settingsStore,
        authStore: widget.authStore,
      );
    }
    return _PhoneProfile(
      settingsStore: widget.settingsStore,
      authStore: widget.authStore,
      notificationsSummary: _notificationsSummary,
    );
  }

  String _notificationsSummary(bool loggedIn) {
    if (!loggedIn) return 'Log in to get go-live and mention notifications';
    final mentions = widget.settingsStore.mentionNotifications ? 'on' : 'off';
    final goLive = _goLive;
    if (!widget.goLivePlatform.supported || goLive == null) {
      return 'Mentions $mentions';
    }
    return 'Go-live ${goLive ? 'on' : 'off'} · mentions $mentions';
  }
}

class _PhoneProfile extends StatelessWidget {
  const _PhoneProfile({
    required this.settingsStore,
    required this.authStore,
    required this.notificationsSummary,
  });

  final SettingsStore settingsStore;
  final AuthStore authStore;
  final String Function(bool loggedIn) notificationsSummary;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return StaggerScope(
      child: Observer(
        builder: (context) {
          final loggedIn = hasAccount(authStore);
          final sections = <Widget>[
            if (loggedIn)
              _ProfileHeader(
                authStore: authStore,
                onSettings: () => Settings.open(context),
              )
            else
              ProfileLoginCard(authStore: authStore),
            if (loggedIn) _AccountCard(authStore: authStore),
            _SettingsCard(
              settingsStore: settingsStore,
              authStore: authStore,
              notificationsSummary: notificationsSummary(authStore.isLoggedIn),
            ),
            if (loggedIn)
              SettingsGroup(
                children: [
                  SettingsRow(
                    glyph: SettingsGlyphKind.logout,
                    title: 'Log out',
                    danger: true,
                    strong: true,
                    onTap: () => confirmLogout(context, authStore),
                  ),
                ],
              ),
            const _Version(),
          ];
          return ListView(
            padding: EdgeInsets.fromLTRB(
              16 + padding.left,
              padding.top + 18,
              16 + padding.right,
              padding.bottom + 24,
            ),
            children: [
              for (final (index, section) in sections.indexed)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: index == sections.length - 1 ? 0 : 22,
                  ),
                  child: StaggeredEntrance(index: index, child: section),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The viewer: picture, name, login, when they joined; "My channel" and
/// "Settings".
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.authStore, required this.onSettings});

  final AuthStore authStore;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    final ground = Theme.of(context).scaffoldBackgroundColor;
    final details = authStore.user.details!;
    final joined = joinedText(details);
    return Semantics(
      container: true,
      label: 'Your profile',
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          Row(
            spacing: 16,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: colors.buttonRing, spreadRadius: 3.5),
                    BoxShadow(color: ground, spreadRadius: 2),
                  ],
                ),
                child: SettingsAvatar(user: details, size: 76),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        details.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: FrostyTokens.bodyFamily,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.78,
                          height: 1.1,
                          color: colors.text,
                        ),
                      ),
                    ),
                    Text(
                      '@${details.login}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: FrostyTokens.bodyFamily,
                        fontSize: 14,
                        color: colors.body,
                      ),
                    ),
                    if (joined != null)
                      Row(
                        spacing: 6,
                        children: [
                          SettingsGlyph(
                            SettingsGlyphKind.calendar,
                            size: 14,
                            color: colors.secondary,
                          ),
                          Flexible(
                            child: Text(
                              joined,
                              style: TextStyle(
                                fontFamily: FrostyTokens.bodyFamily,
                                fontSize: 12.5,
                                color: colors.secondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: SettingsButton(
                  label: 'My channel',
                  expand: true,
                  icon: SettingsGlyph(
                    SettingsGlyphKind.play,
                    size: 13,
                    color: colors.text,
                  ),
                  onPressed: () => openMyChannel(context, authStore),
                ),
              ),
              Expanded(
                child: SettingsButton(
                  label: 'Settings',
                  expand: true,
                  icon: SettingsGlyph(
                    SettingsGlyphKind.general,
                    size: 16,
                    color: colors.text,
                  ),
                  onPressed: onSettings,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "ACCOUNT": blocked users, and Twitch's own account pages.
class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.authStore});

  final AuthStore authStore;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) => SettingsGroup(
        title: 'Account',
        children: [
          SettingsRow(
            glyph: SettingsGlyphKind.ban,
            title: 'Blocked users',
            strong: true,
            value: '${authStore.user.blockedUsers.length}',
            end: SettingsRowEnd.chevron,
            onTap: () => openBlockedUsers(context, authStore),
          ),
          for (final (glyph, title, detail, path) in twitchAccountPages)
            SettingsRow(
              glyph: glyph,
              title: title,
              strong: true,
              subtitle: Text(detail),
              end: SettingsRowEnd.external,
              onTap: () => openTwitchAccountPage(context, title, path),
            ),
        ],
      ),
    );
  }
}

/// "SETTINGS": the sections, each opening its page.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.settingsStore,
    required this.authStore,
    required this.notificationsSummary,
  });

  final SettingsStore settingsStore;
  final AuthStore authStore;
  final String notificationsSummary;

  @override
  Widget build(BuildContext context) {
    return SettingsGroup(
      title: 'Settings',
      children: [
        for (final page in SettingsPageId.sections)
          SettingsSectionRow(
            page: page,
            settingsStore: settingsStore,
            authStore: authStore,
            summary: page == SettingsPageId.notifications
                ? notificationsSummary
                : null,
          ),
      ],
    );
  }
}

/// "ONSET v5.0.5 (68)".
class _Version extends StatefulWidget {
  const _Version();

  @override
  State<_Version> createState() => _VersionState();
}

class _VersionState extends State<_Version> {
  final _info = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: _info,
      builder: (context, snapshot) {
        final info = snapshot.data;
        return Text(
          info == null ? '' : 'ONSET v${info.version} (${info.buildNumber})',
          textAlign: TextAlign.center,
          style: FrostyType.tabular(
            TextStyle(
              fontFamily: FrostyTokens.bodyFamily,
              fontSize: 12,
              color: SettingsColors.of(context).tertiary,
            ),
          ),
        );
      },
    );
  }
}
