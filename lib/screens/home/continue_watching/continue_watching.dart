import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/screens/home/continue_watching/stores/continue_watching_store.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/screens/vod/vod_screen.dart';
import 'package:onset/screens/vod/widgets/vod_card.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/frosty_cached_network_image.dart';
import 'package:onset/widgets/motion/press_scale.dart';
import 'package:onset/widgets/profile_picture.dart';
import 'package:onset/widgets/skeleton_loader.dart';

/// "2:31:04" (or "31:04" under an hour).
String formatResumeTime(int seconds) {
  final d = Duration(seconds: seconds < 0 ? 0 : seconds);
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(h > 0 ? 2 : 1, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

/// When a position was saved, as the shelf words it ("today", "yesterday",
/// "3 days ago"); null when unknown.
String? savedWhen(DateTime? at, {DateTime? now}) {
  if (at == null) return null;
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final day = DateUtils.dateOnly(at.toLocal());
  final days = today.difference(day).inDays;
  if (days <= 0) return 'today';
  if (days == 1) return 'yesterday';
  if (days < 7) return '$days days ago';
  if (days < 30) return '${days ~/ 7} wk ago';
  return '${days ~/ 30} mo ago';
}

/// The second line of an item: the channel and when it was left.
String _subtitle(ContinueWatchingItem item) {
  final owner = item.vod.ownerDisplayName.isNotEmpty
      ? item.vod.ownerDisplayName
      : item.vod.ownerLogin;
  final when = savedWhen(item.updatedAt);
  return [if (owner.isNotEmpty) owner, ?when].join(' · ');
}

void _open(BuildContext context, ContinueWatchingItem item) =>
    unawaited(VodScreen.open(context, vodId: item.vod.id, vod: item.vod));

/// The title row of the shelf: "Continue watching" and "See all".
class _ShelfHeader extends StatelessWidget {
  const _ShelfHeader({required this.store});

  final ContinueWatchingStore store;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    return Row(
      children: [
        const Expanded(child: FeedSectionTitle('Continue watching')),
        TextButton(
          onPressed: () => ContinueWatchingScreen.open(context, store),
          style: TextButton.styleFrom(
            foregroundColor: colors.secondary,
            minimumSize: const Size(44, 36),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          child: const Text('See all'),
        ),
      ],
    );
  }
}

/// The thumbnail of an item with its progress bar (board: 3 px, signal over
/// white 18 %) and, [resumeLabel], "Resume at 2:31:04".
class _ResumeThumbnail extends StatelessWidget {
  const _ResumeThumbnail({
    required this.item,
    required this.radius,
    this.resumeLabel = false,
  });

  final ContinueWatchingItem item;
  final double radius;
  final bool resumeLabel;

  @override
  Widget build(BuildContext context) {
    final url = item.vod.previewThumbnailUrl;
    final borderRadius = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: borderRadius,
      child: ColoredBox(
        color: FeedColors.of(context).well,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url != null && url.isNotEmpty)
              FrostyCachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    SkeletonLoader(borderRadius: borderRadius),
              ),
            if (resumeLabel) ...[
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0x8C000000)],
                    stops: [0.55, 1],
                  ),
                ),
              ),
              PositionedDirectional(
                start: 8,
                bottom: 11,
                child: OverlayPill(
                  height: 22,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 5,
                    children: [
                      const Icon(
                        Icons.play_arrow_rounded,
                        size: 12,
                        color: OverImage.text,
                      ),
                      Text(
                        'Resume at ${formatResumeTime(item.positionSec)}',
                        style: FrostyType.tabular(
                          const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: OverImage.text,
                            height: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            InsetHairline(borderRadius: borderRadius),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 3,
              child: ColoredBox(
                color: const Color(0x2EFFFFFF),
                child: FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: item.progress,
                  child: ColoredBox(color: context.frostyColors.live),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Following's "Continue watching" on a phone (board Accueil): a row of
/// 244 dp cards, each the video with its progress, "Resume at …", the
/// channel's picture, title, channel and when it was left. Nothing when
/// there is nothing to resume.
class ContinueWatchingShelf extends StatelessWidget {
  const ContinueWatchingShelf({super.key, required this.store});

  final ContinueWatchingStore store;

  static const cardWidth = 244.0;
  static const thumbnailHeight = 137.0;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final items = store.items;
        if (items.isEmpty) return const SizedBox.shrink();
        final padding = MediaQuery.paddingOf(context);
        final colors = FeedColors.of(context);
        return Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              Padding(
                padding: EdgeInsets.only(
                  left: FrostySpacing.gutterPhone + padding.left,
                  right: 8 + padding.right,
                ),
                child: _ShelfHeader(store: store),
              ),
              SizedBox(
                height: thumbnailHeight + 9 + 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.only(
                    left: FrostySpacing.gutterPhone + padding.left,
                    right: FrostySpacing.gutterPhone + padding.right,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return SizedBox(
                      width: cardWidth,
                      child: PressScale(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _open(context, item),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 9,
                            children: [
                              SizedBox(
                                height: thumbnailHeight,
                                child: _ResumeThumbnail(
                                  item: item,
                                  radius: 14,
                                  resumeLabel: true,
                                ),
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                spacing: 9,
                                children: [
                                  if (item.vod.ownerLogin.isNotEmpty)
                                    ProfilePicture(
                                      userLogin: item.vod.ownerLogin,
                                      radius: 13,
                                    ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      spacing: 2,
                                      children: [
                                        Text(
                                          item.vod.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: colors.text,
                                          ),
                                        ),
                                        Text(
                                          _subtitle(item),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colors.secondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Following's "Continue watching" beside the tablet's hero (board
/// TabletteAccueil): the latest [rows] videos as 210 x 118 rows with
/// "Resume at … · channel".
class ContinueWatchingColumn extends StatelessWidget {
  const ContinueWatchingColumn({super.key, required this.store, this.rows = 2});

  final ContinueWatchingStore store;
  final int rows;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final items = store.items.take(rows).toList();
        if (items.isEmpty) return const SizedBox.shrink();
        final colors = FeedColors.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: 14,
          children: [
            _ShelfHeader(store: store),
            for (final item in items)
              PressScale(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _open(context, item),
                  child: Row(
                    spacing: 14,
                    children: [
                      SizedBox(
                        width: 210,
                        height: 118,
                        child: _ResumeThumbnail(item: item, radius: 14),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 4,
                          children: [
                            Text(
                              item.vod.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: colors.text,
                              ),
                            ),
                            Text(
                              'Resume at ${formatResumeTime(item.positionSec)}'
                              ' · ${_subtitle(item)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: FrostyType.tabular(
                                TextStyle(
                                  fontSize: 13,
                                  color: colors.secondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Every video of the shelf ("See all"), with its progress.
class ContinueWatchingScreen extends StatelessWidget {
  const ContinueWatchingScreen({super.key, required this.store});

  static const routeName = '/continue-watching';

  final ContinueWatchingStore store;

  static Future<void> open(BuildContext context, ContinueWatchingStore store) =>
      Navigator.of(context).push(
        MaterialPageRoute(
          settings: const RouteSettings(name: routeName),
          builder: (context) => ContinueWatchingScreen(store: store),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Continue watching')),
      body: RefreshIndicator.adaptive(
        onRefresh: store.load,
        child: Observer(
          builder: (context) {
            final items = store.items;
            if (items.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Text(
                      'Nothing to resume',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: FeedColors.of(context).secondary,
                      ),
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom + 8,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return VodCard(
                  vod: item.vod,
                  showChannel: true,
                  progress: item.progress,
                  onTap: () => _open(context, item),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// The shelf's skeleton (board Etats, "Chargement"): the title, then two
/// cards.
class ContinueWatchingSkeleton extends StatelessWidget {
  const ContinueWatchingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        FrostySpacing.gutterPhone + padding.left,
        6,
        0,
        20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 14,
        children: [
          const SkeletonLoader(width: 150, height: 16),
          SizedBox(
            height: ContinueWatchingShelf.thumbnailHeight + 36,
            child: ClipRect(
              child: OverflowBox(
                alignment: AlignmentDirectional.centerStart,
                maxWidth: double.infinity,
                child: Row(
                  spacing: 12,
                  children: [
                    for (var i = 0; i < 2; i++)
                      SizedBox(
                        width: ContinueWatchingShelf.cardWidth,
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 9,
                          children: [
                            SkeletonLoader(
                              height: ContinueWatchingShelf.thumbnailHeight,
                              borderRadius: BorderRadius.all(
                                Radius.circular(14),
                              ),
                            ),
                            Row(
                              spacing: 9,
                              children: [
                                SkeletonLoader(
                                  width: 26,
                                  height: 26,
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(13),
                                  ),
                                ),
                                SkeletonLoader(width: 160, height: 12),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
