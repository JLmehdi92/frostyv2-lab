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

  test('a single tap answers at once, and only once', () {
    fakeAsync((async) {
      taps.tap(const Offset(100, 100));
      expect(calls, ['single']);
      async.elapse(const Duration(seconds: 1));
      expect(calls, ['single']);
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('a second tap soon and close is a double tap, the first stands', () {
    fakeAsync((async) {
      taps.tap(const Offset(100, 100));
      async.elapse(const Duration(milliseconds: 100));
      taps.tap(const Offset(130, 120));
      expect(calls, ['single', 'double']);
      async.elapse(const Duration(seconds: 1));
      expect(calls, ['single', 'double']);
    });
  });

  test('a second tap just inside the window is still a double tap', () {
    fakeAsync((async) {
      taps.tap(const Offset(100, 100));
      async.elapse(kDoubleTapTimeout - const Duration(milliseconds: 1));
      taps.tap(const Offset(100, 100));
      expect(calls, ['single', 'double']);
    });
  });

  test('a third tap starts over as a new first tap', () {
    fakeAsync((async) {
      taps
        ..tap(const Offset(100, 100))
        ..tap(const Offset(100, 100))
        ..tap(const Offset(100, 100));
      expect(calls, ['single', 'double', 'single']);
      taps.tap(const Offset(100, 100));
      expect(calls, ['single', 'double', 'single', 'double']);
    });
  });

  test('a second tap too late is a new first tap', () {
    fakeAsync((async) {
      taps.tap(const Offset(100, 100));
      async.elapse(kDoubleTapTimeout);
      taps.tap(const Offset(100, 100));
      expect(calls, ['single', 'single']);
    });
  });

  test('a second tap too far is a new first tap', () {
    fakeAsync((async) {
      taps.tap(const Offset(100, 100));
      taps.tap(const Offset(100 + kDoubleTapSlop + 1, 100));
      expect(calls, ['single', 'single']);
      taps.tap(const Offset(100 + kDoubleTapSlop + 1, 100));
      expect(calls, ['single', 'single', 'double']);
    });
  });

  test('cancel forgets a pending first tap', () {
    fakeAsync((async) {
      taps
        ..tap(const Offset(100, 100))
        ..cancel()
        ..tap(const Offset(100, 100));
      expect(calls, ['single', 'single']);
      expect(async.pendingTimers, hasLength(1));
      taps.cancel();
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('the window is open only between a first tap and its end', () {
    fakeAsync((async) {
      expect(taps.open.value, isFalse);
      taps.tap(const Offset(100, 100));
      expect(taps.open.value, isTrue);
      async.elapse(kDoubleTapTimeout);
      expect(taps.open.value, isFalse);
      taps
        ..tap(const Offset(100, 100))
        ..tap(const Offset(100, 100));
      expect(taps.open.value, isFalse);
    });
  });
}
