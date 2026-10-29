import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:onset/models/vod.dart';
import 'package:onset/screens/channel/video/live_progress.dart';
import 'package:onset/screens/vod/vod_resume.dart';

/// How far a video got: the bar along its thumbnail, and whether it was
/// watched to the end.
typedef VodProgress = ({double? progress, bool watched});

/// What the viewer has watched of a channel's videos, read once: the saved
/// positions of the videos they opened, and where they left the live
/// broadcasts (a past broadcast not opened yet shows that progress).
class VodWatchProgress {
  const VodWatchProgress({this.resume = const {}, this.live = const {}});

  static const none = VodWatchProgress();

  /// Saved positions, by video id.
  final Map<String, VodResumeEntry> resume;

  /// Where live broadcasts were left, by stream id.
  final Map<String, LiveProgressEntry> live;

  /// The [viewer]'s own positions (null: signed out).
  static Future<VodWatchProgress> load({String? viewer}) async {
    final (resume, live) = await (
      VodResumeRepository.shared.snapshot(viewer: viewer),
      LiveProgressRepository.shared.snapshot(viewer: viewer),
    ).wait;
    return VodWatchProgress(resume: resume, live: live);
  }

  /// [vod]'s bar and watched state.
  VodProgress of(Vod vod) {
    final saved = resume[vod.id];
    if (saved == null) return (progress: _liveProgress(vod), watched: false);
    return (
      progress: saved.finished ? null : saved.progress,
      watched: saved.finished,
    );
  }

  /// How far the viewer got in [vod] live, as a fraction of its length.
  double? _liveProgress(Vod vod) {
    final broadcastId = vod.broadcastId;
    if (vod.type != VodType.archive ||
        broadcastId == null ||
        vod.lengthSeconds <= 0) {
      return null;
    }
    final entry = live[broadcastId];
    if (entry == null) return null;
    return (entry.offsetSec / vod.lengthSeconds).clamp(0.0, 1.0);
  }
}

/// Keeps [watchProgress] for a list of videos: read when the list shows and
/// again when a save lands (the closing save of a player screen finishes
/// after its route has popped).
mixin VodWatchProgressMixin<T extends StatefulWidget> on State<T> {
  VodWatchProgress watchProgress = VodWatchProgress.none;

  /// Whose positions are read (null: signed out).
  String? get watchProgressViewer;

  @override
  void initState() {
    super.initState();
    unawaited(_loadWatchProgress());
    VodResumeRepository.changes.addListener(_onWatchProgressSaved);
  }

  void _onWatchProgressSaved() => unawaited(_loadWatchProgress());

  Future<void> _loadWatchProgress() async {
    final progress = await VodWatchProgress.load(viewer: watchProgressViewer);
    if (mounted) setState(() => watchProgress = progress);
  }

  @override
  void dispose() {
    VodResumeRepository.changes.removeListener(_onWatchProgressSaved);
    super.dispose();
  }
}
