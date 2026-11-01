import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/apis/twitch_directory_service.dart';
import 'package:onset/l10n/enum_labels.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';

/// "Sorted by …" above a category's or a tag's live streams:
/// a quiet text button that opens the
/// orders in a raised menu, the current one ticked in the signal colour.
class StreamSortButton extends StatelessWidget {
  const StreamSortButton({super.key, required this.sort, required this.onSort});

  final StreamSort sort;
  final ValueChanged<StreamSort> onSort;

  /// The menu's width (236 on a phone, 240 on a tablet).
  static const menuWidth = 240.0;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final accent = context.onsetColors.live;
    return PopupMenuButton<StreamSort>(
      tooltip: 'Sort streams',
      initialValue: sort,
      onSelected: onSort,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 2),
      color: colors.raised,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.6),
      menuPadding: const EdgeInsets.all(6),
      constraints: const BoxConstraints.tightFor(width: menuWidth),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colors.pillBorder,
          width: OnsetTokens.hairlineWidth,
        ),
      ),
      itemBuilder: (context) => [
        for (final option in StreamSort.values)
          PopupMenuItem(
            value: option,
            height: 44,
            padding: EdgeInsets.zero,
            child: _SortOption(
              label: option.label,
              selected: option == sort,
              accent: accent,
              colors: colors,
            ),
          ),
      ],
      child: SizedBox(
        height: 44,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            Icon(Icons.sort_rounded, size: 16, color: colors.secondary),
            Flexible(
              child: Text.rich(
                TextSpan(
                  text: 'Sorted by ',
                  children: [
                    TextSpan(
                      text: sort.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: colors.secondary),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: colors.secondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// One order in the menu: 44 high, the current one on a faint fill with
/// the signal tick.
class _SortOption extends StatelessWidget {
  const _SortOption({
    required this.label,
    required this.selected,
    required this.accent,
    required this.colors,
  });

  final String label;
  final bool selected;
  final Color accent;
  final FeedColors colors;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? colors.text.withValues(alpha: 0.06) : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: colors.text,
                ),
              ),
            ),
            if (selected) Icon(Icons.check_rounded, size: 18, color: accent),
          ],
        ),
      ),
    );
  }
}

/// "Sorted by …" beside Following's "Live now"
/// (a 32 dp pill), like Twitch's subheader; it opens the
/// other orders and remembers the choice.
class FollowedSortButton extends StatelessWidget {
  const FollowedSortButton({super.key, required this.settingsStore});

  final SettingsStore settingsStore;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
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
                // English, like the rest of the button, until it is
                // translated.
                child: Text(option.label(L10n.untranslated)),
              ),
          ],
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: ShapeDecoration(
              color: colors.surface,
              shape: StadiumBorder(
                side: BorderSide(
                  color: colors.pillBorder,
                  width: OnsetTokens.hairlineWidth,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                Icon(Icons.sort_rounded, size: 14, color: colors.body),
                Flexible(
                  child: Text(
                    'Sorted by ${sort.label(L10n.untranslated)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors.body,
                    ),
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
