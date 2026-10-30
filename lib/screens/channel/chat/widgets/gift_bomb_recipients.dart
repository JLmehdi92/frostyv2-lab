import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:onset/screens/channel/chat/gift_bomb_tracker.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/motion/motion.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';

/// Under the header row of a collapsed gift bomb (board CadeauxHypeTrain,
/// B): "3 of 5 recipients ▾" while the gifts arrive, then "5 recipients ▾",
/// a 28 dp pill in a 44 dp target that opens the recipients inline as
/// pills (220 ms).
///
/// [live] follows the bomb. Chat rows are rebuilt (and their state
/// dropped) as messages arrive, so the choice is also handed to
/// [onExpandedChanged] for the chat store to keep, and read back from
/// [initiallyExpanded]. Key it by the bomb.
class GiftBombRecipients extends StatefulWidget {
  const GiftBombRecipients({
    super.key,
    required this.live,
    this.initiallyExpanded = false,
    this.onExpandedChanged,
  });

  final ValueListenable<GiftBomb> live;
  final bool initiallyExpanded;
  final ValueChanged<bool>? onExpandedChanged;

  /// The pill that opens and closes the list.
  static const toggleKey = ValueKey('gift-bomb-recipients-toggle');

  /// The recipients' pills.
  static const listKey = ValueKey('gift-bomb-recipients-list');

  static const _duration = Duration(milliseconds: 220);

  /// "3 of 5 recipients", or "5 recipients" once they all arrived.
  static String label(GiftBomb bomb) {
    final count = bomb.count;
    final received = bomb.received < count ? bomb.received : count;
    final noun = count == 1 ? 'recipient' : 'recipients';
    return received < count ? '$received of $count $noun' : '$count $noun';
  }

  @override
  State<GiftBombRecipients> createState() => _GiftBombRecipientsState();
}

class _GiftBombRecipientsState extends State<GiftBombRecipients> {
  late var _expanded = widget.initiallyExpanded;

  void _toggle() {
    setState(() => _expanded = !_expanded);
    widget.onExpandedChanged?.call(_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final expanded = _expanded;
    final onToggle = _toggle;
    final colors = context.onsetColors;
    final accent = colors.subNoticeAccent;
    final text = colors.subNoticeText;
    final reduceMotion = reduceMotionOf(context);
    final duration = reduceMotion
        ? Duration.zero
        : GiftBombRecipients._duration;
    return ValueListenableBuilder<GiftBomb>(
      valueListenable: widget.live,
      builder: (context, bomb, _) {
        final title = GiftBombRecipients.label(bomb);
        final chip = Container(
          height: 28,
          padding: const EdgeInsetsDirectional.only(start: 11, end: 8),
          decoration: ShapeDecoration(
            color: accent.withValues(alpha: 0.12),
            shape: StadiumBorder(
              side: BorderSide(
                color: accent.withValues(alpha: 0.45),
                width: OnsetTokens.hairlineWidth,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: [
              Text(
                title,
                maxLines: 1,
                style: OnsetType.tabular(
                  TextStyle(
                    fontFamily: OnsetTokens.bodyFamily,
                    fontSize: 12.5,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    color: text,
                  ),
                ),
              ),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: duration,
                curve: OnsetMotion.standard,
                child: SheetGlyph(
                  SheetGlyphKind.chevronDown,
                  size: 16,
                  strokeWidth: 2.2,
                  color: text,
                ),
              ),
            ],
          ),
        );
        final toggle = Semantics(
          button: true,
          expanded: expanded,
          label: title,
          onTap: onToggle,
          excludeSemantics: true,
          child: GestureDetector(
            key: GiftBombRecipients.toggleKey,
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            // A 44 dp target around the 28 dp pill, overlapping the row's
            // padding as on the board.
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: chip,
            ),
          ),
        );
        final more = bomb.received - bomb.recipients.length;
        final list = !expanded
            ? const SizedBox(width: double.infinity)
            : Padding(
                key: GiftBombRecipients.listKey,
                padding: const EdgeInsets.only(bottom: 10),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final name in bomb.recipients)
                      _RecipientPill(name, accent: accent),
                    if (more > 0) _RecipientPill('+$more more', accent: accent),
                  ],
                ),
              );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Transform.translate(offset: const Offset(-8, 0), child: toggle),
            if (reduceMotion)
              list
            else
              ClipRect(
                child: AnimatedSize(
                  duration: GiftBombRecipients._duration,
                  curve: OnsetMotion.standard,
                  alignment: AlignmentDirectional.topStart,
                  child: list,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// One recipient: a 26 dp pill ringed in the signal colour.
class _RecipientPill extends StatelessWidget {
  const _RecipientPill(this.name, {required this.accent});

  final String name;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: ShapeDecoration(
        color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.04),
        shape: StadiumBorder(
          side: BorderSide(
            color: accent.withValues(alpha: 0.30),
            width: OnsetTokens.hairlineWidth,
          ),
        ),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: OnsetTokens.bodyFamily,
            fontSize: 12.5,
            height: 1,
            fontWeight: FontWeight.w600,
            color: dark ? const Color(0xFFD6D6D6) : const Color(0xFF3A3A3A),
          ),
        ),
      ),
    );
  }
}
