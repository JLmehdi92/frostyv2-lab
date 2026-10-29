import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:frosty/utils/context_extensions.dart';

/// A list of cards on phones; on a large screen, rows of as many cards as
/// fit at up to [maxItemWidth] each. Rows size to their tallest card, so
/// cards keep their natural height (text scale, missing thumbnails).
///
/// [itemBuilder] is still called once per item index, so paging triggers
/// based on the index keep working.
class AdaptiveSliverList extends StatelessWidget {
  const AdaptiveSliverList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.maxItemWidth = AdaptiveSliverList.rowCardWidth,
  });

  /// Cards laid out as a row (thumbnail beside the text).
  static const rowCardWidth = 560.0;

  /// Cards with the thumbnail on top.
  static const tileCardWidth = 420.0;

  /// Short rows without a thumbnail (categories, offline channels).
  static const compactCardWidth = 400.0;

  /// Video tiles (board VideosSuiviesTablette: four in a 1280 dp window).
  static const videoTileWidth = 320.0;

  /// The side padding around a grid of video tiles: with the tiles' own
  /// 10 dp, the tablet's 28 dp gutter.
  static const videoTileGutter = 18.0;

  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;
  final double maxItemWidth;

  /// How many cards share a row in [width].
  @visibleForTesting
  static int columnsFor(
    double width, {
    required double maxItemWidth,
    required bool largeScreen,
  }) {
    if (!largeScreen || width <= 0) return 1;
    return math.max(1, (width / maxItemWidth).ceil());
  }

  @override
  Widget build(BuildContext context) {
    final largeScreen = context.isLargeScreen;
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final columns = columnsFor(
          constraints.crossAxisExtent,
          maxItemWidth: maxItemWidth,
          largeScreen: largeScreen,
        );
        if (columns == 1) {
          return SliverList.builder(
            itemCount: itemCount,
            itemBuilder: itemBuilder,
          );
        }
        return SliverList.builder(
          itemCount: (itemCount / columns).ceil(),
          itemBuilder: (context, row) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var column = 0; column < columns; column++)
                Expanded(
                  // Only the outer columns keep the window's side insets
                  // (cutouts); cards add them to their own padding.
                  child: MediaQuery.removePadding(
                    context: context,
                    removeLeft: column > 0,
                    removeRight: column < columns - 1,
                    child: row * columns + column < itemCount
                        ? Builder(
                            builder: (context) =>
                                itemBuilder(context, row * columns + column) ??
                                const SizedBox.shrink(),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
