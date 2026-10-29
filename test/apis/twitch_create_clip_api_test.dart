import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/unauthorized_interceptor.dart';

const _clips = 'https://api.twitch.tv/helix/clips';
const _validate = 'https://id.twitch.tv/oauth2/validate';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late TwitchApi api;
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
    api = TwitchApi(dio);
  });

  group('getTokenScopes', () {
    test('reads the scopes the current token was granted', () async {
      adapter.onGet(
        _validate,
        (s) => s.reply(200, {
          'client_id': 'x',
          'login': 'me',
          'scopes': ['chat:read', 'clips:edit'],
          'user_id': '7',
        }),
      );

      expect(await api.getTokenScopes(), {'chat:read', 'clips:edit'});
      expect(requests.single.extra[UnauthorizedInterceptor.quiet], isTrue);
    });

    test('no scopes listed is an empty set', () async {
      adapter.onGet(_validate, (s) => s.reply(200, {'login': 'me'}));

      expect(await api.getTokenScopes(), isEmpty);
    });
  });

  group('createClip', () {
    void answer(int status, Object body) => adapter.onPost(
      _clips,
      (s) => s.reply(status, body),
      queryParameters: {'broadcaster_id': '42'},
    );

    test('asks Helix to clip the channel and reads the edit link', () async {
      answer(202, {
        'data': [
          {
            'id': 'FiveWordsForClipSlug',
            'edit_url':
                'https://www.twitch.tv/streamer/clip/FiveWordsForClipSlug',
          },
        ],
      });

      final clip = await api.createClip(broadcasterId: '42');

      expect(clip.id, 'FiveWordsForClipSlug');
      expect(
        clip.editUrl,
        Uri.parse('https://www.twitch.tv/streamer/clip/FiveWordsForClipSlug'),
      );
      expect(clip.link, 'https://clips.twitch.tv/FiveWordsForClipSlug');
      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.uri.queryParameters, {'broadcaster_id': '42'});
      expect(
        request.extra[UnauthorizedInterceptor.quiet],
        isTrue,
        reason: 'a missing scope is explained by the clip sheet',
      );
    });

    test('an edit link off twitch.tv is dropped', () async {
      answer(202, {
        'data': [
          {'id': 'Slug-abc', 'edit_url': 'https://evil.example/clip'},
        ],
      });

      final clip = await api.createClip(broadcasterId: '42');

      expect(clip.editUrl, isNull);
      expect(clip.link, 'https://clips.twitch.tv/Slug-abc');
    });

    test('an answer without a clip id is an error', () async {
      answer(202, {'data': []});

      await expectLater(
        api.createClip(broadcasterId: '42'),
        throwsA(
          isA<ClipCreateException>().having(
            (e) => e.reason,
            'reason',
            ClipCreateFailure.unknown,
          ),
        ),
      );
    });

    final cases = {
      401: ClipCreateFailure.missingScope,
      403: ClipCreateFailure.restricted,
      404: ClipCreateFailure.offline,
      400: ClipCreateFailure.notClippable,
      429: ClipCreateFailure.rateLimited,
      500: ClipCreateFailure.unknown,
    };
    for (final MapEntry(key: status, value: reason) in cases.entries) {
      test('$status is $reason', () async {
        answer(status, {'message': 'nope'});

        await expectLater(
          api.createClip(broadcasterId: '42'),
          throwsA(
            isA<ClipCreateException>().having(
              (e) => e.reason,
              'reason',
              reason,
            ),
          ),
        );
      });
    }

    test('refuses an id that is not a Twitch id', () {
      expect(
        () => api.createClip(broadcasterId: '42&x=1'),
        throwsArgumentError,
      );
      expect(requests, isEmpty);
    });
  });

  group('getCreatedClip', () {
    test('the clip once Twitch has made it', () async {
      adapter.onGet(
        _clips,
        (s) => s.reply(200, {
          'data': [
            {
              'id': 'Slug-abc',
              'thumbnail_url': 'https://static-cdn.jtvnw.net/x.jpg',
            },
          ],
        }),
        queryParameters: {'id': 'Slug-abc'},
      );

      final made = await api.getCreatedClip('Slug-abc');

      expect(made, isNotNull);
      expect(made!.thumbnailUrl, 'https://static-cdn.jtvnw.net/x.jpg');
    });

    test('null while it is still being made', () async {
      adapter.onGet(
        _clips,
        (s) => s.reply(200, {'data': []}),
        queryParameters: {'id': 'Slug-abc'},
      );

      expect(await api.getCreatedClip('Slug-abc'), isNull);
    });

    test('refuses a slug that is not a clip slug', () {
      expect(() => api.getCreatedClip('a/b'), throwsArgumentError);
    });
  });
}
