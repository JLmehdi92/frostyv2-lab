import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/channel/chat/chat_restrictions.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/link_router.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';

/// The line above the chat input saying why the viewer cannot chat (a ban,
/// a timeout, the slow-mode wait), with a live countdown.
class ChatRestrictionBar extends StatefulWidget {
  const ChatRestrictionBar({
    super.key,
    required this.restriction,
    this.now = DateTime.now,
  });

  final ChatRestriction? restriction;

  static const lineKey = ValueKey('chat-restriction-line');
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

  /// The glyph for each restriction.
  static SheetGlyphKind _glyph(ChatRestrictionKind kind) => switch (kind) {
    ChatRestrictionKind.banned => SheetGlyphKind.block,
    ChatRestrictionKind.timedOut => SheetGlyphKind.timer,
    ChatRestrictionKind.slowMode => SheetGlyphKind.hourglass,
    ChatRestrictionKind.emoteOnly => SheetGlyphKind.emote,
    ChatRestrictionKind.subscribersOnly => SheetGlyphKind.star,
    ChatRestrictionKind.followersOnly ||
    ChatRestrictionKind.followRequired => SheetGlyphKind.heart,
    ChatRestrictionKind.verifiedEmail ||
    ChatRestrictionKind.verifiedPhone => SheetGlyphKind.shield,
    ChatRestrictionKind.emailAliasBanned ||
    ChatRestrictionKind.phoneAliasBanned ||
    ChatRestrictionKind.accountRestricted ||
    ChatRestrictionKind.channelRestricted => SheetGlyphKind.block,
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
    final color = SheetColors.of(context).danger;
    final helpUrl = restriction.helpUrl;
    final bar = Semantics(
      liveRegion: until == null,
      container: true,
      button: helpUrl != null,
      // A fixed height: the chat list pads for it.
      child: Container(
        height: restriction.barHeight,
        alignment: Alignment.bottomCenter,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          key: ChatRestrictionBar.lineKey,
          height: kRestrictionBarHeight,
          child: Row(
            spacing: 7,
            children: [
              SheetGlyph(_glyph(restriction.kind), size: 16, color: color),
              Expanded(
                child: Text(
                  restriction.describe(left, context.l10n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: OnsetTokens.bodyFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (helpUrl != null)
                SheetGlyph(SheetGlyphKind.external, size: 14, color: color),
            ],
          ),
        ),
      ),
    );
    if (helpUrl == null) return bar;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => LinkRouter.open(helpUrl, launchExternal: false),
      child: bar,
    );
  }
}
