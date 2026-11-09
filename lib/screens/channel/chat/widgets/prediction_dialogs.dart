import 'package:flutter/material.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/community_points.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

final predictionTermsUrl = Uri.parse(
  'https://www.twitch.tv/p/legal/predictions-terms-and-conditions/',
);

enum PredictionCreator { streamer, self, other, unknown }

PredictionCreator predictionCreatorOf(
  Prediction prediction, {
  required String channelId,
  String? viewerId,
}) {
  final creator = prediction.creatorId;
  if (creator == null) return PredictionCreator.unknown;
  if (creator == channelId) return PredictionCreator.streamer;
  if (viewerId != null && creator == viewerId) return PredictionCreator.self;
  return prediction.creatorName == null
      ? PredictionCreator.unknown
      : PredictionCreator.other;
}

class PredictionTermsDialog extends StatelessWidget {
  const PredictionTermsDialog({
    super.key,
    required this.outcome,
    required this.stake,
    required this.stakeLabel,
    required this.pointsName,
    this.restriction = PredictionRestriction.none,
    this.showTerms = true,
  });

  final String outcome;
  final int stake;
  final String stakeLabel;
  final String pointsName;
  final PredictionRestriction restriction;
  final bool showTerms;

  static const acceptKey = ValueKey('prediction-terms-accept');
  static const termsKey = ValueKey('prediction-terms-link');

  bool get _spectator => stake == 0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = SheetColors.of(context);
    final body = SheetText.body.copyWith(color: colors.secondary);
    return OnsetDialog(
      title: _spectator
          ? l.predictionSpectatorTitle(outcome: outcome, pointsName: pointsName)
          : l.predictionTermsTitle(
              outcome: outcome,
              points: stakeLabel,
              pointsName: pointsName,
            ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          if (restriction == PredictionRestriction.regionLocked ||
              restriction == PredictionRestriction.categoryLocked)
            Text(
              l.predictionRegionNotice(
                kind: restriction == PredictionRestriction.categoryLocked
                    ? 'category'
                    : 'region',
                pointsName: pointsName,
              ),
              style: body,
            ),
          Text(
            _spectator
                ? l.predictionSpectatorBody(pointsName: pointsName)
                : l.predictionTermsBody,
            style: body,
          ),
          if (showTerms)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                key: termsKey,
                onPressed: () => launchUrl(
                  predictionTermsUrl,
                  mode: LaunchMode.externalApplication,
                ),
                style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                child: Text(l.predictionTermsLink),
              ),
            ),
        ],
      ),
      actions: [
        SheetButton(
          label: l.predictionTermsDecline,
          tone: SheetButtonTone.text,
          onPressed: () => Navigator.pop(context, false),
        ),
        SheetButton(
          key: acceptKey,
          label: l.predictionTermsAccept,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
  }
}

class PredictionModeratorDialog extends StatelessWidget {
  const PredictionModeratorDialog({
    super.key,
    required this.creator,
    this.creatorName,
  });

  final PredictionCreator creator;
  final String? creatorName;

  static const acceptKey = ValueKey('prediction-moderator-accept');

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return OnsetDialog(
      title: l.predictionModeratorTitle,
      message: l.predictionModeratorBody(
        creator: creator.name,
        name: creatorName ?? '',
      ),
      actions: [
        SheetButton(
          label: l.commonCancel,
          tone: SheetButtonTone.text,
          onPressed: () => Navigator.pop(context, false),
        ),
        SheetButton(
          key: acceptKey,
          label: l.predictionModeratorAccept,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
  }
}

String predictionResultText(
  AppLocalizations l,
  PointsActionResult result, {
  required String outcome,
  required int stake,
  required String pointsName,
}) {
  if (result.isSuccess && stake == 0) {
    return l.predictionSpectatorDone(outcome: outcome, pointsName: pointsName);
  }
  final kind = predictionRefusalKind(result.rawCode);
  if (result.isSuccess || kind == 'other') return result.text(l);
  return l.predictionRefused(kind: kind, reason: result.rawCode ?? '');
}
