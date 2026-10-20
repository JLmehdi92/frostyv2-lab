import 'package:flutter/material.dart';
import 'package:frosty/utils/context_extensions.dart';

/// The official app's "Message Blocked" sheet, shown when the viewer taps
/// a word their chat filters hid. Pops true for "Show Message".
class FilteredMessageSheet extends StatelessWidget {
  const FilteredMessageSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Message Blocked',
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 16),
              child: Text(
                'Would you like to see this message? It has been hidden for '
                'you based on your NSFW Chat Filter settings.',
                style: TextStyle(color: context.frostyColors.metadata),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Show Message'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
