import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_watch_streak_service.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

const _gql = 'https://gql.twitch.tv/gql';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late TwitchWatchStreakService service;
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
    service = TwitchWatchStreakService(dio);
  });

  void reply(Object? body, {int status = 200}) => adapter.onPost(
    _gql,
    (server) => server.reply(status, body),
    data: Matchers.any,
  );

  group('a channel streak', () {
    test('is read as the viewer, with Twitch own query', () async {
      reply({
        'data': {
          'channel': {
            'self': {
              'watchStreakMilestone': {
                'watchStreakMilestone': {'value': '3'},
                'watchStreakThreshold': 5,
                'watchStreakCopoBonus': 450,
                'state': 'ACTIVE',
                'expiresAt': null,
              },
            },
          },
          'channelViewerMilestoneSettings': {'isWatchStreakOptOut': false},
        },
      });

      final streak = await service.getWatchStreak(
        channelId: '12826',
        authToken: 'webtok',
      );

      expect(streak!.value, 3);
      final request = requests.single;
      expect(request.uri.host, 'gql.twitch.tv');
      expect(request.headers['Authorization'], 'OAuth webtok');
      expect(request.data['operationName'], 'WatchStreakMilestoneQuery');
      expect(request.data['variables'], {'channelId': '12826'});
    });

    test('a refusal, an error or the network gives nothing', () async {
      reply({
        'errors': [
          {'message': 'failed integrity check'},
        ],
      });
      expect(
        await service.getWatchStreak(channelId: '1', authToken: 't'),
        isNull,
      );

      reply({'error': 'Unauthorized'}, status: 401);
      expect(
        await service.getWatchStreak(channelId: '1', authToken: 't'),
        isNull,
      );
    });

    test('no token or an odd channel id, no request', () async {
      expect(
        await service.getWatchStreak(channelId: '1', authToken: ''),
        isNull,
      );
      expect(
        await service.getWatchStreak(channelId: 'x/y', authToken: 't'),
        isNull,
      );
      expect(requests, isEmpty);
    });
  });

  group('the followed streaks', () {
    test('are read in one request', () async {
      reply({
        'data': {
          'batchGetWatchStreaks': [
            {
              'channel': {'id': '7'},
              'value': 12,
              'isSuspended': false,
            },
          ],
        },
      });

      expect(await service.getStreaks(authToken: 'webtok'), {'7': 12});
      expect(requests.single.headers['Authorization'], 'OAuth webtok');
      expect(
        requests.single.data['operationName'],
        'BatchGetWatchStreaksQuery',
      );
    });

    test('any failure gives nothing', () async {
      reply({'message': 'down'}, status: 503);

      expect(await service.getStreaks(authToken: 't'), isNull);
      expect(await service.getStreaks(authToken: ''), isNull);
    });
  });
}
