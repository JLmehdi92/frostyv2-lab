import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_clip_service.dart';
import 'package:onset/models/clip.dart';

import '../fixtures/clip_responses.dart';

const _gql = 'https://gql.twitch.tv/gql';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late TwitchClipService service;
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
    service = TwitchClipService(dio);
  });

  void reply(Object body) =>
      adapter.onPost(_gql, (s) => s.reply(200, body), data: Matchers.any);

  Map<String, dynamic> lastBody() =>
      (requests.last.data as Map).cast<String, dynamic>();

  group('getChannelClips', () {
    test(
      'asks for the top 100 of a period anonymously, without a cursor',
      () async {
        reply(clipListResponse);

        await service.getChannelClips(
          login: 'xqc',
          period: ClipPeriod.lastWeek,
          sort: ClipSort.trending,
        );

        expect(requests.last.uri.toString(), _gql);
        expect(
          requests.last.headers['Client-ID'],
          'kimne78kx3ncx6brgo4mv6wki5h1ko',
        );
        expect(requests.last.headers['Authorization'], isNull);
        expect(lastBody()['variables'], {
          'login': 'xqc',
          'first': 100,
          'period': 'LAST_WEEK',
          'sort': 'TRENDING',
        });
        expect(lastBody()['query'], isNot(contains('after')));
      },
    );

    test('parses the clips and whether Twitch has more', () async {
      reply(clipListResponse);

      final page = await service.getChannelClips(
        login: 'xqc',
        period: ClipPeriod.allTime,
        sort: ClipSort.top,
      );

      expect(page.items.map((c) => c.id), ['2308545921', '1066051531']);
      expect(page.hasMore, isTrue);
    });

    test('skips a malformed node instead of failing the page', () async {
      reply({
        'data': {
          'user': {
            'id': '1',
            'clips': {
              'edges': [
                {
                  'node': {'id': 'broken'},
                },
                'not a map',
                {'node': clipNode},
              ],
              'pageInfo': {'hasNextPage': false},
            },
          },
        },
      });

      final page = await service.getChannelClips(
        login: 'xqc',
        period: ClipPeriod.allTime,
        sort: ClipSort.top,
      );
      expect(page.items.map((c) => c.id), ['2308545921']);
    });

    test('an empty channel is an empty page', () async {
      reply(clipListEmptyResponse);
      final page = await service.getChannelClips(
        login: 'x',
        period: ClipPeriod.lastDay,
        sort: ClipSort.top,
      );
      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
    });

    test('an unknown channel is NotFound', () async {
      reply(clipUserNotFoundResponse);
      expect(
        service.getChannelClips(
          login: 'nobody',
          period: ClipPeriod.allTime,
          sort: ClipSort.top,
        ),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('GQL errors are typed, integrity flagged', () async {
      reply(clipServerErrorResponse);
      await expectLater(
        service.getChannelClips(
          login: 'xqc',
          period: ClipPeriod.allTime,
          sort: ClipSort.top,
        ),
        throwsA(
          isA<ClipApiException>().having(
            (e) => e.isIntegrity,
            'integrity',
            false,
          ),
        ),
      );

      reply(clipIntegrityResponse);
      await expectLater(
        service.getChannelClips(
          login: 'xqc',
          period: ClipPeriod.allTime,
          sort: ClipSort.top,
        ),
        throwsA(
          isA<ClipApiException>().having(
            (e) => e.isIntegrity,
            'integrity',
            true,
          ),
        ),
      );
    });
  });

  group('getClip', () {
    test('returns the clip, or null when it is gone', () async {
      reply(clipMetadataResponse);
      final clip = await service.getClip(
        'InexpensiveHotGrouseNerfBlueBlaster--wdg-mRtFp79lgSC',
      );
      expect(clip?.title, 'breakup advice');
      expect(lastBody()['variables'], {
        'slug': 'InexpensiveHotGrouseNerfBlueBlaster--wdg-mRtFp79lgSC',
      });

      reply(clipNotFoundResponse);
      expect(await service.getClip('GoneClipSlug'), isNull);
    });

    test('an invalid slug never reaches the network', () async {
      expect(() => service.getClip('../../x'), throwsArgumentError);
      expect(requests, isEmpty);
    });
  });

  group('getClipPlayback', () {
    const slug = 'InexpensiveHotGrouseNerfBlueBlaster--wdg-mRtFp79lgSC';

    test('lists the landscape renditions, best first', () async {
      reply(clipPlaybackResponse());

      final playback = await service.getClipPlayback(slug);

      expect(playback.renditions.map((r) => r.label), [
        '1080p60',
        '720p60',
        '480p',
      ]);
      expect(
        playback.renditions.every((r) => !r.url.contains('portrait')),
        isTrue,
        reason: 'the vertical recomposed asset is not the clip',
      );
    });

    test('falls back to videoQualities without assets', () async {
      reply(clipPlaybackResponse(assets: const []));

      final playback = await service.getClipPlayback(slug);

      expect(playback.renditions.map((r) => r.label), [
        '1080p60',
        '720p60',
        '360p',
      ]);
    });

    test('drops renditions that are not https on a known CDN', () async {
      reply(
        clipPlaybackResponse(
          assets: const [],
          videoQualities: const [
            {
              'quality': '1080',
              'frameRate': 60,
              'sourceURL': 'http://d1.cloudfront.net/a.mp4',
            },
            {
              'quality': '720',
              'frameRate': 30,
              'sourceURL': 'https://evil.example/a.mp4',
            },
            {
              'quality': '480',
              'frameRate': 30,
              'sourceURL': 'https://d1.cloudfront.net.evil.example/a.mp4',
            },
            {
              'quality': '360',
              'frameRate': 30,
              'sourceURL': 'https://d1ndex63qxojbr.cloudfront.net/a.mp4',
            },
          ],
        ),
      );

      final playback = await service.getClipPlayback(slug);

      expect(playback.renditions.map((r) => r.label), ['360p']);
    });

    test('signs each URL with the token, encoded, keeping its query', () {
      final url = TwitchClipService.signedClipUrl(
        'https://d1.cloudfront.net/a/index.mp4?x=1',
        signature: 'sig',
        token: '{"a":"b c&d"}',
      );
      final uri = Uri.parse(url);
      expect(uri.host, 'd1.cloudfront.net');
      expect(uri.queryParameters, {
        'x': '1',
        'sig': 'sig',
        'token': '{"a":"b c&d"}',
      });
    });

    test('the playback signs the chosen rendition', () async {
      reply(clipPlaybackResponse());

      final playback = await service.getClipPlayback(slug);
      final uri = Uri.parse(playback.signedUrl(playback.renditions.first));

      expect(uri.queryParameters['sig'], 'fakesig');
      expect(uri.queryParameters['token'], clipTokenValue);
    });

    test('a forbidding token is a typed refusal', () async {
      reply(clipPlaybackResponse(tokenValue: clipForbiddenTokenValue));

      await expectLater(
        service.getClipPlayback(slug),
        throwsA(
          isA<ClipForbiddenException>().having(
            (e) => e.reason,
            'reason',
            'geoblocked',
          ),
        ),
      );
    });

    test('a gone clip or a missing token is NotFound / ApiException', () async {
      reply(clipNotFoundResponse);
      await expectLater(
        service.getClipPlayback(slug),
        throwsA(isA<NotFoundException>()),
      );

      reply({
        'data': {
          'clip': {'id': '1', 'playbackAccessToken': null},
        },
      });
      await expectLater(
        service.getClipPlayback(slug),
        throwsA(isA<ApiException>()),
      );
    });

    test('no playable rendition is an ApiException', () async {
      reply(clipPlaybackResponse(assets: const [], videoQualities: const []));
      await expectLater(
        service.getClipPlayback(slug),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('downloadClip', () {
    void serveBytes(String url, List<int> bytes) => dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => options.uri.toString() == url
            ? handler.resolve(
                Response<List<int>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: bytes,
                ),
              )
            : handler.next(options),
      ),
    );

    const slug = 'InexpensiveHotGrouseNerfBlueBlaster--wdg-mRtFp79lgSC';

    test('saves the 720p rendition, signed, as an mp4', () async {
      reply(clipPlaybackResponse());
      final playback = await service.getClipPlayback(slug);
      final url = playback.signedUrl(
        playback.renditions.firstWhere((r) => r.label == '720p60'),
      );
      serveBytes(url, [1, 2, 3]);
      final folder = Directory.systemTemp.createTempSync('onset_clip');
      addTearDown(() => folder.deleteSync(recursive: true));

      final file = await service.downloadClip(slug, folder);

      expect(file.path, endsWith('onset-clip-$slug.mp4'));
      expect(file.readAsBytesSync(), [1, 2, 3]);
      expect(requests.last.uri.toString(), url);
    });

    test('an empty answer is an error, never an empty file', () async {
      reply(clipPlaybackResponse());
      final playback = await service.getClipPlayback(slug);
      serveBytes(playback.signedUrl(playback.renditions[1]), []);
      final folder = Directory.systemTemp.createTempSync('onset_clip');
      addTearDown(() => folder.deleteSync(recursive: true));

      await expectLater(
        service.downloadClip(slug, folder),
        throwsA(isA<ApiException>()),
      );
      expect(folder.listSync(), isEmpty);
    });
  });

  group('renditionsFrom', () {
    List<String> labels(List<Object?> qualities, {List<Object?>? assets}) =>
        TwitchClipService.renditionsFrom({
          'videoQualities': qualities,
          'assets': ?assets,
        }).map((r) => r.label).toList();

    const cdn = 'https://d1ndex63qxojbr.cloudfront.net';

    test('bad heights are skipped, string frame rates read, labels unique', () {
      expect(
        labels([
          {'quality': '0', 'frameRate': 30, 'sourceURL': '$cdn/0.mp4'},
          {'quality': '-1', 'frameRate': 30, 'sourceURL': '$cdn/n.mp4'},
          {'quality': '1080', 'frameRate': '60', 'sourceURL': '$cdn/a.mp4'},
          {'quality': '720', 'frameRate': 30, 'sourceURL': '$cdn/b.mp4'},
          {'quality': '720', 'frameRate': 30, 'sourceURL': '$cdn/c.mp4'},
        ]),
        ['1080p60', '720p'],
      );
    });

    test('a SOURCE asset with nothing playable falls back to qualities', () {
      expect(
        labels(
          [
            {'quality': '720', 'frameRate': 30, 'sourceURL': '$cdn/b.mp4'},
          ],
          assets: [
            {
              'type': 'SOURCE',
              'videoQualities': [
                {
                  'quality': '1080',
                  'frameRate': 60,
                  'sourceURL': 'https://elsewhere.example/a.mp4',
                },
              ],
            },
          ],
        ),
        ['720p'],
      );
    });

    test('only the clip CDN Twitch serves, never any CloudFront host', () {
      expect(
        labels([
          {
            'quality': '720',
            'frameRate': 30,
            'sourceURL': 'https://dabc123attacker.cloudfront.net/a.mp4',
          },
        ]),
        isEmpty,
      );
    });
  });

  group('getCategoryClips', () {
    test('a category\'s top clips, with each broadcaster', () async {
      reply({
        'data': {
          'game': {
            'id': '32982',
            'clips': {
              'edges': [
                {
                  'node': {
                    'id': '1',
                    'slug': 'SomeSlug',
                    'title': 'Wow',
                    'viewCount': 10,
                    'createdAt': '2026-10-10T10:00:00Z',
                    'durationSeconds': 30,
                    'broadcaster': {
                      'id': '42',
                      'login': 'streamer',
                      'displayName': 'Streamer',
                    },
                  },
                },
              ],
              'pageInfo': {'hasNextPage': true},
            },
          },
        },
      });

      final page = await service.getCategoryClips(
        gameId: '32982',
        period: ClipPeriod.lastWeek,
        sort: ClipSort.top,
      );

      expect(page.items.single.broadcasterLogin, 'streamer');
      expect(page.hasMore, isTrue);
      expect(lastBody()['variables'], {
        'id': '32982',
        'first': 100,
        'period': 'LAST_WEEK',
        'sort': 'VIEWS_DESC',
      });
      expect(requests.last.headers['Authorization'], isNull);
    });

    test('a bad id never reaches the network', () async {
      expect(
        () => service.getCategoryClips(
          gameId: '1 OR 1',
          period: ClipPeriod.lastWeek,
          sort: ClipSort.top,
        ),
        throwsArgumentError,
      );
      expect(requests, isEmpty);
    });

    test('an unknown category is not found', () async {
      reply({
        'data': {'game': null},
      });
      await expectLater(
        service.getCategoryClips(
          gameId: '1',
          period: ClipPeriod.lastWeek,
          sort: ClipSort.top,
        ),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('clips that all fail to read, or none sent, are an error', () async {
      reply({
        'data': {
          'game': {
            'id': '1',
            'clips': {
              'edges': [
                {
                  'node': {'id': 'x'},
                },
              ],
            },
          },
        },
      });
      await expectLater(
        service.getCategoryClips(
          gameId: '1',
          period: ClipPeriod.lastWeek,
          sort: ClipSort.top,
        ),
        throwsA(isA<ClipApiException>()),
      );

      reply({
        'data': {
          'game': {'id': '1', 'clips': null},
        },
      });
      await expectLater(
        service.getCategoryClips(
          gameId: '1',
          period: ClipPeriod.lastWeek,
          sort: ClipSort.top,
        ),
        throwsA(isA<ClipApiException>()),
      );
    });
  });
}
