import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:onset/models/channel_profile.dart';
import 'package:onset/screens/channel/channel_info.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/screens/vod/vod_time.dart';
import 'package:onset/services/shared_timer_service.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/utils/image_size.dart';
import 'package:onset/widgets/motion/press_scale.dart';
import 'package:onset/widgets/onset_cached_network_image.dart';
import 'package:onset/widgets/onset_photo_view_dialog.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';
import 'package:onset/widgets/skeleton_loader.dart';

/// What the profile's stream card shows: live, a rerun, or the offline
/// image with the last broadcast.
class ProfileStreamFacts {
  ProfileStreamFacts(this.profile);

  final ChannelProfile profile;

  LiveStatus? get live => profile.live;

  /// Twitch's last broadcast is the live one while live (same id).
  String? get title {
    final title = profile.lastBroadcast?.title?.trim();
    return title == null || title.isEmpty ? null : title;
  }

  String? get category => live?.gameName ?? profile.lastBroadcast?.gameName;

  /// The live preview, at [width] pixels and refreshed every five
  /// minutes (like the stream cards), or the offline image.
  ({String url, String? cacheKey})? image(int width, DateTime now) {
    if (live == null) {
      final offline = profile.offlineImageUrl;
      return offline == null ? null : (url: offline, cacheKey: null);
    }
    final height = math.min(width * 9 ~/ 16, 1080);
    final url =
        'https://static-cdn.jtvnw.net/previews-ttv/live_user_'
        '${profile.login.toLowerCase()}-${width}x$height.jpg';
    return (
      url: url,
      cacheKey: '$url-${now.day}-${now.hour}-${now.minute ~/ 5}',
    );
  }

  /// "963 watching · 4 h 02" (with [withCategory], the category first),
  /// "Rerun · …", or "Last live 2 days ago · Chess".
  String details(DateTime now, {bool withCategory = false}) {
    final live = this.live;
    if (live == null) {
      final started = profile.lastBroadcast?.startedAt;
      return [
        if (started != null)
          'Last live ${formatTimeAgo(started, now: now).toLowerCase()}',
        ?profile.lastBroadcast?.gameName,
      ].join(' · ');
    }
    final started = live.startedAt;
    return [
      if (withCategory) ?category,
      if (live.isRerun) 'Rerun',
      '${formatViewers(live.viewers)} watching',
      if (started != null) shortUptime(now.difference(started)),
    ].join(' · ');
  }

  /// Nothing worth a card: offline, without an image or a title.
  bool get isEmpty =>
      live == null && image(0, DateTime(0)) == null && title == null;
}

/// The channel's stream on its profile. On a phone a row:
/// the 112 × 63 picture with its "LIVE" badge, the title, viewers and
/// uptime, and a chevron. On a tablet ([large]) the
/// 16:9 picture with the badge, the title and details over a dark fade.
///
/// A tap opens the channel; while live, the finger going down asks for
/// its playback token first ([onPreload]), like the stream cards.
class ProfileLiveCard extends StatelessWidget {
  const ProfileLiveCard({
    super.key,
    required this.profile,
    required this.onOpen,
    this.onPreload,
    this.large = false,
  });

  final ChannelProfile profile;
  final VoidCallback onOpen;
  final VoidCallback? onPreload;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final facts = ProfileStreamFacts(profile);
    final live = facts.live;
    // Read with the text, so both follow the clock.
    Widget card(BuildContext context) => Semantics(
      button: true,
      label: [
        if (live == null) 'Offline' else if (live.isRerun) 'Rerun' else 'Live',
        ?facts.title,
        facts.details(DateTime.now(), withCategory: true),
      ].join(', '),
      onTap: onOpen,
      excludeSemantics: true,
      child: large ? _large(context, facts) : _row(context, facts),
    );
    return PressScale(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: live == null || onPreload == null
            ? null
            : (_) => onPreload!(),
        onTap: onOpen,
        // The uptime moves once a minute.
        child: live?.startedAt == null
            ? Builder(builder: card)
            : _MinuteClock(builder: card),
      ),
    );
  }

  Widget _picture(
    BuildContext context,
    ProfileStreamFacts facts, {
    required BorderRadius radius,
  }) {
    final colors = FeedColors.of(context);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return ClipRRect(
      borderRadius: radius,
      child: ColoredBox(
        color: large ? Colors.black : colors.well,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = imagePixelWidth(constraints.maxWidth, pixelRatio);
            final image = facts.image(width, DateTime.now());
            if (image == null) {
              return Center(
                child: SheetGlyph(
                  SheetGlyphKind.videos,
                  size: large ? 32 : 22,
                  color: large ? OverImage.secondary : colors.tertiary,
                ),
              );
            }
            return GestureDetector(
              // A long press enlarges the picture, like the stream cards.
              onLongPress: () => showDialog<void>(
                context: context,
                builder: (context) => OnsetPhotoViewDialog(
                  imageUrl: image.url,
                  cacheKey: image.cacheKey,
                ),
              ),
              child: OnsetCachedNetworkImage(
                imageUrl: image.url,
                cacheKey: image.cacheKey,
                memCacheWidth: width,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                useOldImageOnUrlChange: true,
                placeholder: (context, _) =>
                    SkeletonLoader(borderRadius: radius),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _badge(BuildContext context, LiveStatus? live, {required bool large}) {
    if (live == null) return const SizedBox.shrink();
    if (!live.isRerun) {
      if (large) return const LiveBadge();
      // The phone's small badge: 18 high, 10 sp, no ping.
      return Container(
        height: 18,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.onsetColors.live,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          'LIVE',
          style: OnsetType.badge.copyWith(
            fontSize: 10,
            letterSpacing: 0.6,
            height: 1,
            color: OnsetTokens.backgroundDark,
          ),
        ),
      );
    }
    return OverlayPill(
      height: large ? 24 : 18,
      radius: large ? 6 : 5,
      padding: large ? 8 : 6,
      color: OverImage.pillStrong,
      child: Text(
        'RERUN',
        style: OnsetType.badge.copyWith(
          fontSize: large ? 11 : 10,
          letterSpacing: 0.6,
          height: 1,
          color: OverImage.text,
        ),
      ),
    );
  }

  Widget _row(BuildContext context, ProfileStreamFacts facts) {
    final colors = FeedColors.of(context);
    final now = DateTime.now();
    final details = facts.details(now);
    final title = facts.title ?? (facts.live == null ? 'Offline' : 'Live now');
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.hairline,
          width: OnsetTokens.hairlineWidth,
        ),
      ),
      child: Row(
        spacing: 12,
        children: [
          SizedBox(
            width: 112,
            height: 63,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _picture(context, facts, radius: BorderRadius.circular(10)),
                PositionedDirectional(
                  start: 6,
                  top: 6,
                  child: _badge(context, facts.live, large: false),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: 3,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: colors.text,
                  ),
                ),
                if (details.isNotEmpty)
                  Text(
                    details,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OnsetType.tabular(
                      TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: colors.secondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SheetGlyph(
            SheetGlyphKind.chevronRight,
            size: 18,
            strokeWidth: 2,
            color: colors.secondary,
          ),
        ],
      ),
    );
  }

  Widget _large(BuildContext context, ProfileStreamFacts facts) {
    final now = DateTime.now();
    final details = facts.details(now, withCategory: true);
    final title = facts.title ?? (facts.live == null ? 'Offline' : 'Live now');
    const radius = BorderRadius.all(Radius.circular(18));
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _picture(context, facts, radius: radius),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.45, 1],
                  colors: [Color(0x00000000), Color(0xE0000000)],
                ),
              ),
            ),
          ),
          PositionedDirectional(
            start: 14,
            top: 14,
            child: _badge(context, facts.live, large: true),
          ),
          PositionedDirectional(
            start: 16,
            end: 16,
            bottom: 14,
            child: IgnorePointer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: 3,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      color: OverImage.text,
                    ),
                  ),
                  if (details.isNotEmpty)
                    Text(
                      details,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: OnsetType.tabular(
                        const TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          color: OverImage.body,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rebuilds [builder] when the minute changes (the shared clock ticks every
/// second; the uptime moves once a minute).
class _MinuteClock extends StatefulWidget {
  const _MinuteClock({required this.builder});

  final WidgetBuilder builder;

  @override
  State<_MinuteClock> createState() => _MinuteClockState();
}

class _MinuteClockState extends State<_MinuteClock> {
  final _clock = SharedTimerService.instance;
  var _minute = _now();

  static int _now() => DateTime.now().millisecondsSinceEpoch ~/ 60000;

  void _tick() {
    final minute = _now();
    if (minute != _minute && mounted) setState(() => _minute = minute);
  }

  @override
  void initState() {
    super.initState();
    _clock.addListener(_tick);
  }

  @override
  void dispose() {
    _clock.removeListener(_tick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
