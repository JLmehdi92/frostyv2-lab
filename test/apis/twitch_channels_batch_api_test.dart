import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

const _helix = 'https://api.twitch.tv/helix';

Map<String, Object?> _channel(String id, List<String> labels) => {
  'broadcaster_id': id,
  'broadcaster_login': 'c$id',
  'broadcaster_name': 'C$id',
  'broadcaster_language': 'en',
  'title': 'Title',
  'game_id': '1',
  'game_name': 'Game',
  'content_classification_labels': labels,
};

void main() {
  late DioAdapter adapter;
  late TwitchApi api;

  setUp(() {
    final dio = Dio(BaseOptions());
    adapter = DioAdapter(dio: dio);
    api = TwitchApi(dio);
  });

  test('channels are asked for by id, many at once', () async {
    adapter.onGet(
      '$_helix/channels',
      (server) => server.reply(200, {
        'data': [
          _channel('1', ['SexualThemes']),
          _channel('2', []),
        ],
      }),
      queryParameters: {
        'broadcaster_id': ['1', '2'],
      },
    );

    final channels = await api.getChannelsByIds(['1', '2']);

    expect(channels.keys, ['1', '2']);
    expect(channels['1']!.contentClassificationLabels, ['SexualThemes']);
    expect(await api.getChannelsByIds([]), isEmpty);
    expect(() => api.getChannelsByIds(['1', 'x&y']), throwsArgumentError);
  });

  test('more than a hundred take several requests', () async {
    final ids = [for (var i = 1; i <= 150; i++) '$i'];
    adapter
      ..onGet(
        '$_helix/channels',
        (server) => server.reply(200, {
          'data': [_channel('1', [])],
        }),
        queryParameters: {'broadcaster_id': ids.sublist(0, 100)},
      )
      ..onGet(
        '$_helix/channels',
        (server) => server.reply(200, {
          'data': [
            _channel('150', ['Gambling']),
          ],
        }),
        queryParameters: {'broadcaster_id': ids.sublist(100)},
      );

    final channels = await api.getChannelsByIds(ids);

    expect(channels.keys, ['1', '150']);
  });
}
