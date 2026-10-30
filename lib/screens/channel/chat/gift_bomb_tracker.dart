import 'package:flutter/foundation.dart';
import 'package:onset/models/user_notice.dart';
import 'package:onset/models/user_notice_text.dart';

/// A mass gift: one `submysterygift` header and the `subgift` lines that
/// follow it, one per recipient.
@immutable
class GiftBomb {
  /// The id its header and gifts share (see [UserNotice.giftBombKey]).
  final String key;

  /// The gifter's name, as Twitch shows it.
  final String gifterName;
  final bool isAnonymous;

  /// How many subs the header announced.
  final int count;

  /// `Tier 1`, `Tier 2`, `Tier 3`, or null when unknown.
  final String? tier;

  /// How many of its gifts have arrived so far.
  final int received;

  /// Who received them so far, in order: the first
  /// [GiftBombTracker.maxRecipients] names (every gift is still counted in
  /// [received]).
  final List<String> recipients;

  /// Whether its gifts are folded into its header row ("Collapse gift
  /// bombs", decided once when the header arrives).
  final bool collapsed;

  const GiftBomb({
    required this.key,
    required this.gifterName,
    required this.isAnonymous,
    required this.count,
    this.tier,
    this.received = 0,
    this.recipients = const [],
    this.collapsed = false,
  });

  /// Whether every announced gift has arrived.
  bool get complete => count > 0 && received >= count;

  /// One more gift, to [recipient] (null: an unnamed one, only counted).
  GiftBomb withGift(String? recipient) => GiftBomb(
    key: key,
    gifterName: gifterName,
    isAnonymous: isAnonymous,
    count: count,
    tier: tier,
    received: received + 1,
    recipients:
        recipient == null ||
            recipient.isEmpty ||
            recipients.length >= GiftBombTracker.maxRecipients
        ? recipients
        : List.unmodifiable([...recipients, recipient]),
    collapsed: collapsed,
  );

  @override
  bool operator ==(Object other) =>
      other is GiftBomb &&
      other.key == key &&
      other.gifterName == gifterName &&
      other.isAnonymous == isAnonymous &&
      other.count == count &&
      other.tier == tier &&
      other.received == received &&
      other.collapsed == collapsed &&
      listEquals(other.recipients, recipients);

  @override
  int get hashCode => Object.hash(
    key,
    gifterName,
    isAnonymous,
    count,
    tier,
    received,
    collapsed,
    Object.hashAll(recipients),
  );

  @override
  String toString() => 'GiftBomb($key, $gifterName, $count, $received)';
}

/// A gift bomb pinned above chat, from [startedAt] until [endsAt] (Twitch
/// time).
@immutable
class GiftBombBanner {
  /// The bomb as its header announced it.
  final GiftBomb bomb;
  final DateTime startedAt;
  final DateTime endsAt;

  /// The bomb as its gifts arrive (see [GiftBombTracker.watch]); null when
  /// the chat does not follow it, in which case [bomb] is all there is.
  final ValueListenable<GiftBomb>? live;

  const GiftBombBanner({
    required this.bomb,
    required this.startedAt,
    required this.endsAt,
    this.live,
  });

  /// How long the banner stays up in all.
  Duration get total => endsAt.difference(startedAt);

  /// Its id in the highlight stack: the bomb's, so a header heard twice is
  /// one banner (and stays dismissed).
  String get id =>
      bomb.key.isEmpty ? 'at-${startedAt.millisecondsSinceEpoch}' : bomb.key;
}

/// What to do with one incoming notice.
@immutable
class GiftBombDecision {
  /// Whether the notice gets its own chat row.
  final bool show;

  /// The bomb a header announces, when the notice is one.
  final GiftBomb? header;

  /// The bomb to pin above chat, when this header deserves the banner.
  final GiftBomb? banner;

  const GiftBombDecision._({required this.show, this.header, this.banner});

  static const shown = GiftBombDecision._(show: true);
  static const suppressed = GiftBombDecision._(show: false);
}

/// How long Twitch pins a gift bomb's banner above chat: nothing under 5
/// gifts, then 10 seconds, plus 5 more for every 25 gifts, up to 30 seconds
/// from 100 gifts.
Duration? bannerDuration(int count) => switch (count) {
  < 5 => null,
  < 25 => const Duration(seconds: 10),
  < 50 => const Duration(seconds: 15),
  < 75 => const Duration(seconds: 20),
  < 100 => const Duration(seconds: 25),
  _ => const Duration(seconds: 30),
};

/// Follows the gift bombs of one chat, one notice at a time.
///
/// Twitch's Android app shows a bomb's header and then every one of its
/// gifts; with `collapse` on, the gifts of a bomb of five or more whose
/// header was shown are counted (and their recipients kept) but not shown:
/// the header row lists them. Smaller bombs always show every gift. A gift
/// that arrives before its header is always shown: suppressing it would lose
/// the event.
///
/// A pure helper: the chat store feeds it each `USERNOTICE` after the chat
/// delay, so a banner appears in step with the video.
class GiftBombTracker {
  /// How many bombs are remembered. A bomb is only useful for as long as its
  /// own gifts are still arriving.
  static const maxTracked = 100;

  /// How many recipient names one bomb keeps.
  static const maxRecipients = 100;

  /// The smallest bomb whose gifts "Collapse gift bombs" folds away.
  static const collapseFrom = 5;

  /// Bombs by key, least recently active first (a map literal keeps its
  /// insertion order), each in a notifier the pin and the header row follow.
  final _bombs = <String, ValueNotifier<GiftBomb>>{};

  /// How many bombs are remembered.
  int get length => _bombs.length;

  /// The bomb keyed [key], if still remembered.
  GiftBomb? bomb(String key) => _bombs[key]?.value;

  /// The bomb keyed [key] as its gifts arrive, if still remembered. A
  /// forgotten bomb's notifier stays with whoever holds it, frozen.
  ValueListenable<GiftBomb>? watch(String key) => _bombs[key];

  GiftBombDecision onNotice(
    UserNotice notice, {
    required bool collapse,
    required String channelId,
  }) {
    final key = notice.giftBombKey;

    if (notice.isMassGiftHeader) {
      final bomb = GiftBomb(
        key: key ?? '',
        gifterName: notice.isAnonymous
            ? 'An anonymous gifter'
            : readableNoticeName(
                notice.displayName ?? notice.login ?? '',
                notice.login,
              ),
        isAnonymous: notice.isAnonymous,
        count: notice.massGiftCount ?? 0,
        tier: notice.tier,
        received: key == null ? 0 : (_bombs[key]?.value.received ?? 0),
        recipients: key == null
            ? const []
            : (_bombs[key]?.value.recipients ?? const []),
        collapsed: collapse && (notice.massGiftCount ?? 0) >= collapseFrom,
      );
      if (key != null) _remember(bomb);

      final source = notice.sourceRoomId;
      final deservesBanner =
          bannerDuration(bomb.count) != null &&
          !notice.isHistorical &&
          (source == null || source == channelId);

      return GiftBombDecision._(
        show: true,
        header: bomb,
        banner: deservesBanner ? bomb : null,
      );
    }

    final isGift =
        notice.kind == UserNoticeKind.subGift ||
        notice.kind == UserNoticeKind.anonSubGift;
    final bomb = key == null ? null : _bombs[key]?.value;
    if (!isGift || bomb == null) return GiftBombDecision.shown;

    _remember(
      bomb.withGift(
        readableNoticeName(
          notice.recipientDisplayName ?? notice.recipientLogin ?? '',
          notice.recipientLogin,
        ),
      ),
    );
    return bomb.collapsed
        ? GiftBombDecision.suppressed
        : GiftBombDecision.shown;
  }

  /// Stores [bomb] as the most recently active, forgetting the least
  /// recently active one beyond [maxTracked]. A bomb already known keeps
  /// its notifier, so whoever follows it sees the change.
  void _remember(GiftBomb bomb) {
    final live = _bombs.remove(bomb.key);
    if (live == null) {
      _bombs[bomb.key] = ValueNotifier(bomb);
    } else {
      _bombs[bomb.key] = live..value = bomb;
    }
    if (_bombs.length > maxTracked) _bombs.remove(_bombs.keys.first);
  }
}
