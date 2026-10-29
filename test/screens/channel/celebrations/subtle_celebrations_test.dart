import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/models/celebration.dart';
import 'package:onset/screens/channel/celebrations/subtle_celebrations.dart';

Celebration _celebration({
  CelebrationEffect effect = CelebrationEffect.fireworks,
  String? source,
}) => Celebration(
  effect: effect,
  area: CelebrationArea.everywhere,
  intensity: CelebrationIntensity.cool,
  duration: const Duration(seconds: 2),
  source: source,
);

void main() {
  test('the chat line names the effect, and a community gift', () {
    expect(celebrationChatLine(_celebration()), 'Celebration: Fireworks');
    expect(
      celebrationChatLine(
        _celebration(
          effect: CelebrationEffect.extinctionEvent,
          source: 'system_gifting',
        ),
      ),
      'Gifted subs celebration: Extinction event',
    );
    for (final effect in CelebrationEffect.values) {
      expect(celebrationChatLine(_celebration(effect: effect)), isNotEmpty);
    }
  });

  group('feedSubtleCelebrations', () {
    late Observable<Celebration?> latest;
    late bool subtle;
    late List<String> posted;
    late int cleared;
    late ReactionDisposer dispose;

    setUp(() {
      latest = Observable<Celebration?>(null);
      subtle = true;
      posted = [];
      cleared = 0;
      dispose = feedSubtleCelebrations(
        latest: () => latest.value,
        subtle: () => subtle,
        post: posted.add,
        clear: () {
          cleared++;
          runInAction(() => latest.value = null);
        },
      );
    });

    tearDown(() => dispose());

    test('Subtle: each celebration becomes one chat line, cleared', () {
      runInAction(() => latest.value = _celebration());
      expect(posted, ['Celebration: Fireworks']);
      expect(cleared, 1);
      expect(latest.value, isNull);

      runInAction(
        () => latest.value = _celebration(effect: CelebrationEffect.rain),
      );
      expect(posted, ['Celebration: Fireworks', 'Celebration: Rain']);
      expect(cleared, 2);
    });

    test('Full: the overlay plays it, nothing in chat', () {
      subtle = false;
      runInAction(() => latest.value = _celebration());
      expect(posted, isEmpty);
      expect(cleared, 0);
      expect(latest.value, isNotNull);
    });

    test('nothing after dispose', () {
      dispose();
      runInAction(() => latest.value = _celebration());
      expect(posted, isEmpty);
    });
  });
}
