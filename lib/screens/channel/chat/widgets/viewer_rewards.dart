import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/community_points.dart';
import 'package:onset/models/unlockable_emote.dart';
import 'package:onset/models/weekly_rewards.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/sheet/onset_panel.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';

class RewardCardFrame extends StatelessWidget {
  const RewardCardFrame({
    super.key,
    required this.glyph,
    required this.title,
    required this.children,
    this.trailing,
  });

  final SheetGlyphKind glyph;
  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
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
                  glyph,
                  strokeWidth: 1.9,
                  color: SheetColors.accentOf(context),
                ),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: rewardText(colors.text, 14, FontWeight.w700),
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

TextStyle rewardText(Color color, double size, FontWeight weight) => TextStyle(
  fontFamily: OnsetTokens.bodyFamily,
  fontSize: size,
  height: 1.35,
  fontWeight: weight,
  color: color,
);

class RewardPillButton extends StatelessWidget {
  const RewardPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.buttonKey,
  });

  final String label;
  final VoidCallback? onPressed;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: TextButton(
      key: buttonKey,
      onPressed: onPressed,
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
      child: Text(label),
    ),
  );
}

String formatRewardNumber(BuildContext context, int value) =>
    NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(value);

class WeeklyRewardsCard extends StatelessWidget {
  const WeeklyRewardsCard({super.key, required this.rewards, this.now});

  final WeeklyRewards rewards;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final l = context.l10n;
    final accent = SheetColors.accentOf(context);
    final current = rewards.currentTier;
    final left = rewards.daysRequiredPerWeek - rewards.daysShown;
    final ends = rewards.endsAt;
    return RewardCardFrame(
      glyph: SheetGlyphKind.star,
      title: l.weeklyRewardsTitle,
      trailing: current == null
          ? null
          : Text(
              l.weeklyRewardsLevel(level: current.tier),
              style: rewardText(accent, 12, FontWeight.w700),
            ),
      children: [
        Text(
          l.weeklyRewardsDays(
            visited: rewards.daysShown,
            required: rewards.daysRequiredPerWeek,
          ),
          style: rewardText(colors.text, 13, FontWeight.w600),
        ),
        Semantics(
          value: l.weeklyRewardsDays(
            visited: rewards.daysShown,
            required: rewards.daysRequiredPerWeek,
          ),
          child: Row(
            spacing: 4,
            children: [
              for (var day = 0; day < rewards.daysRequiredPerWeek; day++)
                Expanded(
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: day < rewards.daysShown ? accent : colors.raised,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Text(
          l.weeklyRewardsStatus(
            status: rewards.status.name,
            count: left < 1 ? 1 : left,
          ),
          style: rewardText(colors.body, 13, FontWeight.w400),
        ),
        for (final tier in rewards.tiers)
          Row(
            spacing: 8,
            children: [
              SizedBox.square(
                dimension: 22,
                child: tier.badgeUrl == null
                    ? null
                    : Image.network(
                        tier.badgeUrl!,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
              ),
              Expanded(
                child: Text(
                  l.weeklyRewardsTier(
                    level: tier.tier,
                    points: formatRewardNumber(context, tier.channelPoints),
                    count: tier.channelPoints,
                  ),
                  style: rewardText(
                    current != null && tier.tier <= current.tier
                        ? colors.text
                        : colors.secondary,
                    12.5,
                    FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        if (ends != null)
          Text(
            l.weeklyRewardsEnds(
              date: DateFormat.yMMMd(
                Localizations.localeOf(context).toLanguageTag(),
              ).format(ends.toLocal()),
            ),
            style: rewardText(colors.secondary, 12, FontWeight.w400),
          ),
      ],
    );
  }
}

class CommunityMomentCard extends StatelessWidget {
  const CommunityMomentCard({super.key, this.onClaim});

  final VoidCallback? onClaim;

  static const claimKey = ValueKey('moment-claim');

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final l = context.l10n;
    return RewardCardFrame(
      glyph: SheetGlyphKind.unique,
      title: l.momentCardTitle,
      children: [
        Text(
          l.momentCardBody,
          style: rewardText(colors.body, 13, FontWeight.w400),
        ),
        RewardPillButton(
          buttonKey: claimKey,
          label: l.momentClaim,
          onPressed: onClaim,
        ),
      ],
    );
  }
}

bool needsEmoteChoice(PointsReward reward) =>
    reward.automaticType == 'CHOSEN_SUB_EMOTE_UNLOCK' ||
    reward.automaticType == 'CHOSEN_MODIFIED_SUB_EMOTE_UNLOCK';

class EmoteUnlockSheet extends StatefulWidget {
  const EmoteUnlockSheet({
    super.key,
    required this.reward,
    required this.load,
    required this.onUnlock,
  });

  final PointsReward reward;
  final Future<List<UnlockableEmote>?> Function() load;
  final ValueChanged<String> onUnlock;

  static ValueKey<String> emoteKey(String id) => ValueKey('emote-unlock-$id');
  static ValueKey<String> modifierKey(String code) =>
      ValueKey('emote-unlock-modifier-$code');
  static const confirmKey = ValueKey('emote-unlock-confirm');

  @override
  State<EmoteUnlockSheet> createState() => _EmoteUnlockSheetState();
}

class _EmoteUnlockSheetState extends State<EmoteUnlockSheet> {
  late final Future<List<UnlockableEmote>?> _emotes = widget.load();
  UnlockableEmote? _picked;
  String? _modifier;

  bool get _modified =>
      widget.reward.automaticType == 'CHOSEN_MODIFIED_SUB_EMOTE_UNLOCK';

  String? get _choice {
    final picked = _picked;
    if (picked == null) return null;
    if (!_modified) return picked.id;
    final modifier = _modifier;
    return modifier == null ? null : picked.modifiedId(modifier);
  }

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final l = context.l10n;
    final panel = SheetPresentation.isPanel(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: panel
            ? double.infinity
            : MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: FutureBuilder<List<UnlockableEmote>?>(
        future: _emotes,
        builder: (context, snapshot) {
          final emotes = snapshot.data;
          final waiting = snapshot.connectionState != ConnectionState.done;
          return ListView(
            shrinkWrap: !panel,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            children: [
              Text(
                l.emoteUnlockTitle(kind: _modified ? 'modified' : 'chosen'),
                style: SheetText.title.copyWith(color: colors.text),
              ),
              const SizedBox(height: 12),
              if (waiting)
                const Center(child: CircularProgressIndicator())
              else if (emotes == null)
                Text(
                  l.emoteUnlockFailed,
                  style: SheetText.body.copyWith(color: colors.secondary),
                )
              else if (emotes.isEmpty)
                Text(
                  l.emoteUnlockEmpty,
                  style: SheetText.body.copyWith(color: colors.secondary),
                )
              else ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final emote in emotes)
                      _EmoteChoice(
                        key: EmoteUnlockSheet.emoteKey(emote.id),
                        url: emote.imageUrl,
                        label: emote.token,
                        selected: _picked?.id == emote.id,
                        onTap: () => setState(() {
                          _picked = emote;
                          _modifier = null;
                        }),
                      ),
                  ],
                ),
                if (_modified && _picked != null) ...[
                  const SizedBox(height: 14),
                  SheetSectionLabel(
                    l.emoteUnlockModifier,
                    padding: const EdgeInsets.only(bottom: 8),
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final code in UnlockableEmote.modifiers)
                        _EmoteChoice(
                          key: EmoteUnlockSheet.modifierKey(code),
                          url: _picked!.modifiedImageUrl(code),
                          label: '${_picked!.token}_$code',
                          selected: _modifier == code,
                          onTap: () => setState(() => _modifier = code),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                SheetButton(
                  key: EmoteUnlockSheet.confirmKey,
                  label: l.emoteUnlockConfirm(
                    points: formatRewardNumber(context, widget.reward.cost),
                    count: widget.reward.cost,
                  ),
                  large: true,
                  expand: true,
                  onPressed: _choice == null
                      ? null
                      : () => widget.onUnlock(_choice!),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _EmoteChoice extends StatelessWidget {
  const _EmoteChoice({
    super.key,
    required this.url,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String url;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? colors.raised : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? SheetColors.accentOf(context) : colors.hairline,
            width: selected ? 2 : OnsetTokens.hairlineWidth,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 48,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Image.network(
                url,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
