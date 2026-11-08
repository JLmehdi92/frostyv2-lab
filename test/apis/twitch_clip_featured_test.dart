import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/apis/twitch_clip_service.dart';
import 'package:onset/models/clip.dart';

import '../fixtures/clip_responses.dart';

TwitchClipService _service(
  List<String> queries, {
  required bool rejectFeatured,
}) {
  final dio = Dio(BaseOptions());
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final query = '${(options.data as Map)['query']}';
        queries.add(query);
        final featured = query.contains('isFeatured');
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: featured && rejectFeatured ? 422 : 200,
            data: featured && rejectFeatured
                ? {
                    'errors': [
                      {
                        'message':
                            'Cannot query field "isFeatured" on type "Clip".',
                      },
                    ],
                  }
                : clipListResponse,
          ),
        );
      },
    ),
  );
  return TwitchClipService(dio);
}

void main() {
  test('channel clips ask whether each clip is featured', () async {
    final queries = <String>[];
    final page = await _service(queries, rejectFeatured: false).getChannelClips(
      login: 'xqc',
      period: ClipPeriod.lastWeek,
      sort: ClipSort.top,
    );
    expect(queries.single, contains('isFeatured'));
    expect(page.featuredKnown, isTrue);
    expect(page.items, isNotEmpty);
  });

  test('a refused featured field falls back to the plain list', () async {
    final queries = <String>[];
    final page = await _service(queries, rejectFeatured: true).getChannelClips(
      login: 'xqc',
      period: ClipPeriod.lastWeek,
      sort: ClipSort.top,
    );
    expect(queries, hasLength(2));
    expect(queries.last, isNot(contains('isFeatured')));
    expect(page.featuredKnown, isFalse);
    expect(page.items, isNotEmpty);
  });
}
