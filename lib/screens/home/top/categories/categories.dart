import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/models/category.dart';
import 'package:frosty/screens/home/stream_list/stream_card_parts.dart';
import 'package:frosty/screens/home/stream_list/streams_list.dart';
import 'package:frosty/screens/home/top/categories/categories_store.dart';
import 'package:frosty/screens/home/top/categories/category_card.dart';
import 'package:frosty/screens/home/top/categories/category_streams.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/widgets/alert_message.dart';
import 'package:frosty/widgets/frosty_scrollbar.dart';
import 'package:frosty/widgets/motion/staggered_entrance.dart';

/// Browse's top categories as a grid of box arts (boards Parcourir and
/// ParcourirTablette), most watched first, more as the end comes into view.
///
/// As the tablet's [rail] beside a category, it says so in its title, rings
/// the [selectedId] and hands taps to [onSelect]; elsewhere a tap opens the
/// category's page.
class Categories extends StatefulWidget {
  const Categories({
    super.key,
    required this.store,
    required this.scrollController,
    this.rail = false,
    this.selectedId,
    this.onSelect,
  });

  final CategoriesStore store;
  final ScrollController scrollController;

  /// The tablet's column beside the chosen category's streams.
  final bool rail;
  final String? selectedId;

  /// Null: a tap opens the category's page.
  final ValueChanged<CategoryTwitch>? onSelect;

  /// Tile columns in [width] (at least three: the phone's board).
  static int columnsFor(double width, {required double gap}) =>
      math.max(3, ((width + gap) / (_minTile + gap)).floor());

  static const _minTile = 104.0;

  @override
  State<Categories> createState() => _CategoriesState();
}

class _CategoriesState extends State<Categories>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  CategoriesStore get _store => widget.store;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      _store.checkLastTimeRefreshedAndUpdate();
    }
  }

  Future<void> _refresh() async {
    HapticFeedback.lightImpact();
    await _store.refreshCategories();

    final error = _store.error;
    if (error == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AlertMessage(message: error, centered: false)),
    );
  }

  void _open(CategoryTwitch category) {
    final onSelect = widget.onSelect;
    if (onSelect != null) {
      onSelect(category);
    } else {
      CategoryStreams.open(context, category.id);
    }
  }

  /// The grid's padding, from the boards: 16 on a phone, the tablet's 28
  /// gutter, the rail's 28 / 20.
  EdgeInsets _gutter(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    if (widget.rail) {
      return EdgeInsets.only(left: 28 + padding.left, right: 20);
    }
    final gutter = context.isLargeScreen
        ? FrostySpacing.gutterTablet
        : FrostySpacing.gutterPhone;
    return EdgeInsets.only(
      left: gutter + padding.left,
      right: gutter + padding.right,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    _store.checkLastTimeRefreshedAndUpdate();

    final padding = MediaQuery.paddingOf(context);
    final large = context.isLargeScreen;
    final gap = large ? 14.0 : 12.0;
    final rowGap = 16.0;
    final top = widget.rail ? 18.0 : (large ? 20.0 : 16.0);

    return RefreshIndicator.adaptive(
      edgeOffset: padding.top,
      onRefresh: _refresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final gutter = _gutter(context);
          final columns = Categories.columnsFor(
            constraints.maxWidth - gutter.horizontal,
            gap: gap,
          );
          return Observer(
            builder: (context) {
              final categories = _store.categories;
              final error = _store.error;
              final header = <Widget>[
                SliverToBoxAdapter(child: SizedBox(height: padding.top + top)),
                if (widget.rail)
                  SliverPadding(
                    padding: gutter.copyWith(bottom: 14),
                    sliver: const SliverToBoxAdapter(child: _RailTitle()),
                  ),
              ];

              if (categories.isEmpty && _store.isLoading && error == null) {
                return StaggerScope(
                  key: const ValueKey('loading'),
                  child: CustomScrollView(
                    controller: widget.scrollController,
                    physics: const NeverScrollableScrollPhysics(),
                    slivers: [
                      ...header,
                      RowGridSliver(
                        itemCount: columns * 4,
                        columns: columns,
                        gutter: 0,
                        gap: gap,
                        rowGap: rowGap,
                        padding: gutter,
                        itemBuilder: (context, index) => StaggeredEntrance(
                          index: index,
                          child: const CategoryTileSkeleton(),
                        ),
                      ),
                    ],
                  ),
                );
              }

              Widget? status;
              if (error != null && categories.isEmpty) {
                status = FeedStatusView.error(
                  message: error,
                  onRetry: () => _refresh(),
                );
              } else if (categories.isEmpty) {
                status = const FeedStatusView.empty(
                  message: 'No top categories',
                );
              }
              if (status != null) {
                return StaggerScope(
                  key: const ValueKey('status'),
                  child: CustomScrollView(
                    controller: widget.scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      ...header,
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: StaggeredEntrance(index: 0, child: status),
                      ),
                    ],
                  ),
                );
              }

              final selectedId = widget.selectedId;
              final loadingMore = _store.isLoadingMore;
              // A page that failed is not asked for again by itself (it
              // would be, at every rebuild): "Try again" or a refresh does.
              final pagingFailed = error != null && _store.hasMore;
              return FrostyScrollbar(
                controller: widget.scrollController,
                padding: EdgeInsets.only(
                  top: padding.top,
                  bottom: padding.bottom,
                ),
                child: StaggerScope(
                  key: const ValueKey('content'),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    controller: widget.scrollController,
                    slivers: [
                      ...header,
                      RowGridSliver(
                        // While the next page loads, a row of skeletons ends
                        // the grid (boards).
                        itemCount:
                            categories.length +
                            (loadingMore
                                ? _fill(categories.length, columns)
                                : 0),
                        columns: columns,
                        gutter: 0,
                        gap: gap,
                        rowGap: rowGap,
                        padding: gutter,
                        itemBuilder: (context, index) {
                          if (index >= categories.length) {
                            return const CategoryTileSkeleton();
                          }
                          if (index > categories.length - 10 &&
                              _store.hasMore &&
                              !pagingFailed) {
                            // After the frame: the next page flips the
                            // loading state this grid reads, which must not
                            // change while it is being laid out.
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted &&
                                  _store.hasMore &&
                                  _store.error == null) {
                                _store.getCategories();
                              }
                            });
                          }
                          final category = categories[index];
                          return StaggeredEntrance(
                            key: ValueKey(category.id),
                            index: index,
                            child: CategoryTile(
                              category: category,
                              selected: category.id == selectedId,
                              onTap: () => _open(category),
                            ),
                          );
                        },
                      ),
                      if (pagingFailed)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Center(
                              child: TextButton.icon(
                                onPressed: _store.getCategories,
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 18,
                                ),
                                label: const Text('Try again'),
                              ),
                            ),
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: padding.bottom + (widget.rail ? 32 : 0),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Skeletons that complete the last row, or a whole row.
  static int _fill(int count, int columns) {
    final rest = count % columns;
    return rest == 0 ? columns : columns - rest;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

/// "Top categories · Most watched first" over the tablet's rail.
class _RailTitle extends StatelessWidget {
  const _RailTitle();

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        const Expanded(child: FeedSectionTitle('Top categories')),
        Text(
          'Most watched first',
          style: TextStyle(fontSize: 12, color: colors.tertiary),
        ),
      ],
    );
  }
}
