import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_points_service.dart';
import 'package:onset/apis/twitch_tv_session_interceptor.dart';
import 'package:onset/constants.dart';
import 'package:onset/models/community_points.dart';
import 'package:onset/models/twitch_tv_session.dart';
import 'package:onset/screens/channel/stores/channel_events_store.dart';
import 'package:onset/services/hermes_client.dart';

class _MockHermes extends Mock implements HermesClient {}

void main() {
  test(
    'points mutations from the channel store carry the TV session',
    () async {
      final sent = <RequestOptions>[];
      final hermes = _MockHermes();
      when(() => hermes.events).thenAnswer((_) => const Stream.empty());
      final service = TwitchPointsService.withDefaults(
        interceptors: [
          TwitchTvSessionInterceptor(
            credentials: () => const TwitchTvCredentials(
              session: TwitchTvSession(
                accessToken: 'tv-access',
                userId: '77',
                deviceId: 'tvdevice00000001',
              ),
              clientSessionId: 'session000000001',
            ),
            onRejected: () {},
          ),
          InterceptorsWrapper(
            onRequest: (options, handler) {
              sent.add(options);
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'data': {
                      'redeemCommunityPointsCustomReward': {'error': null},
                    },
                  },
                ),
              );
            },
          ),
        ],
      );
      final store = ChannelEventsStore(
        channelId: '1',
        channelLogin: 'chan',
        viewerId: '77',
        client: hermes,
        pointsService: service,
        tokenProvider: () async => 'web-token',
      );
      await store.redeemReward(
        const PointsReward(id: 'r1', title: 'Hydrate', cost: 100),
      );
      final headers = {
        for (final e
            in sent
                .singleWhere(
                  (request) => '${(request.data as Map)['query']}'
                      .trimLeft()
                      .startsWith('mutation'),
                )
                .headers
                .entries)
          e.key.toLowerCase(): e.value,
      };
      expect(headers['client-id'], kTwitchTvClientId);
      expect(headers['authorization'], 'OAuth tv-access');
      expect(headers['x-device-id'], 'tvdevice00000001');
    },
  );
}
