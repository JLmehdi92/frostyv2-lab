import 'package:mobx/mobx.dart';
import 'package:onset/models/celebration.dart';

/// The compact chat line a celebration becomes when "Celebrations on video"
/// is Subtle: what played, never over the video.
String celebrationChatLine(Celebration celebration) {
  final effect = switch (celebration.effect) {
    CelebrationEffect.fireworks => 'Fireworks',
    CelebrationEffect.rain => 'Rain',
    CelebrationEffect.float => 'Float',
    CelebrationEffect.flamethrower => 'Flamethrower',
    CelebrationEffect.extinctionEvent => 'Extinction event',
    CelebrationEffect.unknown => 'Sparkles',
  };
  return celebration.isAutomatic
      ? 'Gifted subs celebration: $effect'
      : 'Celebration: $effect';
}

/// While [subtle] says so, every celebration [latest] brings becomes a line
/// in chat ([post]) and is cleared at once ([clear]), so nothing plays over
/// the video. Otherwise the overlay plays it, as before.
///
/// Only a new celebration triggers this: switching the setting mid-way does
/// not repeat one that already played.
ReactionDisposer feedSubtleCelebrations({
  required Celebration? Function() latest,
  required bool Function() subtle,
  required void Function(String line) post,
  required void Function() clear,
}) => reaction<Celebration?>((_) => latest(), (celebration) {
  if (celebration == null || !subtle()) return;
  post(celebrationChatLine(celebration));
  clear();
});
