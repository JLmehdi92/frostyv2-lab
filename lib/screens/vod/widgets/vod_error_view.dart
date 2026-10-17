import 'package:flutter/material.dart';
import 'package:frosty/apis/twitch_vod_service.dart';
import 'package:frosty/widgets/alert_message.dart';

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
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AlertMessage(
              message: messageFor(problem, subject: subject),
              color: Colors.white,
              trailingIcon: _retryable && onRetry != null
                  ? Icons.refresh_rounded
                  : null,
              onTrailingIconPressed: _retryable ? onRetry : null,
            ),
            if (detailFor(problem) case final detail?)
              Text(
                detail,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
          ],
        ),
      ),
    ),
  );
}
