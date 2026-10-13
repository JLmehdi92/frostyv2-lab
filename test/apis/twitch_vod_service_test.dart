import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/apis/twitch_vod_service.dart';
import 'package:frosty/models/vod.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../fixtures/vod_responses.dart';

const _gql = 'https://gql.twitch.tv/gql';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late TwitchVodService service;
  late List<RequestOptions> gqlRequests;

  setUp(() {
    dio = Dio(BaseOptions());
    adapter = DioAdapter(dio: dio);
    gqlRequests = [];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.uri.toString() == _gql) gqlRequests.add(options);
          handler.next(options);
        },
      ),
    );
    service = TwitchVodService(dio);
  });

  void reply(Object body) =>
      adapter.onPost(_gql, (s) => s.reply(200, body), data: Matchers.any);

  Map<String, dynamic> lastVariables() =>
      ((gqlRequests.last.data as Map)['variables'] as Map)
          .cast<String, dynamic>();

  group('getChannelVideos', () {
    test('sends the public client id and the paging variables', () async {
      reply(vodListResponse);

      await service.getChannelVideos(
        login: 'streamer',
        type: VodType.highlight,
        cursor: 'abc',
        first: 10,
      );

      expect(gqlRequests.last.headers['Client-ID'], isNotEmpty);
      expect(lastVariables(), {
        'login': 'streamer',
        'type': 'HIGHLIGHT',
        'first': 10,
        'after': 'abc',
      });
    });

    test('parses edges, cursor and hasNextPage', () async {
      reply(vodListResponse);

      final page = await service.getChannelVideos(
        login: 'streamer',
        type: VodType.archive,
      );

      expect(page.items.map((v) => v.id), ['1000000001', '1000000003']);
      expect(page.cursor, 'cursor-2');
      expect(page.hasNextPage, isTrue);
    });

    test('an empty list has no next page', () async {
      reply(vodListEmptyResponse);

      final page = await service.getChannelVideos(
        login: 'streamer',
        type: VodType.upload,
      );

      expect(page.items, isEmpty);
      expect(page.hasNextPage, isFalse);
    });

    test('an unknown channel throws NotFoundException', () async {
      reply(vodListUnknownUserResponse);

      expect(
        () => service.getChannelVideos(login: 'nobody', type: VodType.archive),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('getVideo', () {
    test('returns the vod', () async {
      reply(vodDetailResponse);

      final vod = await service.getVideo('v1000000001');

      expect(vod?.id, '1000000001');
      expect(lastVariables(), {'id': '1000000001'});
    });

    test('returns null when the vod does not exist', () async {
      reply(vodMissingResponse);

      expect(await service.getVideo('123'), isNull);
    });
  });

  group('getComments', () {
    test('sends the offset and parses the page in order', () async {
      reply(vodCommentsResponse);

      final page = await service.getComments(
        vodId: '1000000001',
        offsetSeconds: 3600,
      );

      expect(lastVariables(), {'id': '1000000001', 'offset': 3600});
      expect(page.comments.map((c) => c.id), ['comment-1', 'comment-2']);
      expect(page.hasNextPage, isTrue);
    });

    test('flags integrity failures', () async {
      reply(vodCommentsIntegrityResponse);

      expect(
        () => service.getComments(vodId: '1', offsetSeconds: 0),
        throwsA(
          isA<VodApiException>().having(
            (e) => e.isIntegrity,
            'integrity',
            true,
          ),
        ),
      );
    });

    test('other GQL errors are not integrity failures', () async {
      reply(vodCommentsServiceErrorResponse);

      expect(
        () => service.getComments(vodId: '1', offsetSeconds: 0),
        throwsA(
          isA<VodApiException>().having(
            (e) => e.isIntegrity,
            'integrity',
            false,
          ),
        ),
      );
    });
  });

  group('getMutedSegments', () {
    test('parses muted segments', () async {
      reply(vodMutedSegmentsResponse);

      final segments = await service.getMutedSegments('1000000001');

      expect(segments.map((s) => (s.offset, s.duration)), [
        (120, 360),
        (1800, 180),
      ]);
    });

    test('never throws', () async {
      reply(vodCommentsServiceErrorResponse);

      expect(await service.getMutedSegments('1'), isEmpty);
    });
  });

  group('getVodUsherUrl', () {
    test('builds the usher vod url with the exact parameters', () async {
      reply(vodTokenResponse);

      final url = await service.getVodUsherUrl(vodId: 'v1000000001');
      final uri = Uri.parse(url);

      expect(uri.host, 'usher.ttvnw.net');
      expect(uri.path, '/vod/1000000001.m3u8');
      expect(uri.queryParameters.keys.toSet(), {
        'allow_source',
        'allow_audio_only',
        'supported_codecs',
        'playlist_include_framerate',
        'p',
        'sig',
        'token',
      });
      expect(uri.queryParameters['sig'], 'vodsig');
      expect(uri.queryParameters['token'], vodTokenValue);
      expect(url, contains('supported_codecs=av1%2Ch265%2Ch264'));
      expect(lastVariables()['id'], '1000000001');
      expect(
        (gqlRequests.last.data as Map)['query'],
        contains('playerType: "site"'),
      );
    });

    test('reuses a valid token and can force a fresh one', () async {
      reply(vodTokenResponse);

      await service.getVodUsherUrl(vodId: '1000000001');
      await service.getVodUsherUrl(vodId: '1000000001');
      expect(gqlRequests, hasLength(1));

      await service.getVodUsherUrl(vodId: '1000000001', forceFreshToken: true);
      expect(gqlRequests, hasLength(2));
    });

    test('a forbidden token throws VodForbiddenException', () async {
      reply(vodTokenForbiddenResponse);

      expect(
        () => service.getVodUsherUrl(vodId: '1000000001'),
        throwsA(
          isA<VodForbiddenException>().having(
            (e) => e.reason,
            'reason',
            'geoblocked',
          ),
        ),
      );
    });

    test('a missing token throws ApiException', () async {
      reply({
        'data': {'videoPlaybackAccessToken': null},
      });

      expect(
        () => service.getVodUsherUrl(vodId: '1000000001'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('normalizeVodId', () {
    test('strips a leading v', () {
      expect(TwitchVodService.normalizeVodId('v123'), '123');
      expect(TwitchVodService.normalizeVodId('123'), '123');
    });

    test('rejects anything that is not a numeric id', () {
      for (final bad in ['12a', '../1', '', 'v', '1' * 21, '1 2']) {
        expect(
          () => TwitchVodService.normalizeVodId(bad),
          throwsArgumentError,
          reason: bad,
        );
      }
    });
  });

  group('diagnoseVodPlaylist', () {
    const url = 'https://usher.ttvnw.net/vod/1000000001.m3u8?x=1';

    test('a playable playlist has no problem', () async {
      adapter.onGet(url, (s) => s.reply(200, '#EXTM3U\n'));

      expect(await service.diagnoseVodPlaylist(url), isNull);
    });

    test('maps usher error codes', () async {
      adapter.onGet(url, (s) => s.reply(403, usherRestrictedBody));
      expect(
        await service.diagnoseVodPlaylist(url),
        VodPlaybackProblem.subscriberOnly,
      );

      adapter.onGet(url, (s) => s.reply(403, usherGeoBlockedBody));
      expect(
        await service.diagnoseVodPlaylist(url),
        VodPlaybackProblem.geoBlocked,
      );

      adapter.onGet(url, (s) => s.reply(404, 'not found'));
      expect(
        await service.diagnoseVodPlaylist(url),
        VodPlaybackProblem.notFound,
      );
    });

    test('a network failure is unknown, never a throw', () async {
      adapter.onGet(
        url,
        (s) => s.throws(
          0,
          DioException.connectionError(
            requestOptions: RequestOptions(path: url),
            reason: 'offline',
          ),
        ),
      );

      expect(
        await service.diagnoseVodPlaylist(url),
        VodPlaybackProblem.unknown,
      );
    });
  });
}
