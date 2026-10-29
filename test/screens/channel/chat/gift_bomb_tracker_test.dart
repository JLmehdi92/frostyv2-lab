import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/models/user_notice.dart';
import 'package:onset/screens/channel/chat/gift_bomb_tracker.dart';

import '../../../fixtures/irc_messages.dart';

UserNotice _notice(String raw) => IRCMessage.fromString(raw).notice!;

/// A gift bomb header of [count] subs keyed [key].
UserNotice _header(String key, {int count = 5}) => UserNotice.fromTags({
  'msg-id': 'submysterygift',
  'display-name': 'G',
  'login': 'g',
  'msg-param-community-gift-id': key,
  'msg-param-mass-gift-count': '$count',
  'msg-param-sub-plan': '1000',
  'room-id': '12345',
});

/// One gift of the bomb keyed [key].
UserNotice _child(String key) => UserNotice.fromTags({
  'msg-id': 'subgift',
  'display-name': 'G',
  'login': 'g',
  'msg-param-community-gift-id': key,
  'msg-param-recipient-display-name': 'R',
  'msg-param-sub-plan': '1000',
  'room-id': '12345',
});

void main() {
  late GiftBombTracker tracker;

  setUp(() => tracker = GiftBombTracker());

  GiftBombDecision onNotice(UserNotice notice, {bool collapse = false}) =>
      tracker.onNotice(notice, collapse: collapse, channelId: '12345');

  group('like Twitch', () {
    test('shows the header and every gift of the bomb', () {
      final header = onNotice(_notice(massGiftHeader));
      expect(header.show, isTrue);
      expect(header.header?.key, '1234567890123456789');

      for (final raw in massGiftRecipients) {
        expect(onNotice(_notice(raw)).show, isTrue);
      }
      expect(tracker.bomb('1234567890123456789')?.received, 5);
    });

    test('describes the bomb from its header', () {
      final bomb = onNotice(_notice(massGiftHeader)).header!;

      expect(bomb.gifterName, 'BigGifter');
      expect(bomb.isAnonymous, isFalse);
      expect(bomb.count, 5);
      expect(bomb.tier, 'Tier 1');
      expect(bomb.received, 0);
    });

    test('marks an anonymous bomb', () {
      expect(onNotice(_notice(anonymousMassGift)).header!.isAnonymous, isTrue);
    });
  });

  group('collapsed', () {
    test('hides the gifts of a bomb whose header was shown', () {
      expect(onNotice(_notice(massGiftHeader), collapse: true).show, isTrue);

      for (final raw in massGiftRecipients) {
        expect(onNotice(_notice(raw), collapse: true).show, isFalse);
      }
      expect(tracker.bomb('1234567890123456789')?.received, 5);
    });

    test('shows a gift whose header has not arrived yet', () {
      expect(
        onNotice(_notice(massGiftRecipients.first), collapse: true).show,
        isTrue,
      );
      expect(onNotice(_notice(massGiftHeader), collapse: true).show, isTrue);
      expect(
        onNotice(_notice(massGiftRecipients[1]), collapse: true).show,
        isFalse,
      );
    });

    test('keys a bomb by its origin id when it has no community gift id', () {
      final header = UserNotice.fromTags(const {
        'msg-id': 'submysterygift',
        'display-name': 'G',
        'msg-param-mass-gift-count': '2',
        'msg-param-origin-id': '4e 29 ab',
      });
      final child = UserNotice.fromTags(const {
        'msg-id': 'subgift',
        'display-name': 'G',
        'msg-param-origin-id': '4e 29 ab',
        'msg-param-recipient-display-name': 'R',
      });

      expect(onNotice(header, collapse: true).header?.key, '4e 29 ab');
      expect(onNotice(child, collapse: true).show, isFalse);
    });

    test('never hides a single gift', () {
      expect(onNotice(_notice(subGift), collapse: true).show, isTrue);
    });

    test('remembers the latest 100 bombs only', () {
      for (var i = 0; i < 101; i++) {
        onNotice(_header('bomb-$i'), collapse: true);
      }

      expect(tracker.length, 100);
      expect(tracker.bomb('bomb-0'), isNull);
      expect(onNotice(_child('bomb-0'), collapse: true).show, isTrue);
      expect(onNotice(_child('bomb-100'), collapse: true).show, isFalse);
    });

    test('keeps a bomb that is still receiving gifts', () {
      onNotice(_header('busy'), collapse: true);
      for (var i = 0; i < 99; i++) {
        onNotice(_header('bomb-$i'), collapse: true);
      }
      // A gift of the oldest bomb makes it the most recent again.
      onNotice(_child('busy'), collapse: true);
      onNotice(_header('one-more'), collapse: true);

      expect(tracker.bomb('busy'), isNotNull);
      expect(tracker.bomb('bomb-0'), isNull);
    });
  });

  group('banner', () {
    test('a live bomb of five or more gets one', () {
      final decision = onNotice(_notice(massGiftHeader));

      expect(decision.banner, isNotNull);
      expect(decision.banner!.count, 5);
    });

    test('a bomb of four does not', () {
      expect(onNotice(_header('small', count: 4)).banner, isNull);
    });

    test('a bomb replayed from history does not', () {
      expect(onNotice(_notice(massGiftHeaderHistorical)).banner, isNull);
    });

    test('a bomb from another channel of a shared chat does not', () {
      expect(onNotice(_notice(massGiftHeaderShared)).banner, isNull);
    });

    test('a gift does not', () {
      onNotice(_notice(massGiftHeader));

      expect(onNotice(_notice(massGiftRecipients.first)).banner, isNull);
    });
  });

  group('bannerDuration', () {
    test("follows Twitch's thresholds", () {
      expect(bannerDuration(0), isNull);
      expect(bannerDuration(4), isNull);
      expect(bannerDuration(5), const Duration(seconds: 10));
      expect(bannerDuration(24), const Duration(seconds: 10));
      expect(bannerDuration(25), const Duration(seconds: 15));
      expect(bannerDuration(49), const Duration(seconds: 15));
      expect(bannerDuration(50), const Duration(seconds: 20));
      expect(bannerDuration(74), const Duration(seconds: 20));
      expect(bannerDuration(75), const Duration(seconds: 25));
      expect(bannerDuration(99), const Duration(seconds: 25));
      expect(bannerDuration(100), const Duration(seconds: 30));
      expect(bannerDuration(1000), const Duration(seconds: 30));
    });
  });

  group('shared chat', () {
    test("collapsing hides a partner gift bomb's gifts", () {
      final header = onNotice(_notice(sharedMassGiftHeader), collapse: true);
      expect(header.show, isTrue);
      expect(header.banner, isNull);

      expect(
        onNotice(_notice(sharedMassGiftRecipient), collapse: true).show,
        isFalse,
      );
    });
  });
}
