import 'package:mobx/mobx.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/celebration.dart';

/// The compact chat line a celebration becomes when "Celebrations on video"
/// is Subtle, in [l]'s language: what played, never over the video.
String celebrationChatLine(Celebration celebration, AppLocalizations l) {
  // Its name selects the effect's name; unknown falls to the other branch.
  final effect = l.celebrationEffect(effect: celebration.effect.name);
  return celebration.isAutomatic
      ? l.celebrationChatLineGiftedSubs(effect: effect)
      : l.celebrationChatLine(effect: effect);
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
  // A line put in the chat's buffer: no widget to ask the language of.
  post(celebrationChatLine(celebration, L10n.current));
  clear();
});
