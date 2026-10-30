import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/screens/channel/chat/emote_menu/emote_menu.dart';
import 'package:onset/screens/channel/chat/stores/chat_store.dart';
import 'package:onset/screens/channel/chat/stores/chat_tabs_store.dart';
import 'package:onset/screens/channel/chat/widgets/chat_bottom_bar.dart';
import 'package:onset/screens/channel/chat/widgets/chat_message.dart';
import 'package:onset/screens/channel/chat/widgets/chat_rules_sheet.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/common_utils.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/motion/motion.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';
import 'package:onset/widgets/onset_scrollbar.dart';
import 'package:onset/widgets/sheet/onset_panel.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';

class Chat extends StatefulWidget {
  final ChatStore chatStore;
  final EdgeInsetsGeometry? listPadding;

  /// Callback to add a new chat tab.
  /// Passes this to ChatBottomBar for the ChatDetails menu.
  final VoidCallback onAddChat;

  /// When set, the widget operates in merged mode: messages come from all tabs
  /// and the active tab determines the send target.
  final ChatTabsStore? chatTabsStore;

  const Chat({
    super.key,
    required this.chatStore,
    this.listPadding,
    required this.onAddChat,
    this.chatTabsStore,
  });

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  ChatStore get chatStore => widget.chatStore;
  EdgeInsetsGeometry? get listPadding => widget.listPadding;
  VoidCallback get onAddChat => widget.onAddChat;
  ChatTabsStore? get chatTabsStore => widget.chatTabsStore;

  bool get _isMerged => chatTabsStore != null;

  /// Whether the last build put the emote menu under the input.
  bool _builtInline = false;

  /// Where the tablet's emote panel goes, above the input in this chat
  /// (board ChaineOutilsTablette); null when it does not fit (the menu
  /// then opens under the input, as on a phone). Read from the last
  /// layout, so [_recheckPlacement] confirms it after each frame.
  PanelPlacement? _emotePanelPlacement() {
    final chat = globalRectOf(context);
    if (chat == null || chat.isEmpty) return null;
    final media = MediaQuery.of(context);
    final isHorizontalLandscape =
        context.isLandscape && !chatStore.settings.landscapeForceVerticalChat;
    final bottomInset = isHorizontalLandscape ? 0.0 : media.padding.bottom;
    // Where the input sits once the menu is a panel: at the bottom of the
    // chat, even while an inline menu still pushes it up.
    final barTop = chat.bottom - bottomInset - chatStore.bottomBarHeight;
    // The nub points at the emote button, at one end of the input. The
    // setting's "left" is the input's start (its prefix), so the right
    // in a right-to-left language.
    final atStart = chatStore.settings.emoteMenuButtonOnLeft;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final inset = atStart ? 32.0 : 120.0;
    final buttonX = atStart != rtl ? chat.left + inset : chat.right - inset;
    return placePanel(
      bounds: Rect.fromLTRB(
        media.padding.left,
        media.padding.top,
        media.size.width - media.padding.right,
        media.size.height - media.padding.bottom,
      ),
      anchor: Rect.fromLTWH(buttonX - 18, barTop, 36, 44),
      size: EmoteMenu.panelSize,
      sides: const [PanelSide.above],
      region: chat,
      avoid: PanelAvoidScope.of(context),
      gap: 10,
    );
  }

  /// A rotation, the video toggling or a first open decide on a layout
  /// that is about to change: once laid out, decide again.
  void _recheckPlacement() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !chatStore.assetsStore.showEmoteMenu) return;
      final inline = _emotePanelPlacement() == null;
      if (inline != _builtInline) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final showEmoteMenu = chatStore.assetsStore.showEmoteMenu;
        // A tablet's emote menu is a panel over the chat when it fits.
        final tablet = context.isLargeScreen;
        final emoteMenuInline =
            showEmoteMenu && (!tablet || _emotePanelPlacement() == null);
        _builtInline = emoteMenuInline;
        if (tablet && showEmoteMenu) _recheckPlacement();
        return PanelRegion(
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  alignment: AlignmentDirectional.bottomCenter,
                  children: [
                    // Wrap only the message list with GestureDetector
                    // so taps on ChatBottomBar don't trigger unfocus
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (chatStore.assetsStore.showEmoteMenu) {
                          chatStore.assetsStore.showEmoteMenu = false;
                        } else if (chatStore.textFieldFocusNode.hasFocus) {
                          chatStore.unfocusInput();
                        }
                      },
                      child: MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          textScaler:
                              chatStore.settings.messageScale.textScaler,
                        ),
                        child: DefaultTextStyle(
                          style: context.defaultTextStyle.copyWith(
                            fontSize: chatStore.settings.fontSize,
                          ),
                          child: Builder(
                            builder: (context) {
                              // Don't add bottom padding in horizontal landscape
                              // (immersive mode with home indicator on side).
                              // landscapeForceVerticalChat uses portrait layout
                              // with normal system UI, so still needs padding.
                              final isHorizontalLandscape =
                                  context.isLandscape &&
                                  !chatStore
                                      .settings
                                      .landscapeForceVerticalChat;
                              final bottomPadding =
                                  emoteMenuInline || isHorizontalLandscape
                                  ? 0.0
                                  : MediaQuery.of(context).padding.bottom;

                              final scrollController = _isMerged
                                  ? chatTabsStore!.mergedScrollController
                                  : chatStore.scrollController;

                              return OnsetScrollbar(
                                controller: scrollController,
                                padding: EdgeInsets.only(
                                  top: MediaQuery.of(context).padding.top,
                                  bottom:
                                      chatStore.bottomBarHeight + bottomPadding,
                                ),
                                child: Observer(
                                  builder: (context) {
                                    return _isMerged
                                        ? _buildMergedList(
                                            scrollController,
                                            bottomPadding,
                                          )
                                        : _buildNormalList(
                                            scrollController,
                                            bottomPadding,
                                          );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ChatRulesPrompt(
                        rules: chatStore.chatRules,
                        focus: chatStore.textFieldFocusNode,
                        child: ChatBottomBar(
                          chatStore: chatStore,
                          onAddChat: onAddChat,
                          emoteMenuInline: emoteMenuInline,
                          channelDisplayName: _isMerged
                              ? getReadableName(
                                  chatTabsStore!.activeTab.displayName,
                                  chatTabsStore!.activeTab.channelLogin,
                                )
                              : null,
                        ),
                      ),
                    ),
                    _buildResumeScrollButton(emoteMenuInline),
                    if (tablet)
                      EmoteMenuPanelOverlay(
                        chatStore: chatStore,
                        open: showEmoteMenu && !emoteMenuInline,
                        onClose: () =>
                            chatStore.assetsStore.showEmoteMenu = false,
                        placement: _emotePanelPlacement,
                      ),
                  ],
                ),
              ),
              _buildEmoteMenu(context, open: emoteMenuInline),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNormalList(
    ScrollController scrollController,
    double bottomPadding,
  ) {
    return ListView.builder(
      reverse: true,
      padding: (listPadding ?? EdgeInsets.zero).add(
        EdgeInsets.only(bottom: chatStore.bottomBarHeight + bottomPadding),
      ),
      addAutomaticKeepAlives: false,
      controller: scrollController,
      itemCount: chatStore.renderMessages.length,
      itemBuilder: (context, index) => ChatMessage(
        ircMessage: chatStore
            .renderMessages[chatStore.renderMessages.length - 1 - index],
        chatStore: chatStore,
      ),
    );
  }

  Widget _buildMergedList(
    ScrollController scrollController,
    double bottomPadding,
  ) {
    final mergedMessages = chatTabsStore!.mergedMessages;
    final channelIdToUserTwitch = chatTabsStore!.mergedChannelIdToUserTwitch;
    final currentChannelId = chatTabsStore!.activeTab.channelId;

    return ListView.builder(
      reverse: true,
      padding: (listPadding ?? EdgeInsets.zero).add(
        EdgeInsets.only(bottom: chatStore.bottomBarHeight + bottomPadding),
      ),
      addAutomaticKeepAlives: false,
      controller: scrollController,
      itemCount: mergedMessages.length,
      itemBuilder: (context, index) {
        final merged = mergedMessages[mergedMessages.length - 1 - index];
        return ChatMessage(
          ircMessage: merged.ircMessage,
          chatStore: merged.chatStore,
          inputChatStore: chatStore,
          onActivateSourceTab: () {
            final tabs = chatTabsStore!.tabs;
            final idx = tabs.indexWhere(
              (t) => t.channelId == merged.chatStore.channelId,
            );
            if (idx != -1 && idx != chatTabsStore!.activeTabIndex) {
              chatTabsStore!.setActiveTab(idx, silent: true);
            }
          },
          overrideChannelIdToUserTwitch: channelIdToUserTwitch,
          overrideCurrentChannelId: currentChannelId,
        );
      },
    );
  }

  Widget _buildResumeScrollButton(bool emoteMenuInline) {
    return Builder(
      builder: (context) {
        final isHorizontalLandscape =
            context.isLandscape &&
            !chatStore.settings.landscapeForceVerticalChat;
        return AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.only(
            left: 4,
            top: 4,
            right: 4,
            bottom:
                chatStore.bottomBarHeight +
                (emoteMenuInline || isHorizontalLandscape
                    ? 0
                    : MediaQuery.of(context).padding.bottom),
          ),
          child: Observer(
            builder: (_) {
              final isAutoScrolling = _isMerged
                  ? chatTabsStore!.mergedAutoScroll
                  : chatStore.autoScroll;
              final bufferCount = _isMerged
                  ? chatTabsStore!.mergedBufferCount
                  : chatStore.messageBuffer.length;
              final onResume = _isMerged
                  ? chatTabsStore!.resumeMergedScroll
                  : chatStore.resumeScroll;

              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: isAutoScrolling
                    ? null
                    : ElevatedButton.icon(
                        onPressed: onResume,
                        icon: const Icon(Icons.arrow_downward_rounded),
                        label: Text(
                          bufferCount > 0
                              ? '$bufferCount new ${bufferCount == 1 ? 'message' : 'messages'}'
                              : 'Resume scroll',
                          style: context.onsetText.metadata,
                        ),
                      ),
              );
            },
          ),
        );
      },
    );
  }

  /// The emote menu under the input (a phone, or a tablet without room
  /// for the panel): board ChaineTchatOutils, #101010 under a hairline.
  Widget _buildEmoteMenu(BuildContext context, {required bool open}) {
    final colors = SheetColors.of(context);
    return AnimatedContainer(
      curve: OnsetMotion.standard,
      duration: motionDuration(context, const Duration(milliseconds: 260)),
      height: open ? context.screenHeight / (context.isPortrait ? 3 : 2) : 0,
      color: colors.emoteMenu,
      child: AnimatedSwitcher(
        duration: motionDuration(context, const Duration(milliseconds: 100)),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: open
            ? ClipRect(
                child: Column(
                  children: [
                    Container(
                      height: OnsetTokens.hairlineWidth,
                      color: colors.ring,
                    ),
                    Expanded(child: EmoteMenu(chatStore: chatStore)),
                  ],
                ),
              )
            : null,
      ),
    );
  }
}
