import 'package:flutter/material.dart';
import 'package:frosty/screens/home/stream_list/stream_tags.dart';
import 'package:frosty/utils/context_extensions.dart';

/// "Watch Streak N" on a followed card, like Twitch's Following tab: the
/// viewer's running streak in that channel, as Twitch counts it.
class WatchStreakTag extends StatelessWidget {
  const WatchStreakTag({super.key, required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Container(
      height: StreamTags.height,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(StreamTags.height / 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: 14,
            color: context.frostyColors.live,
          ),
          Text(
            'Watch Streak $value',
            maxLines: 1,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
