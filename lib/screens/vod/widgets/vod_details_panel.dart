import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/l10n/enum_labels.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/vod.dart';
import 'package:onset/screens/channel_profile/channel_profile_screen.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/vod/player_media.dart';
import 'package:onset/screens/vod/stores/ivs_vod_store.dart';
import 'package:onset/screens/vod/vod_overlay.dart';
import 'package:onset/screens/vod/vod_player_controller.dart';
import 'package:onset/screens/vod/widgets/video_glyph.dart';
import 'package:onset/screens/vod/widgets/video_kit.dart';
import 'package:onset/screens/vod/widgets/vod_info_strip.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/share_link.dart';
import 'package:onset/widgets/alert_message.dart';
import 'package:onset/widgets/motion/press_scale.dart';
import 'package:onset/widgets/profile_picture.dart';

/// A tablet's area around the VOD: the title,
/// category and views, the channel's card with "Open channel", the player's
/// actions as pills (copy the link at the current time, share, speed,
/// quality, captions) and, under a landscape video, what the player does
/// (muted parts, double taps, Up Next).
class VodDetailsPanel extends StatelessWidget {
  const VodDetailsPanel({
    super.key,
    required this.vod,
    required this.player,
    required this.settings,
    this.mutedSegments = const [],
    this.upNext = false,
    this.legend = true,
  });

  final Vod vod;

  /// Null while there is no player (loading, the content warning).
  final VodPlayerController? player;
  final SettingsStore settings;
  final List<MutedSegment> mutedSegments;

  /// Whether something plays next at the end (not for a recording).
  final bool upNext;

  /// The line about the player's gestures at the bottom.
  final bool legend;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final content = SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 18, 24, legend ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          VodInfoStrip(
            vod: vod,
            large: true,
            padding: EdgeInsets.zero,
            divider: false,
          ),
          if (vod.ownerLogin.isNotEmpty) _ChannelCard(vod: vod),
          _Actions(vod: vod, player: player),
        ],
      ),
    );
    if (!legend) return content;
    // The legend stays at the bottom; what is above scrolls when short.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: content),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          // Its own observer: the autoplay setting can change meanwhile.
          child: Observer(
            builder: (context) => _Legend(
              colors: colors,
              muted: mutedSegments.isNotEmpty,
              upNext: upNext ? settings.vodAutoplay : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// The channel's picture and name, and "Open channel" (its profile).
class _ChannelCard extends StatelessWidget {
  const _ChannelCard({required this.vod});

  final Vod vod;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final name = vod.ownerDisplayName.isNotEmpty
        ? vod.ownerDisplayName
        : vod.ownerLogin;
    void openChannel() => ChannelProfileScreen.open(
      context,
      login: vod.ownerLogin,
      userId: vod.ownerId.isEmpty ? null : vod.ownerId,
      displayName: name,
    );
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 12, 12),
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
          ProfilePicture(userLogin: vod.ownerLogin),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: OnsetTokens.bodyFamily,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colors.text,
              ),
            ),
          ),
          Semantics(
            button: true,
            label: 'Open channel',
            onTap: openChannel,
            excludeSemantics: true,
            child: PressScale(
              child: Material(
                color: colors.raised,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: colors.pillBorder,
                    width: OnsetTokens.hairlineWidth,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: openChannel,
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 6,
                      children: [
                        Text(
                          'Open channel',
                          style: TextStyle(
                            fontFamily: OnsetTokens.bodyFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.text,
                          ),
                        ),
                        VideoGlyph(
                          VideoGlyphKind.chevronRight,
                          color: colors.text,
                          size: 14,
                          strokeWidth: 2.2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The player's actions as pills.
class _Actions extends StatelessWidget {
  const _Actions({required this.vod, required this.player});

  final Vod vod;
  final VodPlayerController? player;

  Duration get _position => player?.position ?? Duration.zero;

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: vodShareLink(vod, _position)));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: AlertMessage(message: 'Link copied', centered: false),
        ),
      );
  }

  void _openSettings(BuildContext context, VodPlayerController player) {
    player.showOverlay();
    unawaited(
      showVodSettingsSheet(
        context,
        controller: player,
        media: PlayerMedia.vod(vod),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = this.player;
    return Observer(
      builder: (context) {
        final rate = player?.playbackRate ?? 1;
        final qualities = player?.qualities ?? const <String>[];
        final quality = player?.quality;
        final captions = player is IvsVodStore ? player.captions : null;
        final captionsOn = captions?.enabled ?? false;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            VideoActionPill(
              glyph: VideoGlyphKind.link,
              label: 'Copy link at current time',
              onTap: () => unawaited(_copyLink(context)),
            ),
            VideoActionPill(
              glyph: VideoGlyphKind.share,
              label: 'Share',
              onTap: () => unawaited(
                shareLink(
                  context,
                  vodShareLink(vod, _position),
                  subject: vod.title,
                ),
              ),
            ),
            if (player != null) ...[
              VideoActionPill(
                glyph: VideoGlyphKind.speed,
                label:
                    'Speed '
                    '${rate == 1.0 ? 'Normal' : formatPlaybackRate(rate)}',
                selected: rate != 1.0,
                onTap: () => _openSettings(context, player),
              ),
              if (qualities.length > 1 && quality != null)
                VideoActionPill(
                  glyph: VideoGlyphKind.settings,
                  label: 'Quality $quality',
                  onTap: () => _openSettings(context, player),
                ),
              if (captions != null)
                VideoActionPill(
                  glyph: VideoGlyphKind.captions,
                  label: 'Closed Captions',
                  selected: captionsOn,
                  semanticsLabel:
                      'Closed Captions, ${captionsOn ? 'on' : 'off'}',
                  onTap: () {
                    HapticFeedback.selectionClick();
                    captions.setEnabled(!captionsOn);
                  },
                ),
            ],
          ],
        );
      },
    );
  }
}

/// What the player does, in the tertiary grey: the muted parts' tick, the
/// double taps, Up Next and its setting.
class _Legend extends StatelessWidget {
  const _Legend({
    required this.colors,
    required this.muted,
    required this.upNext,
  });

  final FeedColors colors;
  final bool muted;
  final VodAutoplay? upNext;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: OnsetTokens.bodyFamily,
      fontSize: 12,
      height: 1.3,
      color: colors.tertiary,
    );
    final upNext = this.upNext;
    return Wrap(
      spacing: 18,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (muted)
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              Container(
                width: 16,
                height: 2,
                decoration: BoxDecoration(
                  color: colors.body,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              Text('Muted parts (copyright)', style: style),
            ],
          ),
        Text('Double-tap the sides to skip 10 s', style: style),
        if (upNext != null)
          Text(
            upNext == VodAutoplay.never
                ? 'Up Next at the end'
                // English, like the rest of the panel, until it is
                // translated.
                : 'Up Next at the end · ${upNext.label(L10n.untranslated)}',
            style: style,
          ),
      ],
    );
  }
}
