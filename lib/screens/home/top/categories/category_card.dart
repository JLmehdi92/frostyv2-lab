import 'package:flutter/material.dart';
import 'package:frosty/models/category.dart';
import 'package:frosty/screens/home/stream_list/stream_card_parts.dart';
import 'package:frosty/screens/home/top/categories/category_streams.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/utils/image_size.dart';
import 'package:frosty/widgets/frosty_cached_network_image.dart';
import 'package:frosty/widgets/motion/motion.dart';
import 'package:frosty/widgets/motion/press_scale.dart';
import 'package:frosty/widgets/motion/reduce_motion.dart';
import 'package:frosty/widgets/skeleton_loader.dart';

/// [boxArtUrl] at [width] device pixels wide (3:4). Helix gives either a
/// template (`{width}x{height}`) or a sized URL (`-285x380.jpg`).
String categoryArtUrl(String boxArtUrl, int width) {
  final height = (width * 4 / 3).round();
  if (boxArtUrl.contains('{width}')) {
    return boxArtUrl
        .replaceFirst('{width}', '$width')
        .replaceFirst('{height}', '$height');
  }
  final dash = boxArtUrl.lastIndexOf('-');
  if (dash < 0) return boxArtUrl;
  return boxArtUrl.replaceRange(dash + 1, null, '${width}x$height.jpg');
}

/// The letters a box art without a picture shows ("Grand Theft Auto V" →
/// "GTAV", "Rocket League" → "RL"), at most four.
String categoryMonogram(String name) {
  final words = name
      .split(RegExp(r'[\s:\-–—_&]+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return '';
  if (words.length == 1) {
    return words.single.characters.take(3).toString().toUpperCase();
  }
  return words
      .take(4)
      .map((word) => word.characters.first.toUpperCase())
      .join();
}

/// The boards' dark washes behind a box art that cannot be shown.
const _washes = [
  [Color(0xFF4A3B24), Color(0xFF17120A)],
  [Color(0xFF1F3B5E), Color(0xFF0B1522)],
  [Color(0xFF5A2328), Color(0xFF1C0A0C)],
  [Color(0xFF2F4A27), Color(0xFF10190D)],
  [Color(0xFF3A3F48), Color(0xFF111317)],
  [Color(0xFF4A2A1E), Color(0xFF150B07)],
];

/// A category's box art (3:4) with its inner hairline; while it loads, the
/// skeleton; when it cannot be had, a dark wash with the category's
/// letters (boards Parcourir, Recherche).
class CategoryArt extends StatelessWidget {
  const CategoryArt({
    super.key,
    required this.category,
    required this.width,
    this.radius = 12,
    this.monogramSize = 22,
  });

  final CategoryTwitch category;

  /// The width it is drawn at (the picture is asked for at that size).
  final double width;
  final double radius;
  final double monogramSize;

  @override
  Widget build(BuildContext context) {
    final pixels = imagePixelWidth(
      width,
      MediaQuery.devicePixelRatioOf(context),
    );
    final borderRadius = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: borderRadius,
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: ColoredBox(
          color: FeedColors.of(context).well,
          child: Stack(
            fit: StackFit.expand,
            children: [
              FrostyCachedNetworkImage(
                imageUrl: categoryArtUrl(category.boxArtUrl, pixels),
                memCacheWidth: pixels,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    SkeletonLoader(borderRadius: borderRadius),
                errorWidget: (context, url, error) => _Monogram(
                  name: category.name,
                  seed: category.id,
                  fontSize: monogramSize,
                ),
              ),
              InsetHairline(borderRadius: borderRadius),
            ],
          ),
        ),
      ),
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({
    required this.name,
    required this.seed,
    required this.fontSize,
  });

  final String name;
  final String seed;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final wash = _washes[seed.hashCode.abs() % _washes.length];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(-0.4, -1),
          end: const Alignment(0.4, 1),
          colors: wash,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.7, -1),
                radius: 1.2,
                colors: [Color(0x1AFFFFFF), Color(0x00FFFFFF)],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(fontSize * 0.45),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                categoryMonogram(name),
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  fontFamily: FrostyTokens.displayFamily,
                  fontSize: fontSize,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.04 * fontSize,
                  color: const Color(0xD1FFFFFF),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A category in a grid (boards Parcourir, ParcourirTablette): the box art
/// and the name under it on up to two lines. [selected] rings it in the
/// signal colour (the tablet's category beside its streams).
class CategoryTile extends StatelessWidget {
  const CategoryTile({
    super.key,
    required this.category,
    required this.onTap,
    this.selected = false,
    this.nameSize = 13,
    this.monogramSize = 22,
  });

  final CategoryTwitch category;
  final VoidCallback onTap;
  final bool selected;
  final double nameSize;
  final double monogramSize;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final ground = Theme.of(context).scaffoldBackgroundColor;
    final accent = context.frostyColors.live;
    final duration = motionDuration(context, const Duration(milliseconds: 240));
    return Semantics(
      button: true,
      selected: selected,
      label: category.name,
      onTap: onTap,
      excludeSemantics: true,
      child: PressScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              LayoutBuilder(
                builder: (context, constraints) => AnimatedContainer(
                  duration: duration,
                  curve: FrostyMotion.standard,
                  // The ring is drawn outside the art (2 dp of ground, then
                  // 2 dp of signal), so nothing moves when it shows.
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: selected ? accent : accent.withValues(alpha: 0),
                        spreadRadius: selected ? 4 : 0,
                      ),
                      BoxShadow(
                        color: selected ? ground : ground.withValues(alpha: 0),
                        spreadRadius: selected ? 2 : 0,
                      ),
                    ],
                  ),
                  child: CategoryArt(
                    category: category,
                    width: constraints.maxWidth,
                    monogramSize: monogramSize,
                  ),
                ),
              ),
              Text(
                category.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: nameSize,
                  height: 1.3,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected || nameSize > 13 ? colors.text : colors.body,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A [CategoryTile], loading.
class CategoryTileSkeleton extends StatelessWidget {
  const CategoryTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        AspectRatio(
          aspectRatio: 3 / 4,
          child: SkeletonLoader(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        SkeletonLoader(
          height: 12,
          width: 72,
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
      ],
    );
  }
}

/// A category in a list (board Recherche): its box art (45 × 60), its name
/// and a chevron; a tap opens its page.
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
    final colors = FeedColors.of(context);
    final padding = MediaQuery.paddingOf(context);
    // The card sinks as soon as the finger is down (design system press).
    return PressScale(
      enabled: isTappable,
      child: InkWell(
        onTap: isTappable
            ? () => CategoryStreams.open(context, category.id)
            : null,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            FrostySpacing.gutterPhone + padding.left,
            6,
            FrostySpacing.gutterPhone + padding.right,
            6,
          ),
          child: Row(
            spacing: 14,
            children: [
              SizedBox(
                width: 45,
                child: CategoryArt(
                  category: category,
                  width: 45,
                  radius: 8,
                  monogramSize: 11,
                ),
              ),
              Expanded(
                child: Text(
                  category.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
              ),
              if (isTappable)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: colors.tertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A [CategoryCard], loading.
class CategoryCardSkeleton extends StatelessWidget {
  const CategoryCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        FrostySpacing.gutterPhone + padding.left,
        6,
        FrostySpacing.gutterPhone + padding.right,
        6,
      ),
      child: const Row(
        spacing: 14,
        children: [
          SkeletonLoader(
            width: 45,
            height: 60,
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          SkeletonLoader(
            width: 140,
            height: 14,
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
        ],
      ),
    );
  }
}
