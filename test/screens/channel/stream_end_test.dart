import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_vod_service.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/models/vod.dart';
import 'package:onset/screens/channel/stream_end.dart';

class _MockApi extends Mock implements TwitchApi {}

class _MockVods extends Mock implements TwitchVodService {}

Vod _vod(
  String id,
  DateTime createdAt, {
  String? broadcastId,
  VodType type = VodType.archive,
}) => Vod(
  id: id,
  title: 'Stream',
  lengthSeconds: 3600,
  createdAt: createdAt,
  viewCount: 1,
  ownerId: '1',
  ownerLogin: 'streamer',
  ownerDisplayName: 'Streamer',
  type: type,
  broadcastId: broadcastId,
);

StreamTwitch _stream({String id = '', String startedAt = ''}) => StreamTwitch(
  '1',
  'streamer',
  'Streamer',
  '',
  '',
  'Title',
  10,
  startedAt,
  '',
  id: id,
);

void main() {
  late _MockApi api;
  late _MockVods vods;
  late StreamEndLookup lookup;

  setUp(() {
    api = _MockApi();
    vods = _MockVods();
    lookup = StreamEndLookup(api: api, vods: vods);
  });

  group('isVodOfBroadcast', () {
    final started = DateTime.utc(2026, 11, 8, 18);

    test('matches the broadcast id when Twitch gives one', () {
      expect(
        isVodOfBroadcast(
          _vod('1', started, broadcastId: '42'),
          _stream(id: '42'),
        ),
        isTrue,
      );
      expect(
        isVodOfBroadcast(
          _vod('1', started, broadcastId: '41'),
          _stream(id: '42'),
        ),
        isFalse,
      );
    });

    test('otherwise a past broadcast that began with the stream', () {
      final stream = _stream(startedAt: started.toIso8601String());
      expect(
        isVodOfBroadcast(
          _vod('1', started.add(const Duration(seconds: 20))),
          stream,
        ),
        isTrue,
      );
      expect(
        isVodOfBroadcast(
          _vod('1', started.subtract(const Duration(days: 1))),
          stream,
        ),
        isFalse,
      );
      expect(
        isVodOfBroadcast(_vod('1', started, type: VodType.highlight), stream),
        isFalse,
      );
      expect(isVodOfBroadcast(_vod('1', started), _stream()), isFalse);
    });
  });

  group('latestBroadcastIfOffline', () {
    void videos(List<Vod> items) => when(
      () => vods.getChannelVideos(login: 'streamer', type: VodType.archive),
    ).thenAnswer((_) async => VodPage(items: items, hasMore: false));

    test('an offline channel gives its newest past broadcast', () async {
      when(
        () => api.getStream(userLogin: 'streamer'),
      ).thenThrow(ApiException('offline', 404));
      videos([
        _vod('old', DateTime.utc(2026, 11, 2)),
        _vod('new', DateTime.utc(2026, 11, 7)),
      ]);
      expect((await lookup.latestBroadcastIfOffline('streamer'))?.id, 'new');
    });

    test('a lookup that hangs gives up quickly', () async {
      when(
        () => api.getStream(userLogin: 'streamer'),
      ).thenAnswer((_) => Completer<StreamTwitch>().future);
      expect(
        await lookup.latestBroadcastIfOffline(
          'streamer',
          within: const Duration(milliseconds: 10),
        ),
        isNull,
      );
    });

    test('a live channel, or an unknown state, gives nothing', () async {
      videos([_vod('new', DateTime.utc(2026, 11, 7))]);
      when(
        () => api.getStream(userLogin: 'streamer'),
      ).thenAnswer((_) async => _stream());
      expect(await lookup.latestBroadcastIfOffline('streamer'), isNull);
      when(
        () => api.getStream(userLogin: 'streamer'),
      ).thenThrow(ApiException('down', 500));
      expect(await lookup.latestBroadcastIfOffline('streamer'), isNull);
      verifyNever(
        () => vods.getChannelVideos(
          login: any(named: 'login'),
          type: any(named: 'type'),
        ),
      );
    });

    test('no past broadcast, or a failed lookup, gives nothing', () async {
      when(
        () => api.getStream(userLogin: 'streamer'),
      ).thenThrow(ApiException('offline', 404));
      videos([]);
      expect(await lookup.latestBroadcastIfOffline('streamer'), isNull);
      when(
        () => vods.getChannelVideos(login: 'streamer', type: VodType.archive),
      ).thenThrow(Exception('gql changed'));
      expect(await lookup.latestBroadcastIfOffline('streamer'), isNull);
    });
  });
}
