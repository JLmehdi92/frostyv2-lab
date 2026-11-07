import 'package:flutter/material.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/user.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/common_utils.dart';
import 'package:onset/widgets/onset_cached_network_image.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';

class SharedChatBanner extends StatelessWidget {
  const SharedChatBanner({
    super.key,
    required this.partners,
    required this.onDismiss,
  });

  final List<UserTwitch> partners;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = SheetColors.of(context);
    final accent = SheetColors.accentOf(context);
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
        padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 4, 10),
        decoration: BoxDecoration(
          color: colors.raised,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors.ring,
            width: OnsetTokens.hairlineWidth,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: SheetGlyph(SheetGlyphKind.people, size: 16, color: accent),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 3,
                children: [
                  Text(
                    l.sharedChatStarted,
                    style: SheetText.row.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.text,
                    ),
                  ),
                  if (partners.isNotEmpty) ...[
                    Text(
                      l.sharedChatStartedBody(count: partners.length),
                      style: SheetText.rowDetail.copyWith(
                        color: colors.secondary,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: SharedChatChannels(channels: partners),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: l.commonHide,
              style: IconButton.styleFrom(
                fixedSize: const Size(40, 40),
                minimumSize: const Size(40, 40),
                padding: EdgeInsets.zero,
              ),
              onPressed: onDismiss,
              icon: SheetGlyph(
                SheetGlyphKind.close,
                size: 18,
                strokeWidth: 2,
                color: colors.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SharedChatChannels extends StatelessWidget {
  const SharedChatChannels({super.key, required this.channels});

  final List<UserTwitch> channels;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final channel in channels)
          Container(
            constraints: const BoxConstraints(minHeight: 26),
            padding: const EdgeInsetsDirectional.fromSTEB(3, 3, 10, 3),
            decoration: ShapeDecoration(
              color: colors.chip,
              shape: StadiumBorder(
                side: BorderSide(
                  color: colors.ring,
                  width: OnsetTokens.hairlineWidth,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                ClipOval(
                  child: SizedBox.square(
                    dimension: 20,
                    child: channel.profileImageUrl.isEmpty
                        ? ColoredBox(color: colors.well)
                        : OnsetCachedNetworkImage(
                            imageUrl: channel.profileImageUrl,
                            width: 20,
                            height: 20,
                          ),
                  ),
                ),
                Flexible(
                  child: Text(
                    getReadableName(channel.displayName, channel.login),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SheetText.rowDetail.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class SharedChatStrip extends StatelessWidget {
  const SharedChatStrip({super.key, required this.channels});

  final List<UserTwitch> channels;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      SheetSectionLabel(context.l10n.sharedChatWith),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: SharedChatChannels(channels: channels),
      ),
    ],
  );
}
