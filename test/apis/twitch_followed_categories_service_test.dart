import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_followed_categories_service.dart';
import 'package:frosty/models/followed_category.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

const _gql = 'https://gql.twitch.tv/gql';

Map<String, Object?> _game({
  String id = '509658',
  String name = 'Just Chatting',
  String displayName = 'Just Chatting',
  String? slug = 'just-chatting',
  int viewers = 1200,
}) => {
  'id': id,
  'name': name,
  'displayName': displayName,
  'slug': slug,
  'viewersCount': viewers,
  'boxArtURL': 'https://static-cdn.jtvnw.net/ttv-boxart/$id-285x380.jpg',
};

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late TwitchFollowedCategoriesService service;
  late List<RequestOptions> requests;

  setUp(() {
    dio = Dio(BaseOptions());
    adapter = DioAdapter(dio: dio);
    requests = [];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.next(options);
        },
      ),
    );
    service = TwitchFollowedCategoriesService(dio);
  });

  void reply(Object? body, {int status = 200}) => adapter.onPost(
    _gql,
    (server) => server.reply(status, body),
    data: Matchers.any,
  );

  group('followed categories', () {
    test('are read as the viewer with the web token', () async {
      reply({
        'data': {
          'currentUser': {
            'followedGames': {
              'nodes': [
                _game(),
                _game(
                  id: '27471',
                  name: 'Minecraft',
                  displayName: '',
                  viewers: 0,
                ),
              ],
            },
          },
        },
      });

      final categories = await service.getFollowedCategories(
        authToken: 'webtok',
      );

      expect(categories, hasLength(2));
      expect(categories![0].id, '509658');
      expect(categories[0].title, 'Just Chatting');
      expect(categories[0].viewers, 1200);
      expect(
        categories[0].twitchUrl,
        Uri.https('www.twitch.tv', '/directory/category/just-chatting'),
      );
      expect(categories[1].title, 'Minecraft');
      final request = requests.single;
      expect(request.headers['Authorization'], 'OAuth webtok');
      expect(request.headers['Client-ID'], 'kimne78kx3ncx6brgo4mv6wki5h1ko');
      expect(request.uri.host, 'gql.twitch.tv');
      expect(request.data['query'], contains('followedGames'));
    });

    test('a token Twitch does not accept gives nothing', () async {
      reply({
        'data': {'currentUser': null},
      });

      expect(await service.getFollowedCategories(authToken: 'old'), isNull);
    });

    test('an integrity refusal gives nothing and is not retried', () async {
      reply({
        'errors': [
          {'message': 'failed integrity check'},
        ],
        'data': null,
      });

      expect(await service.getFollowedCategories(authToken: 'tok'), isNull);
      expect(requests, hasLength(1));
    });

    test('any GQL error gives nothing', () async {
      reply({
        'errors': [
          {'message': 'Cannot query field "followedGames"'},
        ],
      });

      expect(await service.getFollowedCategories(authToken: 'tok'), isNull);
    });

    test('a network failure gives nothing', () async {
      reply({'message': 'down'}, status: 500);

      expect(await service.getFollowedCategories(authToken: 'tok'), isNull);
    });

    test('no token, no request', () async {
      expect(await service.getFollowedCategories(authToken: ''), isNull);
      expect(requests, isEmpty);
    });

    test('broken nodes are left out', () async {
      reply({
        'data': {
          'currentUser': {
            'followedGames': {
              'nodes': [
                null,
                {'id': 'x'},
                _game(id: 'abc'),
                _game(),
              ],
            },
          },
        },
      });

      final categories = await service.getFollowedCategories(authToken: 't');

      expect(categories!.map((c) => c.id), ['509658']);
    });

    test('box art is only taken from Twitch\'s image host', () async {
      reply({
        'data': {
          'currentUser': {
            'followedGames': {
              'nodes': [
                {..._game(), 'boxArtURL': 'https://evil.example/a.jpg'},
              ],
            },
          },
        },
      });

      final categories = await service.getFollowedCategories(authToken: 't');

      expect(categories!.single.boxArtUrl, isEmpty);
    });
  });

  group('category slug', () {
    test('is read anonymously', () async {
      reply({
        'data': {
          'game': {'slug': 'just-chatting'},
        },
      });

      expect(await service.getCategorySlug('509658'), 'just-chatting');
      expect(requests.single.headers.containsKey('Authorization'), isFalse);
    });

    test('a failure or an odd id gives nothing', () async {
      reply({'errors': []}, status: 500);

      expect(await service.getCategorySlug('509658'), isNull);
      expect(await service.getCategorySlug('../x'), isNull);
    });
  });

  group('the follow link of a category page', () {
    test('opens the category on twitch.tv by its slug', () async {
      reply({
        'data': {
          'game': {'slug': 'chess'},
        },
      });

      expect(
        await service.categoryPageUrl('743', name: 'Chess'),
        Uri.https('www.twitch.tv', '/directory/category/chess'),
      );
    });

    test('falls back to the name when the slug is unknown', () async {
      reply({'data': null});

      expect(
        await service.categoryPageUrl('743', name: 'Chess'),
        Uri.https('www.twitch.tv', '/directory/game/Chess'),
      );
    });
  });

  group('the twitch.tv page of a category', () {
    test('uses the slug, or the name when the slug is unknown', () {
      expect(
        FollowedCategory.twitchUrlFor(slug: 'just-chatting', name: 'x'),
        Uri.https('www.twitch.tv', '/directory/category/just-chatting'),
      );
      expect(
        FollowedCategory.twitchUrlFor(slug: null, name: 'Just Chatting'),
        Uri.https('www.twitch.tv', '/directory/game/Just Chatting'),
      );
    });

    test('never leaves twitch.tv for an odd slug', () {
      final url = FollowedCategory.twitchUrlFor(
        slug: '../../evil.com',
        name: 'Game',
      );
      expect(url.host, 'www.twitch.tv');
      expect(url.path, '/directory/game/Game');
    });
  });
}
