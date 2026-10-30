import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/models/category.dart';
import 'package:onset/screens/home/search/stores/search_store.dart';
import 'package:onset/screens/home/top/categories/category_card.dart';
import 'package:onset/screens/home/top/categories/category_streams.dart';
import 'package:onset/widgets/motion/staggered_entrance.dart';
import 'package:onset/widgets/state_views.dart';

/// The categories found by a search (boards Recherche and
/// RechercheTablette), the exact name first: rows on a phone, box arts in
/// [columns] on a tablet. A tap opens the category.
class SearchResultsCategories extends StatelessWidget {
  final SearchStore searchStore;

  /// How many to show (null: all).
  final int? limit;

  /// Box arts side by side (1: rows).
  final int columns;

  /// The grid's sides and the gaps between its tiles.
  final double gutter;
  final double gap;
  final double rowGap;

  /// The names' size under the box arts.
  final double nameSize;

  const SearchResultsCategories({
    super.key,
    required this.searchStore,
    this.limit,
    this.columns = 1,
    this.gutter = 0,
    this.gap = 14,
    this.rowGap = 18,
    this.nameSize = 14,
  });

  /// A status in the room the results would start in: a failure with its
  /// mark, nothing found without one.
  Widget _message(String message, {bool failed = false}) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 100),
    child: Center(
      child: failed
          // "Try again" (approved addition): the same search again.
          ? InlineStatus.error(
              message: message,
              onRetry: () => searchStore.handleQuery(searchStore.lastQuery),
            )
          : InlineStatus(message: message, glyph: null),
    ),
  );

  Widget _skeleton() {
    final count = limit ?? 8;
    if (columns > 1) {
      return _Tiles(
        columns: columns,
        gutter: gutter,
        gap: gap,
        rowGap: rowGap,
        children: [
          for (var i = 0; i < (count < columns ? columns : count); i++)
            const CategoryTileSkeleton(),
        ],
      );
    }
    return Column(
      children: [for (var i = 0; i < count; i++) const CategoryCardSkeleton()],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final future = searchStore.categoryFuture;

        // Show skeletons immediately while waiting for debounce.
        if (future == null) {
          if (searchStore.isSearching) return _skeleton();
          return const SizedBox.shrink();
        }

        switch (future.status) {
          case FutureStatus.pending:
            return _skeleton();
          case FutureStatus.rejected:
            return _message('Unable to load categories', failed: true);
          case FutureStatus.fulfilled:
            final CategoriesTwitch? categories = future.result;

            if (categories == null) {
              return _message('Failed to get categories', failed: true);
            }

            if (categories.data.isEmpty) {
              return _message('No matching categories');
            }

            final shown = limit == null
                ? categories.data
                : categories.data.take(limit!).toList();
            if (columns > 1) {
              return _Tiles(
                columns: columns,
                gutter: gutter,
                gap: gap,
                rowGap: rowGap,
                children: [
                  for (var i = 0; i < shown.length; i++)
                    StaggeredEntrance(
                      key: ValueKey(shown[i].id),
                      index: i,
                      offset: 6,
                      child: CategoryTile(
                        category: shown[i],
                        nameSize: nameSize,
                        monogramSize: 26,
                        onTap: () => CategoryStreams.open(context, shown[i].id),
                      ),
                    ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < shown.length; i++)
                  StaggeredEntrance(
                    key: ValueKey(shown[i].id),
                    index: i,
                    offset: 6,
                    child: CategoryCard(category: shown[i]),
                  ),
              ],
            );
        }
      },
    );
  }
}

/// Box arts in [columns], top-aligned.
class _Tiles extends StatelessWidget {
  const _Tiles({
    required this.columns,
    required this.gutter,
    required this.gap,
    required this.rowGap,
    required this.children,
  });

  final int columns;
  final double gutter;
  final double gap;
  final double rowGap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = (children.length / columns).ceil();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: gutter),
      child: Column(
        spacing: rowGap,
        children: [
          for (var row = 0; row < rows; row++)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: gap,
              children: [
                for (var column = 0; column < columns; column++)
                  Expanded(
                    child: row * columns + column < children.length
                        ? children[row * columns + column]
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
