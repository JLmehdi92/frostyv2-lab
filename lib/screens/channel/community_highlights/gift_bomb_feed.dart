import 'package:frosty/screens/channel/chat/gift_bomb_tracker.dart';
import 'package:mobx/mobx.dart';

/// Pins each gift bomb a chat announces from now on: every time [latest]
/// changes to a bomb, [show] gets it.
///
/// [latest] reads the chat's latest banner-worthy bomb, which the chat sets
/// after its chat delay, so the banner shows in step with the video. A bomb
/// announced before this starts is not pinned late.
ReactionDisposer feedGiftBombs({
  required GiftBomb? Function() latest,
  required void Function(GiftBomb bomb) show,
}) => reaction<GiftBomb?>((_) => latest(), (bomb) {
  if (bomb != null) show(bomb);
});
