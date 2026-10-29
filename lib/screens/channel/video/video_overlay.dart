import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/screens/channel/chat/details/chat_users_list.dart';
import 'package:frosty/screens/channel/chat/stores/chat_store.dart';
import 'package:frosty/screens/channel/video/caption_menu.dart';
import 'package:frosty/screens/channel/video/create_clip_sheet.dart';
import 'package:frosty/screens/channel/video/latency_pill.dart';
import 'package:frosty/screens/channel/video/overlay_common.dart';
import 'package:frosty/screens/channel/video/player_controller.dart';
import 'package:frosty/screens/channel/video/player_glyph.dart';
import 'package:frosty/screens/channel/video/quality_selection.dart';
import 'package:frosty/screens/channel/video/stores/ivs_video_store.dart';
import 'package:frosty/screens/channel_profile/channel_profile_screen.dart';
import 'package:frosty/screens/home/top/categories/category_streams.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/vod/channel_videos.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/utils.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/utils/modal_bottom_sheet.dart';
import 'package:frosty/widgets/motion/rolling_number.dart';
import 'package:frosty/widgets/motion/signal_ping.dart';
import 'package:frosty/widgets/profile_picture.dart';
import 'package:frosty/widgets/section_header.dart';
import 'package:frosty/widgets/uptime.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sizes of the live player's chrome on this screen (boards ChaineLecteur
/// for the phone, Tablette and TablettePortrait for the tablet), shared
/// with the channel screen, which puts the latency pill exactly where the
/// controls' top row leaves room for it.
@immutable
class PlayerChromeMetrics {
  const PlayerChromeMetrics._({
    required this.large,
    required this.landscape,
    required this.top,
    required this.left,
    required this.right,
    required this.bottom,
    required this.bottomLeft,
    required this.topScrim,
    required this.bottomScrim,
    required this.avatar,
  });

  factory PlayerChromeMetrics.of(BuildContext context) {
    final large = context.isLargeScreen;
    final landscape = context.isLandscape;
    if (large) {
      return PlayerChromeMetrics._(
        large: true,
        landscape: landscape,
        top: 10,
        left: 10,
        right: 10,
        bottom: 8,
        bottomLeft: 18,
        topScrim: 110,
        bottomScrim: 110,
        avatar: 32,
      );
    }
    return landscape
        ? const PlayerChromeMetrics._(
            large: false,
            landscape: true,
            top: 8,
            left: 14,
            right: 10,
            bottom: 8,
            bottomLeft: 24,
            topScrim: 112,
            bottomScrim: 92,
            avatar: 32,
          )
        : const PlayerChromeMetrics._(
            large: false,
            landscape: false,
            top: 4,
            left: 0,
            right: 4,
            bottom: 2,
            bottomLeft: 12,
            topScrim: 100,
            bottomScrim: 80,
            avatar: 28,
          );
  }

  final bool large;
  final bool landscape;

  /// Insets of the top row of 44 dp buttons.
  final double top;
  final double left;
  final double right;

  /// Insets of the bottom row.
  final double bottom;
  final double bottomLeft;

  final double topScrim;
  final double bottomScrim;

  /// The channel's picture in the top row.
  final double avatar;

  /// Space between the last top button and the latency pill, and between
  /// the pill and the edge.
  static const pillGap = 4.0;
  double get pillEdge => right + 8;

  double get pillHeight => large ? 28 : 26;

  /// Where the latency pill sits over the video.
  double get pillTop => top + (44 - pillHeight) / 2;
}

/// Light on dark over the picture, in either theme (the boards' values).
abstract final class _Over {
  static const text = FrostyTokens.textPrimaryDark;
  static const body = Color(0xFFE5E5E5);
  static const shadow = kPlayerChromeShadow;
}

/// The scrim behind a row of controls: black 80 % at the edge, clear
/// towards the middle (never a blur over the video).
BoxDecoration _scrim({required bool fromTop}) => BoxDecoration(
  gradient: LinearGradient(
    begin: fromTop ? Alignment.topCenter : Alignment.bottomCenter,
    end: fromTop ? Alignment.bottomCenter : Alignment.topCenter,
    colors: const [Color(0xCC000000), Color(0x00000000)],
  ),
);

/// Creates a widget containing controls which enable interactions with an underlying [Video] widget.
class VideoOverlay extends StatelessWidget {
  final PlayerController videoStore;
  final ChatStore chatStore;
  final SettingsStore settingsStore;

  /// Long-pressing the uptime and viewer row previews a celebration.
  ///
  /// Celebrations only fire when a viewer actually gifts subs, so without this
  /// the animation could never be reviewed on a real screen — the one place
  /// that decides whether it is too loud or too dim.
  final VoidCallback? onLongPressStats;

  /// The room the top row keeps for the latency pill.
  static const latencySlotKey = ValueKey('latency-slot');

  const VideoOverlay({
    super.key,
    required this.videoStore,
    required this.chatStore,
    required this.settingsStore,
    this.onLongPressStats,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = PlayerChromeMetrics.of(context);

    final backButton = _PlayerButton(
      tooltip: 'Back',
      glyph: PlayerGlyphKind.back,
      glyphSize: 22,
      onPressed: Navigator.of(context).pop,
    );

    void openVideos() => ChannelVideosScreen.open(
      context,
      userLogin: chatStore.channelName,
      displayName: chatStore.displayName,
    );

    final videosButton = _PlayerButton(
      tooltip: 'Videos',
      glyph: PlayerGlyphKind.videos,
      onPressed: openVideos,
    );

    final chatOverlayButton = Observer(
      builder: (_) {
        final on = videoStore.settingsStore.fullScreenChatOverlay;
        return _PlayerButton(
          tooltip: on ? 'Hide chat overlay' : 'Show chat overlay',
          glyph: PlayerGlyphKind.chatBubble,
          // Shown: one of the active states the signal is reserved for.
          color: on ? FrostyTokens.accent : _Over.text,
          selected: on,
          onPressed: () => videoStore.settingsStore.fullScreenChatOverlay =
              !videoStore.settingsStore.fullScreenChatOverlay,
        );
      },
    );

    // Tablet button: fits/fills the 16:9 video to the device screen (e.g. a
    // 3:2 tablet) without ever distorting it. Only the IVS texture engine
    // supports this, so it is hidden for the other engines.
    final fillScreenButton = videoStore is IvsVideoStore
        ? Observer(
            builder: (context) {
              final ivs = videoStore as IvsVideoStore;
              return _PlayerButton(
                tooltip: ivs.fillScreen ? 'Fit to screen' : 'Fill screen',
                glyph: PlayerGlyphKind.fillScreen,
                color: ivs.fillScreen ? FrostyTokens.accent : _Over.text,
                selected: ivs.fillScreen,
                onPressed: ivs.toggleFillScreen,
              );
            },
          )
        : const SizedBox.shrink();

    final videoSettingsButton = _PlayerButton(
      tooltip: 'Quality and settings',
      glyph: PlayerGlyphKind.settings,
      onPressed: () => _openSettings(context),
    );

    // Mute toggle for the IVS player (the hardware keys still control the
    // system media volume).
    final muteButton = videoStore is IvsVideoStore
        ? Observer(
            builder: (context) {
              final ivs = videoStore as IvsVideoStore;
              return _PlayerButton(
                tooltip: ivs.muted ? 'Unmute' : 'Mute',
                glyph: _isSilent(ivs)
                    ? PlayerGlyphKind.muted
                    : PlayerGlyphKind.volume,
                below: false,
                onPressed: ivs.toggleMute,
              );
            },
          )
        : const SizedBox.shrink();

    final refreshButton = _PlayerButton(
      tooltip: 'Refresh',
      glyph: PlayerGlyphKind.refresh,
      below: false,
      onPressed: videoStore.handleRefresh,
    );

    final fullScreenButton = Observer(
      builder: (_) => _PlayerButton(
        tooltip: videoStore.settingsStore.fullScreen
            ? 'Exit fullscreen mode'
            : 'Enter fullscreen mode',
        glyph: PlayerGlyphKind.fullscreen,
        below: false,
        onPressed: () async {
          final settingsStore = videoStore.settingsStore;
          if (context.isPortrait) {
            // Twitch-style: enter landscape immersive fullscreen, starting
            // with the chat as an overlay. Double-tap then cycles the modes.
            settingsStore.fullScreen = true;
            settingsStore.fullScreenChatOverlay = true;
            await enterLandscape();
          } else {
            settingsStore.fullScreen = false;
            exitToPortrait();
          }
        },
      ),
    );

    // The side chat's own control on a tablet (board Tablette): hides it
    // (the "hidden" layout the double tap reaches) and brings it back.
    final sideChatButton = Observer(
      builder: (_) {
        final settingsStore = videoStore.settingsStore;
        final hidden = settingsStore.fullScreen;
        return _PlayerButton(
          tooltip: hidden ? 'Show chat' : 'Hide chat',
          glyph: PlayerGlyphKind.sidebar,
          below: false,
          onPressed: () {
            if (hidden) {
              settingsStore.fullScreen = false;
            } else {
              settingsStore.fullScreen = true;
              settingsStore.fullScreenChatOverlay = false;
            }
          },
        );
      },
    );

    final rotateButton = _PlayerButton(
      tooltip: context.isPortrait
          ? 'Enter landscape mode'
          : 'Exit landscape mode',
      glyph: PlayerGlyphKind.rotate,
      below: false,
      onPressed: () async {
        if (context.isPortrait) {
          await enterLandscape();
        } else {
          exitToPortrait();
        }
      },
    );

    final pipButton = Builder(
      builder: (_) {
        // On iOS, show toggle behavior. On Android, always show enter PiP.
        final showExitState = Platform.isIOS && videoStore.isInPipMode;
        return _PlayerButton(
          tooltip: showExitState
              ? 'Exit picture-in-picture'
              : 'Enter picture-in-picture',
          glyph: PlayerGlyphKind.pip,
          below: false,
          onPressed: videoStore.togglePictureInPicture,
        );
      },
    );

    return Observer(
      builder: (context) {
        final streamInfo = videoStore.streamInfo;
        final offlineChannelInfo = videoStore.offlineChannelInfo;
        final landscape = metrics.landscape;
        final fullScreen = videoStore.settingsStore.fullScreen;

        final scrims = [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: metrics.topScrim,
            child: DecoratedBox(decoration: _scrim(fromTop: true)),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: metrics.bottomScrim,
            child: DecoratedBox(decoration: _scrim(fromTop: false)),
          ),
        ];

        if (streamInfo == null) {
          final login = offlineChannelInfo?.broadcasterLogin ?? '';
          final name = offlineChannelInfo == null
              ? null
              : getReadableName(
                  offlineChannelInfo.broadcasterName.isNotEmpty
                      ? offlineChannelInfo.broadcasterName
                      : chatStore.displayName,
                  login,
                );
          return Stack(
            children: [
              ...scrims,
              Positioned(
                top: metrics.top,
                left: metrics.left,
                right: metrics.right,
                child: Row(
                  children: [
                    backButton,
                    if (name != null)
                      Expanded(
                        child: _ChannelIdentity(
                          login: login,
                          name: name,
                          subtitle: 'Offline',
                          avatar: metrics.avatar,
                          sharedChat: chatStore.isInSharedChatMode,
                          onTap: () => ChannelProfileScreen.open(
                            context,
                            login: offlineChannelInfo!.broadcasterLogin,
                            displayName: offlineChannelInfo.broadcasterName,
                            fromChannel: true,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    videosButton,
                    if (fullScreen && landscape) chatOverlayButton,
                  ],
                ),
              ),
              Center(
                child: FilledButton.tonalIcon(
                  onPressed: openVideos,
                  icon: const Icon(Icons.video_library_outlined),
                  label: const Text('Past broadcasts'),
                ),
              ),
              Positioned(
                right: metrics.right,
                bottom: metrics.bottom,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    refreshButton,
                    // On iPad, hide the rotate button on the overlay
                    // Flutter doesn't allow programmatic rotation on iPad unless multitasking is disabled.
                    if (!isIPad()) rotateButton,
                    if (landscape) fullScreenButton,
                  ],
                ),
              ),
            ],
          );
        }

        // A tablet in portrait shows the channel under the video; a tablet
        // beside its chat shows the category here and the title below.
        final showIdentity = !(metrics.large && !landscape);
        final subtitle = metrics.large && landscape && !fullScreen
            ? streamInfo.gameName
            : streamInfo.title.trim();
        final showLatency = settingsStore.showLatency;

        return Stack(
          children: [
            ...scrims,
            Positioned(
              top: metrics.top,
              left: metrics.left,
              right: metrics.right,
              child: Row(
                children: [
                  backButton,
                  if (showIdentity)
                    Expanded(
                      child: _ChannelIdentity(
                        login: streamInfo.userLogin,
                        name: getReadableName(
                          streamInfo.userName,
                          streamInfo.userLogin,
                        ),
                        subtitle: subtitle,
                        avatar: metrics.avatar,
                        large: metrics.large || landscape,
                        sharedChat: chatStore.isInSharedChatMode,
                        categoryId: subtitle == streamInfo.gameName
                            ? streamInfo.gameId
                            : null,
                        onTap: () => ChannelProfileScreen.open(
                          context,
                          login: streamInfo.userLogin,
                          displayName: streamInfo.userName,
                          fromChannel: true,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  CreateClipButton(
                    broadcasterId: streamInfo.userId,
                    color: _Over.text,
                    icon: const PlayerGlyph(
                      PlayerGlyphKind.clip,
                      color: _Over.text,
                      shadow: true,
                    ),
                  ),
                  videosButton,
                  if (fullScreen && landscape) chatOverlayButton,
                  if (landscape) fillScreenButton,
                  if (!Platform.isIOS || isIPad()) videoSettingsButton,
                  // The latency pill is drawn by the channel screen over
                  // this spot, outside the controls that hide: the row
                  // keeps the room it needs.
                  if (showLatency) ...[
                    const SizedBox(width: PlayerChromeMetrics.pillGap),
                    SizedBox(
                      key: VideoOverlay.latencySlotKey,
                      width: LatencyPill.slotWidth(
                        context,
                        large: metrics.large,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            Center(
              child: _PlayPauseButton(
                paused: videoStore.paused,
                onPressed: videoStore.handlePausePlay,
              ),
            ),
            Positioned(
              left: metrics.bottomLeft,
              right: metrics.right,
              bottom: metrics.bottom,
              child: Row(
                children: [
                  Expanded(
                    child: _LongPressListener(
                      onLongPress: onLongPressStats,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _LiveStats(
                          startedAt: streamInfo.startedAt,
                          viewers: streamInfo.viewerCount,
                          large: metrics.large,
                          animate: videoStore.overlayVisible,
                          onTapViewers: () =>
                              _openChatters(context, streamInfo.userLogin),
                        ),
                      ),
                    ),
                  ),
                  // Portrait has no room for one more button next to the
                  // stream info; mute stays in the settings sheet there.
                  if (landscape) muteButton,
                  if (landscape && metrics.large) sideChatButton,
                  pipButton,
                  refreshButton,
                  // On iPad, hide the rotate button on the overlay
                  // Flutter doesn't allow programmatic rotation on iPad unless multitasking is disabled.
                  if (!isIPad()) rotateButton,
                  if (landscape) fullScreenButton,
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _openChatters(BuildContext context, String userLogin) =>
      showModalBottomSheetWithProperFocus(
        isScrollControlled: true,
        context: context,
        builder: (context) => GestureDetector(
          onTap: FocusScope.of(context).unfocus,
          child: ChattersList(
            chatDetailsStore: chatStore.chatDetailsStore,
            chatStore: chatStore,
            userLogin: userLogin,
          ),
        ),
      );

  void _openSettings(BuildContext context) {
    videoStore.updateStreamQualities();
    showModalBottomSheetWithProperFocus(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            'Stream quality',
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            isFirst: true,
          ),
          // One scrollable list holds the qualities and the IVS
          // measurement entries so the sheet never overflows in landscape.
          Flexible(
            child: Observer(
              builder: (context) => ListView(
                shrinkWrap: true,
                primary: false,
                children: [
                  ...videoStore.availableStreamQualities.map(
                    (quality) => ListTile(
                      trailing: videoStore.streamQuality == quality
                          ? Icon(
                              Icons.check_rounded,
                              // A selected check is one of the four
                              // states the accent is reserved for.
                              color: context.frostyColors.live,
                            )
                          : null,
                      title: Text(
                        qualityLabel(quality),
                        style: context.frostyText.metadata,
                      ),
                      onTap: () {
                        videoStore.setStreamQuality(quality);
                        SharedPreferences.getInstance().then(
                          (prefs) =>
                              prefs.setString('last_stream_quality', quality),
                        );
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  if (videoStore case final IvsVideoStore ivs) ...[
                    const SectionHeader(
                      'Volume',
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    ),
                    // Own Observer so dragging the slider does not rebuild
                    // the whole quality list.
                    Observer(
                      builder: (context) => VolumeRow(
                        muted: ivs.muted,
                        volume: ivs.volume,
                        onToggleMute: ivs.toggleMute,
                        onVolumeChanged: ivs.setVolume,
                      ),
                    ),
                    CaptionMenu(captions: ivs.captions),
                    const SectionHeader(
                      'Measurement',
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    ),
                    ListTile(
                      title: const Text('Video stats'),
                      subtitle: const Text(
                        'Latency, buffer, bitrate and frames over the video',
                      ),
                      trailing: ivs.statsVisible
                          ? const Icon(Icons.check_rounded)
                          : null,
                      onTap: () {
                        ivs.toggleStats();
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      title: const Text('Reset stats'),
                      subtitle: const Text('Start a new latency measurement'),
                      onTap: () {
                        ivs.resetStats();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A 44 dp control over the video: a board glyph with its soft shadow.
class _PlayerButton extends StatelessWidget {
  const _PlayerButton({
    required this.tooltip,
    required this.glyph,
    required this.onPressed,
    this.color = _Over.text,
    this.glyphSize = 20,
    this.below = true,
    this.selected,
  });

  final String tooltip;
  final PlayerGlyphKind glyph;
  final VoidCallback? onPressed;
  final Color color;
  final double glyphSize;

  /// Top-row tips open below the button, bottom-row ones above it.
  final bool below;

  /// A toggle's state, for screen readers.
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      preferBelow: below,
      child: Semantics(
        selected: selected,
        child: IconButton(
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          style: IconButton.styleFrom(
            foregroundColor: color,
            highlightColor: const Color(0x1FFFFFFF),
            // The boards' 44 dp row, not Material's 48.
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: PlayerGlyph(glyph, color: color, size: glyphSize, shadow: true),
        ),
      ),
    );
  }
}

/// Play / pause in the middle of the video: a 64 dp disc of black 38 %
/// with a hairline, so it reads over any picture without a blur.
class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.paused, required this.onPressed});

  final bool paused;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: paused ? 'Play' : 'Pause',
      preferBelow: false,
      child: SizedBox.square(
        dimension: 64,
        child: Material(
          color: const Color(0x61000000),
          shape: const CircleBorder(
            side: BorderSide(
              color: Color(0x29FFFFFF),
              width: FrostyTokens.hairlineWidth,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Center(
              child: PlayerGlyph(
                paused ? PlayerGlyphKind.play : PlayerGlyphKind.pause,
                color: _Over.text,
                size: 28,
                strokeWidth: 2.6,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The channel in the top row: its picture in the signal ring, its name and
/// the title (or the category, which then opens its streams on a double tap).
class _ChannelIdentity extends StatelessWidget {
  const _ChannelIdentity({
    required this.login,
    required this.name,
    required this.subtitle,
    required this.avatar,
    required this.onTap,
    this.large = false,
    this.sharedChat = false,
    this.categoryId,
  });

  final String login;
  final String name;
  final String subtitle;
  final double avatar;
  final VoidCallback onTap;
  final bool large;

  /// A shared chat session: the ring says so, as it did before.
  final bool sharedChat;

  /// Set when [subtitle] is the category.
  final String? categoryId;

  @override
  Widget build(BuildContext context) {
    const ring = 1.5;
    final subtitleText = Text(
      // The avatar ring used to be the only sign of a shared chat session;
      // every live channel wears the signal ring now, so it is said.
      sharedChat && subtitle.isNotEmpty ? 'Shared chat · $subtitle' : subtitle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: large ? 12 : 11.5,
        height: 1.3,
        color: _Over.body,
        shadows: _Over.shadow,
      ),
    );
    final picture = avatar + ring * 4;
    // A row too narrow for the picture and some of the name (a small
    // phone with large text) leaves the channel to the info under the
    // video rather than overflow.
    return LayoutBuilder(
      builder: (context, constraints) {
        final row = Row(
          children: [
            Semantics(
              button: true,
              label: 'Channel profile',
              child: Tooltip(
                message: 'Channel profile',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onTap,
                  child: Container(
                    width: avatar + ring * 4,
                    height: avatar + ring * 4,
                    padding: const EdgeInsets.all(ring),
                    decoration: const BoxDecoration(
                      color: FrostyTokens.accent,
                      shape: BoxShape.circle,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(ring),
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: ProfilePicture(
                        userLogin: login,
                        radius: avatar / 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: large ? 15 : 14,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      color: _Over.text,
                      shadows: _Over.shadow,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Tooltip(
                      message: subtitle,
                      triggerMode: TooltipTriggerMode.tap,
                      child: categoryId == null
                          ? subtitleText
                          : Semantics(
                              link: true,
                              onTap: () =>
                                  CategoryStreams.open(context, categoryId!),
                              child: GestureDetector(
                                onDoubleTap: () =>
                                    CategoryStreams.open(context, categoryId!),
                                child: subtitleText,
                              ),
                            ),
                    ),
                ],
              ),
            ),
          ],
        );
        if (constraints.maxWidth < picture + 8 + 24) {
          return const SizedBox.shrink();
        }
        return row;
      },
    );
  }
}

/// "LIVE 3:12:40 · 👁 2,445" at the bottom left (the phone boards), or
/// "LIVE · 2,445 · 3:12:40" with the pinging dot (the tablet boards). A tap
/// on the viewers lists the chatters.
class _LiveStats extends StatelessWidget {
  const _LiveStats({
    required this.startedAt,
    required this.viewers,
    required this.large,
    required this.onTapViewers,
    this.animate = true,
  });

  final String startedAt;
  final int viewers;
  final bool large;
  final VoidCallback onTapViewers;

  /// Whether the controls are shown (the live dot pings only then).
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final style = FrostyType.tabular(
      TextStyle(
        fontFamily: FrostyTokens.bodyFamily,
        fontSize: large ? 13 : 12.5,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: _Over.text,
        shadows: _Over.shadow,
      ),
    );
    final badge = Container(
      height: large ? 24 : 20,
      padding: EdgeInsets.symmetric(horizontal: large ? 8 : 6),
      decoration: BoxDecoration(
        color: FrostyTokens.accent,
        borderRadius: BorderRadius.circular(large ? 6 : 5),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          if (large)
            // Its ripple stops while the controls are hidden: nothing
            // loops over the video unseen.
            TickerMode(
              enabled: animate,
              child: const SignalPing(
                size: 6,
                color: FrostyTokens.backgroundDark,
              ),
            ),
          Text(
            'LIVE',
            style: FrostyType.badge.copyWith(
              fontSize: large ? 11 : 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.06 * (large ? 11 : 10),
              color: FrostyTokens.backgroundDark,
              height: 1,
            ),
          ),
        ],
      ),
    );
    final uptime = Tooltip(
      message: 'Stream uptime',
      preferBelow: false,
      triggerMode: TooltipTriggerMode.tap,
      child: Uptime(
        startTime: startedAt,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
    final count = Tooltip(
      message: 'Viewer count',
      preferBelow: false,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTapViewers,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            if (!large)
              const PlayerGlyph(
                PlayerGlyphKind.eye,
                color: _Over.text,
                size: 14,
                shadow: true,
              ),
            Semantics(
              label: '${NumberFormat().format(viewers)} viewers',
              child: ExcludeSemantics(
                child: RollingNumber(
                  NumberFormat().format(viewers),
                  style: style,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (large) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          badge,
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                count,
                Text(' · ', style: style),
                Flexible(child: uptime),
              ],
            ),
          ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 10,
      children: [
        // Uptime and viewers shrink first on narrow phones.
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              badge,
              Flexible(child: uptime),
            ],
          ),
        ),
        Flexible(child: count),
      ],
    );
  }
}

/// Whether the IVS player is muted or at zero volume (same icon everywhere).
bool _isSilent(IvsVideoStore store) => store.muted || store.volume == 0;

/// Detects a long press without entering the gesture arena.
///
/// A plain [GestureDetector] here loses to the [Tooltip]s wrapping the uptime
/// and viewer count: they are descendants, so they win the arena and swallow
/// the press. Only the gaps between them would respond, which reads as the
/// feature being broken. [Listener] sees raw pointer events and never
/// competes, so the whole row is pressable.
class _LongPressListener extends StatefulWidget {
  final VoidCallback? onLongPress;
  final Widget child;

  const _LongPressListener({required this.onLongPress, required this.child});

  @override
  State<_LongPressListener> createState() => _LongPressListenerState();
}

class _LongPressListenerState extends State<_LongPressListener> {
  static const _holdDuration = Duration(milliseconds: 600);

  /// How far the finger may drift and still count as a press rather than a
  /// scroll or a drag of the player.
  static const _slop = 24.0;

  Timer? _timer;
  Offset? _origin;

  void _start(PointerDownEvent event) {
    if (widget.onLongPress == null) return;

    _origin = event.position;
    _timer?.cancel();
    _timer = Timer(_holdDuration, () {
      _timer = null;
      widget.onLongPress?.call();
    });
  }

  void _move(PointerMoveEvent event) {
    final origin = _origin;
    if (origin == null || _timer == null) return;

    if ((event.position - origin).distance > _slop) _cancel();
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
    _origin = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _start,
      onPointerMove: _move,
      onPointerUp: (_) => _cancel(),
      onPointerCancel: (_) => _cancel(),
      child: widget.child,
    );
  }
}
