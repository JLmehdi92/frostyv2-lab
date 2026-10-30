import 'package:flutter/material.dart';
import 'package:onset/apis/twitch_vod_service.dart';
import 'package:onset/screens/vod/widgets/video_glyph.dart';
import 'package:onset/theme.dart';

/// Why a VOD (or a clip) cannot play, over a black player area. Never opens
/// a browser.
class VodErrorView extends StatelessWidget {
  const VodErrorView({
    super.key,
    required this.problem,
    this.onRetry,
    this.subject = 'video',
  });

  final VodPlaybackProblem problem;

  /// What is playing, in the messages: "video" or "clip".
  final String subject;

  /// Offered for problems that may be temporary.
  final VoidCallback? onRetry;

  static String messageFor(
    VodPlaybackProblem problem, {
    String subject = 'video',
  }) => switch (problem) {
    VodPlaybackProblem.subscriberOnly =>
      'This $subject is only available to subscribers.',
    VodPlaybackProblem.geoBlocked =>
      'This $subject is not available in your region',
    VodPlaybackProblem.notFound => 'This $subject is no longer available',
    VodPlaybackProblem.tokenRejected ||
    VodPlaybackProblem.unknown => "Couldn't play this $subject",
  };

  /// A second line, under the message (the official app's wording).
  static String? detailFor(VodPlaybackProblem problem) => switch (problem) {
    VodPlaybackProblem.subscriberOnly =>
      'Subscribe now to watch and support this channel.',
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
    final detail = detailFor(problem);
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
                messageFor(problem, subject: subject),
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
                    label: const Text('Try again'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
