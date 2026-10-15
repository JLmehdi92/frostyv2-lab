import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/screens/channel/chat/details/chat_users_list.dart';
import 'package:frosty/screens/channel/chat/stores/chat_store.dart';
import 'package:frosty/screens/channel/video/overlay_common.dart';
import 'package:frosty/screens/channel/video/player_controller.dart';
import 'package:frosty/screens/channel/video/quality_selection.dart';
import 'package:frosty/screens/channel/video/stores/ivs_video_store.dart';
import 'package:frosty/screens/channel/video/stream_info_bar.dart';
import 'package:frosty/screens/channel_profile/channel_profile_screen.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/vod/channel_videos.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/utils.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/utils/modal_bottom_sheet.dart';
import 'package:frosty/widgets/live_indicator.dart';
import 'package:frosty/widgets/section_header.dart';
import 'package:frosty/widgets/uptime.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  const VideoOverlay({
    super.key,
    required this.videoStore,
    required this.chatStore,
    required this.settingsStore,
    this.onLongPressStats,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = context.frostyColors.overlayOnSurface;

    final backButton = IconButton(
      tooltip: 'Back',
      icon: Icon(
        Icons.adaptive.arrow_back_rounded,
        color: surfaceColor,
        shadows: kOverlayShadow,
      ),
      onPressed: Navigator.of(context).pop,
    );

    void openVideos() => ChannelVideosScreen.open(
      context,
      userLogin: chatStore.channelName,
      displayName: chatStore.displayName,
    );

    final videosButton = IconButton(
      tooltip: 'Videos',
      icon: Icon(
        Icons.video_library_outlined,
        color: surfaceColor,
        shadows: kOverlayShadow,
      ),
      onPressed: openVideos,
    );

    final chatOverlayButton = Observer(
      builder: (_) => IconButton(
        tooltip: videoStore.settingsStore.fullScreenChatOverlay
            ? 'Hide chat overlay'
            : 'Show chat overlay',
        onPressed: () => videoStore.settingsStore.fullScreenChatOverlay =
            !videoStore.settingsStore.fullScreenChatOverlay,
        icon: videoStore.settingsStore.fullScreenChatOverlay
            ? Icon(Icons.chat_rounded, shadows: kOverlayShadow)
            : Icon(Icons.chat_outlined, shadows: kOverlayShadow),
        color: surfaceColor,
      ),
    );

    // Tablet button: fits/fills the 16:9 video to the device screen (e.g. a
    // 3:2 tablet) without ever distorting it. Only the IVS texture engine
    // supports this, so it is hidden for the other engines.
    final fillScreenButton = videoStore is IvsVideoStore
        ? Observer(
            builder: (context) {
              final ivs = videoStore as IvsVideoStore;
              return Tooltip(
                message: ivs.fillScreen ? 'Fit to screen' : 'Fill screen',
                preferBelow: false,
                child: IconButton(
                  icon: Icon(
                    Icons.tablet_mac,
                    color: ivs.fillScreen
                        ? context.frostyColors.live
                        : surfaceColor,
                    shadows: kOverlayShadow,
                  ),
                  onPressed: ivs.toggleFillScreen,
                ),
              );
            },
          )
        : const SizedBox.shrink();

    final videoSettingsButton = IconButton(
      tooltip: 'Quality and settings',
      icon: Icon(Icons.settings, shadows: kOverlayShadow),
      color: surfaceColor,
      onPressed: () {
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
                              (prefs) => prefs.setString(
                                'last_stream_quality',
                                quality,
                              ),
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
                        Observer(
                          builder: (context) => SwitchListTile(
                            title: const Text('Captions'),
                            subtitle: const Text(
                              'Closed captions, when the stream has them',
                            ),
                            value: videoStore.settingsStore.showCaptions,
                            onChanged: (on) =>
                                videoStore.settingsStore.showCaptions = on,
                          ),
                        ),
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
                          subtitle: const Text(
                            'Start a new latency measurement',
                          ),
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
      },
    );

    // Mute toggle for the IVS player (the hardware keys still control the
    // system media volume).
    final muteButton = videoStore is IvsVideoStore
        ? Observer(
            builder: (context) {
              final ivs = videoStore as IvsVideoStore;
              return Tooltip(
                message: ivs.muted ? 'Unmute' : 'Mute',
                preferBelow: false,
                child: IconButton(
                  icon: Icon(
                    _isSilent(ivs)
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    color: surfaceColor,
                    shadows: kOverlayShadow,
                  ),
                  onPressed: ivs.toggleMute,
                ),
              );
            },
          )
        : const SizedBox.shrink();

    final refreshButton = Tooltip(
      message: 'Refresh',
      preferBelow: false,
      child: IconButton(
        icon: Icon(
          Icons.refresh_rounded,
          color: surfaceColor,
          shadows: kOverlayShadow,
        ),
        onPressed: videoStore.handleRefresh,
      ),
    );

    final fullScreenButton = Observer(
      builder: (_) {
        // In portrait the button always enters full screen.
        final active =
            videoStore.settingsStore.fullScreen && context.isLandscape;
        return Tooltip(
          message: active ? 'Exit fullscreen mode' : 'Enter fullscreen mode',
          preferBelow: false,
          child: IconButton(
            icon: Icon(
              active ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
              color: surfaceColor,
              shadows: kOverlayShadow,
            ),
            onPressed: () async {
              final settingsStore = videoStore.settingsStore;
              final largeScreen = context.isLargeScreen;
              if (context.isPortrait) {
                final before = (
                  settingsStore.fullScreen,
                  settingsStore.fullScreenChatOverlay,
                );
                // Twitch-style: enter landscape immersive fullscreen, starting
                // with the chat as an overlay. Double-tap then cycles the
                // modes.
                settingsStore.fullScreen = true;
                settingsStore.fullScreenChatOverlay = true;
                if (largeScreen) {
                  unawaited(
                    undoIfStillPortrait(
                      context,
                      undo: () => settingsStore
                        ..fullScreen = before.$1
                        ..fullScreenChatOverlay = before.$2,
                    ),
                  );
                }
                await enterLandscape(largeScreen: largeScreen);
              } else if (largeScreen) {
                toggleLargeScreenFullScreen(settingsStore);
              } else {
                settingsStore.fullScreen = false;
                exitToPortrait();
              }
            },
          ),
        );
      },
    );

    final rotateButton = Tooltip(
      message: context.isPortrait
          ? 'Enter landscape mode'
          : 'Exit landscape mode',
      preferBelow: false,
      child: IconButton(
        icon: Icon(
          Icons.screen_rotation_rounded,
          color: surfaceColor,
          shadows: kOverlayShadow,
        ),
        onPressed: () async {
          if (context.isPortrait) {
            await enterLandscape(largeScreen: context.isLargeScreen);
          } else {
            exitToPortrait();
          }
        },
      ),
    );

    // Flutter can't rotate an iPad programmatically (unless multitasking is
    // disabled), and a large screen is turned by hand.
    final screenButtons = liveScreenButtons(
      landscape: context.isLandscape,
      largeScreen: context.isLargeScreen,
      iPad: isIPad(),
    );

    return Observer(
      builder: (context) {
        final streamInfo = videoStore.streamInfo;
        final offlineChannelInfo = videoStore.offlineChannelInfo;

        final topGradient = overlayGradient(fromTop: true);
        final bottomGradient = overlayGradient(fromTop: false);

        if (streamInfo == null) {
          return Stack(
            children: [
              // Top gradient behind top cluster
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 100, // Covers top area around controls (extended)
                child: Container(decoration: topGradient),
              ),
              // Bottom gradient behind bottom cluster
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 80, // Covers bottom area around controls
                child: Container(decoration: bottomGradient),
              ),
              // Content
              Stack(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              backButton,
                              if (offlineChannelInfo != null)
                                Flexible(
                                  child: StreamInfoBar(
                                    offlineChannelInfo: offlineChannelInfo,
                                    displayName: chatStore.displayName,
                                    showUptime: false,
                                    showViewerCount: false,
                                    showOfflineIndicator: false,
                                    textColor: surfaceColor,
                                    isOffline: true,
                                    isInSharedChatMode:
                                        chatStore.isInSharedChatMode,
                                    onTapChannel: () =>
                                        ChannelProfileScreen.open(
                                          context,
                                          login: offlineChannelInfo
                                              .broadcasterLogin,
                                          displayName: offlineChannelInfo
                                              .broadcasterName,
                                          fromChannel: true,
                                        ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      videosButton,
                      if (videoStore.settingsStore.fullScreen &&
                          context.isLandscape)
                        chatOverlayButton,
                    ],
                  ),
                  Center(
                    child: FilledButton.tonalIcon(
                      onPressed: openVideos,
                      icon: const Icon(Icons.video_library_outlined),
                      label: const Text('Past broadcasts'),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        refreshButton,
                        if (screenButtons.rotate) rotateButton,
                        if (screenButtons.fullScreen) fullScreenButton,
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        return Stack(
          children: [
            // Top gradient behind top cluster
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 100, // Covers top area around controls (extended)
              child: Container(decoration: topGradient),
            ),
            // Bottom gradient behind bottom cluster
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 80, // Covers bottom area around controls
              child: Container(decoration: bottomGradient),
            ),
            // Content
            Stack(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            backButton,
                            Flexible(
                              child: Observer(
                                builder: (context) => StreamInfoBar(
                                  streamInfo: streamInfo,
                                  onTapChannel: () => ChannelProfileScreen.open(
                                    context,
                                    login: streamInfo.userLogin,
                                    displayName: streamInfo.userName,
                                    fromChannel: true,
                                  ),
                                  showUptime: false,
                                  showViewerCount: false,
                                  textColor: surfaceColor,
                                  isInSharedChatMode:
                                      chatStore.isInSharedChatMode,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    videosButton,
                    if (videoStore.settingsStore.fullScreen &&
                        context.isLandscape)
                      chatOverlayButton,
                    if (context.isLandscape) fillScreenButton,
                    if (!Platform.isIOS || isIPad()) videoSettingsButton,
                  ],
                ),
                Center(
                  child: Tooltip(
                    message: videoStore.paused ? 'Play' : 'Pause',
                    preferBelow: false,
                    child: IconButton(
                      iconSize: 56,
                      icon: Icon(
                        videoStore.paused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        color: surfaceColor,
                        shadows: kOverlayShadow,
                      ),
                      onPressed: videoStore.handlePausePlay,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: _LongPressListener(
                          onLongPress: onLongPressStats,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              spacing: 8,
                              children: [
                                // Uptime and viewers shrink first on narrow
                                // phones so the latency (used for measuring)
                                // always stays readable.
                                Flexible(
                                  child: Tooltip(
                                    message: 'Stream uptime',
                                    preferBelow: false,
                                    triggerMode: TooltipTriggerMode.tap,
                                    child: Row(
                                      spacing: 6,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const LiveIndicator(),
                                        Flexible(
                                          child: Uptime(
                                            startTime: streamInfo.startedAt,
                                            overflow: TextOverflow.ellipsis,
                                            style: context.frostyText.metadata
                                                .copyWith(
                                                  color: surfaceColor,
                                                  shadows: kOverlayShadow,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Flexible(
                                  child: Tooltip(
                                    message: 'Viewer count',
                                    preferBelow: false,
                                    child: GestureDetector(
                                      onTap: () =>
                                          showModalBottomSheetWithProperFocus(
                                            isScrollControlled: true,
                                            context: context,
                                            builder: (context) =>
                                                GestureDetector(
                                                  onTap: FocusScope.of(
                                                    context,
                                                  ).unfocus,
                                                  child: ChattersList(
                                                    chatDetailsStore: chatStore
                                                        .chatDetailsStore,
                                                    chatStore: chatStore,
                                                    userLogin:
                                                        streamInfo.userLogin,
                                                  ),
                                                ),
                                          ),
                                      child: Row(
                                        spacing: 4,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.visibility,
                                            size: 14,
                                            shadows: kOverlayShadow,
                                            color: surfaceColor,
                                          ),
                                          Flexible(
                                            child: Text(
                                              NumberFormat().format(
                                                videoStore
                                                    .streamInfo
                                                    ?.viewerCount,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: context.frostyText.metadata
                                                  .copyWith(
                                                    color: surfaceColor,
                                                    fontFeatures: const [
                                                      FontFeature.tabularFigures(),
                                                    ],
                                                    shadows: kOverlayShadow,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                if (settingsStore.showLatency)
                                  Tooltip(
                                    message: videoStore is IvsVideoStore
                                        ? 'Latency to broadcaster · tap for video stats'
                                        : 'Latency to broadcaster',
                                    preferBelow: false,
                                    triggerMode: videoStore is IvsVideoStore
                                        ? TooltipTriggerMode.longPress
                                        : TooltipTriggerMode.tap,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: videoStore is IvsVideoStore
                                          ? (videoStore as IvsVideoStore)
                                                .toggleStats
                                          : null,
                                      child: Row(
                                        spacing: 4,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.speed_rounded,
                                            size: 14,
                                            color: surfaceColor,
                                            shadows: kOverlayShadow,
                                          ),
                                          Observer(
                                            builder: (context) => Text(
                                              _latencyLabel(videoStore),
                                              maxLines: 1,
                                              style: context.frostyText.metadata
                                                  .copyWith(
                                                    color: surfaceColor,
                                                    fontFeatures: const [
                                                      FontFeature.tabularFigures(),
                                                    ],
                                                    shadows: kOverlayShadow,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Portrait has no room for one more button next to the
                      // stream info; mute stays in the settings sheet there.
                      if (context.isLandscape) muteButton,
                      Builder(
                        builder: (_) {
                          // On iOS, show toggle behavior. On Android, always show enter PiP.
                          final isIOS = Platform.isIOS;
                          final showExitState = isIOS && videoStore.isInPipMode;

                          return Tooltip(
                            message: showExitState
                                ? 'Exit picture-in-picture'
                                : 'Enter picture-in-picture',
                            preferBelow: false,
                            child: IconButton(
                              icon: Icon(
                                showExitState
                                    ? Icons.picture_in_picture_alt_outlined
                                    : Icons.picture_in_picture_alt_rounded,
                                color: surfaceColor,
                                shadows: kOverlayShadow,
                              ),
                              onPressed: videoStore.togglePictureInPicture,
                            ),
                          );
                        },
                      ),
                      refreshButton,
                      if (screenButtons.rotate) rotateButton,
                      if (screenButtons.fullScreen) fullScreenButton,
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Latency text for the overlay badge, or the reconnect progress while the
/// IVS engine is recovering from an error.
String _latencyLabel(PlayerController store) => switch (store) {
  // Compact so it fits next to the stream info on narrow phones.
  IvsVideoStore(status: IvsPlaybackStatus.reconnecting) =>
    '↻ ${store.retryAttempt}/${store.maxRetryAttempts}',
  _ => store.latency ?? '—',
};

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
