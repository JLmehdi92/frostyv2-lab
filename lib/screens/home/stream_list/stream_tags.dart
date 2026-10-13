import 'package:flutter/material.dart';
import 'package:frosty/apis/twitch_directory_service.dart';
import 'package:frosty/utils/context_extensions.dart';

/// A stream's tags as small pills on one line (the ones that do not fit
/// are cut, so every card keeps its height).
class StreamTags extends StatelessWidget {
  const StreamTags({super.key, required this.tags, this.max = 4, this.onTap});

  final List<String> tags;
  final int max;

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
    final scheme = context.colorScheme;
    final pills = SizedBox(
      height: height,
      child: ClipRect(
        child: OverflowBox(
          alignment: AlignmentDirectional.centerStart,
          maxWidth: double.infinity,
          child: Row(
            spacing: 4,
            children: [for (final tag in shown) _pill(tag, scheme)],
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

  Widget _pill(String tag, ColorScheme scheme) {
    final radius = BorderRadius.circular(height / 2);
    final label = Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      child: Text(
        tag,
        maxLines: 1,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
    final open = onTap;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: radius,
      child: open == null || !TwitchDirectoryService.tagPattern.hasMatch(tag)
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
