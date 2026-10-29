import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/channel/video/player_controller.dart';

import '../../../helpers/fake_player.dart';

void main() {
  test('the PiP play action waits for a clear content warning', () {
    final player = FakePlayer();
    for (final gate in [ContentGate.covering, ContentGate.pending]) {
      player.setContentGate(gate);
      pipPlayPause(player);
      expect(player.calls, isNot(contains('pausePlay')), reason: gate.name);
    }

    player.setContentGate(ContentGate.clear);
    pipPlayPause(player);
    expect(player.calls, contains('pausePlay'));
  });

  test('only a clear warning lets the stream leave the screen', () {
    expect(ContentGate.clear.allowsLeaving, isTrue);
    expect(ContentGate.pending.allowsLeaving, isFalse);
    expect(ContentGate.covering.allowsLeaving, isFalse);
  });
}
