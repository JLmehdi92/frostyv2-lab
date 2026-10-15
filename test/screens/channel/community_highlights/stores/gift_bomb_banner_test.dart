import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/community_highlight_event.dart';
import 'package:frosty/screens/channel/chat/gift_bomb_tracker.dart';
import 'package:frosty/screens/channel/community_highlights/highlight_stack.dart';

import '../../../../helpers/community_highlights_harness.dart';

GiftBomb _bomb({String key = 'bomb', int count = 5}) => GiftBomb(
  key: key,
  gifterName: 'BigGifter',
  isAnonymous: false,
  count: count,
  tier: 'Tier 1',
);

void main() {
  late Harness h;

  setUp(() => h = Harness());

  void run(void Function(FakeAsync async) body) =>
      fakeAsync(body, initialTime: harnessNow);

  test('pins the banner at once, for 10 s from five gifts', () {
    run((async) {
      h.create();
      async.flushMicrotasks();

      h.store.showGiftBomb(_bomb());
      expect(h.store.current!.kind, HighlightKind.giftBomb);
      final banner = h.store.giftBomb!;
      expect(banner.bomb, _bomb());
      expect(banner.startedAt, harnessNow);
      expect(banner.endsAt, harnessNow.add(const Duration(seconds: 10)));

      async.elapse(const Duration(milliseconds: 9900));
      expect(h.store.giftBomb, isNotNull);

      async.elapse(const Duration(milliseconds: 200));
      expect(h.store.giftBomb, isNull);
      expect(h.store.visible, isFalse);
      h.store.dispose();
    });
  });

  test('a hundred gifts stay up for 30 s', () {
    run((async) {
      h.create();
      async.flushMicrotasks();

      h.store.showGiftBomb(_bomb(count: 100));
      async.elapse(const Duration(seconds: 29));
      expect(h.store.giftBomb, isNotNull);
      async.elapse(const Duration(seconds: 2));
      expect(h.store.giftBomb, isNull);
      h.store.dispose();
    });
  });

  test('fewer than five gifts get no banner', () {
    run((async) {
      h.create();
      async.flushMicrotasks();

      h.store.showGiftBomb(_bomb(count: 4));
      expect(h.store.giftBomb, isNull);
      expect(h.store.visible, isFalse);
      h.store.dispose();
    });
  });

  test('a new bomb replaces the one up', () {
    run((async) {
      h.create();
      async.flushMicrotasks();

      h.store.showGiftBomb(_bomb(key: 'a'));
      async.elapse(const Duration(seconds: 5));
      h.store.showGiftBomb(_bomb(key: 'b', count: 25));

      expect(h.store.stack.items, hasLength(1));
      expect(h.store.giftBomb!.bomb.key, 'b');
      // Its own 15 s, from now.
      async.elapse(const Duration(seconds: 14));
      expect(h.store.giftBomb, isNotNull);
      async.elapse(const Duration(seconds: 2));
      expect(h.store.giftBomb, isNull);
      h.store.dispose();
    });
  });

  test('a dismissed banner stays dismissed', () {
    run((async) {
      h.create();
      async.flushMicrotasks();

      h.store.showGiftBomb(_bomb());
      h.store.dismissCurrent();
      expect(h.store.visible, isFalse);

      // Another highlight commits the store again.
      h.send(HighlightTopic.polls, pollPayload('POLL_CREATE'));
      async.flushMicrotasks();
      expect(
        h.store.stack.items.map((i) => i.kind),
        isNot(contains(HighlightKind.giftBomb)),
      );
      h.store.dispose();
    });
  });

  test('a banner never arrives expanded', () {
    run((async) {
      h.create(expandNew: true);
      async.flushMicrotasks();

      h.store.showGiftBomb(_bomb());
      expect(h.store.current!.expanded, isFalse);
      h.store.dispose();
    });
  });
}
