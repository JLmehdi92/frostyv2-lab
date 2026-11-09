import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/apis/twitch_social_service.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/l10n/enum_labels.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/user.dart';
import 'package:onset/screens/channel/channel.dart';
import 'package:onset/screens/onboarding/login_webview.dart';
import 'package:onset/screens/settings/account/blocked_users.dart';
import 'package:onset/screens/settings/account/edit_profile.dart';
import 'package:onset/screens/settings/account/gift_settings.dart';
import 'package:onset/screens/settings/account/whisper_privacy_settings.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/widgets/settings_glyph.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';
import 'package:onset/screens/settings/widgets/settings_page.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/onset_cached_network_image.dart';
import 'package:onset/widgets/twitch_web_page.dart';
import 'package:provider/provider.dart';

/// Account settings only twitch.tv can change: password, email, phone,
/// two-factor and verification; linked accounts. Named in
/// lib/l10n/enum_labels.dart.
const twitchHelpUrl = 'https://link.twitch.tv/help';

enum TwitchAccountPage {
  profile(SettingsGlyphKind.user, '/settings/profile'),
  security(SettingsGlyphKind.shield, '/settings/security'),
  notifications(SettingsGlyphKind.bell, '/settings/notifications'),
  connections(SettingsGlyphKind.link, '/settings/connections'),
  familyCenter(SettingsGlyphKind.lock, '/settings/family-center'),
  subscriptions(SettingsGlyphKind.sparkle, '/subscriptions'),
  drops(SettingsGlyphKind.dice, '/drops/inventory'),
  turbo(SettingsGlyphKind.play, '/turbo'),
  prime(SettingsGlyphKind.sparkle, '/prime'),
  recap(SettingsGlyphKind.calendar, '/annual-recap'),
  signup(SettingsGlyphKind.user, '/signup'),
  deleteAccount(SettingsGlyphKind.trash, '/user/delete-account');

  const TwitchAccountPage(this.glyph, this.path);

  static const profileTab = [security, connections];

  final SettingsGlyphKind glyph;

  /// Its path on www.twitch.tv.
  final String path;
}

/// Settings › Account: who is
/// logged in, their channel and blocked users, their twitch.tv pages, and
/// logging out.
class AccountSettings extends StatelessWidget {
  final AuthStore authStore;

  const AccountSettings({super.key, required this.authStore});

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final details = authStore.user.details;
        // Logged out from here: the page is on its way out.
        if (!authStore.isLoggedIn || details == null) {
          return const SizedBox.shrink();
        }
        final colors = SettingsColors.of(context);
        final l = context.l10n;
        return SettingsGroupsView(
          children: [
            SettingsGroup(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    spacing: 14,
                    children: [
                      SettingsAvatar(user: details, size: 56),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 3,
                          children: [
                            Text(
                              details.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: OnsetTokens.bodyFamily,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.27,
                                color: colors.text,
                              ),
                            ),
                            Text(
                              accountLine(l, details),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: OnsetTokens.bodyFamily,
                                fontSize: 13,
                                color: colors.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SettingsGroup(
              title: l.settingsYourAccount,
              children: [
                SettingsRow(
                  glyph: SettingsGlyphKind.user,
                  title: l.settingsMyChannel,
                  end: SettingsRowEnd.chevron,
                  onTap: () => openMyChannel(context, authStore),
                ),
                SettingsRow(
                  key: const ValueKey('settings-edit-profile'),
                  glyph: SettingsGlyphKind.notes,
                  title: l.editProfileTitle,
                  end: SettingsRowEnd.chevron,
                  onTap: () => openEditProfile(context, authStore),
                ),
                SettingsRow(
                  glyph: SettingsGlyphKind.ban,
                  title: l.settingsPageBlocked,
                  value: '${authStore.user.blockedUsers.length}',
                  end: SettingsRowEnd.chevron,
                  onTap: () => openBlockedUsers(context, authStore),
                ),
              ],
            ),
            if (context.read<TwitchViewerActionsService?>() case final service?)
              GiftSettingsGroup(
                load: () => service.giftSettings(
                  authToken: authStore.twitchWebToken ?? '',
                ),
                save: (settings) => service.updateGiftSettings(
                  settings: settings,
                  authToken: authStore.twitchWebToken ?? '',
                ),
              ),
            if (context.read<TwitchSocialService?>() case final social?)
              WhisperPrivacyGroup(
                load: () => social.whisperPrivacy(
                  authToken: authStore.twitchWebToken ?? '',
                ),
                save: (block) => social.setBlockStrangers(
                  block: block,
                  authToken: authStore.twitchWebToken ?? '',
                ),
              ),
            SettingsGroup(
              title: l.settingsOnTwitch,
              children: [
                for (final page in TwitchAccountPage.values)
                  SettingsRow(
                    glyph: page.glyph,
                    title: page.title(l),
                    end: SettingsRowEnd.external,
                    onTap: () => openTwitchAccountPage(context, page),
                  ),
              ],
            ),
            SettingsGroup(
              children: [
                SettingsRow(
                  glyph: SettingsGlyphKind.logout,
                  title: l.settingsLogOut,
                  danger: true,
                  onTap: () async {
                    final out = await confirmLogout(context, authStore);
                    // On a phone this page goes with the account.
                    if (out &&
                        context.mounted &&
                        SettingsPaneScope.maybeOf(context) == null) {
                      Navigator.maybePop(context);
                    }
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Whether the account pages have something to show: logged in, the
/// account read, and Twitch reachable (else Profile shows the login or the
/// connection problem).
bool hasAccount(AuthStore authStore) =>
    authStore.error == null &&
    authStore.isLoggedIn &&
    authStore.user.details != null;

/// "@login · Joined March 2019", in [l]'s language.
String accountLine(AppLocalizations l, UserTwitch user) {
  final joined = joinedText(l, user);
  return joined == null ? '@${user.login}' : '@${user.login} · $joined';
}

/// "Joined March 2019" in [l]'s language, when Twitch said when.
String? joinedText(AppLocalizations l, UserTwitch user) {
  final created = user.createdAt;
  if (created == null) return null;
  return l.settingsJoined(date: created.toLocal());
}

/// The viewer's picture from their account (no request of its own), or
/// their initial while it loads or when they have none.
class SettingsAvatar extends StatelessWidget {
  const SettingsAvatar({super.key, required this.user, required this.size});

  final UserTwitch user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    final placeholder = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: colors.tile,
      child: Text(
        user.displayName.isEmpty
            ? '?'
            : user.displayName.characters.first.toUpperCase(),
        style: TextStyle(
          fontFamily: OnsetTokens.bodyFamily,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w800,
          color: colors.secondary,
        ),
      ),
    );
    return ExcludeSemantics(
      child: ClipOval(
        child: SizedBox.square(
          dimension: size,
          child: user.profileImageUrl.isEmpty
              ? placeholder
              : OnsetCachedNetworkImage(
                  imageUrl: user.profileImageUrl,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => placeholder,
                  errorWidget: (_, _, _) => placeholder,
                ),
        ),
      ),
    );
  }
}

/// "My channel": the viewer's own channel.
void openMyChannel(BuildContext context, AuthStore authStore) {
  final details = authStore.user.details;
  if (details == null) return;
  Navigator.of(context).push(
    MaterialPageRoute(
      settings: const RouteSettings(name: 'My channel'),
      builder: (context) => VideoChat(
        userId: details.id,
        userName: details.displayName,
        userLogin: details.login,
      ),
    ),
  );
}

/// The blocked users: a page on a phone, the side column's entry on a
/// tablet.
void openBlockedUsers(BuildContext context, AuthStore authStore) =>
    openSettingsPage(
      context,
      id: SettingsPageId.blocked,
      builder: (context) => BlockedUsers(authStore: authStore),
    );

/// One of Twitch's own account pages, signed in (the app has no API for
/// these).
void openTwitchAccountPage(BuildContext context, TwitchAccountPage page) =>
    TwitchWebPage.open(
      context,
      title: page.title(context.l10n),
      url: Uri.https('www.twitch.tv', page.path),
    );

/// Asks before logging out; true when the viewer logged out.
Future<bool> confirmLogout(BuildContext context, AuthStore authStore) async {
  final confirmed = await confirmSettingsAction(
    context,
    title: context.l10n.settingsLogOutTitle,
    message: context.l10n.settingsLogOutMessage,
    confirm: context.l10n.settingsLogOut,
  );
  if (!confirmed) return false;
  authStore.logout();
  return true;
}

/// "Connect with Twitch": Twitch's login page.
void openLogin(BuildContext context) => Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => LoginWebView()),
);

/// A long press on the login card: logs in with a token copied before (the
/// viewer's own, whatever app it was made for).
Future<void> loginFromClipboard(AuthStore authStore) async {
  final clipboardText = (await Clipboard.getData(Clipboard.kTextPlain))?.text;

  if (clipboardText == null) return;

  authStore.login(token: clipboardText, acceptAnyApp: true);
}

/// Profile while logged out: "Anonymous", why to log
/// in and "Connect with Twitch" (a long press logs in with a copied token);
/// or, when Twitch cannot be reached, the problem and "Reconnect".
class ProfileLoginCard extends StatelessWidget {
  const ProfileLoginCard({super.key, required this.authStore});

  final AuthStore authStore;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final colors = SettingsColors.of(context);
        final l = context.l10n;
        final error = authStore.error != null;
        final disc = Container(
          width: 60,
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: error ? colors.dangerTint : colors.tile,
            shape: BoxShape.circle,
            border: error
                ? null
                : Border.all(
                    color: colors.buttonRing,
                    width: OnsetTokens.hairlineWidth,
                  ),
          ),
          child: SettingsGlyph(
            error ? SettingsGlyphKind.error : SettingsGlyphKind.anonymous,
            size: 26,
            strokeWidth: error ? 1.9 : 1.8,
            color: error ? colors.danger : colors.secondary,
          ),
        );
        final heading = Row(
          spacing: 14,
          children: [
            disc,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 3,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      error
                          ? l.settingsUnableToReachTwitch
                          : l.settingsAnonymous,
                      style: TextStyle(
                        fontFamily: OnsetTokens.bodyFamily,
                        fontSize: error ? 20 : 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: error ? -0.4 : -0.72,
                        height: 1.15,
                        color: colors.text,
                      ),
                    ),
                  ),
                  Text(
                    error
                        ? l.settingsCheckConnection
                        : l.settingsWatchingWithoutAccount,
                    style: TextStyle(
                      fontFamily: OnsetTokens.bodyFamily,
                      fontSize: 13,
                      color: colors.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
        final List<Widget> body;
        if (error) {
          body = [
            heading,
            SettingsButton(
              label: l.settingsReconnect,
              large: true,
              expand: true,
              icon: SettingsGlyph(
                SettingsGlyphKind.reconnect,
                strokeWidth: 2,
                color: colors.text,
              ),
              onPressed: authStore.init,
            ),
          ];
        } else {
          body = [
            heading,
            Text(
              l.settingsLoginPitch,
              style: SettingsText.body.copyWith(color: colors.body),
            ),
            SettingsButton(
              label: l.commonConnectWithTwitch,
              tone: SettingsButtonTone.primary,
              large: true,
              expand: true,
              icon: SettingsGlyph(
                SettingsGlyphKind.user,
                strokeWidth: 2.1,
                color: SettingsColors.onAccentOf(context),
              ),
              onPressed: () => openLogin(context),
            ),
            Text(
              l.settingsLoginDisclaimer,
              style: TextStyle(
                fontFamily: OnsetTokens.bodyFamily,
                fontSize: 12,
                height: 1.5,
                color: colors.tertiary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colors.well,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colors.cardRing,
                  width: OnsetTokens.hairlineWidth,
                ),
              ),
              child: Text(
                l.settingsTokenLoginTip,
                style: TextStyle(
                  fontFamily: OnsetTokens.bodyFamily,
                  fontSize: 12,
                  height: 1.5,
                  color: colors.secondary,
                ),
              ),
            ),
          ];
        }
        return Semantics(
          onLongPressHint: error ? null : l.settingsTokenLoginHint,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onLongPress: error ? null : () => loginFromClipboard(authStore),
            child: SettingsCard(
              radius: OnsetTokens.radiusLarge,
              padding: const EdgeInsets.all(20),
              ring: error ? colors.dangerFill.withValues(alpha: 0.35) : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: body,
              ),
            ),
          ),
        );
      },
    );
  }
}
