import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:onset/apis/twitch_community_service.dart';
import 'package:onset/models/channel_leaderboards.dart';

import '../fixtures/community_gql_payloads.dart';
import '../fixtures/drops_gql_payloads.dart';

const _gql = 'https://gql.twitch.tv/gql';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late TwitchCommunityService service;
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
    service = TwitchCommunityService(dio);
  });

  void reply(Object? body, {int status = 200}) => adapter.onPost(
    _gql,
    (server) => server.reply(status, body),
    data: Matchers.any,
  );

  Map<String, dynamic> sent() {
    final data = requests.single.data;
    return Map<String, dynamic>.from(
      data is String ? jsonDecode(data) as Map : data as Map,
    );
  }

  group('getResubNotification', () {
    test('asks for the channel resub with the viewer token', () async {
      reply(resubNotificationResponse);

      final resub = await service.getResubNotification(
        channelId: '42',
        authToken: 'tok',
      );

      expect(resub?.months, 14);
      expect(sent()['operationName'], 'ChannelResubNotificationQuery');
      expect(sent()['variables'], {'channelId': '42'});
      expect(requests.single.headers['Authorization'], 'OAuth tok');
    });

    test('sends nothing without a token or with a bad channel id', () async {
      expect(
        await service.getResubNotification(channelId: '42', authToken: ''),
        isNull,
      );
      expect(
        await service.getResubNotification(channelId: 'x', authToken: 'tok'),
        isNull,
      );
      expect(requests, isEmpty);
    });

    test('answers null on a server failure', () async {
      reply({'error': 'boom'}, status: 500);

      expect(
        await service.getResubNotification(channelId: '42', authToken: 'tok'),
        isNull,
      );
    });
  });

  group('getLeaderboards', () {
    test('asks anonymously for the boards and the settings', () async {
      reply(leaderboardsResponse);

      final boards = await service.getLeaderboards(channelId: '42');

      expect(boards?.kinds, [LeaderboardKind.cheers, LeaderboardKind.gifts]);
      expect(sent()['operationName'], 'ChannelLeaderboardsQuery');
      expect(sent()['variables'], {
        'channelId': '42',
        'fetchChannelSettings': true,
      });
      expect(requests.single.headers.containsKey('Authorization'), isFalse);
    });

    test('adds the viewer token when there is one', () async {
      reply(leaderboardsResponse);

      await service.getLeaderboards(channelId: '42', authToken: 'tok');

      expect(requests.single.headers['Authorization'], 'OAuth tok');
    });

    test('answers null on an error or a bad id', () async {
      reply({
        'errors': [
          {'message': 'service error'},
        ],
      });

      expect(await service.getLeaderboards(channelId: '42'), isNull);
      expect(await service.getLeaderboards(channelId: '4 2'), isNull);
    });
  });

  group('getShoutoutProfile', () {
    test('reads the profile anonymously without a token', () async {
      reply(shoutoutResponse);

      final profile = await service.getShoutoutProfile(
        channelLogin: 'SomeChannel',
        targetLogin: 'Target',
      );

      expect(profile?.displayName, 'Target');
      expect(profile?.following, isNull);
      expect(sent()['operationName'], 'ShoutoutQuery');
      expect(sent()['variables'], {
        'channelLogin': 'somechannel',
        'targetLogin': 'target',
      });
    });

    test('adds whether the viewer follows with a token', () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: (options.data as Map)['operationName'] == 'ShoutoutQuery'
                  ? shoutoutResponse
                  : followingShoutoutStatusResponse,
            ),
          ),
        ),
      );

      final profile = await service.getShoutoutProfile(
        channelLogin: 'somechannel',
        targetLogin: 'target',
        authToken: 'tok',
      );

      expect(profile?.following, isTrue);
      expect(requests, hasLength(2));
      expect(requests.first.headers.containsKey('Authorization'), isFalse);
      expect(requests.last.headers['Authorization'], 'OAuth tok');
    });

    test('a bad login is never sent', () async {
      expect(
        await service.getShoutoutProfile(
          channelLogin: 'some channel',
          targetLogin: 'target',
        ),
        isNull,
      );
      expect(requests, isEmpty);
    });
  });
  group('getDropCampaigns', () {
    test('asks with the viewer token for the progress', () async {
      reply(signedInDropCampaignsResponse());

      final campaigns = await service.getDropCampaigns(
        channelId: '42',
        authToken: 'tok',
      );

      expect(campaigns!.single.claimableCount, 1);
      expect(sent()['operationName'], 'ViewerDropsCampaignsQuery');
      expect(sent()['variables'], {'channelID': '42'});
      expect(sent()['query'], contains('TimeBasedDropSelfEdgeFragment'));
      expect(requests.single.headers['Authorization'], 'OAuth tok');
    });

    test('asks without the viewer fields when logged out', () async {
      reply(anonymousDropCampaignsResponse);

      final campaigns = await service.getDropCampaigns(channelId: '42');

      expect(campaigns!.single.drops.single.progress, isNull);
      expect(sent()['query'], isNot(contains('self')));
      expect(requests.single.headers.containsKey('Authorization'), isFalse);
    });

    test('sends nothing for a bad id and answers null on failure', () async {
      expect(await service.getDropCampaigns(channelId: 'x'), isNull);
      expect(requests, isEmpty);

      reply({'error': 'boom'}, status: 500);
      expect(await service.getDropCampaigns(channelId: '42'), isNull);
    });
  });
}
