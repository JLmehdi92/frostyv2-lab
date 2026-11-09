import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';

const _gql = 'https://gql.twitch.tv/gql';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late TwitchViewerActionsService service;
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

  Map<dynamic, dynamic> input() => (sent()['variables'] as Map)['input'] as Map;

  group('setLeadModerator', () {
    test('assigns the lead_mod role with the exact document', () async {
      reply({
        'data': {
          'assignChannelRole': {'isAssigned': true, 'error': null},
        },
      });

      final outcome = await service.setLeadModerator(
        channelId: '11',
        userId: '33',
        granted: true,
        authToken: 'tok',
      );

      expect(outcome, ViewerActionOutcome.done);
      expect(sent()['operationName'], 'AssignLeadModMutation');
      expect(sent()['query'], contains('assignChannelRole(input: \$input)'));
      expect(input(), {
        'channelID': '11',
        'roleID': 'lead_mod',
        'targetUserID': '33',
      });
      expect(requests.single.headers['Authorization'], 'OAuth tok');
    });

    test('unassigns with the unassign document', () async {
      reply({
        'data': {
          'unassignChannelRole': {'isUnassigned': true, 'error': null},
        },
      });

      final outcome = await service.setLeadModerator(
        channelId: '11',
        userId: '33',
        granted: false,
        authToken: 'tok',
      );

      expect(outcome, ViewerActionOutcome.done);
      expect(sent()['operationName'], 'UnassignLeadModMutation');
    });

    test('an error code is a refusal and a false flag a failure', () async {
      reply({
        'data': {
          'assignChannelRole': {
            'isAssigned': false,
            'error': {'code': 'MAX_REACHED'},
          },
        },
      });
      expect(
        await service.setLeadModerator(
          channelId: '11',
          userId: '33',
          granted: true,
          authToken: 'tok',
        ),
        ViewerActionOutcome.refused,
      );
    });

    test('a false flag without an error is a failure', () async {
      reply({
        'data': {
          'assignChannelRole': {'isAssigned': false, 'error': null},
        },
      });
      expect(
        await service.setLeadModerator(
          channelId: '11',
          userId: '33',
          granted: true,
          authToken: 'tok',
        ),
        ViewerActionOutcome.failed,
      );
    });

    test('bad ids and a missing token send nothing', () async {
      expect(
        await service.setLeadModerator(
          channelId: '11; drop',
          userId: '33',
          granted: true,
          authToken: 'tok',
        ),
        ViewerActionOutcome.failed,
      );
      expect(
        await service.setLeadModerator(
          channelId: '11',
          userId: '33',
          granted: true,
          authToken: '',
        ),
        ViewerActionOutcome.signedOut,
      );
      expect(requests, isEmpty);
    });
  });

  group('pinMessage', () {
    test('pins as a moderator for 20 minutes', () async {
      reply({
        'data': {
          'pinChatMessage': {
            'pinnedChatMessage': {
              'id': 'pin-1',
              'pinnedMessage': {'id': 'm-1'},
            },
            'error': null,
          },
        },
      });

      final outcome = await service.pinMessage(
        channelId: '11',
        messageId: 'abc-123',
        authToken: 'tok',
      );

      expect(outcome, ViewerActionOutcome.done);
      expect(sent()['operationName'], 'PinChatMessage');
      expect(input(), {
        'channelID': '11',
        'durationSeconds': 1200,
        'messageID': 'abc-123',
        'type': 'MOD',
      });
    });

    test('an error code is a refusal', () async {
      reply({
        'data': {
          'pinChatMessage': {
            'pinnedChatMessage': null,
            'error': {'code': 'FORBIDDEN'},
          },
        },
      });
      expect(
        await service.pinMessage(
          channelId: '11',
          messageId: 'abc',
          authToken: 'tok',
        ),
        ViewerActionOutcome.refused,
      );
    });

    test('an integrity error is said as such', () async {
      reply({
        'errors': [
          {'message': 'failed integrity check'},
        ],
      });
      expect(
        await service.pinMessage(
          channelId: '11',
          messageId: 'abc',
          authToken: 'tok',
        ),
        ViewerActionOutcome.integrityRefused,
      );
    });
  });

  group('unpinMessage', () {
    test('unpins by the pin id with the UNPIN reason', () async {
      reply({
        'data': {
          'unpinChatMessage': {
            'unpinnedChatMessage': {
              'id': 'pin-1',
              'pinnedMessage': {'id': 'm-1'},
            },
            'error': null,
          },
        },
      });

      expect(
        await service.unpinMessage(pinId: 'pin-1', authToken: 'tok'),
        ViewerActionOutcome.done,
      );
      expect(sent()['operationName'], 'unpinChatMessage');
      expect(input(), {'id': 'pin-1', 'reason': 'UNPIN'});
    });

    test('a malformed pin id sends nothing', () async {
      expect(
        await service.unpinMessage(pinId: 'a b', authToken: 'tok'),
        ViewerActionOutcome.failed,
      );
      expect(requests, isEmpty);
    });
  });
}
