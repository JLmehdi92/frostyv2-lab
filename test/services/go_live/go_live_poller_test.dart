import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/services/go_live/go_live_poller.dart';

void main() {
  late int checks;
  late bool playing;
  late GoLivePoller poller;

  setUp(() {
    checks = 0;
    playing = false;
    poller = GoLivePoller(
      check: () async => checks++,
      playingInBackground: () => playing,
    );
  });

  tearDown(() => poller.dispose());

  test('checks at once, then every interval while in front', () {
    fakeAsync((async) {
      poller.start();
      async.flushMicrotasks();
      expect(checks, 1);
      async.elapse(kGoLiveAppInterval * 3);
      expect(checks, 4);
    });
  });

  test('keeps checking in picture-in-picture (inactive)', () {
    fakeAsync((async) {
      poller.start();
      poller.onLifecycle(AppLifecycleState.inactive);
      async.elapse(kGoLiveAppInterval * 2);
      expect(checks, 3);
    });
  });

  test('stops in the background unless a stream plays there', () {
    fakeAsync((async) {
      poller.start();
      async.flushMicrotasks();
      poller.onLifecycle(AppLifecycleState.hidden);
      poller.onLifecycle(AppLifecycleState.paused);
      async.elapse(kGoLiveAppInterval * 3);
      expect(checks, 1);
      expect(poller.running, isFalse);

      // Back in front: checks again at once, then on schedule.
      poller.onLifecycle(AppLifecycleState.resumed);
      async.flushMicrotasks();
      expect(checks, 2);
      async.elapse(kGoLiveAppInterval);
      expect(checks, 3);
    });
  });

  test('goes on in the background while a stream plays there', () {
    fakeAsync((async) {
      playing = true;
      poller.start();
      poller.onLifecycle(AppLifecycleState.paused);
      async.elapse(kGoLiveAppInterval * 2);
      expect(checks, 3);

      // The stream stops: the next tick stops the checks.
      playing = false;
      async.elapse(kGoLiveAppInterval * 3);
      expect(checks, 3);
      expect(poller.running, isFalse);
    });
  });

  test('a slow check is not started twice', () {
    fakeAsync((async) {
      var started = 0;
      final slow = GoLivePoller(
        check: () {
          started++;
          return Future<void>.delayed(kGoLiveAppInterval * 2.5);
        },
        playingInBackground: () => false,
      );
      slow.start();
      async.elapse(kGoLiveAppInterval * 2);
      expect(started, 1);
      async.elapse(kGoLiveAppInterval);
      expect(started, 2);
      slow.dispose();
    });
  });

  test('a failing check does not stop the next ones', () {
    fakeAsync((async) {
      var calls = 0;
      final failing = GoLivePoller(
        check: () async {
          calls++;
          throw StateError('offline');
        },
        playingInBackground: () => false,
      );
      failing.start();
      async.elapse(kGoLiveAppInterval * 2);
      expect(calls, 3);
      failing.dispose();
    });
  });

  test('stops for good once detached or disposed', () {
    fakeAsync((async) {
      poller.start();
      async.flushMicrotasks();
      poller.onLifecycle(AppLifecycleState.detached);
      async.elapse(kGoLiveAppInterval * 2);
      expect(checks, 1);
      poller.dispose();
      poller.onLifecycle(AppLifecycleState.resumed);
      async.elapse(kGoLiveAppInterval * 2);
      expect(checks, 1);
    });
  });
}
