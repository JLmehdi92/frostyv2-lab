import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/apis/unauthorized_interceptor.dart';
import 'package:frosty/models/emotes.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

const _helix = 'https://api.twitch.tv/helix';

Map<String, Object?> _emote(
  String id,
  String name,
  String type,
  String owner,
) => {
  'id': id,
  'name': name,
  'emote_type': type,
  'emote_set_id': 's$id',
  'owner_id': owner,
  'format': ['static'],
  'scale': ['1.0'],
  'theme_mode': ['dark'],
};

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late TwitchApi api;

  setUp(() {
    dio = Dio(BaseOptions());
    adapter = DioAdapter(dio: dio);
    api = TwitchApi(dio);
  });

  test('every page of the viewer\'s emotes, typed', () async {
    adapter
      ..onGet(
        '$_helix/chat/emotes/user',
        (server) => server.reply(200, {
          'data': [
            _emote('1', 'Kappa', 'globals', '0'),
            _emote('2', 'pogFollow', 'follower', '42'),
          ],
          'pagination': {'cursor': 'c1'},
        }),
        queryParameters: {'user_id': '7', 'broadcaster_id': '42'},
      )
      ..onGet(
        '$_helix/chat/emotes/user',
        (server) => server.reply(200, {
          'data': [_emote('3', 'subHype', 'subscriptions', '99')],
          'pagination': <String, Object>{},
        }),
        queryParameters: {
          'user_id': '7',
          'broadcaster_id': '42',
          'after': 'c1',
        },
      );

    final emotes = await api.getUserEmotes(userId: '7', broadcasterId: '42');

    expect(emotes.map((e) => e.name), ['Kappa', 'pogFollow', 'subHype']);
    expect(emotes.map((e) => e.type), [
      EmoteType.twitchGlobal,
      EmoteType.twitchFollower,
      EmoteType.twitchSub,
    ]);
    expect(emotes[1].ownerId, '42');
  });

  test('a token without the scope fails quietly', () async {
    final extras = <Map<String, Object?>>[];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          extras.add(options.extra);
          handler.next(options);
        },
      ),
    );
    adapter.onGet(
      '$_helix/chat/emotes/user',
      (server) => server.reply(401, {'message': 'Missing scope'}),
      queryParameters: {'user_id': '7', 'broadcaster_id': '42'},
    );

    await expectLater(
      api.getUserEmotes(userId: '7', broadcasterId: '42'),
      throwsA(isA<UnauthorizedException>()),
    );
    expect(extras.single[UnauthorizedInterceptor.quiet], isTrue);
  });

  test('users are asked for by id, many at once', () async {
    adapter.onGet(
      '$_helix/users',
      (server) => server.reply(200, {
        'data': [
          {
            'id': '1',
            'login': 'a',
            'display_name': 'A',
            'profile_image_url': '',
          },
        ],
      }),
      queryParameters: {
        'id': ['1', '2'],
      },
    );

    final users = await api.getUsersByIds(['1', '2']);
    expect(users.single.displayName, 'A');
    expect(() => api.getUsersByIds(['1', 'x']), throwsArgumentError);
  });
}
