import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_auth_interceptor.dart';
import 'package:onset/apis/twitch_chat_history_service.dart';
import 'package:onset/constants.dart';
import 'package:onset/models/chat_history.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';

const _gql = 'https://gql.twitch.tv/gql';

class _MockAuthStore extends Mock implements AuthStore {}

/// One `recentChatMessages` entry as Twitch's web document selects it.
Map<String, Object?> historyEntry({
  String id = 'msg-1',
  String sentAt = '2026-10-30T12:00:00.123Z',
  String? deletedAt,
  Object? sender = const {
    'id': '111',
    'login': 'viewer',
    'displayName': 'Viewer',
    'chatColor': '#00FF00',
  },
  String? senderChatColor = '#FF0000',
  Object? badges = const [
    {'setID': 'subscriber', 'version': '12'},
    {'setID': 'moderator', 'version': '1'},
  ],
  Object? fragments,
  String text = 'hello Kappa',
  Object? sourceChannel,
  Object? parentMessage,
  Object? threadParentMessage,
}) => {
  'id': id,
  'sentAt': sentAt,
  'deletedAt': deletedAt,
  'content': {
    'text': text,
    'fragments':
        fragments ??
        [
          {'text': 'hello ', 'content': null},
          {
            'text': 'Kappa',
            'content': {'__typename': 'Emote', 'id': '25'},
          },
        ],
  },
  'sender': sender,
  'senderBadges': badges,
  'senderChatColor': senderChatColor,
  'sourceChannel': sourceChannel,
  'parentMessage': parentMessage,
  'threadParentMessage': threadParentMessage,
};

Map<String, Object?> historyBody(List<Object?> messages) => {
  'data': {
    'channel': {'recentChatMessages': messages},
  },
};

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late TwitchChatHistoryService service;
  late List<RequestOptions> requests;

  setUp(() {
    dio = Dio(BaseOptions());
    adapter = DioAdapter(dio: dio);
    requests = [];
    // The app's own Helix session on the same Dio, as if the service were
    // ever wired to the shared client: it must still not reach GQL.
    final auth = _MockAuthStore();
    when(() => auth.headersTwitch).thenReturn({
      'Authorization': 'Bearer helix-session-token',
      'Client-Id': 'onset-fork-client-id',
    });
    dio.interceptors
      ..add(TwitchAuthInterceptor(auth))
      ..add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.next(options);
          },
        ),
      );
    service = TwitchChatHistoryService(dio);
  });

  void reply(Object? body, {int status = 200, Duration? delay}) =>
      adapter.onPost(
        _gql,
        (server) => server.reply(status, body, delay: delay),
        data: Matchers.any,
      );

  Future<List<ChatHistoryMessage>> load({String token = 'web-token'}) =>
      service.getRecentMessages(
        channelLogin: 'channel',
        channelId: '12345',
        authToken: token,
      );

  group('request', () {
    test('one full-text ChatHistory query with the web token', () async {
      reply(historyBody([historyEntry()]));

      await load();

      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.uri.toString(), _gql);
      expect(request.headers['Client-ID'], kTwitchWebClientId);
      expect(request.headers['Authorization'], 'OAuth web-token');
      // Never the app's own Helix token, under any header name.
      for (final value in request.headers.values) {
        expect('$value', isNot(contains('helix-session-token')));
        expect('$value', isNot(contains('onset-fork-client-id')));
      }
      final data = request.data as Map;
      expect(data['operationName'], 'ChatHistory');
      // The whole document, not a persisted hash.
      expect(data.containsKey('extensions'), isFalse);
      final query = data['query'] as String;
      expect(query, startsWith('query ChatHistory('));
      expect(query, contains('channel(name: \$channelLogin)'));
      expect(query, contains('recentChatMessages'));
      expect(query, contains('senderBadges(channelID: \$channelID)'));
      for (final field in [
        'sentAt',
        'deletedAt',
        'senderChatColor',
        'sourceChannel',
        'parentMessage',
        'threadParentMessage',
        '... on Emote',
        '... on CheermoteToken',
        '... on GifContent',
      ]) {
        expect(query, contains(field));
      }
      // Fields ONSET does not draw are not asked for.
      expect(query, isNot(contains('AutoMod')));
      expect(query, isNot(contains('sourceSenderBadges')));
      expect(data['variables'], {
        'channelLogin': 'channel',
        'channelID': '12345',
      });
    });

    test('nothing is sent without a web token or with a bad channel', () async {
      reply(historyBody([historyEntry()]));

      expect(await load(token: ''), isEmpty);
      expect(
        await service.getRecentMessages(
          channelLogin: 'bad login',
          channelId: '12345',
          authToken: 'web-token',
        ),
        isEmpty,
      );
      expect(
        await service.getRecentMessages(
          channelLogin: 'channel',
          channelId: '12a',
          authToken: 'web-token',
        ),
        isEmpty,
      );
      expect(requests, isEmpty);
    });
  });

  group('response', () {
    test('parses every drawn field', () async {
      reply(
        historyBody([
          historyEntry(
            fragments: [
              {'text': 'hi ', 'content': null},
              {
                'text': 'Kappa',
                'content': {'__typename': 'Emote', 'id': '25'},
              },
              {'text': ' ', 'content': null},
              {
                'text': 'Cheer100',
                'content': {'__typename': 'CheermoteToken', 'bitsAmount': 100},
              },
              {
                'text': ' Cheer50',
                'content': {'__typename': 'CheermoteToken', 'bitsAmount': 50},
              },
              {
                'text': '@someone',
                'content': {'__typename': 'User', 'login': 'someone'},
              },
              {
                'text': 'Party',
                'content': {
                  '__typename': 'GifContent',
                  'id': 'g1',
                  'url': 'https://media.giphy.com/media/g1/giphy.gif',
                },
              },
            ],
            deletedAt: '2026-10-30T12:00:05Z',
            sourceChannel: {'id': '999'},
            parentMessage: {
              'id': 'parent-1',
              'content': {'text': 'the question'},
              'sender': {'id': '222', 'login': 'asker', 'displayName': 'Asker'},
            },
            threadParentMessage: {
              'id': 'root-1',
              'sender': {'login': 'starter', 'displayName': 'Starter'},
            },
          ),
        ]),
      );

      final message = (await load()).single;

      expect(message.id, 'msg-1');
      expect(message.sentAt, DateTime.utc(2026, 10, 30, 12, 0, 0, 123));
      expect(message.deleted, isTrue);
      expect(message.sender!.id, '111');
      expect(message.sender!.login, 'viewer');
      expect(message.sender!.displayName, 'Viewer');
      // The colour for this channel first, the account's after.
      expect(message.color, '#FF0000');
      expect(message.badges, [
        (setId: 'subscriber', version: '12'),
        (setId: 'moderator', version: '1'),
      ]);
      expect(message.fragments.map((f) => f.text).join(), contains('Kappa'));
      expect(message.fragments[1].emoteId, '25');
      expect(
        message.fragments.map((f) => f.bits).fold(0, (a, b) => a + b),
        150,
      );
      expect(message.fragments.last.gif!.id, 'g1');
      expect(message.sourceChannelId, '999');
      expect(message.parent!.id, 'parent-1');
      expect(message.parent!.text, 'the question');
      expect(message.parent!.sender!.login, 'asker');
      expect(message.threadParent!.id, 'root-1');
      expect(message.threadParent!.sender!.displayName, 'Starter');
    });

    test('the account colour when the channel colour is unset', () async {
      reply(historyBody([historyEntry(senderChatColor: null)]));
      expect((await load()).single.color, '#00FF00');
    });

    test('plain text when there are no fragments', () async {
      reply(
        historyBody([historyEntry(fragments: const [], text: 'just text')]),
      );
      final message = (await load()).single;
      expect(message.fragments.single.text, 'just text');
      expect(message.fragments.single.emoteId, isNull);
    });

    test('a message without a sender is kept for the caller to drop', () async {
      reply(historyBody([historyEntry(sender: null)]));
      expect((await load()).single.sender, isNull);
    });

    test('entries that cannot be read are skipped, the rest kept', () async {
      reply(
        historyBody([
          'not a map',
          historyEntry(id: ''),
          historyEntry(sentAt: 'yesterday'),
          {'id': 'x'},
          historyEntry(id: 'good'),
        ]),
      );
      expect((await load()).map((m) => m.id), ['good']);
    });

    test('at most maxMessages, the newest', () async {
      reply(
        historyBody([
          for (var i = 0; i < TwitchChatHistoryService.maxMessages + 5; i++)
            historyEntry(id: 'm$i'),
        ]),
      );
      final messages = await load();
      expect(messages, hasLength(TwitchChatHistoryService.maxMessages));
      expect(messages.last.id, 'm${TwitchChatHistoryService.maxMessages + 4}');
      expect(messages.first.id, 'm5');
    });

    test('an empty history is empty', () async {
      reply(historyBody(const []));
      expect(await load(), isEmpty);
    });
  });

  group('failure means no history', () {
    test('refused as unauthenticated', () async {
      reply({
        'errors': [
          {
            'message': 'unauthenticated',
            'path': ['channel', 'recentChatMessages'],
            'extensions': {'code': 'Unauthenticated'},
          },
        ],
        'data': {'channel': null},
      });
      expect(await load(), isEmpty);
    });

    test('any GQL error, even beside data', () async {
      reply({
        ...historyBody([historyEntry()]),
        'errors': [
          {'message': 'service timeout'},
        ],
      });
      expect(await load(), isEmpty);
    });

    test('a token Twitch refuses (401)', () async {
      reply({'error': 'Unauthorized', 'status': 401}, status: 401);
      expect(await load(), isEmpty);
    });

    test('a server error', () async {
      reply('oops', status: 500);
      expect(await load(), isEmpty);
    });

    test('a slow answer, past the timeout', () async {
      service = TwitchChatHistoryService(
        dio,
        timeout: const Duration(milliseconds: 50),
      );
      reply(
        historyBody([historyEntry()]),
        delay: const Duration(milliseconds: 400),
      );
      final watch = Stopwatch()..start();
      expect(await load(), isEmpty);
      expect(watch.elapsed, lessThan(const Duration(milliseconds: 350)));
    });

    test('the default timeout is within 3 to 5 seconds', () {
      final timeout = TwitchChatHistoryService(dio).timeout;
      expect(timeout, greaterThanOrEqualTo(const Duration(seconds: 3)));
      expect(timeout, lessThanOrEqualTo(const Duration(seconds: 5)));
    });

    test('malformed data', () async {
      for (final body in <Object?>[
        null,
        'text',
        <Object?>[],
        {'data': 'x'},
        {'data': <String, Object?>{}},
        {
          'data': {'channel': 'x'},
        },
        {
          'data': {
            'channel': {'recentChatMessages': 'x'},
          },
        },
        {
          'data': {
            'channel': {'recentChatMessages': null},
          },
        },
      ]) {
        adapter.reset();
        reply(body);
        expect(await load(), isEmpty, reason: '$body');
      }
    });

    test('hostile field types do not throw', () async {
      reply(
        historyBody([
          historyEntry(
            id: 'h1',
            sender: {'id': 5, 'login': [], 'displayName': {}},
            badges: 'x',
            fragments: [
              7,
              {'text': 5},
              {
                'text': 'Kappa',
                'content': {'__typename': 'Emote', 'id': 25},
              },
              {
                'text': 'Cheer',
                'content': {'__typename': 'CheermoteToken', 'bitsAmount': 'x'},
              },
            ],
            sourceChannel: {'id': 'not-a-number'},
            parentMessage: 'x',
          ),
        ]),
      );
      final message = (await load()).single;
      expect(message.sender?.login, isNull);
      expect(message.badges, isEmpty);
      expect(message.fragments.every((f) => f.emoteId == null), isTrue);
      expect(message.fragments.every((f) => f.bits == 0), isTrue);
      expect(message.sourceChannelId, isNull);
      expect(message.parent, isNull);
    });
  });
}
