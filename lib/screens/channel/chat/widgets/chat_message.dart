import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/constants.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/models/user.dart';
import 'package:onset/models/user_notice.dart';
import 'package:onset/models/user_notice_presentation.dart';
import 'package:onset/screens/channel/chat/chat_commands.dart';
import 'package:onset/screens/channel/chat/chat_filters.dart';
import 'package:onset/screens/channel/chat/moderation_notice.dart';
import 'package:onset/screens/channel/chat/stores/chat_store.dart';
import 'package:onset/screens/channel/chat/widgets/chat_link_card.dart';
import 'package:onset/screens/channel/chat/widgets/chat_user_modal.dart';
import 'package:onset/screens/channel/chat/widgets/filtered_message_sheet.dart';
import 'package:onset/screens/channel/chat/widgets/gift_bomb_recipients.dart';
import 'package:onset/screens/channel/chat/widgets/overlay_chat_scope.dart';
import 'package:onset/screens/channel/chat/widgets/power_up_frame.dart';
import 'package:onset/screens/channel/chat/widgets/raid_welcome_card.dart';
import 'package:onset/screens/channel/chat/widgets/reply_thread.dart';
import 'package:onset/screens/channel/chat/widgets/user_notice_row.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/utils/twitch_report.dart';
import 'package:onset/widgets/sheet/onset_panel.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';
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

    // A line with no user id (a sender not known any more, or one the
    // chat's history did not identify) has no card to open.
    final userId = ircMessage.tags['user-id'];
    if (userId == null) return;

    showChatUserCard(
      context,
      chatStore: chatStore,
      username: ircMessage.user!,
      userId: userId,
      displayName: ircMessage.tags['display-name'] ?? ircMessage.user!,
      // A tablet's card opens beside the tapped message.
      anchor: globalRectOf(context),
    );
  }

  void onTapPingedUser(BuildContext context, {required String nickname}) {
    // Ignore if the message is a recent message in the modal bottom sheet.
    if (isModal) return;

    final twitchApi = context.read<TwitchApi>();
    twitchApi.getUser(userLogin: nickname).then((user) {
      if (context.mounted) {
        showChatUserCard(
          context,
          chatStore: chatStore,
          username: user.login,
          userId: user.id,
          displayName: user.displayName,
          anchor: globalRectOf(context),
        );
      }
    });
  }

  /// The store to use for notifications and emote menu in merged mode.
  ChatStore get _effectiveInputStore => inputChatStore ?? chatStore;

  Future<void> copyMessage() async {
    await Clipboard.setData(ClipboardData(text: ircMessage.message ?? ''));

    _effectiveInputStore.updateNotification(L10n.current.chatMessageCopied);
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

  String? get _cheerSourceChannel {
    if (ircMessage.tags['bits'] == null) return null;
    final source = ircMessage.tags['source-room-id'];
    final room =
        ircMessage.tags['room-id'] ??
        overrideCurrentChannelId ??
        chatStore.channelId;
    if (source == null || source == room) return null;
    return _channelProfiles[source]?.displayName;
  }

  /// Copies what a notice row shows: its sentence, then the viewer's message.
  Future<void> copyNotice() async {
    final sentence = ircMessage
        .noticeText(
          channelName: _noticeChannelName,
          showGiftCount: !chatStore.settings.hideGiftCount,
        )
        .map((segment) => segment.text)
        .join();
    final text = [
      if (sentence.isNotEmpty) sentence,
      if (ircMessage.message != null && !_isMessageHidden) ircMessage.message!,
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));

    _effectiveInputStore.updateNotification(L10n.current.chatMessageCopied);
  }

  bool get _canPin {
    final source = ircMessage.tags['source-room-id'];
    return chatStore.canPinMessages &&
        ircMessage.command == Command.privateMessage &&
        ircMessage.tags['id'] != null &&
        (source == null || source == chatStore.channelId);
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
    final show = await showOnsetSheet<bool>(
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

    // The message in a card, then what can be
    // done with it.
    final outerContext = context;
    showOnsetSheet<void>(
      context: context,
      builder: (context) {
        final colors = SheetColors.of(context);
        return ListView(
          shrinkWrap: true,
          primary: false,
          padding: const EdgeInsets.only(bottom: 14),
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: colors.well,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colors.hairline,
                  width: OnsetTokens.hairlineWidth,
                ),
              ),
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

                    nameContrast: chatStore.settings.nameColorContrast,
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
            SheetRow(
              glyph: SheetGlyphKind.copy,
              label: context.l10n.chatCopyMessage,
              onTap: () {
                copyMessage();
                Navigator.pop(context);
              },
            ),
            SheetRow(
              glyph: SheetGlyphKind.paste,
              label: context.l10n.chatCopyMessageAndPaste,
              onTap: () async {
                await copyMessage();

                // A message delay only holds what others send; typing stays
                // open (the composer shows the delay), so pasting does too.
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
            ),
            SheetRow(
              glyph: SheetGlyphKind.reply,
              label: context.l10n.chatReplyToMessage,
              onTap: () {
                // In merged mode, switch to the source tab so the reply
                // targets the correct channel (reply-parent-msg-id is
                // channel-scoped).
                onActivateSourceTab?.call();

                chatStore.replyingToMessage = ircMessage;
                chatStore.safeRequestFocus();
                Navigator.pop(context);
              },
            ),
            if (twitchReportUri(ircMessage.user ?? '') case final url?)
              SheetRow(
                key: const ValueKey('report-message'),
                glyph: SheetGlyphKind.flag,
                label: context.l10n.chatReportMessage,
                end: SheetRowEnd.external,
                onTap: () {
                  Navigator.pop(context);
                  openTwitchReport(
                    outerContext,
                    title: outerContext.l10n.chatReportMessage,
                    url: url,
                  );
                },
              ),
            if (_canPin)
              SheetRow(
                key: const ValueKey('pin-message'),
                glyph: SheetGlyphKind.pin,
                label: context.l10n.chatPinMessage,
                onTap: () {
                  Navigator.pop(context);
                  chatStore.pinMessage(ircMessage.tags['id']!);
                },
              ),
            if (_canDelete)
              SheetRow(
                glyph: SheetGlyphKind.trash,
                label: context.l10n.chatDeleteMessage,
                danger: true,
                onTap: () {
                  Navigator.pop(context);
                  chatStore.moderate(
                    DeleteMessageCommand(ircMessage.tags['id']!),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final defaultTextStyle = DefaultTextStyle.of(context).style;
    final messageHeaderTextColor = context.onsetColors.metadata;
    const messageHeaderFontWeight = FontWeight.w600;

    return Observer(
      builder: (context) {
        // Read in the Observer: a change of the setting redraws the row.
        final messageHeaderIconSize =
            defaultBadgeSize * chatStore.settings.badgeScale;
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
                chatStore.settings.showsNoticesIn(chatStore.channelId) &&
                ircMessage.tags['msg-id'] == 'highlighted-message';
            final redemptionHeader =
                chatStore.settings.showsNoticesIn(chatStore.channelId)
                ? switch (ircMessage.tags['msg-id']) {
                    'skip-subs-mode-message' =>
                      context.l10n.chatSubsOnlyRedemption,
                    'animated-message' => context.l10n.chatAnimatedMessage,
                    'gigantified-emote-message' =>
                      context.l10n.chatGigantifiedEmote,
                    _ => null,
                  }
                : null;
            final cheerChannel = _cheerSourceChannel;

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

                  nameContrast: chatStore.settings.nameColorContrast,
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
                    : () => showOnsetSheet<void>(
                        context: context,
                        isScrollControlled: false,
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
              highlightColor = context.onsetColors.highlightedMessage;
              messageHeaderIcon = Icon(
                Icons.auto_awesome_rounded,
                size: messageHeaderIconSize,
                color: messageHeaderTextColor,
              );
              messageHeader = Text(
                context.l10n.chatFirstMessage,
                style: TextStyle(
                  fontWeight: messageHeaderFontWeight,
                  color: messageHeaderTextColor,
                ),
              );
            } else if (cheerChannel != null) {
              messageHeaderIcon = Icon(
                Icons.diamond_outlined,
                size: messageHeaderIconSize,
                color: messageHeaderTextColor,
              );
              messageHeader = Text(
                context.l10n.chatCheeredIn(channel: cheerChannel),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: messageHeaderFontWeight,
                  color: messageHeaderTextColor,
                ),
              );
            } else if (shouldHighlightMessage) {
              highlightColor = context.onsetColors.highlightedMessage;
              messageHeader = Text(
                context.l10n.chatHighlightedMessage,
                style: TextStyle(
                  fontWeight: messageHeaderFontWeight,
                  color: messageHeaderTextColor,
                ),
              );
            } else if (redemptionHeader != null) {
              highlightColor = context.onsetColors.highlightedMessage;
              messageHeader = Text(
                redemptionHeader,
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
              if (chatStore.settings.showsNoticesIn(chatStore.channelId)) {
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
                      Text(
                        context.l10n.chatMessageDeleted,
                        style: const TextStyle(
                          fontWeight: messageHeaderFontWeight,
                        ),
                      )
                    else
                      Text(
                        context.l10n.chatPermanentlyBanned,
                        style: const TextStyle(
                          fontWeight: messageHeaderFontWeight,
                        ),
                      )
                  else
                    Text(
                      timedOutLabel(int.parse(banDuration), context.l10n),
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

                        nameContrast: chatStore.settings.nameColorContrast,
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
            final noticeStyle = context.onsetText.metadata;
            if (ircMessage.raidArrival case final arrival?) {
              // The welcome of a raid the viewer followed: its own card.
              isNoticeRow = true;
              final sent = int.tryParse(ircMessage.tags['tmi-sent-ts'] ?? '');
              renderMessage = RaidWelcomeCard(
                arrival: arrival,
                shownAt: sent == null
                    ? null
                    : DateTime.fromMillisecondsSinceEpoch(sent),
              );
            } else if (ircMessage.actionCallback != null &&
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
            if (!chatStore.settings.showsNoticesIn(chatStore.channelId)) {
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
                          context.l10n.chatAnnouncement,
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

        final animatedPowerUp =
            chatStore.settings.showsNoticesIn(chatStore.channelId) &&
            ircMessage.mention != true &&
            ircMessage.tags['msg-id'] == 'animated-message' &&
            (ircMessage.command == Command.privateMessage ||
                ircMessage.command == Command.userState);

        // Color the message if the color has been set.
        final coloredMessage = animatedPowerUp
            ? PowerUpMessageFrame(
                animationId: ircMessage.tags['animation-id'],
                child: dividedMessage,
              )
            : highlightColor == null
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
          onLongPressHint: hasOptions
              ? context.l10n.chatMessageOptionsHint
              : context.l10n.chatCopyMessageHint,
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

        nameContrast: chatStore.settings.nameColorContrast,
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
      segments: ircMessage.noticeText(
        channelName: _noticeChannelName,
        l: context.l10n,
        showGiftCount: !chatStore.settings.hideGiftCount,
      ),
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
      footer: _giftBombFooter(notice),
      bubble: chatStore.settings.chatBubbleEvents.contains(
        chatBubbleEventOf(notice).name,
      ),
    );
  }

  /// "N recipients ▾" under the header of a gift bomb whose gifts are
  /// folded into it ("Collapse gift bombs", five gifts or more).
  Widget? _giftBombFooter(UserNotice notice) {
    if (!notice.isMassGiftHeader) return null;
    final key = notice.giftBombKey;
    if (key == null) return null;
    final live = chatStore.watchGiftBomb(key);
    if (live == null || !live.value.collapsed) return null;
    return GiftBombRecipients(
      key: ValueKey('gift-bomb-recipients-$key'),
      live: live,
      initiallyExpanded: chatStore.expandedGiftBombs.contains(key),
      onExpandedChanged: (expanded) =>
          chatStore.setGiftBombExpanded(key, expanded),
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
        AnnouncementColor.primary || null => context.onsetColors.live,
      };
}
