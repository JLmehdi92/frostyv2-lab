import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/apis/twitch_directory_service.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';

/// A chip naming the order of a live list; it opens the other orders.
class StreamSortButton extends StatelessWidget {
  const StreamSortButton({super.key, required this.sort, required this.onSort});

  final StreamSort sort;
  final ValueChanged<StreamSort> onSort;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<StreamSort>(
      tooltip: 'Sort streams',
      initialValue: sort,
      onSelected: onSort,
      itemBuilder: (context) => [
        for (final option in StreamSort.values)
          CheckedPopupMenuItem(
            value: option,
            checked: option == sort,
            child: Text(option.label),
          ),
      ],
      child: Chip(
        avatar: const Icon(Icons.sort_rounded, size: 18),
        label: Text(sort.label),
      ),
    );
  }
}

/// "Sorted by …" above Following's live channels, like Twitch's subheader;
/// it opens the other orders and remembers the choice.
class FollowedSortButton extends StatelessWidget {
  const FollowedSortButton({super.key, required this.settingsStore});

  final SettingsStore settingsStore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Observer(
      builder: (context) {
        final sort = settingsStore.followedSort;
        return PopupMenuButton<FollowedSort>(
          tooltip: 'Sort live channels',
          initialValue: sort,
          onSelected: (value) => settingsStore.followedSort = value,
          itemBuilder: (context) => [
            for (final option in FollowedSort.values)
              CheckedPopupMenuItem(
                value: option,
                checked: option == sort,
                child: Text(option.label),
              ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                Icon(
                  Icons.sort_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      text: 'Sorted by ',
                      children: [
                        TextSpan(
                          text: sort.label,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
