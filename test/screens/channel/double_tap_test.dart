import 'package:fake_async/fake_async.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/channel/double_tap.dart';

void main() {
  late List<String> calls;
  late VideoTaps taps;

  setUp(() {
    calls = [];
    taps = VideoTaps(
      onSingle: () => calls.add('single'),
      onDouble: () => calls.add('double'),
    );
  });

  test('a single tap answers once the double tap window is over', () {
    fakeAsync((async) {
      taps.tap(const Offset(100, 100));
      async.elapse(kDoubleTapTimeout - const Duration(milliseconds: 1));
      expect(calls, isEmpty);
      async.elapse(const Duration(milliseconds: 1));
      expect(calls, ['single']);
    });
  });

  test('a second tap soon and close is a double tap, never a single', () {
    fakeAsync((async) {
      taps.tap(const Offset(100, 100));
      async.elapse(const Duration(milliseconds: 100));
      taps.tap(const Offset(130, 120));
      async.elapse(const Duration(seconds: 1));
      expect(calls, ['double']);
    });
  });

  test('a third tap starts over', () {
    fakeAsync((async) {
      taps
        ..tap(const Offset(100, 100))
        ..tap(const Offset(100, 100))
        ..tap(const Offset(100, 100));
      async.elapse(const Duration(seconds: 1));
      expect(calls, ['double', 'single']);
    });
  });

  test('a second tap too late is a new first tap', () {
    fakeAsync((async) {
      taps.tap(const Offset(100, 100));
      async.elapse(kDoubleTapTimeout);
      taps.tap(const Offset(100, 100));
      async.elapse(const Duration(seconds: 1));
      expect(calls, ['single', 'single']);
    });
  });

  test('a second tap too far flushes the first, then waits', () {
    fakeAsync((async) {
      taps.tap(const Offset(100, 100));
      taps.tap(const Offset(100 + kDoubleTapSlop + 1, 100));
      expect(calls, ['single']);
      async.elapse(const Duration(seconds: 1));
      expect(calls, ['single', 'single']);
    });
  });

  test('cancel drops a pending tap and forgets it', () {
    fakeAsync((async) {
      taps
        ..tap(const Offset(100, 100))
        ..cancel()
        ..tap(const Offset(100, 100));
      async.elapse(const Duration(seconds: 1));
      expect(calls, ['single']);
    });
  });
}
