import 'package:flutter/material.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/emotes.dart';
import 'package:onset/screens/channel/chat/emote_menu/emote_menu.dart';
import 'package:onset/screens/channel/chat/emote_menu/emote_menu_section.dart';
import 'package:onset/screens/channel/chat/stores/chat_assets_store.dart';
import 'package:onset/screens/channel/chat/stores/chat_store.dart';
import 'package:onset/widgets/sheet/onset_panel.dart';

class EmoteMenuPanel extends StatelessWidget {
  final ChatStore chatStore;
  final List<Emote>? emotes;
  final Map<String, List<Emote>>? twitchEmotes;

  const EmoteMenuPanel({
    super.key,
    required this.chatStore,
    this.emotes,
    this.twitchEmotes,
  });

  @override
  Widget build(BuildContext context) {
    if (emotes != null) {
      final globalEmotes = emotes!
          .where(
            (emote) =>
                emote.type == EmoteType.bttvGlobal ||
                emote.type == EmoteType.ffzGlobal ||
                emote.type == EmoteType.sevenTVGlobal,
          )
          .toList();

      final channelEmotes = emotes!
          .where(
            (emote) =>
                emote.type == EmoteType.bttvChannel ||
                emote.type == EmoteType.bttvShared ||
                emote.type == EmoteType.ffzChannel ||
                emote.type == EmoteType.sevenTVChannel,
          )
          .toList();

      return EmoteTabsView(
        style: EmoteTabsStyle.pills,
        panel: SheetPresentation.isPanel(context),
        headers: [
          if (channelEmotes.isNotEmpty) context.l10n.emoteMenuChannel,
          context.l10n.emoteMenuGlobal,
        ],
        children: [
          if (channelEmotes.isNotEmpty)
            EmoteMenuSection(chatStore: chatStore, emotes: channelEmotes),
          EmoteMenuSection(chatStore: chatStore, emotes: globalEmotes),
        ],
      );
    } else {
      final isSubbed = chatStore.userState.subscriber;

      twitchEmotes?.removeWhere(
        (key, value) => key.toLowerCase() == chatStore.channelName,
      );

      return EmoteTabsView(
        style: EmoteTabsStyle.pills,
        panel: SheetPresentation.isPanel(context),
        headers: twitchEmotes!.keys
            .map((header) => _sectionTab(header, context.l10n))
            .toList(),
        children: twitchEmotes!.entries
            .map(
              (e) => EmoteMenuSection(
                chatStore: chatStore,
                emotes: e.value,
                // Subscriber emotes of this channel; the follower and Bits
                // ones the viewer has stay usable.
                disabled: e.key == UserEmoteSection.channel && !isSubbed,
                usable: chatStore.assetsStore.userEmoteToObject.keys.toSet(),
              ),
            )
            .toList(),
      );
    }
  }
}

/// The tab of a section of the viewer's Twitch emotes: the app's sections
/// named in [l]'s language, a channel's by the first word of its name.
String _sectionTab(String section, AppLocalizations l) => switch (section) {
  UserEmoteSection.channel => l.emoteMenuChannel,
  UserEmoteSection.global => l.emoteMenuGlobal,
  UserEmoteSection.unlocked => l.emoteMenuUnlocked,
  UserEmoteSection.other => l.emoteMenuOther,
  _ => section.split(' ')[0],
};
