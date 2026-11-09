import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/live_together.dart';

import '../fixtures/live_together_payloads.dart';

void main() {
  group('LiveTogether.fromCostream', () {
    test('reads the organizer, the roster and the totals', () {
      final roster = LiveTogether.fromCostream(costreamResponse())!;

      expect(roster.kind, LiveTogetherKind.costream);
      expect(roster.host?.login, 'hostchannel');
      expect(roster.totalViewers, 48210);
      expect(roster.othersThan('1000').map((m) => m.login), [
        'hostchannel',
        'thirdone',
      ]);
      expect(roster.hiddenCount('1000'), 2);
    });

    test('is null when the stream is not shared', () {
      expect(LiveTogether.fromCostream(costreamNoneResponse), isNull);
      expect(LiveTogether.fromCostream(null), isNull);
      expect(LiveTogether.fromCostream({'errors': []}), isNull);
    });
  });

  group('LiveTogether.fromGuestStar', () {
    test('reads the guests and whether each one is live', () {
      final session = LiveTogether.fromGuestStar(guestStarResponse())!;

      expect(session.kind, LiveTogetherKind.guestStar);
      expect(session.host?.login, 'thischannel');
      expect(session.othersThan('1000').map((m) => m.login), [
        'guestone',
        'guesttwo',
      ]);
      expect(session.members.first.isLive, isFalse);
      expect(session.members.last.viewers, 210);
    });

    test('is null without a call or guests', () {
      expect(LiveTogether.fromGuestStar(guestStarNoneResponse), isNull);
    });
  });

  test('rejects malformed members', () {
    expect(LiveTogetherMember.tryParse({'id': 'x', 'login': 'a'}), isNull);
    expect(LiveTogetherMember.tryParse({'id': '1', 'login': 'A B'}), isNull);
    final plain = LiveTogetherMember.tryParse({
      'id': '1',
      'login': 'abc',
      'profileImageURL': 'http://insecure',
    })!;
    expect(plain.displayName, 'abc');
    expect(plain.imageUrl, isNull);
  });
}
