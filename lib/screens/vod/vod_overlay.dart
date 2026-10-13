import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/screens/channel/channel.dart';
import 'package:frosty/screens/channel/video/overlay_common.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/vod/vod_player_controller.dart';
import 'package:frosty/screens/vod/vod_time.dart';
import 'package:frosty/screens/vod/widgets/vod_seek_bar.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/utils/modal_bottom_sheet.dart';
import 'package:frosty/widgets/profile_picture.dart';
import 'package:frosty/widgets/section_header.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Link to [vod] at [at], as Twitch shares it.
String vodShareLink(Vod vod, Duration at) {
  final base = 'https://www.twitch.tv/videos/${vod.id}';
  return at.inSeconds <= 0 ? base : '$base?t=${formatVodTimeForShare(at)}';
}

/// Controls over the VOD player: back, title and channel, ±10 s and
/// play/pause, the seek bar with elapsed time, speed, sound, PiP, fit/fill
/// and rotation. Double-tap the left or right third to skip 10 s.
class VodOverlay extends StatefulWidget {
  const VodOverlay({
    super.key,
    required this.controller,
    required this.vod,
    required this.settings,
    this.mutedSegments = const [],
    this.fillScreen,
    this.onToggleFillScreen,
    this.showChatOverlayButton = false,
    this.isLandscape = false,
  });

  final VodPlayerController controller;
  final Vod vod;
  final SettingsStore settings;
  final List<MutedSegment> mutedSegments;

  /// Fit/fill state, when the engine supports it (IVS only).
  final bool? fillScreen;
  final VoidCallback? onToggleFillScreen;

  /// Landscape full screen: toggles the chat drawn over the video.
  final bool showChatOverlayButton;
  final bool isLandscape;

  @override
  State<VodOverlay> createState() => _VodOverlayState();
}

class _VodOverlayState extends State<VodOverlay> {
  static const _skip = Duration(seconds: 10);

  Offset? _doubleTapAt;

  /// The "−10 s"/"+10 s" badge after a double tap (true = forward).
  bool? _skipBadgeForward;
  Timer? _skipBadgeTimer;

  VodPlayerController get _c => widget.controller;

  @override
  void dispose() {
    _skipBadgeTimer?.cancel();
    super.dispose();
  }

  Color _onSurface(BuildContext context) =>
      Theme.of(context).extension<FrostyColors>()?.overlayOnSurface ??
      Colors.white;

  void _onDoubleTap(double width) {
    final x = _doubleTapAt?.dx ?? width / 2;
    if (x < width / 3) {
      _c.seekBy(-_skip);
      _showSkipBadge(forward: false);
    } else if (x > width * 2 / 3) {
      _c.seekBy(_skip);
      _showSkipBadge(forward: true);
    } else {
      _c.togglePlay();
    }
  }

  void _showSkipBadge({required bool forward}) {
    _skipBadgeTimer?.cancel();
    setState(() => _skipBadgeForward = forward);
    _skipBadgeTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _skipBadgeForward = null);
    });
  }

  Widget _icon(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    double size = 24,
    Color? color,
  }) => IconButton(
    tooltip: tooltip,
    iconSize: size,
    onPressed: onPressed,
    icon: Icon(
      icon,
      color: color ?? _onSurface(context),
      shadows: kOverlayShadow,
    ),
  );

  void _openChannel(BuildContext context) {
    final vod = widget.vod;
    if (vod.ownerId.isEmpty || vod.ownerLogin.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoChat(
          userId: vod.ownerId,
          userName: vod.ownerDisplayName,
          userLogin: vod.ownerLogin,
        ),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    _c.showOverlay();
    showModalBottomSheetWithProperFocus(
      context: context,
      builder: (sheetContext) =>
          VodSettingsSheet(controller: _c, vod: widget.vod),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gestures = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _c.handleVideoTap,
          onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
          onDoubleTap: () => _onDoubleTap(constraints.maxWidth),
          child: const SizedBox.expand(),
        );
        final badgeForward = _skipBadgeForward;

        return Stack(
          children: [
            gestures,
            if (badgeForward != null)
              Align(
                alignment: badgeForward
                    ? const Alignment(0.7, 0)
                    : const Alignment(-0.7, 0),
                child: IgnorePointer(
                  child: _SkipBadge(
                    key: ValueKey(badgeForward),
                    forward: badgeForward,
                  ),
                ),
              ),
            Observer(
              builder: (context) {
                final visible = _c.overlayVisible;
                return IgnorePointer(
                  ignoring: !visible,
                  child: AnimatedOpacity(
                    opacity: visible ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: _controls(context),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _controls(BuildContext context) {
    final onSurface = _onSurface(context);
    final vod = widget.vod;

    final top = Container(
      decoration: overlayGradient(fromTop: true),
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          _icon(
            context,
            icon: Icons.adaptive.arrow_back_rounded,
            tooltip: 'Back',
            onPressed: () => Navigator.maybePop(context),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _openChannel(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    vod.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: onSurface,
                      fontWeight: FontWeight.w600,
                      shadows: kOverlayShadow,
                    ),
                  ),
                  if (vod.ownerLogin.isNotEmpty)
                    Row(
                      spacing: 6,
                      children: [
                        ProfilePicture(userLogin: vod.ownerLogin, radius: 9),
                        Flexible(
                          child: Text(
                            vod.ownerDisplayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: onSurface.withValues(alpha: 0.85),
                              fontSize: 13,
                              shadows: kOverlayShadow,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (widget.showChatOverlayButton)
            Observer(
              builder: (context) => _icon(
                context,
                icon: widget.settings.fullScreenChatOverlay
                    ? Icons.chat_rounded
                    : Icons.chat_outlined,
                tooltip: widget.settings.fullScreenChatOverlay
                    ? 'Hide chat overlay'
                    : 'Show chat overlay',
                onPressed: () => widget.settings.fullScreenChatOverlay =
                    !widget.settings.fullScreenChatOverlay,
              ),
            ),
          _icon(
            context,
            icon: Icons.settings,
            tooltip: 'Settings',
            onPressed: () => _openSettings(context),
          ),
        ],
      ),
    );

    final center = Observer(
      builder: (context) {
        final ended = _c.ended;
        final paused = _c.paused;
        return Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 24,
          children: [
            _icon(
              context,
              icon: Icons.replay_10_rounded,
              tooltip: 'Back 10 seconds',
              size: 36,
              onPressed: () => _c.seekBy(-_skip),
            ),
            _icon(
              context,
              icon: ended
                  ? Icons.replay_rounded
                  : paused
                  ? Icons.play_arrow_rounded
                  : Icons.pause_rounded,
              tooltip: ended
                  ? 'Replay'
                  : paused
                  ? 'Play'
                  : 'Pause',
              size: 56,
              onPressed: _c.togglePlay,
            ),
            _icon(
              context,
              icon: Icons.forward_10_rounded,
              tooltip: 'Forward 10 seconds',
              size: 36,
              onPressed: () => _c.seekBy(_skip),
            ),
          ],
        );
      },
    );

    final bottom = Container(
      decoration: overlayGradient(fromTop: false),
      padding: const EdgeInsets.fromLTRB(12, 24, 4, 0),
      child: Observer(
        builder: (context) {
          final rate = _c.playbackRate;
          final silent = _c.muted || _c.volume == 0;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              VodSeekBar(
                position: _c.position,
                duration: _c.duration,
                buffered: _c.buffered,
                mutedSegments: widget.mutedSegments,
                onSeek: _c.seekTo,
                onScrubbing: (scrubbing) {
                  if (scrubbing) _c.showOverlay();
                },
              ),
              Row(
                children: [
                  Text(
                    '${formatVodTime(_c.position)} / '
                    '${formatVodTime(_c.duration)}',
                    style: TextStyle(
                      color: onSurface,
                      fontSize: 13,
                      shadows: kOverlayShadow,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Spacer(),
                  if (rate != 1.0)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: _SpeedChip(
                        rate: rate,
                        onTap: () => _openSettings(context),
                      ),
                    ),
                  _icon(
                    context,
                    icon: silent
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    tooltip: _c.muted ? 'Unmute' : 'Mute',
                    onPressed: _c.toggleMute,
                  ),
                  if (Platform.isAndroid)
                    _icon(
                      context,
                      icon: Icons.picture_in_picture_alt_rounded,
                      tooltip: 'Picture-in-picture',
                      onPressed: _c.requestPictureInPicture,
                    ),
                  if (widget.onToggleFillScreen != null)
                    _icon(
                      context,
                      icon: Icons.tablet_mac,
                      tooltip: widget.fillScreen == true
                          ? 'Fit to screen'
                          : 'Fill screen',
                      color: widget.fillScreen == true
                          ? Theme.of(context).colorScheme.primary
                          : null,
                      onPressed: widget.onToggleFillScreen,
                    ),
                  _icon(
                    context,
                    icon: widget.isLandscape
                        ? Icons.fullscreen_exit_rounded
                        : Icons.fullscreen_rounded,
                    tooltip: widget.isLandscape
                        ? 'Exit full screen'
                        : 'Full screen',
                    onPressed: () async {
                      if (widget.isLandscape) {
                        exitToPortrait();
                      } else {
                        await enterLandscape();
                      }
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return Stack(
      children: [
        Positioned(top: 0, left: 0, right: 0, child: top),
        Center(child: center),
        Positioned(bottom: 0, left: 0, right: 0, child: bottom),
      ],
    );
  }
}

/// Quality, volume, playback speed and share-at-time for a VOD.
class VodSettingsSheet extends StatelessWidget {
  const VodSettingsSheet({
    super.key,
    required this.controller,
    required this.vod,
  });

  final VodPlayerController controller;
  final Vod vod;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Observer(
        builder: (context) => ListView(
          shrinkWrap: true,
          primary: false,
          children: [
            if (controller.qualities.length > 1) ...[
              const SectionHeader(
                'Quality',
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                isFirst: true,
              ),
              for (final quality in controller.qualities)
                ListTile(
                  title: Text(quality),
                  trailing: controller.quality == quality
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () {
                    controller.setQuality(quality);
                    unawaited(
                      SharedPreferences.getInstance().then(
                        (prefs) =>
                            prefs.setString('last_stream_quality', quality),
                      ),
                    );
                    Navigator.pop(context);
                  },
                ),
            ],
            const SectionHeader(
              'Volume',
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            ),
            VolumeRow(
              muted: controller.muted,
              volume: controller.volume,
              onToggleMute: controller.toggleMute,
              onVolumeChanged: controller.setVolume,
            ),
            const SectionHeader(
              'Playback speed',
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            ),
            for (final rate in kVodPlaybackRates)
              ListTile(
                title: Text(rate == 1.0 ? 'Normal' : formatPlaybackRate(rate)),
                trailing: controller.playbackRate == rate
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () {
                  controller.setPlaybackRate(rate);
                  Navigator.pop(context);
                },
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: const Text('Copy link at current time'),
              onTap: () async {
                final link = vodShareLink(vod, controller.position);
                Navigator.pop(context);
                await Clipboard.setData(ClipboardData(text: link));
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// `1.25×` (trailing zeros dropped: `1.5×`, `2×`).
String formatPlaybackRate(double rate) {
  final text = rate
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
  return '$text×';
}

class _SpeedChip extends StatelessWidget {
  const _SpeedChip({required this.rate, required this.onTap});

  final double rate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black.withValues(alpha: 0.6),
    borderRadius: BorderRadius.circular(6),
    child: InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          formatPlaybackRate(rate),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ),
    ),
  );
}

class _SkipBadge extends StatelessWidget {
  const _SkipBadge({super.key, required this.forward});

  final bool forward;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0.6, end: 1),
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeOut,
    builder: (context, scale, child) =>
        Transform.scale(scale: scale, child: child),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              forward ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
              color: Colors.white,
            ),
            Text(
              forward ? '+10 s' : '−10 s',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
