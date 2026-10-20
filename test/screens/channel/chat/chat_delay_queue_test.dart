import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/channel/chat/chat_delay_queue.dart';

void main() {
  final t0 = DateTime(2026, 10, 20, 12);
  DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

  group('ChatDelayQueue', () {
    test('releases a payload once its delay has passed', () {
      final queue = ChatDelayQueue();
      final released = <String>[];

      queue.add(
        () => released.add('a'),
        now: t0,
        delay: const Duration(seconds: 3),
      );

      queue.flushDue(at(2999));
      expect(released, isEmpty);
      queue.flushDue(at(3000));
      expect(released, ['a']);
      expect(queue.isEmpty, isTrue);
    });

    test('keeps arrival order when the delay shrinks', () {
      // The video jumped back to the live edge: the delay drops from 8 s to
      // 2 s. A message that arrived later must never overtake an earlier one
      // (a deletion would otherwise land before the message it deletes).
      final queue = ChatDelayQueue();
      final released = <String>[];

      queue.add(
        () => released.add('old'),
        now: t0,
        delay: const Duration(seconds: 8),
      );
      queue.add(
        () => released.add('new'),
        now: at(1000),
        delay: const Duration(seconds: 2),
      );

      queue.flushDue(at(3000));
      expect(released, isEmpty, reason: 'new waits for old');
      queue.flushDue(at(8000));
      expect(released, ['old', 'new']);
    });

    test('a longer delay only holds the later payloads', () {
      final queue = ChatDelayQueue();
      final released = <String>[];

      queue.add(
        () => released.add('a'),
        now: t0,
        delay: const Duration(seconds: 2),
      );
      queue.add(
        () => released.add('b'),
        now: at(500),
        delay: const Duration(seconds: 6),
      );

      queue.flushDue(at(2000));
      expect(released, ['a']);
      queue.flushDue(at(6499));
      expect(released, ['a']);
      queue.flushDue(at(6500));
      expect(released, ['a', 'b']);
    });

    test('a negative delay releases at once', () {
      final queue = ChatDelayQueue();
      final released = <String>[];

      queue.add(
        () => released.add('a'),
        now: t0,
        delay: const Duration(seconds: -4),
      );
      queue.flushDue(t0);

      expect(released, ['a']);
    });

    test('flushAll releases everything in order and clear drops it', () {
      final queue = ChatDelayQueue();
      final released = <String>[];

      queue
        ..add(
          () => released.add('a'),
          now: t0,
          delay: const Duration(seconds: 5),
        )
        ..add(
          () => released.add('b'),
          now: t0,
          delay: const Duration(seconds: 1),
        );
      queue.flushAll();
      expect(released, ['a', 'b']);

      queue.add(() => released.add('c'), now: t0, delay: Duration.zero);
      queue.clear();
      queue.flushDue(at(10000));
      expect(released, ['a', 'b']);
      expect(queue.isEmpty, isTrue);
    });

    test('a payload that enqueues another during a flush is kept', () {
      final queue = ChatDelayQueue();
      final released = <String>[];

      queue.add(
        () {
          released.add('a');
          queue.add(() => released.add('b'), now: t0, delay: Duration.zero);
        },
        now: t0,
        delay: Duration.zero,
      );
      queue.flushDue(t0);
      queue.flushDue(t0);

      expect(released, ['a', 'b']);
    });
  });
}
