import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_channel_profile_service.dart';
import 'package:onset/apis/twitch_directory_service.dart';
import 'package:onset/models/team.dart';

const _gql = 'https://gql.twitch.tv/gql';
const _helix = 'https://api.twitch.tv/helix';

void main() {
  late Dio dio;
  late DioAdapter adapter;

  setUp(() {
    dio = Dio(BaseOptions());
    adapter = DioAdapter(dio: dio);
  });

  void replyGql(Object body) =>
      adapter.onPost(_gql, (s) => s.reply(200, body), data: Matchers.any);

  group('search suggestions', () {
    test('reads channels, categories and plain texts', () async {
      replyGql({
        'data': {
          'searchSuggestions': {
            'edges': [
              {
                'node': {
                  'id': '1',
                  'text': 'xqc',
                  'content': {
                    '__typename': 'SearchSuggestionChannel',
                    'id': 'c',
                    'user': {
                      'id': '71092938',
                      'login': 'xQc',
                      'displayName': 'xQc',
                    },
                  },
                },
              },
              {
                'node': {
                  'id': '2',
                  'text': 'just chatting',
                  'content': {
                    '__typename': 'SearchSuggestionCategory',
                    'id': 'g',
                    'game': {
                      'id': '509658',
                      'name': 'Just Chatting',
                      'displayName': 'Just Chatting',
                    },
                  },
                },
              },
              {
                'node': {'id': '3', 'text': 'xqc react', 'content': null},
              },
              {
                'node': {'id': '4', 'text': '  ', 'content': null},
              },
            ],
          },
        },
      });

      final suggestions = await TwitchDirectoryService(
        dio,
      ).searchSuggestions('xq');

      expect(suggestions.map((s) => (s.text, s.kind, s.login)), [
        ('xQc', SearchSuggestionKind.channel, 'xqc'),
        ('Just Chatting', SearchSuggestionKind.category, null),
        ('xqc react', SearchSuggestionKind.text, null),
      ]);
    });

    test(
      'an answer without suggestions throws, an empty query asks nothing',
      () async {
        replyGql({
          'data': {'searchSuggestions': null},
          'errors': [
            {'message': 'service error'},
          ],
        });
        final service = TwitchDirectoryService(dio);
        expect(await service.searchSuggestions('  '), isEmpty);
        await expectLater(
          service.searchSuggestions('xq'),
          throwsA(isA<DirectoryApiException>()),
        );
      },
    );
  });

  group('trailer', () {
    test('reads the trailer video', () async {
      replyGql({
        'data': {
          'user': {
            'id': '1',
            'channel': {
              'id': '1',
              'trailer': {
                'video': {
                  'id': '2001',
                  'title': 'Welcome',
                  'lengthSeconds': 75,
                  'previewThumbnailURL': 'https://static-cdn.jtvnw.net/t.jpg',
                },
              },
            },
          },
        },
      });
      final trailer = await TwitchChannelProfileService(
        dio,
      ).getTrailer('streamer');
      expect(trailer?.videoId, '2001');
      expect(trailer?.title, 'Welcome');
      expect(trailer?.length, const Duration(seconds: 75));
      expect(trailer?.thumbnailUrl, 'https://static-cdn.jtvnw.net/t.jpg');
    });

    test('no trailer is null, a refused channel throws', () async {
      replyGql({
        'data': {
          'user': {
            'id': '1',
            'channel': {'id': '1', 'trailer': null},
          },
        },
      });
      final service = TwitchChannelProfileService(dio);
      expect(await service.getTrailer('streamer'), isNull);

      replyGql({
        'data': {'user': null},
        'errors': [
          {'message': 'boom'},
        ],
      });
      await expectLater(
        service.getTrailer('streamer'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('teams', () {
    test("a channel's teams and a team's members", () async {
      adapter
        ..onGet(
          '$_helix/teams/channel',
          (s) => s.reply(200, {
            'data': [
              {
                'id': '6358',
                'team_name': 'Staff',
                'team_display_name': 'Twitch Staff',
                'thumbnail_url': 'https://static-cdn.jtvnw.net/s.png',
                'banner': 'http://insecure/b.png',
                'info': '<p>Hello&nbsp;<b>team</b></p>',
              },
              {'id': 'x', 'team_name': 'bad'},
            ],
          }),
          queryParameters: {'broadcaster_id': '42'},
        )
        ..onGet(
          '$_helix/teams',
          (s) => s.reply(200, {
            'data': [
              {
                'id': '6358',
                'team_name': 'staff',
                'team_display_name': 'Twitch Staff',
                'info': '',
                'users': [
                  {'user_id': '1', 'user_login': 'One', 'user_name': 'One'},
                  {'user_id': 'nope', 'user_login': 'two', 'user_name': 'Two'},
                ],
              },
            ],
          }),
          queryParameters: {'name': 'staff'},
        );
      final api = TwitchApi(dio);

      final teams = await api.getChannelTeams(broadcasterId: '42');
      expect(teams, hasLength(1));
      expect(teams.single.name, 'staff');
      expect(teams.single.thumbnailUrl, 'https://static-cdn.jtvnw.net/s.png');
      expect(teams.single.bannerUrl, isNull);
      expect(teams.single.info, contains('team'));
      expect(teams.single.info, 'Hello team');

      final team = await api.getTeam(name: 'staff');
      expect(team?.members.map((m) => m.login), ['one']);
    });

    test('an unknown team is null', () {
      expect(Team.fromJson({'id': '1', 'team_name': '../x'}), isNull);
    });
  });
}
