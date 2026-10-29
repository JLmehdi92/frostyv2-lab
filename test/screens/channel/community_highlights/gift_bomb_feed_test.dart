import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/screens/channel/chat/gift_bomb_tracker.dart';
import 'package:onset/screens/channel/community_highlights/gift_bomb_feed.dart';

GiftBomb _bomb(String key) => GiftBomb(
  key: key,
  gifterName: 'G',
  isAnonymous: false,
  count: 5,
  tier: 'Tier 1',
);

void main() {
  late Observable<GiftBomb?> latest;
  late List<GiftBomb> shown;
  late ReactionDisposer dispose;

  setUp(() {
    latest = Observable<GiftBomb?>(null);
    shown = [];
  });

  void feed() =>
      dispose = feedGiftBombs(latest: () => latest.value, show: shown.add);

  test('pins each new gift bomb the chat announces', () {
    feed();

    runInAction(() => latest.value = _bomb('a'));
    runInAction(() => latest.value = _bomb('b'));

    expect(shown.map((b) => b.key), ['a', 'b']);
    dispose();
  });

  test('does not pin the bomb already announced when it starts', () {
    latest.value = _bomb('old');
    feed();

    expect(shown, isEmpty);
    dispose();
  });

  test('does not pin the same bomb twice', () {
    feed();

    runInAction(() => latest.value = _bomb('a'));
    runInAction(() => latest.value = _bomb('a'));

    expect(shown, hasLength(1));
    dispose();
  });

  test('stops once disposed', () {
    feed();
    dispose();

    runInAction(() => latest.value = _bomb('a'));

    expect(shown, isEmpty);
  });
}
