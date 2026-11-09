import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/apis/twitch_clip_service.dart';
import 'package:onset/models/recap.dart';

import '../fixtures/clip_extras_payloads.dart';

TwitchClipService _service(
  List<RequestOptions> sent,
  Object? Function(RequestOptions) reply,
) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        sent.add(options);
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: reply(options),
          ),
        );
      },
    ),
  );
  return TwitchClipService(dio);
}

Map<String, Object?> _body(RequestOptions o) =>
    Map<String, Object?>.from(o.data as Map);

void main() {
  group('getChannelRecaps', () {
    test(
      'reads a channel’s published recaps and their clips in order',
      () async {
        final sent = <RequestOptions>[];
        final recaps = await _service(
          sent,
          (_) => channelRecapsResponse([
            recapNode(),
            recapNode(id: 'gone-0000', state: 'UNPUBLISHED'),
          ]),
        ).getChannelRecaps('1000');
        expect(recaps, hasLength(1));
        final recap = recaps.single;
        expect(recap.title, 'Warzone night');
        expect(recap.channelLogin, 'caster');
        expect(recap.clips.map((c) => c.title), ['im down', 'second']);
        expect(recap.duration, const Duration(seconds: 95));
        expect(recap.thumbnailUrl, startsWith('https://'));
        final body = _body(sent.single);
        expect(body['operationName'], 'ChannelRecaps');
        expect(body['variables'], {'channelID': '1000', 'first': 10});
        expect(sent.single.headers['Authorization'], isNull);
      },
    );

    test('any failure is an empty shelf; a bad id is never sent', () async {
      final sent = <RequestOptions>[];
      final failing = _service(
        sent,
        (_) => {
          'errors': [
            {'message': 'Cannot query field "recaps" on type "Query".'},
          ],
        },
      );
      expect(await failing.getChannelRecaps('1000'), isEmpty);
      expect(await failing.getChannelRecaps('x y'), isEmpty);
      expect(sent, hasLength(1));
    });

    test('a recap without a playable clip is dropped', () async {
      final node = recapNode()..['clips'] = <Object>[];
      expect(
        await _service(
          <RequestOptions>[],
          (_) => channelRecapsResponse([node]),
        ).getChannelRecaps('1000'),
        isEmpty,
      );
    });
  });

  group('getRecap', () {
    test('reads the recap again by its id', () async {
      final sent = <RequestOptions>[];
      final recap = await _service(
        sent,
        (_) => recapsByIdsResponse([recapNode()]),
      ).getRecap('2cca905c-0000-0000-0000-000000000000');
      expect(recap.clips, hasLength(2));
      expect(_body(sent.single)['variables'], {
        'ids': ['2cca905c-0000-0000-0000-000000000000'],
      });
    });

    test('gone or unpublished: no longer available', () async {
      await expectLater(
        _service(
          <RequestOptions>[],
          (_) => recapsByIdsResponse([]),
        ).getRecap('2cca905c-0000-0000-0000-000000000000'),
        throwsA(isA<RecapUnavailableException>()),
      );
      await expectLater(
        _service(
          <RequestOptions>[],
          (_) => recapsByIdsResponse([recapNode(state: 'UNPUBLISHED')]),
        ).getRecap('2cca905c-0000-0000-0000-000000000000'),
        throwsA(isA<RecapUnavailableException>()),
      );
    });

    test('an API change is an error, not “unavailable”', () async {
      await expectLater(
        _service(
          <RequestOptions>[],
          (_) => {
            'errors': [
              {'message': 'boom'},
            ],
          },
        ).getRecap('2cca905c-0000-0000-0000-000000000000'),
        throwsA(isA<ClipApiException>()),
      );
    });
  });
}
