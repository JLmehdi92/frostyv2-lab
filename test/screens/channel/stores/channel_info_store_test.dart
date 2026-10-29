import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/screens/channel/stores/channel_info_store.dart';

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
        quiet: any(named: 'quiet'),
      ),
    ).thenAnswer(
      (_) async =>
          StreamsTwitch([_stream('42'), _stream('1'), _stream('2')], const {}),
    );
  });

  ChannelInfoStore store({String? viewer = '7'}) =>
      ChannelInfoStore(channelId: '42', api: api, viewerId: () => viewer);

  test('a screen without a player asks at once (the channel profile)', () {
    fakeAsync((async) {
      final info = ChannelInfoStore(
        channelId: '42',
        api: api,
        viewerId: () => '7',
        startDelay: Duration.zero,
      )..start();
      async.flushTimers();
      verify(() => api.isFollowing(userId: '7', broadcasterId: '42')).called(1);
      expect(info.following.value, isTrue);
      info.dispose();
    });
  });

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
          quiet: any(named: 'quiet'),
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
          quiet: any(named: 'quiet'),
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

  test('a viewer known late is asked about then; signing out forgets', () {
    fakeAsync((async) {
      String? viewer;
      final info =
          ChannelInfoStore(channelId: '42', api: api, viewerId: () => viewer)
            ..start()
            ..wantAlsoLive();
      async.elapse(ChannelInfoStore.headStart);
      async.flushMicrotasks();
      expect(info.following.value, isNull);
      expect(info.alsoLive.value, isEmpty);

      viewer = '7';
      info.viewerChanged();
      async.flushMicrotasks();
      expect(info.following.value, isTrue);
      expect(info.alsoLive.value, isNotEmpty);

      viewer = null;
      info.viewerChanged();
      async.flushMicrotasks();
      expect(info.following.value, isNull);
      expect(info.alsoLive.value, isEmpty);
      info.dispose();
    });
  });

  test('a viewer change before the head start waits for it', () {
    fakeAsync((async) {
      final info = store()..start();
      info.viewerChanged();
      async.flushMicrotasks();
      verifyNever(
        () => api.isFollowing(
          userId: any(named: 'userId'),
          broadcasterId: any(named: 'broadcasterId'),
        ),
      );
      async.elapse(ChannelInfoStore.headStart);
      async.flushMicrotasks();
      expect(info.following.value, isTrue);
      info.dispose();
    });
  });

  test('an answer for the previous account is dropped', () {
    fakeAsync((async) {
      String? viewer = '7';
      final follow = Completer<bool>();
      final streams = Completer<StreamsTwitch>();
      when(
        () => api.isFollowing(
          userId: any(named: 'userId'),
          broadcasterId: any(named: 'broadcasterId'),
        ),
      ).thenAnswer((_) => follow.future);
      when(
        () => api.getFollowedStreams(
          id: any(named: 'id'),
          first: any(named: 'first'),
          quiet: any(named: 'quiet'),
        ),
      ).thenAnswer((_) => streams.future);
      final info =
          ChannelInfoStore(channelId: '42', api: api, viewerId: () => viewer)
            ..start()
            ..wantAlsoLive();
      async.elapse(ChannelInfoStore.headStart);

      // Signed out while Twitch answers for the previous account.
      viewer = null;
      info.viewerChanged();
      follow.complete(true);
      streams.complete(StreamsTwitch([_stream('1')], const {}));
      async.flushMicrotasks();
      expect(info.following.value, isNull);
      expect(info.alsoLive.value, isEmpty);
      info.dispose();
    });
  });

  test('a failed "also live" is asked again, quietly', () {
    fakeAsync((async) {
      var fail = true;
      when(
        () => api.getFollowedStreams(
          id: any(named: 'id'),
          first: any(named: 'first'),
          quiet: any(named: 'quiet'),
        ),
      ).thenAnswer((_) async {
        if (fail) throw Exception('offline');
        return StreamsTwitch([_stream('1')], const {});
      });
      final info = store()
        ..start()
        ..wantAlsoLive();
      async.elapse(ChannelInfoStore.headStart);
      async.flushMicrotasks();
      expect(info.alsoLive.value, isEmpty);

      fail = false;
      info.refresh();
      async.flushMicrotasks();
      expect(info.alsoLive.value.map((s) => s.userId), ['1']);
      // Never a "Session expired" prompt for it.
      verify(
        () => api.getFollowedStreams(
          id: '7',
          first: any(named: 'first'),
          quiet: true,
        ),
      ).called(2);
      info.dispose();
    });
  });
}
