import 'package:flutter/material.dart';
import 'package:onset/models/vod.dart';
import 'package:onset/screens/vod/stores/channel_videos_store.dart';
import 'package:onset/screens/vod/widgets/channel_videos_tab.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';

/// The profile's video types: past broadcasts (the default), highlights
/// and uploads, each with its empty message.
const kProfileVideoTypes = [
  (VodType.archive, 'Past broadcasts', 'No past broadcasts'),
  (VodType.highlight, 'Highlights', 'No highlights'),
  (VodType.upload, 'Uploads', 'No uploads'),
];

/// The profile's Videos tab: the type pills, then that type's list with
/// its progress, pull to refresh and states ([ChannelVideosTab]).
class ProfileVideosTab extends StatelessWidget {
  const ProfileVideosTab({
    super.key,
    required this.type,
    required this.onType,
    required this.storeFor,
    this.nested = false,
    this.leadingSlivers = const [],
    this.refreshEdgeOffset = 0,
  });

  final VodType type;
  final ValueChanged<VodType> onType;

  /// Each type's store, made the first time it is shown.
  final ChannelVideosStore Function(VodType type) storeFor;
  final bool nested;
  final List<Widget> leadingSlivers;
  final double refreshEdgeOffset;

  @override
  Widget build(BuildContext context) {
    final (_, _, empty) = kProfileVideoTypes.firstWhere((t) => t.$1 == type);
    final padding = MediaQuery.paddingOf(context);
    // Each type keeps its own list and scroll position.
    return ChannelVideosTab(
      key: PageStorageKey('videos-${type.name}'),
      store: storeFor(type),
      emptyMessage: empty,
      nested: nested,
      refreshEdgeOffset: refreshEdgeOffset,
      leadingSlivers: [
        ...leadingSlivers,
        SliverToBoxAdapter(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.fromLTRB(
              16 + padding.left,
              12,
              16 + padding.right,
              4,
            ),
            child: Row(
              spacing: 8,
              children: [
                for (final (value, label, _) in kProfileVideoTypes)
                  SheetChoicePill(
                    label: label,
                    large: true,
                    selected: value == type,
                    onSelected: value == type ? null : () => onType(value),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
