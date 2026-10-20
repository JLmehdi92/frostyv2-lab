import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/stream.dart';

import '../fixtures/api_responses.dart';

void main() {
  group('StreamTwitch', () {
    test('fromJson deserializes snake_case fields', () {
      final stream = StreamTwitch.fromJson(
        (twitchStreamResponse['data']! as List).first as Map<String, dynamic>,
      );

      expect(stream.userId, '12345');
      expect(stream.userLogin, 'testuser');
      expect(stream.userName, 'TestUser');
      expect(stream.gameId, '509658');
      expect(stream.gameName, 'Just Chatting');
      expect(stream.title, 'Test Stream');
      expect(stream.viewerCount, 1000);
      expect(stream.startedAt, '2024-01-01T00:00:00Z');
      expect(stream.thumbnailUrl, 'https://cdn/thumb.jpg');
      expect(stream.id, '40000000001');
    });

    test('a stream without an id reads as an empty id', () {
      final json = Map<String, dynamic>.of(
        (twitchStreamResponse['data']! as List).first as Map<String, dynamic>,
      )..remove('id');

      expect(StreamTwitch.fromJson(json).id, '');
    });
  });

  group('StreamsTwitch', () {
    test('fromJson deserializes data and pagination', () {
      final streams = StreamsTwitch.fromJson(
        twitchStreamResponse as Map<String, dynamic>,
      );

      expect(streams.data.length, 1);
      expect(streams.data.first.userName, 'TestUser');
      expect(streams.pagination['cursor'], 'next_cursor');
    });

    test('fromJson handles empty data list', () {
      final streams = StreamsTwitch.fromJson(const {
        'data': <dynamic>[],
        'pagination': <String, String>{},
      });

      expect(streams.data, isEmpty);
    });
  });

  test('tags and language, empty when Helix leaves them out', () {
    final base = {
      'user_id': '1',
      'user_login': 'a',
      'user_name': 'A',
      'game_id': '2',
      'game_name': 'G',
      'title': 'T',
      'viewer_count': 3,
      'started_at': '2026-10-13T15:00:00Z',
      'thumbnail_url': 'https://x/{width}x{height}.jpg',
    };
    final tagged = StreamTwitch.fromJson({
      ...base,
      'tags': ['English', 'Speedrun'],
      'language': 'en',
    });
    expect(tagged.tags, ['English', 'Speedrun']);
    expect(tagged.language, 'en');

    final bare = StreamTwitch.fromJson({...base, 'tags': null});
    expect(bare.tags, isEmpty);
    expect(bare.language, '');
  });
}
