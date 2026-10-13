import 'dart:async';

import 'package:flutter/material.dart';
import 'package:frosty/screens/channel/chat/chat_restrictions.dart';
import 'package:frosty/utils/context_extensions.dart';

/// The line above the chat input saying why the viewer cannot chat (a ban,
/// a timeout, the slow-mode wait), with a live countdown.
class ChatRestrictionBar extends StatefulWidget {
  const ChatRestrictionBar({
    super.key,
    required this.restriction,
    this.now = DateTime.now,
  });

  final ChatRestriction? restriction;
  final DateTime Function() now;

  @override
  State<ChatRestrictionBar> createState() => _ChatRestrictionBarState();
}

class _ChatRestrictionBarState extends State<ChatRestrictionBar> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(ChatRestrictionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    _ticker?.cancel();
    _ticker = widget.restriction?.until == null
        ? null
        : Timer.periodic(const Duration(seconds: 1), (_) {
            if (mounted) setState(() {});
          });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  static IconData _icon(ChatRestrictionKind kind) => switch (kind) {
    ChatRestrictionKind.banned => Icons.block_rounded,
    ChatRestrictionKind.timedOut => Icons.timer_off_outlined,
    ChatRestrictionKind.slowMode => Icons.hourglass_bottom_rounded,
    ChatRestrictionKind.emoteOnly => Icons.emoji_emotions_outlined,
    ChatRestrictionKind.subscribersOnly => Icons.star_outline_rounded,
    ChatRestrictionKind.followersOnly => Icons.favorite_border_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final restriction = widget.restriction;
    // Room modes read in the input's placeholder; this line is for what
    // locks the input.
    if (restriction == null || !restriction.showsBar) {
      return const SizedBox.shrink();
    }
    final until = restriction.until;
    final left = until?.difference(widget.now());
    final scheme = context.colorScheme;
    final color = scheme.error;
    return Semantics(
      liveRegion: until == null,
      container: true,
      // A fixed height: the chat list pads for it.
      child: Container(
        height: kRestrictionBarHeight,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          spacing: 6,
          children: [
            Icon(_icon(restriction.kind), size: 16, color: color),
            Expanded(
              child: Text(
                restriction.describe(left),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
