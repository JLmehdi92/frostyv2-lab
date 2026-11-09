import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/apis/twitch_clip_service.dart';

import '../fixtures/clip_extras_payloads.dart';

class _Sent {
  final requests = <RequestOptions>[];

  Map<String, Object?> get lastBody =>
      Map<String, Object?>.from(requests.last.data as Map);
}

TwitchClipService _service(_Sent sent, Object? Function(RequestOptions) reply) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        sent.requests.add(options);
        final data = reply(options);
        if (data is DioException) {
          handler.reject(data);
          return;
        }
        handler.resolve(
          Response(requestOptions: options, statusCode: 200, data: data),
        );
      },
    ),
  );
  return TwitchClipService(dio);
}

const _slug = 'SmellySlipperyEggnogDBstyle-YKZwOj2rR3IVcuor';

void main() {
  group('getClipExtras', () {
    test('reads the portrait version and the auto clip flag', () async {
      final sent = _Sent();
      final extras = await _service(
        sent,
        (_) => clipExtrasLiveResponse,
      ).getClipExtras(_slug);
      expect(extras!.hasPortrait, isTrue);
      expect(extras.autoClip, isFalse);
      expect(sent.lastBody['operationName'], 'ClipExtras');
      expect(sent.lastBody['variables'], {'slug': _slug});
    });

    test('an auto clip without a vertical asset', () async {
      final extras = await _service(
        _Sent(),
        (_) => clipExtrasAutoLandscapeResponse,
      ).getClipExtras(_slug);
      expect(extras!.autoClip, isTrue);
      expect(extras.hasPortrait, isFalse);
    });

    test('any failure hides the extras', () async {
      final service = _service(
        _Sent(),
        (o) => {
          'errors': [
            {'message': 'Cannot query field "isAutoCurated" on type "Clip".'},
          ],
        },
      );
      expect(await service.getClipExtras(_slug), isNull);
      final down = _service(
        _Sent(),
        (o) => DioException(requestOptions: o),
      );
      expect(await down.getClipExtras(_slug), isNull);
    });

    test('a bad slug never reaches Twitch', () async {
      final sent = _Sent();
      expect(
        await _service(
          sent,
          (_) => clipExtrasLiveResponse,
        ).getClipExtras('../x'),
        isNull,
      );
      expect(sent.requests, isEmpty);
    });
  });

  group('portrait renditions', () {
    final clip = {
      'assets': [
        {
          'type': 'SOURCE',
          'videoQualities': [
            {
              'quality': '1080',
              'frameRate': 60,
              'sourceURL':
                  'https://d1ndex63qxojbr.cloudfront.net/a/landscape/1080.mp4',
            },
          ],
        },
        {
          'type': 'RECOMPOSED',
          'videoQualities': [
            {
              'quality': '1044',
              'frameRate': 30,
              'sourceURL':
                  'https://d1ndex63qxojbr.cloudfront.net/a/portrait/1044.mp4',
            },
          ],
        },
      ],
    };

    test('the portrait asset is used only when asked', () {
      expect(
        TwitchClipService.renditionsFrom(clip).single.url,
        contains('landscape'),
      );
      expect(
        TwitchClipService.renditionsFrom(clip, portrait: true).single.url,
        contains('portrait'),
      );
    });

    test('no portrait asset: nothing to play, never the landscape one', () {
      expect(
        TwitchClipService.renditionsFrom({
          'assets': [(clip['assets']! as List).first],
          'videoQualities': [
            {
              'quality': '720',
              'sourceURL': 'https://d1ndex63qxojbr.cloudfront.net/b/720.mp4',
            },
          ],
        }, portrait: true),
        isEmpty,
      );
    });
  });

  group('getClipComments', () {
    test('reads the comments and the next cursor', () async {
      final sent = _Sent();
      final page = await _service(
        sent,
        (_) => clipCommentsLiveResponse,
      ).getClipComments(_slug);
      expect(page.items, hasLength(2));
      final first = page.items.first;
      expect(first.body, 'who is eggbert');
      expect(first.likeCount, 3);
      expect(first.replyCount, 1);
      expect(first.authorDisplayName, 'viewer_one');
      expect(page.items.last.collapsed, isTrue);
      expect(page.items.last.heartedByCreator, isTrue);
      expect(page.cursor, 'cursor-2');
      expect(sent.requests.last.headers['Authorization'], isNull);
    });

    test(
      'pages with the cursor and sends the web token when there is one',
      () async {
        final sent = _Sent();
        await _service(
          sent,
          (_) => clipCommentsLiveResponse,
        ).getClipComments(_slug, cursor: 'cursor-2', authToken: 'tok');
        expect((sent.lastBody['variables']! as Map)['after'], 'cursor-2');
        expect(sent.requests.last.headers['Authorization'], 'OAuth tok');
      },
    );

    test('an unreadable answer is an error, not an empty list', () async {
      final service = _service(
        _Sent(),
        (_) => {
          'data': {'clip': null},
        },
      );
      await expectLater(
        service.getClipComments(_slug),
        throwsA(isA<ClipApiException>()),
      );
    });
  });
}
