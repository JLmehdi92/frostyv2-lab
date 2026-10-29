import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/models/irc.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/widgets/sheet/onset_sheet.dart';
import 'package:frosty/widgets/sheet/sheet_glyph.dart';

class ChatModes extends StatelessWidget {
  final ROOMSTATE roomState;

  const ChatModes({super.key, required this.roomState});

  String pluralize(String str, String count) => count == '1' ? str : '${str}s';

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        // The board's pills: what is on, and for how long.
        final active = <(String, SheetGlyphKind, String?)>[
          if (roomState.emoteOnly != '0')
            ('Emote only', SheetGlyphKind.emote, null),
          if (roomState.followersOnly != '-1')
            ('Follower only', SheetGlyphKind.heart, _getFollowersDuration()),
          if (roomState.slowMode != '0')
            ('Slow mode', SheetGlyphKind.hourglass, _getSlowModeDuration()),
          if (roomState.subMode != '0') ('Sub only', SheetGlyphKind.star, null),
          if (roomState.r9k != '0')
            ('Unique mode', SheetGlyphKind.unique, null),
        ]..sort((a, b) => a.$1.compareTo(b.$1));

        return Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            for (final (label, glyph, duration) in active)
              _ModePill(label: label, glyph: glyph, duration: duration),
          ],
        );
      },
    );
  }

  String? _getFollowersDuration() {
    if (roomState.followersOnly == '0') {
      return null; // No duration for immediate followers
    }
    final minutes = int.parse(roomState.followersOnly);
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '${hours}h';
      } else {
        return '${hours}h ${remainingMinutes}m';
      }
    }
    return '${minutes}m';
  }

  String _getSlowModeDuration() {
    final seconds = int.parse(roomState.slowMode);
    if (seconds >= 60) {
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      if (remainingSeconds == 0) {
        return '${minutes}m';
      } else {
        return '${minutes}m ${remainingSeconds}s';
      }
    }
    return '${seconds}s';
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({
    required this.label,
    required this.glyph,
    required this.duration,
  });

  final String label;
  final SheetGlyphKind glyph;
  final String? duration;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: ShapeDecoration(
        color: colors.raised,
        shape: StadiumBorder(
          side: BorderSide(
            color: colors.ring,
            width: FrostyTokens.hairlineWidth,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          SheetGlyph(glyph, size: 14, color: colors.body),
          Text(
            label,
            style: TextStyle(
              fontFamily: FrostyTokens.bodyFamily,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.body,
            ),
          ),
          if (duration case final duration?)
            Text(
              duration,
              style: SheetText.tabular(
                TextStyle(
                  fontFamily: FrostyTokens.bodyFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colors.secondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
