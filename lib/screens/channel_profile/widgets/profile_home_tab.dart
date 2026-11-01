import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:intl/intl.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/channel_profile.dart';
import 'package:onset/models/clip.dart';
import 'package:onset/models/vod.dart';
import 'package:onset/screens/channel_profile/widgets/profile_live_card.dart';
import 'package:onset/screens/channel_profile/widgets/profile_parts.dart';
import 'package:onset/screens/channel_profile/widgets/profile_schedule_tab.dart';
import 'package:onset/screens/clips/clip_screen.dart';
import 'package:onset/screens/clips/stores/channel_clips_store.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/screens/vod/stores/channel_videos_store.dart';
import 'package:onset/screens/vod/vod_screen.dart';
import 'package:onset/screens/vod/vod_time.dart';
import 'package:onset/screens/vod/vod_watch_progress.dart';
import 'package:onset/screens/vod/widgets/vod_card.dart';
import 'package:onset/services/notifications/schedule_reminders.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/motion/press_scale.dart';
import 'package:onset/widgets/onset_cached_network_image.dart';
import 'package:onset/widgets/onset_photo_view_dialog.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';
import 'package:onset/widgets/skeleton_loader.dart';

/// How many videos and clips the Home tab previews on a phone (two rows of
/// two); a tablet shows two rows of its columns.
const kProfileHomePreviewCount = 4;

/// The columns of the Home tab's grids for a [width] wide pane.
int profileGridColumns(double width, {required bool large}) =>
    !large ? 2 : (width >= 640 ? 3 : 2);

/// A channel's profile Home: on a
/// tablet ([showStream]) the stream beside "Coming up", on a phone the
/// next stream (the stream is in the header there); then "Recent
/// broadcasts" and the week's "Popular clips", each with "See all".
class ProfileHomeContent extends StatefulWidget {
  const ProfileHomeContent({
    super.key,
    required this.login,
    required this.profile,
    required this.videos,
    required this.clips,
    required this.onOpenChannel,
    required this.onViewAllVideos,
    required this.onViewAllClips,
    this.channelName = '',
    this.onPreload,
    this.schedule,
    this.reminders,
    this.now,
    this.showStream = false,
    this.large = false,
    this.status,
  });

  final String login;
  final String channelName;
  final ChannelProfile? profile;
  final ChannelVideosStore videos;
  final ChannelClipsStore clips;
  final VoidCallback onOpenChannel;
  final VoidCallback? onPreload;
  final VoidCallback onViewAllVideos;
  final VoidCallback onViewAllClips;

  /// Null until read (or when it could not be).
  final ChannelSchedule? schedule;
  final ScheduleReminders? reminders;

  /// The clock (tests).
  final DateTime? now;

  /// The stream card (a tablet's Home).
  final bool showStream;
  final bool large;

  /// What went wrong loading the profile, above everything.
  final Widget? status;

  @override
  State<ProfileHomeContent> createState() => _ProfileHomeContentState();
}

class _ProfileHomeContentState extends State<ProfileHomeContent>
    with VodWatchProgressMixin {
  @override
  String? get watchProgressViewer => widget.videos.vodService.viewerId?.call();

  @override
  void initState() {
    super.initState();
    if (!widget.videos.loaded) unawaited(widget.videos.load());
    if (!widget.clips.loaded) unawaited(widget.clips.load());
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.now ?? DateTime.now();
    final large = widget.large;
    final schedule = widget.schedule;
    final coming = schedule == null
        ? const <ScheduleSegment>[]
        : comingUp(schedule, now).take(large ? 2 : 1).toList();
    final time = DateFormat.jm();

    Widget scheduleCard(ScheduleSegment segment, int index) =>
        ProfileScheduleCard(
          segment: segment,
          next: index == 0,
          meta: large
              ? [
                  time.format(segment.startAt.toLocal()),
                  ?segment.categoryName,
                ].join(' · ')
              : context.l10n.profileNextStreamAt(
                  time: time.format(segment.startAt.toLocal()),
                ),
          reminders: widget.reminders,
          login: widget.login,
          channelName: widget.channelName,
          large: large,
        );

    final profile = widget.profile;
    final streamCard =
        widget.showStream &&
            profile != null &&
            !ProfileStreamFacts(profile).isEmpty
        ? ProfileLiveCard(
            profile: profile,
            onOpen: widget.onOpenChannel,
            onPreload: widget.onPreload,
            large: large,
          )
        : null;

    Widget? top;
    if (large && (streamCard != null || coming.isNotEmpty)) {
      final upNext = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          ProfileEyebrow(context.l10n.profileComingUp),
          for (final (index, segment) in coming.indexed)
            scheduleCard(segment, index),
        ],
      );
      top = LayoutBuilder(
        builder: (context, constraints) {
          if (streamCard == null) return upNext;
          if (coming.isEmpty) {
            return Align(
              alignment: AlignmentDirectional.centerStart,
              child: SizedBox(width: 480, child: streamCard),
            );
          }
          // Side by side when the pane leaves the column 280 dp.
          if (constraints.maxWidth >= 480 + 18 + 280) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 18,
              children: [
                SizedBox(width: 480, child: streamCard),
                Expanded(child: upNext),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 20,
            children: [streamCard, upNext],
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.status case final status?)
          Padding(padding: const EdgeInsets.only(bottom: 14), child: status),
        if (top != null)
          Padding(padding: const EdgeInsets.only(bottom: 24), child: top)
        else ...[
          if (streamCard != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: streamCard,
            ),
          for (final (index, segment) in coming.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: scheduleCard(segment, index),
            ),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = profileGridColumns(
              constraints.maxWidth,
              large: large,
            );
            final count = large ? columns * 2 : kProfileHomePreviewCount;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Observer(
                  builder: (context) {
                    final store = widget.videos;
                    final loading = !store.loaded && store.isLoading;
                    final videos = store.videos.take(count).toList();
                    if (!loading && videos.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return _Section(
                      title: context.l10n.profileRecentBroadcasts,
                      onSeeAll: widget.onViewAllVideos,
                      large: large,
                      columns: columns,
                      tiles: loading
                          ? [
                              for (var i = 0; i < count; i++)
                                ProfileTileSkeleton(large: large),
                            ]
                          : [
                              for (final vod in videos)
                                ProfileVideoTile(
                                  vod: vod,
                                  progress: watchProgress.of(vod),
                                  large: large,
                                ),
                            ],
                    );
                  },
                ),
                Observer(
                  builder: (context) {
                    final store = widget.clips;
                    final loading = !store.loaded && store.isLoading;
                    final clips = store.clips.take(count).toList();
                    if (!loading && clips.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return _Section(
                      title: context.l10n.profilePopularClips,
                      onSeeAll: widget.onViewAllClips,
                      large: large,
                      columns: columns,
                      tiles: loading
                          ? [
                              for (var i = 0; i < count; i++)
                                ProfileTileSkeleton(large: large),
                            ]
                          : [
                              for (final clip in clips)
                                ProfileClipTile(clip: clip, large: large),
                            ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// A titled grid of tiles.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.onSeeAll,
    required this.large,
    required this.columns,
    required this.tiles,
  });

  final String title;
  final VoidCallback onSeeAll;
  final bool large;
  final int columns;
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    final gap = large ? 16.0 : 12.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          ProfileSectionTitle(title: title, onSeeAll: onSeeAll, large: large),
          LayoutBuilder(
            builder: (context, constraints) {
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: large ? 18 : 14,
                children: [
                  for (final tile in tiles) SizedBox(width: width, child: tile),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// A tile's picture (12 dp corners, 14 on a tablet): the image (or
/// a mark), chips in the top corner, the length bottom right and the
/// progress along the bottom. A long press enlarges it.
class _TilePicture extends StatelessWidget {
  const _TilePicture({
    required this.imageUrl,
    required this.fallback,
    required this.length,
    required this.large,
    this.chips = const [],
    this.progress,
  });

  final String? imageUrl;
  final SheetGlyphKind fallback;
  final String length;
  final bool large;
  final List<Widget> chips;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final radius = BorderRadius.circular(large ? 14 : 12);
    final url = imageUrl;
    final progress = this.progress;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: radius,
        child: ColoredBox(
          color: colors.well,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (url == null)
                Center(
                  child: SheetGlyph(fallback, size: 22, color: colors.tertiary),
                )
              else
                Semantics(
                  image: true,
                  label: context.l10n.profileThumbnail,
                  onLongPressHint: context.l10n.streamEnlargeHint,
                  child: GestureDetector(
                    onLongPress: () {
                      HapticFeedback.lightImpact();
                      showDialog<void>(
                        context: context,
                        builder: (context) =>
                            OnsetPhotoViewDialog(imageUrl: url),
                      );
                    },
                    child: LayoutBuilder(
                      builder: (context, constraints) =>
                          OnsetCachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            memCacheWidth: (constraints.maxWidth * pixelRatio)
                                .ceil(),
                            placeholder: (context, _) =>
                                SkeletonLoader(borderRadius: radius),
                          ),
                    ),
                  ),
                ),
              if (chips.isNotEmpty)
                PositionedDirectional(
                  start: 6,
                  top: 6,
                  child: Row(spacing: 4, children: chips),
                ),
              PositionedDirectional(
                end: large ? 8 : 6,
                bottom: large ? 10 : 8,
                child: _TileChip(text: length, large: large),
              ),
              if (progress != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 3,
                  child: ColoredBox(
                    color: Colors.white.withValues(alpha: large ? 0.18 : 0.16),
                    child: FractionallySizedBox(
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: progress.clamp(0.0, 1.0),
                      child: ColoredBox(color: context.onsetColors.live),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A dark chip over a tile's picture (the length, "Watched", the views).
class _TileChip extends StatelessWidget {
  const _TileChip({this.text, this.child, required this.large, this.color});

  final String? text;
  final Widget? child;
  final bool large;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return OverlayPill(
      height: large ? 22 : 20,
      radius: large ? 6 : 5,
      padding: large ? 7 : 6,
      color:
          color ?? (large ? const Color(0xBF0A0A0A) : const Color(0xA6000000)),
      child:
          child ??
          Text(
            text ?? '',
            style: OnsetType.tabular(
              const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: OverImage.text,
              ),
            ),
          ),
    );
  }
}

/// The text under a tile: the title (2 lines), then its details.
class _TileText extends StatelessWidget {
  const _TileText({required this.title, this.details, required this.large});

  final String title;
  final String? details;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: large ? 14 : 13,
            fontWeight: FontWeight.w600,
            height: 1.3,
            color: colors.text,
          ),
        ),
        if (details case final details?)
          Text(
            details,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: OnsetType.tabular(
              TextStyle(fontSize: 12, height: 1.3, color: colors.secondary),
            ),
          ),
      ],
    );
  }
}

/// A past broadcast in the Home grid ("Recent broadcasts"): its
/// picture with the length and the viewer's progress, its title, age and
/// views. A tap plays it in-app.
class ProfileVideoTile extends StatelessWidget {
  const ProfileVideoTile({
    super.key,
    required this.vod,
    this.progress = (progress: null, watched: false),
    this.large = false,
  });

  final Vod vod;
  final VodProgress progress;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final title = vod.title.trim().isEmpty ? l.videoUntitled : vod.title.trim();
    final details = [
      formatTimeAgo(vod.createdAt, l),
      l.videoViewsShort(
        count: vod.viewCount,
        views: formatViewers(vod.viewCount),
      ),
    ].join(' · ');
    return Semantics(
      button: true,
      label: '$title, ${formatVodTime(vod.duration)}, $details',
      child: PressScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () =>
              unawaited(VodScreen.open(context, vodId: vod.id, vod: vod)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: large ? 8 : 6,
            children: [
              _TilePicture(
                imageUrl: vodThumbnailUrl(vod),
                fallback: SheetGlyphKind.videos,
                length: formatVodTime(vod.duration),
                large: large,
                progress: progress.progress,
                chips: [
                  if (vod.isRecording)
                    _TileChip(
                      text: l.profileRecording,
                      large: large,
                      color: OnsetTokens.danger.withValues(alpha: 0.9),
                    ),
                  if (progress.watched)
                    _TileChip(text: l.profileWatched, large: large),
                  if (vod.isRestricted)
                    _TileChip(
                      large: large,
                      child: const SheetGlyph(
                        SheetGlyphKind.lock,
                        size: 12,
                        color: OverImage.text,
                      ),
                    ),
                ],
              ),
              ExcludeSemantics(
                child: _TileText(
                  title: title,
                  details: vod.isRestricted
                      ? '${l.profileSubscribersOnly} · $details'
                      : details,
                  large: large,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A clip in the Home grid: its picture with the views and length, its
/// title, age and clipper. A tap plays it in-app.
class ProfileClipTile extends StatelessWidget {
  const ProfileClipTile({super.key, required this.clip, this.large = false});

  final Clip clip;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final title = clip.title.trim().isEmpty
        ? l.clipUntitled
        : clip.title.trim();
    final views = l.videoViewsShort(
      count: clip.viewCount,
      views: formatViewers(clip.viewCount),
    );
    final curator = clip.curatorDisplayName;
    final details = [
      formatTimeAgo(clip.createdAt, l),
      if (curator != null) l.clipClippedBy(curator: curator),
    ].join(' · ');
    return Semantics(
      button: true,
      label: '$title, $views, $details',
      child: PressScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () =>
              unawaited(ClipScreen.open(context, slug: clip.slug, clip: clip)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: large ? 8 : 6,
            children: [
              _TilePicture(
                imageUrl: clip.thumbnailUrl,
                fallback: SheetGlyphKind.videos,
                length: formatVodTime(clip.duration),
                large: large,
                chips: [_TileChip(text: views, large: large)],
              ),
              ExcludeSemantics(
                child: _TileText(title: title, details: details, large: large),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A tile loading: the picture and two lines, under the global sheen.
class ProfileTileSkeleton extends StatelessWidget {
  const ProfileTileSkeleton({super.key, this.large = false});

  final bool large;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(large ? 14 : 12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: SkeletonLoader(borderRadius: radius),
        ),
        const SkeletonLoader(width: 140, height: 12),
        const SkeletonLoader(width: 90, height: 10),
      ],
    );
  }
}
