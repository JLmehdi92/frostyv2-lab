import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/apis/twitch_chat_rules_service.dart';
import 'package:frosty/constants.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

const _gql = 'https://gql.twitch.tv/gql';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late TwitchChatRulesService service;
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
    service = TwitchChatRulesService(dio);
  });

  void reply(Object body) => adapter.onPost(
    _gql,
    (s) => s.reply(200, body),
    data: Matchers.any,
  );

  test("asks Twitch's ChatRules query anonymously, by channel id", () async {
    reply({
      'data': {
        'user': {
          'id': '71092938',
          'displayName': 'xQc',
          'profileImageURL':
              'https://static-cdn.jtvnw.net/jtv_user_pictures/xqc.jpeg',
          'chatSettings': {
            'rules': ['English please', 'Fresh memes'],
          },
        },
      },
    });

    final rules = await service.getRules('71092938');

    expect(rules?.rules, ['English please', 'Fresh memes']);
    expect(rules?.channelName, 'xQc');
    final request = requests.single;
    expect(request.headers['Client-ID'], kTwitchWebClientId);
    expect(request.headers.containsKey('Authorization'), isFalse);
    final data = request.data as Map;
    expect(data['operationName'], 'ChatRules');
    expect(data['variables'], {'userID': '71092938'});
    expect(data['query'], contains('chatSettings { rules }'));
  });

  test('an unknown channel is null', () async {
    reply({
      'data': {'user': null},
    });
    expect(await service.getRules('1'), isNull);
  });

  test('an answer without data throws, so nothing is shown', () async {
    reply({
      'errors': [
        {'message': 'failed integrity check'},
      ],
    });
    await expectLater(
      service.getRules('1'),
      throwsA(isA<ApiException>()),
    );
  });

  test('a channel id that is not one never reaches the network', () async {
    expect(() => service.getRules('../x'), throwsArgumentError);
    expect(() => service.getRules(''), throwsArgumentError);
    expect(requests, isEmpty);
  });
}
