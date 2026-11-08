import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/screens/channel/chat/chat_restrictions.dart';

final _now = DateTime.utc(2026, 10, 13, 20);

ChatRestriction? _for({
  ROOMSTATE room = const ROOMSTATE(),
  bool privileged = false,
  bool subscriber = false,
  bool banned = false,
  DateTime? timedOutUntil,
  DateTime? lastSentAt,
}) => chatRestriction(
  room: room,
  privileged: privileged,
  subscriber: subscriber,
  now: _now,
  banned: banned,
  timedOutUntil: timedOutUntil,
  lastSentAt: lastSentAt,
);

void main() {
  test('nothing in an open chat', () {
    expect(_for(), isNull);
  });

  test('a ban or timeout comes first and locks the input', () {
    final banned = _for(banned: true, room: const ROOMSTATE(emoteOnly: '1'))!;
    expect(banned.kind, ChatRestrictionKind.banned);
    // Twitch says nothing on an unban: a send is how the viewer finds out.
    expect(banned.blocksInput, isFalse);
    expect(banned.showsBar, isTrue);

    final timedOut = _for(
      timedOutUntil: _now.add(const Duration(minutes: 10)),
    )!;
    expect(timedOut.kind, ChatRestrictionKind.timedOut);
    expect(
      timedOut.describe(const Duration(minutes: 4, seconds: 5)),
      'You’re timed out · 4:05',
    );
    // Over: nothing left.
    expect(_for(timedOutUntil: _now), isNull);
  });

  test('slow mode waits after a message, except for the privileged', () {
    const room = ROOMSTATE(slowMode: '30');
    final wait = _for(
      room: room,
      lastSentAt: _now.subtract(const Duration(seconds: 10)),
    )!;
    expect(wait.kind, ChatRestrictionKind.slowMode);
    expect(wait.until, _now.add(const Duration(seconds: 20)));
    expect(wait.describe(const Duration(seconds: 20)), contains('20s'));
    expect(
      _for(
        room: room,
        privileged: true,
        lastSentAt: _now.subtract(const Duration(seconds: 10)),
      ),
      isNull,
    );
    expect(_for(room: room), isNull);
  });

  test('room modes inform without locking', () {
    expect(
      _for(room: const ROOMSTATE(emoteOnly: '1'))!.kind,
      ChatRestrictionKind.emoteOnly,
    );
    expect(
      _for(room: const ROOMSTATE(subMode: '1'))!.kind,
      ChatRestrictionKind.subscribersOnly,
    );
    expect(_for(room: const ROOMSTATE(subMode: '1'), subscriber: true), isNull);
    final followers = _for(room: const ROOMSTATE(followersOnly: '10'))!;
    expect(followers.blocksInput, isFalse);
    expect(followers.describe(null), 'Followers-only · 10m');
    // The follow age in its largest whole unit, never raw minutes.
    String ageOf(String minutes, [AppLocalizations? l]) =>
        _for(room: ROOMSTATE(followersOnly: minutes))!.describe(null, l);
    expect(ageOf('180'), 'Followers-only · 3h');
    expect(ageOf('90'), 'Followers-only · 1h 30m');
    expect(ageOf('2880'), 'Followers-only · 2 days');
    expect(ageOf('10080'), 'Followers-only · 7 days');
    expect(ageOf('43200'), 'Followers-only · 1 month');
    expect(ageOf('129600'), 'Followers-only · 3 months');
    final french = lookupAppLocalizations(const Locale('fr'));
    expect(ageOf('10', french), 'Followers depuis 10\u00a0min');
    expect(ageOf('10080', french), 'Followers depuis 7\u00a0jours');
    expect(
      _for(room: const ROOMSTATE(followersOnly: '0'))!.describe(null),
      'Followers-only chat',
    );
  });

  test('only the viewer\'s own CLEARCHAT counts', () {
    IRCMessage clear(String tags) => IRCMessage.fromString(
      '@$tags :tmi.twitch.tv CLEARCHAT #channel :someone',
    );
    expect(
      ownClearChat(
        clear('ban-duration=600;target-user-id=7'),
        ownUserId: '7',
        now: _now,
      ),
      (banned: false, until: _now.add(const Duration(minutes: 10))),
    );
    expect(ownClearChat(clear('target-user-id=7'), ownUserId: '7', now: _now), (
      banned: true,
      until: null,
    ));
    expect(
      ownClearChat(clear('target-user-id=8'), ownUserId: '7', now: _now),
      isNull,
    );
    expect(
      ownClearChat(clear('target-user-id=7'), ownUserId: null, now: _now),
      isNull,
    );
  });

  test('a timeout counts from when Twitch sent it; history is ignored', () {
    IRCMessage clear(String tags) => IRCMessage.fromString(
      '@$tags :tmi.twitch.tv CLEARCHAT #channel :someone',
    );
    final sent = _now.subtract(const Duration(minutes: 9, seconds: 50));
    expect(
      ownClearChat(
        clear(
          'ban-duration=600;target-user-id=7;'
          'tmi-sent-ts=${sent.millisecondsSinceEpoch}',
        ),
        ownUserId: '7',
        now: _now,
      ),
      (banned: false, until: _now.add(const Duration(seconds: 10))),
    );
    final over = _now.subtract(const Duration(minutes: 11));
    expect(
      ownClearChat(
        clear(
          'ban-duration=600;target-user-id=7;'
          'tmi-sent-ts=${over.millisecondsSinceEpoch}',
        ),
        ownUserId: '7',
        now: _now,
      ),
      isNull,
    );
    expect(
      ownClearChat(
        clear('historical=1;target-user-id=7'),
        ownUserId: '7',
        now: _now,
      ),
      isNull,
    );
  });

  test('waits read like a clock', () {
    expect(formatWait(const Duration(seconds: 9)), '9s');
    expect(formatWait(const Duration(minutes: 1, seconds: 2)), '1:02');
    expect(
      formatWait(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
    expect(formatWait(const Duration(seconds: -5)), '0s');
  });

  group('a refusal tied to the account or the channel', () {
    test('each one Twitch sends is named', () {
      expect(
        accountRestrictionOf('msg_verified_email'),
        ChatRestrictionKind.verifiedEmail,
      );
      expect(
        accountRestrictionOf('msg_requires_verified_phone_number'),
        ChatRestrictionKind.verifiedPhone,
      );
      expect(
        accountRestrictionOf('msg_banned_email_alias'),
        ChatRestrictionKind.emailAliasBanned,
      );
      expect(
        accountRestrictionOf('msg_banned_phone_number_alias'),
        ChatRestrictionKind.phoneAliasBanned,
      );
      expect(
        accountRestrictionOf('msg_user_has_consequence'),
        ChatRestrictionKind.accountRestricted,
      );
      expect(
        accountRestrictionOf('msg_channel_suspended'),
        ChatRestrictionKind.channelRestricted,
      );
      expect(
        accountRestrictionOf('msg_followersonly_zero'),
        ChatRestrictionKind.followRequired,
      );
      expect(accountRestrictionOf('msg_warned'), ChatRestrictionKind.warned);
      expect(accountRestrictionOf('msg_slowmode'), isNull);
      expect(accountRestrictionOf('msg_duplicate'), isNull);
    });

    test('shows its bar after a ban or timeout, before the room modes', () {
      final refused = chatRestriction(
        room: const ROOMSTATE(emoteOnly: '1'),
        privileged: false,
        subscriber: false,
        now: _now,
        refusedFor: ChatRestrictionKind.verifiedPhone,
      )!;
      expect(refused.kind, ChatRestrictionKind.verifiedPhone);
      expect(refused.showsBar, isTrue);
      expect(refused.blocksInput, isFalse);

      final banned = chatRestriction(
        room: const ROOMSTATE(),
        privileged: false,
        subscriber: false,
        now: _now,
        banned: true,
        refusedFor: ChatRestrictionKind.verifiedPhone,
      )!;
      expect(banned.kind, ChatRestrictionKind.banned);
    });

    test('says why in each language, and links verification', () {
      final english = lookupAppLocalizations(const Locale('en'));
      final french = lookupAppLocalizations(const Locale('fr'));
      const email = ChatRestriction(ChatRestrictionKind.verifiedEmail);
      expect(email.describe(null, english), 'Verified email required');
      expect(email.describe(null, french), 'E-mail vérifié requis');
      expect(email.helpUrl, kTwitchSecuritySettingsUrl);
      const follow = ChatRestriction(ChatRestrictionKind.followRequired);
      expect(follow.describe(null, french), 'Suivez la chaîne');
      expect(follow.helpUrl, isNull);
    });
  });
}
