import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/models/user.dart';
import 'package:onset/screens/channel/chat/chat_commands.dart';
import 'package:onset/screens/channel/chat/moderation.dart';

class _MockTwitchApi extends Mock implements TwitchApi {}

void main() {
  late _MockTwitchApi api;
  final calls = <(String, bool)>[];

  setUp(() {
    api = _MockTwitchApi();
    calls.clear();
    when(
      () => api.getUser(userLogin: 'kai'),
    ).thenAnswer((_) async => const UserTwitch('33', 'kai', 'Kai', ''));
  });

  ChatModeration as(
    String moderatorId, {
    ViewerActionOutcome outcome = ViewerActionOutcome.done,
    bool withSetter = true,
  }) => ChatModeration(
    api: api,
    broadcasterId: '11',
    moderatorId: moderatorId,
    setLeadModerator: withSetter
        ? (userId, {required granted}) async {
            calls.add((userId, granted));
            return outcome;
          }
        : null,
  );

  group('parsing', () {
    test('/leadmod and /unleadmod take one user', () {
      final add = parseChatCommand('/leadmod @Kai');
      expect(add, isA<LeadModCommand>());
      expect((add as LeadModCommand).login, 'kai');
      expect(add.granted, isTrue);
      final remove = parseChatCommand('/unleadmod kai');
      expect((remove as LeadModCommand).granted, isFalse);
      expect(parseChatCommand('/leadmod'), isA<UnsupportedCommand>());
      expect(parseChatCommand('/leadmod a b'), isA<UnsupportedCommand>());
    });

    test('both are broadcaster only and suggested to moderators', () {
      expect(
        broadcasterOnlyName(const LeadModCommand('a', granted: true)),
        'leadmod',
      );
      expect(
        broadcasterOnlyName(const LeadModCommand('a', granted: false)),
        'unleadmod',
      );
      expect(matchCommands('/lead', moderator: true).map((c) => c.name), [
        'leadmod',
      ]);
      expect(matchCommands('/lead'), isEmpty);
    });
  });

  group('running', () {
    test('the broadcaster adds and removes a lead moderator', () async {
      expect(await as('11').run(const LeadModCommand('kai', granted: true)), (
        ok: true,
        message: 'Kai is now a lead moderator.',
      ));
      expect(await as('11').run(const LeadModCommand('kai', granted: false)), (
        ok: true,
        message: 'Kai is no longer a lead moderator.',
      ));
      expect(calls, [('33', true), ('33', false)]);
    });

    test('a moderator is told only the broadcaster can', () async {
      final outcome = await as(
        '22',
      ).run(const LeadModCommand('kai', granted: true));
      expect(outcome.ok, isFalse);
      expect(calls, isEmpty);
    });

    test('a refusal and a missing web session are said', () async {
      expect(
        await as(
          '11',
          outcome: ViewerActionOutcome.refused,
        ).run(const LeadModCommand('kai', granted: true)),
        (ok: false, message: 'Twitch declined this.'),
      );
      expect(
        await as(
          '11',
          withSetter: false,
        ).run(const LeadModCommand('kai', granted: true)),
        (ok: false, message: 'Log in again to do this from ONSET.'),
      );
    });
  });
}
