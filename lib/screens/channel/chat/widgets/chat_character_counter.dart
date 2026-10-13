import 'package:flutter/material.dart';
import 'package:frosty/utils/context_extensions.dart';

/// Twitch refuses chat messages longer than this.
const kChatMessageMaxLength = 500;

/// Shows how many characters are left once fewer than this remain.
const kChatCounterThreshold = 50;

/// The characters left in [controller], shown near the limit like Twitch.
class ChatCharacterCounter extends StatelessWidget {
  const ChatCharacterCounter({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final left = kChatMessageMaxLength - value.text.characters.length;
        if (left >= kChatCounterThreshold) return const SizedBox.shrink();
        return Semantics(
          liveRegion: true,
          label: '$left characters left',
          child: ExcludeSemantics(
            child: Text(
              '$left',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: left <= 10
                    ? context.colorScheme.error
                    : context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      },
    );
  }
}
