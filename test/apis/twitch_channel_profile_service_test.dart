import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:onset/apis/twitch_channel_profile_service.dart';
import 'package:onset/constants.dart';

import '../fixtures/channel_profile_payloads.dart';

const _gql = 'https://gql.twitch.tv/gql';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late TwitchChannelProfileService service;
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
    service = TwitchChannelProfileService(dio);
  });

  void reply(Object body) => adapter.onPost(
    _gql,
    (s) => s.reply(200, body is String ? jsonDecode(body) : body),
    data: Matchers.any,
  );

  test('the profile, anonymously, by lowercase login', () async {
    reply(gqlChannelProfileXqc);

    final profile = await service.getProfile(' xQc ');

    expect(profile?.displayName, 'xQc');
    final request = requests.single;
    expect(request.headers['Client-ID'], kTwitchWebClientId);
    expect(request.headers.containsKey('Authorization'), isFalse);
    final data = request.data as Map;
    expect(data['operationName'], 'ChannelProfile');
    expect(data['variables'], {'login': 'xqc'});
    expect(data['query'], contains('panels'));
    // The live card's uptime and category (verified anonymously on
    // 2026-10-29).
    expect(
      data['query'],
      contains(
        'stream { id type viewersCount createdAt game { displayName } }',
      ),
    );
  });

  test('an unknown channel is null', () async {
    reply(gqlChannelProfileNoUser);
    expect(await service.getProfile('nobody'), isNull);
  });

  test('the schedule, and none when the channel has none', () async {
    reply(gqlChannelScheduleStreamer);
    expect((await service.getSchedule('streamer')).segments, hasLength(6));

    reply({
      'data': {
        'user': {
          'id': '1',
          'channel': {'id': '1', 'schedule': null},
        },
      },
    });
    expect((await service.getSchedule('someone')).segments, isEmpty);
  });

  test('a bad login never reaches the network', () async {
    expect(() => service.getProfile('a b'), throwsArgumentError);
    expect(() => service.getSchedule('../x'), throwsArgumentError);
    expect(requests, isEmpty);
  });

  test('errors without data throw typed', () async {
    reply({
      'errors': [
        {'message': 'service timeout'},
      ],
      'data': null,
    });
    await expectLater(
      service.getProfile('xqc'),
      throwsA(isA<ChannelProfileApiException>()),
    );
  });

  test('a nested resolver error keeps the rest', () async {
    final body = jsonDecode(gqlChannelProfileXqc) as Map<String, dynamic>;
    body['errors'] = [
      {
        'message': 'server error',
        'path': ['user', 'panels'],
      },
    ];
    (body['data']['user'] as Map)['panels'] = null;
    reply(body);

    final profile = await service.getProfile('xqc');
    expect(profile?.panels, isEmpty);
    expect(profile?.followers, isNotNull);
  });

  test('a user nulled by an error, or unreadable, throws', () async {
    reply({
      'data': {'user': null},
      'errors': [
        {
          'message': 'service timeout',
          'path': ['user'],
        },
      ],
    });
    await expectLater(
      service.getProfile('xqc'),
      throwsA(isA<ChannelProfileApiException>()),
    );

    reply({
      'data': {
        'user': {'id': 'not a number', 'login': 'xqc'},
      },
    });
    await expectLater(
      service.getProfile('xqc'),
      throwsA(isA<ChannelProfileApiException>()),
    );
  });

  test(
    'a schedule nulled by an error throws instead of reading empty',
    () async {
      reply({
        'data': {
          'user': {
            'id': '1',
            'channel': {'id': '1', 'schedule': null},
          },
        },
        'errors': [
          {
            'message': 'service timeout',
            'path': ['user', 'channel', 'schedule'],
          },
        ],
      });
      await expectLater(
        service.getSchedule('xqc'),
        throwsA(isA<ChannelProfileApiException>()),
      );
    },
  );
}
