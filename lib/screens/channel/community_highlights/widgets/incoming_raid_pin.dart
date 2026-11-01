import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/channel/celebrations/onset_rocket.dart';
import 'package:onset/screens/channel/chat/incoming_raid.dart';
import 'package:onset/screens/channel/community_highlights/raid_text.dart';
import 'package:onset/screens/channel/community_highlights/widgets/raid_avatar.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/motion/motion.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';

/// "X is raiding with N viewers" (incoming pin): a 54 dp row
/// with 14 dp corners, the raider's picture with the ONSET rocket flying
/// in, and a close button. It leaves by itself after a few seconds.
class IncomingRaidPin extends StatelessWidget {
  const IncomingRaidPin({super.key, required this.raid, this.onDismiss});

  final IncomingRaid raid;
  final VoidCallback? onDismiss;

  static const _height = 54.0;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final l = context.l10n;
    final count = raidViewerCount(raid.viewers);
    final viewers = NumberFormat.decimalPattern().format(count);
    final reduceMotion = reduceMotionOf(context);
    final textScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: 1.3);
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Semantics(
        container: true,
        liveRegion: true,
        label: l.raidIncoming(
          count: count,
          name: raid.raiderName,
          viewers: viewers,
        ),
        child: Container(
          constraints: BoxConstraints(minHeight: textScaler.scale(_height)),
          padding: const EdgeInsetsDirectional.only(start: 8, end: 4),
          decoration: ShapeDecoration(
            color: colors.sheet,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: colors.ring,
                width: OnsetTokens.hairlineWidth,
              ),
            ),
          ),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 42,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      top: 4,
                      child: RaidAvatar(
                        name: raid.raiderName,
                        url: raid.avatarUrl,
                        login: raid.raiderLogin,
                        size: 34,
                      ),
                    ),
                    Positioned(
                      right: -4,
                      top: -2,
                      child: reduceMotion
                          ? const OnsetRocket()
                          : const _FlyIn(child: OnsetRocket(flicker: true)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: l10nSpans(
                              l.raidIncoming(
                                count: count,
                                name: l10nMark(0),
                                viewers: l10nMark(1),
                              ),
                              [
                                TextSpan(
                                  text: raid.raiderName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TextSpan(
                                  text: viewers,
                                  style: const TextStyle(
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: OnsetTokens.bodyFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                            color: colors.text,
                          ),
                        ),
                        Text(
                          l.raidSayHi,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: OnsetTokens.bodyFamily,
                            fontSize: 12,
                            height: 1.3,
                            color: colors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  tooltip: l.commonHide,
                  style: IconButton.styleFrom(
                    fixedSize: const Size(40, 40),
                    minimumSize: const Size(40, 40),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: SheetGlyph(
                    SheetGlyphKind.close,
                    size: 14,
                    strokeWidth: 2.2,
                    color: colors.tertiary,
                  ),
                  onPressed: onDismiss,
                )
              else
                const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

/// The rocket flying in from below left (760 ms, from
/// (-26, 26) at half size, fully opaque by 60 %).
class _FlyIn extends StatelessWidget {
  const _FlyIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 760),
      curve: OnsetMotion.standard,
      builder: (context, t, child) => Opacity(
        opacity: (t / 0.6).clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(-26 * (1 - t), 26 * (1 - t)),
          child: Transform.scale(scale: 0.5 + 0.5 * t, child: child),
        ),
      ),
      child: child,
    );
  }
}
