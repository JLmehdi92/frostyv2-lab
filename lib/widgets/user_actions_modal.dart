import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frosty/screens/channel_profile/channel_profile_screen.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/settings/widgets/go_live_setting.dart';
import 'package:frosty/screens/vod/channel_videos.dart';
import 'package:frosty/utils/share_link.dart';
import 'package:frosty/widgets/sheet/onset_sheet.dart';
import 'package:frosty/widgets/sheet/sheet_glyph.dart';
import 'package:frosty/widgets/twitch_web_page.dart';
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
    // The board's "More" sheet (ChaineCarteUtilisateur).
    return ListView(
      primary: false,
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 10),
      children: [
        if (showProfile)
          SheetRow(
            glyph: SheetGlyphKind.profile,
            label: 'Profile',
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
          label: 'Videos',
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
            label: '${isPinned == true ? 'Unpin' : 'Pin'} $name',
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
            label: 'Block $name',
            onTap: () => authStore
                .showBlockDialog(
                  context,
                  targetUser: name,
                  targetUserId: userId,
                )
                .then((_) {
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }),
          ),
        if (authStore.isLoggedIn) GoLiveBellTile(channelId: userId, name: name),
        if (authStore.isLoggedIn)
          SheetRow(
            glyph: SheetGlyphKind.heart,
            label: 'Follow $name on Twitch',
            detail: 'Opens the channel on twitch.tv',
            end: SheetRowEnd.external,
            onTap: () {
              Navigator.pop(context);
              TwitchWebPage.open(
                context,
                title: name,
                url: Uri.https('www.twitch.tv', '/$userLogin'),
              );
            },
          ),
        SheetRow(
          glyph: SheetGlyphKind.link,
          label: 'Copy link',
          onTap: () async {
            await Clipboard.setData(
              ClipboardData(text: 'https://www.twitch.tv/$userLogin'),
            );
            if (!context.mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Link copied')));
            Navigator.pop(context);
          },
        ),
        SheetRow(
          glyph: SheetGlyphKind.share,
          label: 'Share $name',
          onTap: () async {
            await shareLink(context, 'https://www.twitch.tv/$userLogin');
            if (context.mounted) Navigator.pop(context);
          },
        ),
        SheetRow(
          glyph: SheetGlyphKind.flag,
          label: 'Report $name',
          onTap: () => TwitchWebPage.open(
            context,
            title: 'Report $name',
            url: Uri.https('www.twitch.tv', '/$userLogin/report'),
          ),
        ),
      ],
    );
  }
}
