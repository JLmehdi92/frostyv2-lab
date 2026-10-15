import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/irc.dart';
import 'package:frosty/models/user_notice.dart';

import '../fixtures/irc_messages.dart';

UserNotice _parse(String raw) =>
    UserNotice.fromTags(IRCMessage.fromString(raw).tags);

void main() {
  group('UserNotice.fromTags', () {
    test('reads a resub that shares its streak', () {
      final notice = _parse(resubStreak);

      expect(notice.kind, UserNoticeKind.resub);
      expect(notice.tier, 'Tier 1');
      expect(notice.isPrime, isFalse);
      expect(notice.cumulativeMonths, 14);
      expect(notice.streakMonths, 5);
      expect(notice.shouldShareStreak, isTrue);
      expect(
        notice.systemMessage,
        "ReSubber subscribed at Tier 1. They've subscribed for 14 months, "
        'currently on a 5 month streak!',
      );
    });

    test('keeps a hidden streak hidden', () {
      final notice = _parse(resubHiddenStreak);

      expect(notice.streakMonths, 5);
      expect(notice.shouldShareStreak, isFalse);
    });

    test('reads a Prime sub', () {
      final notice = _parse(primeSub);

      expect(notice.kind, UserNoticeKind.sub);
      expect(notice.tier, 'Prime');
      expect(notice.isPrime, isTrue);
      expect(notice.cumulativeMonths, 1);
      expect(notice.systemMessage, 'PrimeUser subscribed with Prime.');
    });

    test('reads a gift and its recipient', () {
      final notice = _parse(subGift);

      expect(notice.kind, UserNoticeKind.subGift);
      expect(notice.tier, 'Tier 1');
      expect(notice.recipientDisplayName, 'Lucky');
      expect(notice.senderCount, 3);
      expect(notice.communityGiftId, isNull);
      expect(notice.isPartOfMassGift, isFalse);
    });

    test('reads the legacy anonymous gift kind', () {
      expect(_parse(anonymousSubGiftLegacy).kind, UserNoticeKind.anonSubGift);
    });

    test('reads a gift bomb header', () {
      final notice = _parse(massGiftHeader);

      expect(notice.kind, UserNoticeKind.communityGift);
      expect(notice.isMassGiftHeader, isTrue);
      expect(notice.massGiftCount, 5);
      expect(notice.senderCount, 50);
      expect(notice.communityGiftId, '1234567890123456789');
    });

    test('ties every gift of a bomb to its header', () {
      for (final raw in massGiftRecipients) {
        final notice = _parse(raw);

        expect(notice.kind, UserNoticeKind.subGift);
        expect(notice.isPartOfMassGift, isTrue);
        expect(notice.communityGiftId, '1234567890123456789');
        expect(notice.senderCount, 0);
      }
      expect(_parse(massGiftRecipients[2]).recipientDisplayName, 'Viewer3');
    });

    test('reads an anonymous gift bomb header', () {
      final notice = _parse(anonymousMassGift);

      expect(notice.kind, UserNoticeKind.communityGift);
      expect(notice.massGiftCount, 5);
      expect(notice.senderCount, 0);
    });

    test('reads a gift being continued', () {
      final notice = _parse(giftPaidUpgrade);

      expect(notice.kind, UserNoticeKind.giftPaidUpgrade);
      expect(
        notice.systemMessage,
        'Upgrader is continuing the Gift Sub they got from Gifter!',
      );
    });

    test('keeps the user message of a resub in the IRC body', () {
      final message = IRCMessage.fromString(resubStreak);

      expect(message.command, Command.userNotice);
      expect(message.user, 'resubber');
      expect(message.message, 'Kappa 14 months!');
    });
  });
}
