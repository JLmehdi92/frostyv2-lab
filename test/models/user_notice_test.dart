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

    test('reads who sent the notice', () {
      final notice = _parse(resubStreak);

      expect(notice.displayName, 'ReSubber');
      expect(notice.login, 'resubber');
      expect(notice.userId, '20001');
      expect(notice.roomId, '12345');
      expect(notice.sourceRoomId, isNull);
      expect(notice.isAnonymous, isFalse);
      expect(notice.isHistorical, isFalse);
    });

    test('reads the gift months and the recipient login', () {
      expect(_parse(subGift).giftMonths, 1);
      expect(_parse(multiMonthGift).giftMonths, 3);
      expect(_parse(subGift).recipientLogin, 'lucky');
      expect(_parse(primeSub).giftMonths, isNull);
    });

    test("spots Twitch's anonymous gifter by its user id", () {
      final notice = _parse(anonymousSubGift);

      expect(notice.kind, UserNoticeKind.subGift);
      expect(notice.isAnonymous, isTrue);
      expect(_parse(anonymousMassGift).isAnonymous, isTrue);
    });

    test('spots an anonymous gift by its legacy msg-id', () {
      expect(_parse(anonymousSubGiftLegacy).isAnonymous, isTrue);
      expect(
        UserNotice.fromTags(const {'msg-id': 'anonsubmysterygift'}).isAnonymous,
        isTrue,
      );
    });

    test('spots an anonymous gift by its login alone', () {
      expect(
        UserNotice.fromTags(const {
          'msg-id': 'subgift',
          'login': 'ananonymousgifter',
        }).isAnonymous,
        isTrue,
      );
    });

    test('reads an extended sub and the month it runs to', () {
      final notice = _parse(extendSub);

      expect(notice.kind, UserNoticeKind.extendSub);
      expect(notice.benefitEndMonth, 6);
      expect(notice.tier, 'Tier 1');
    });

    test('knows the reward gift kind', () {
      expect(
        UserNotice.fromTags(const {'msg-id': 'rewardgift'}).kind,
        UserNoticeKind.rewardGift,
      );
    });

    test('keys a gift bomb by its community gift id', () {
      final header = _parse(massGiftHeader);

      expect(header.originId, '4e 29 ab');
      expect(header.giftBombKey, '1234567890123456789');
      expect(_parse(massGiftRecipients.first).giftBombKey, header.giftBombKey);
    });

    test('falls back to the origin id when there is no community gift id', () {
      final notice = UserNotice.fromTags(const {
        'msg-id': 'submysterygift',
        'msg-param-origin-id': '4e 29 ab',
      });

      expect(notice.communityGiftId, isNull);
      expect(notice.giftBombKey, '4e 29 ab');
    });

    test('has no gift bomb key without either id', () {
      expect(_parse(primeSub).giftBombKey, isNull);
    });

    test('reads a notice replayed from history', () {
      expect(_parse(massGiftHeaderHistorical).isHistorical, isTrue);
    });

    test('reads the channel a shared-chat notice came from', () {
      final notice = _parse(massGiftHeaderShared);

      expect(notice.sourceRoomId, '99999');
      expect(notice.roomId, '12345');
    });

    test('reads the sub goal a sub counts towards', () {
      final notice = _parse(subWithGoal);

      expect(notice.goalCurrentContributions, 524);
      expect(notice.goalTargetContributions, 1200);
      expect(notice.goalContributionType, 'SUBS');
      expect(notice.goalDescription, 'Road to 1200');
      expect(notice.hasGoal, isTrue);
      expect(_parse(primeSub).hasGoal, isFalse);
    });

    test('reads who gave the gift being continued', () {
      final notice = _parse(giftPaidUpgrade);

      expect(notice.senderLogin, 'gifter');
      expect(notice.senderName, 'Gifter');
    });

    test('unescapes a semicolon and a backslash in a tag', () {
      final notice = UserNotice.fromTags(const {
        'msg-id': 'sub',
        'system-msg': r'a\:b\\c',
      });

      expect(notice.systemMessage, r'a;b\c');
    });

    test("reads a raid's viewers and the raider's avatar at 70px", () {
      final notice = _parse(raidNotice);

      expect(notice.kind, UserNoticeKind.raid);
      expect(notice.raidViewerCount, 15);
      expect(
        notice.raiderAvatarUrl,
        'https://static-cdn.jtvnw.net/jtv_user_pictures/'
        'raider-profile_image-70x70.png',
      );
      expect(_parse(primeSub).raiderAvatarUrl, isNull);
    });

    test('keeps the user message of a resub in the IRC body', () {
      final message = IRCMessage.fromString(resubStreak);

      expect(message.command, Command.userNotice);
      expect(message.user, 'resubber');
      expect(message.message, 'Kappa 14 months!');
    });
  });
}
