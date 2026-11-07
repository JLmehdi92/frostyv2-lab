import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/models/user_notice.dart';
import 'package:onset/models/user_notice_text.dart';

import '../fixtures/irc_messages.dart';

List<NoticeSegment> _wordRaw(String raw, {String channelName = 'Channel'}) =>
    userNoticeText(
      UserNotice.fromTags(IRCMessage.fromString(raw).tags),
      channelName: channelName,
    );

List<NoticeSegment> _word(
  Map<String, String> tags, {
  String channelName = 'Channel',
}) => userNoticeText(UserNotice.fromTags(tags), channelName: channelName);

String _text(List<NoticeSegment> segments) =>
    segments.map((s) => s.text).join();

List<String> _bold(List<NoticeSegment> segments) =>
    segments.where((s) => s.bold).map((s) => s.text).toList();

/// The tags of a sub or resub from `X`, on top of which each test sets the
/// counts it is about.
Map<String, String> _sub({
  String plan = '1000',
  String? cumulative,
  String? streak,
  bool share = false,
  String displayName = 'X',
  String login = 'x',
}) => {
  'msg-id': 'resub',
  'display-name': displayName,
  'login': login,
  'msg-param-sub-plan': plan,
  'msg-param-cumulative-months': ?cumulative,
  'msg-param-streak-months': ?streak,
  'msg-param-should-share-streak': share ? '1' : '0',
  'system-msg': '$displayName subscribed.',
};

/// The tags of a gift from `G` to `R`.
Map<String, String> _gift({
  String plan = '1000',
  String? months,
  String? senderCount,
}) => {
  'msg-id': 'subgift',
  'display-name': 'G',
  'login': 'g',
  'msg-param-sub-plan': plan,
  'msg-param-gift-months': ?months,
  'msg-param-sender-count': ?senderCount,
  'msg-param-recipient-display-name': 'R',
  'msg-param-recipient-user-name': 'r',
  'system-msg': 'G gifted a sub to R!',
};

/// The tags of a gift bomb of [count] subs from `G`.
Map<String, String> _bomb({
  String plan = '1000',
  String count = '5',
  String? senderCount,
}) => {
  'msg-id': 'submysterygift',
  'display-name': 'G',
  'login': 'g',
  'msg-param-sub-plan': plan,
  'msg-param-mass-gift-count': count,
  'msg-param-sender-count': ?senderCount,
  'system-msg': 'G is gifting subs!',
};

void main() {
  group('sub and resub', () {
    test('a first sub says only the tier', () {
      final words = _word(_sub(cumulative: '1'));

      expect(_text(words), 'X subscribed at Tier 1.');
      expect(_bold(words), ['X']);
    });

    test('a first Prime sub says Prime', () {
      expect(_text(_wordRaw(primeSub)), 'PrimeUser subscribed with Prime.');
    });

    test('a first sub of an unknown plan leaves the tier out', () {
      expect(
        _text(_word(_sub(plan: 'Custom', cumulative: '1'))),
        'X subscribed.',
      );
    });

    test('Tier 2 and Tier 3 name their tier', () {
      expect(_text(_word(_sub(plan: '2000'))), 'X subscribed at Tier 2.');
      expect(_text(_word(_sub(plan: '3000'))), 'X subscribed at Tier 3.');
    });

    test('a resub counts the months', () {
      expect(
        _text(_word(_sub(cumulative: '14'))),
        'X subscribed at Tier 1. They’ve subscribed for 14 months!',
      );
      expect(
        _text(_word(_sub(plan: 'Prime', cumulative: '14'))),
        'X subscribed with Prime. They’ve subscribed for 14 months!',
      );
      expect(
        _text(_word(_sub(plan: 'Custom', cumulative: '14'))),
        'X subscribed. They’ve subscribed for 14 months!',
      );
    });

    test('a shared streak adds the streak', () {
      expect(
        _text(_wordRaw(resubStreak)),
        'ReSubber subscribed at Tier 1. They’ve subscribed for 14 months, '
        'currently on a 5-month streak!',
      );
      expect(
        _text(
          _word(_sub(plan: 'Prime', cumulative: '3', streak: '2', share: true)),
        ),
        'X subscribed with Prime. They’ve subscribed for 3 months, '
        'currently on a 2-month streak!',
      );
      expect(
        _text(
          _word(
            _sub(plan: 'Custom', cumulative: '3', streak: '2', share: true),
          ),
        ),
        'X subscribed. They’ve subscribed for 3 months, '
        'currently on a 2-month streak!',
      );
    });

    test('a streak of one month still reads "month"', () {
      expect(
        _text(_word(_sub(cumulative: '1', streak: '1', share: true))),
        'X subscribed at Tier 1. They’ve subscribed for 1 month, '
        'currently on a 1-month streak!',
      );
    });

    test('a hidden streak is not shown', () {
      expect(
        _text(_wordRaw(resubHiddenStreak)),
        'ReSubber subscribed at Tier 1. They’ve subscribed for 14 months!',
      );
    });

    test('a zero streak is not shown', () {
      expect(
        _text(_word(_sub(cumulative: '14', streak: '0', share: true))),
        'X subscribed at Tier 1. They’ve subscribed for 14 months!',
      );
    });

    test('a resub and a sub with the same counts read the same', () {
      final sub = _sub(cumulative: '14')..['msg-id'] = 'sub';

      expect(_text(_word(sub)), _text(_word(_sub(cumulative: '14'))));
    });

    test('only the name is bold', () {
      expect(_bold(_wordRaw(resubStreak)), ['ReSubber']);
    });

    test('a name in another script is followed by the login', () {
      final words = _word(
        _sub(cumulative: '1', displayName: '名前', login: 'namae'),
      );

      expect(_text(words), '名前 (namae) subscribed at Tier 1.');
      expect(_bold(words), ['名前 (namae)']);
    });

    test('an accented name is followed by the login too', () {
      expect(
        _bold(_word(_sub(cumulative: '1', displayName: 'Zoé', login: 'zoe'))),
        ['Zoé (zoe)'],
      );
    });
  });

  group('subgift', () {
    test('a first gift says so', () {
      final words = _word(_gift(senderCount: '1'));

      expect(
        _text(words),
        'G gifted a Tier 1 sub to R! It’s their first gift sub in the channel!',
      );
      expect(_bold(words), ['G', 'R']);
    });

    test('a later gift counts the gifts', () {
      expect(
        _text(_wordRaw(subGift)),
        'Gifter gifted a Tier 1 sub to Lucky! They’ve given 3 gift subs in '
        'the channel!',
      );
    });

    test('a gift with no count, as inside a gift bomb, says nothing more', () {
      expect(_text(_word(_gift())), 'G gifted a Tier 1 sub to R!');
      expect(
        _text(_word(_gift(senderCount: '0'))),
        'G gifted a Tier 1 sub to R!',
      );
      expect(
        _text(_wordRaw(massGiftRecipients.first)),
        'BigGifter gifted a Tier 1 sub to Viewer1!',
      );
    });

    test('a gift of an unknown plan leaves the tier out', () {
      expect(_text(_word(_gift(plan: 'Custom'))), 'G gifted a sub to R!');
    });

    test('a multi-month gift names the months and the tier in bold', () {
      final words = _wordRaw(multiMonthGift);

      expect(
        _text(words),
        'Gifter gifted 3 months of Tier 1 to Lucky! It’s their first gift sub '
        'in the channel!',
      );
      expect(_bold(words), ['Gifter', '3 months', 'Tier 1', 'Lucky']);
    });

    test('a multi-month gift counts the gifts after a space', () {
      expect(
        _text(_word(_gift(months: '6', senderCount: '2'))),
        'G gifted 6 months of Tier 1 to R! They’ve given 2 gift subs in the '
        'channel!',
      );
      expect(
        _text(_word(_gift(months: '6'))),
        'G gifted 6 months of Tier 1 to R!',
      );
    });

    test('a multi-month gift of an unknown plan reads as a Sub', () {
      final words = _word(_gift(plan: 'Custom', months: '3'));

      expect(_text(words), 'G gifted a 3-month sub to R!');
      expect(_bold(words), ['G', '3-month', 'R']);
    });

    test('a single-month gift is not called multi-month', () {
      expect(_text(_word(_gift(months: '1'))), 'G gifted a Tier 1 sub to R!');
    });

    test('an anonymous gift comes from "An anonymous gifter", not Twitch\'s '
        'account name', () {
      expect(
        _text(_wordRaw(anonymousSubGift)),
        'An anonymous gifter gifted a Tier 1 sub to Lucky!',
      );
    });

    test('in French, an anonymous gift comes from « Anonyme »', () {
      final segments = userNoticeText(
        UserNotice.fromTags(IRCMessage.fromString(anonymousSubGift).tags),
        channelName: 'Channel',
        l: lookupAppLocalizations(const Locale('fr')),
      );
      expect(
        _text(segments),
        'Anonyme a offert un abonnement de niveau 1 à Lucky\u202f!',
      );
      expect(_bold(segments), contains('Anonyme'));
    });

    test('a recipient in another script is followed by the login', () {
      final tags = _gift()
        ..['msg-param-recipient-display-name'] = '名前'
        ..['msg-param-recipient-user-name'] = 'namae';

      expect(_bold(_word(tags)), ['G', '名前 (namae)']);
    });

    test("the gifter's name is shown as is, without the login", () {
      final tags = _gift()
        ..['display-name'] = '名前'
        ..['login'] = 'namae';

      expect(_bold(_word(tags)), ['名前', 'R']);
      expect(_bold(_word({...tags, 'msg-param-gift-months': '3'})).first, '名前');
    });

    test('a gift with no recipient falls back to Twitch\'s sentence', () {
      final tags = _gift()..remove('msg-param-recipient-display-name');

      expect(_text(_word(tags)), 'G gifted a sub to R!');
    });
  });

  group('submysterygift', () {
    test('a first gift bomb says so, after a full stop', () {
      final words = _word(_bomb(senderCount: '1'));

      expect(
        _text(words),
        'G is gifting 5 Tier 1 subs to Channel’s community. It’s their first '
        'gift sub in the channel!',
      );
      expect(_bold(words), ['G']);
    });

    test('a later gift bomb gives the total', () {
      expect(
        _text(_wordRaw(massGiftHeader, channelName: 'Streamer')),
        'BigGifter is gifting 5 Tier 1 subs to Streamer’s community. They’ve '
        'gifted a total of 50 subs in the channel!',
      );
    });

    test('a gift bomb with no count ends on an exclamation mark', () {
      expect(
        _text(_word(_bomb())),
        'G is gifting 5 Tier 1 subs to Channel’s community!',
      );
      expect(
        _text(_word(_bomb(senderCount: '0'))),
        'G is gifting 5 Tier 1 subs to Channel’s community!',
      );
    });

    test('a gift bomb of one is a single Sub', () {
      expect(
        _text(_word(_bomb(count: '1'))),
        'G is gifting 1 Tier 1 sub to Channel’s community!',
      );
    });

    test('a gift bomb of an unknown plan leaves the tier out', () {
      expect(
        _text(_word(_bomb(plan: 'Custom'))),
        'G is gifting 5 subs to Channel’s community!',
      );
    });

    test('an anonymous gift bomb comes from "An anonymous gifter"', () {
      final words = _wordRaw(anonymousMassGift);

      expect(
        _text(words),
        'An anonymous gifter is gifting 5 Tier 1 subs to Channel’s community!',
      );
      expect(_bold(words), ['An anonymous gifter']);
    });

    test('a gift bomb with no count falls back to Twitch\'s sentence', () {
      final tags = _bomb()..remove('msg-param-mass-gift-count');

      expect(_text(_word(tags)), 'G is gifting subs!');
    });
  });

  group('extendsub', () {
    test('writes the month in the language it is given, whatever Intl '
        'says', () async {
      await initializeDateFormatting('fr');
      final previous = Intl.defaultLocale;
      addTearDown(() => Intl.defaultLocale = previous);
      final notice = UserNotice.fromTags(IRCMessage.fromString(extendSub).tags);
      Intl.defaultLocale = 'fr';
      expect(
        _text(
          userNoticeText(
            notice,
            channelName: 'Channel',
            l: lookupAppLocalizations(const Locale('en')),
          ),
        ),
        contains('through June!'),
      );
      Intl.defaultLocale = 'en_US';
      expect(
        _text(
          userNoticeText(
            notice,
            channelName: 'Channel',
            l: lookupAppLocalizations(const Locale('fr')),
          ),
        ),
        contains('jusqu\u2019en juin'),
      );
    });

    test('names the month the sub runs to', () {
      final words = _wordRaw(extendSub);

      expect(
        _text(words),
        'Extender extended their Tier 1 subscription through June!',
      );
      expect(_bold(words), ['Extender']);
    });

    test('names every month in full', () {
      final tags = {
        'msg-id': 'extendsub',
        'display-name': 'X',
        'msg-param-sub-plan': '1000',
        'msg-param-sub-benefit-end-month': '12',
      };

      expect(
        _text(_word(tags)),
        'X extended their Tier 1 subscription through December!',
      );
      expect(
        _text(_word({...tags, 'msg-param-sub-benefit-end-month': '1'})),
        'X extended their Tier 1 subscription through January!',
      );
    });

    test('falls back to Twitch\'s sentence for a month out of range', () {
      final tags = {
        'msg-id': 'extendsub',
        'display-name': 'X',
        'msg-param-sub-plan': '1000',
        'msg-param-sub-benefit-end-month': '13',
        'system-msg': 'X extended their sub!',
      };

      expect(_text(_word(tags)), 'X extended their sub!');
    });
  });

  group('raid', () {
    test("bolds the raider's name in Twitch's sentence", () {
      final words = _wordRaw(raidNotice);

      expect(_text(words), '15 raiders from Raider have joined!');
      expect(_bold(words), ['Raider']);
    });

    test('bolds only a whole name', () {
      final words = _word({
        'msg-id': 'raid',
        'msg-param-displayName': 'Rai',
        'system-msg': '15 raiders from Raider and Rai have joined!',
      });

      expect(_text(words), '15 raiders from Raider and Rai have joined!');
      expect(_bold(words), ['Rai']);
    });

    test('leaves the sentence plain when the name is not in it', () {
      final words = _word({
        'msg-id': 'raid',
        'msg-param-displayName': 'Someone',
        'system-msg': '15 raiders have joined!',
      });

      expect(_bold(words), isEmpty);
    });

    group('in French, worded from the tags', () {
      final french = lookupAppLocalizations(const Locale('fr'));
      List<NoticeSegment> wordFr(Map<String, String> tags) => userNoticeText(
        UserNotice.fromTags(tags),
        channelName: 'Channel',
        l: french,
      );

      test('the raider in bold, the viewers counted', () {
        final words = userNoticeText(
          UserNotice.fromTags(IRCMessage.fromString(raidNotice).tags),
          channelName: 'Channel',
          l: french,
        );

        expect(
          _text(words),
          'Raider lance un raid avec 15\u00a0spectateurs\u202f!',
        );
        expect(_bold(words), ['Raider']);
      });

      test('one viewer, and thousands grouped as French writes them', () {
        expect(
          _text(
            wordFr({
              'msg-id': 'raid',
              'msg-param-displayName': 'Raider',
              'msg-param-viewerCount': '1',
              'system-msg': '1 raiders from Raider have joined!',
            }),
          ),
          'Raider lance un raid avec 1\u00a0spectateur\u202f!',
        );
        expect(
          _text(
            wordFr({
              'msg-id': 'raid',
              'msg-param-displayName': 'Raider',
              'msg-param-viewerCount': '1234',
              'system-msg': '1234 raiders from Raider have joined!',
            }),
          ),
          'Raider lance un raid avec 1\u202f234\u00a0spectateurs\u202f!',
        );
      });

      test("a name in other letters keeps its login, as Twitch's names do", () {
        final words = wordFr({
          'msg-id': 'raid',
          'login': 'raider',
          'msg-param-displayName': '레이더',
          'msg-param-viewerCount': '15',
          'system-msg': '15 raiders from 레이더 have joined!',
        });

        expect(_bold(words), ['레이더 (raider)']);
      });

      test("Twitch's sentence when a tag is missing", () {
        expect(
          _text(
            wordFr({
              'msg-id': 'raid',
              'msg-param-displayName': 'Raider',
              'system-msg': '15 raiders from Raider have joined!',
            }),
          ),
          '15 raiders from Raider have joined!',
        );
      });

      test('the English screen keeps Twitch\'s own sentence', () {
        expect(
          _text(
            userNoticeText(
              UserNotice.fromTags(IRCMessage.fromString(raidNotice).tags),
              channelName: 'Channel',
              l: lookupAppLocalizations(const Locale('en')),
            ),
          ),
          '15 raiders from Raider have joined!',
        );
      });
    });
  });

  group('kinds without a template', () {
    test('show Twitch\'s sentence with the leading name in bold', () {
      final words = _word({
        'msg-id': 'primepaidupgrade',
        'display-name': 'Upgrader',
        'system-msg': 'Upgrader converted from a Prime sub to a Tier 1 sub!',
      });

      expect(
        _text(words),
        'Upgrader converted from a Prime sub to a Tier 1 sub!',
      );
      expect(_bold(words), ['Upgrader']);
    });

    test('leave a sentence that does not start with the name plain', () {
      final words = _word({
        'msg-id': 'bitsbadgetier',
        'display-name': 'X',
        'system-msg': 'bits badge tier notification',
      });

      expect(_text(words), 'bits badge tier notification');
      expect(_bold(words), isEmpty);
    });

    test('do not bold a name that only starts the first word', () {
      final words = _word({
        'msg-id': 'bitsbadgetier',
        'display-name': 'X',
        'system-msg': 'Xavier reached a badge tier!',
      });

      expect(_bold(words), isEmpty);
    });

    test('keep the legacy anonymous gift kinds', () {
      expect(
        _text(_wordRaw(anonymousSubGiftLegacy)),
        'An anonymous user gifted a Tier 1 sub to Lucky!',
      );
    });

    test('give nothing when Twitch sent no sentence', () {
      expect(_word({'msg-id': 'announcement', 'display-name': 'X'}), isEmpty);
    });
  });

  group('richer sub notices', () {
    test('a sub paid months in advance says so', () {
      final words = _word({
        ..._sub(cumulative: '3'),
        'msg-param-multimonth-duration': '6',
        'msg-param-multimonth-tenure': '0',
      });
      expect(
        _text(words),
        'X subscribed at Tier 1. They’ve subscribed for 3 months! '
        'They paid for 6 months in advance.',
      );
    });

    test('a single month paid ahead adds nothing', () {
      expect(
        _text(_word({..._sub(), 'msg-param-multimonth-duration': '1'})),
        'X subscribed at Tier 1.',
      );
    });

    test('a month of a multi-month gift names the gifter', () {
      final tags = {
        ..._sub(),
        'msg-param-was-gifted': 'true',
        'msg-param-gift-months': '6',
        'msg-param-gift-month-being-redeemed': '2',
        'msg-param-gifter-name': 'Santa',
      };
      expect(
        _text(_word(tags)),
        'X subscribed at Tier 1. Month 2 of a 6-month gift sub from Santa.',
      );
      expect(
        _text(_word({...tags, 'msg-param-anon-gift': 'true'})),
        'X subscribed at Tier 1. '
        'Month 2 of a 6-month gift sub from an anonymous gifter.',
      );
      expect(
        _text(_word({...tags, 'msg-param-gift-month-being-redeemed': '9'})),
        'X subscribed at Tier 1.',
      );
    });

    test('a continued gift names both, in bold', () {
      final words = _wordRaw(giftPaidUpgrade);
      expect(
        _text(words),
        'Upgrader is continuing the gift sub they got from Gifter!',
      );
      expect(_bold(words), ['Upgrader', 'Gifter']);
      expect(
        _text(
          _word({'msg-id': 'anongiftpaidupgrade', 'display-name': 'Upgrader'}),
        ),
        'Upgrader is continuing the gift sub they got from an anonymous '
        'gifter!',
      );
    });

    test('a gift paid forward names the earlier gifter', () {
      final standard = {
        'msg-id': 'standardpayforward',
        'display-name': 'Kind',
        'msg-param-prior-gifter-display-name': 'First',
        'msg-param-prior-gifter-anonymous': 'false',
        'msg-param-recipient-display-name': 'Lucky',
        'system-msg': 'Kind is paying forward the Gift they got from First.',
      };
      expect(
        _text(_word(standard)),
        'Kind is paying forward the gift sub they got from First to Lucky!',
      );
      expect(_bold(_word(standard)), ['Kind', 'First', 'Lucky']);
      expect(
        _text(
          _word({
            ...standard,
            'msg-id': 'communitypayforward',
            'msg-param-recipient-display-name': '',
          }),
        ),
        'Kind is paying forward the gift sub they got from First to the '
        'community!',
      );
      expect(
        _text(_word({...standard, 'msg-param-prior-gifter-anonymous': 'true'})),
        'Kind is paying forward the Gift they got from First.',
      );
    });

    test('a sponsor’s bonus subs are counted', () {
      expect(
        _text(
          _word({
            'msg-id': 'giftsubbasematch',
            'msg-param-advertiser-name': 'Brand',
            'msg-param-gift-sub-match-quantity': '5',
            'system-msg': 'Brand matched.',
          }),
        ),
        'Brand added 5 bonus gift subs!',
      );
    });

    test('a shared reward counts the viewers it reaches', () {
      final words = _word({
        'msg-id': 'rewardgift',
        'display-name': 'Fan',
        'msg-param-trigger-type': 'CHEER',
        'msg-param-selected-count': '10',
        'msg-param-total-reward-count': '10',
        'system-msg': 'Fan’s Cheer shared rewards.',
      });
      expect(_text(words), 'Thanks to Fan, 10 other viewers get a reward!');
      expect(_bold(words), ['Fan']);
    });

    test('a watch streak and its points', () {
      expect(
        _text(
          _word({
            'msg-id': 'viewermilestone',
            'display-name': 'Fan',
            'msg-param-category': 'watch-streak',
            'msg-param-value': '7',
            'msg-param-copoReward': '1450',
            'system-msg': 'Fan watched 7 consecutive streams.',
          }),
        ),
        'Fan reached a 7-stream Watch Streak! They earned 1,450 channel '
        'points.',
      );
      expect(
        _text(
          _word({
            'msg-id': 'viewermilestone',
            'display-name': 'Fan',
            'msg-param-category': 'other',
            'msg-param-value': '7',
            'system-msg': 'Fan reached something.',
          }),
        ),
        'Fan reached something.',
      );
    });

    test('a charity donation with its amount and currency', () {
      final words = _word({
        'msg-id': 'charitydonation',
        'display-name': 'Fan',
        'msg-param-charity-name': 'Save\\sthe\\sKids',
        'msg-param-donation-amount': '500',
        'msg-param-exponent': '2',
        'msg-param-donation-currency': 'USD',
        'system-msg': 'Fan donated.',
      });
      expect(_text(words), r'Fan donated $5.00 to Save the Kids!');
      expect(_bold(words), ['Fan', 'Save the Kids']);
    });

    test('French words them too', () async {
      await initializeDateFormatting('fr');
      final l = lookupAppLocalizations(const Locale('fr'));
      final words = userNoticeText(
        UserNotice.fromTags(IRCMessage.fromString(giftPaidUpgrade).tags),
        channelName: 'Chaîne',
        l: l,
      );
      expect(
        _text(words),
        'Upgrader prolonge l’abonnement offert par Gifter !',
      );
    });

    test('French words a gift paid forward as a new gift', () {
      final l = lookupAppLocalizations(const Locale('fr'));
      final words = userNoticeText(
        UserNotice.fromTags({
          'msg-id': 'standardpayforward',
          'display-name': 'Kind',
          'msg-param-prior-gifter-display-name': 'First',
          'msg-param-recipient-display-name': 'Lucky',
          'system-msg': 'x',
        }),
        channelName: 'Chaîne',
        l: l,
      );
      expect(
        _text(words),
        'Kind offre à son tour un abonnement à Lucky, après celui offert par '
        'First\u202f!',
      );
    });

    test('the gifter’s total can be left out', () {
      final tags = _gift(senderCount: '12');
      expect(_text(_word(tags)), contains('12'));
      final hidden = userNoticeText(
        UserNotice.fromTags(tags),
        channelName: 'Channel',
        showGiftCount: false,
      );
      expect(_text(hidden), isNot(contains('12')));
    });
  });
}
