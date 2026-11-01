import 'package:flutter/material.dart';
import 'package:onset/apis/twitch_vod_service.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/vod/widgets/video_glyph.dart';
import 'package:onset/theme.dart';

/// What cannot play, in [VodErrorView]'s messages (each language words a
/// video and a clip its own way: « Cette vidéo », « Ce clip »).
enum PlaybackSubject { video, clip }

/// Why a VOD (or a clip) cannot play, over a black player area. Never opens
/// a browser.
class VodErrorView extends StatelessWidget {
  const VodErrorView({
    super.key,
    required this.problem,
    this.onRetry,
    this.subject = PlaybackSubject.video,
  });

  final VodPlaybackProblem problem;

  /// What is playing, in the messages.
  final PlaybackSubject subject;

  /// Offered for problems that may be temporary.
  final VoidCallback? onRetry;

  /// The message for [problem], in [l]'s language.
  static String messageFor(
    VodPlaybackProblem problem,
    AppLocalizations l, {
    PlaybackSubject subject = PlaybackSubject.video,
  }) => switch (problem) {
    VodPlaybackProblem.subscriberOnly => l.playbackSubscriberOnly(
      subject: subject.name,
    ),
    VodPlaybackProblem.geoBlocked => l.playbackGeoBlocked(
      subject: subject.name,
    ),
    VodPlaybackProblem.notFound => l.playbackNotFound(subject: subject.name),
    VodPlaybackProblem.tokenRejected ||
    VodPlaybackProblem.unknown => l.playbackFailed(subject: subject.name),
  };

  /// A second line, under the message (the official app's wording).
  static String? detailFor(VodPlaybackProblem problem, AppLocalizations l) =>
      switch (problem) {
        VodPlaybackProblem.subscriberOnly => l.playbackSubscribeDetail,
        _ => null,
      };

  /// Subscriber-only can pass too: subscribing elsewhere, or a renewed web
  /// token, opens it (the official app offers a refresh there).
  bool get _retryable =>
      problem == VodPlaybackProblem.unknown ||
      problem == VodPlaybackProblem.tokenRejected ||
      problem == VodPlaybackProblem.subscriberOnly;

  @override
  Widget build(BuildContext context) {
    const text = OnsetTokens.textPrimaryDark;
    final l = context.l10n;
    final detail = detailFor(problem, l);
    final retry = _retryable ? onRetry : null;
    // The player's own ground, as the content warning draws it:
    // a glyph in its disc, the message, the detail, "Try again".
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: OnsetTokens.raisedDark,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: VideoGlyph(
                    problem == VodPlaybackProblem.subscriberOnly
                        ? VideoGlyphKind.lock
                        : VideoGlyphKind.alert,
                    color: text,
                    size: 18,
                    strokeWidth: 2,
                  ),
                ),
              ),
              Text(
                messageFor(problem, l, subject: subject),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: OnsetTokens.bodyFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                  color: text,
                ),
              ),
              if (detail != null)
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: OnsetTokens.bodyFamily,
                    fontSize: 12.5,
                    height: 1.4,
                    color: OnsetTokens.textBodyDark,
                  ),
                ),
              if (retry != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: TextButton.icon(
                    onPressed: retry,
                    style: TextButton.styleFrom(
                      foregroundColor: text,
                      backgroundColor: OnsetTokens.raisedDark,
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: const StadiumBorder(
                        side: BorderSide(
                          color: Color(0x24FFFFFF),
                          width: OnsetTokens.hairlineWidth,
                        ),
                      ),
                      textStyle: const TextStyle(
                        fontFamily: OnsetTokens.bodyFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 17),
                    label: Text(l.commonTryAgain),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
