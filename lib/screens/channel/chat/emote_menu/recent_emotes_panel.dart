import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/screens/channel/chat/emote_menu/emote_menu_section.dart';
import 'package:onset/screens/channel/chat/stores/chat_store.dart';
import 'package:onset/widgets/sheet/onset_panel.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';

class RecentEmotesPanel extends StatelessWidget {
  final ChatStore chatStore;

  const RecentEmotesPanel({super.key, required this.chatStore});

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        if (chatStore.assetsStore.recentEmotes.isEmpty) {
          // The empty state.
          final color = SheetColors.of(context).tertiary;
          // Scrolls (never by hand) rather than overflow while the menu
          // folds away under it.
          return Center(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
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
                    context.l10n.emoteMenuNoRecent,
                    style: SheetText.status.copyWith(
                      fontSize: 13,
                      color: color,
                    ),
                  ),
                ],
              ),
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
