import 'package:flutter/material.dart';
import 'package:frosty/constants.dart';
import 'package:frosty/models/category.dart';
import 'package:frosty/screens/home/top/categories/category_streams.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/widgets/frosty_cached_network_image.dart';
import 'package:frosty/widgets/skeleton_loader.dart';

/// A tappable card widget that displays a category's box art and name under.
class CategoryCard extends StatelessWidget {
  final CategoryTwitch category;
  final bool isTappable;

  const CategoryCard({
    super.key,
    required this.category,
    this.isTappable = true,
  });

  @override
  Widget build(BuildContext context) {
    // The box art is drawn 80 dp wide.
    final artWidth = (80 * MediaQuery.devicePixelRatioOf(context)).ceil();
    final artHeight = (artWidth * (4 / 3)).toInt();

    return InkWell(
      onTap: isTappable
          ? () => Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: CategoryStreams.routeName),
                builder: (context) => CategoryStreams(categoryId: category.id),
              ),
            )
          : null,
      child: Padding(
        padding: EdgeInsets.only(
          top: 8,
          bottom: 8,
          left: 16 + MediaQuery.of(context).padding.left,
          right: 16 + MediaQuery.of(context).padding.right,
        ),
        child: Row(
          spacing: 16,
          children: [
            SizedBox(
              width: 80,
              child: ClipRRect(
                borderRadius: kCardBorderRadius,
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: FrostyCachedNetworkImage(
                    imageUrl: category.boxArtUrl.replaceRange(
                      category.boxArtUrl.lastIndexOf('-') + 1,
                      null,
                      '${artWidth}x$artHeight.jpg',
                    ),
                    placeholder: (context, url) =>
                        const SkeletonLoader(borderRadius: kCardBorderRadius),
                  ),
                ),
              ),
            ),
            Flexible(
              child: Text(
                category.name.toUpperCase(),
                style: context.frostyText.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
