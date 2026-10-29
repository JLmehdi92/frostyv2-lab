import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/home/followed_videos/stores/followed_videos_store.dart';
import 'package:frosty/screens/home/stream_list/stream_card_parts.dart';
import 'package:frosty/screens/home/stream_list/streams_list.dart';
import 'package:frosty/screens/vod/vod_screen.dart';
import 'package:frosty/screens/vod/vod_watch_progress.dart';
import 'package:frosty/screens/vod/widgets/video_card_layout.dart';
import 'package:frosty/screens/vod/widgets/video_glyph.dart';
import 'package:frosty/screens/vod/widgets/video_kit.dart';
import 'package:frosty/screens/vod/widgets/vod_card.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/widgets/adaptive_sliver_list.dart';
import 'package:frosty/widgets/alert_message.dart';
import 'package:frosty/widgets/motion/press_scale.dart';
import 'package:frosty/widgets/motion/staggered_entrance.dart';

/// The day sections of the followed videos, newest first (an approved
/// addition to board VideosSuivies).
enum FollowedVideosSection {
  today('Today'),
  yesterday('Yesterday'),
  thisWeek('This week'),
  older('Older');

  const FollowedVideosSection(this.label);

  final String label;

  /// Where a video made at [createdAt] goes, seen at [now] (both local).
  static FollowedVideosSection of(DateTime createdAt, DateTime now) {
    final local = createdAt.toLocal();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    // Calendar days, not 24 h periods (a summer-time change is 23 or
    // 25 h); a video dated after now counts as today.
    final days = (startOfToday.difference(day).inHours / 24).round();
    if (days <= 0) return FollowedVideosSection.today;
    if (days == 1) return FollowedVideosSection.yesterday;
    if (days < 7) return FollowedVideosSection.thisWeek;
    return FollowedVideosSection.older;
  }
}

/// [videos] in their day sections, in the order given (newest first), the
/// empty sections left out.
List<(FollowedVideosSection, List<Vod>)> groupFollowedVideos(
  List<Vod> videos,
  DateTime now,
) {
  final sections = <FollowedVideosSection, List<Vod>>{};
  for (final vod in videos) {
    sections
        .putIfAbsent(
          FollowedVideosSection.of(vod.createdAt, now.toLocal()),
          () => [],
        )
        .add(vod);
  }
  return [
    for (final section in FollowedVideosSection.values)
      if (sections[section] case final list?) (section, list),
  ];
}

/// The newest videos of the channels the viewer follows (boards
/// VideosSuivies, VideosSuiviesTablette): rows on a phone, a grid of tiles
/// on a tablet, in Today / Yesterday / This week / Older sections, with the
/// viewer's progress.
class FollowedVideosScreen extends StatefulWidget {
  const FollowedVideosScreen({super.key, required this.store});

  static const routeName = '/followed-videos';

  final FollowedVideosStore store;

  /// Opens the list for the logged-in viewer [userId].
  static Future<void> open(BuildContext context, {required String userId}) =>
      Navigator.of(context).push(
        MaterialPageRoute(
          settings: const RouteSettings(name: routeName),
          builder: (context) => FollowedVideosScreen(
            store: FollowedVideosStore(
              twitchApi: context.twitchApi,
              vodService: context.twitchVodService,
              userId: userId,
            ),
          ),
        ),
      );

  @override
  State<FollowedVideosScreen> createState() => _FollowedVideosScreenState();
}

class _FollowedVideosScreenState extends State<FollowedVideosScreen>
    with VodWatchProgressMixin {
  @override
  String? get watchProgressViewer => widget.store.vodService.viewerId?.call();

  @override
  void initState() {
    super.initState();
    unawaited(widget.store.load());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tablet = context.isLargeScreen;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value:
          theme.appBarTheme.systemOverlayStyle ??
          (theme.brightness == Brightness.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(tablet: tablet),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: Observer(builder: (context) => _body(context, tablet)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, bool tablet) {
    final store = widget.store;
    final videos = store.videos;
    final error = store.error;

    Widget grid(int count, NullableIndexedWidgetBuilder builder) =>
        AdaptiveSliverList.videos(
          tiles: tablet,
          itemCount: count,
          itemBuilder: builder,
        );

    if (videos.isEmpty) {
      if (store.loading) {
        return CustomScrollView(
          physics: const NeverScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 4)),
            grid(
              tablet ? 8 : 6,
              (context, _) =>
                  tablet ? const VideoTileSkeleton() : const VideoRowSkeleton(),
            ),
          ],
        );
      }
      return RefreshIndicator.adaptive(
        onRefresh: store.load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: error != null
                  ? FeedStatusView.error(message: error, onRetry: store.load)
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 16,
                        children: [
                          const VideoListEmpty(message: 'No recent videos'),
                          _RefreshPill(onPressed: store.load),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      );
    }

    final sections = groupFollowedVideos(videos, DateTime.now());
    final insets = MediaQuery.paddingOf(context);
    final side = tablet
        ? FrostySpacing.gutterTablet
        : FrostySpacing.gutterPhone;
    // Where each section's cards start in the one cascade of the page.
    final starts = <int>[];
    var count = 0;
    for (final (_, list) in sections) {
      starts.add(count);
      count += list.length;
    }
    return RefreshIndicator.adaptive(
      onRefresh: store.load,
      child: StaggerScope(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    side + insets.left,
                    12,
                    side + insets.right,
                    0,
                  ),
                  child: AlertMessage(message: error),
                ),
              ),
            for (final (n, (section, list)) in sections.indexed) ...[
              SliverToBoxAdapter(
                child: VideoSectionLabel(
                  section.label,
                  padding: EdgeInsets.fromLTRB(
                    side + insets.left,
                    tablet ? 14 : 16,
                    side + insets.right,
                    tablet ? 0 : 6,
                  ),
                ),
              ),
              grid(list.length, (context, i) {
                final vod = list[i];
                final progress = watchProgress.of(vod);
                return StaggeredEntrance(
                  index: starts[n] + i,
                  child: VodCard(
                    vod: vod,
                    tile: tablet,
                    showChannel: true,
                    channelAvatar: true,
                    progress: progress.progress,
                    watched: progress.watched,
                    onTap: () => unawaited(
                      VodScreen.open(context, vodId: vod.id, vod: vod),
                    ),
                  ),
                );
              }),
            ],
            SliverPadding(padding: EdgeInsets.only(bottom: insets.bottom + 24)),
          ],
        ),
      ),
    );
  }
}

/// The page's top (board VideosSuivies: 56 dp, the back chevron and the
/// title; VideosSuiviesTablette: 88 dp, the back disc, the title and what
/// the list is).
class _Header extends StatelessWidget {
  const _Header({required this.tablet});

  final bool tablet;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final padding = MediaQuery.paddingOf(context);
    final back = Tooltip(
      message: 'Back',
      child: PressScale(
        child: Material(
          color: tablet ? colors.surface : Colors.transparent,
          shape: CircleBorder(
            side: tablet
                ? BorderSide(
                    color: colors.pillBorder,
                    width: FrostyTokens.hairlineWidth,
                  )
                : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.maybePop(context),
            child: SizedBox.square(
              dimension: 44,
              child: Center(
                child: VideoGlyph(
                  VideoGlyphKind.back,
                  color: colors.text,
                  size: 22,
                  strokeWidth: 2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final title = Text(
      'Followed videos',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: FrostyTokens.displayFamily,
        fontSize: tablet ? 24 : 18,
        fontWeight: FontWeight.w700,
        letterSpacing: tablet ? -0.48 : -0.27,
        height: 1.2,
        color: colors.text,
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colors.hairline,
            width: FrostyTokens.hairlineWidth,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          top: padding.top,
          left: padding.left + (tablet ? 20 : 4),
          right: padding.right + (tablet ? 28 : 8),
        ),
        child: SizedBox(
          height: tablet ? 88 : 56,
          child: Row(
            spacing: tablet ? 14 : 4,
            children: [
              back,
              Expanded(
                child: Semantics(
                  header: true,
                  child: tablet
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 2,
                          children: [
                            title,
                            Text(
                              'The newest videos of the channels you follow',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: FrostyTokens.bodyFamily,
                                fontSize: 13,
                                color: colors.secondary,
                              ),
                            ),
                          ],
                        )
                      : title,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Refresh" under the empty list (pulling down works too).
class _RefreshPill extends StatelessWidget {
  const _RefreshPill({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: colors.text,
        backgroundColor: colors.raised,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: StadiumBorder(
          side: BorderSide(
            color: colors.pillBorder,
            width: FrostyTokens.hairlineWidth,
          ),
        ),
        textStyle: const TextStyle(
          fontFamily: FrostyTokens.bodyFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      icon: const Icon(Icons.refresh_rounded, size: 17),
      label: const Text('Refresh'),
    );
  }
}
