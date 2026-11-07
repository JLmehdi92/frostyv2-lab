import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/models/community_highlights.dart';
import 'package:onset/screens/channel/chat/stores/chat_assets_store.dart';
import 'package:onset/screens/channel/community_highlights/pinned_to_irc.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';

/// A pinned message as the channel's chat shows it: badges, name colour,
/// Twitch emotes and 7TV/BTTV/FFZ words, at the chat's emote and badge
/// scale. It rebuilds when the chat's emotes finish loading.
class PinnedChatText extends StatelessWidget {
  const PinnedChatText({
    super.key,
    required this.pin,
    required this.assetsStore,
    required this.settings,
    required this.channelId,
    required this.channelLogin,
    this.viewerLogin,
  });

  final PinnedChatMessage pin;
  final ChatAssetsStore assetsStore;
  final SettingsStore settings;
  final String channelId;
  final String channelLogin;
  final String? viewerLogin;

  @override
  Widget build(BuildContext context) {
    final message = pinnedToIrcMessage(
      pin,
      channelId: channelId,
      channelLogin: channelLogin,
      viewerLogin: viewerLogin,
    );
    return Observer(
      builder: (context) {
        final style = DefaultTextStyle.of(context).style;
        return Text.rich(
          TextSpan(
            style: style,
            children: message.generateSpan(
              context,
              style: style,
              assetsStore: assetsStore,
              emoteScale: settings.emoteScale,
              badgeScale: settings.badgeScale,
              animateEmotes: settings.animateEmotes,
              showGifs: settings.showGifs,
              animateGifs: settings.animateGifs,
              nameContrast: settings.nameColorContrast,
              launchExternal: settings.launchUrlExternal,
            ),
          ),
        );
      },
    );
  }
}
