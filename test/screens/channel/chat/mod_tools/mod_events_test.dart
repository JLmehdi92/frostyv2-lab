import 'package:flutter_test/flutter_test.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/channel/chat/mod_tools/mod_action_text.dart';
import 'package:onset/screens/channel/chat/mod_tools/mod_events.dart';

void main() {
  final now = DateTime.utc(2026, 11, 7, 10);

  Map<String, Object?> moderate(
    String action, [
    Map<String, Object?>? target,
  ]) => {
    'action': action,
    'moderator_user_login': 'mira',
    'moderator_user_name': 'Mira',
    _objectOf(action): ?target,
  };

  group('channel.moderate', () {
    test('a timeout keeps its target, reason and end', () {
      final entry = parseModerateEvent(
        moderate('timeout', {
          'user_id': '33',
          'user_login': 'ana',
          'user_name': 'Ana',
          'reason': 'spam',
          'expires_at': '2026-11-07T10:10:00Z',
        }),
        now: now,
      )!;
      expect(entry.userId, '33');
      expect(entry.timeoutLength, const Duration(minutes: 10));
      expect(
        modActionLine(L10n.english, entry),
        'Mira timed out Ana for 10 minutes. Reason: “spam”.',
      );
    });

    test('a timeout a few milliseconds short still reads as whole minutes', () {
      expect(
        roundedTimeoutSeconds(const Duration(minutes: 9, seconds: 59)),
        600,
      );
      expect(roundedTimeoutSeconds(const Duration(seconds: 29)), 29);
    });

    test('mode, term and unban request actions read as sentences', () {
      String line(String action, [Map<String, Object?>? target]) =>
          modActionLine(
            L10n.english,
            parseModerateEvent(moderate(action, target), now: now)!,
          );
      expect(line('slow'), 'Mira turned slow mode on.');
      expect(line('emoteonlyoff'), 'Mira turned emote-only mode off.');
      expect(line('add_blocked_term'), 'Mira added a blocked term.');
      expect(
        line('approve_unban_request', {
          'user_login': 'ana',
          'user_name': 'Ana',
          'moderator_message': 'ok',
        }),
        'Mira approved the unban request from Ana. Reason: “ok”.',
      );
      expect(line('vip', {'user_login': 'kai'}), 'Mira made kai a VIP.');
    });

    test('unknown, shared and malformed actions are dropped', () {
      expect(parseModerateEvent(moderate('shared_chat_ban'), now: now), isNull);
      expect(parseModerateEvent(moderate('mystery'), now: now), isNull);
      expect(parseModerateEvent(moderate('ban'), now: now), isNull);
      expect(
        parseModerateEvent({'action': 'clear'}, now: now),
        isNull,
        reason: 'no moderator',
      );
      expect(parseModerateEvent({'action': 42}, now: now), isNull);
    });

    test('a timeout without an end still reads', () {
      final entry = parseModerateEvent(
        moderate('timeout', {'user_login': 'ana'}),
        now: now,
      )!;
      expect(modActionLine(L10n.english, entry), 'Mira timed out ana.');
    });
  });

  group('AutoMod', () {
    test('a held message and its update', () {
      final held = parseHeldMessage({
        'message_id': 'm-1',
        'user_id': '33',
        'user_login': 'ana',
        'user_name': 'Ana',
        'message': {'text': 'bad words', 'fragments': []},
        'reason': 'automod',
        'automod': {'category': 'swearing', 'level': 3},
        'held_at': '2026-11-07T10:00:00Z',
      })!;
      expect(held.text, 'bad words');
      expect(held.level, 3);
      expect(held.isPending, isTrue);
      final update = parseHeldMessageUpdate({
        'message_id': 'm-1',
        'status': 'Approved',
      });
      expect(update?.status, HeldMessageStatus.approved);
      expect(parseHeldMessageUpdate({'message_id': 'm-1'}), isNull);
      expect(parseHeldMessage({'message_id': 'm-2'}), isNull);
    });
  });

  group('shoutouts', () {
    final data = {
      'broadcasterUserID': '11',
      'targetLogin': 'Kai',
      'targetUserID': '33',
      'targetUserDisplayName': 'Kai',
      'shoutoutID': 's-1',
    };

    test('a shoutout of this channel is read', () {
      final shoutout = parseShoutout('create', data, channelId: '11')!;
      expect(shoutout.targetLogin, 'kai');
      expect(shoutout.targetName, 'Kai');
    });

    test('another channel, another type or a bad login is dropped', () {
      expect(parseShoutout('create', data, channelId: '12'), isNull);
      expect(parseShoutout('update', data, channelId: '11'), isNull);
      expect(
        parseShoutout('create', {
          ...data,
          'targetLogin': 'a b',
        }, channelId: '11'),
        isNull,
      );
      expect(
        parseShoutout('create', {
          ...data,
          'targetUserID': 'x',
        }, channelId: '11'),
        isNull,
      );
    });
  });
}

String _objectOf(String action) => switch (action) {
  'approve_unban_request' || 'deny_unban_request' => 'unban_request',
  _ => action,
};
