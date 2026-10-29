import 'package:flutter/material.dart';
import 'package:frosty/apis/twitch_directory_service.dart';
import 'package:frosty/screens/home/stream_list/stream_card_parts.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/utils/context_extensions.dart';

/// A stream's tags as small pills on one line (the ones that do not fit
/// are cut, so every card keeps its height).
class StreamTags extends StatelessWidget {
  const StreamTags({
    super.key,
    required this.tags,
    this.max = 4,
    this.onTap,
    this.active,
  });

  final List<String> tags;
  final int max;

  /// The tag of the page the card is on: lit in the signal colour, and it
  /// does not open its own page again (board Categorie).
  final String? active;

  /// Opens a tag; null leaves the pills inert.
  final ValueChanged<String>? onTap;

  static const height = 22.0;

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final tag in tags.take(max))
        if (tag.trim().isNotEmpty) tag.trim(),
    ];
    if (shown.isEmpty) return const SizedBox.shrink();
    final colors = FeedColors.of(context);
    final pills = SizedBox(
      height: height,
      child: ClipRect(
        child: OverflowBox(
          alignment: AlignmentDirectional.centerStart,
          maxWidth: double.infinity,
          child: Row(
            spacing: 4,
            children: [for (final tag in shown) _pill(context, tag, colors)],
          ),
        ),
      ),
    );
    if (onTap != null) return pills;
    return Semantics(
      label: 'Tags: ${shown.join(', ')}',
      child: ExcludeSemantics(child: pills),
    );
  }

  Widget _pill(BuildContext context, String tag, FeedColors colors) {
    final radius = BorderRadius.circular(height / 2);
    final lit =
        active != null && tag.toLowerCase() == active!.trim().toLowerCase();
    final accent = context.frostyColors.live;
    final label = Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: lit
          ? BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: accent,
                width: FrostyTokens.hairlineWidth,
              ),
            )
          : null,
      child: Text(
        tag,
        maxLines: 1,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: lit ? accent : colors.secondary,
        ),
      ),
    );
    final open = onTap;
    return Material(
      color: lit ? accent.withValues(alpha: 0.10) : colors.raised,
      borderRadius: radius,
      child:
          lit ||
              open == null ||
              !TwitchDirectoryService.tagPattern.hasMatch(tag)
          ? label
          : Semantics(
              button: true,
              label: 'Tag $tag',
              excludeSemantics: true,
              child: InkWell(
                borderRadius: radius,
                onTap: () => open(tag),
                child: label,
              ),
            ),
    );
  }
}
