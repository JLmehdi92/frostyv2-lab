import 'package:flutter/material.dart';
import 'package:frosty/screens/home/stream_list/stream_card_parts.dart';
import 'package:frosty/screens/home/stream_list/stream_tags.dart';

/// "Streak N" on a followed card, with its tags, like Twitch's Following
/// tab: the viewer's running streak in that channel, as Twitch counts it,
/// in the community green of the boards.
class WatchStreakTag extends StatelessWidget {
  const WatchStreakTag({super.key, required this.value});

  final int value;

  @override
  Widget build(BuildContext context) =>
      StreakPill(value: value, height: StreamTags.height);
}
