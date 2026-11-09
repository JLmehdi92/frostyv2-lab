import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:onset/apis/twitch_channel_profile_service.dart';

import '../fixtures/clip_eligibility_payloads.dart';

const _gql = 'https://gql.twitch.tv/gql';

void main() {
  late DioAdapter adapter;
  late TwitchChannelProfileService service;

  setUp(() {
    final dio = Dio(BaseOptions());
    adapter = DioAdapter(dio: dio);
    service = TwitchChannelProfileService(dio);
  });

  void reply(Object body, {int status = 200}) => adapter.onPost(
    _gql,
    (server) => server.reply(status, body),
    data: Matchers.any,
  );

  test('reads the DJ role seen live', () async {
    reply(djRoleLive);
    expect(await service.isParticipatingDj('djchannel'), isTrue);
  });

  test(
    'fails closed on a schema error, a server error or a bad login',
    () async {
      reply(djRoleRejected);
      expect(await service.isParticipatingDj('djchannel'), isFalse);
      reply({'message': 'down'}, status: 500);
      expect(await service.isParticipatingDj('djchannel'), isFalse);
      expect(await service.isParticipatingDj('not a login'), isFalse);
    },
  );
}
