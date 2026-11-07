import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/l10n/enum_labels.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/irc.dart';
import 'package:onset/screens/channel/chat/chat_commands.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';

class ChatModes extends StatelessWidget {
  final ROOMSTATE roomState;

  const ChatModes({super.key, required this.roomState});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Observer(
      builder: (context) {
        // The pills: what is on, and for how long, in the order of their
        // names.
        final followersNow = roomState.followersOnly == '0';
        final active = <(String, SheetGlyphKind, String?, String)>[
          if (roomState.emoteOnly != '0')
            (
              ChatMode.emoteOnly.pill(l),
              SheetGlyphKind.emote,
              null,
              l.chatModeExplainer(mode: 'emoteOnly'),
            ),
          if (roomState.followersOnly != '-1')
            (
              ChatMode.followers.pill(l),
              SheetGlyphKind.heart,
              _getFollowersDuration(l),
              l.chatModeExplainer(
                mode: followersNow ? 'followersNow' : 'followers',
              ),
            ),
          if (roomState.slowMode != '0')
            (
              ChatMode.slow.pill(l),
              SheetGlyphKind.hourglass,
              _getSlowModeDuration(l),
              l.chatModeExplainer(mode: 'slow'),
            ),
          if (roomState.subMode != '0')
            (
              ChatMode.subscribers.pill(l),
              SheetGlyphKind.star,
              null,
              l.chatModeExplainer(mode: 'subscribers'),
            ),
          if (roomState.r9k != '0')
            (
              ChatMode.uniqueChat.pill(l),
              SheetGlyphKind.unique,
              null,
              l.chatModeExplainer(mode: 'uniqueChat'),
            ),
        ]..sort((a, b) => a.$1.compareTo(b.$1));

        return Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            for (final (label, glyph, duration, explainer) in active)
              Tooltip(
                message: explainer,
                triggerMode: TooltipTriggerMode.tap,
                child: _ModePill(
                  label: label,
                  glyph: glyph,
                  duration: duration,
                ),
              ),
          ],
        );
      },
    );
  }

  String? _getFollowersDuration(AppLocalizations l) {
    if (roomState.followersOnly == '0') {
      return null; // No duration for immediate followers
    }
    final minutes = int.parse(roomState.followersOnly);
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return l.chatShortHours(hours: hours);
      } else {
        return l.chatShortHoursMinutes(hours: hours, minutes: remainingMinutes);
      }
    }
    return l.chatShortMinutes(minutes: minutes);
  }

  String _getSlowModeDuration(AppLocalizations l) {
    final seconds = int.parse(roomState.slowMode);
    if (seconds >= 60) {
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      if (remainingSeconds == 0) {
        return l.chatShortMinutes(minutes: minutes);
      } else {
        return l.chatShortMinutesSeconds(
          minutes: minutes,
          seconds: remainingSeconds,
        );
      }
    }
    return l.chatShortSeconds(seconds: seconds);
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
            width: OnsetTokens.hairlineWidth,
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
              fontFamily: OnsetTokens.bodyFamily,
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
                  fontFamily: OnsetTokens.bodyFamily,
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
