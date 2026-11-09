import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/channel/stores/follow_prompts.dart';

void main() {
  late ValueNotifier<bool?> following;
  late int callouts;
  late int offers;
  var canFollow = true;

  setUp(() {
    following = ValueNotifier<bool?>(null);
    callouts = 0;
    offers = 0;
    canFollow = true;
  });

  FollowPrompts prompts({bool offer = false}) => FollowPrompts(
    following: following,
    canFollow: () => canFollow,
    onCallout: () => callouts++,
    onOfferFollow: () => offers++,
    offerFollow: offer,
  )..start();

  test('the callout comes once, after a while, to a non-follower', () {
    fakeAsync((async) {
      final p = prompts();
      following.value = false;
      async.elapse(const Duration(minutes: 9));
      expect(callouts, 0);
      async.elapse(const Duration(minutes: 2));
      expect(callouts, 1);
      async.elapse(const Duration(hours: 1));
      expect(callouts, 1);
      p.dispose();
    });
  });

  test('no callout to a follower, an unknown state or a signed-out viewer', () {
    fakeAsync((async) {
      following.value = true;
      prompts();
      async.elapse(const Duration(minutes: 11));
      following.value = null;
      prompts();
      async.elapse(const Duration(minutes: 11));
      following.value = false;
      canFollow = false;
      prompts();
      async.elapse(const Duration(minutes: 11));
      expect(callouts, 0);
    });
  });

  test('a closed screen never calls out', () {
    fakeAsync((async) {
      following.value = false;
      prompts().dispose();
      async.elapse(const Duration(minutes: 11));
      expect(callouts, 0);
    });
  });

  test('a followChannel link offers the follow once the state is known', () {
    final p = prompts(offer: true);
    expect(offers, 0);
    following.value = false;
    expect(offers, 1);
    following.value = true;
    following.value = false;
    expect(offers, 1);
    p.dispose();
  });

  test('a followChannel link to a followed channel offers nothing', () {
    prompts(offer: true);
    following.value = true;
    expect(offers, 0);
  });

  test('without the link, nothing is offered', () {
    prompts();
    following.value = false;
    expect(offers, 0);
  });
}
