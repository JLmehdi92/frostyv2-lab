import 'package:flutter/material.dart' as material show Clip;
import 'package:flutter/material.dart' hide Clip;
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/clip.dart';
import 'package:onset/screens/channel/channel.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/screens/vod/vod_time.dart';
import 'package:onset/screens/vod/widgets/video_glyph.dart';
import 'package:onset/screens/vod/widgets/video_kit.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/twitch_report.dart';
import 'package:onset/widgets/motion/press_scale.dart';
import 'package:onset/widgets/profile_picture.dart';

/// Title, views and age, category, channel and clipper, and the actions of
/// a clip under the player: Watch full video, Copy link and
/// Share.
class ClipInfoPanel extends StatelessWidget {
  const ClipInfoPanel({
    super.key,
    required this.clip,
    required this.onCopyLink,
    required this.onShare,
    this.onWatchFullVideo,
    this.onDownload,
    this.autoClip = false,
    this.onWatchPortrait,
    this.onComments,
  });

  final bool autoClip;
  final VoidCallback? onWatchPortrait;
  final VoidCallback? onComments;

  final VoidCallback? onDownload;

  final Clip clip;
  final VoidCallback onCopyLink;
  final VoidCallback onShare;

  /// Opens the VOD at the clip; null when the VOD is gone.
  final VoidCallback? onWatchFullVideo;

  void _openChannel(BuildContext context) {
    if (clip.broadcasterId.isEmpty || clip.broadcasterLogin.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: VideoChat.routeName),
        builder: (context) => VideoChat(
          userId: clip.broadcasterId,
          userName: clip.broadcasterDisplayName,
          userLogin: clip.broadcasterLogin,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final l = context.l10n;
    final details = [
      l.videoViews(count: clip.viewCount),
      formatTimeAgo(clip.createdAt, l),
    ].join(' · ');
    final gameId = clip.gameId;
    final gameName = clip.gameName;
    final curator = clip.curatorDisplayName;
    final title = clip.title.trim().isEmpty
        ? l.clipUntitled
        : clip.title.trim();
    final channel = clip.broadcasterDisplayName.isNotEmpty
        ? clip.broadcasterDisplayName
        : clip.broadcasterLogin;
    final watchFull = onWatchFullVideo;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colors.hairline,
            width: OnsetTokens.hairlineWidth,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: OnsetTokens.displayFamily,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.16,
                height: 1.3,
                color: colors.text,
              ),
            ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(
                  details,
                  style: OnsetType.tabular(
                    TextStyle(
                      fontFamily: OnsetTokens.bodyFamily,
                      fontSize: 13,
                      height: 1.3,
                      color: colors.secondary,
                    ),
                  ),
                ),
                if (gameId != null && gameName != null)
                  VideoCategoryChip(name: gameName, gameId: gameId, height: 26),
                if (clip.vodId != null)
                  ClipOriginPill(label: l.clipFromPastBroadcast),
                if (autoClip)
                  ClipOriginPill(
                    key: const ValueKey('clip-auto'),
                    label: l.clipAutoLabel,
                  ),
              ],
            ),
            if (clip.broadcasterLogin.isNotEmpty)
              Semantics(
                button: true,
                label: curator == null
                    ? l.clipOpenChannel(channel: channel)
                    : l.clipOpenChannelClippedBy(
                        channel: channel,
                        curator: curator,
                      ),
                onTap: () => _openChannel(context),
                excludeSemantics: true,
                child: PressScale(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openChannel(context),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Row(
                        spacing: 10,
                        children: [
                          ProfilePicture(
                            userLogin: clip.broadcasterLogin,
                            radius: 16,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              spacing: 1,
                              children: [
                                Text(
                                  channel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: OnsetTokens.bodyFamily,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: colors.text,
                                  ),
                                ),
                                if (curator != null)
                                  Text(
                                    l.clipClippedBy(curator: curator),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: OnsetTokens.bodyFamily,
                                      fontSize: 12,
                                      color: colors.secondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          VideoGlyph(
                            VideoGlyphKind.chevronRight,
                            color: colors.secondary,
                            size: 16,
                            strokeWidth: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 2),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (watchFull != null)
                  VideoActionPill(
                    glyph: VideoGlyphKind.broadcast,
                    label: l.clipWatchFullVideo,
                    raised: true,
                    onTap: watchFull,
                  ),
                VideoActionPill(
                  glyph: VideoGlyphKind.link,
                  label: l.clipCopyLink,
                  raised: true,
                  onTap: onCopyLink,
                ),
                _ShareDisc(onTap: onShare),
                if (onComments != null)
                  VideoActionPill(
                    key: const ValueKey('clip-comments'),
                    glyph: VideoGlyphKind.comment,
                    label: l.clipComments,
                    raised: true,
                    onTap: onComments,
                  ),
                if (onWatchPortrait != null)
                  VideoActionPill(
                    key: const ValueKey('clip-portrait'),
                    glyph: VideoGlyphKind.portrait,
                    label: l.clipWatchPortrait,
                    raised: true,
                    onTap: onWatchPortrait,
                  ),
                if (onDownload != null)
                  VideoActionPill(
                    key: const ValueKey('clip-download'),
                    glyph: VideoGlyphKind.download,
                    label: l.clipDownload,
                    raised: true,
                    onTap: onDownload,
                  ),
                VideoActionPill(
                  key: const ValueKey('clip-report'),
                  glyph: VideoGlyphKind.alert,
                  label: l.clipReport,
                  raised: true,
                  onTap: () => openTwitchReport(
                    context,
                    title: l.clipReport,
                    url: Uri.https('clips.twitch.tv', '/${clip.slug}'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Share in a 40 dp disc.
class _ShareDisc extends StatelessWidget {
  const _ShareDisc({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    return Tooltip(
      message: context.l10n.clipShare,
      child: PressScale(
        child: Material(
          color: colors.raised,
          shape: CircleBorder(
            side: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? OnsetTokens.hairlineStrongDark
                  : colors.pillBorder,
              width: OnsetTokens.hairlineWidth,
            ),
          ),
          clipBehavior: material.Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox.square(
              dimension: 40,
              child: Center(
                child: VideoGlyph(
                  VideoGlyphKind.share,
                  color: colors.text,
                  size: 16,
                  strokeWidth: 1.9,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ClipOriginPill extends StatelessWidget {
  const ClipOriginPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: colors.pillBorder,
          width: OnsetTokens.hairlineWidth,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: OnsetTokens.bodyFamily,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colors.secondary,
        ),
      ),
    );
  }
}
