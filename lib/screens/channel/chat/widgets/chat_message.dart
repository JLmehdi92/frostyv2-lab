import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/constants.dart';
import 'package:frosty/models/irc.dart';
import 'package:frosty/models/user.dart';
import 'package:frosty/models/user_notice.dart';
import 'package:frosty/models/user_notice_presentation.dart';
import 'package:frosty/screens/channel/chat/chat_commands.dart';
import 'package:frosty/screens/channel/chat/chat_filters.dart';
import 'package:frosty/screens/channel/chat/stores/chat_store.dart';
import 'package:frosty/screens/channel/chat/widgets/chat_link_card.dart';
import 'package:frosty/screens/channel/chat/widgets/chat_user_modal.dart';
import 'package:frosty/screens/channel/chat/widgets/filtered_message_sheet.dart';
import 'package:frosty/screens/channel/chat/widgets/overlay_chat_scope.dart';
import 'package:frosty/screens/channel/chat/widgets/reply_thread.dart';
import 'package:frosty/screens/channel/chat/widgets/user_notice_row.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/utils/modal_bottom_sheet.dart';
import 'package:provider/provider.dart';

class ChatMessage extends StatelessWidget {
  final IRCMessage ircMessage;
  final ChatStore chatStore;
  final bool isModal;
  final bool showReplyHeader;
  final bool isInReplyThread;

  /// Override for merged chat view — provides combined channel profiles.
  final Map<String, UserTwitch>? overrideChannelIdToUserTwitch;

  /// Override for merged chat view — sets the active/send-target channel ID.
  final String? overrideCurrentChannelId;

  /// In merged mode, the active tab's ChatStore for notifications and emote
  /// menu. Composer actions (reply/paste) use [onActivateSourceTab] to switch
  /// to the source tab first, then operate on [chatStore] directly.
  final ChatStore? inputChatStore;

  /// In merged mode, switches the active tab to this message's source channel.
  final VoidCallback? onActivateSourceTab;

  const ChatMessage({
    super.key,
    required this.ircMessage,
    required this.chatStore,
    this.isModal = false,
    this.showReplyHeader = true,
    this.isInReplyThread = false,
    this.overrideChannelIdToUserTwitch,
    this.overrideCurrentChannelId,
    this.inputChatStore,
    this.onActivateSourceTab,
  });

  void onTapName(BuildContext context) {
    // Ignore if the message is a recent message in the modal bottom sheet.
    if (isModal) return;

    // Ignore if long-pressing own username.
    if (ircMessage.user == null ||
        ircMessage.user == chatStore.auth.user.details?.login) {
      return;
    }

    showModalBottomSheetWithProperFocus(
      isScrollControlled: true,
      context: context,
      builder: (context) => ChatUserModal(
        chatStore: chatStore,
        username: ircMessage.user!,
        userId: ircMessage.tags['user-id']!,
        displayName: ircMessage.tags['display-name']!,
      ),
    );
  }

  void onTapPingedUser(BuildContext context, {required String nickname}) {
    // Ignore if the message is a recent message in the modal bottom sheet.
    if (isModal) return;

    final twitchApi = context.read<TwitchApi>();
    twitchApi.getUser(userLogin: nickname).then((user) {
      if (context.mounted) {
        showModalBottomSheetWithProperFocus(
          isScrollControlled: true,
          context: context,
          builder: (context) => ChatUserModal(
            chatStore: chatStore,
            username: user.login,
            userId: user.id,
            displayName: user.displayName,
          ),
        );
      }
    });
  }

  /// The store to use for notifications and emote menu in merged mode.
  ChatStore get _effectiveInputStore => inputChatStore ?? chatStore;

  Future<void> copyMessage() async {
    await Clipboard.setData(ClipboardData(text: ircMessage.message ?? ''));

    _effectiveInputStore.updateNotification('Message copied');
  }

  /// Whether this message is drawn as a [UserNoticeRow]: any `USERNOTICE`
  /// but an announcement, which keeps its own look. Still true once the
  /// notice is deleted or its author banned: only its message is hidden then.
  bool get _isNoticeRow {
    final notice = ircMessage.notice;
    return notice != null && notice.kind != UserNoticeKind.announcement;
  }

  /// Whether the viewer's own message is hidden, by a deletion or a ban that
  /// the viewer has neither revealed nor chosen to see through.
  bool get _isMessageHidden =>
      (ircMessage.command == Command.clearChat ||
          ircMessage.command == Command.clearMessage) &&
      !chatStore.settings.showDeletedMessages &&
      !chatStore.revealedMessageIds.contains(ircMessage.tags['id']);

  /// The channel profiles known to this chat, by channel id.
  Map<String, UserTwitch> get _channelProfiles =>
      overrideChannelIdToUserTwitch ??
      chatStore.assetsStore.channelIdToUserTwitch;

  /// The display name of the channel a notice happened in: in a shared chat,
  /// the channel it was relayed from.
  String get _noticeChannelName {
    final source = ircMessage.tags['source-room-id'];
    return (source == null ? null : _channelProfiles[source]?.displayName) ??
        chatStore.displayName;
  }

  /// Copies what a notice row shows: its sentence, then the viewer's message.
  Future<void> copyNotice() async {
    final sentence = ircMessage
        .noticeText(channelName: _noticeChannelName)
        .map((segment) => segment.text)
        .join();
    final text = [
      if (sentence.isNotEmpty) sentence,
      if (ircMessage.message != null && !_isMessageHidden) ircMessage.message!,
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));

    _effectiveInputStore.updateNotification('Message copied');
  }

  /// A moderator may delete this message: one sent in this chat (not from
  /// another channel of a shared chat), not by the broadcaster, and not by
  /// another moderator unless the viewer is the broadcaster.
  bool get _canDelete {
    final source = ircMessage.tags['source-room-id'];
    return chatStore.canModerate &&
        ircMessage.command == Command.privateMessage &&
        ircMessage.tags['id'] != null &&
        (source == null || source == chatStore.channelId) &&
        ircMessage.user?.toLowerCase() != chatStore.channelName.toLowerCase() &&
        // Only the broadcaster may delete a moderator's message.
        (ircMessage.tags['mod'] != '1' ||
            chatStore.channelName.toLowerCase() ==
                chatStore.auth.user.details?.login.toLowerCase());
  }

  /// The id the viewer's "Show Message" is remembered under.
  String get _filterKey =>
      ircMessage.tags['id'] ?? 'local-${identityHashCode(ircMessage)}';

  /// The chat filters to apply to this message, or null when nothing of it
  /// is hidden: filters off, a channel the viewer moderates ("you will
  /// still see all messages"), nothing rated high enough, or revealed.
  ChatFilterSettings? get _chatFilters {
    if (!chatStore.settings.chatFiltersEnabled) return null;
    final filters = ChatFilterSettings.of(chatStore.settings);
    if (!ircMessage.isFiltered(filters) || chatStore.canModerate) return null;
    if (chatStore.revealedFilteredMessageIds.contains(_filterKey)) return null;
    return filters;
  }

  /// Twitch's "Message Blocked" question; "Show Message" reveals it.
  Future<void> _onTapFiltered(BuildContext context) async {
    if (isModal) return;
    final show = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => const FilteredMessageSheet(),
    );
    if (show == true) chatStore.revealFilteredMessage(_filterKey);
  }

  void onLongPressMessage(BuildContext context, TextStyle defaultTextStyle) {
    HapticFeedback.lightImpact();

    if (_isNoticeRow) {
      copyNotice();
      return;
    }

    if (ircMessage.command != Command.privateMessage &&
        ircMessage.command != Command.userState) {
      copyMessage();
      return;
    }

    showModalBottomSheetWithProperFocus(
      context: context,
      isScrollControlled: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        primary: false,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text.rich(
              TextSpan(
                children: ircMessage.generateSpan(
                  context,
                  assetsStore: chatStore.assetsStore,
                  emoteScale: chatStore.settings.emoteScale,
                  badgeScale: chatStore.settings.badgeScale,
                  animateEmotes: chatStore.settings.animateEmotes,
                  showGifs: chatStore.settings.showGifs,
                  animateGifs: chatStore.settings.animateGifs,
                  launchExternal: chatStore.settings.launchUrlExternal,
                  timestamp: chatStore.settings.timestampType,
                  channelIdToUserTwitch:
                      overrideChannelIdToUserTwitch ??
                      chatStore.assetsStore.channelIdToUserTwitch,
                  currentChannelId:
                      overrideCurrentChannelId ?? chatStore.channelId,
                  chatFilters: _chatFilters,
                ),
                style: defaultTextStyle,
              ),
            ),
          ),
          const Divider(indent: 12, endIndent: 12),
          ListTile(
            onTap: () {
              copyMessage();
              Navigator.pop(context);
            },
            leading: const Icon(Icons.copy),
            title: const Text('Copy message'),
          ),
          ListTile(
            onTap: () async {
              await copyMessage();

              final effectiveChatDelay = chatStore.settings.effectiveChatDelay;

              final hasChatDelay =
                  chatStore.settings.showVideo && effectiveChatDelay > 0;

              if (hasChatDelay) {
                _effectiveInputStore.updateNotification(
                  'Chatting is disabled due to message delay (${effectiveChatDelay.toInt()}s)',
                );
                if (context.mounted) {
                  Navigator.pop(context);
                }
                return;
              }

              // In merged mode, switch to the source tab so the paste
              // targets the correct channel's composer.
              onActivateSourceTab?.call();

              // Paste the copied message into the text controller
              chatStore.textController.text = ircMessage.message ?? '';
              chatStore.safeRequestFocus();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            leading: const Icon(Icons.content_paste),
            title: const Text('Copy message and paste'),
          ),
          ListTile(
            onTap: () {
              // In merged mode, switch to the source tab so the reply
              // targets the correct channel (reply-parent-msg-id is
              // channel-scoped).
              onActivateSourceTab?.call();

              chatStore.replyingToMessage = ircMessage;
              chatStore.safeRequestFocus();
              Navigator.pop(context);
            },
            leading: const Icon(Icons.reply),
            title: const Text('Reply to message'),
          ),
          if (_canDelete)
            ListTile(
              onTap: () {
                Navigator.pop(context);
                chatStore.moderate(
                  DeleteMessageCommand(ircMessage.tags['id']!),
                );
              },
              leading: Icon(
                Icons.delete_outline_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              title: const Text('Delete message'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final defaultTextStyle = DefaultTextStyle.of(context).style;
    final messageHeaderIconSize =
        defaultBadgeSize * chatStore.settings.badgeScale;
    final messageHeaderTextColor = context.frostyColors.metadata;
    const messageHeaderFontWeight = FontWeight.w600;

    return Observer(
      builder: (context) {
        Color? highlightColor;
        final Widget renderMessage;
        // A notice row draws its own full-width background and accent, so it
        // skips the highlight wrapper and the side padding.
        var isNoticeRow = false;

        switch (ircMessage.command) {
          case Command.privateMessage:
          case Command.userState:
            final shouldHighlightFirstMessage =
                chatStore.settings.highlightFirstTimeChatter &&
                ircMessage.tags['first-msg'] == '1';
            final shouldHighlightMessage =
                chatStore.settings.showUserNotices &&
                ircMessage.tags['msg-id'] == 'highlighted-message';

            final messageSpan = Text.rich(
              TextSpan(
                children: ircMessage.generateSpan(
                  context,
                  onTapName: () => onTapName(context),
                  onTapPingedUser: (nickname) =>
                      onTapPingedUser(context, nickname: nickname),
                  style: defaultTextStyle,
                  assetsStore: chatStore.assetsStore,
                  emoteScale: chatStore.settings.emoteScale,
                  badgeScale: chatStore.settings.badgeScale,
                  animateEmotes: chatStore.settings.animateEmotes,
                  showGifs: chatStore.settings.showGifs,
                  animateGifs: chatStore.settings.animateGifs,
                  launchExternal: chatStore.settings.launchUrlExternal,
                  timestamp: chatStore.settings.timestampType,
                  channelIdToUserTwitch:
                      overrideChannelIdToUserTwitch ??
                      chatStore.assetsStore.channelIdToUserTwitch,
                  currentChannelId:
                      overrideCurrentChannelId ?? chatStore.channelId,
                  chatFilters: _chatFilters,
                  onTapFiltered: () => _onTapFiltered(context),
                ),
              ),
            );

            // Check if the message is replying to another message.
            final replyUser = ircMessage.tags['reply-parent-display-name'];
            final replyBody = ircMessage.tags['reply-parent-msg-body'];

            Widget? messageHeaderIcon;
            Widget? messageHeader;
            if (replyUser != null && replyBody != null && showReplyHeader) {
              messageHeaderIcon = Icon(
                Icons.chat_rounded,
                size: messageHeaderIconSize,
                color: messageHeaderTextColor,
              );
              messageHeader = GestureDetector(
                onTap: isModal
                    ? null
                    : () => showModalBottomSheetWithProperFocus(
                        context: context,
                        builder: (context) {
                          return ReplyThread(
                            selectedMessage: ircMessage,
                            chatStore: chatStore,
                          );
                        },
                      ),
                child: Text.rich(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  TextSpan(
                    children: [
                      TextSpan(
                        text: replyUser,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: messageHeaderTextColor,
                        ),
                      ),
                      TextSpan(
                        text: ': $replyBody',
                        style: TextStyle(color: messageHeaderTextColor),
                      ),
                    ],
                  ),
                ),
              );
            } else if (shouldHighlightFirstMessage) {
              highlightColor = context.frostyColors.highlightedMessage;
              messageHeaderIcon = Icon(
                Icons.auto_awesome_rounded,
                size: messageHeaderIconSize,
                color: messageHeaderTextColor,
              );
              messageHeader = Text(
                'First message',
                style: TextStyle(
                  fontWeight: messageHeaderFontWeight,
                  color: messageHeaderTextColor,
                ),
              );
            } else if (shouldHighlightMessage) {
              highlightColor = context.frostyColors.highlightedMessage;
              messageHeader = Text(
                'Highlighted message',
                style: TextStyle(
                  fontWeight: messageHeaderFontWeight,
                  color: messageHeaderTextColor,
                ),
              );
            }

            // If user is being mentioned in the message, highlight it red.
            if (ircMessage.mention == true) {
              highlightColor = context.colorScheme.error;
            }

            final Widget body;
            if (messageHeader != null) {
              body = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  if (messageHeaderIcon != null)
                    Row(
                      spacing: 4,
                      children: [
                        messageHeaderIcon,
                        Flexible(child: messageHeader),
                      ],
                    )
                  else
                    messageHeader,
                  messageSpan,
                ],
              );
            } else {
              body = messageSpan;
            }

            // A link the chat filters hide is not previewed.
            final preview = chatStore.settings.showLinkPreviews
                ? chatPreviewLink(ircMessage.shownText(_chatFilters))
                : null;
            renderMessage = preview == null
                ? body
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      body,
                      ChatLinkCard(link: preview.link, url: preview.url),
                    ],
                  );

            break;
          case Command.clearChat:
          case Command.clearMessage:
            // A deleted notice, or one whose author was banned, keeps its
            // sentence: only the viewer's own message goes.
            if (_isNoticeRow) {
              if (chatStore.settings.showUserNotices) {
                isNoticeRow = true;
                renderMessage = _noticeRow(
                  context,
                  defaultTextStyle,
                  showMessage: !_isMessageHidden,
                );
              } else {
                renderMessage = const SizedBox();
              }
              break;
            }

            // Render timeouts and bans
            final banDuration = ircMessage.tags['ban-duration'];

            renderMessage = Opacity(
              opacity: 0.5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  if (banDuration == null)
                    if (ircMessage.command == Command.clearMessage)
                      const Text(
                        'Message deleted',
                        style: TextStyle(fontWeight: messageHeaderFontWeight),
                      )
                    else
                      const Text(
                        'Permanently banned',
                        style: TextStyle(fontWeight: messageHeaderFontWeight),
                      )
                  else
                    Text(
                      'Timed out for $banDuration ${int.parse(banDuration) > 1 ? 'seconds' : 'second'}',
                      style: const TextStyle(
                        fontWeight: messageHeaderFontWeight,
                      ),
                    ),
                  Text.rich(
                    TextSpan(
                      children: ircMessage.generateSpan(
                        context,
                        onTapName: () => onTapName(context),
                        style: defaultTextStyle,
                        assetsStore: chatStore.assetsStore,
                        emoteScale: chatStore.settings.emoteScale,
                        badgeScale: chatStore.settings.badgeScale,
                        animateEmotes: chatStore.settings.animateEmotes,
                        showGifs: chatStore.settings.showGifs,
                        animateGifs: chatStore.settings.animateGifs,
                        showMessage:
                            chatStore.settings.showDeletedMessages ||
                            chatStore.revealedMessageIds.contains(
                              ircMessage.tags['id'],
                            ),
                        onTapDeletedMessage: () {
                          if (ircMessage.tags['id'] != null) {
                            chatStore.revealMessage(ircMessage.tags['id']!);
                          }
                        },
                        launchExternal: chatStore.settings.launchUrlExternal,
                        timestamp: chatStore.settings.timestampType,
                        channelIdToUserTwitch:
                            overrideChannelIdToUserTwitch ??
                            chatStore.assetsStore.channelIdToUserTwitch,
                        currentChannelId:
                            overrideCurrentChannelId ?? chatStore.channelId,
                        chatFilters: _chatFilters,
                        onTapFiltered: () => _onTapFiltered(context),
                      ),
                    ),
                  ),
                ],
              ),
            );
            break;
          case Command.notice:
            // Les notices portent des comptes a rebours : chasse fixe.
            final noticeStyle = context.frostyText.metadata;
            if (ircMessage.actionCallback != null &&
                ircMessage.actionLabel != null) {
              renderMessage = Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: ircMessage.message ?? '',
                      style: noticeStyle,
                    ),
                    TextSpan(text: ' '),
                    TextSpan(
                      text: ircMessage.actionLabel!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: Theme.of(context).colorScheme.primary,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = ircMessage.actionCallback,
                    ),
                  ],
                ),
              );
            } else {
              renderMessage = Text.rich(
                TextSpan(text: ircMessage.message),
                style: noticeStyle,
              );
            }
            break;
          case Command.userNotice:
            if (!chatStore.settings.showUserNotices) {
              renderMessage = const SizedBox();
            } else if (_isNoticeRow) {
              isNoticeRow = true;
              renderMessage = _noticeRow(context, defaultTextStyle);
            } else {
              // An announcement carries its text in the IRC body, not in
              // system-msg, and picks its own colour.
              final announcementColor = _announcementColor(
                context,
                ircMessage.notice?.announcementColor,
              );
              highlightColor = announcementColor;

              renderMessage = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Icon(
                        Icons.campaign_rounded,
                        size: messageHeaderIconSize,
                        color: announcementColor,
                      ),
                      Expanded(
                        child: Text(
                          'Announcement',
                          style: TextStyle(
                            fontWeight: messageHeaderFontWeight,
                            color: announcementColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (ircMessage.message != null)
                    _userMessage(context, defaultTextStyle),
                ],
              );
            }
            break;
          default:
            renderMessage = const SizedBox();
        }

        // Check if this is a reply message in reply thread context for indentation
        final isReplyInThread =
            isInReplyThread &&
            ircMessage.tags['reply-parent-display-name'] != null &&
            ircMessage.tags['reply-parent-msg-body'] != null;

        // Add reply icon for messages in reply thread
        final messageWithIcon = isReplyInThread
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0, top: 2.0),
                    child: Icon(
                      Icons.subdirectory_arrow_right_rounded,
                      size: 16,
                      color: messageHeaderTextColor,
                    ),
                  ),
                  Expanded(child: renderMessage),
                ],
              )
            : renderMessage;

        final paddedMessage = Padding(
          padding: EdgeInsets.only(
            top: chatStore.settings.messageSpacing / 2,
            bottom: chatStore.settings.messageSpacing / 2,
            left: isReplyInThread
                ? 16
                : (highlightColor == null && !isNoticeRow ? 12 : 0),
            right: highlightColor == null && !isNoticeRow ? 12 : 0,
          ),
          child: messageWithIcon,
        );

        // Add a divider above the message if dividers are enabled.
        final dividedMessage = chatStore.settings.showChatMessageDividers
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [paddedMessage, const Divider()],
              )
            : paddedMessage;

        // Color the message if the color has been set.
        final coloredMessage = highlightColor == null
            ? dividedMessage
            : Container(
                padding: const EdgeInsets.only(left: 8, right: 12),
                decoration: BoxDecoration(
                  color: highlightColor.withValues(alpha: 0.1),
                  border: Border(
                    left: BorderSide(color: highlightColor, width: 4),
                  ),
                ),
                child: dividedMessage,
              );

        final hasOptions =
            ircMessage.command == Command.privateMessage ||
            ircMessage.command == Command.userState;
        final finalMessage = Semantics(
          onLongPressHint: hasOptions ? 'message options' : 'copy message',
          child: InkWell(
            onTap: () {
              FocusScope.of(context).unfocus();
              if (_effectiveInputStore.assetsStore.showEmoteMenu) {
                _effectiveInputStore.assetsStore.showEmoteMenu = false;
              }
            },
            onLongPress: () => onLongPressMessage(context, defaultTextStyle),
            child: coloredMessage,
          ),
        );

        return finalMessage;
      },
    );
  }

  /// The viewer's own message under a notice, drawn as an ordinary chat line.
  Widget _userMessage(
    BuildContext context,
    TextStyle defaultTextStyle, {
    bool showMessage = true,
    VoidCallback? onTapDeletedMessage,
  }) => Text.rich(
    TextSpan(
      children: ircMessage.generateSpan(
        context,
        onTapName: () => onTapName(context),
        style: defaultTextStyle,
        assetsStore: chatStore.assetsStore,
        emoteScale: chatStore.settings.emoteScale,
        badgeScale: chatStore.settings.badgeScale,
        animateEmotes: chatStore.settings.animateEmotes,
        showGifs: chatStore.settings.showGifs,
        animateGifs: chatStore.settings.animateGifs,
        showMessage: showMessage,
        onTapDeletedMessage: onTapDeletedMessage,
        launchExternal: chatStore.settings.launchUrlExternal,
        timestamp: chatStore.settings.timestampType,
        channelIdToUserTwitch: _channelProfiles,
        currentChannelId: overrideCurrentChannelId ?? chatStore.channelId,
      ),
    ),
  );

  /// A sub, gift or other notice, drawn as Twitch's notice row. With
  /// [showMessage] false the viewer's message is replaced by the tappable
  /// deleted-message placeholder.
  Widget _noticeRow(
    BuildContext context,
    TextStyle defaultTextStyle, {
    bool showMessage = true,
  }) {
    final notice = ircMessage.notice!;
    final presentation = noticePresentation(notice);
    final source = notice.sourceRoomId;

    return UserNoticeRow(
      segments: ircMessage.noticeText(channelName: _noticeChannelName),
      presentation: presentation,
      userMessage: ircMessage.message == null
          ? null
          : _userMessage(
              context,
              defaultTextStyle,
              showMessage: showMessage,
              onTapDeletedMessage: () {
                final id = ircMessage.tags['id'];
                if (id != null) chatStore.revealMessage(id);
              },
            ),
      avatarUrl: switch (presentation.icon) {
        NoticeGlyph.sharedChat =>
          source == null ? null : _channelProfiles[source]?.profileImageUrl,
        NoticeGlyph.raider => notice.raiderAvatarUrl,
        _ => null,
      },
      // A sponsored bonus sub is branded by its advertiser.
      accentColor: notice.sponsorColor,
      goalCurrent: notice.goalCurrentContributions,
      goalTarget: notice.goalTargetContributions,
      overlay: OverlayChatScope.of(context),
    );
  }

  /// The colour a moderator picked for an announcement.
  ///
  /// `PRIMARY` means "no colour chosen", so it follows the accent instead of
  /// inventing one. The other four are Twitch's own fixed palette and are kept
  /// recognisable rather than remapped onto the app's tokens — a green
  /// announcement has to read as green.
  static Color _announcementColor(BuildContext context, AnnouncementColor? c) =>
      switch (c) {
        AnnouncementColor.blue => const Color(0xFF3B8BFF),
        AnnouncementColor.green => const Color(0xFF2FCE6E),
        AnnouncementColor.orange => const Color(0xFFFF9147),
        AnnouncementColor.purple => const Color(0xFFB15CFF),
        AnnouncementColor.primary || null => context.frostyColors.live,
      };
}
