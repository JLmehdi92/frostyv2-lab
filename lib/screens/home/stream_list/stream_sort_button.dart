import 'package:flutter/material.dart';
import 'package:frosty/apis/twitch_directory_service.dart';

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
