import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/hype_train.dart';
import 'package:frosty/models/hype_train_event.dart';
import 'package:frosty/screens/channel/hype_train/hype_train_queue.dart';

import 'hype_train_test_data.dart';

HtProgressionEvent small(int total, {int level = 1}) => HtProgressionEvent(
  id: 'p$total',
  sequenceId: total,
  action: const HtAction('CHEER'),
  source: HtSource.bits,
  quantity: 1,
  isLarge: false,
  progress: progress(level: level, total: total),
);

HtProgressionEvent large(int total) => HtProgressionEvent(
  id: 'large$total',
  sequenceId: total,
  action: const HtAction('TIER_1_GIFTED_SUB'),
  source: HtSource.subs,
  quantity: 50,
  isLarge: true,
  progress: progress(total: total),
);

HtConductorEvent conductorFor(HtSource source, String id) =>
    HtConductorEvent(HtConductor(source: source, user: user(id)));

void main() {
  late HtEventQueue queue;

  setUp(() => queue = HtEventQueue());

  test('first in, first out', () {
    final a = small(1);
    final b = small(2);
    queue
      ..enqueue(a)
      ..enqueue(b);

    expect(queue.length, 2);
    expect(queue.pop(), same(a));
    expect(queue.pop(), same(b));
    expect(queue.pop(), isNull);
  });

  test('a burst of small progressions keeps only the newest', () {
    for (var i = 1; i <= 5; i++) {
      queue.enqueue(small(i));
    }
    final big = large(6);
    queue
      ..enqueue(big)
      ..enqueue(small(7))
      ..enqueue(small(8));

    final drained = queue.drainForEnd();
    expect(drained, hasLength(7));
    expect(drained[5], same(big));
    expect((drained.last as HtProgressionEvent).sequenceId, 8);
  });

  test('a conductor update replaces the queued one in place', () {
    final first = conductorFor(HtSource.bits, 'a');
    final subs = conductorFor(HtSource.subs, 'b');
    final newer = conductorFor(HtSource.bits, 'c');
    queue
      ..enqueue(first)
      ..enqueue(subs)
      ..enqueue(newer);

    expect(queue.drainForEnd(), [newer, subs]);
  });

  test('drainForEnd returns everything in order and empties', () {
    final events = [small(1), conductorFor(HtSource.bits, 'a'), small(2)];
    events.forEach(queue.enqueue);

    expect(queue.drainForEnd(), events);
    expect(queue.length, 0);
  });

  test('the queue is capped at 100, dropping the oldest', () {
    for (var i = 0; i < 120; i++) {
      queue.enqueue(large(i));
    }

    expect(queue.length, HtEventQueue.maxLength);
    expect((queue.pop()! as HtProgressionEvent).sequenceId, 20);
  });

  test('a level-up already announced by a merge becomes plain progress', () {
    queue.enqueue(
      HtMergeEvent(
        train: HypeTrainExecution(
          id: 'm',
          progress: progress(level: 9, total: 30000),
        ),
      ),
    );
    final expires = DateTime.utc(2026, 10, 13, 16);
    queue
      ..enqueue(
        HtLevelUpEvent(
          timeToExpire: expires,
          progress: progress(level: 9, total: 30100),
        ),
      )
      ..enqueue(
        HtLevelUpEvent(
          timeToExpire: expires,
          progress: progress(level: 10, total: 40000),
        ),
      );

    final drained = queue.drainForEnd();
    final plain = drained[1] as HtProgressionEvent;
    expect(plain.progress.total, 30100);
    expect(plain.expiresAt, expires);
    expect(plain.isLarge, isFalse);
    expect(drained[2], isA<HtLevelUpEvent>());
  });

  test('clear empties the queue', () {
    queue
      ..enqueue(small(1))
      ..clear();

    expect(queue.length, 0);
  });
}
