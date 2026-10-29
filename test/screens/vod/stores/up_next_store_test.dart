import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/vod.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/vod/stores/up_next_store.dart';
import 'package:onset/screens/vod/vod_resume.dart';

Vod _vod(String id, {bool restricted = false, String? gameId = '33'}) => Vod(
  id: id,
  title: 'Video $id',
  lengthSeconds: 3600,
  createdAt: DateTime.utc(2026, 10, 2),
  viewCount: 1,
  ownerId: '42',
  ownerLogin: 'streamer',
  ownerDisplayName: 'Streamer',
  gameId: gameId,
  isRestricted: restricted,
);

void main() {
  late List<Vod> channel;
  late List<Vod> similar;
  late Map<String, VodResumeEntry> saved;
  late VodAutoplay autoplay;
  late bool? metered;
  late List<Vod> played;
  late int channelLoads;
  late int similarLoads;

  setUp(() {
    channel = [_vod('1'), _vod('2'), _vod('3')];
    similar = [];
    saved = {};
    autoplay = VodAutoplay.always;
    metered = true;
    played = [];
    channelLoads = 0;
    similarLoads = 0;
  });

  var visible = true;

  UpNextStore make({Vod? current}) => UpNextStore(
    isVisible: () => visible,
    current: current ?? _vod('1'),
    channelVideos: () async {
      channelLoads++;
      return channel;
    },
    similarVideos: (gameId) async {
      similarLoads++;
      return similar;
    },
    savedPositions: () async => saved,
    autoplay: () => autoplay,
    isMetered: () async => metered,
    onPlay: played.add,
  );

  test('at the end, counts down 10 seconds then plays the next video', () {
    fakeAsync((async) {
      final store = make();
      store.onEnded();
      async.flushMicrotasks();

      expect(store.phase, UpNextPhase.countdown);
      expect(store.next?.id, '2');
      expect(store.secondsLeft, 10);

      async.elapse(const Duration(seconds: 4));
      expect(store.secondsLeft, 6);
      expect(played, isEmpty);

      async.elapse(const Duration(seconds: 6));
      expect(played.map((v) => v.id), ['2']);
      expect(store.phase, UpNextPhase.done);
      store.dispose();
    });
  });

  test('cancel stops the countdown and hides the card', () {
    fakeAsync((async) {
      final store = make();
      store.onEnded();
      async.flushMicrotasks();

      store.cancel();
      async.elapse(const Duration(seconds: 20));

      expect(played, isEmpty);
      expect(store.phase, UpNextPhase.dismissed);
      store.dispose();
    });
  });

  test('play now plays at once', () {
    fakeAsync((async) {
      final store = make();
      store.onEnded();
      async.flushMicrotasks();

      store.playNow();
      async.elapse(const Duration(seconds: 20));

      expect(played.map((v) => v.id), ['2'], reason: 'once only');
      store.dispose();
    });
  });

  test('without autoplay the card waits for the viewer', () {
    fakeAsync((async) {
      autoplay = VodAutoplay.never;
      final store = make();
      store.onEnded();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 30));

      expect(store.phase, UpNextPhase.waiting);
      expect(store.next?.id, '2');
      expect(played, isEmpty);
      store.dispose();
    });
  });

  test('Wi-Fi only counts down on Wi-Fi, waits on mobile data', () {
    fakeAsync((async) {
      autoplay = VodAutoplay.wifiOnly;
      metered = true;
      final onData = make();
      onData.onEnded();
      async.flushMicrotasks();
      expect(onData.phase, UpNextPhase.waiting);

      metered = false;
      final onWifi = make();
      onWifi.onEnded();
      async.flushMicrotasks();
      expect(onWifi.phase, UpNextPhase.countdown);
      onData.dispose();
      onWifi.dispose();
    });
  });

  test('skips watched and subscriber-only videos', () {
    fakeAsync((async) {
      channel = [_vod('1'), _vod('2', restricted: true), _vod('3'), _vod('4')];
      saved = {
        '3': const VodResumeEntry(
          positionSec: 0,
          lengthSec: 3600,
          finished: true,
        ),
      };
      final store = make();
      store.onEnded();
      async.flushMicrotasks();

      expect(store.next?.id, '4');
      store.dispose();
    });
  });

  test('nothing new on the channel: a similar video of the category', () {
    fakeAsync((async) {
      channel = [_vod('1')];
      similar = [_vod('1'), _vod('9')];
      final store = make();
      store.onEnded();
      async.flushMicrotasks();

      expect(store.next?.id, '9');
      expect(store.similar, isTrue);
      store.dispose();
    });
  });

  test('nothing at all: no card', () {
    fakeAsync((async) {
      channel = [_vod('1')];
      final store = make(current: _vod('1', gameId: null));
      store.onEnded();
      async.flushMicrotasks();

      expect(store.phase, UpNextPhase.none);
      expect(similarLoads, 0, reason: 'no category to look in');
      store.dispose();
    });
  });

  test('a failing list is no card, not an error', () {
    fakeAsync((async) {
      final store = UpNextStore(
        current: _vod('1'),
        channelVideos: () async => throw Exception('offline'),
        similarVideos: (_) async => throw Exception('offline'),
        savedPositions: () async => saved,
        autoplay: () => autoplay,
        isMetered: () async => metered,
        onPlay: played.add,
      );
      store.onEnded();
      async.flushMicrotasks();

      expect(store.phase, UpNextPhase.none);
      store.dispose();
    });
  });

  test('ending again (after a replay) reuses the list', () {
    fakeAsync((async) {
      final store = make();
      store.onEnded();
      async.flushMicrotasks();
      store.cancel();

      store.reset();
      expect(store.phase, UpNextPhase.idle);
      store.onEnded();
      async.flushMicrotasks();

      expect(store.phase, UpNextPhase.countdown);
      expect(channelLoads, 1);
      store.dispose();
    });
  });

  test('a replay during the countdown stops it', () {
    fakeAsync((async) {
      final store = make();
      store.onEnded();
      async.flushMicrotasks();

      store.reset();
      async.elapse(const Duration(seconds: 20));

      expect(played, isEmpty);
      expect(store.phase, UpNextPhase.idle);
      store.dispose();
    });
  });

  test('a reset while the list loads shows nothing', () {
    fakeAsync((async) {
      final store = make();
      store.onEnded();
      store.reset();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 20));

      expect(store.phase, UpNextPhase.idle);
      expect(played, isEmpty);
      store.dispose();
    });
  });

  test('the countdown holds while hidden (picture-in-picture)', () {
    fakeAsync((async) {
      final store = make();
      store.onEnded();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 3));

      store.hold(true);
      async.elapse(const Duration(seconds: 30));
      expect(played, isEmpty);
      expect(store.secondsLeft, 10, reason: 'starts over once visible');

      store.hold(false);
      async.elapse(const Duration(seconds: 10));
      expect(played.map((v) => v.id), ['2']);
      store.dispose();
    });
  });

  test('covered by another screen, the countdown waits and starts over', () {
    fakeAsync((async) {
      visible = true;
      final store = make();
      store.onEnded();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 3));

      visible = false;
      async.elapse(const Duration(seconds: 30));
      expect(played, isEmpty);
      expect(store.secondsLeft, 10);

      visible = true;
      async.elapse(const Duration(seconds: 10));
      expect(played.map((v) => v.id), ['2']);
      store.dispose();
    });
  });

  test('holds for different reasons add up', () {
    fakeAsync((async) {
      visible = true;
      final store = make();
      store.onEnded();
      async.flushMicrotasks();

      store.hold(true);
      store.hold(true, reason: UpNextHold.focus);
      store.hold(false);
      async.elapse(const Duration(seconds: 30));
      expect(played, isEmpty, reason: 'still without playback focus');

      store.hold(false, reason: UpNextHold.focus);
      async.elapse(const Duration(seconds: 10));
      expect(played.map((v) => v.id), ['2']);
      store.dispose();
    });
  });

  test('disposed: nothing plays', () {
    fakeAsync((async) {
      final store = make();
      store.onEnded();
      async.flushMicrotasks();
      store.dispose();
      async.elapse(const Duration(seconds: 20));

      expect(played, isEmpty);
    });
  });
}
