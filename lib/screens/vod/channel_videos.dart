import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onset/models/clip.dart';
import 'package:onset/models/vod.dart';
import 'package:onset/screens/clips/stores/channel_clips_store.dart';
import 'package:onset/screens/clips/widgets/channel_clips_tab.dart';
import 'package:onset/screens/home/shell/shell_tabs.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/screens/vod/stores/channel_videos_store.dart';
import 'package:onset/screens/vod/widgets/channel_videos_tab.dart';
import 'package:onset/screens/vod/widgets/video_glyph.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/motion/press_scale.dart';
import 'package:onset/widgets/profile_picture.dart';

/// A channel's past broadcasts, highlights, uploads and clips, each played
/// in-app: the channel and "· Videos" over the tabs
/// with the signal underline; the tabs also follow a swipe.
class ChannelVideosScreen extends StatefulWidget {
  static const routeName = 'ChannelVideos';

  const ChannelVideosScreen({
    super.key,
    required this.userLogin,
    required this.displayName,
    this.initialTab = VodType.archive,
    this.startOnClips = false,
    this.clipPeriod = ClipPeriod.lastWeek,
  });

  final String userLogin;
  final String displayName;
  final VodType initialTab;

  /// Opens on the Clips tab (a `/<channel>/clips` link), for [clipPeriod].
  final bool startOnClips;
  final ClipPeriod clipPeriod;

  static Future<void> open(
    BuildContext context, {
    required String userLogin,
    required String displayName,
    VodType initialTab = VodType.archive,
    bool startOnClips = false,
    ClipPeriod clipPeriod = ClipPeriod.lastWeek,
  }) => Navigator.push(
    context,
    MaterialPageRoute(
      settings: const RouteSettings(name: routeName),
      builder: (context) => ChannelVideosScreen(
        userLogin: userLogin,
        displayName: displayName,
        initialTab: initialTab,
        startOnClips: startOnClips,
        clipPeriod: clipPeriod,
      ),
    ),
  );

  @override
  State<ChannelVideosScreen> createState() => _ChannelVideosScreenState();
}

class _ChannelVideosScreenState extends State<ChannelVideosScreen>
    with SingleTickerProviderStateMixin {
  static const _tabs = [
    (VodType.archive, 'Past broadcasts', 'No past broadcasts'),
    (VodType.highlight, 'Highlights', 'No highlights'),
    (VodType.upload, 'Uploads', 'No uploads'),
  ];

  late final _stores = {
    for (final (type, _, _) in _tabs)
      type: ChannelVideosStore(
        login: widget.userLogin,
        type: type,
        vodService: context.twitchVodService,
      ),
  };

  late final _clipsStore = ChannelClipsStore(
    login: widget.userLogin,
    clipService: context.twitchClipService,
    period: widget.clipPeriod,
  );

  late final TabController _tabController = TabController(
    length: _tabs.length + 1,
    vsync: this,
    initialIndex: widget.startOnClips
        ? _tabs.length
        : _tabs
              .indexWhere((t) => t.$1 == widget.initialTab)
              .clamp(0, _tabs.length - 1),
  );

  /// The tab under the underline: it follows a swipe as it passes half way.
  late int _shown = _tabController.index;

  @override
  void initState() {
    super.initState();
    _tabController.animation?.addListener(_onSwipe);
  }

  void _onSwipe() {
    // A tap animates across the tabs between: the underline goes straight
    // to the one tapped.
    if (_tabController.indexIsChanging) return;
    final shown = _tabController.animation!.value.round();
    if (shown != _shown) setState(() => _shown = shown);
  }

  @override
  void dispose() {
    _tabController.animation?.removeListener(_onSwipe);
    _tabController.dispose();
    for (final store in _stores.values) {
      store.dispose();
    }
    _clipsStore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = FeedColors.of(context);
    final accent = context.onsetColors.live;
    final ground = theme.scaffoldBackgroundColor;
    final padding = MediaQuery.paddingOf(context);
    final labels = [for (final (_, label, _) in _tabs) label, 'Clips'];

    final header = DecoratedBox(
      decoration: BoxDecoration(
        color: ground.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(
            color: colors.hairline,
            width: OnsetTokens.hairlineWidth,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          top: padding.top,
          left: padding.left,
          right: padding.right,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 56,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 4, end: 8),
                child: Row(
                  spacing: 6,
                  children: [
                    Tooltip(
                      message: 'Back',
                      child: PressScale(
                        child: IconButton(
                          onPressed: () => Navigator.maybePop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 44,
                            height: 44,
                          ),
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: VideoGlyph(
                            VideoGlyphKind.back,
                            color: colors.text,
                            size: 22,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    ),
                    ProfilePicture(userLogin: widget.userLogin, radius: 15),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text.rich(
                          TextSpan(
                            text: widget.displayName,
                            children: [
                              TextSpan(
                                text: ' · Videos',
                                style: TextStyle(
                                  color: colors.tertiary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: OnsetTokens.displayFamily,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.27,
                            color: colors.text,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ShellTabs(
              labels: labels,
              index: _shown,
              onSelect: (i) {
                setState(() => _shown = i);
                _tabController.animateTo(i);
              },
              height: 44,
              fontSize: 15,
              gap: 22,
              bottomPadding: 11,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              activeColor: colors.text,
              idleColor: colors.tertiary,
              indicatorColor: accent,
            ),
          ],
        ),
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value:
          theme.appBarTheme.systemOverlayStyle ??
          (theme.brightness == Brightness.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark),
      child: Scaffold(
        backgroundColor: ground,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    for (final (type, _, empty) in _tabs)
                      ChannelVideosTab(
                        store: _stores[type]!,
                        emptyMessage: empty,
                      ),
                    ChannelClipsTab(store: _clipsStore),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
