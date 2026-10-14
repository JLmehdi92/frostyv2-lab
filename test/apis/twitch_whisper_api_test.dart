import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late TwitchApi api;

  const helix = 'https://api.twitch.tv/helix';

  setUp(() {
    dio = Dio(BaseOptions());
    dioAdapter = DioAdapter(dio: dio);
    api = TwitchApi(dio);
  });

  group('createEventSubSubscription', () {
    test('points the subscription at the websocket session', () async {
      dioAdapter.onPost(
        '$helix/eventsub/subscriptions',
        (server) => server.reply(202, {
          'data': [
            {'id': 'f1c2a387-161a-49f9-a165-0f21d7a4e1c4', 'status': 'enabled'},
          ],
        }),
        data: {
          'type': 'user.whisper.message',
          'version': '1',
          'condition': {'user_id': '7'},
          'transport': {'method': 'websocket', 'session_id': 's1'},
        },
      );

      expect(
        await api.createEventSubSubscription(
          type: 'user.whisper.message',
          version: '1',
          condition: {'user_id': '7'},
          sessionId: 's1',
        ),
        'f1c2a387-161a-49f9-a165-0f21d7a4e1c4',
      );
    });

    test('an answer without an id is an error', () {
      dioAdapter.onPost(
        '$helix/eventsub/subscriptions',
        (server) => server.reply(202, {'data': []}),
        data: Matchers.any,
      );

      expect(
        () => api.createEventSubSubscription(
          type: 't',
          version: '1',
          condition: {},
          sessionId: 's',
        ),
        throwsA(isA<ApiException>()),
      );
    });
  });

  test('deleteEventSubSubscription', () async {
    dioAdapter.onDelete(
      '$helix/eventsub/subscriptions',
      (server) => server.reply(204, null),
      queryParameters: {'id': 'abc'},
    );
    await api.deleteEventSubSubscription('abc');
  });

  group('sendWhisper', () {
    test('sends the trimmed message', () async {
      dioAdapter.onPost(
        '$helix/whispers',
        (server) => server.reply(204, null),
        queryParameters: {'from_user_id': '7', 'to_user_id': '8'},
        data: {'message': 'hello there'},
      );

      await api.sendWhisper(
        fromUserId: '7',
        toUserId: '8',
        message: '  hello there ',
      );
    });

    test('refuses an empty or too long message and odd ids', () {
      for (final message in ['', '   ', 'a' * 10001]) {
        expect(
          () =>
              api.sendWhisper(fromUserId: '7', toUserId: '8', message: message),
          throwsArgumentError,
        );
      }
      expect(
        () => api.sendWhisper(fromUserId: '7', toUserId: 'x', message: 'hi'),
        throwsArgumentError,
      );
    });

    test("Twitch's refusal comes through", () {
      dioAdapter.onPost(
        '$helix/whispers',
        (server) => server.reply(400, {
          'message': 'The recipient blocked whispers from strangers.',
        }),
        queryParameters: {'from_user_id': '7', 'to_user_id': '8'},
        data: Matchers.any,
      );

      expect(
        () => api.sendWhisper(fromUserId: '7', toUserId: '8', message: 'hi'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('blocked whispers'),
          ),
        ),
      );
    });
  });
}
