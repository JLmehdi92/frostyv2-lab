import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/category.dart';
import 'package:onset/screens/home/shell/shell_pages.dart';
import 'package:onset/screens/home/stores/home_store.dart';
import 'package:onset/screens/home/stream_list/stores/stream_list_store.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/screens/home/stream_list/streams_list.dart';
import 'package:onset/screens/home/top/categories/categories.dart';
import 'package:onset/screens/home/top/categories/category_streams.dart';
import 'package:onset/screens/home/top/categories/stores/categories_store.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/motion/motion.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';
import 'package:onset/widgets/recommendations/recommended_channels.dart';
import 'package:provider/provider.dart';

/// The shell's Browse section:
/// "Categories" (the top categories) and "Live channels" (the top streams),
/// the tabs living in the shell's header.
///
/// On a landscape tablet the categories are a rail beside the chosen one's
/// streams, videos and clips; elsewhere a tap opens the category's page.
class BrowsePage extends StatefulWidget {
  const BrowsePage({
    super.key,
    required this.tab,
    required this.categoriesController,
    required this.liveController,
  });

  final BrowseTab tab;

  /// The categories' and the live channels' scroll (a second tap on the
  /// tab or on Browse brings them back to the top).
  final ScrollController categoriesController;
  final ScrollController liveController;

  /// Width from which the categories sit beside the chosen one (a
  /// landscape tablet, 1280 dp wide).
  static const masterDetailWidth = 1000.0;

  /// The rail's width (448).
  static const railWidth = 448.0;

  @override
  State<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends State<BrowsePage> {
  late final _categories = CategoriesStore(
    authStore: context.read<AuthStore>(),
    twitchApi: context.read<TwitchApi>(),
  );

  /// The grid moves between the full page and the rail when the window
  /// changes (rotation, folding): its state and scroll go along.
  final _gridKey = GlobalKey(debugLabel: 'browse-categories');

  /// The category beside the rail, once the viewer picked one (until then,
  /// the first).
  String? _picked;

  void _pick(CategoryTwitch category) {
    if (category.id == _picked) return;
    setState(() => _picked = category.id);
  }

  @override
  Widget build(BuildContext context) {
    return ShellPages<BrowseTab>(
      pages: BrowseTab.values,
      current: widget.tab,
      motion: ShellPagesMotion.lateral,
      builder: (context, tab) => switch (tab) {
        BrowseTab.categories => _categoriesTab(context),
        BrowseTab.live => _LiveChannels(controller: widget.liveController),
      },
    );
  }

  Widget _categoriesTab(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final masterDetail =
        context.isLargeScreen && size.width >= BrowsePage.masterDetailWidth;
    if (!masterDetail) {
      return Categories(
        key: _gridKey,
        store: _categories,
        scrollController: widget.categoriesController,
      );
    }
    return Observer(
      builder: (context) {
        final categories = _categories.categories;
        // The pick stays even when a refresh no longer lists it (it was on
        // a later page): the pane keeps it, only the ring goes.
        // The first category, once shown, stays the pick: a refresh that
        // reorders the list does not swap the pane.
        final selected = _picked ??= categories.firstOrNull?.id;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: BrowsePage.railWidth + padding.left,
              child: MediaQuery.removePadding(
                context: context,
                removeRight: true,
                child: Categories(
                  key: _gridKey,
                  store: _categories,
                  scrollController: widget.categoriesController,
                  rail: true,
                  selectedId: selected,
                  onSelect: _pick,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  top: 16,
                  right: OnsetSpacing.gutterTablet + padding.right,
                ),
                child: _CategoryPane(categoryId: selected),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The chosen category's streams, videos and clips in a raised panel
/// (#141414, 24 dp top corners); another category
/// slides in over the last (280 ms).
class _CategoryPane extends StatelessWidget {
  const _CategoryPane({required this.categoryId});

  final String? categoryId;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    const radius = BorderRadius.vertical(
      top: Radius.circular(OnsetTokens.radiusLarge),
    );
    final reduce = reduceMotionOf(context);
    final id = categoryId;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: radius,
        border: Border.all(
          color: colors.hairline,
          width: OnsetTokens.hairlineWidth,
        ),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              // The pane is the category's window: its grid counts its
              // columns in the pane, and nothing pads it but the system's
              // bottom inset. It stays a tablet's layout however narrow or
              // short (LargeScreenScope below).
              data: media.copyWith(
                size: constraints.biggest,
                padding: EdgeInsets.only(bottom: media.padding.bottom),
                viewPadding: EdgeInsets.only(bottom: media.viewPadding.bottom),
              ),
              child: AnimatedSwitcher(
                duration: motionDuration(
                  context,
                  const Duration(milliseconds: 280),
                ),
                switchInCurve: OnsetMotion.standard,
                switchOutCurve: OnsetMotion.standard,
                layoutBuilder: (current, previous) => Stack(
                  fit: StackFit.expand,
                  children: [...previous, ?current],
                ),
                transitionBuilder: (child, animation) {
                  final fade = FadeTransition(opacity: animation, child: child);
                  if (reduce) return fade;
                  return SlideTransition(
                    position: Tween(
                      begin: const Offset(12 / 800, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: fade,
                  );
                },
                child: id == null
                    ? const SizedBox.shrink(key: ValueKey('none'))
                    : LargeScreenScope(
                        key: ValueKey(id),
                        large: true,
                        child: CategoryView(categoryId: id, embedded: true),
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Browse's "Live channels": the top streams with every list behaviour
/// (language, hidden labels, paging, refresh); on a tablet under "Live
/// channels across Twitch", as tiles.
class _LiveChannels extends StatelessWidget {
  const _LiveChannels({required this.controller});

  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final large = context.isLargeScreen;
    return StreamsList(
      listType: ListType.top,
      scrollController: controller,
      leadingSlivers: [
        if (large)
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(
              OnsetSpacing.gutterTablet,
              20,
              OnsetSpacing.gutterTablet,
              2,
            ),
            sliver: SliverToBoxAdapter(child: _LiveChannelsTitle()),
          )
        else
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
        const SliverToBoxAdapter(child: RecommendationsShelf()),
      ],
    );
  }
}

/// "Live channels across Twitch".
class _LiveChannelsTitle extends StatelessWidget {
  const _LiveChannelsTitle();

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final l = context.l10n;
    return Semantics(
      header: true,
      child: Text.rich(
        TextSpan(
          // "Live channels" and, lighter, "across Twitch", where the
          // language puts it.
          children: l10nSpans(l.browseLiveChannels(where: l10nMark(0)), [
            TextSpan(
              text: l.browseAcrossTwitch,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colors.tertiary,
              ),
            ),
          ]),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: FeedSectionTitle.style.copyWith(color: colors.text),
      ),
    );
  }
}
