import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/models/stream.dart';
import 'package:frosty/screens/channel/stores/channel_info_store.dart';
import 'package:mocktail/mocktail.dart';

class MockTwitchApi extends Mock implements TwitchApi {}

StreamTwitch _stream(String id) => StreamTwitch(
  id,
  'user$id',
  'User$id',
  '1',
  'Game',
  'Title',
  10,
  '2026-01-01T00:00:00Z',
  '',
);

void main() {
  late MockTwitchApi api;

  setUp(() {
    api = MockTwitchApi();
    when(
      () => api.isFollowing(
        userId: any(named: 'userId'),
        broadcasterId: any(named: 'broadcasterId'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => api.getFollowedStreams(
        id: any(named: 'id'),
        first: any(named: 'first'),
      ),
    ).thenAnswer(
      (_) async =>
          StreamsTwitch([_stream('42'), _stream('1'), _stream('2')], const {}),
    );
  });

  ChannelInfoStore store({String? viewer = '7'}) =>
      ChannelInfoStore(channelId: '42', api: api, viewerId: () => viewer);

  test('asks nothing until the player has had its head start', () {
    fakeAsync((async) {
      final info = store()..start();
      async.elapse(
        ChannelInfoStore.headStart - const Duration(milliseconds: 1),
      );
      verifyNever(
        () => api.isFollowing(
          userId: any(named: 'userId'),
          broadcasterId: any(named: 'broadcasterId'),
        ),
      );
      async.elapse(const Duration(milliseconds: 1));
      async.flushMicrotasks();
      expect(info.following.value, isTrue);
      info.dispose();
    });
  });

  test('a signed-out viewer is never asked about', () {
    fakeAsync((async) {
      final info = store(viewer: null)
        ..start()
        ..wantAlsoLive();
      async.elapse(ChannelInfoStore.headStart);
      async.flushMicrotasks();
      expect(info.following.value, isNull);
      expect(info.alsoLive.value, isEmpty);
      verifyZeroInteractions(api);
      info.dispose();
    });
  });

  test('the other live channels leave this one out, only when wanted', () {
    fakeAsync((async) {
      final info = store()..start();
      async.elapse(ChannelInfoStore.headStart);
      async.flushMicrotasks();
      verifyNever(
        () => api.getFollowedStreams(
          id: any(named: 'id'),
          first: any(named: 'first'),
        ),
      );

      info.wantAlsoLive();
      async.flushMicrotasks();
      expect(info.alsoLive.value.map((s) => s.userId), ['1', '2']);

      // Asked once.
      info.wantAlsoLive();
      async.flushMicrotasks();
      verify(
        () => api.getFollowedStreams(
          id: '7',
          first: any(named: 'first'),
        ),
      ).called(1);
      info.dispose();
    });
  });

  test('a failure leaves the defaults, and nothing lands after dispose', () {
    fakeAsync((async) {
      when(
        () => api.isFollowing(
          userId: any(named: 'userId'),
          broadcasterId: any(named: 'broadcasterId'),
        ),
      ).thenThrow(Exception('offline'));
      final failing = store()..start();
      async.elapse(ChannelInfoStore.headStart);
      async.flushMicrotasks();
      expect(failing.following.value, isNull);
      failing.dispose();
      clearInteractions(api);

      when(
        () => api.isFollowing(
          userId: any(named: 'userId'),
          broadcasterId: any(named: 'broadcasterId'),
        ),
      ).thenAnswer((_) async => true);
      final closed = store()..start();
      closed.dispose();
      async.elapse(ChannelInfoStore.headStart);
      async.flushMicrotasks();
      verifyNever(
        () => api.isFollowing(
          userId: any(named: 'userId'),
          broadcasterId: any(named: 'broadcasterId'),
        ),
      );
    });
  });

  test('refreshFollowing reads it again', () {
    fakeAsync((async) {
      final info = store()..start();
      async.elapse(ChannelInfoStore.headStart);
      async.flushMicrotasks();
      when(
        () => api.isFollowing(
          userId: any(named: 'userId'),
          broadcasterId: any(named: 'broadcasterId'),
        ),
      ).thenAnswer((_) async => false);
      info.refreshFollowing();
      async.flushMicrotasks();
      expect(info.following.value, isFalse);
      info.dispose();
    });
  });
}
