import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/models/user_notice.dart';
import 'package:onset/models/user_notice_presentation.dart';

import '../fixtures/irc_messages.dart';

NoticePresentation _presentRaw(String raw) =>
    noticePresentation(UserNotice.fromTags(IRCMessage.fromString(raw).tags));

NoticePresentation _present(Map<String, String> tags) =>
    noticePresentation(UserNotice.fromTags(tags));

void main() {
  group('noticePresentation', () {
    test('a named sub or resub gets the special row and no icon', () {
      for (final raw in [userNoticeSubscription, resubStreak, primeSub]) {
        final presentation = _presentRaw(raw);

        expect(presentation.layout, NoticeLayout.special);
        expect(presentation.icon, isNull);
      }
    });

    test('a named gift or gift bomb gets the special row and no icon', () {
      for (final raw in [
        subGift,
        multiMonthGift,
        massGiftHeader,
        ...massGiftRecipients,
      ]) {
        final presentation = _presentRaw(raw);

        expect(presentation.layout, NoticeLayout.special);
        expect(presentation.icon, isNull);
      }
    });

    test('an anonymous gift gets the anonymous gift icon, centred', () {
      for (final raw in [
        anonymousSubGift,
        anonymousSubGiftLegacy,
        anonymousMassGift,
      ]) {
        final presentation = _presentRaw(raw);

        expect(presentation.layout, NoticeLayout.special);
        expect(presentation.icon, NoticeGlyph.anonymousGift);
        expect(presentation.iconBias, 0.5);
      }
    });

    test('an extended sub gets the special row and no icon', () {
      final presentation = _presentRaw(extendSub);

      expect(presentation.layout, NoticeLayout.special);
      expect(presentation.icon, isNull);
    });

    test('a sub from another channel of a shared chat shows that channel', () {
      final presentation = _present({
        'msg-id': 'resub',
        'room-id': '12345',
        'source-room-id': '99999',
      });

      expect(presentation.layout, NoticeLayout.special);
      expect(presentation.icon, NoticeGlyph.sharedChat);
      expect(presentation.iconBias, 0.3);
    });

    test('a sub relayed from this very channel shows no channel', () {
      final presentation = _present({
        'msg-id': 'sub',
        'room-id': '12345',
        'source-room-id': '12345',
      });

      expect(presentation.icon, isNull);
    });

    test('a sub towards a goal gets the sub goal row', () {
      final presentation = _presentRaw(subWithGoal);

      expect(presentation.layout, NoticeLayout.subGoal);
      expect(presentation.icon, isNull);
    });

    test('an announcement gets the generic row and the megaphone', () {
      final presentation = _present({'msg-id': 'announcement'});

      expect(presentation.layout, NoticeLayout.generic);
      expect(presentation.icon, NoticeGlyph.megaphone);
    });

    test('a raid gets the raid row and the raider', () {
      final presentation = _presentRaw(raidNotice);

      expect(presentation.layout, NoticeLayout.raid);
      expect(presentation.icon, NoticeGlyph.raider);
    });

    test('charity, sponsored and reward gifts and milestones keep icons', () {
      expect(_present({'msg-id': 'charitydonation'}).icon, NoticeGlyph.charity);
      expect(_present({'msg-id': 'giftsubbasematch'}).icon, NoticeGlyph.gift);
      expect(_present({'msg-id': 'rewardgift'}).icon, NoticeGlyph.gift);
      expect(
        _present({'msg-id': 'viewermilestone'}).icon,
        NoticeGlyph.milestone,
      );
      expect(
        _present({'msg-id': 'viewermilestone'}).layout,
        NoticeLayout.generic,
      );
    });

    test('kinds Twitch drops are kept in the special row, no icon', () {
      for (final msgId in [
        'giftpaidupgrade',
        'primepaidupgrade',
        'standardpayforward',
        'communitypayforward',
        'bitsbadgetier',
        'somethingnew',
      ]) {
        final presentation = _present({'msg-id': msgId, 'login': 'someone'});

        expect(presentation.layout, NoticeLayout.special, reason: msgId);
        expect(presentation.icon, isNull, reason: msgId);
      }
    });

    test('continuing an anonymous gift does not make the viewer anonymous', () {
      expect(_present({'msg-id': 'anongiftpaidupgrade'}).icon, isNull);
    });

    test('an unraid gets the generic row', () {
      expect(_present({'msg-id': 'unraid'}).layout, NoticeLayout.generic);
    });
  });

  test('a partner sub in a shared chat shows the partner channel', () {
    final presentation = _presentRaw(sharedResub);

    expect(presentation.layout, NoticeLayout.special);
    expect(presentation.icon, NoticeGlyph.sharedChat);
  });

  test('a partner announcement keeps the announcement layout', () {
    expect(_presentRaw(sharedAnnouncement).icon, NoticeGlyph.megaphone);
  });

  group('chatBubbleEventOf', () {
    ChatBubbleEvent of(String msgId) =>
        chatBubbleEventOf(UserNotice.fromTags({'msg-id': msgId}));

    test('each notice falls in its bubble type', () {
      expect(of('sub'), ChatBubbleEvent.subs);
      expect(of('resub'), ChatBubbleEvent.subs);
      expect(of('subgift'), ChatBubbleEvent.gifts);
      expect(of('submysterygift'), ChatBubbleEvent.gifts);
      expect(of('raid'), ChatBubbleEvent.raids);
      expect(of('announcement'), ChatBubbleEvent.announcements);
      expect(of('viewermilestone'), ChatBubbleEvent.other);
      expect(of('something-new'), ChatBubbleEvent.other);
    });
  });
}
