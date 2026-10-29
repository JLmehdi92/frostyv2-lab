import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/screens/channel/chat/stores/chat_store.dart';
import 'package:frosty/screens/channel/chat/widgets/chat_message.dart';
import 'package:frosty/screens/channel/chat/widgets/chat_moderation_bar.dart';
import 'package:frosty/screens/channel/chat/widgets/user_card_info.dart';
import 'package:frosty/screens/channel_profile/channel_profile_screen.dart';
import 'package:frosty/screens/whispers/whisper_conversation.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/utils.dart';
import 'package:frosty/widgets/alert_message.dart';
import 'package:frosty/widgets/frosty_scrollbar.dart';
import 'package:frosty/widgets/profile_picture.dart';
import 'package:frosty/widgets/sheet/onset_panel.dart';
import 'package:frosty/widgets/sheet/onset_sheet.dart';
import 'package:frosty/widgets/sheet/sheet_glyph.dart';
import 'package:frosty/widgets/user_actions_modal.dart';

/// Opens someone's user card (board ChaineCarteUtilisateur): a sheet on a
/// phone (under the video), a panel beside the chat on a tablet when
/// [anchor] (what was tapped) leaves room for it (ChaineOutilsTablette).
Future<void> showChatUserCard(
  BuildContext context, {
  required ChatStore chatStore,
  required String username,
  required String userId,
  required String displayName,
  Rect? anchor,
}) => showSheetOrPanel<void>(
  context: context,
  size: ChatUserModal.panelSize,
  sides: const [PanelSide.left, PanelSide.right, PanelSide.above],
  anchor: anchor,
  region: PanelRegion.of(context),
  builder: (context) => ChatUserModal(
    chatStore: chatStore,
    username: username,
    userId: userId,
    displayName: displayName,
  ),
);

class ChatUserModal extends StatefulWidget {
  final ChatStore chatStore;
  final String username;
  final String displayName;
  final String userId;

  const ChatUserModal({
    super.key,
    required this.chatStore,
    required this.username,
    required this.displayName,
    required this.userId,
  });

  /// The tablet panel (board ChaineOutilsTablette).
  static const panelSize = Size(384, 344);

  /// The phone sheet (board ChaineCarteUtilisateur).
  static const sheetHeight = 470.0;

  @override
  State<ChatUserModal> createState() => _ChatUserModalState();
}

class _ChatUserModalState extends State<ChatUserModal> {
  Widget _action({
    required String tooltip,
    required SheetGlyphKind glyph,
    required VoidCallback onPressed,
  }) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      fixedSize: const Size(44, 44),
      minimumSize: const Size(44, 44),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    icon: SheetGlyph(glyph, color: SheetColors.of(context).text),
  );

  @override
  Widget build(BuildContext context) {
    final name = getReadableName(widget.displayName, widget.username);
    final colors = SheetColors.of(context);
    final dense = SheetPresentation.isPanel(context);

    final header = Padding(
      padding: EdgeInsets.fromLTRB(16, dense ? 12 : 6, dense ? 6 : 4, 0),
      child: Row(
        spacing: 12,
        children: [
          ProfilePicture(userLogin: widget.username, radius: dense ? 22 : 24),
          Expanded(
            child: Tooltip(
              message: name,
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SheetText.subtitle.copyWith(color: colors.text),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.chatStore.auth.isLoggedIn)
                _action(
                  tooltip: 'Reply',
                  glyph: SheetGlyphKind.reply,
                  onPressed: () {
                    widget.chatStore.textController.text =
                        '@${widget.username} ';
                    Navigator.pop(context);
                    widget.chatStore.safeRequestFocus();
                  },
                ),
              if (widget.chatStore.auth.isLoggedIn &&
                  widget.chatStore.whispers != null)
                _action(
                  tooltip: 'Whisper',
                  glyph: SheetGlyphKind.whisper,
                  onPressed: () {
                    final navigator = Navigator.of(context);
                    navigator
                      ..pop()
                      ..push(
                        WhisperConversation.route(
                          store: widget.chatStore.whispers!,
                          userId: widget.userId,
                          login: widget.username,
                          displayName: name,
                        ),
                      );
                  },
                ),
              _action(
                tooltip: 'Profile',
                glyph: SheetGlyphKind.profile,
                onPressed: () {
                  Navigator.pop(context);
                  ChannelProfileScreen.open(
                    context,
                    login: widget.username,
                    userId: widget.userId,
                    displayName: name,
                    // The streamer of this chat: Watch goes back to it.
                    fromChannel:
                        widget.username.toLowerCase() ==
                        widget.chatStore.channelName.toLowerCase(),
                  );
                },
              ),
              _action(
                tooltip: 'More',
                glyph: SheetGlyphKind.more,
                onPressed: () => showOnsetSheet<void>(
                  context: context,
                  panel: true,
                  builder: (context) => UserActionsModal(
                    authStore: widget.chatStore.auth,
                    name: name,
                    userLogin: widget.username,
                    userId: widget.userId,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final info = Builder(
      builder: (context) {
        final store = widget.chatStore;
        final isBroadcaster =
            widget.username.toLowerCase() == store.channelName.toLowerCase();
        return UserCardInfo(
          api: store.twitchApi,
          userId: widget.userId,
          channelId: store.channelId,
          showFollowAge: store.canModerate && !isBroadcaster,
          dense: dense,
          badges: userCardBadges(
            store.messages.lastWhereOrNull(
              (message) => message.user == widget.username,
            ),
            store.assetsStore.twitchBadgesToObject,
          ),
        );
      },
    );

    final moderation = Observer(
      builder: (context) {
        final store = widget.chatStore;
        final login = widget.username.toLowerCase();
        // Twitch refuses actions on the broadcaster and on oneself.
        if (!store.canModerate ||
            login == store.channelName.toLowerCase() ||
            login == store.auth.user.details?.login.toLowerCase()) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ChatModerationBar(
            login: widget.username,
            name: name,
            dense: dense,
            onModerate: (command) =>
                store.moderate(command, userId: widget.userId),
          ),
        );
      },
    );

    final divider = Container(
      height: FrostyTokens.hairlineWidth,
      margin: EdgeInsets.fromLTRB(16, dense ? 2 : 4, 16, 0),
      color: colors.hairline,
    );

    Widget messages({required bool shrinkWrap}) => Observer(
      builder: (context) {
        final userMessages = widget.chatStore.messages.reversed
            .where((message) => message.user == widget.username)
            .toList();

        if (userMessages.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: AlertMessage(message: 'No recent messages'),
          );
        }

        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(
              widget.chatStore.settings.messageScale,
            ),
          ),
          child: DefaultTextStyle(
            style: DefaultTextStyle.of(
              context,
            ).style.copyWith(fontSize: widget.chatStore.settings.fontSize),
            child: FrostyScrollbar(
              child: ListView.builder(
                reverse: true,
                primary: false,
                shrinkWrap: shrinkWrap,
                padding: EdgeInsets.fromLTRB(4, dense ? 10 : 8, 4, 14),
                itemCount: userMessages.length,
                itemBuilder: (context, index) => ChatMessage(
                  ircMessage: userMessages[index],
                  chatStore: widget.chatStore,
                  isModal: true,
                ),
              ),
            ),
          ),
        );
      },
    );

    final top = [
      header,
      info,
      moderation,
      divider,
      if (!dense)
        const SheetSectionLabel(
          'Recent messages',
          padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
        ),
    ];

    return SizedBox(
      height: dense ? null : ChatUserModal.sheetHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // A short screen (a phone turned) scrolls the whole card.
          if (constraints.maxHeight < (dense ? 280 : 380)) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...top,
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: messages(shrinkWrap: true),
                  ),
                ],
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...top,
              Expanded(child: messages(shrinkWrap: false)),
            ],
          );
        },
      ),
    );
  }
}
