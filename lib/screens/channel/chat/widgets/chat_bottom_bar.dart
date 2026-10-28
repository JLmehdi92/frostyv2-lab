import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/constants.dart';
import 'package:frosty/models/irc.dart';
import 'package:frosty/screens/channel/chat/details/chat_details.dart';
import 'package:frosty/screens/channel/chat/stores/chat_store.dart';
import 'package:frosty/screens/channel/chat/widgets/chat_character_counter.dart';
import 'package:frosty/screens/channel/chat/widgets/chat_restriction_bar.dart';
import 'package:frosty/screens/channel/video/player_glyph.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/utils/modal_bottom_sheet.dart';
import 'package:frosty/widgets/blurred_container.dart';
import 'package:frosty/widgets/channel_points_button.dart';
import 'package:frosty/widgets/chat_input/emote_text_span_builder.dart';
import 'package:frosty/widgets/frosty_cached_network_image.dart';

class ChatBottomBar extends StatelessWidget {
  final ChatStore chatStore;

  /// Callback to add a new chat tab.
  /// Passes this to ChatDetails to show "Add chat" option.
  final VoidCallback onAddChat;

  /// When set, indicates merged mode — shown in hint text (e.g., "Chat in xQc").
  final String? channelDisplayName;

  const ChatBottomBar({
    super.key,
    required this.chatStore,
    required this.onAddChat,
    this.channelDisplayName,
  });

  /// Whether the landscape side chat shows a pencil instead of the text
  /// field, and whether it shows the send button.
  ///
  /// ONSET's rule, on every screen size: a side chat under 30% of the width
  /// is too narrow for a text field, so a pencil widens it first.
  @visibleForTesting
  static ({bool pencil, bool send}) inputControls({
    required double chatWidth,
    required bool landscape,
    required bool showVideo,
    required bool expandChat,
  }) => (
    pencil: !expandChat && chatWidth < 0.3 && showVideo && landscape,
    send: chatWidth >= 0.3 || expandChat || !landscape,
  );

  @override
  Widget build(BuildContext context) {
    final isEmotesEnabled =
        chatStore.settings.showTwitchEmotes ||
        chatStore.settings.show7TVEmotes ||
        chatStore.settings.showBTTVEmotes ||
        chatStore.settings.showFFZEmotes;

    final emoteMenuButton = isEmotesEnabled
        ? Tooltip(
            message: 'Emote menu',
            preferBelow: false,
            child: Semantics(
              selected: chatStore.assetsStore.showEmoteMenu,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: chatStore.assetsStore.showEmoteMenu
                      ? context.frostyColors.live.withValues(alpha: 0.14)
                      : null,
                ),
                icon: PlayerGlyph(
                  PlayerGlyphKind.emote,
                  color: chatStore.assetsStore.showEmoteMenu
                      ? context.frostyColors.live
                      : context.colorScheme.onSurfaceVariant,
                ),
                onPressed: () {
                  chatStore.unfocusInput();
                  chatStore.assetsStore.showEmoteMenu =
                      !chatStore.assetsStore.showEmoteMenu;
                },
              ),
            ),
          )
        : null;

    return Observer(
      builder: (context) {
        // A tablet in portrait has the larger input (board
        // TablettePortrait).
        final large = context.isLargeScreen && context.isPortrait;
        final matchingEmotes = chatStore.matchingEmotes;
        final matchingChatters = chatStore.matchingChatters;

        final isFullscreenOverlay =
            chatStore.settings.fullScreen && context.isLandscape;

        final inputControls = ChatBottomBar.inputControls(
          chatWidth: chatStore.settings.chatWidth,
          landscape: context.isLandscape,
          showVideo: chatStore.settings.showVideo,
          expandChat: chatStore.expandChat,
        );

        final effectiveChatDelay = chatStore.settings.effectiveChatDelay;

        // Check if chat delay is active (for indicator only, doesn't block input)
        final hasChatDelay =
            chatStore.settings.showVideo && effectiveChatDelay > 0;

        const loginTooltipMessage = 'Log in to chat';

        final bottomBarContent = Column(
          children: [
            if (chatStore.auth.isLoggedIn)
              Observer(
                builder: (_) =>
                    ChatRestrictionBar(restriction: chatStore.restriction),
              ),
            if (chatStore.replyingToMessage != null) ...[
              const Divider(),
              TextFieldTapRegion(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: context.frostyColors.live,
                        width: 4,
                      ),
                    ),
                  ),
                  // Left: 8px so text aligns at 12px (4px border + 8px padding)
                  // Right: 4px to give close button some breathing room
                  padding: const EdgeInsets.only(left: 8, right: 4),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Expanded(
                        child: Tooltip(
                          message: chatStore.replyingToMessage!.message ?? '',
                          preferBelow: false,
                          child: Text.rich(
                            TextSpan(
                              children: chatStore.replyingToMessage!
                                  .generateSpan(
                                    context,
                                    assetsStore: chatStore.assetsStore,
                                    emoteScale: chatStore.settings.emoteScale,
                                    badgeScale: chatStore.settings.badgeScale,
                                    animateEmotes: chatStore.settings.animateEmotes,
                                    // One line: a GIF shows as its title.
                                    showGifs: false,
                                    launchExternal:
                                        chatStore.settings.launchUrlExternal,
                                    timestamp: chatStore.settings.timestampType,
                                    currentChannelId: chatStore.channelId,
                                  ),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.defaultTextStyle.copyWith(
                              fontSize: chatStore.settings.fontSize,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cancel reply',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => chatStore.replyingToMessage = null,
                        icon: const Icon(Icons.close, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            // Wrap autocomplete sections with TextFieldTapRegion so taps
            // on them don't trigger TextField's onTapOutside callback.
            if (chatStore.settings.autocomplete &&
                chatStore.showEmoteAutocomplete &&
                matchingEmotes.isNotEmpty) ...[
              const Divider(),
              TextFieldTapRegion(
                child: SizedBox(
                  height: 50,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(4),
                    itemCount: matchingEmotes.length,
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) => InkWell(
                      onTap: () => chatStore.addEmote(
                        matchingEmotes[index],
                        autocompleteMode: true,
                      ),
                      onLongPress: () {
                        HapticFeedback.lightImpact();

                        IRCMessage.showEmoteDetailsBottomSheet(
                          context,
                          emote: matchingEmotes[index],
                          launchExternal: chatStore.settings.launchUrlExternal,
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Center(
                          child: FrostyCachedNetworkImage(
                            imageUrl: matchingEmotes[index].url,
                            useFade: false,
                            height:
                                matchingEmotes[index].height?.toDouble() ??
                                defaultEmoteSize,
                            width: matchingEmotes[index].width?.toDouble(),
                            semanticLabel: matchingEmotes[index].name,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (chatStore.settings.autocomplete &&
                chatStore.matchingCommands.isNotEmpty) ...[
              const Divider(),
              TextFieldTapRegion(
                child: SizedBox(
                  height: 50,
                  child: ListView(
                    padding: const EdgeInsets.all(4),
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final command in chatStore.matchingCommands)
                        Tooltip(
                          message: '${command.usage} · ${command.description}',
                          child: TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                            onPressed: () {
                              final text = '/${command.name} ';
                              chatStore.textController.value = TextEditingValue(
                                text: text,
                                selection: TextSelection.collapsed(
                                  offset: text.length,
                                ),
                              );
                            },
                            child: Text('/${command.name}'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            if (chatStore.settings.autocomplete &&
                chatStore.showMentionAutocomplete &&
                matchingChatters.isNotEmpty) ...[
              const Divider(),
              TextFieldTapRegion(
                child: SizedBox(
                  height: 50,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(4),
                    itemCount: matchingChatters.length,
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) => TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () {
                        final split = chatStore.textController.text.split(' ')
                          ..removeLast()
                          ..add('@${matchingChatters[index]} ');

                        chatStore.textController.text = split.join(' ');
                        chatStore.textController.selection =
                            TextSelection.fromPosition(
                              TextPosition(
                                offset: chatStore.textController.text.length,
                              ),
                            );
                      },
                      child: Text(matchingChatters[index]),
                    ),
                  ),
                ),
              ),
            ],
            Padding(
              // Board Chaine: 10 above, 12 at the sides, 14 below.
              padding: EdgeInsets.fromLTRB(12, 10, 12, large ? 14 : 12),
              // A side chat at its narrowest (20 %) is smaller than the
              // pencil, the points and "⋯": they shrink rather than spill.
              child: _ShrinkWhenNarrow(
                enabled: inputControls.pencil,
                child: Row(
                  spacing: 8,
                  mainAxisSize: inputControls.pencil
                      ? MainAxisSize.min
                      : MainAxisSize.max,
                  children: [
                    if (inputControls.pencil)
                      Builder(
                        builder: (context) {
                          final isDisabled = !chatStore.auth.isLoggedIn;

                          return GestureDetector(
                            onTap: isDisabled
                                ? () {
                                    chatStore.updateNotification(
                                      loginTooltipMessage,
                                    );
                                  }
                                : null,
                            child: IconButton(
                              tooltip: 'Enter a message',
                              onPressed: isDisabled
                                  ? null
                                  : () {
                                      chatStore.expandChat = true;
                                      chatStore.safeRequestFocus();
                                    },
                              icon: const Icon(Icons.edit),
                            ),
                          );
                        },
                      )
                    else
                      Expanded(
                        child: Observer(
                          builder: (context) {
                            final isLoggedIn = chatStore.auth.isLoggedIn;
                            final isWaitingForAck = chatStore.isWaitingForAck;
                            final isConnected = chatStore.isConnected;
                            final hasConnected = chatStore.hasConnected;
                            final locked =
                                chatStore.restriction?.blocksInput ?? false;
                            final isEnabled =
                                isLoggedIn &&
                                !isWaitingForAck &&
                                isConnected &&
                                !locked;
                            // Inside the pill, as an accent disc, once there
                            // is something to send (board ChaineTchatOutils).
                            final sendButton =
                                chatStore.showSendButton && inputControls.send
                                ? _SendButton(
                                    waiting: isWaitingForAck,
                                    onPressed: isEnabled
                                        ? () => chatStore.sendMessage(
                                            chatStore.textController.text,
                                          )
                                        : null,
                                  )
                                : null;

                            return GestureDetector(
                              onTap: !isLoggedIn
                                  ? () {
                                      chatStore.updateNotification(
                                        loginTooltipMessage,
                                      );
                                    }
                                  : null,
                              child: ExtendedTextField(
                                textInputAction: TextInputAction.send,
                                focusNode: chatStore.textFieldFocusNode,
                                minLines: 1,
                                maxLines: 3,
                                enabled: isEnabled,
                                style: TextStyle(fontSize: large ? 15 : 14),
                                specialTextSpanBuilder: EmoteTextSpanBuilder(
                                  emoteToObject:
                                      chatStore.assetsStore.emoteToObject,
                                  userEmoteToObject:
                                      chatStore.assetsStore.userEmoteToObject,
                                  emoteSize:
                                      chatStore.settings.emoteScale *
                                      defaultEmoteSize,
                                ),
                                decoration: InputDecoration(
                                  // The pill is 44 high (48 on a tablet in
                                  // portrait), the field 40 inside it.
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal:
                                        chatStore
                                                .settings
                                                .emoteMenuButtonOnLeft &&
                                            emoteMenuButton != null
                                        ? 4
                                        : 16,
                                    // The icons' 44 / 48 dp set the height.
                                    vertical: 10,
                                  ),
                                  prefixIcon:
                                      chatStore.settings.emoteMenuButtonOnLeft
                                      ? emoteMenuButton
                                      : null,
                                  prefixIconConstraints: BoxConstraints(
                                    minWidth: large ? 44 : 40,
                                    minHeight: large ? 48 : 44,
                                  ),
                                  suffixIconConstraints: BoxConstraints(
                                    minHeight: large ? 48 : 44,
                                  ),
                                  suffixIcon: Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      spacing: 4,
                                      children: [
                                        ChatCharacterCounter(
                                          controller: chatStore.textController,
                                        ),
                                        if (!chatStore
                                                .settings
                                                .emoteMenuButtonOnLeft &&
                                            emoteMenuButton != null)
                                          emoteMenuButton,
                                        ?sendButton,
                                      ],
                                    ),
                                  ),
                                  hintMaxLines: 1,
                                  hintText: !isLoggedIn
                                      ? loginTooltipMessage
                                      : locked
                                      ? "You can't chat right now"
                                      : !isConnected
                                      ? (hasConnected
                                            ? 'Chat disconnected'
                                            : 'Connecting...')
                                      : isWaitingForAck
                                      ? 'Sending...'
                                      : chatStore.restriction != null
                                      ? chatStore.restriction!.describe(null)
                                      : chatStore.replyingToMessage != null
                                      ? channelDisplayName != null
                                            ? 'Reply in ${channelDisplayName!}'
                                            : 'Reply'
                                      : hasChatDelay
                                      ? channelDisplayName != null
                                            ? 'Chat in ${channelDisplayName!} (${effectiveChatDelay.toInt()}s delay)'
                                            : 'Chat (${effectiveChatDelay.toInt()}s delay)'
                                      : channelDisplayName != null
                                      ? 'Chat in ${channelDisplayName!}'
                                      : 'Chat',
                                ),
                                controller: chatStore.textController,
                                // Twitch refuses longer messages.
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(
                                    kChatMessageMaxLength,
                                  ),
                                ],
                                onSubmitted: chatStore.sendMessage,
                                onTapOutside: (_) {
                                  chatStore.textFieldFocusNode.unfocus();
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    // Beside the message box, where Twitch puts it.
                    ChannelPointsButton(
                      channelId: chatStore.channelId,
                      large: large,
                    ),
                    // The chat's details, always one tap away (approved
                    // addition next to the points), unless the chat's header
                    // already has it (a tablet's side chat).
                    if (!ChatMoreInHeader.of(context))
                      TextFieldTapRegion(
                        child: ChatMoreButton(
                          large: large,
                          onPressed: () => showModalBottomSheetWithProperFocus(
                            isScrollControlled: true,
                            context: context,
                            builder: (_) => ChatDetails(
                              chatDetailsStore: chatStore.chatDetailsStore,
                              chatStore: chatStore,
                              userLogin: chatStore.channelName,
                              onAddChat: onAddChat,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );

        // Don't add bottom padding when:
        // - Emote menu is open: The emote menu provides its own bottom boundary
        // - In horizontal landscape mode: System is in immersive mode and home
        //   indicator is on the side (left/right), not the content bottom.
        //   SafeArea handles left/right insets for the notch.
        // Note: landscapeForceVerticalChat uses portrait layout in landscape
        // orientation with normal (non-immersive) system UI, so it still needs
        // bottom padding.
        final isHorizontalLandscape =
            context.isLandscape &&
            !chatStore.settings.landscapeForceVerticalChat;
        final needsBottomPadding =
            !chatStore.assetsStore.showEmoteMenu && !isHorizontalLandscape;

        return isFullscreenOverlay
            ? Padding(
                padding: EdgeInsets.only(
                  bottom: needsBottomPadding
                      ? MediaQuery.of(context).padding.bottom
                      : 0,
                ),
                child: bottomBarContent,
              )
            : BlurredContainer(
                gradientDirection: GradientDirection.down,
                padding: EdgeInsets.only(
                  bottom: needsBottomPadding
                      ? MediaQuery.of(context).padding.bottom
                      : 0,
                ),
                child: bottomBarContent,
              );
      },
    );
  }
}

/// Send, inside the message pill: a 36 dp accent disc (a spinner while
/// Twitch has not acknowledged the last message).
class _SendButton extends StatelessWidget {
  const _SendButton({required this.waiting, required this.onPressed});

  final bool waiting;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = context.frostyColors.live;
    return IconButton(
      tooltip: waiting ? 'Sending...' : 'Send',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: accent,
        disabledBackgroundColor: accent.withValues(alpha: 0.4),
      ),
      onPressed: onPressed,
      icon: waiting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: FrostyTokens.backgroundDark,
              ),
            )
          : const PlayerGlyph(
              PlayerGlyphKind.send,
              color: FrostyTokens.backgroundDark,
              size: 18,
              strokeWidth: 2,
            ),
    );
  }
}

/// "⋯": the chat's details (modes, chatters, rules, reconnect, add chat…),
/// a 44 dp disc beside the channel points (board ChaineDetailsTchat).
class ChatMoreButton extends StatelessWidget {
  const ChatMoreButton({
    super.key,
    required this.onPressed,
    this.large = false,
  });

  final VoidCallback onPressed;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final size = large ? 48.0 : 44.0;
    return IconButton(
      tooltip: 'More',
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: size, height: size),
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: context.theme.inputDecorationTheme.fillColor,
        shape: CircleBorder(
          side: BorderSide(
            color: context.frostyColors.hairline,
            width: FrostyTokens.hairlineWidth,
          ),
        ),
      ),
      onPressed: onPressed,
      icon: PlayerGlyph(
        PlayerGlyphKind.more,
        color: context.colorScheme.onSurface,
      ),
    );
  }
}

/// Marks a chat whose header holds the "⋯" (a tablet's side chat, board
/// Tablette), so the input row does not repeat it.
class ChatMoreInHeader extends InheritedWidget {
  const ChatMoreInHeader({super.key, required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ChatMoreInHeader>() != null;

  @override
  bool updateShouldNotify(ChatMoreInHeader oldWidget) => false;
}

/// Scales [child] down to the width it is given, when [enabled].
class _ShrinkWhenNarrow extends StatelessWidget {
  const _ShrinkWhenNarrow({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: FittedBox(fit: BoxFit.scaleDown, child: child),
    );
  }
}
