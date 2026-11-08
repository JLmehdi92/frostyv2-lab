import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/drop_campaign.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/sheet/onset_panel.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';

String communityDropsLine(
  DropCampaign campaign,
  String channel,
  AppLocalizations l,
) {
  final offer = campaign.offer;
  return switch (offer.kind) {
    CommunityDropsOfferKind.watch => l.communityDropsWatch(
      channel: channel,
      minutes: offer.amount,
    ),
    CommunityDropsOfferKind.subs => l.communityDropsSubs(
      channel: channel,
      count: offer.amount,
    ),
    CommunityDropsOfferKind.turbo => l.communityDropsTurbo(channel: channel),
    CommunityDropsOfferKind.several => l.communityDropsSeveral(
      channel: channel,
    ),
  };
}

class DropsCard extends StatelessWidget {
  const DropsCard({
    super.key,
    required this.campaigns,
    this.claimingDropId,
    this.onClaim,
    this.onLinkAccount,
  });

  final List<DropCampaign> campaigns;
  final String? claimingDropId;
  final ValueChanged<TimedDrop>? onClaim;
  final ValueChanged<Uri>? onLinkAccount;

  static ValueKey<String> claimKey(String dropId) =>
      ValueKey('drops-claim-$dropId');
  static ValueKey<String> linkKey(String campaignId) =>
      ValueKey('drops-link-$campaignId');

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final l = context.l10n;
    final signedOut = campaigns.every(
      (campaign) => campaign.drops.every((drop) => drop.progress == null),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SheetPresentation.isPanel(context)
            ? (dark ? const Color(0xFF202020) : colors.well)
            : colors.well,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.hairline,
          width: OnsetTokens.hairlineWidth,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            Row(
              spacing: 8,
              children: [
                SheetGlyph(
                  SheetGlyphKind.gift,
                  strokeWidth: 1.9,
                  color: SheetColors.accentOf(context),
                ),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l.dropsCardTitle,
                      style: _style(colors.text, 14, FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
            for (final campaign in campaigns) _campaign(context, campaign),
            Text(
              signedOut ? l.dropsSignInForProgress : l.dropsProgressNote,
              style: _style(colors.secondary, 12, FontWeight.w400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _campaign(BuildContext context, DropCampaign campaign) {
    final colors = SheetColors.of(context);
    final l = context.l10n;
    final ends = campaign.endAt;
    final link = campaign.accountLinkUrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        Text(
          campaign.gameName.isEmpty
              ? campaign.name
              : '${campaign.name} · ${campaign.gameName}',
          style: _style(colors.text, 13, FontWeight.w600),
        ),
        if (ends != null)
          Text(
            l.dropsEndsOn(
              date: DateFormat.yMMMd(
                Localizations.localeOf(context).toLanguageTag(),
              ).format(ends.toLocal()),
            ),
            style: _style(colors.secondary, 12, FontWeight.w400),
          ),
        for (final drop in campaign.drops) _drop(context, drop),
        if (campaign.isAccountConnected == false && link != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: linkKey(campaign.id),
              onPressed: onLinkAccount == null
                  ? null
                  : () => onLinkAccount!(link),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 44),
                foregroundColor: SheetColors.accentOf(context),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(l.dropsLinkAccount),
            ),
          ),
      ],
    );
  }

  Widget _drop(BuildContext context, TimedDrop drop) {
    final colors = SheetColors.of(context);
    final l = context.l10n;
    final progress = drop.progress;
    final state = drop.state;
    final detail = switch (state) {
      DropState.claimed => l.dropsClaimed,
      DropState.locked => l.dropsLocked,
      DropState.claimable => null,
      _ when drop.requiredMinutes > 0 => l.dropsMinutesLeft(
        minutes: drop.minutesLeft,
      ),
      _ when drop.requiredSubs > 0 => l.dropsSubsProgress(
        current: progress?.subs ?? 0,
        total: drop.requiredSubs,
      ),
      _ => null,
    };
    return Row(
      spacing: 10,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 4,
            children: [
              Text(
                drop.rewardName,
                style: _style(colors.text, 13, FontWeight.w500),
              ),
              if (progress != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: drop.fraction,
                    minHeight: 4,
                    color: SheetColors.accentOf(context),
                    backgroundColor: colors.hairline,
                  ),
                ),
              if (detail != null)
                Text(
                  detail,
                  style: _style(colors.secondary, 12, FontWeight.w400),
                ),
            ],
          ),
        ),
        if (state == DropState.claimable)
          claimingDropId == drop.id
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : TextButton(
                  key: claimKey(drop.id),
                  onPressed: onClaim == null || claimingDropId != null
                      ? null
                      : () => onClaim!(drop),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    backgroundColor: SheetColors.accentOf(context),
                    foregroundColor: SheetColors.onAccentOf(context),
                    shape: const StadiumBorder(),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                      fontFamily: OnsetTokens.bodyFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(l.dropsClaim),
                ),
      ],
    );
  }

  static TextStyle _style(Color color, double size, FontWeight weight) =>
      TextStyle(
        fontFamily: OnsetTokens.bodyFamily,
        fontSize: size,
        height: 1.35,
        fontWeight: weight,
        color: color,
      );
}
