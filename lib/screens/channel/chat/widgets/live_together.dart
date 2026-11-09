import 'package:flutter/material.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/live_together.dart';
import 'package:onset/utils/common_utils.dart';
import 'package:onset/widgets/onset_cached_network_image.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';

Future<LiveTogether?> loadLiveTogether({
  required Future<LiveTogether?> Function() guestStar,
  required Future<LiveTogether?> Function() costream,
}) async {
  final results = await Future.wait([guestStar(), costream()]);
  return results.first ?? results.last;
}

String liveTogetherNames(
  LiveTogether roster,
  String channelId,
  AppLocalizations l, {
  int shown = 2,
}) {
  final others = roster.othersThan(channelId);
  final names = others
      .take(shown)
      .map((m) => getReadableName(m.displayName, m.login))
      .join(', ');
  final more =
      others.length - others.take(shown).length + roster.hiddenCount(channelId);
  return more > 0 ? l.liveTogetherNamesMore(names: names, count: more) : names;
}

class LiveTogetherStrip extends StatelessWidget {
  const LiveTogetherStrip({
    super.key,
    required this.roster,
    required this.channelId,
    required this.onOpen,
  });

  static const rowKey = ValueKey('live-together-row');

  final LiveTogether? roster;
  final String channelId;
  final ValueChanged<LiveTogetherMember> onOpen;

  @override
  Widget build(BuildContext context) {
    final roster = this.roster;
    if (roster == null || roster.othersThan(channelId).isEmpty) {
      return const SizedBox.shrink();
    }
    final l = context.l10n;
    final total = roster.totalViewers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetSectionLabel(l.liveTogetherTitle(kind: roster.kind.name)),
        SheetRow(
          key: rowKey,
          glyph: SheetGlyphKind.people,
          label: l.liveTogetherLine(
            kind: roster.kind.name,
            names: liveTogetherNames(roster, channelId, l),
          ),
          detail: total == null ? null : l.liveTogetherTotal(count: total),
          end: SheetRowEnd.chevron,
          onTap: () => showOnsetSheet<void>(
            context: context,
            builder: (_) => LiveTogetherSheet(
              roster: roster,
              channelId: channelId,
              onOpen: onOpen,
            ),
          ),
        ),
      ],
    );
  }
}

class LiveTogetherSheet extends StatelessWidget {
  const LiveTogetherSheet({
    super.key,
    required this.roster,
    required this.channelId,
    required this.onOpen,
  });

  static ValueKey<String> memberKey(String login) =>
      ValueKey('live-together-$login');

  final LiveTogether roster;
  final String channelId;
  final ValueChanged<LiveTogetherMember> onOpen;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = SheetColors.of(context);
    final total = roster.totalViewers;
    return ListView(
      shrinkWrap: true,
      primary: false,
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l.liveTogetherTitle(kind: roster.kind.name),
                  style: SheetText.subtitle.copyWith(color: colors.text),
                ),
              ),
              if (total != null)
                Text(
                  l.liveTogetherTotal(count: total),
                  style: SheetText.rowDetail.copyWith(color: colors.secondary),
                ),
            ],
          ),
        ),
        for (final member in roster.othersThan(channelId))
          SheetRow(
            key: memberKey(member.login),
            leading: _Avatar(url: member.imageUrl),
            label: getReadableName(member.displayName, member.login),
            detail: _detail(member, l),
            end: member.isLive ? SheetRowEnd.chevron : SheetRowEnd.none,
            onTap: member.isLive
                ? () {
                    Navigator.of(context).pop();
                    onOpen(member);
                  }
                : null,
          ),
      ],
    );
  }

  String _detail(LiveTogetherMember member, AppLocalizations l) {
    final viewers = member.viewers;
    final state = viewers == null
        ? l.liveTogetherNotLive
        : l.streamViewers(count: viewers);
    return member.id == roster.host?.id
        ? '${l.liveTogetherHost} · $state'
        : state;
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    return ClipOval(
      child: SizedBox.square(
        dimension: 28,
        child: url == null
            ? ColoredBox(color: SheetColors.of(context).well)
            : OnsetCachedNetworkImage(imageUrl: url, width: 28, height: 28),
      ),
    );
  }
}
