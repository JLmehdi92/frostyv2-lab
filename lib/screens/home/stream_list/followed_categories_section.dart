import 'package:flutter/material.dart';
import 'package:frosty/models/followed_category.dart';
import 'package:frosty/screens/home/stream_list/stream_card_parts.dart';
import 'package:frosty/screens/home/top/categories/category_streams.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/widgets/frosty_cached_network_image.dart';
import 'package:frosty/widgets/motion/press_scale.dart';
import 'package:frosty/widgets/skeleton_loader.dart';
import 'package:intl/intl.dart';

/// Opens the live streams of [category].
void _openCategory(BuildContext context, FollowedCategory category) =>
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: CategoryStreams.routeName),
        builder: (context) => CategoryStreams(categoryId: category.id),
      ),
    );

/// Following's "Categories": the categories the viewer follows, with how
/// many people watch each (boards Accueil / Etats: 104 dp box art on a
/// phone, 132 on a tablet); a tap opens its live streams. Nothing when
/// there are none (or Twitch did not give them).
class FollowedCategoriesSection extends StatelessWidget {
  const FollowedCategoriesSection({super.key, required this.categories});

  final List<FollowedCategory> categories;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    final padding = MediaQuery.paddingOf(context);
    final large = context.isLargeScreen;
    final gutter = large
        ? FrostySpacing.gutterTablet
        : FrostySpacing.gutterPhone;
    final artWidth = large ? 132.0 : 104.0;

    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          Padding(
            padding: EdgeInsets.only(
              left: gutter + padding.left,
              right: gutter + padding.right,
            ),
            child: const Align(
              alignment: AlignmentDirectional.centerStart,
              child: FeedSectionTitle('Categories'),
            ),
          ),
          SizedBox(
            // Box art (3:4), then the name and the viewers.
            height: artWidth * 4 / 3 + 50,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.only(
                left: gutter + padding.left,
                right: gutter + padding.right,
              ),
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) => _FollowedCategoryTile(
                category: categories[index],
                width: artWidth,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowedCategoryTile extends StatelessWidget {
  const _FollowedCategoryTile({required this.category, required this.width});

  final FollowedCategory category;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final viewers = category.viewers;
    const radius = BorderRadius.all(Radius.circular(12));
    return SizedBox(
      width: width,
      child: PressScale(
        child: InkWell(
          borderRadius: radius,
          onTap: () => _openCategory(context, category),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 6,
            children: [
              ClipRRect(
                borderRadius: radius,
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: category.boxArtUrl.isEmpty
                      ? ColoredBox(color: colors.raised)
                      : FrostyCachedNetworkImage(
                          imageUrl: category.boxArtUrl,
                          fit: BoxFit.cover,
                          memCacheWidth:
                              (width * MediaQuery.devicePixelRatioOf(context))
                                  .round(),
                          placeholder: (context, url) =>
                              const SkeletonLoader(borderRadius: radius),
                        ),
                ),
              ),
              Text(
                category.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
              Text(
                '${NumberFormat.compact().format(viewers)} '
                '${viewers == 1 ? 'viewer' : 'viewers'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FrostyType.tabular(
                  TextStyle(fontSize: 12, color: colors.secondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The followed categories as pills, under the tablet's hero
/// (TabletteAccueil): box art and name; a tap opens its live streams.
class FollowedCategoryChips extends StatelessWidget {
  const FollowedCategoryChips({super.key, required this.categories});

  final List<FollowedCategory> categories;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    final colors = FeedColors.of(context);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final category in categories)
          Semantics(
            button: true,
            label:
                '${category.title}, '
                '${NumberFormat.compact().format(category.viewers)} viewers',
            excludeSemantics: true,
            child: PressScale(
              child: Material(
                color: colors.surface,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: colors.pillBorder,
                    width: FrostyTokens.hairlineWidth,
                  ),
                ),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => _openCategory(context, category),
                  child: Container(
                    height: 32,
                    constraints: const BoxConstraints(maxWidth: 220),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 8,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: SizedBox(
                            width: 18,
                            height: 24,
                            child: category.boxArtUrl.isEmpty
                                ? ColoredBox(color: colors.raised)
                                : FrostyCachedNetworkImage(
                                    imageUrl: category.boxArtUrl,
                                    fit: BoxFit.cover,
                                    memCacheWidth:
                                        (18 *
                                                MediaQuery.devicePixelRatioOf(
                                                  context,
                                                ))
                                            .round(),
                                  ),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            category.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colors.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
