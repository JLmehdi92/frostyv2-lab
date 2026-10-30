import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/screens/settings/account/account_settings.dart';
import 'package:onset/screens/settings/account/blocked_users.dart';
import 'package:onset/screens/settings/chat_settings.dart';
import 'package:onset/screens/settings/general_settings.dart';
import 'package:onset/screens/settings/notifications_settings.dart';
import 'package:onset/screens/settings/other_settings.dart';
import 'package:onset/screens/settings/settings_master_detail.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/video_settings.dart';
import 'package:onset/screens/settings/widgets/settings_glyph.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';
import 'package:onset/screens/settings/widgets/settings_page.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:provider/provider.dart';

/// The settings page pushed over the app (Profile's "Settings", the chat's
/// menu): on a phone its first page (the account, the sections, then
/// Other's groups); on a tablet a side column and a pane.
class Settings extends StatefulWidget {
  static const routeName = 'Settings';

  final SettingsStore settingsStore;

  /// The page the tablet's pane opens on.
  final SettingsPageId initialPage;

  const Settings({
    super.key,
    required this.settingsStore,
    this.initialPage = SettingsPageId.general,
  });

  /// Pushes the settings.
  static Future<void> open(
    BuildContext context, {
    SettingsPageId initialPage = SettingsPageId.general,
  }) => Navigator.of(context).push(
    MaterialPageRoute(
      settings: const RouteSettings(name: routeName),
      builder: (context) => Settings(
        settingsStore: context.read<SettingsStore>(),
        initialPage: initialPage,
      ),
    ),
  );

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  // Kept here: the tablet's page survives a rotation or a fold to a phone
  // size and back.
  late final _selection = SettingsSelection(page: widget.initialPage);

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authStore = context.read<AuthStore>();
    return SettingsScaffold(
      title: 'Settings',
      body: context.isLargeScreen
          ? SettingsMasterDetail(
              selection: _selection,
              settingsStore: widget.settingsStore,
              authStore: authStore,
            )
          : SettingsHome(
              settingsStore: widget.settingsStore,
              authStore: authStore,
            ),
    );
  }
}

/// The phone's first settings page: the account card, the sections, then
/// Other's groups and the version.
class SettingsHome extends StatelessWidget {
  const SettingsHome({
    super.key,
    required this.settingsStore,
    required this.authStore,
  });

  final SettingsStore settingsStore;
  final AuthStore authStore;

  @override
  Widget build(BuildContext context) {
    return SettingsGroupsView(
      footer: const SettingsFooter(),
      children: [
        SettingsAccountCard(authStore: authStore),
        SettingsGroup(
          title: 'Customize',
          children: [
            for (final page in SettingsPageId.customize)
              SettingsSectionRow(
                page: page,
                settingsStore: settingsStore,
                authStore: authStore,
              ),
          ],
        ),
        ...otherSettingsGroups(context, settingsStore),
      ],
    );
  }
}

/// The line under a section in Profile and the phone's settings.
String settingsSectionSummary(SettingsPageId page, {required bool loggedIn}) =>
    switch (page) {
      SettingsPageId.general => 'Theme, accent color, browse, links',
      SettingsPageId.video => 'Low-latency player, captions, overlay',
      SettingsPageId.chat => 'Sizing, alerts, filters, emotes',
      SettingsPageId.notifications =>
        loggedIn
            ? 'Go-live and chat mentions'
            : 'Log in to get go-live and mention notifications',
      SettingsPageId.other => 'Updates, cache, privacy, about',
      _ => '',
    };

/// A section of the settings (General, Video…): its icon, its name and what
/// is in it; opens its page.
class SettingsSectionRow extends StatelessWidget {
  const SettingsSectionRow({
    super.key,
    required this.page,
    required this.settingsStore,
    required this.authStore,
    this.summary,
  });

  final SettingsPageId page;
  final SettingsStore settingsStore;
  final AuthStore authStore;

  /// What the line under the name says (its section summary by default).
  final String? summary;

  @override
  Widget build(BuildContext context) {
    Widget row(String summary) => SettingsRow(
      glyph: page.glyph,
      title: page.title,
      strong: true,
      minHeight: 60,
      subtitle: Text(summary),
      end: SettingsRowEnd.chevron,
      onTap: () => openSettingsPage(
        context,
        id: page,
        builder: (context) => buildSettingsPage(
          page,
          settingsStore: settingsStore,
          authStore: authStore,
        ),
      ),
    );
    // A given summary is already up to date (its owner observes it).
    if (summary case final summary?) return row(summary);
    return Observer(
      builder: (context) =>
          row(settingsSectionSummary(page, loggedIn: authStore.isLoggedIn)),
    );
  }
}

/// The page [id] of the settings.
Widget buildSettingsPage(
  SettingsPageId id, {
  required SettingsStore settingsStore,
  required AuthStore authStore,
}) => switch (id) {
  SettingsPageId.general => GeneralSettings(settingsStore: settingsStore),
  SettingsPageId.video => VideoSettings(settingsStore: settingsStore),
  SettingsPageId.chat => ChatSettings(settingsStore: settingsStore),
  SettingsPageId.notifications => NotificationsSettings(
    settingsStore: settingsStore,
    authStore: authStore,
  ),
  SettingsPageId.other => OtherSettings(settingsStore: settingsStore),
  SettingsPageId.account => AccountSettings(authStore: authStore),
  SettingsPageId.blocked => BlockedUsers(authStore: authStore),
  SettingsPageId.chatFilters => const SizedBox.shrink(),
};

/// The account at the top of the phone's settings: who is logged in (opens
/// the account page), or the way to log in, or the connection problem.
class SettingsAccountCard extends StatelessWidget {
  const SettingsAccountCard({super.key, required this.authStore});

  final AuthStore authStore;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final colors = SettingsColors.of(context);
        final details = authStore.user.details;
        final Widget leading;
        final String title;
        final String detail;
        final VoidCallback onTap;
        VoidCallback? onLongPress;
        Widget? trailing;
        if (authStore.error != null) {
          leading = _Disc(
            glyph: SettingsGlyphKind.error,
            color: colors.danger,
            fill: colors.dangerTint,
          );
          title = 'Unable to connect to Twitch';
          detail = 'Check your connection, then try again';
          onTap = authStore.init;
          trailing = SettingsButton(
            label: 'Reconnect',
            onPressed: authStore.init,
          );
        } else if (authStore.isLoggedIn && details != null) {
          leading = SettingsAvatar(user: details, size: 48);
          title = details.displayName;
          detail = 'Blocked users, twitch.tv, log out';
          onTap = () => openSettingsPage(
            context,
            id: SettingsPageId.account,
            builder: (context) => AccountSettings(authStore: authStore),
          );
        } else {
          leading = _Disc(
            glyph: SettingsGlyphKind.anonymous,
            color: colors.secondary,
            fill: colors.tile,
          );
          title = 'Anonymous';
          detail =
              'Log in to enable the ability to chat, view followed streams, '
              'and more.';
          onTap = () => openLogin(context);
          onLongPress = () => loginFromClipboard(authStore);
        }
        return SettingsCard(
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            splashFactory: NoSplash.splashFactory,
            highlightColor: colors.pressed,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Row(
                spacing: 14,
                children: [
                  leading,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 3,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: OnsetTokens.bodyFamily,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colors.text,
                          ),
                        ),
                        Text(
                          detail,
                          style: TextStyle(
                            fontFamily: OnsetTokens.bodyFamily,
                            fontSize: 13,
                            color: colors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing ??
                      SettingsGlyph(
                        SettingsGlyphKind.chevronRight,
                        strokeWidth: 2,
                        color: colors.tertiary,
                      ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A 48 dp round tile with a glyph (no account, a connection problem).
class _Disc extends StatelessWidget {
  const _Disc({required this.glyph, required this.color, required this.fill});

  final SettingsGlyphKind glyph;
  final Color color;
  final Color fill;

  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 48,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
    child: SettingsGlyph(glyph, size: 22, strokeWidth: 1.8, color: color),
  );
}
