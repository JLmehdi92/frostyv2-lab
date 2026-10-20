import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/channel/chat/chat_delay_queue.dart';

void main() {
  final t0 = DateTime(2026, 10, 20, 12);
  DateTime at(int ms) => t0.add(Duration(milliseconds: ms));
  Duration s(int seconds) => Duration(seconds: seconds);

  group('ChatDelayQueue', () {
    test('releases a payload once the delay has passed', () {
      final queue = ChatDelayQueue();
      final released = <String>[];

      queue.add(() => released.add('a'), now: t0);

      queue.flushDue(at(2999), s(3));
      expect(released, isEmpty);
      queue.flushDue(at(3000), s(3));
      expect(released, ['a']);
      expect(queue.isEmpty, isTrue);
    });

    test('keeps arrival order when the delay shrinks', () {
      // The video jumped back to the live edge: the delay drops from 8 s to
      // 2 s. A message that arrived later must never overtake an earlier one
      // (a deletion would otherwise land before the message it deletes).
      final queue = ChatDelayQueue();
      final released = <String>[];

      queue.add(() => released.add('old'), now: t0);
      queue.flushDue(at(1000), s(8));
      queue.add(() => released.add('new'), now: at(1000));

      queue.flushDue(at(2500), s(2));
      expect(released, ['old']);
      queue.flushDue(at(3000), s(2));
      expect(released, ['old', 'new']);
    });

    test('a shrinking delay releases at once what is already due', () {
      // 40 s of pause pushed the delay up; playing at the live edge brings
      // it back to 2 s: chat must not stay frozen for the old 40 s.
      final queue = ChatDelayQueue();
      final released = <String>[];

      for (var i = 0; i < 5; i++) {
        queue.add(() => released.add('m$i'), now: at(i * 1000));
      }
      queue.flushDue(at(6000), s(40));
      expect(released, isEmpty);

      queue.flushDue(at(6000), s(2));
      expect(released, ['m0', 'm1', 'm2', 'm3', 'm4']);
    });

    test('a growing delay holds what is not due yet', () {
      final queue = ChatDelayQueue();
      final released = <String>[];

      queue
        ..add(() => released.add('a'), now: t0)
        ..add(() => released.add('b'), now: at(1500));

      queue.flushDue(at(2000), s(2));
      expect(released, ['a']);
      queue.flushDue(at(3600), s(6));
      expect(released, ['a']);
      queue.flushDue(at(7500), s(6));
      expect(released, ['a', 'b']);
    });

    test('a zero or negative delay releases everything', () {
      final queue = ChatDelayQueue();
      final released = <String>[];

      queue
        ..add(() => released.add('a'), now: t0)
        ..add(() => released.add('b'), now: t0);
      queue.flushDue(t0, s(-4));

      expect(released, ['a', 'b']);
    });

    test('flushAll releases everything in order and clear drops it', () {
      final queue = ChatDelayQueue();
      final released = <String>[];

      queue
        ..add(() => released.add('a'), now: t0)
        ..add(() => released.add('b'), now: at(10));
      queue.flushAll();
      expect(released, ['a', 'b']);

      queue.add(() => released.add('c'), now: t0);
      queue.clear();
      queue.flushDue(at(10000), Duration.zero);
      expect(released, ['a', 'b']);
      expect(queue.isEmpty, isTrue);
    });

    test('a payload that enqueues another during a flush is kept', () {
      final queue = ChatDelayQueue();
      final released = <String>[];

      queue.add(() {
        released.add('a');
        queue.add(() => released.add('b'), now: t0);
      }, now: t0);
      queue.flushDue(t0, Duration.zero);
      queue.flushDue(t0, Duration.zero);

      expect(released, ['a', 'b']);
    });
  });
}
