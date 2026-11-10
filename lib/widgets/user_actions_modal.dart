import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/report.dart';
import 'package:onset/screens/channel_profile/channel_preferences_screen.dart';
import 'package:onset/screens/channel_profile/channel_profile_screen.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/go_live_setting.dart';
import 'package:onset/screens/vod/channel_videos.dart';
import 'package:onset/utils/share_link.dart';
import 'package:onset/utils/twitch_report.dart';
import 'package:onset/widgets/follow/follow_flow.dart';
import 'package:onset/widgets/report/report_sheet.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';
import 'package:onset/widgets/twitch_web_page.dart';
import 'package:provider/provider.dart';

class UserActionsModal extends StatelessWidget {
  final AuthStore authStore;
  final String name;
  final String userLogin;
  final String userId;
  final bool showPinOption;
  final bool? isPinned;

  /// Offers the channel's profile (not from the profile itself).
  final bool showProfile;

  const UserActionsModal({
    super.key,
    required this.authStore,
    required this.name,
    required this.userLogin,
    required this.userId,
    this.showPinOption = false,
    this.isPinned,
    this.showProfile = true,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // The "More" sheet of the user card.
    return ListView(
      primary: false,
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 10),
      children: [
        if (showProfile)
          SheetRow(
            glyph: SheetGlyphKind.profile,
            label: l.userActionsProfile,
            onTap: () {
              Navigator.pop(context);
              ChannelProfileScreen.open(
                context,
                login: userLogin,
                userId: userId,
                displayName: name,
              );
            },
          ),
        SheetRow(
          glyph: SheetGlyphKind.videos,
          label: l.userActionsVideos,
          onTap: () {
            Navigator.pop(context);
            ChannelVideosScreen.open(
              context,
              userLogin: userLogin,
              displayName: name,
            );
          },
        ),
        if (showPinOption)
          SheetRow(
            glyph: SheetGlyphKind.pin,
            label: isPinned == true
                ? l.userActionsUnpin(name: name)
                : l.userActionsPin(name: name),
            onTap: () {
              if (isPinned == true) {
                context.read<SettingsStore>().pinnedChannelIds = [
                  ...context.read<SettingsStore>().pinnedChannelIds
                    ..remove(userId),
                ];
              } else {
                context.read<SettingsStore>().pinnedChannelIds = [
                  ...context.read<SettingsStore>().pinnedChannelIds,
                  userId,
                ];
              }

              Navigator.pop(context);
            },
          ),
        if (authStore.isLoggedIn)
          SheetRow(
            glyph: SheetGlyphKind.block,
            label: l.userActionsBlock(name: name),
            onTap: () => authStore
                .showBlockDialog(
                  context,
                  targetUser: name,
                  targetUserId: userId,
                  source: BlockSource.chat,
                )
                .then((_) {
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }),
          ),
        if (authStore.isLoggedIn) GoLiveBellTile(channelId: userId, name: name),
        SheetRow(
          glyph: SheetGlyphKind.settings,
          label: l.userActionsChannelPrefs,
          onTap: () {
            Navigator.pop(context);
            ChannelPreferencesScreen.open(
              context,
              channelId: userId,
              name: name,
              settingsStore: context.read<SettingsStore>(),
              loggedIn: authStore.isLoggedIn,
            );
          },
        ),
        if (authStore.isLoggedIn)
          UserActionsFollowRow(
            name: name,
            userLogin: userLogin,
            userId: userId,
          ),
        SheetRow(
          glyph: SheetGlyphKind.link,
          label: l.userActionsCopyLink,
          onTap: () async {
            await Clipboard.setData(
              ClipboardData(text: 'https://www.twitch.tv/$userLogin'),
            );
            if (!context.mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l.userActionsLinkCopied)));
            Navigator.pop(context);
          },
        ),
        SheetRow(
          glyph: SheetGlyphKind.share,
          label: l.userActionsShare(name: name),
          onTap: () async {
            await shareLink(context, 'https://www.twitch.tv/$userLogin');
            if (context.mounted) Navigator.pop(context);
          },
        ),
        SheetRow(
          glyph: SheetGlyphKind.flag,
          label: l.userActionsReport(name: name),
          onTap: () => reportFromOnset(
            context,
            target: ReportTarget.user(userId: userId, name: name),
            title: l.userActionsReport(name: name),
            fallbackUrl: twitchReportUri(userLogin),
          ),
        ),
      ],
    );
  }
}

class UserActionsFollowRow extends StatefulWidget {
  const UserActionsFollowRow({
    super.key,
    required this.name,
    required this.userLogin,
    required this.userId,
  });

  final String name;
  final String userLogin;
  final String userId;

  @override
  State<UserActionsFollowRow> createState() => _UserActionsFollowRowState();
}

class _UserActionsFollowRowState extends State<UserActionsFollowRow> {
  bool? _following;

  @override
  void initState() {
    super.initState();
    unawaited(_loadState());
  }

  Future<void> _loadState() async {
    final actions = FollowFlow.actionsOf(context);
    if (actions == null || widget.userId.isEmpty) return;
    final following = await actions.followsChannel(widget.userId);
    if (mounted) setState(() => _following = following);
  }

  Future<void> _openOnTwitch() => TwitchWebPage.open(
    context,
    title: widget.name,
    url: Uri.https('www.twitch.tv', '/${widget.userLogin}'),
  );

  Future<void> _toggle(bool following) async {
    final navigator = Navigator.of(context);
    final now = await FollowFlow.toggle(
      context,
      target: FollowTarget.channel,
      id: widget.userId,
      name: widget.name,
      following: following,
      openOnTwitch: _openOnTwitch,
    );
    if (now != null && mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final following = _following;
    if (following == null) {
      return SheetRow(
        glyph: SheetGlyphKind.heart,
        label: l.userActionsFollowOnTwitch(name: widget.name),
        detail: l.userActionsFollowDetail,
        end: SheetRowEnd.external,
        onTap: () {
          Navigator.pop(context);
          unawaited(_openOnTwitch());
        },
      );
    }
    return FollowPendingGate(
      id: widget.userId,
      child: SheetRow(
        glyph: SheetGlyphKind.heart,
        label: following
            ? l.userActionsUnfollow(name: widget.name)
            : l.userActionsFollow(name: widget.name),
        onTap: () => _toggle(following),
      ),
    );
  }
}
