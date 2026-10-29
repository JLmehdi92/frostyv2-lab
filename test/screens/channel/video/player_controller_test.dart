import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/channel/video/player_controller.dart';

import '../../../helpers/fake_player.dart';

void main() {
  test('the PiP play action does nothing while the warning covers it', () {
    final player = FakePlayer()..setContentGated(true);
    pipPlayPause(player);
    expect(player.calls, isNot(contains('pausePlay')));

    player.setContentGated(false);
    pipPlayPause(player);
    expect(player.calls, contains('pausePlay'));
  });
}
