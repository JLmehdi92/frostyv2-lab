import 'package:flutter_test/flutter_test.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/channel/chat/chat_commands.dart';

void main() {
  test('messages and /me go out as they are', () {
    expect(parseChatCommand('hello'), isA<SendAsIs>());
    expect(parseChatCommand('/me waves'), isA<SendAsIs>());
    expect(parseChatCommand('.me waves'), isA<SendAsIs>());
    expect(parseChatCommand('...ok'), isA<SendAsIs>());
    expect(parseChatCommand('. hello'), isA<SendAsIs>());
  });

  test('/color takes a Twitch name or a hex', () {
    expect(
      (parseChatCommand('/color HotPink') as ColorCommand).color,
      'hot_pink',
    );
    expect(
      (parseChatCommand('/color blue_violet') as ColorCommand).color,
      'blue_violet',
    );
    expect(
      (parseChatCommand('/color #ff00aa') as ColorCommand).color,
      '#FF00AA',
    );
    expect(
      (parseChatCommand('/color ff00aa') as ColorCommand).color,
      '#FF00AA',
    );
    expect(parseChatCommand('/color purple'), isA<UnsupportedCommand>());
    expect(parseChatCommand('/color'), isA<UnsupportedCommand>());
  });

  test('/block and /unblock take one login', () {
    expect(
      (parseChatCommand('/block @SomeOne') as BlockCommand).login,
      'someone',
    );
    expect(
      (parseChatCommand('/unblock someone') as UnblockCommand).login,
      'someone',
    );
    expect(parseChatCommand('/block'), isA<UnsupportedCommand>());
    expect(parseChatCommand('/block a b'), isA<UnsupportedCommand>());
    expect(parseChatCommand('/block a-b'), isA<UnsupportedCommand>());
  });

  test('help, whispers, moderator and unknown commands', () {
    expect(parseChatCommand('/help'), isA<HelpCommand>());
    final whisper = parseChatCommand('/w @Friend hi  there') as WhisperCommand;
    expect(whisper.login, 'friend');
    expect(whisper.message, 'hi there');
    expect(parseChatCommand('/whisper friend yo'), isA<WhisperCommand>());
    expect(
      (parseChatCommand('/w friend') as UnsupportedCommand).text(L10n.english),
      'Usage: /\u2060w <user> <message>',
    );
    expect(parseChatCommand('/w'), isA<UnsupportedCommand>());
    expect(
      (parseChatCommand('/pin abc') as UnsupportedCommand).text(L10n.english),
      contains('not available'),
    );
    expect(
      (parseChatCommand('/dance') as UnsupportedCommand).text(L10n.english),
      contains('/help'),
    );
  });

  group('moderator commands', () {
    test('/ban takes a user and an optional reason', () {
      final ban = parseChatCommand('/ban @Troll spam  links') as BanCommand;
      expect(ban.login, 'troll');
      expect(ban.reason, 'spam links');
      expect((parseChatCommand('/ban troll') as BanCommand).reason, '');
      expect(
        (parseChatCommand('/ban') as UnsupportedCommand).text(L10n.english),
        'Usage: /\u2060ban <user> [reason]',
      );
      expect(parseChatCommand('/ban a-b'), isA<UnsupportedCommand>());
    });

    test('/timeout reads a length, 10 minutes by default', () {
      TimeoutCommand timeout(String text) =>
          parseChatCommand(text) as TimeoutCommand;
      expect(timeout('/timeout troll').duration, const Duration(minutes: 10));
      expect(
        timeout('/timeout troll 30').duration,
        const Duration(seconds: 30),
      );
      expect(timeout('/timeout troll 5m').duration, const Duration(minutes: 5));
      expect(timeout('/timeout troll 2H').duration, const Duration(hours: 2));
      expect(timeout('/timeout troll 1d').duration, const Duration(days: 1));
      expect(timeout('/timeout troll 2w').duration, const Duration(days: 14));
      // Not a length: the reason, with the default length.
      final reasoned = timeout('/timeout troll calm down');
      expect(reasoned.duration, const Duration(minutes: 10));
      expect(reasoned.reason, 'calm down');
      expect(timeout('/timeout troll 1h spam').reason, 'spam');
      expect(
        (parseChatCommand('/timeout troll 3w') as UnsupportedCommand).text(
          L10n.english,
        ),
        contains('2 weeks'),
      );
      expect(parseChatCommand('/timeout troll 0'), isA<UnsupportedCommand>());
      // A mistyped length is refused, not taken as the reason.
      for (final typo in ['5min', '1h30m', '1.5h']) {
        expect(
          (parseChatCommand('/timeout troll $typo') as UnsupportedCommand).text(
            L10n.english,
          ),
          contains('Unknown length'),
        );
      }
      expect(timeout('/timeout troll 1W').duration, const Duration(days: 7));
      // Too long to be a timeout, not a reason.
      expect(
        parseChatCommand('/timeout troll 99999999999999999999mo'),
        isA<UnsupportedCommand>(),
      );
      expect(parseChatCommand('/timeout'), isA<UnsupportedCommand>());
    });

    test('/unban and /untimeout take one user', () {
      expect((parseChatCommand('/unban Troll') as UnbanCommand).login, 'troll');
      final untimeout = parseChatCommand('/untimeout troll') as UnbanCommand;
      expect(untimeout.timeout, isTrue);
      expect(parseChatCommand('/unban'), isA<UnsupportedCommand>());
      expect(parseChatCommand('/unban a b'), isA<UnsupportedCommand>());
    });

    test('/warn needs a reason', () {
      final warn = parseChatCommand('/warn troll no spam') as WarnCommand;
      expect(warn.login, 'troll');
      expect(warn.reason, 'no spam');
      expect(
        (parseChatCommand('/warn troll') as UnsupportedCommand).text(
          L10n.english,
        ),
        'Usage: /\u2060warn <user> <reason>',
      );
    });

    test('/delete takes a message id, /clear nothing', () {
      expect(
        (parseChatCommand('/delete 9d4b2624-caa6-41ca') as DeleteMessageCommand)
            .messageId,
        '9d4b2624-caa6-41ca',
      );
      expect(parseChatCommand('/delete nope!'), isA<UnsupportedCommand>());
      expect(parseChatCommand('/clear'), isA<ClearChatCommand>());
    });

    test('room modes', () {
      ChatModeCommand mode(String text) =>
          parseChatCommand(text) as ChatModeCommand;
      expect(mode('/slow').mode, ChatMode.slow);
      expect(mode('/slow').on, isTrue);
      expect(mode('/slow').duration, const Duration(seconds: 30));
      expect(mode('/slow 10').duration, const Duration(seconds: 10));
      expect(mode('/slowoff').on, isFalse);
      expect(parseChatCommand('/slow 2'), isA<UnsupportedCommand>());
      expect(parseChatCommand('/slow 121'), isA<UnsupportedCommand>());
      expect(mode('/followers').duration, Duration.zero);
      expect(mode('/followers 10').duration, const Duration(minutes: 10));
      expect(mode('/followers 1w').duration, const Duration(days: 7));
      expect(mode('/followers 3mo').duration, const Duration(days: 90));
      expect(parseChatCommand('/followers 4mo'), isA<UnsupportedCommand>());
      // Whole minutes only.
      expect(parseChatCommand('/followers 30s'), isA<UnsupportedCommand>());
      expect(parseChatCommand('/followers 90s'), isA<UnsupportedCommand>());
      expect(mode('/followers 120s').duration, const Duration(minutes: 2));
      expect(parseChatCommand('/followers abc'), isA<UnsupportedCommand>());
      expect(parseChatCommand('/slow abc'), isA<UnsupportedCommand>());
      expect(parseChatCommand('/slow 1 2'), isA<UnsupportedCommand>());
      expect(mode('/r9kbeta').on, isTrue);
      expect(parseChatCommand('/clear now'), isA<UnsupportedCommand>());
      expect(mode('/followersoff').on, isFalse);
      expect(mode('/subscribers').mode, ChatMode.subscribers);
      expect(mode('/subscribersoff').on, isFalse);
      expect(mode('/emoteonly').mode, ChatMode.emoteOnly);
      expect(mode('/emoteonlyoff').on, isFalse);
      expect(mode('/uniquechat').mode, ChatMode.uniqueChat);
      expect(mode('/r9kbetaoff').mode, ChatMode.uniqueChat);
      expect(mode('/uniquechatoff').on, isFalse);
      expect(parseChatCommand('/emoteonly now'), isA<UnsupportedCommand>());
    });
  });

  test('moderator commands are suggested to moderators only', () {
    expect(matchCommands('/ba').map((c) => c.name), isEmpty);
    expect(matchCommands('/ba', moderator: true).map((c) => c.name), ['ban']);
    expect(
      matchCommands('/', moderator: true),
      hasLength(kChatCommands.length + kModeratorChatCommands.length),
    );
  });

  test('suggestions while the command name is typed', () {
    expect(matchCommands('/'), hasLength(kChatCommands.length));
    expect(matchCommands('/co').map((c) => c.name), ['color']);
    expect(matchCommands('/BL').map((c) => c.name), ['block']);
    expect(matchCommands('/color '), isEmpty);
    expect(matchCommands('hello /co'), isEmpty);
    expect(matchCommands('/zzz'), isEmpty);
  });

  test('/user takes one login and /disconnect takes nothing', () {
    expect(
      (parseChatCommand('/user @Friend_1') as UserCardCommand).login,
      'friend_1',
    );
    expect(parseChatCommand('/disconnect'), isA<DisconnectCommand>());
    for (final line in ['/user', '/user a b', '/disconnect now']) {
      final command = parseChatCommand(line);
      expect(command, isA<UnsupportedCommand>(), reason: line);
      expect(
        (command as UnsupportedCommand).problem,
        isA<UsageProblem>(),
        reason: line,
      );
    }
    expect(matchCommands('/us').map((c) => c.name), ['user']);
    expect(matchCommands('/dis').map((c) => c.name), ['disconnect']);
  });
}
