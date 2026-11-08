import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:onset/apis/twitch_api.dart';

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late TwitchApi api;

  const helix = 'https://api.twitch.tv/helix';

  setUp(() {
    dio = Dio(BaseOptions());
    dioAdapter = DioAdapter(dio: dio);
    api = TwitchApi(dio);
  });

  test('a block sends the reason and where it came from', () async {
    dioAdapter.onPut(
      '$helix/users/blocks',
      (server) => server.reply(204, null),
      queryParameters: {
        'target_user_id': '42',
        'source_context': 'chat',
        'reason': 'harassment',
      },
    );

    expect(
      await api.blockUser(
        userId: '42',
        reason: BlockReason.harassment,
        source: BlockSource.chat,
      ),
      isTrue,
    );
  });

  test('a block without a reason sends only the target', () async {
    dioAdapter.onPut(
      '$helix/users/blocks',
      (server) => server.reply(204, null),
      queryParameters: {'target_user_id': '42'},
    );

    expect(await api.blockUser(userId: '42'), isTrue);
  });
}
