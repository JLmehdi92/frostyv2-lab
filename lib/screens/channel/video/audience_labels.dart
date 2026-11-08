import 'package:flutter/material.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/channel/video/player_glyph.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/content_labels.dart';

class AudienceLabels extends StatelessWidget {
  const AudienceLabels({
    super.key,
    required this.labelIds,
    required this.paidPromotion,
    required this.onDismiss,
  });

  final List<String> labelIds;
  final bool paidPromotion;
  final VoidCallback onDismiss;

  bool get isEmpty => labelIds.isEmpty && !paidPromotion;

  @override
  Widget build(BuildContext context) {
    if (isEmpty) return const SizedBox.shrink();
    final l = context.l10n;
    final names = contentLabelNames(labelIds, l);
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsetsDirectional.only(start: 12, end: 2),
      decoration: BoxDecoration(
        color: const Color(0xCC0A0A0A),
        borderRadius: BorderRadius.circular(OnsetTokens.radiusCard),
        border: Border.all(
          color: OnsetTokens.hairlineRaisedDark,
          width: OnsetTokens.hairlineWidth,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PlayerGlyph(
            PlayerGlyphKind.eye,
            color: OnsetTokens.textSecondaryDark,
            size: 16,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (names.isNotEmpty)
                    Text(
                      l.audienceLabelMature(labels: names.join(', ')),
                      style: OnsetType.meta.copyWith(
                        color: OnsetTokens.textBodyDark,
                      ),
                    ),
                  if (paidPromotion)
                    Text(
                      l.audienceLabelPaidPromotion,
                      style: OnsetType.meta.copyWith(
                        color: OnsetTokens.textBodyDark,
                      ),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: l.audienceLabelHide,
            onPressed: onDismiss,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            padding: EdgeInsets.zero,
            icon: const PlayerGlyph(
              PlayerGlyphKind.close,
              color: OnsetTokens.textSecondaryDark,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }
}

String audienceLabelsSignature(List<String> labelIds, bool paidPromotion) =>
    '${labelIds.join('|')}#$paidPromotion';
