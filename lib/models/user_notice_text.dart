import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/user_notice.dart';

/// One run of a notice's sentence: a name or count Twitch sets in bold, or
/// the plain words between them.
@immutable
class NoticeSegment {
  final String text;
  final bool bold;

  const NoticeSegment(this.text, {this.bold = false});

  @override
  bool operator ==(Object other) =>
      other is NoticeSegment && other.text == text && other.bold == bold;

  @override
  int get hashCode => Object.hash(text, bold);

  @override
  String toString() => bold ? '**$text**' : text;
}

/// Words a sub or gift notice, in [l]'s language (the one on screen by
/// default).
///
/// The sentences are built from the `msg-param-*` tags rather than showing
/// `system-msg`, with every name in bold. The tags carry the same
/// facts in every language, so the sentence reads the same whatever the
/// channel's locale.
///
/// Kinds with no sentence of their own, or a notice
/// missing a value its sentence needs, fall back to Twitch's own `system-msg`
/// with the leading name in bold. [channelName] is the display name of the
/// channel a gift bomb is aimed at.
List<NoticeSegment> userNoticeText(
  UserNotice notice, {
  required String channelName,
  AppLocalizations? l,
}) {
  final words = l ?? L10n.current;
  final segments = switch (notice.kind) {
    UserNoticeKind.sub || UserNoticeKind.resub => _sub(notice, words),
    UserNoticeKind.subGift => _subGift(notice, words),
    UserNoticeKind.communityGift => _communityGift(notice, channelName, words),
    UserNoticeKind.extendSub => _extendSub(notice, words),
    UserNoticeKind.raid => _raid(notice),
    _ => null,
  };

  return segments ?? _systemMessage(notice);
}

/// The name Twitch shows for a viewer: the display name, followed by the login
/// when the display name is written with anything beyond ASCII, so a viewer
/// can still be told apart and looked up.
String readableNoticeName(String displayName, String? login) {
  if (login == null || login.isEmpty) return displayName;
  if (displayName.toLowerCase() == login.toLowerCase()) return displayName;
  if (displayName.runes.every((rune) => rune <= 127)) return displayName;
  return '$displayName ($login)';
}

/// 1, 2 or 3 for "Tier 1", "Tier 2" or "Tier 3", or null for Prime and
/// unknown plans.
int? _paidTier(UserNotice notice) => switch (notice.tier) {
  'Tier 1' => 1,
  'Tier 2' => 2,
  'Tier 3' => 3,
  _ => null,
};

String? _senderName(UserNotice notice) {
  final displayName = notice.displayName ?? notice.login;
  if (displayName == null) return null;
  return readableNoticeName(displayName, notice.login);
}

/// [message], a sentence built with [l10nMark]s, as segments: mark `i` is
/// `bold[i]`, in bold; then each sentence of [more] after a space, in plain
/// words. One message per sentence, names where the language puts them.
List<NoticeSegment> _sentences(
  String message,
  List<String> bold, [
  List<String?> more = const [],
]) {
  final segments = <NoticeSegment>[];
  final plain = StringBuffer();
  void flush() {
    if (plain.isEmpty) return;
    segments.add(NoticeSegment(plain.toString()));
    plain.clear();
  }

  final marks = {
    for (final (index, name) in bold.indexed)
      l10nMark(index).runes.single: name,
  };
  for (final rune in message.runes) {
    if (marks[rune] case final name?) {
      flush();
      segments.add(NoticeSegment(name, bold: true));
    } else {
      plain.writeCharCode(rune);
    }
  }
  for (final sentence in more.nonNulls) {
    plain.write(' $sentence');
  }
  flush();
  return segments;
}

/// "It's their first Gift Sub in the channel!" or "They've given N Gift Subs
/// in the channel!", or null when the gifter's count is hidden or unknown.
String? _giftCountSentence(int? senderCount, AppLocalizations l) {
  if (senderCount == null || senderCount <= 0) return null;
  if (senderCount == 1) return l.noticeGiftFirst;
  return l.noticeGiftCount(count: senderCount);
}

List<NoticeSegment>? _sub(UserNotice notice, AppLocalizations l) {
  final name = _senderName(notice);
  if (name == null) return null;

  final tier = _paidTier(notice);
  final plan = notice.isPrime
      ? 'prime'
      : tier != null
      ? 'tier'
      : 'none';
  final subscribed = notice.kind == UserNoticeKind.resub
      ? l.noticeResubscribed(plan: plan, name: l10nMark(0), tier: tier ?? 0)
      : l.noticeSubscribed(plan: plan, name: l10nMark(0), tier: tier ?? 0);

  final months = notice.cumulativeMonths;
  final streak = notice.streakMonths;
  final String? tail;
  if (months != null &&
      notice.shouldShareStreak &&
      streak != null &&
      streak > 0) {
    tail = l.noticeSubStreak(months: months, streak: streak);
  } else if (months != null && months > 1) {
    tail = l.noticeSubMonths(months: months);
  } else {
    tail = null;
  }

  return _sentences(subscribed, [name], [tail]);
}

List<NoticeSegment>? _subGift(UserNotice notice, AppLocalizations l) {
  // Twitch names the gifter by their display name alone (the anonymous
  // gifter account reads "AnAnonymousGifter"); only the recipient gets the
  // login after a name beyond ASCII.
  final gifter = notice.displayName ?? notice.login;
  final recipientName = notice.recipientDisplayName;
  if (gifter == null || recipientName == null) return null;

  final recipient = readableNoticeName(recipientName, notice.recipientLogin);
  final tier = _paidTier(notice);
  final months = notice.giftMonths ?? 1;
  final countSentence = _giftCountSentence(notice.senderCount, l);

  if (months > 1) {
    if (tier != null) {
      return _sentences(
        l.noticeGiftedMonthsTier(
          gifter: l10nMark(0),
          months: l10nMark(1),
          tier: l10nMark(2),
          recipient: l10nMark(3),
        ),
        [
          gifter,
          l.noticeGiftMonths(count: months),
          l.noticeGiftTier(tier: tier),
          recipient,
        ],
        [countSentence],
      );
    }
    return _sentences(
      l.noticeGiftedMonths(
        gifter: l10nMark(0),
        months: l10nMark(1),
        recipient: l10nMark(2),
      ),
      [gifter, l.noticeGiftMonthsShort(count: months), recipient],
      [countSentence],
    );
  }

  return _sentences(
    l.noticeGiftedSub(
      tiered: tier == null ? 'no' : 'yes',
      gifter: l10nMark(0),
      tier: tier ?? 0,
      recipient: l10nMark(1),
    ),
    [gifter, recipient],
    [countSentence],
  );
}

List<NoticeSegment>? _communityGift(
  UserNotice notice,
  String channelName,
  AppLocalizations l,
) {
  final count = notice.massGiftCount;
  final gifter = notice.isAnonymous
      ? l.chatAnonymousGifter
      : _senderName(notice);
  if (count == null || gifter == null) return null;

  final tier = _paidTier(notice);
  final senderCount = notice.senderCount ?? 0;
  final more = switch (senderCount) {
    1 => l.noticeCommunityGiftFirst,
    > 1 => l.noticeCommunityGiftTotal(count: senderCount),
    _ => null,
  };

  return _sentences(
    l.noticeCommunityGift(
      tiered: tier == null ? 'no' : 'yes',
      count: count,
      gifter: l10nMark(0),
      tier: tier ?? 0,
      channel: channelName,
      end: more == null ? 'last' : 'more',
    ),
    [gifter],
    [more],
  );
}

List<NoticeSegment>? _extendSub(UserNotice notice, AppLocalizations l) {
  final name = _senderName(notice);
  final month = notice.benefitEndMonth;
  if (name == null || month == null || month < 1 || month > 12) return null;

  final tier = _paidTier(notice);
  return _sentences(
    l.noticeExtendedSub(
      tiered: tier == null ? 'no' : 'yes',
      name: l10nMark(0),
      tier: tier ?? 0,
      // In the language of `Intl`, the one on screen.
      month: DateFormat.MMMM().format(DateTime(2000, month)),
    ),
    [name],
  );
}

final _wordCharacter = RegExp(r'\w');

/// Twitch's raid sentence ("15 raiders from X have joined!"), with the
/// raiding channel's name in bold, or null when the name is not in it.
List<NoticeSegment>? _raid(UserNotice notice) {
  final message = notice.systemMessage;
  final name = notice.raiderDisplayName;
  if (message.isEmpty || name == null) return null;

  final match = RegExp(
    '(?<!\\w)${RegExp.escape(name)}(?!\\w)',
    caseSensitive: false,
  ).firstMatch(message);
  if (match == null) return null;

  return [
    if (match.start > 0) NoticeSegment(message.substring(0, match.start)),
    NoticeSegment(match[0]!, bold: true),
    if (match.end < message.length) NoticeSegment(message.substring(match.end)),
  ];
}

/// Twitch's own sentence, with the sender's name in bold when the sentence
/// starts with it.
List<NoticeSegment> _systemMessage(UserNotice notice) {
  final message = notice.systemMessage;
  if (message.isEmpty) return const [];

  final candidates = [notice.displayName, notice.login].nonNulls;
  for (final name in candidates) {
    if (message.length > name.length &&
        message.toLowerCase().startsWith(name.toLowerCase()) &&
        !_wordCharacter.hasMatch(message[name.length])) {
      return [
        NoticeSegment(message.substring(0, name.length), bold: true),
        NoticeSegment(message.substring(name.length)),
      ];
    }
  }

  return [NoticeSegment(message)];
}
