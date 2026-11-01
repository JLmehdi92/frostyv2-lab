import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/user.dart';
import 'package:onset/screens/channel/chat/chat_commands.dart';
import 'package:onset/screens/channel/chat/moderation.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

void main() {
  late MockTwitchApi api;
  late ChatModeration moderation;

  setUp(() {
    api = MockTwitchApi();
    moderation = ChatModeration(
      api: api,
      broadcasterId: '11',
      moderatorId: '22',
    );
    when(
      () => api.getUser(userLogin: 'troll'),
    ).thenAnswer((_) async => const UserTwitch('33', 'troll', 'Troll', ''));
  });

  test('/ban looks the login up and bans', () async {
    when(
      () => api.banUser(
        broadcasterId: '11',
        moderatorId: '22',
        userId: '33',
        reason: 'spam',
      ),
    ).thenAnswer((_) async {});

    final outcome = await moderation.run(const BanCommand('troll', 'spam'));

    expect(outcome, (ok: true, message: 'You banned Troll.'));
  });

  test('a known id skips the lookup', () async {
    when(
      () => api.banUser(
        broadcasterId: '11',
        moderatorId: '22',
        userId: '44',
        duration: const Duration(minutes: 10),
      ),
    ).thenAnswer((_) async {});

    final outcome = await moderation.run(
      const TimeoutCommand('troll', Duration(minutes: 10), ''),
      userId: '44',
    );

    expect(outcome.ok, isTrue);
    expect(outcome.message, 'You timed out troll for 10 minutes.');
    verifyNever(() => api.getUser(userLogin: any(named: 'userLogin')));
  });

  test('/unban and /untimeout', () async {
    when(
      () => api.unbanUser(broadcasterId: '11', moderatorId: '22', userId: '33'),
    ).thenAnswer((_) async {});

    expect(
      (await moderation.run(const UnbanCommand('troll'))).message,
      'You unbanned Troll.',
    );
    expect(
      (await moderation.run(
        const UnbanCommand('troll', timeout: true),
      )).message,
      'You removed the timeout of Troll.',
    );
  });

  test('/warn, /delete and /clear', () async {
    when(
      () => api.warnUser(
        broadcasterId: '11',
        moderatorId: '22',
        userId: '33',
        reason: 'be nice',
      ),
    ).thenAnswer((_) async {});
    when(
      () => api.deleteChatMessages(
        broadcasterId: '11',
        moderatorId: '22',
        messageId: any(named: 'messageId'),
      ),
    ).thenAnswer((_) async {});

    expect(
      (await moderation.run(const WarnCommand('troll', 'be nice'))).message,
      'You warned Troll.',
    );
    expect(
      (await moderation.run(const DeleteMessageCommand('abc'))).message,
      'Message deleted.',
    );
    expect(
      (await moderation.run(const ClearChatCommand())).message,
      'You cleared the chat.',
    );
    verify(
      () => api.deleteChatMessages(
        broadcasterId: '11',
        moderatorId: '22',
        messageId: 'abc',
      ),
    ).called(1);
    verify(
      () => api.deleteChatMessages(broadcasterId: '11', moderatorId: '22'),
    ).called(1);
  });

  test('room modes change only their own setting', () async {
    when(
      () => api.updateChatSettings(
        broadcasterId: any(named: 'broadcasterId'),
        moderatorId: any(named: 'moderatorId'),
        slowMode: any(named: 'slowMode'),
        slowModeWaitTime: any(named: 'slowModeWaitTime'),
        followerMode: any(named: 'followerMode'),
        followerModeDuration: any(named: 'followerModeDuration'),
        subscriberMode: any(named: 'subscriberMode'),
        emoteMode: any(named: 'emoteMode'),
        uniqueChatMode: any(named: 'uniqueChatMode'),
      ),
    ).thenAnswer((_) async {});

    expect(
      (await moderation.run(
        const ChatModeCommand(
          ChatMode.slow,
          on: true,
          duration: Duration(seconds: 30),
        ),
      )).message,
      'Slow mode on (30 seconds).',
    );
    verify(
      () => api.updateChatSettings(
        broadcasterId: '11',
        moderatorId: '22',
        slowMode: true,
        slowModeWaitTime: const Duration(seconds: 30),
      ),
    ).called(1);

    expect(
      (await moderation.run(
        const ChatModeCommand(
          ChatMode.followers,
          on: true,
          duration: Duration(days: 7),
        ),
      )).message,
      'Followers-only mode on (followers of 1 week).',
    );
    verify(
      () => api.updateChatSettings(
        broadcasterId: '11',
        moderatorId: '22',
        followerMode: true,
        followerModeDuration: const Duration(days: 7),
      ),
    ).called(1);

    expect(
      (await moderation.run(
        const ChatModeCommand(ChatMode.emoteOnly, on: false),
      )).message,
      'Emote-only mode off.',
    );
    verify(
      () => api.updateChatSettings(
        broadcasterId: '11',
        moderatorId: '22',
        emoteMode: false,
      ),
    ).called(1);
  });

  group('failures say why', () {
    test('offline', () async {
      when(
        () => api.deleteChatMessages(
          broadcasterId: '11',
          moderatorId: '22',
          messageId: 'abc',
        ),
      ).thenThrow(const NetworkException('No internet connection.'));

      expect(
        (await moderation.run(const DeleteMessageCommand('abc'))).message,
        "Couldn't delete the message: No internet connection.",
      );
    });

    test('an unknown login', () async {
      when(
        () => api.getUser(userLogin: 'ghost'),
      ).thenThrow(const NotFoundException('User does not exist'));

      final outcome = await moderation.run(const BanCommand('ghost', ''));

      expect(outcome, (
        ok: false,
        message: "Couldn't ban: no user named ghost",
      ));
    });

    test("Twitch's refusal", () async {
      when(
        () => api.banUser(broadcasterId: '11', moderatorId: '22', userId: '33'),
      ).thenThrow(const ApiException('The user is already banned.'));

      expect(
        (await moderation.run(const BanCommand('troll', ''))).message,
        "Couldn't ban: The user is already banned.",
      );
    });

    test('not a moderator, or missing the new scopes', () async {
      when(
        () =>
            api.unbanUser(broadcasterId: '11', moderatorId: '22', userId: '33'),
      ).thenThrow(const ApiException('Access denied', 403));
      expect(
        (await moderation.run(const UnbanCommand('troll'))).message,
        "Couldn't unban: Twitch says you can't moderate this chat.",
      );

      when(
        () =>
            api.unbanUser(broadcasterId: '11', moderatorId: '22', userId: '33'),
      ).thenThrow(const UnauthorizedException('Please log in'));
      expect(
        (await moderation.run(const UnbanCommand('troll'))).message,
        'Log in again to moderate from this app.',
      );
    });

    test("an unknown login is named in the failure's log", () async {
      when(
        () => api.getUser(userLogin: 'ghost'),
      ).thenThrow(const NotFoundException('User does not exist'));
      final logged = <String?>[];
      final previous = debugPrint;
      debugPrint = (message, {wrapWidth}) => logged.add(message);
      addTearDown(() => debugPrint = previous);

      await moderation.run(const BanCommand('ghost', ''));

      expect(logged.single, contains('ghost'));
    });

    group('on a French screen', () {
      setUp(() => L10n.use(const Locale('fr')));
      tearDown(() => L10n.use(const Locale('en')));

      test(
        "the failure's kind in French, then Twitch's short reason quoted",
        () async {
          when(
            () => api.banUser(
              broadcasterId: '11',
              moderatorId: '22',
              userId: '33',
            ),
          ).thenThrow(
            const ApiException(
              'The user is already banned.',
              400,
              null,
              ApiErrorKind.badRequest,
              'The user is already banned.',
            ),
          );

          expect(
            (await moderation.run(const BanCommand('troll', ''))).message,
            'Impossible de bannir. Requête non valide. Raison de '
            'Twitch\u00a0: «\u00a0The user is already banned.\u00a0»',
          );
        },
      );

      test("no quote without Twitch's words, nor for a long text", () async {
        when(
          () =>
              api.banUser(broadcasterId: '11', moderatorId: '22', userId: '33'),
        ).thenThrow(const NetworkException('No internet connection.'));
        expect(
          (await moderation.run(const BanCommand('troll', ''))).message,
          'Impossible de bannir. Pas de connexion Internet. Vérifiez votre '
          'réseau.',
        );

        when(
          () =>
              api.banUser(broadcasterId: '11', moderatorId: '22', userId: '33'),
        ).thenThrow(
          ApiException(
            'x',
            400,
            null,
            ApiErrorKind.badRequest,
            'x' * (maxQuotedTwitchReason + 1),
          ),
        );
        expect(
          (await moderation.run(const BanCommand('troll', ''))).message,
          'Impossible de bannir. Requête non valide.',
        );
      });

      test('the kind ends as a sentence, before the reason and alone; the '
          "reason too when Twitch's words have no full stop", () async {
        void refuse(ApiErrorKind kind, String? twitch) => when(
          () =>
              api.banUser(broadcasterId: '11', moderatorId: '22', userId: '33'),
        ).thenThrow(ApiException('x', 400, null, kind, twitch));

        // A kind with no full stop (a caption on the error screens).
        refuse(ApiErrorKind.forbidden, null);
        expect(
          (await moderation.run(const BanCommand('troll', ''))).message,
          'Impossible de bannir. Accès refusé. Autorisations insuffisantes.',
        );
        refuse(ApiErrorKind.forbidden, 'Verify your phone number first.');
        expect(
          (await moderation.run(const BanCommand('troll', ''))).message,
          'Impossible de bannir. Accès refusé. Autorisations insuffisantes. '
          'Raison de Twitch\u00a0: «\u00a0Verify your phone number '
          'first.\u00a0»',
        );
        refuse(ApiErrorKind.unknown, 'You may not ban');
        expect(
          (await moderation.run(const BanCommand('troll', ''))).message,
          'Impossible de bannir. Une erreur inattendue est survenue. Raison de '
          'Twitch\u00a0: «\u00a0You may not ban\u00a0».',
        );
        // A kind that ends with its own punctuation keeps it alone.
        refuse(ApiErrorKind.sendTimeout, null);
        expect(
          (await moderation.run(const BanCommand('troll', ''))).message,
          'Impossible de bannir. L’envoi a pris trop de temps. Réessayez.',
        );
      });

      test('an unknown login, as a sentence', () async {
        when(
          () => api.getUser(userLogin: 'ghost'),
        ).thenThrow(const NotFoundException('User does not exist'));

        expect(
          (await moderation.run(const BanCommand('ghost', ''))).message,
          'Impossible de bannir. Aucun utilisateur nommé ghost.',
        );
      });
    });

    test('anything else never escapes', () async {
      when(
        () => api.deleteChatMessages(broadcasterId: '11', moderatorId: '22'),
      ).thenThrow(StateError('boom'));

      expect(await moderation.run(const ClearChatCommand()), (
        ok: false,
        message: "Couldn't clear the chat (unexpected error).",
      ));
    });
  });
}
