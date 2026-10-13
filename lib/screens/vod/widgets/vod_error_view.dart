import 'package:flutter/material.dart';
import 'package:frosty/apis/twitch_vod_service.dart';
import 'package:frosty/widgets/alert_message.dart';

/// Why a VOD cannot play, over a black player area. Never opens a browser.
class VodErrorView extends StatelessWidget {
  const VodErrorView({super.key, required this.problem, this.onRetry});

  final VodPlaybackProblem problem;

  /// Offered for problems that may be temporary.
  final VoidCallback? onRetry;

  static String messageFor(VodPlaybackProblem problem) => switch (problem) {
    VodPlaybackProblem.subscriberOnly => 'This video is for subscribers only',
    VodPlaybackProblem.geoBlocked =>
      'This video is not available in your region',
    VodPlaybackProblem.notFound => 'This video is no longer available',
    VodPlaybackProblem.tokenRejected ||
    VodPlaybackProblem.unknown => "Couldn't play this video",
  };

  bool get _retryable =>
      problem == VodPlaybackProblem.unknown ||
      problem == VodPlaybackProblem.tokenRejected;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AlertMessage(
          message: messageFor(problem),
          color: Colors.white,
          trailingIcon: _retryable && onRetry != null
              ? Icons.refresh_rounded
              : null,
          onTrailingIconPressed: _retryable ? onRetry : null,
        ),
      ),
    ),
  );
}
