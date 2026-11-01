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
        "X subscribed at Tier 1. They've subscribed for 14 months!",
      );
      expect(
        _text(_word(_sub(plan: 'Prime', cumulative: '14'))),
        "X subscribed with Prime. They've subscribed for 14 months!",
      );
      expect(
        _text(_word(_sub(plan: 'Custom', cumulative: '14'))),
        "X subscribed. They've subscribed for 14 months!",
      );
    });

    test('a shared streak adds the streak', () {
      expect(
        _text(_wordRaw(resubStreak)),
        "ReSubber subscribed at Tier 1. They've subscribed for 14 months, "
        'currently on a 5 month streak!',
      );
      expect(
        _text(
          _word(_sub(plan: 'Prime', cumulative: '3', streak: '2', share: true)),
        ),
        "X subscribed with Prime. They've subscribed for 3 months, "
        'currently on a 2 month streak!',
      );
      expect(
        _text(
          _word(
            _sub(plan: 'Custom', cumulative: '3', streak: '2', share: true),
          ),
        ),
        "X subscribed. They've subscribed for 3 months, "
        'currently on a 2 month streak!',
      );
    });

    test('a streak of one month still reads "month"', () {
      expect(
        _text(_word(_sub(cumulative: '1', streak: '1', share: true))),
        "X subscribed at Tier 1. They've subscribed for 1 month, "
        'currently on a 1 month streak!',
      );
    });

    test('a hidden streak is not shown', () {
      expect(
        _text(_wordRaw(resubHiddenStreak)),
        "ReSubber subscribed at Tier 1. They've subscribed for 14 months!",
      );
    });

    test('a zero streak is not shown', () {
      expect(
        _text(_word(_sub(cumulative: '14', streak: '0', share: true))),
        "X subscribed at Tier 1. They've subscribed for 14 months!",
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
        "G gifted a Tier 1 Sub to R! It's their first Gift Sub in the channel!",
      );
      expect(_bold(words), ['G', 'R']);
    });

    test('a later gift counts the gifts', () {
      expect(
        _text(_wordRaw(subGift)),
        "Gifter gifted a Tier 1 Sub to Lucky! They've given 3 Gift Subs in "
        'the channel!',
      );
    });

    test('a gift with no count, as inside a gift bomb, says nothing more', () {
      expect(_text(_word(_gift())), 'G gifted a Tier 1 Sub to R!');
      expect(
        _text(_word(_gift(senderCount: '0'))),
        'G gifted a Tier 1 Sub to R!',
      );
      expect(
        _text(_wordRaw(massGiftRecipients.first)),
        'BigGifter gifted a Tier 1 Sub to Viewer1!',
      );
    });

    test('a gift of an unknown plan leaves the tier out', () {
      expect(_text(_word(_gift(plan: 'Custom'))), 'G gifted a Sub to R!');
    });

    test('a multi-month gift names the months and the tier in bold', () {
      final words = _wordRaw(multiMonthGift);

      expect(
        _text(words),
        "Gifter gifted 3 months of Tier 1 to Lucky! It's their first Gift Sub "
        'in the channel!',
      );
      expect(_bold(words), ['Gifter', '3 months', 'Tier 1', 'Lucky']);
    });

    test('a multi-month gift counts the gifts after a space', () {
      expect(
        _text(_word(_gift(months: '6', senderCount: '2'))),
        "G gifted 6 months of Tier 1 to R! They've given 2 Gift Subs in the "
        'channel!',
      );
      expect(
        _text(_word(_gift(months: '6'))),
        'G gifted 6 months of Tier 1 to R!',
      );
    });

    test('a multi-month gift of an unknown plan reads as a Sub', () {
      final words = _word(_gift(plan: 'Custom', months: '3'));

      expect(_text(words), 'G gifted a 3 month Sub to R!');
      expect(_bold(words), ['G', '3 month', 'R']);
    });

    test('a single-month gift is not called multi-month', () {
      expect(_text(_word(_gift(months: '1'))), 'G gifted a Tier 1 Sub to R!');
    });

    test('an anonymous gift names the anonymous gifter account', () {
      expect(
        _text(_wordRaw(anonymousSubGift)),
        'AnAnonymousGifter gifted a Tier 1 Sub to Lucky!',
      );
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
        "G is gifting 5 Tier 1 Subs to Channel's community. It's their first "
        'Gift Sub in the channel!',
      );
      expect(_bold(words), ['G']);
    });

    test('a later gift bomb gives the total', () {
      expect(
        _text(_wordRaw(massGiftHeader, channelName: 'Streamer')),
        "BigGifter is gifting 5 Tier 1 Subs to Streamer's community. They've "
        'gifted a total of 50 in the channel!',
      );
    });

    test('a gift bomb with no count ends on an exclamation mark', () {
      expect(
        _text(_word(_bomb())),
        "G is gifting 5 Tier 1 Subs to Channel's community!",
      );
      expect(
        _text(_word(_bomb(senderCount: '0'))),
        "G is gifting 5 Tier 1 Subs to Channel's community!",
      );
    });

    test('a gift bomb of one is a single Sub', () {
      expect(
        _text(_word(_bomb(count: '1'))),
        "G is gifting 1 Tier 1 Sub to Channel's community!",
      );
    });

    test('a gift bomb of an unknown plan leaves the tier out', () {
      expect(
        _text(_word(_bomb(plan: 'Custom'))),
        "G is gifting 5 Subs to Channel's community!",
      );
    });

    test('an anonymous gift bomb comes from "An anonymous gifter"', () {
      final words = _wordRaw(anonymousMassGift);

      expect(
        _text(words),
        "An anonymous gifter is gifting 5 Tier 1 Subs to Channel's community!",
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
      final words = _wordRaw(giftPaidUpgrade);

      expect(
        _text(words),
        'Upgrader is continuing the Gift Sub they got from Gifter!',
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
}
