import 'package:flutter/material.dart';
import 'package:frosty/utils/context_extensions.dart';

/// A stream's tags as small pills on one line (the ones that do not fit
/// are cut, so every card keeps its height).
class StreamTags extends StatelessWidget {
  const StreamTags({super.key, required this.tags, this.max = 4});

  final List<String> tags;
  final int max;

  static const height = 22.0;

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final tag in tags.take(max))
        if (tag.trim().isNotEmpty) tag.trim(),
    ];
    if (shown.isEmpty) return const SizedBox.shrink();
    final scheme = context.colorScheme;
    return Semantics(
      label: 'Tags: ${shown.join(', ')}',
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          child: ClipRect(
            child: OverflowBox(
              alignment: AlignmentDirectional.centerStart,
              maxWidth: double.infinity,
              child: Row(
                spacing: 4,
                children: [
                  for (final tag in shown)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(height / 2),
                      ),
                      child: Text(
                        tag,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
