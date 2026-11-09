import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/models/chat_ui_settings.dart';

import '../fixtures/chat_ui_settings_payloads.dart';

const _gql = 'https://gql.twitch.tv/gql';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late List<RequestOptions> requests;
  late TwitchViewerActionsService service;

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
    service = TwitchViewerActionsService(dio);
  });

  void reply(Object? body) => adapter.onPost(
    _gql,
    (server) => server.reply(200, body),
    data: Matchers.any,
  );

  Map<String, dynamic> sent() {
    final data = requests.single.data;
    return Map<String, dynamic>.from(
      data is String ? jsonDecode(data) as Map : data as Map,
    );
  }

  test('reads the four synced chat settings with the web token', () async {
    reply(chatUiSettingsResponse());
    final settings = await service.chatUiSettings(authToken: 'tok');
    expect(settings, isNotNull);
    expect(settings![ChatUiSetting.readableColors], isTrue);
    expect(settings[ChatUiSetting.gifAnimations], isFalse);
    expect(sent()['operationName'], 'ChatUISettingsQuery');
    expect(requests.single.headers['Authorization'], 'OAuth tok');
  });

  test('a missing setting hides the sync', () async {
    reply({
      'data': {
        'currentUser': {
          'chatUISettings': {'isGifsEnabled': true},
        },
      },
    });
    expect(await service.chatUiSettings(authToken: 'tok'), isNull);
  });

  test('an error or a signed-out viewer reads nothing', () async {
    reply({
      'errors': [
        {'message': 'unauthenticated'},
      ],
    });
    expect(await service.chatUiSettings(authToken: 'tok'), isNull);
    requests.clear();
    expect(await service.chatUiSettings(authToken: ''), isNull);
    expect(requests, isEmpty);
  });

  for (final setting in ChatUiSetting.values) {
    test('${setting.name} is saved with its own mutation', () async {
      reply(setChatUiSettingResponse(setting.mutation, false));
      expect(
        await service.updateChatUiSetting(
          setting: setting,
          enabled: false,
          authToken: 'tok',
        ),
        ViewerActionOutcome.done,
      );
      final body = sent();
      expect(body['operationName'], setting.operation);
      expect(body['variables'], {
        'input': {setting.field: false},
      });
      expect(body['query'], contains('${setting.mutation}(input: \$input)'));
    });
  }

  test('a change Twitch does not echo is not done', () async {
    reply(setChatUiSettingResponse('setGifsEnabled', true));
    expect(
      await service.updateChatUiSetting(
        setting: ChatUiSetting.gifs,
        enabled: false,
        authToken: 'tok',
      ),
      ViewerActionOutcome.failed,
    );
  });

  test('an anti-bot refusal is told apart', () async {
    reply({
      'errors': [
        {'message': 'failed integrity check'},
      ],
    });
    expect(
      await service.updateChatUiSetting(
        setting: ChatUiSetting.gifs,
        enabled: false,
        authToken: 'tok',
      ),
      ViewerActionOutcome.integrityRefused,
    );
  });
}
