import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/models/irc.dart';
import 'package:frosty/screens/channel/chat/emote_menu/emote_menu_section.dart';
import 'package:frosty/screens/channel/chat/stores/chat_store.dart';
import 'package:frosty/widgets/sheet/onset_panel.dart';
import 'package:frosty/widgets/sheet/onset_sheet.dart';
import 'package:frosty/widgets/sheet/sheet_glyph.dart';

class RecentEmotesPanel extends StatelessWidget {
  final ChatStore chatStore;

  const RecentEmotesPanel({super.key, required this.chatStore});

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        if (chatStore.assetsStore.recentEmotes.isEmpty) {
          // The board's empty state.
          final color = SheetColors.of(context).tertiary;
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                SheetGlyph(
                  SheetGlyphKind.emote,
                  size: 26,
                  strokeWidth: 1.6,
                  color: color,
                ),
                Text(
                  'No recent emotes',
                  style: SheetText.status.copyWith(fontSize: 13, color: color),
                ),
              ],
            ),
          );
        }

        final panel = SheetPresentation.isPanel(context);
        return MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: GridView.builder(
            gridDelegate: emoteGridDelegate(context, panel: panel),
            padding: EdgeInsets.fromLTRB(panel ? 6 : 4, 4, panel ? 6 : 4, 10),
            itemBuilder: (context, index) {
              final emote = chatStore.assetsStore.recentEmotes[index];
              final validEmotes = [
                ...chatStore.assetsStore.emoteToObject.values,
                ...chatStore.assetsStore.userEmoteToObject.values,
              ];
              final matchingEmotes = validEmotes.where(
                (existingEmote) =>
                    existingEmote.name == emote.name &&
                    existingEmote.type == emote.type,
              );

              return EmoteCell(
                emote: emote,
                url: matchingEmotes.isNotEmpty
                    ? matchingEmotes.first.url
                    : emote.url,
                locked: matchingEmotes.isEmpty,
                onTap: matchingEmotes.isNotEmpty
                    ? () => chatStore.addEmote(emote)
                    : null,
                onLongPress: () {
                  HapticFeedback.lightImpact();

                  IRCMessage.showEmoteDetailsBottomSheet(
                    context,
                    emote: emote,
                    launchExternal: chatStore.settings.launchUrlExternal,
                  );
                },
              );
            },
            itemCount: chatStore.assetsStore.recentEmotes.length,
          ),
        );
      },
    );
  }
}
