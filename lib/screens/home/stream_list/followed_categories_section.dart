import 'package:flutter/material.dart';
import 'package:frosty/constants.dart';
import 'package:frosty/models/followed_category.dart';
import 'package:frosty/screens/home/top/categories/category_streams.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/widgets/frosty_cached_network_image.dart';
import 'package:frosty/widgets/section_header.dart';
import 'package:frosty/widgets/skeleton_loader.dart';
import 'package:intl/intl.dart';

/// Following's "Categories": the categories the viewer follows, with how
/// many people watch each; a tap opens its live streams. Nothing when there
/// are none (or Twitch did not give them).
class FollowedCategoriesSection extends StatelessWidget {
  const FollowedCategoriesSection({super.key, required this.categories});

  final List<FollowedCategory> categories;

  static const _artWidth = 96.0;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    final padding = MediaQuery.paddingOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(
          'Categories',
          isFirst: true,
          padding: EdgeInsets.fromLTRB(
            16 + padding.left,
            16,
            16 + padding.right,
            8,
          ),
        ),
        SizedBox(
          // Box art (4:3 tall), then the name and the viewers.
          height: _artWidth * 4 / 3 + 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.only(
              left: 16 + padding.left,
              right: 16 + padding.right,
            ),
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) =>
                _FollowedCategoryTile(category: categories[index]),
          ),
        ),
      ],
    );
  }
}

class _FollowedCategoryTile extends StatelessWidget {
  const _FollowedCategoryTile({required this.category});

  final FollowedCategory category;

  @override
  Widget build(BuildContext context) {
    final viewers = category.viewers;
    return SizedBox(
      width: FollowedCategoriesSection._artWidth,
      child: InkWell(
        borderRadius: kCardBorderRadius,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: CategoryStreams.routeName),
            builder: (context) => CategoryStreams(categoryId: category.id),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: kCardBorderRadius,
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: category.boxArtUrl.isEmpty
                    ? ColoredBox(
                        color: context.colorScheme.surfaceContainerHighest,
                      )
                    : FrostyCachedNetworkImage(
                        imageUrl: category.boxArtUrl,
                        placeholder: (context, url) => const SkeletonLoader(
                          borderRadius: kCardBorderRadius,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              category.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${NumberFormat.compact().format(viewers)} '
              '${viewers == 1 ? 'viewer' : 'viewers'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
