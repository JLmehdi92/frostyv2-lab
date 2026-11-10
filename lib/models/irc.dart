import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:onset/apis/twitch_community_service.dart';
import 'package:onset/constants.dart';
import 'package:onset/l10n/enum_labels.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/badges.dart';
import 'package:onset/models/chat_gif.dart';
import 'package:onset/models/cheermote.dart';
import 'package:onset/models/emote_traits.dart';
import 'package:onset/models/emotes.dart';
import 'package:onset/models/raid_arrival.dart';
import 'package:onset/models/report.dart';
import 'package:onset/models/user.dart';
import 'package:onset/models/user_notice.dart';
import 'package:onset/models/user_notice_text.dart';
import 'package:onset/screens/channel/chat/chat_filters.dart';
import 'package:onset/screens/channel/chat/stores/chat_assets_store.dart';
import 'package:onset/screens/channel/chat/widgets/chat_gif_image.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/services/cache_manager.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/common_utils.dart' as utils;
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/utils/link_router.dart';
import 'package:onset/utils/twitch_report.dart';
import 'package:onset/widgets/onset_cached_network_image.dart';
import 'package:onset/widgets/onset_photo_view_dialog.dart';
import 'package:onset/widgets/report/report_sheet.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';
import 'package:provider/provider.dart';

// Constants for IRC message rendering
const String _ircActionPrefix = '\x01';
const String _ircActionSuffix = '\x01';
const int _ircActionPrefixLength = 8;
const String _invalidUnicodeChar = '\u{E0000}';
const String _twitchEmoteBaseUrl = 'https://static-cdn.jtvnw.net/emoticons/v2';
const String _twitchIrcServer = 'tmi.twitch.tv';
const String _emoteModeSuffix = '/default/dark/3.0';
const String _staticEmoteSuffix = '/static/dark/3.0';
const double _emojiSizeOffset = 5.0;

/// The login of a line's sender who is not known any more (a deleted
/// account in a VOD's replay or the chat's history), with
/// [kDeletedUserDisplayName] as its display name.
const kDeletedUserLogin = 'deleted_user';

/// The display name of a line's sender who is not known any more: data, as
/// the chat always had it (a reply to the line quotes it, and its mention
/// too), shown in the language on screen ([IRCMessage.shownDisplayName]).
/// No Twitch display name has a space: it is never a real account's.
const kDeletedUserDisplayName = 'Deleted user';

/// The object representation of a Twitch IRC message.
class IRCMessage {
  final String raw;
  Command command;
  final Map<String, String> tags;
  final String? user;
  final Map<String, Emote>? localEmotes;
  String? message;
  List<String>? split;
  bool? action;
  bool? mention;
  final VoidCallback? actionCallback;
  final String? actionLabel;

  /// The welcome card of a raid the viewer followed here (a line of
  /// ONSET's own, never from Twitch).
  final RaidArrival? raidArrival;

  /// The message cut around its GIFs (`gifs` tag), or empty when it has
  /// none. The cut is made on the text as sent, so [message] and [split]
  /// still hold every word, GIF titles included.
  final List<GifMessagePart> gifParts;

  /// The text as sent (after a `/me` prefix), before [message] is tidied:
  /// the `flags` positions count in it. Null for messages ONSET makes.
  final String? textAsSent;

  /// AutoMod's ratings of the text (its `flags` tag).
  late final List<AutoModFlag> autoModFlags = parseAutoModFlags(tags['flags']);

  ChatFilterSettings? _filteredFor;
  _FilteredWords? _filtered;

  /// The words shown while [settings] hide part of the message, in step
  /// with [split] and [gifParts], or null when they hide nothing.
  _FilteredWords? _filteredWords(ChatFilterSettings settings) {
    final text = textAsSent;
    if (text == null || autoModFlags.isEmpty || !settings.enabled) return null;
    if (_filteredFor == settings) return _filtered;
    _filteredFor = settings;
    final masked = maskFilteredText(text, autoModFlags, settings);
    if (masked == null) return _filtered = null;
    final (text: maskedText, :mark) = masked;
    var offset = 0;
    final parts = <_ShownWords?>[];
    for (final (index, part) in gifParts.indexed) {
      final end = offset + part.text.length;
      parts.add(
        part.gif == null && end <= maskedText.length
            ? _hideWords(
                _gifPartsShown[index].words,
                _splitWords(_normalizeText(maskedText.substring(offset, end))),
                mark,
              )
            : null,
      );
      offset = end;
    }
    final shown = _hideWords(
      split ?? const [],
      _splitWords(_normalizeText(maskedText)),
      mark,
    );
    final anyHidden =
        shown.hidden.isNotEmpty ||
        parts.any((p) => p?.hidden.isNotEmpty ?? false);
    if (!anyHidden) return _filtered = null;
    return _filtered = _FilteredWords(split: shown, gifParts: parts);
  }

  /// The [masked] words as shown: a word holding [mark] has those units as
  /// `*` and is hidden, unless it is one of the message's Twitch emotes (it
  /// stays the emote, as in the official app). [mark] never occurs in the
  /// text sent, so the other words are the chatter's own.
  _ShownWords _hideWords(
    List<String> original,
    List<String> masked,
    String mark,
  ) {
    final aligned = original.length == masked.length;
    final words = <String>[];
    final hidden = <int>{};
    for (final (i, word) in masked.indexed) {
      if (!word.contains(mark)) {
        words.add(word);
      } else if (aligned && (localEmotes?.containsKey(original[i]) ?? false)) {
        words.add(original[i]);
      } else {
        words.add(word.replaceAll(mark, '*'));
        hidden.add(i);
      }
    }
    return (words: words, hidden: hidden);
  }

  /// Whether [settings] hide part of this message.
  bool isFiltered(ChatFilterSettings settings) =>
      _filteredWords(settings) != null;

  /// The text as shown under [filters]: [message] without the words they
  /// hide (what a link preview may read), or [message] itself.
  String? shownText(ChatFilterSettings? filters) {
    final filtered = filters == null ? null : _filteredWords(filters);
    if (filtered == null) return message;
    final (:words, :hidden) = filtered.split;
    return [
      for (final (i, word) in words.indexed)
        if (!hidden.contains(i)) word,
    ].join(' ');
  }

  /// Whether the line was built for a sender who is not known any more
  /// ([kDeletedUserLogin] and [kDeletedUserDisplayName], with no user id):
  /// its name is worded where it shows ([shownDisplayName]).
  bool get isFromDeletedUser =>
      user == kDeletedUserLogin &&
      tags['display-name'] == kDeletedUserDisplayName &&
      tags['user-id'] == null;

  /// The sender's name as a viewer reads it, in [l]'s language: the display
  /// name, or « Utilisateur supprimé » / "Deleted user" for a sender not
  /// known any more ([isFromDeletedUser]).
  String? shownDisplayName(AppLocalizations l) =>
      isFromDeletedUser ? l.chatDeletedUser : tags['display-name'];

  /// Whether this message is a `USERNOTICE`, even after a deletion or a ban
  /// of its author has changed its [command] to [Command.clearMessage] or
  /// [Command.clearChat].
  bool get isUserNotice =>
      command == Command.userNotice ||
      tags.containsKey('system-msg') ||
      _rawCommand(raw) == 'USERNOTICE';

  /// The IRC command of a raw line: the word after the tags and the prefix.
  static String? _rawCommand(String raw) {
    var rest = raw;
    if (rest.startsWith('@')) {
      final end = rest.indexOf(' ');
      if (end < 0) return null;
      rest = rest.substring(end + 1);
    }
    final words = rest.split(' ');
    if (words.length < 2) return null;
    return words[0].startsWith(':') ? words[1] : words[0];
  }

  /// The parsed `USERNOTICE`, or null for any other message.
  ///
  /// Parsed on first use and kept, so a notice row costs one parse however
  /// often the chat list rebuilds it.
  late final UserNotice? notice = isUserNotice
      ? UserNotice.fromTags(tags)
      : null;

  List<NoticeSegment>? _noticeText;
  String? _noticeTextChannel;
  String? _noticeTextLanguage;
  bool? _noticeTextShowsGiftCount;

  /// The notice's sentence in [l]'s language (the one on screen by
  /// default), worded on first use and kept for as long as [channelName]
  /// and the language stay the same. [channelName] is the display name of
  /// the channel a gift bomb is aimed at, which for a shared-chat partner is
  /// only known once its profile has loaded.
  List<NoticeSegment> noticeText({
    required String channelName,
    AppLocalizations? l,
    bool showGiftCount = true,
  }) {
    final notice = this.notice;
    if (notice == null) return const [];
    final words = l ?? L10n.current;
    if (_noticeText == null ||
        _noticeTextChannel != channelName ||
        _noticeTextLanguage != words.localeName ||
        _noticeTextShowsGiftCount != showGiftCount) {
      _noticeText = userNoticeText(
        notice,
        channelName: channelName,
        l: words,
        showGiftCount: showGiftCount,
      );
      _noticeTextChannel = channelName;
      _noticeTextLanguage = words.localeName;
      _noticeTextShowsGiftCount = showGiftCount;
    }
    return _noticeText!;
  }

  IRCMessage({
    required this.raw,
    required this.command,
    required this.tags,
    this.user,
    this.localEmotes,
    this.message,
    this.split,
    this.action,
    this.mention,
    this.actionCallback,
    this.actionLabel,
    this.gifParts = const [],
    this.textAsSent,
    this.raidArrival,
  });

  /// Applies the given CLEARCHAT message to the provided messages and buffer.
  ///
  /// Returns whether a line of [messages] was marked in place (its command
  /// or its timeout changed), which nothing observable reports: a cleared
  /// chat goes through the list's own operations and returns false, as does
  /// a timeout of someone with no line, or one repeated.
  static bool clearChat({
    required List<IRCMessage> messages,
    required List<IRCMessage> bufferedMessages,
    required IRCMessage ircMessage,
  }) {
    // If there is no message, it means that entire chat was cleared.
    if (ircMessage.message == null) {
      messages.clear();
      bufferedMessages.clear();
      messages.add(
        IRCMessage.createNotice(message: L10n.current.chatClearedByModerator),
      );
      return false;
    }

    final bannedUser = ircMessage.message;
    final banDuration = ircMessage.tags['ban-duration'];
    var marked = false;

    // Search the messages for the banned/timed-out user.
    messages.asMap().forEach((i, message) {
      if (message.user == bannedUser) {
        if (message.command != Command.clearChat ||
            (banDuration != null &&
                message.tags['ban-duration'] != banDuration)) {
          marked = true;
        }

        // Mark the message for removal.
        messages[i].command = Command.clearChat;

        // If timed-out, indicate the duration.
        if (banDuration != null) {
          messages[i].tags['ban-duration'] = banDuration;
        }
      }
    });

    // Search the buffered messages for the banned/timed-out user.
    bufferedMessages.asMap().forEach((i, bufferedMessage) {
      if (bufferedMessage.user == bannedUser) {
        // Mark the message for removal.
        bufferedMessages[i].command = Command.clearChat;

        // If timed-out, indicate the duration.
        if (banDuration != null) {
          bufferedMessages[i].tags['ban-duration'] = banDuration;
        }
      }
    });
    return marked;
  }

  /// Applies the given CLEARMSG message to the provided messages and buffer.
  ///
  /// Returns whether a line of [messages] was marked in place, which
  /// nothing observable reports.
  static bool clearMessage({
    required List<IRCMessage> messages,
    required List<IRCMessage> bufferedMessages,
    required IRCMessage ircMessage,
  }) {
    final targetId = ircMessage.tags['target-msg-id'];
    var marked = false;

    // Search for the message associated with the ID and mark the message for deletion.
    for (var i = 0; i < messages.length; i++) {
      if (messages[i].tags['id'] == targetId) {
        marked = messages[i].command != Command.clearMessage;
        messages[i].command = Command.clearMessage;
        break;
      }
    }

    // Search for the buffered message associated with the ID and mark the message for deletion.
    for (var i = 0; i < bufferedMessages.length; i++) {
      if (bufferedMessages[i].tags['id'] == targetId) {
        bufferedMessages[i].command = Command.clearMessage;
        break;
      }
    }
    return marked;
  }

  /// Adds timestamp to the span if enabled
  void _addTimestamp(
    List<InlineSpan> span,
    TextStyle? style,
    TimestampType timestamp,
    Color metadataColor,
  ) {
    if (timestamp == TimestampType.disabled) return;

    final time =
        tags['tmi-sent-ts'] ?? DateTime.now().millisecondsSinceEpoch.toString();
    final parsedTime = DateTime.fromMillisecondsSinceEpoch(int.parse(time));

    final timeText = timestamp == TimestampType.twentyFour
        ? '${DateFormat.Hm().format(parsedTime)} '
        : '${DateFormat('h:mm').format(parsedTime)} ';

    span.add(
      TextSpan(
        text: timeText,
        // Monospace, like every other number in the app: at a glance the
        // timestamps form a straight column instead of drifting with the
        // width of each digit.
        style: style?.copyWith(
          fontFamily: OnsetTokens.monoFamily,
          color: metadataColor,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  /// Adds historical and channel source badges to the span
  void _addHistoricalAndChannelBadges(
    BuildContext context,
    List<InlineSpan> span,
    double badgeSize,
    Map<String, UserTwitch>? channelIdToUserTwitch,
    String? currentChannelId,
  ) {
    final isHistorical = tags['historical'] == '1';
    if (isHistorical) {
      span.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Tooltip(
            message: context.l10n.chatHistoricalMessage,
            preferBelow: false,
            triggerMode: TooltipTriggerMode.tap,
            child: Icon(
              Icons.history_rounded,
              size: badgeSize,
              color: context.onsetColors.metadata,
            ),
          ),
        ),
      );
      span.add(const TextSpan(text: ' '));
    }

    final sourceChannelId = tags['source-room-id'] ?? tags['room-id'];
    final sourceChannelUser = channelIdToUserTwitch?[sourceChannelId];
    if (sourceChannelUser != null) {
      final isCurrentChannel = sourceChannelId == currentChannelId;

      span.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Tooltip(
            triggerMode: TooltipTriggerMode.tap,
            preferBelow: false,
            message: isCurrentChannel
                ? context.l10n.chatSentFromCurrent(
                    name: sourceChannelUser.displayName,
                  )
                : context.l10n.chatSentFrom(
                    name: sourceChannelUser.displayName,
                  ),
            child: CachedNetworkImage(
              cacheManager: CustomCacheManager.instance,
              imageUrl: sourceChannelUser.profileImageUrl,
              imageBuilder: (context, imageProvider) => Container(
                width: badgeSize,
                height: badgeSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: isCurrentChannel
                      ? Border.all(color: context.onsetColors.live, width: 1.5)
                      : null,
                ),
                child: Container(
                  margin: isCurrentChannel ? const EdgeInsets.all(1.5) : null,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: imageProvider,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              placeholder: (context, url) => Container(
                width: badgeSize,
                height: badgeSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: isCurrentChannel
                      ? Border.all(color: context.onsetColors.live, width: 1.5)
                      : null,
                ),
              ),
            ),
          ),
        ),
      );
      span.add(const TextSpan(text: ' '));
    }
  }

  BadgeOrigin _badgeOrigin(
    Map<String, UserTwitch>? channels,
    String? currentChannelId,
  ) {
    final source = tags['source-room-id'];
    final here = currentChannelId ?? tags['room-id'];
    if (source == null || source == here) {
      return (elsewhere: false, channel: null);
    }
    final user = channels?[source];
    return (
      elsewhere: true,
      channel: user == null
          ? null
          : utils.getReadableName(user.displayName, user.login),
    );
  }

  /// Adds all user badges (Twitch, FFZ, BTTV, 7TV) to the span
  bool _addUserBadges(
    BuildContext context,
    List<InlineSpan> span,
    ChatAssetsStore assetsStore,
    double badgeSize,
    bool launchExternal,
    bool isHistorical,
    BadgeOrigin origin,
  ) {
    var skipBot = false;
    final twitchBadgeToObject = assetsStore.twitchBadgesToObject;
    final ffzUserToBadges = assetsStore.userToFFZBadges;
    final sevenTVUserToBadges = assetsStore.userTo7TVBadges;
    final bttvUserToBadge = assetsStore.userToBTTVBadges;
    final ffzRoomInfo = assetsStore.ffzRoomInfo;

    final ffzUserBadges = ffzUserToBadges[tags['user-id']];
    final twitchBadges = tags['badges']?.split(',');

    // Add Twitch badges
    if (twitchBadges != null) {
      for (final badge in twitchBadges) {
        final badgeInfo = twitchBadgeToObject[badge];
        if (badgeInfo != null) {
          var badgeUrl = badgeInfo.url;

          // Handle custom FFZ mod badge
          if (badgeInfo.name == 'Moderator' &&
              (ffzUserBadges != null || ffzRoomInfo?.modUrls != null)) {
            final botBadge = ffzUserBadges?.firstWhereOrNull(
              (element) => element.name == 'Bot',
            );

            if (botBadge != null) {
              badgeUrl = botBadge.url;
              skipBot = true;
            } else if (ffzRoomInfo?.modUrls != null) {
              badgeUrl =
                  ffzRoomInfo!.modUrls?.url4x ??
                  ffzRoomInfo.modUrls?.url2x ??
                  ffzRoomInfo.modUrls!.url1x;
            }

            final newBadge = ChatBadge(
              name: skipBot
                  ? context.l10n.chatBadgeModeratorBot(
                      moderator: badgeInfo.name,
                    )
                  : badgeInfo.name,
              url: badgeUrl,
              type: BadgeType.twitch,
            );

            span.add(
              _createBadgeSpan(
                context,
                badge: newBadge,
                size: badgeSize,
                backgroundColor: context.onsetColors.subOnly,
                launchExternal: launchExternal,
                explainerKind: twitchBadgeExplainerKind(badge),
                origin: origin,
              ),
            );
            span.add(const TextSpan(text: ' '));
            continue;
          }

          // Handle custom FFZ VIP badge
          if (badgeInfo.name == 'VIP' && ffzRoomInfo?.vipBadge != null) {
            badgeUrl =
                ffzRoomInfo!.vipBadge?.url4x ??
                ffzRoomInfo.vipBadge?.url2x ??
                ffzRoomInfo.vipBadge!.url1x;
          }

          final newBadge = ChatBadge(
            name: badgeInfo.name,
            url: badgeUrl,
            type: BadgeType.twitch,
          );

          span.add(
            _createBadgeSpan(
              context,
              badge: newBadge,
              size: badgeSize,
              launchExternal: launchExternal,
              explainerKind: twitchBadgeExplainerKind(badge),
              origin: origin,
            ),
          );
          span.add(const TextSpan(text: ' '));
        }
      }
    }

    // Add FFZ badges
    if (ffzUserBadges != null) {
      for (final badge in ffzUserBadges) {
        final color = Color(int.parse(badge.color!.replaceFirst('#', '0xFF')));

        if (badge.name == 'Bot') {
          if (!skipBot) {
            final indexToInsert = isHistorical ? 2 : 0;
            span.insert(
              indexToInsert,
              _createBadgeSpan(
                context,
                badge: badge,
                size: badgeSize,
                backgroundColor: color,
                launchExternal: launchExternal,
              ),
            );
            span.insert(indexToInsert + 1, const TextSpan(text: ' '));
          }
        } else {
          span.add(
            _createBadgeSpan(
              context,
              badge: badge,
              size: badgeSize,
              backgroundColor: color,
              launchExternal: launchExternal,
            ),
          );
          span.add(const TextSpan(text: ' '));
        }
      }
    }

    // Add BTTV badges
    final userBTTVBadge = bttvUserToBadge[tags['user-id']];
    if (userBTTVBadge != null) {
      span.add(
        _createBadgeSpan(
          context,
          badge: userBTTVBadge,
          size: badgeSize,
          isSvg: true,
          launchExternal: launchExternal,
        ),
      );
      span.add(const TextSpan(text: ' '));
    }

    // Add 7TV badges
    final user7TVBadges = sevenTVUserToBadges[tags['user-id']];
    if (user7TVBadges != null) {
      for (final badge in user7TVBadges) {
        span.add(
          _createBadgeSpan(
            context,
            badge: badge,
            size: badgeSize,
            launchExternal: launchExternal,
          ),
        );
        span.add(const TextSpan(text: ' '));
      }
    }

    return skipBot;
  }

  /// Adds the username to the span with proper color and styling
  void _addUsername(
    List<InlineSpan> span,
    BuildContext context,
    void Function()? onTapName,
    double? nameContrast,
  ) {
    var color = Color(
      int.parse((tags['color'] ?? '#868686').replaceFirst('#', '0xFF')),
    );

    if (nameContrast != null) {
      color = utils.adjustChatNameColor(
        context,
        color,
        targetContrast: nameContrast,
      );
    }

    final displayName = tags['display-name']!;
    span.add(
      TextSpan(
        text: isFromDeletedUser
            ? shownDisplayName(context.l10n)
            : user != null
            ? utils.getReadableName(displayName, user!)
            : displayName,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
        recognizer: TapGestureRecognizer()..onTap = onTapName,
      ),
    );

    // Add the colon separator between the username and their message
    if (action == false) span.add(const TextSpan(text: ':'));
  }

  /// Adds message content with emotes, emojis and text processing
  void _addMessageContent(
    BuildContext context,
    List<InlineSpan> span,
    Map<String, Emote> emoteToObject,
    double emoteSize,
    double emoteScale,
    bool showMessage,
    bool launchExternal,
    TextStyle? textStyle,
    void Function(String)? onTapPingedUser,
    void Function()? onTapDeletedMessage, {
    Color? linkColor,
    bool animateEmotes = true,
    Cheermotes cheermotes = Cheermotes.empty,
    bool showGifs = true,
    bool animateGifs = true,
    _FilteredWords? filtered,
    VoidCallback? onTapFiltered,
  }) {
    if (!showMessage) {
      span.add(
        TextSpan(
          text: ' ${context.l10n.chatMessageDeletedInline}',
          style: onTapDeletedMessage != null
              ? textStyle?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                )
              : null,
          recognizer: onTapDeletedMessage != null
              ? (TapGestureRecognizer()..onTap = onTapDeletedMessage)
              : null,
        ),
      );
      return;
    }

    void addWords(Iterable<String> words, {Set<int>? hidden, int skip = 0}) {
      _addWords(
        context,
        span,
        words.skip(skip).toList(),
        emoteToObject,
        emoteSize,
        emoteScale,
        launchExternal,
        textStyle,
        onTapPingedUser,
        linkColor: linkColor,
        animateEmotes: animateEmotes,
        cheermotes: cheermotes,
        hidden: hidden == null ? null : {for (final i in hidden) i - skip},
        onTapFiltered: onTapFiltered,
      );
    }

    // A reply starts with the parent's @name, which the reply header shows.
    var skipReplyName = tags.containsKey('reply-parent-display-name');

    if (gifParts.isEmpty) {
      final split = this.split;
      if (split == null) return;
      final shown = filtered?.split;
      addWords(
        shown?.words ?? split,
        hidden: shown?.hidden,
        skip: skipReplyName ? 1 : 0,
      );
      return;
    }

    for (final (index, part) in gifParts.indexed) {
      final (:text, :words) = _gifPartsShown[index];
      final shown = filtered?.gifParts[index];
      final gif = part.gif;
      if (gif == null) {
        addWords(
          shown?.words ?? words,
          hidden: shown?.hidden,
          skip: skipReplyName ? 1 : 0,
        );
        skipReplyName = false;
        continue;
      }
      skipReplyName = false;

      if (!showGifs || !gif.isLoadable) {
        // Twitch draws the title as plain text when GIFs are turned off.
        span.add(TextSpan(text: ' $text', style: textStyle));
        continue;
      }
      final title = text.isEmpty ? 'GIF' : text;
      // Like Twitch, the GIF starts a new line and takes its title's place.
      span
        ..add(const TextSpan(text: '\n'))
        ..add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: ChatGifImage(
              gif: gif,
              title: title,
              animate: animateGifs,
              textStyle: textStyle,
              onTap: () => _showAssetDetailsBottomSheet(
                context,
                leading: ChatGifImage(
                  gif: gif,
                  title: title,
                  animate: animateGifs,
                  height: 56,
                ),
                url: gif.url,
                title: title,
                copyName: title,
                subtitle: const Text('GIF'),
                launchExternal: launchExternal,
              ),
            ),
          ),
        );
    }
  }

  /// Adds [words] to [span], each with the space before it: emotes, cheers,
  /// emojis, mentions, links and text.
  void _addWords(
    BuildContext context,
    List<InlineSpan> span,
    List<String> words,
    Map<String, Emote> emoteToObject,
    double emoteSize,
    double emoteScale,
    bool launchExternal,
    TextStyle? textStyle,
    void Function(String)? onTapPingedUser, {
    Color? linkColor,
    bool animateEmotes = true,
    Cheermotes cheermotes = Cheermotes.empty,
    Set<int>? hidden,
    VoidCallback? onTapFiltered,
  }) {
    // Keep a local span which will be reversed and added to the final span.
    final localSpan = <InlineSpan>[];

    // Cheermotes are drawn only in a cheer, like Twitch ("Cheer100"
    // elsewhere is just text).
    final isCheer = tags['bits'] != null && !cheermotes.isEmpty;
    final dark = Theme.of(context).brightness == Brightness.dark;
    var giantPending = isGigantified;

    // Iterate through the words in reverse-order.
    var index = words.length - 1;

    // Terminate after the first word in the message reached.
    while (index != -1) {
      final word = words[index];
      if (hidden?.contains(index) ?? false) {
        // A word the chat filters hide, drawn as stars like Twitch; a tap
        // asks whether to show the message.
        localSpan
          ..add(
            TextSpan(
              text: word,
              style: textStyle,
              semanticsLabel: context.l10n.chatFilteredWord,
              recognizer: onTapFiltered == null
                  ? null
                  : (TapGestureRecognizer()..onTap = onTapFiltered),
            ),
          )
          ..add(const TextSpan(text: ' '));
        index--;
        continue;
      }
      final cheer = isCheer ? cheermotes.match(word) : null;
      final emote = cheer != null
          ? null
          : emoteToObject[word] ?? localEmotes?[word];

      if (cheer != null) {
        // Reversed order (like the other words): the amount, the image
        // before it, then the space before the cheer.
        localSpan
          ..add(
            TextSpan(
              text: '${cheer.amount}',
              style: (textStyle ?? const TextStyle()).copyWith(
                color: Color(cheer.tier.color),
                fontWeight: FontWeight.bold,
              ),
            ),
          )
          ..add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Semantics(
                label: context.l10n.chatCheerSemantics(
                  prefix: cheer.prefix,
                  count: cheer.amount,
                ),
                child: OnsetCachedNetworkImage(
                  imageUrl: cheer.tier.url(dark: dark, animated: animateEmotes),
                  height: emoteSize,
                  useFade: false,
                  placeholder: (context, url) => const SizedBox(),
                ),
              ),
            ),
          )
          ..add(const TextSpan(text: ' '));
        index--;
      } else if (emote != null) {
        // If the emote is zero-width and not the first word, process the stack.
        if (emote.zeroWidth && index != 0) {
          index = _processZeroWidthEmoteStack(
            context,
            localSpan,
            words,
            index,
            emote,
            emoteToObject,
            emoteSize,
            emoteScale,
            textStyle,
            launchExternal,
            linkColor: linkColor,
            animateEmotes: animateEmotes,
          );
        } else {
          final giant = giantPending;
          giantPending = false;
          final height = emote.height != null
              ? emote.height! * emoteScale
              : emoteSize;
          localSpan.add(
            _createEmoteSpan(
              context,
              emote: emote,
              animate: animateEmotes,
              height: giant ? height * gigantifiedEmoteFactor : height,
              width: emote.width != null
                  ? emote.width! *
                        emoteScale *
                        (giant ? gigantifiedEmoteFactor : 1)
                  : null,
              launchExternal: launchExternal,
            ),
          );
          localSpan.add(const TextSpan(text: ' '));
          index--;
        }
      } else {
        if (regexEmoji.hasMatch(word)) {
          localSpan.add(
            _createEmojiSpan(
              emoji: word,
              style: textStyle?.copyWith(
                fontSize: emoteSize - _emojiSizeOffset,
              ),
            ),
          );
        } else {
          localSpan.add(
            _createTextSpan(
              text: word,
              style: textStyle,
              linkColor: linkColor,
              launchExternal: launchExternal,
              onTapPingedUser: onTapPingedUser,
            ),
          );
        }
        localSpan.add(const TextSpan(text: ' '));
        index--;
      }
    }

    // Add the local span reversed to the final span.
    span.addAll(localSpan.reversed);
  }

  /// The tidied text of each of [gifParts], with the words of a text part:
  /// worked out once, not on every rebuild of the chat line.
  late final List<({String text, List<String> words})> _gifPartsShown = [
    for (final part in gifParts)
      if (_normalizeText(part.text) case final text)
        (text: text, words: part.gif == null ? _splitWords(text) : const []),
  ];

  /// Handles zero-width emote stacking logic and returns updated index
  int _processZeroWidthEmoteStack(
    BuildContext context,
    List<InlineSpan> localSpan,
    List<String> words,
    int startIndex,
    Emote startEmote,
    Map<String, Emote> emoteToObject,
    double emoteSize,
    double emoteScale,
    TextStyle? textStyle,
    bool launchExternal, {
    Color? linkColor,
    bool animateEmotes = true,
  }) {
    final emoteStack = <Emote>[];
    var index = startIndex;

    // Handle stacking consecutive zero-width emotes.
    Emote? nextEmote = startEmote;
    while (nextEmote != null && nextEmote.zeroWidth && index != 0) {
      emoteStack.add(nextEmote);
      index--;
      nextEmote = emoteToObject[words[index]] ?? localEmotes?[words[index]];
    }

    // If there's one more emote that's NOT zero-width, add it to the base of the stack.
    if (nextEmote != null) emoteStack.add(nextEmote);

    // Check if the next word is an emoji to be added to the stack.
    final nextWordIsEmoji = regexEmoji.hasMatch(words[index]);

    // Create the stack of emotes with the base emoji if there is one.
    final children = [
      if (nextWordIsEmoji)
        Text(
          words[index],
          style: textStyle?.copyWith(fontSize: emoteSize - _emojiSizeOffset),
        ),
      ...emoteStack.reversed.map(
        (emote) => OnsetCachedNetworkImage(
          imageUrl: emote.urlFor(animate: animateEmotes),
          height: emote.height != null ? emote.height! * emoteScale : emoteSize,
          width: emote.width != null ? emote.width! * emoteScale : emoteSize,
          useFade: false,
        ),
      ),
    ];

    // Create the message for the tooltip
    final message = emoteStack.reversed.map((emote) => emote.name);
    final emoji = words[index];

    localSpan.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: InkWell(
          onTap: () => _showAssetDetailsBottomSheet(
            context,
            leading: Stack(
              alignment: AlignmentDirectional.center,
              children: [
                if (nextWordIsEmoji)
                  Text(emoji, style: textStyle?.copyWith(fontSize: 40)),
                ...emoteStack.reversed.map(
                  (emote) =>
                      OnsetCachedNetworkImage(imageUrl: emote.url, width: 56),
                ),
              ],
            ),
            url: emoteStack.last.url,
            title: nextWordIsEmoji
                ? emoji
                : '${emoteStack.last.name} '
                      '(${emoteStack.last.type.label(context.l10n)})',
            subtitle: Text(
              context.l10n.chatEmoteStackWith(
                emotes: nextWordIsEmoji
                    ? message.join(' + ')
                    : message.skip(1).join(' + '),
              ),
            ),
            launchExternal: launchExternal,
          ),
          child: Semantics(
            label: [if (nextWordIsEmoji) emoji, ...message].join(' + '),
            excludeSemantics: true,
            child: Stack(
              alignment: AlignmentDirectional.center,
              children: children,
            ),
          ),
        ),
      ),
    );

    // If the next word is neither an emote nor emoji, add it as a text span.
    if (nextEmote == null && !nextWordIsEmoji) {
      localSpan.add(const TextSpan(text: ' '));
      localSpan.add(
        _createTextSpan(
          text: words[index],
          style: textStyle,
          linkColor: linkColor,
          launchExternal: launchExternal,
        ),
      );
    }

    // Add space after the zero-width emote stack (like all other elements)
    localSpan.add(const TextSpan(text: ' '));

    return index - 1;
  }

  bool get isGigantified => tags['msg-id'] == 'gigantified-emote-message';

  static const gigantifiedEmoteFactor = 3.0;

  /// Returns an [InlineSpan] list that corresponds to the badges, username, words, and emotes of the given [IRCMessage].
  List<InlineSpan> generateSpan(
    BuildContext context, {
    TextStyle? style,
    required ChatAssetsStore assetsStore,
    required double badgeScale,
    required double emoteScale,
    required bool launchExternal,
    void Function()? onTapName,
    void Function(String)? onTapPingedUser,
    void Function()? onTapDeletedMessage,
    bool showMessage = true,
    Map<String, UserTwitch>? channelIdToUserTwitch,
    TimestampType timestamp = TimestampType.disabled,
    String? currentChannelId,
    bool animateEmotes = true,
    bool showGifs = true,
    bool animateGifs = true,
    ChatFilterSettings? chatFilters,
    VoidCallback? onTapFiltered,
    double? nameContrast = readableNameColorContrast,
  }) {
    final emoteToObject = assetsStore.emoteToObject;
    final badgeSize = defaultBadgeSize * badgeScale;
    final emoteSize = defaultEmoteSize * emoteScale;
    final linkColor = Theme.of(context).colorScheme.primary;

    // The span list that will be used to render the chat message
    final span = <InlineSpan>[];

    _addTimestamp(span, style, timestamp, context.onsetColors.metadata);
    _addHistoricalAndChannelBadges(
      context,
      span,
      badgeSize,
      channelIdToUserTwitch,
      currentChannelId,
    );

    final isHistorical = tags['historical'] == '1';
    _addUserBadges(
      context,
      span,
      assetsStore,
      badgeSize,
      launchExternal,
      isHistorical,
      _badgeOrigin(channelIdToUserTwitch, currentChannelId),
    );

    _addUsername(span, context, onTapName, nameContrast);

    // Italicize the text if it was called with an IRC Action (e.g., "/me").
    final textStyle = action == true
        ? const TextStyle(fontStyle: FontStyle.italic)
        : style;

    _addMessageContent(
      context,
      span,
      emoteToObject,
      emoteSize,
      emoteScale,
      showMessage,
      launchExternal,
      textStyle,
      onTapPingedUser,
      onTapDeletedMessage,
      linkColor: linkColor,
      animateEmotes: animateEmotes,
      cheermotes: assetsStore.cheermotes,
      showGifs: showGifs,
      animateGifs: animateGifs,
      filtered: chatFilters == null ? null : _filteredWords(chatFilters),
      onTapFiltered: onTapFiltered,
    );

    return span;
  }

  static WidgetSpan _createEmojiSpan({
    required String emoji,
    TextStyle? style,
  }) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Text(emoji, style: style),
    );
  }

  static Widget _createBadgeWidget({
    required ChatBadge badge,
    double? size,
    Color? backgroundColor,
    bool? isSvg,
    String? semanticLabel,
  }) {
    if (backgroundColor != null) {
      return ColoredBox(
        color: backgroundColor,
        child: OnsetCachedNetworkImage(
          imageUrl: badge.url,
          height: size,
          width: size,
          useFade: false,
          semanticLabel: semanticLabel,
        ),
      );
    } else if (isSvg == true) {
      return SvgPicture.network(
        badge.url,
        height: size,
        width: size,
        semanticsLabel: semanticLabel,
        excludeFromSemantics: semanticLabel == null,
      );
    } else {
      return OnsetCachedNetworkImage(
        imageUrl: badge.url,
        height: size,
        width: size,
        useFade: false,
        semanticLabel: semanticLabel,
      );
    }
  }

  static WidgetSpan _createBadgeSpan(
    BuildContext context, {
    required ChatBadge badge,
    required double size,
    required bool launchExternal,
    Color? backgroundColor,
    bool? isSvg,
    String? explainerKind,
    BadgeOrigin origin = (elsewhere: false, channel: null),
  }) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: InkWell(
        onTap: () => _showAssetDetailsBottomSheet(
          context,
          leading: _createBadgeWidget(
            badge: badge,
            backgroundColor: backgroundColor,
            isSvg: isSvg,
            size: 56,
          ),
          url: badge.url,
          title: badge.name,
          subtitle: BadgeDetails(
            badge: badge,
            explainerKind: explainerKind,
            origin: origin,
          ),
          launchExternal: launchExternal,
          showCopyName: false,
        ),
        child: _createBadgeWidget(
          badge: badge,
          size: size,
          backgroundColor: backgroundColor,
          isSvg: isSvg,
          semanticLabel: badge.name,
        ),
      ),
    );
  }

  static WidgetSpan _createEmoteSpan(
    BuildContext context, {
    required Emote emote,
    required double height,
    required double? width,
    required bool launchExternal,
    bool animate = true,
  }) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: InkWell(
        onTap: () => showEmoteDetailsBottomSheet(
          context,
          emote: emote,
          launchExternal: launchExternal,
        ),
        child: OnsetCachedNetworkImage(
          imageUrl: emote.urlFor(animate: animate),
          height: height,
          width: width,
          useFade: false,
          placeholder: (context, url) => const SizedBox(),
          semanticLabel: emote.name,
        ),
      ),
    );
  }

  static TextSpan _createTextSpan({
    required String text,
    required bool launchExternal,
    TextStyle? style,
    Color? linkColor,
    Function(String)? onTapPingedUser,
  }) {
    if (text.startsWith('@')) {
      return TextSpan(
        text: text,
        style: style?.copyWith(fontWeight: FontWeight.bold),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            if (onTapPingedUser != null) {
              onTapPingedUser(text.substring(1).split(',')[0]);
            }
          },
      );
    } else if (regexLink.hasMatch(text)) {
      return TextSpan(
        text: text,
        style: style?.copyWith(
          color: linkColor,
          decoration: TextDecoration.underline,
          decorationColor: linkColor,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () => LinkRouter.open(
            text,
            launchExternal: launchExternal,
            confirm: true,
          ),
      );
    } else {
      return TextSpan(text: text, style: style);
    }
  }

  static void showEmoteDetailsBottomSheet(
    BuildContext context, {
    required Emote emote,
    required bool launchExternal,
    VoidCallback? onRemoveRecent,
    VoidCallback? onSubscribe,
  }) {
    _showAssetDetailsBottomSheet(
      context,
      actions: (context) => [
        if (onSubscribe != null)
          SheetRow(
            glyph: SheetGlyphKind.star,
            label: context.l10n.channelSubscribe,
            detail: context.l10n.chatDetailsOpensTwitch,
            end: SheetRowEnd.external,
            onTap: () {
              Navigator.pop(context);
              onSubscribe();
            },
          ),
        if (emote.type.name.startsWith('twitch') &&
            twitchReportUri(emote.ownerUsername ?? '') != null)
          SheetRow(
            key: const ValueKey('report-emote'),
            glyph: SheetGlyphKind.flag,
            label: context.l10n.chatReportEmote,
            end: SheetRowEnd.external,
            onTap: () {
              final navigator = Navigator.of(context);
              final title = context.l10n.chatReportEmote;
              navigator.pop();
              reportFromOnset(
                navigator.context,
                target: ReportTarget.emote(
                  emoteId: ReportTarget.twitchEmoteId(emote.url) ?? '',
                  ownerId: emote.ownerId ?? '',
                  name: emote.name,
                ),
                title: title,
                fallbackUrl: twitchReportUri(emote.ownerUsername!),
              );
            },
          ),
        if (onRemoveRecent != null)
          SheetRow(
            glyph: SheetGlyphKind.trash,
            label: context.l10n.emoteMenuRemoveRecent,
            onTap: () {
              onRemoveRecent();
              Navigator.pop(context);
            },
          ),
      ],
      leading: OnsetCachedNetworkImage(imageUrl: emote.url, width: 48),
      url: emote.url,
      title: emote.realName != null
          ? '${emote.name} (${emote.realName})'
          : emote.name,
      subtitle: Builder(
        builder: (context) {
          final detail = SheetText.rowDetail.copyWith(
            color: SheetColors.of(context).secondary,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 3,
            children: [
              Text(emote.type.label(context.l10n)),
              if (emote.ownerDisplayName != null && emote.ownerUsername != null)
                Text(
                  context.l10n.chatEmoteBy(
                    name: utils.getReadableName(
                      emote.ownerDisplayName!,
                      emote.ownerUsername!,
                    ),
                  ),
                  style: detail,
                ),
              if (emote.limitedTime)
                Text(context.l10n.emoteLimitedTime, style: detail),
              if (emote.unlockHint(context.l10n) case final hint?)
                Text(hint, style: detail),
              if (emoteModifierOf(emote.url) case final code?)
                Text(context.l10n.emoteModifierLine(code: code), style: detail),
              if (emote.type == EmoteType.twitchBits)
                if (twitchEmoteIdOf(emote.url) case final id?)
                  EmoteBitsThresholdLine(emoteId: id, style: detail),
            ],
          );
        },
      ),
      launchExternal: launchExternal,
    );
  }

  /// An emote's or a badge's details: the
  /// picture in a 64 dp tile (a tap opens it full size), its name and what
  /// it is, then copy and open.
  static void _showAssetDetailsBottomSheet(
    BuildContext context, {
    required Widget leading,
    required String url,
    required String title,
    required Widget subtitle,
    required bool launchExternal,
    bool showCopyName = true,
    String? copyName,
    List<Widget> Function(BuildContext context)? actions,
  }) {
    showOnsetSheet<void>(
      context: context,
      isScrollControlled: false,
      builder: (context) {
        final colors = SheetColors.of(context);
        return ListView(
          shrinkWrap: true,
          primary: false,
          padding: const EdgeInsets.only(bottom: 18),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                spacing: 14,
                children: [
                  Material(
                    color: colors.raised,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: colors.ring,
                        width: OnsetTokens.hairlineWidth,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => showDialog(
                        context: context,
                        // The chat is beside, under or over the video.
                        builder: (context) => OnsetPhotoViewDialog(
                          imageUrl: url,
                          blurBackground: false,
                        ),
                      ),
                      child: SizedBox.square(
                        dimension: 64,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 48,
                              maxHeight: 48,
                            ),
                            child: leading,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 3,
                      children: [
                        Text(
                          title,
                          style: SheetText.title.copyWith(color: colors.text),
                        ),
                        DefaultTextStyle.merge(
                          style: TextStyle(
                            fontFamily: OnsetTokens.bodyFamily,
                            fontSize: 13,
                            height: 1.35,
                            color: colors.body,
                          ),
                          child: subtitle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: OnsetTokens.hairlineWidth,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: colors.hairline,
            ),
            const SizedBox(height: 6),
            ...?actions?.call(context),
            if (showCopyName)
              SheetRow(
                glyph: SheetGlyphKind.copy,
                label: context.l10n.chatCopyName,
                onTap: () {
                  // An emote's title is "name (real name)": only the name.
                  Clipboard.setData(
                    ClipboardData(text: copyName ?? title.split(' (')[0]),
                  );

                  Navigator.pop(context);
                },
              ),
            SheetRow(
              glyph: SheetGlyphKind.link,
              label: context.l10n.chatCopyImageUrl,
              onTap: () {
                Clipboard.setData(ClipboardData(text: url));

                Navigator.pop(context);
              },
            ),
            SheetRow(
              glyph: SheetGlyphKind.external,
              label: context.l10n.chatOpenInBrowser,
              onTap: () {
                // Web links only, like every link the app opens.
                unawaited(LinkRouter.open(url, launchExternal: launchExternal));

                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  /// [text] without the invisible character some clients add and without
  /// empty or doubled spaces.
  static String _normalizeText(String text) => text
      .split(' ')
      // Also remove any "INVALID/UNDEFINED" Unicode characters.
      // Rendering this character on iOS shows a question mark inside a square.
      // This character is used by some clients to bypass restrictions on repeating message.
      .map((word) => word.replaceAll(_invalidUnicodeChar, '').trim())
      .where((element) => element != '')
      .join(' ');

  /// The words of [text] (already normalized), a run of emojis being a word
  /// of its own.
  static List<String> _splitWords(String text) {
    final emojiBuffer = StringBuffer();
    final wordBuffer = StringBuffer();
    final split = <String>[];

    for (final character in text.characters) {
      if (regexEmoji.hasMatch(character)) {
        if (wordBuffer.isNotEmpty) {
          split.addAll(wordBuffer.toString().split(' '));
          wordBuffer.clear();
        }
        emojiBuffer.write(character);
      } else {
        if (emojiBuffer.isNotEmpty) {
          split.add(emojiBuffer.toString());
          emojiBuffer.clear();
        }
        wordBuffer.write(character);
      }
    }

    if (wordBuffer.isNotEmpty) {
      split.addAll(
        wordBuffer.toString().split(' ').where((element) => element != ''),
      );
    }
    if (emojiBuffer.isNotEmpty) split.add(emojiBuffer.toString());
    return split;
  }

  /// The value of tag [key] in [rawTags] as sent, escapes included, or null.
  ///
  /// The tag map is built from a string whose `\s` were all turned into
  /// spaces first, which also hits an escaped backslash followed by `s`: a
  /// value that must come out exact is unescaped from here instead.
  static String? _rawTagValue(String rawTags, String key) {
    final prefix = '$key=';
    for (final tag in rawTags.split(';')) {
      if (tag.startsWith(prefix)) return tag.substring(prefix.length);
    }
    return null;
  }

  /// Parses an IRC string and returns its corresponding [IRCMessage] object.
  factory IRCMessage.fromString(String whole, {String? userLogin}) {
    // We have three parts:
    // 1. The tags of the IRC message.
    // 2. The metadata (user, command, and channel).
    // 3. The message itself.

    // First, slice the message tags (1) and set aside the rest for later.
    // Each part is separated by a space, so we'll start off by breaking off the tags and parsing them.

    // Obtain the index to break off the tags.
    final tagAndIrcMessageDivider = whole.indexOf(' ');

    // Get the tags substring and escape characters.
    // IRC messages escape spaces with \s.
    final rawTags = whole.substring(1, tagAndIrcMessageDivider);
    final tags = rawTags.replaceAll('\\s', ' ');

    // Next, parse and map the tags.
    final mappedTags = <String, String>{};

    // Loop through each tag and store their key value pairs into the map.
    for (final tag in tags.split(';')) {
      // Skip if the tag has no value. Only the first `=` separates the key:
      // a value can hold more (the url of a GIF does).
      final equals = tag.indexOf('=');
      if (equals < 0 || equals == tag.length - 1) continue;

      mappedTags[tag.substring(0, equals)] = tag.substring(equals + 1);
    }

    // Now we'll parse the message itself.
    // Obtain the entire substring after the tags and excluding the first : (colon)
    final ircMessage = whole.substring(tagAndIrcMessageDivider + 2);

    // Split each section of the message (part 2 and its subparts and part 3).
    // Index 0 contains the username of sender (user) or tmi.twitch.tv depending on the command
    // Index 1 is command type
    // Index 2 is #channel name that we are currently connected to
    // Index 3 and beyond is the :message (word by word) that is sent by the user or empty depending on the command
    final splitMessage = ircMessage.split(' ');

    // If the username exists, set it.
    // tmi.twitch.tv means the message was sent by Twitch rather than a user, so will be irrelevant.
    final String? user = splitMessage[0] == _twitchIrcServer
        ? mappedTags['login']
        : splitMessage[0].substring(0, splitMessage[0].indexOf('!'));

    // If there is an associated message, set it.
    String? message;
    if (splitMessage.length > 3) {
      final combinedMessage = splitMessage.sublist(3).join(' ');

      if (combinedMessage.startsWith(':')) {
        message = combinedMessage.substring(1);
      } else {
        message = combinedMessage;
      }
    }

    // Check if IRC actions like "/me" were called. Done before the emotes:
    // their positions count from after the "\x01ACTION " prefix.
    var action = false;
    if (message != null &&
        message.length > _ircActionPrefixLength &&
        message.startsWith(_ircActionPrefix) &&
        message.endsWith(_ircActionSuffix)) {
      action = true;
      message = message.substring(_ircActionPrefixLength, message.length - 1);
    }

    // Now process any Twitch emotes contained in the message tags.
    // The map containing emotes from the user's tags to their URL.
    // This may include sub emotes that they can access but other users cannot.
    final localEmotes = <String, Emote>{};

    final emoteTags = mappedTags['emotes'];
    if (emoteTags != null && message != null) {
      // Emotes and their indices are separated by '/' so split them there.
      final emotes = emoteTags.split('/');

      for (final emoteIdAndPosition in emotes) {
        final indexBetweenIdAndPositions = emoteIdAndPosition.indexOf(':');
        final emoteId = emoteIdAndPosition.substring(
          0,
          indexBetweenIdAndPositions,
        );

        // Parse the range in order to extract the associated word.
        // If there are more than one indices, use the first one.
        // Else, use the one provided indices.
        final String range;
        if (emoteIdAndPosition.contains(',')) {
          range = emoteIdAndPosition.substring(
            indexBetweenIdAndPositions + 1,
            emoteIdAndPosition.indexOf(','),
          );
        } else {
          range = emoteIdAndPosition.substring(indexBetweenIdAndPositions + 1);
        }

        // Extract the word associated with this emoteId by using the provided indices.
        final indexSplit = range.split('-');
        final startIndex = int.parse(indexSplit[0]);
        final endIndex = int.parse(indexSplit[1]);

        final emoteWord = message.substring(startIndex, endIndex + 1);

        // Store the emote word and its associated URL for later use.
        localEmotes[emoteWord] = Emote(
          name: emoteWord,
          zeroWidth: false,
          url: '$_twitchEmoteBaseUrl/$emoteId$_emoteModeSuffix',
          staticUrl: '$_twitchEmoteBaseUrl/$emoteId$_staticEmoteSuffix',
          type: EmoteType.twitchSub,
        );
      }
    }

    var mention = false;
    List<String>? split;
    var gifParts = const <GifMessagePart>[];
    final textAsSent = message;
    if (message != null) {
      // Check if the message mentions the logged-in user
      if (userLogin != null) {
        mention = mentionsUser(message, userLogin);
      }

      // Cut around the GIFs now: their positions count in the text as sent.
      gifParts = GifMessagePart.split(
        message,
        ChatGif.parseTag(UserNotice.unescapeTag(_rawTagValue(rawTags, 'gifs'))),
      );

      message = _normalizeText(message);
      split = _splitWords(message);
    }

    // Check and parse the command.
    // The majority of messages will be PRIVMSG, so check that first.
    final Command messageCommand;
    switch (splitMessage[1]) {
      case 'PRIVMSG':
        messageCommand = Command.privateMessage;
        break;
      case 'CLEARCHAT':
        messageCommand = Command.clearChat;
        break;
      case 'CLEARMSG':
        messageCommand = Command.clearMessage;
        break;
      case 'NOTICE':
        messageCommand = Command.notice;
        break;
      case 'USERNOTICE':
        messageCommand = Command.userNotice;
        break;
      case 'ROOMSTATE':
        messageCommand = Command.roomState;
        break;
      case 'USERSTATE':
        messageCommand = Command.userState;
        break;
      case 'GLOBALUSERSTATE':
        messageCommand = Command.globalUserState;
        break;
      default:
        debugPrint('Unknown command: $splitMessage[1]');
        messageCommand = Command.none;
    }

    return IRCMessage(
      raw: whole,
      command: messageCommand,
      tags: mappedTags,
      user: user,
      localEmotes: localEmotes,
      message: message,
      split: split,
      action: action,
      mention: mention,
      gifParts: gifParts,
      textAsSent: textAsSent,
    );
  }

  /// "You followed X's raid", at the top of the new chat (stamped when it
  /// joins the chat).
  factory IRCMessage.raidWelcome(RaidArrival arrival) => IRCMessage(
    raw: '',
    tags: {'tmi-sent-ts': '${DateTime.now().millisecondsSinceEpoch}'},
    command: Command.notice,
    message: L10n.current.chatRaidWelcomeFrom(name: arrival.fromName),
    raidArrival: arrival,
  );

  factory IRCMessage.createNotice({
    required String message,
    VoidCallback? actionCallback,
    String? actionLabel,
  }) => IRCMessage(
    raw: '',
    tags: {'tmi-sent-ts': '${DateTime.now().millisecondsSinceEpoch}'},
    command: Command.notice,
    message: message,
    actionCallback: actionCallback,
    actionLabel: actionLabel,
  );
}

class BadgeDetails extends StatelessWidget {
  const BadgeDetails({
    super.key,
    required this.badge,
    this.explainerKind,
    this.origin = (elsewhere: false, channel: null),
  });

  final ChatBadge badge;
  final String? explainerKind;
  final BadgeOrigin origin;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final explainer = badgeExplainerText(l, explainerKind, origin);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 3,
      children: [
        Text(badge.type.label(l)),
        if (explainer != null)
          Text(
            explainer,
            style: SheetText.rowDetail.copyWith(
              color: SheetColors.of(context).secondary,
            ),
          ),
      ],
    );
  }
}

/// The object representation of the IRC ROOMSTATE message.
class ROOMSTATE {
  final String emoteOnly;
  final String followersOnly;
  final String r9k;
  final String slowMode;
  final String subMode;

  const ROOMSTATE({
    this.emoteOnly = '0',
    this.followersOnly = '-1',
    this.r9k = '0',
    this.slowMode = '0',
    this.subMode = '0',
  });

  /// Create a new copy with the parameters from the provided [IRCMessage]
  ROOMSTATE fromIRCMessage(IRCMessage ircMessage) => ROOMSTATE(
    emoteOnly: ircMessage.tags['emote-only'] ?? emoteOnly,
    followersOnly: ircMessage.tags['followers-only'] ?? followersOnly,
    r9k: ircMessage.tags['r9k'] ?? r9k,
    slowMode: ircMessage.tags['slow'] ?? slowMode,
    subMode: ircMessage.tags['subs-only'] ?? subMode,
  );
}

class USERSTATE {
  final String? raw;
  final String color;
  final String displayName;
  final bool mod;
  final bool subscriber;

  /// A VIP of the channel (no slow mode or room modes, like moderators).
  final bool vip;

  const USERSTATE({
    this.raw,
    this.color = '',
    this.displayName = '',
    this.mod = false,
    this.subscriber = false,
    this.vip = false,
  });

  USERSTATE fromIRCMessage(IRCMessage ircMessage) => USERSTATE(
    raw: ircMessage.raw,
    color: ircMessage.tags['color'] ?? color,
    displayName: ircMessage.tags['display-name'] ?? displayName,
    mod: ircMessage.tags['mod'] == '0' ? false : true,
    subscriber: ircMessage.tags['subscriber'] == '0' ? false : true,
    // USERSTATE always carries every badge: none (an empty tag) means
    // not a VIP any more.
    vip:
        ircMessage.tags['badges']
            ?.split(',')
            .any((b) => b.startsWith('vip/')) ??
        false,
  );
}

/// Whether [message] names [login] as a whole word (with or without `@`),
/// ignoring case: "al" is not mentioned by "really".
bool mentionsUser(String message, String login) {
  if (login.isEmpty) return false;
  return RegExp(
    '(?:^|[^a-z0-9_])@?${RegExp.escape(login.toLowerCase())}(?![a-z0-9_])',
  ).hasMatch(message.toLowerCase());
}

/// The possible types of Twitch IRC commands.
enum Command {
  privateMessage,
  clearChat,
  clearMessage,
  notice,
  userNotice,
  roomState,
  userState,
  globalUserState,
  none,
}

// Regex from dart_emoji package; used for emoji compatibility with zero-width
final regexEmoji = RegExp(
  r'[\u{1f300}-\u{1f5ff}\u{1f900}-\u{1f9ff}\u{1f600}-\u{1f64f}'
  r'\u{1f680}-\u{1f6ff}\u{2600}-\u{26ff}\u{2700}'
  r'-\u{27bf}\u{1f1e6}-\u{1f1ff}\u{1f191}-\u{1f251}'
  r'\u{1f004}\u{1f0cf}\u{1f170}-\u{1f171}\u{1f17e}'
  r'-\u{1f17f}\u{1f18e}\u{3030}\u{2b50}\u{2b55}'
  r'\u{2934}-\u{2935}\u{2b05}-\u{2b07}\u{2b1b}'
  r'-\u{2b1c}\u{3297}\u{3299}\u{303d}\u{00a9}'
  r'\u{00ae}\u{2122}\u{23f3}\u{24c2}\u{23e9}'
  r'-\u{23ef}\u{25b6}\u{23f8}-\u{23fa}\u{200d}]+',
  unicode: true,
);

/// Words as shown, and the indexes of those the chat filters hide.
typedef _ShownWords = ({List<String> words, Set<int> hidden});

/// A message's words while the chat filters hide part of it.
class _FilteredWords {
  const _FilteredWords({required this.split, required this.gifParts});

  /// In step with [IRCMessage.split].
  final _ShownWords split;

  /// In step with [IRCMessage.gifParts] (null for a GIF).
  final List<_ShownWords?> gifParts;
}

class EmoteBitsThresholdLine extends StatefulWidget {
  const EmoteBitsThresholdLine({
    super.key,
    required this.emoteId,
    required this.style,
  });

  final String emoteId;
  final TextStyle style;

  @override
  State<EmoteBitsThresholdLine> createState() => _EmoteBitsThresholdLineState();
}

class _EmoteBitsThresholdLineState extends State<EmoteBitsThresholdLine> {
  int? _threshold;

  @override
  void initState() {
    super.initState();
    final service = context.read<TwitchCommunityService?>();
    if (service == null) return;
    unawaited(
      service.getEmoteBitsThreshold(emoteId: widget.emoteId).then((value) {
        if (mounted && value != null) setState(() => _threshold = value);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final threshold = _threshold;
    if (threshold == null) return const SizedBox.shrink();
    return Text(
      context.l10n.emoteBitsThreshold(count: threshold),
      style: widget.style,
    );
  }
}
