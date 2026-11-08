import 'package:onset/models/vod.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/vod/vod_resume.dart';

/// Whether the viewer has seen enough of [vod] for Up Next to skip it, with
/// this rule: to the end of a video
/// under 5 minutes, 5 minutes of one up to 50 minutes, a tenth of a longer
/// one. [saved] is where this device last left it.
bool isVodWatched(Vod vod, VodResumeEntry? saved) {
  if (saved == null) return false;
  if (saved.finished) return true;
  final length = vod.lengthSeconds > 0 ? vod.lengthSeconds : saved.lengthSec;
  final position = saved.positionSec;
  if (length < 300) return position >= length;
  if (length <= 3000) return position >= 300;
  return position >= length * 0.1;
}

/// The video to offer after [current], like the official app: the first of
/// [candidates] (the channel's videos, newest first) that is another video,
/// not restricted to subscribers and not already watched ([saved] by id).
Vod? pickUpNext({
  required Vod current,
  required List<Vod> candidates,
  required Map<String, VodResumeEntry> saved,
}) {
  for (final vod in candidates) {
    if (vod.id == current.id || vod.isRestricted) continue;
    if (isVodWatched(vod, saved[vod.id])) continue;
    return vod;
  }
  return null;
}

/// Whether the next video may start by itself under [setting], on a
/// network that is [metered] (null when unknown: then it may be mobile
/// data, so Wi-Fi only waits for the viewer).
bool autoplayAllowed(VodAutoplay setting, {required bool? metered}) =>
    switch (setting) {
      VodAutoplay.always => true,
      VodAutoplay.wifiOnly => metered == false,
      VodAutoplay.never => false,
    };

List<Vod>? collectionQueueAfter(String currentId, List<Vod> collection) {
  final index = collection.indexWhere((vod) => vod.id == currentId);
  if (index < 0) return null;
  return collection.sublist(index + 1);
}
