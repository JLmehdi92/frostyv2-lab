import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/models/badges.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/models/user.dart';
import 'package:onset/screens/channel/chat/widgets/user_card_info.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

ChatBadge _badge(String name) =>
    ChatBadge(name: name, url: 'https://x/$name.png', type: BadgeType.twitch);

IRCMessage _message(String tags) => IRCMessage.fromString(
  '@$tags :troll!troll@troll.tmi.twitch.tv PRIVMSG #chan :hi',
);

void main() {
  group('userCardBadges', () {
    final known = {
      'subscriber/12': _badge('Subscriber'),
      'founder/0': _badge('Founder'),
      'premium/1': _badge('Prime Gaming'),
      'moderator/1': _badge('Moderator'),
    };

    test('known badges in order, with subscriber months', () {
      final badges = userCardBadges(
        _message(
          'badges=moderator/1,subscriber/12,premium/1;badge-info=subscriber/14',
        ),
        known,
      );
      expect(badges.map((b) => b.label), [
        'Moderator',
        'Subscriber · 14 months',
        'Prime Gaming',
      ]);
    });

    test('a founder for 1 month', () {
      expect(
        userCardBadges(
          _message('badges=founder/0;badge-info=founder/1'),
          known,
        ).single.label,
        'Founder · 1 month',
      );
    });

    test('unknown badges, no badges, no message', () {
      expect(userCardBadges(_message('badges=glhf-pledge/1'), known), isEmpty);
      expect(userCardBadges(_message('badges='), known), isEmpty);
      expect(userCardBadges(null, known), isEmpty);
    });
  });

  group('UserCardInfo', () {
    late MockTwitchApi api;

    setUp(() => api = MockTwitchApi());

    Future<void> pump(WidgetTester tester, {required bool moderator}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserCardInfo(
              api: api,
              userId: '33',
              channelId: '11',
              showFollowAge: moderator,
              badges: const [],
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('account age to anyone, follow age to moderators', (
      tester,
    ) async {
      when(() => api.getUser(id: '33')).thenAnswer(
        (_) async => UserTwitch(
          '33',
          'troll',
          'Troll',
          '',
          createdAt: DateTime(2019, 3, 12, 12),
        ),
      );
      when(
        () => api.getFollowedAt(broadcasterId: '11', userId: '33'),
      ).thenAnswer((_) async => DateTime(2023, 1, 2, 12));

      await pump(tester, moderator: false);
      expect(find.text('Account created Mar 12, 2019'), findsOneWidget);
      expect(find.textContaining('Following since'), findsNothing);
      verifyNever(
        () => api.getFollowedAt(
          broadcasterId: any(named: 'broadcasterId'),
          userId: any(named: 'userId'),
        ),
      );

      await tester.pumpWidget(const SizedBox());
      await pump(tester, moderator: true);
      expect(find.text('Following since Jan 2, 2023'), findsOneWidget);
    });

    testWidgets('lines that cannot be read are left out', (tester) async {
      when(
        () => api.getUser(id: '33'),
      ).thenThrow(const ApiException('offline'));
      when(
        () => api.getFollowedAt(broadcasterId: '11', userId: '33'),
      ).thenAnswer((_) async => null);

      await pump(tester, moderator: true);
      expect(find.textContaining('Account created'), findsNothing);
      expect(find.textContaining('Following since'), findsNothing);
    });
  });
}
