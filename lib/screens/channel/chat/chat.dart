import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/channel/chat/emote_menu/emote_menu.dart';
import 'package:onset/screens/channel/chat/mod_tools/stores/mod_tools_store.dart';
import 'package:onset/screens/channel/chat/mod_tools/widgets/mod_tools_sheet.dart';
import 'package:onset/screens/channel/chat/mod_tools/widgets/shield_mode_indicator.dart';
import 'package:onset/screens/channel/chat/stores/chat_store.dart';
import 'package:onset/screens/channel/chat/stores/chat_tabs_store.dart';
import 'package:onset/screens/channel/chat/widgets/chat_bottom_bar.dart';
import 'package:onset/screens/channel/chat/widgets/chat_message.dart';
import 'package:onset/screens/channel/chat/widgets/chat_rules_sheet.dart';
import 'package:onset/screens/channel/chat/widgets/chat_user_modal.dart';
import 'package:onset/screens/channel/chat/widgets/overlay_chat_scope.dart';
import 'package:onset/screens/channel/chat/widgets/shared_chat_banner.dart';
import 'package:onset/screens/settings/chat_settings.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/settings_page.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/common_utils.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/announce.dart';
import 'package:onset/widgets/motion/motion.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';
import 'package:onset/widgets/onset_scrollbar.dart';
import 'package:onset/widgets/sheet/onset_panel.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';

typedef ChatSettingsOpener =
    void Function(BuildContext context, SettingsStore settings);

void openChatSettings(BuildContext context, SettingsStore settings) =>
    unawaited(
      openSettingsPage(
        context,
        id: SettingsPageId.chat,
        builder: (_) => ChatSettings(settingsStore: settings),
      ),
    );

typedef ChatUserCardOpener =
    void Function(
      BuildContext context, {
      required ChatStore chatStore,
      required ChatUserCardRequest user,
    });

void openChatUserCard(
  BuildContext context, {
  required ChatStore chatStore,
  required ChatUserCardRequest user,
}) => showChatUserCard(
  context,
  chatStore: chatStore,
  username: user.login,
  userId: user.id,
  displayName: user.displayName,
);

class _SharedChatBannerSlot extends StatelessWidget {
  const _SharedChatBannerSlot({required this.chatStore});

  final ChatStore chatStore;

  @override
  Widget build(BuildContext context) => Observer(
    builder: (context) {
      final show = chatStore.showSharedChatBanner;
      return AnimatedSwitcher(
        duration: motionDuration(context, const Duration(milliseconds: 240)),
        switchInCurve: OnsetMotion.emphasizedDecelerate,
        switchOutCurve: OnsetMotion.emphasizedAccelerate,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SizeTransition(
            sizeFactor: animation,
            axisAlignment: -1,
            child: child,
          ),
        ),
        child: show
            ? SharedChatBanner(
                key: const ValueKey('shared-chat-banner'),
                partners: chatStore.sharedChatPartners,
                startedNow: chatStore.sharedChatStartedNow,
                onDismiss: chatStore.dismissSharedChatBanner,
              )
            : const SizedBox(width: double.infinity),
      );
    },
  );
}

class Chat extends StatefulWidget {
  final ChatStore chatStore;
  final EdgeInsetsGeometry? listPadding;

  /// Callback to add a new chat tab.
  /// Passes this to ChatBottomBar for the ChatDetails menu.
  final VoidCallback onAddChat;

  /// When set, the widget operates in merged mode: messages come from all tabs
  /// and the active tab determines the send target.
  final ChatTabsStore? chatTabsStore;

  final ChatUserCardOpener openUserCard;

  final ChatSettingsOpener openSettings;

  const Chat({
    super.key,
    required this.chatStore,
    this.listPadding,
    required this.onAddChat,
    this.chatTabsStore,
    this.openUserCard = openChatUserCard,
    this.openSettings = openChatSettings,
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

  StreamSubscription<ChatUserCardRequest>? _userCards;
  StreamSubscription<void>? _settingsRequests;
  StreamSubscription<ModToolsView>? _modToolsRequests;
  ReactionDisposer? _expandAnnouncer;

  @override
  void initState() {
    super.initState();
    _listenUserCards();
    _announceExpansion();
  }

  @override
  void didUpdateWidget(Chat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chatStore != widget.chatStore) {
      _listenUserCards();
      _announceExpansion();
    }
  }

  void _announceExpansion() {
    _expandAnnouncer?.call();
    _expandAnnouncer = reaction((_) => chatStore.expandChat, (bool expanded) {
      if (!mounted) return;
      final l = context.l10n;
      announce(
        context,
        expanded ? l.chatExpandedAnnouncement : l.chatCollapsedAnnouncement,
      );
    });
  }

  @override
  void dispose() {
    _userCards?.cancel();
    _settingsRequests?.cancel();
    _modToolsRequests?.cancel();
    _expandAnnouncer?.call();
    super.dispose();
  }

  void _listenUserCards() {
    _userCards?.cancel();
    _userCards = chatStore.userCardRequests.listen((user) {
      if (!mounted) return;
      widget.openUserCard(context, chatStore: chatStore, user: user);
    });
    _settingsRequests?.cancel();
    _settingsRequests = chatStore.chatSettingsRequests.listen((_) {
      if (!mounted) return;
      widget.openSettings(context, chatStore.settings);
    });
    _modToolsRequests?.cancel();
    _modToolsRequests = chatStore.modToolsRequests.listen((view) {
      if (!mounted) return;
      showModTools(context, chatStore, view: view);
    });
  }

  /// Whether the last build put the emote menu under the input.
  bool _builtInline = false;

  /// Where the tablet's emote panel goes, above the input in this chat;
  /// null when it does not fit (the menu
  /// then opens under the input, as on a phone). Read from the last
  /// layout, so [_recheckPlacement] confirms it after each frame.
  PanelPlacement? _emotePanelPlacement() {
    final chat = globalRectOf(context);
    if (chat == null || chat.isEmpty) return null;
    // One aspect each: this runs in the chat's build, which must not be
    // rebuilt by the keyboard's insets changing on every frame.
    final padding = MediaQuery.paddingOf(context);
    final size = MediaQuery.sizeOf(context);
    final isHorizontalLandscape =
        context.isLandscape && !chatStore.settings.landscapeForceVerticalChat;
    final bottomInset = isHorizontalLandscape ? 0.0 : padding.bottom;
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
        padding.left,
        padding.top,
        size.width - padding.right,
        size.height - padding.bottom,
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
        final tapClosesOverlay =
            chatStore.settings.tapToCloseOverlayChat &&
            OverlayChatScope.of(context);
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
                        } else if (tapClosesOverlay) {
                          chatStore.settings.fullScreenChatOverlay = false;
                        }
                      },
                      child: _MessageTextScale(
                        scale: chatStore.settings.messageScale,
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
                              // The screen's bottom padding is read by the
                              // leaves below only: it changes as the
                              // keyboard slides over the navigation bar,
                              // and the messages must not be rebuilt then.
                              final safeBottom =
                                  !emoteMenuInline && !isHorizontalLandscape;

                              final scrollController = _isMerged
                                  ? chatTabsStore!.mergedScrollController
                                  : chatStore.scrollController;

                              final list = Observer(
                                builder: (context) {
                                  return _isMerged
                                      ? _buildMergedList(
                                          scrollController,
                                          safeBottom,
                                        )
                                      : _buildNormalList(
                                          scrollController,
                                          safeBottom,
                                        );
                                },
                              );
                              // The input's height (reply bar, autocomplete,
                              // restriction bar) is observed here: nothing
                              // else rebuilds the scrollbar when it changes.
                              // The list, built above, is passed in as is.
                              return Observer(
                                builder: (_) => _ChatScrollbar(
                                  controller: scrollController,
                                  bottomBarHeight: chatStore.bottomBarHeight,
                                  safeBottom: safeBottom,
                                  child: list,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _SharedChatBannerSlot(chatStore: chatStore),
                    ),
                    PositionedDirectional(
                      top: 8,
                      end: 8,
                      child: ShieldModeIndicator(chatStore: chatStore),
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

  Widget _buildNormalList(ScrollController scrollController, bool safeBottom) {
    final messages = chatStore.renderMessages;
    return _ChatListView(
      controller: scrollController,
      padding: listPadding,
      bottomBarHeight: chatStore.bottomBarHeight,
      safeBottom: safeBottom,
      count: messages.length,
      delegate: SliverChildBuilderDelegate(
        (context, index) => ChatMessage(
          ircMessage: messages[messages.length - 1 - index],
          chatStore: chatStore,
        ),
        childCount: messages.length,
        addAutomaticKeepAlives: false,
      ),
    );
  }

  Widget _buildMergedList(ScrollController scrollController, bool safeBottom) {
    final mergedMessages = chatTabsStore!.mergedMessages;
    final channelIdToUserTwitch = chatTabsStore!.mergedChannelIdToUserTwitch;
    final currentChannelId = chatTabsStore!.activeTab.channelId;

    return _ChatListView(
      controller: scrollController,
      padding: listPadding,
      bottomBarHeight: chatStore.bottomBarHeight,
      safeBottom: safeBottom,
      count: mergedMessages.length,
      delegate: SliverChildBuilderDelegate(
        (context, index) {
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
        childCount: mergedMessages.length,
        addAutomaticKeepAlives: false,
      ),
    );
  }

  Widget _buildResumeScrollButton(bool emoteMenuInline) {
    // An Observer: it follows the input's height (a reply bar appearing),
    // which nothing else rebuilds it for.
    return Observer(
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
                    : MediaQuery.paddingOf(context).bottom),
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
                              ? context.l10n.chatNewMessages(count: bufferCount)
                              : context.l10n.chatResumeScroll,
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
  /// for the panel): #101010 under a hairline.
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

/// The chat's message size setting, applied over the screen's metrics.
///
/// Its own widget: copying the whole [MediaQueryData] depends on all of
/// it, and the software keyboard changes it on every frame it slides in.
/// Here only this widget is rebuilt then; the messages under it, built
/// once and passed as [child], are left alone unless an aspect they read
/// changed.
class _MessageTextScale extends StatelessWidget {
  const _MessageTextScale({required this.scale, required this.child});

  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: scale.textScaler),
      child: child,
    );
  }
}

/// The message list: a reversed [ListView] over [delegate], padded with
/// [padding], the chat input's [bottomBarHeight] and, when [safeBottom],
/// the screen's bottom padding.
///
/// The bottom padding is read here, in a widget of its own, and the
/// [delegate] is made by the caller: when that padding changes (the
/// keyboard sliding over the navigation bar) only this list is rebuilt,
/// with the same delegate, so the messages already built are kept.
class _ChatListView extends StatelessWidget {
  const _ChatListView({
    required this.controller,
    required this.padding,
    required this.bottomBarHeight,
    required this.safeBottom,
    required this.count,
    required this.delegate,
  });

  final ScrollController controller;
  final EdgeInsetsGeometry? padding;
  final double bottomBarHeight;
  final bool safeBottom;
  final int count;
  final SliverChildDelegate delegate;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = safeBottom
        ? MediaQuery.paddingOf(context).bottom
        : 0.0;
    // What ListView.builder makes, with the delegate kept.
    return ListView.custom(
      reverse: true,
      padding: (padding ?? EdgeInsets.zero).add(
        EdgeInsets.only(bottom: bottomBarHeight + bottomPadding),
      ),
      controller: controller,
      semanticChildCount: count,
      childrenDelegate: delegate,
    );
  }
}

/// The chat's scrollbar, kept clear of the screen's padding and of the chat
/// input; it reads the padding itself so that [child], the message list,
/// is not rebuilt when the padding changes.
class _ChatScrollbar extends StatelessWidget {
  const _ChatScrollbar({
    required this.controller,
    required this.bottomBarHeight,
    required this.safeBottom,
    required this.child,
  });

  final ScrollController controller;
  final double bottomBarHeight;
  final bool safeBottom;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return OnsetScrollbar(
      controller: controller,
      padding: EdgeInsets.only(
        top: padding.top,
        bottom: bottomBarHeight + (safeBottom ? padding.bottom : 0),
      ),
      child: child,
    );
  }
}
