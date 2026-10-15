import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/apis/twitch_stream_service.dart';
import 'package:frosty/models/playback_access_token.dart';
import 'package:frosty/services/playback_token_cache.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late TwitchStreamService service;

  const login = 'somestreamer';

  setUp(() {
    dio = Dio(BaseOptions());
    adapter = DioAdapter(dio: dio);
    service = TwitchStreamService(dio);
  });

  test(
    'requests a playback access token then resolves usher variants',
    () async {
      adapter
        ..onPost(
          'https://gql.twitch.tv/gql',
          (server) => server.reply(200, {
            'data': {
              'streamPlaybackAccessToken': {
                'value': '{"token":"abc"}',
                'signature': 'deadbeef',
              },
            },
          }),
          data: Matchers.any,
        )
        ..onGet(
          'https://usher.ttvnw.net/api/channel/hls/$login.m3u8',
          (server) => server.reply(200, '''
#EXTM3U
#EXT-X-MEDIA:TYPE=VIDEO,GROUP-ID="chunked",NAME="1080p60 (source)",DEFAULT=YES
#EXT-X-STREAM-INF:BANDWIDTH=6000000,VIDEO="chunked"
https://video-edge-1.ttvnw.net/chunked/index-live.m3u8
'''),
        );

      final variants = await service.getStreamVariants(userLogin: login);

      expect(variants, hasLength(1));
      expect(variants.first.name, '1080p60 (source)');
      expect(
        variants.first.url,
        'https://video-edge-1.ttvnw.net/chunked/index-live.m3u8',
      );
    },
  );

  test('throws when no access token is returned (offline channel)', () async {
    adapter.onPost(
      'https://gql.twitch.tv/gql',
      (server) => server.reply(200, {
        'data': {'streamPlaybackAccessToken': null},
      }),
      data: Matchers.any,
    );

    expect(
      () => service.getStreamVariants(userLogin: login),
      throwsA(isA<ApiException>()),
    );
  });

  group('usher parameters', () {
    void stubToken() {
      adapter.onPost(
        'https://gql.twitch.tv/gql',
        (server) => server.reply(200, {
          'data': {
            'streamPlaybackAccessToken': {
              'value': '{"token":"abc"}',
              'signature': 'deadbeef',
            },
          },
        }),
        data: Matchers.any,
      );
    }

    void expectUsherParams(Map<String, dynamic> params) {
      expect(params['allow_source'], 'true');
      expect(params['fast_bread'], 'true');
      // Audio only can be picked, like in the official app.
      expect(params['allow_audio_only'], 'true');
      // The user's 2K (1440p HEVC/AV1) support: must never change.
      expect(params['supported_codecs'], 'av1,h265,h264');
      expect(params['type'], 'any');
      expect(params['sig'], 'deadbeef');
      expect(params['token'], '{"token":"abc"}');
      expect(int.tryParse('${params['p']}'), isNotNull);
      // Legacy flags the official app never sends.
      expect(params.containsKey('low_latency'), isFalse);
      expect(params.containsKey('player'), isFalse);
    }

    test('usherQueryParameters keeps 2K codecs and drops legacy flags', () {
      final params = TwitchStreamService.usherQueryParameters(
        signature: 'deadbeef',
        token: '{"token":"abc"}',
        p: 1234,
      );

      expectUsherParams(params);
      expect(params['p'], '1234');
    });

    test('getUsherUrl builds the usher url with the same parameters', () async {
      stubToken();

      final url = await service.getUsherUrl(userLogin: login);
      final uri = Uri.parse(url);

      expect(uri.host, 'usher.ttvnw.net');
      expect(uri.path, '/api/channel/hls/$login.m3u8');
      expectUsherParams(uri.queryParameters);
      expect(url, contains('supported_codecs=av1%2Ch265%2Ch264'));
      expect(url, contains('token=%7B%22token%22%3A%22abc%22%7D'));
      expect(url, contains('&type=any'));
    });

    test('getStreamVariants requests usher with the same parameters', () async {
      stubToken();
      Map<String, dynamic>? usherParams;
      String? usherUri;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.uri.host == 'usher.ttvnw.net') {
              usherParams = Map.of(options.queryParameters);
              usherUri = options.uri.toString();
            }
            handler.next(options);
          },
        ),
      );
      adapter.onGet(
        'https://usher.ttvnw.net/api/channel/hls/$login.m3u8',
        (server) => server.reply(200, '#EXTM3U\n'),
      );

      await service.getStreamVariants(userLogin: login);

      expect(usherParams, isNotNull);
      expectUsherParams(usherParams!);
      expect(usherUri, contains('supported_codecs=av1%2Ch265%2Ch264'));
      expect(usherUri, isNot(contains('low_latency')));
    });
  });

  group('playback token cache', () {
    late DateTime now;
    late PlaybackTokenCache cache;
    late int gqlPosts;

    void stubToken({int expiresInSeconds = 600, bool offline = false}) {
      final expires = now.millisecondsSinceEpoch ~/ 1000 + expiresInSeconds;
      adapter.onPost(
        'https://gql.twitch.tv/gql',
        (server) => server.reply(200, {
          'data': {
            'streamPlaybackAccessToken': offline
                ? null
                : {'value': '{"expires":$expires}', 'signature': 'deadbeef'},
          },
        }),
        data: Matchers.any,
      );
    }

    setUp(() {
      now = DateTime.now().toUtc();
      cache = PlaybackTokenCache(now: () => now);
      gqlPosts = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.uri.host == 'gql.twitch.tv') gqlPosts++;
            handler.next(options);
          },
        ),
      );
      service = TwitchStreamService(dio, tokenCache: cache);
    });

    test('reuses a valid token', () async {
      stubToken();

      await service.getUsherUrl(userLogin: login);
      await service.getUsherUrl(userLogin: login);

      expect(gqlPosts, 1);
    });

    test('fetches a new token once the cached one expired', () async {
      stubToken(expiresInSeconds: 120);

      await service.getUsherUrl(userLogin: login);
      now = now.add(const Duration(minutes: 3));
      await service.getUsherUrl(userLogin: login);

      expect(gqlPosts, 2);
    });

    test('forceFreshToken bypasses the cache', () async {
      stubToken();

      await service.getUsherUrl(userLogin: login);
      await service.getUsherUrl(userLogin: login, forceFreshToken: true);
      await service.getUsherUrl(userLogin: login);

      expect(gqlPosts, 2);
    });

    test('does not cache an offline channel', () async {
      stubToken(offline: true);

      await expectLater(
        service.getUsherUrl(userLogin: login),
        throwsA(isA<ApiException>()),
      );
      expect(cache.get(login), isNull);
    });

    test('without a cache every call fetches a token', () async {
      stubToken();
      service = TwitchStreamService(dio);

      await service.getUsherUrl(userLogin: login);
      await service.getUsherUrl(userLogin: login);

      expect(gqlPosts, 2);
    });
  });

  group('playback refusal', () {
    late List<Object?> sent;

    void stubToken({Object? authorization}) => adapter.onPost(
      'https://gql.twitch.tv/gql',
      (server) => server.reply(200, {
        'data': {
          'streamPlaybackAccessToken': {
            'value': '{"token":"abc"}',
            'signature': 'deadbeef',
            'authorization': authorization,
          },
        },
      }),
      data: Matchers.any,
    );

    setUp(() {
      sent = [];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            sent.add(options.data);
            handler.next(options);
          },
        ),
      );
    });

    test('asks twitch why a stream would be refused', () async {
      stubToken(authorization: {'forbiddenReasonCode': 'NONE'});

      await service.getUsherUrl(userLogin: login);

      final query = (sent.single as Map)['query'] as String;
      expect(query, contains('authorization { forbiddenReasonCode }'));
      expect(service.refusalFor(login), isNull);
    });

    test('remembers a subscribers-only refusal per channel', () async {
      stubToken(
        authorization: {'forbiddenReasonCode': 'UNAUTHORIZED_ENTITLEMENTS'},
      );

      await service.getUsherUrl(userLogin: login);

      expect(service.refusalFor(login), PlaybackRefusal.subscribersOnly);
      expect(service.refusalFor('someone_else'), isNull);
    });

    test('an unexpected reason shape still plays', () async {
      stubToken(authorization: {'forbiddenReasonCode': 5});

      expect(await service.getUsherUrl(userLogin: login), contains('sig='));
      expect(service.refusalFor(login), isNull);
    });

    test('a refused token is not cached', () async {
      final now = DateTime.now().toUtc();
      final cache = PlaybackTokenCache(now: () => now);
      service = TwitchStreamService(dio, tokenCache: cache);
      final expires = now.millisecondsSinceEpoch ~/ 1000 + 600;
      adapter.onPost(
        'https://gql.twitch.tv/gql',
        (server) => server.reply(200, {
          'data': {
            'streamPlaybackAccessToken': {
              'value': '{"expires":$expires}',
              'signature': 'deadbeef',
              'authorization': {'forbiddenReasonCode': 'GEOBLOCKED'},
            },
          },
        }),
        data: Matchers.any,
      );

      await service.getUsherUrl(userLogin: login);
      await service.getUsherUrl(userLogin: login);

      expect(sent, hasLength(2), reason: 'each try asks twitch again');
      expect(cache.get(login), isNull);
      expect(service.refusalFor(login), PlaybackRefusal.geoblocked);
    });

    test('a query twitch rejects is asked again without the reason', () async {
      adapter
        ..onPost(
          'https://gql.twitch.tv/gql',
          (server) => server.reply(200, {
            'errors': [
              {'message': 'Cannot query field "authorization"'},
            ],
            'data': null,
          }),
          data: TwitchStreamService.accessTokenRequest(
            login,
            TwitchStreamService.accessTokenQuery,
          ),
        )
        ..onPost(
          'https://gql.twitch.tv/gql',
          (server) => server.reply(200, {
            'data': {
              'streamPlaybackAccessToken': {
                'value': '{"token":"abc"}',
                'signature': 'deadbeef',
              },
            },
          }),
          data: TwitchStreamService.accessTokenRequest(
            login,
            TwitchStreamService.plainAccessTokenQuery,
          ),
        );

      expect(await service.getUsherUrl(userLogin: login), contains('sig='));
      expect(sent, hasLength(2));
      expect(service.refusalFor(login), isNull);
    });

    test('reads the reason usher gives for a refused playlist', () async {
      const url =
          'https://usher.ttvnw.net/api/channel/hls/$login.m3u8?sig=x&token=y';
      adapter.onGet(
        url,
        (server) => server.reply(403, [
          {
            'url': 'https://usher.ttvnw.net/api/channel/hls/$login.m3u8',
            'error': 'Content Restricted In Region',
            'error_code': 'content_geoblocked',
            'type': 'error',
          },
        ]),
      );

      expect(await service.usherRefusal(url), 'Content Restricted In Region');
    });

    test('a playable or unreadable playlist gives no reason', () async {
      const ok = 'https://usher.ttvnw.net/api/channel/hls/a.m3u8?sig=x';
      const garbled = 'https://usher.ttvnw.net/api/channel/hls/b.m3u8?sig=x';
      adapter
        ..onGet(ok, (server) => server.reply(200, '#EXTM3U'))
        ..onGet(garbled, (server) => server.reply(403, '<html>no</html>'));

      expect(await service.usherRefusal(ok), isNull);
      expect(await service.usherRefusal(garbled), isNull);
      expect(
        await service.usherRefusal('https://evil.example/hls/a.m3u8'),
        isNull,
      );
    });
  });

  test('refusal codes map to what the viewer is told', () {
    expect(PlaybackRefusal.fromCode('NONE'), isNull);
    expect(PlaybackRefusal.fromCode(null), isNull);
    expect(
      PlaybackRefusal.fromCode('UNAUTHORIZED_ENTITLEMENTS'),
      PlaybackRefusal.subscribersOnly,
    );
    expect(PlaybackRefusal.fromCode('GEOBLOCKED'), PlaybackRefusal.geoblocked);
    expect(
      PlaybackRefusal.fromCode('CHANNEL_RESTRICTED_BANNED_USER'),
      PlaybackRefusal.bannedFromChannel,
    );
    expect(
      PlaybackRefusal.fromCode('UNAUTHORIZED'),
      PlaybackRefusal.unauthorized,
    );
    expect(PlaybackRefusal.fromCode('UNKNOWN__'), isNull);
    expect(PlaybackRefusal.fromCode('SOMETHING_NEW'), isNull);
  });

  group('preload', () {
    late DateTime now;
    late PlaybackTokenCache cache;
    late int posts;

    void stubToken({Duration delay = Duration.zero, int status = 200}) {
      final expires = now.millisecondsSinceEpoch ~/ 1000 + 600;
      adapter.onPost(
        'https://gql.twitch.tv/gql',
        (server) => server.reply(status, {
          'data': {
            'streamPlaybackAccessToken': {
              'value': '{"expires":$expires}',
              'signature': 'deadbeef',
            },
          },
        }, delay: delay),
        data: Matchers.any,
      );
    }

    setUp(() {
      now = DateTime.now().toUtc();
      cache = PlaybackTokenCache(now: () => now);
      posts = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.uri.host == 'gql.twitch.tv') posts++;
            handler.next(options);
          },
        ),
      );
      service = TwitchStreamService(dio, tokenCache: cache);
    });

    test('the player reuses a preloaded token', () async {
      stubToken();

      await service.preload(login);
      await TwitchStreamService(
        dio,
        tokenCache: cache,
      ).getUsherUrl(userLogin: login);

      expect(posts, 1);
    });

    test('a player opening during the preload waits for it', () async {
      stubToken(delay: const Duration(milliseconds: 50));

      final preloading = service.preload(login);
      final url = await TwitchStreamService(
        dio,
        tokenCache: cache,
      ).getUsherUrl(userLogin: login);
      await preloading;

      expect(url, contains('sig=deadbeef'));
      expect(posts, 1);
    });

    test('a player opening during a failing preload gets its error', () async {
      stubToken(delay: const Duration(milliseconds: 50), status: 500);

      final preloading = service.preload(login);
      await expectLater(
        TwitchStreamService(
          dio,
          tokenCache: cache,
        ).getUsherUrl(userLogin: login),
        throwsA(isA<ApiException>()),
      );
      await preloading;

      expect(posts, 1, reason: 'no second request after the first failed');
    });

    test('a failed preload is quiet and asked again by the player', () async {
      stubToken(status: 500);

      await service.preload(login);
      stubToken();
      await service.getUsherUrl(userLogin: login);

      expect(posts, 2);
    });
  });

  group('enhanced broadcasting (1440p HEVC / AV1)', () {
    late _RecordingAdapter recorder;

    setUp(() {
      recorder = _RecordingAdapter();
      dio = Dio(BaseOptions())..httpClientAdapter = recorder;
      service = TwitchStreamService(dio);
    });

    test('advertises the enhanced codecs on the usher request', () async {
      await service.getUsherUrl(userLogin: login);

      final url = await service.getUsherUrl(userLogin: login);
      expect(url, contains('supported_codecs=av1%2Ch265%2Ch264'));
      expect(url, contains('reassignments_supported=true'));
    });

    test(
      'sends the user token so Twitch returns the enhanced renditions',
      () async {
        await service.getUsherUrl(userLogin: login, authToken: 'usertoken');

        expect(
          recorder.requests.first.headers['Authorization'],
          'OAuth usertoken',
        );
      },
    );

    test(
      'falls back to an anonymous request when the token is rejected',
      () async {
        recorder.failAuthenticatedRequests = true;

        final url = await service.getUsherUrl(
          userLogin: login,
          authToken: 'usertoken',
        );

        expect(recorder.requests, hasLength(2));
        expect(
          recorder.requests.first.headers['Authorization'],
          'OAuth usertoken',
        );
        expect(
          recorder.requests.last.headers.containsKey('Authorization'),
          isFalse,
        );
        expect(url, contains('usher.ttvnw.net'));
      },
    );

    test('a 401 renews the web token in the background', () async {
      recorder.failAuthenticatedRequests = true;
      final renewal = Completer<String?>();
      var renewals = 0;
      service.onWebTokenRejected = () {
        renewals++;
        return renewal.future;
      };

      // Completes although the renewal never does: the stream starts
      // anonymously at once.
      final url = await service.getUsherUrl(
        userLogin: login,
        authToken: 'stale',
      );

      expect(url, contains('usher.ttvnw.net'));
      expect(renewals, 1);
    });

    test('other failures fall back without renewing the token', () async {
      recorder
        ..failAuthenticatedRequests = true
        ..authFailureStatus = 500;
      var renewals = 0;
      service.onWebTokenRejected = () async {
        renewals++;
        return null;
      };

      await service.getUsherUrl(userLogin: login, authToken: 'fine');

      expect(renewals, 0);
      expect(
        recorder.requests.last.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('a token preloaded with the web token is reused', () async {
      final expires = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 600;
      recorder.tokenValue = '{"expires":$expires}';
      final cache = PlaybackTokenCache();
      service = TwitchStreamService(dio, tokenCache: cache);

      await service.preload(login, authToken: 'web');
      await TwitchStreamService(
        dio,
        tokenCache: cache,
      ).getUsherUrl(userLogin: login, authToken: 'web');

      expect(recorder.requests, hasLength(1));
    });

    test("one viewer's token is never replayed for another", () async {
      final cache = PlaybackTokenCache();
      service = TwitchStreamService(dio, tokenCache: cache);

      await service.getUsherUrl(userLogin: login, authToken: 'account-a');
      await service.getUsherUrl(userLogin: login, authToken: 'account-b');
      await service.getUsherUrl(userLogin: login);

      expect(recorder.requests, hasLength(3));
    });
  });
}

/// Minimal adapter that records every GQL request and can reject the
/// authenticated one, which `DioAdapter` cannot express (it matches a URL
/// once, and both attempts hit the same URL).
class _RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  bool failAuthenticatedRequests = false;
  int authFailureStatus = 401;

  /// The token's value; give it an `expires` for the cache to keep it.
  String tokenValue = '{"token":"abc"}';

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    final isAuthenticated = options.headers.containsKey('Authorization');
    if (failAuthenticatedRequests && isAuthenticated) {
      return ResponseBody.fromString(
        '{"errors":[{"message":"unauthorized"}]}',
        authFailureStatus,
      );
    }

    return ResponseBody.fromString(
      jsonEncode({
        'data': {
          'streamPlaybackAccessToken': {
            'value': tokenValue,
            'signature': 'deadbeef',
          },
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
