import 'package:flutter/foundation.dart';
import 'package:frosty/models/user_notice.dart';

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

/// Words a sub or gift notice the way Twitch's Android app does.
///
/// Twitch's app builds these sentences from the `msg-param-*` tags rather than
/// showing `system-msg`, and sets every name in bold. The tags carry the same
/// facts in every language, so the sentence reads the same whatever the
/// channel's locale.
///
/// Kinds Twitch has no sentence for (and Twitch's app drops), or a notice
/// missing a value its sentence needs, fall back to Twitch's own `system-msg`
/// with the leading name in bold. [channelName] is the display name of the
/// channel a gift bomb is aimed at.
List<NoticeSegment> userNoticeText(
  UserNotice notice, {
  required String channelName,
}) {
  final words = switch (notice.kind) {
    UserNoticeKind.sub || UserNoticeKind.resub => _sub(notice),
    UserNoticeKind.subGift => _subGift(notice),
    UserNoticeKind.communityGift => _communityGift(notice, channelName),
    UserNoticeKind.extendSub => _extendSub(notice),
    UserNoticeKind.raid => _raid(notice),
    _ => null,
  };

  return words ?? _systemMessage(notice);
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

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// "Tier 1", "Tier 2" or "Tier 3", or null for Prime and unknown plans.
String? _paidTier(UserNotice notice) => switch (notice.tier) {
  'Tier 1' || 'Tier 2' || 'Tier 3' => notice.tier,
  _ => null,
};

String? _senderName(UserNotice notice) {
  final displayName = notice.displayName ?? notice.login;
  if (displayName == null) return null;
  return readableNoticeName(displayName, notice.login);
}

String _plural(int count, String singular) =>
    count == 1 ? singular : '${singular}s';

/// "It's their first Gift Sub in the channel!" or "They've given N Gift Subs
/// in the channel!", or null when the gifter's count is hidden or unknown.
String? _giftCountSentence(int? senderCount) {
  if (senderCount == null || senderCount <= 0) return null;
  if (senderCount == 1) return "It's their first Gift Sub in the channel!";
  return "They've given $senderCount Gift Subs in the channel!";
}

List<NoticeSegment>? _sub(UserNotice notice) {
  final name = _senderName(notice);
  if (name == null) return null;

  final tier = _paidTier(notice);
  final subscribed = notice.isPrime
      ? ' subscribed with Prime.'
      : tier != null
      ? ' subscribed at $tier.'
      : ' subscribed.';

  final months = notice.cumulativeMonths;
  final streak = notice.streakMonths;
  final String tail;
  if (months != null &&
      notice.shouldShareStreak &&
      streak != null &&
      streak > 0) {
    tail =
        " They've subscribed for $months ${_plural(months, 'month')}, "
        'currently on a $streak month streak!';
  } else if (months != null && months > 1) {
    tail = " They've subscribed for $months months!";
  } else {
    tail = '';
  }

  return [NoticeSegment(name, bold: true), NoticeSegment('$subscribed$tail')];
}

List<NoticeSegment>? _subGift(UserNotice notice) {
  // Twitch names the gifter by their display name alone (the anonymous
  // gifter account reads "AnAnonymousGifter"); only the recipient gets the
  // login after a name beyond ASCII.
  final gifter = notice.displayName ?? notice.login;
  final recipientName = notice.recipientDisplayName;
  if (gifter == null || recipientName == null) return null;

  final recipient = readableNoticeName(recipientName, notice.recipientLogin);
  final tier = _paidTier(notice);
  final months = notice.giftMonths ?? 1;
  final countSentence = _giftCountSentence(notice.senderCount);
  final tail = countSentence == null ? '!' : '! $countSentence';

  if (months > 1) {
    return [
      NoticeSegment(gifter, bold: true),
      if (tier != null) ...[
        const NoticeSegment(' gifted '),
        NoticeSegment('$months months', bold: true),
        const NoticeSegment(' of '),
        NoticeSegment(tier, bold: true),
        const NoticeSegment(' to '),
      ] else ...[
        const NoticeSegment(' gifted a '),
        NoticeSegment('$months month', bold: true),
        const NoticeSegment(' Sub to '),
      ],
      NoticeSegment(recipient, bold: true),
      NoticeSegment(tail),
    ];
  }

  return [
    NoticeSegment(gifter, bold: true),
    NoticeSegment(
      tier == null ? ' gifted a Sub to ' : ' gifted a $tier Sub to ',
    ),
    NoticeSegment(recipient, bold: true),
    NoticeSegment(tail),
  ];
}

List<NoticeSegment>? _communityGift(UserNotice notice, String channelName) {
  final count = notice.massGiftCount;
  final gifter = notice.isAnonymous
      ? 'An anonymous gifter'
      : _senderName(notice);
  if (count == null || gifter == null) return null;

  final tier = _paidTier(notice);
  final subs = tier == null
      ? '$count ${_plural(count, 'Sub')}'
      : '$count $tier ${_plural(count, 'Sub')}';
  final senderCount = notice.senderCount ?? 0;
  final tail = switch (senderCount) {
    1 => ". It's their first Gift Sub in the channel!",
    > 1 => ". They've gifted a total of $senderCount in the channel!",
    _ => '!',
  };

  return [
    NoticeSegment(gifter, bold: true),
    NoticeSegment(" is gifting $subs to $channelName's community$tail"),
  ];
}

List<NoticeSegment>? _extendSub(UserNotice notice) {
  final name = _senderName(notice);
  final month = notice.benefitEndMonth;
  if (name == null || month == null || month < 1 || month > 12) return null;

  final tier = _paidTier(notice);
  final subscription = tier == null ? 'subscription' : '$tier subscription';

  return [
    NoticeSegment(name, bold: true),
    NoticeSegment(
      ' extended their $subscription through ${_months[month - 1]}!',
    ),
  ];
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
