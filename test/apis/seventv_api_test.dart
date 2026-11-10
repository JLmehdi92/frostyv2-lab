import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/seventv_api.dart';
import 'package:onset/models/emotes.dart';

import '../fixtures/api_responses.dart';

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late SevenTVApi api;

  setUp(() {
    dio = Dio(BaseOptions());
    dioAdapter = DioAdapter(dio: dio);
    api = SevenTVApi(dio);
  });

  group('getEmotesGlobal', () {
    test('returns list of global 7TV emotes', () async {
      dioAdapter.onGet(
        'https://7tv.io/v3/emote-sets/global',
        (server) => server.reply(200, sevenTVEmotesGlobalResponse),
      );

      final emotes = await api.getEmotesGlobal();

      expect(emotes, hasLength(1));
      expect(emotes.first.name, 'EZ');
      expect(emotes.first.type, EmoteType.sevenTVGlobal);
      expect(emotes.first.url, contains('7tv.app'));
      expect(emotes.first.url, contains('4x.webp'));
      expect(emotes.first.ownerDisplayName, 'Creator');
      expect(emotes.first.ownerUsername, 'creator');
    });

    test('returns empty list for empty emotes', () async {
      dioAdapter.onGet(
        'https://7tv.io/v3/emote-sets/global',
        (server) => server.reply(200, {'emotes': <dynamic>[]}),
      );

      final emotes = await api.getEmotesGlobal();

      expect(emotes, isEmpty);
    });
  });

  group('getEmotesChannel', () {
    test('returns emote set ID and channel emotes', () async {
      dioAdapter.onGet(
        'https://7tv.io/v3/users/twitch/12345',
        (server) => server.reply(200, sevenTVEmotesChannelResponse),
      );

      final (emoteSetId, emotes) = await api.getEmotesChannel(id: '12345');

      expect(emoteSetId, 'set_abc123');
      expect(emotes, hasLength(1));
      expect(emotes.first.name, 'Clap');
      expect(emotes.first.type, EmoteType.sevenTVChannel);
    });

    test('filters out emotes with empty URLs', () async {
      dioAdapter.onGet(
        'https://7tv.io/v3/users/twitch/12345',
        (server) => server.reply(200, {
          'emote_set': {
            'id': 'set_filter',
            'emotes': [
              {
                'id': 'valid',
                'name': 'ValidEmote',
                'data': {
                  'id': 'valid',
                  'name': 'ValidEmote',
                  'flags': 0,
                  'owner': null,
                  'host': {
                    'url': '//cdn.7tv.app/emote/valid',
                    'files': [
                      {
                        'name': '1x.webp',
                        'width': 32,
                        'height': 32,
                        'format': 'WEBP',
                      },
                    ],
                  },
                },
              },
              {
                'id': 'empty_url',
                'name': 'NoUrlEmote',
                'data': {
                  'id': 'empty_url',
                  'name': 'NoUrlEmote',
                  'flags': 0,
                  'owner': null,
                  'host': {
                    'url': '//cdn.7tv.app/emote/empty_url',
                    // Only AVIF files — these get filtered by lastWhereOrNull,
                    // resulting in empty URL
                    'files': [
                      {
                        'name': '1x.avif',
                        'width': 32,
                        'height': 32,
                        'format': 'AVIF',
                      },
                    ],
                  },
                },
              },
            ],
          },
        }),
      );

      final (_, emotes) = await api.getEmotesChannel(id: '12345');

      expect(emotes, hasLength(1));
      expect(emotes.first.name, 'ValidEmote');
    });

    test('throws on 404 for unknown user', () {
      dioAdapter.onGet(
        'https://7tv.io/v3/users/twitch/99999',
        (server) => server.reply(404, {'message': 'Unknown User'}),
      );

      expect(
        () => api.getEmotesChannel(id: '99999'),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('getChannel', () {
    test('also names the channel’s 7TV user', () async {
      dioAdapter.onGet(
        'https://7tv.io/v3/users/twitch/12345',
        (server) => server.reply(200, {
          ...sevenTVEmotesChannelResponse,
          'user': {'id': '7tv-user-1'},
        }),
      );

      final channel = await api.getChannel(id: '12345');

      expect(channel.userId, '7tv-user-1');
      expect(channel.setId, isNotEmpty);
      expect(channel.emotes, isNotEmpty);
    });
  });

  group('getEmoteSet', () {
    test('reads a set’s emotes with the given type', () async {
      dioAdapter.onGet(
        'https://7tv.io/v3/emote-sets/set9',
        (server) => server.reply(200, {
          'id': 'set9',
          'emotes': sevenTVEmotesChannelResponse['emote_set']!['emotes'],
        }),
      );

      final emotes = await api.getEmoteSet(
        id: 'set9',
        type: EmoteType.sevenTVPersonal,
      );

      expect(emotes, isNotEmpty);
      expect(
        emotes.every((emote) => emote.type == EmoteType.sevenTVPersonal),
        isTrue,
      );
    });
  });

  group('getUsersCosmetics', () {
    test('asks for every user in one query and maps the answers', () async {
      String? query;
      dioAdapter.onPost(
        'https://7tv.io/v4/gql',
        (server) => server.reply(200, {
          'data': {
            'users': {
              'u0': {
                'style': {
                  'activeBadge': {
                    'name': 'Sub',
                    'images': [
                      {
                        'url': 'https://cdn.7tv.app/badge/b/3x.webp',
                        'mime': 'image/webp',
                        'scale': 3,
                        'frameCount': 1,
                      },
                    ],
                  },
                },
              },
              'u1': null,
            },
          },
        }),
        data: Matchers.any,
      );
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            query = (options.data as Map)['query'] as String;
            handler.next(options);
          },
        ),
      );

      final cosmetics = await api.getUsersCosmetics(['1', '2', '1', 'x']);

      expect(cosmetics.keys, ['1', '2']);
      expect(cosmetics['1']!.badge!.name, 'Sub');
      expect(cosmetics['2']!.badge, isNull);
      expect(query, contains('u0: userByConnection'));
      expect(query, contains('platformId: "2"'));
      expect(query, isNot(contains('"x"')));
    });

    test('no valid id asks nothing', () async {
      expect(await api.getUsersCosmetics(['a"b']), isEmpty);
    });

    test('an answer without users is an error', () async {
      dioAdapter.onPost(
        'https://7tv.io/v4/gql',
        (server) => server.reply(200, {
          'errors': [
            {'message': 'changed'},
          ],
        }),
        data: Matchers.any,
      );
      await expectLater(
        api.getUsersCosmetics(['1']),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
