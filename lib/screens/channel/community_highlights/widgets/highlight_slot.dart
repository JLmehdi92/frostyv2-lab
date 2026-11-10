import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/community_highlights.dart';
import 'package:onset/models/report.dart';
import 'package:onset/screens/channel/community_highlights/highlight_stack.dart';
import 'package:onset/screens/channel/community_highlights/stores/community_highlights_store.dart';
import 'package:onset/screens/channel/community_highlights/widgets/gift_bomb_pin.dart';
import 'package:onset/screens/channel/community_highlights/widgets/highlight_cards.dart';
import 'package:onset/screens/channel/community_highlights/widgets/incoming_raid_pin.dart';
import 'package:onset/screens/channel/community_highlights/widgets/raid_card.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/twitch_report.dart';
import 'package:onset/widgets/motion/motion.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';
import 'package:onset/widgets/report/report_sheet.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';
import 'package:onset/widgets/twitch_web_page.dart';

/// Renders a pinned message like chat (the channel screen passes its chat
/// renderer); null falls back to plain text.
typedef PinnedMessageBuilder =
    Widget? Function(BuildContext context, PinnedChatMessage pin);

/// What the viewer calls each kind, in [l]'s language.
String highlightLabel(HighlightKind kind, AppLocalizations l) =>
    l.highlightKind(kind: kind.name);

IconData highlightIcon(HighlightKind kind) => switch (kind) {
  HighlightKind.poll => Icons.poll_outlined,
  HighlightKind.prediction => Icons.emoji_events_outlined,
  HighlightKind.pinned => Icons.push_pin_outlined,
  HighlightKind.raid => Icons.groups_outlined,
  HighlightKind.giftBomb => Icons.card_giftcard_rounded,
  HighlightKind.incomingRaid => Icons.rocket_launch_outlined,
};

void Function(ViewerActionOutcome? outcome) viewerActionReporter(
  BuildContext context, {
  VoidCallback? retry,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l = context.l10n;
  return (outcome) {
    if (outcome == null || outcome == ViewerActionOutcome.done) return;
    final canRetry = retry != null && outcome == ViewerActionOutcome.failed;
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l.viewerActionResult(status: outcome.name)),
          action: canRetry
              ? SnackBarAction(label: l.commonRetry, onPressed: retry)
              : null,
        ),
      );
  };
}

/// The card of [item], or nothing when its data is gone.
Widget buildHighlightCard(
  CommunityHighlightsStore store,
  HighlightItem item, {
  required bool expanded,
  required VoidCallback onToggle,
  required ValueChanged<OutgoingRaid> onWatchRaid,
  PinnedMessageBuilder? pinnedMessage,
  bool dismissible = true,
  bool compact = false,
}) {
  final login = store.channelLogin;
  HighlightCardContext cardFor(BuildContext context) => HighlightCardContext(
    expanded: expanded,
    onToggle: onToggle,
    onDismiss: dismissible ? store.dismissCurrent : null,
    now: store.serverNow,
    onVote: store.canVote
        ? (choiceId) => unawaited(
            store.voteInPoll(choiceId).then(viewerActionReporter(context)),
          )
        : null,
    votedChoiceId: store.votedChoiceId,
    voting: store.voting,
    onTakePart: login == null
        ? null
        : () => TwitchWebPage.open(
            context,
            title: context.l10n.highlightTwitchChat,
            url: Uri.https('www.twitch.tv', '/popout/$login/chat'),
          ),
    onReport: switch (login == null ? null : twitchReportUri(login)) {
      final url? => () => reportFromOnset(
        context,
        target: ReportTarget.channel(
          channelId: store.channelId,
          name: login ?? '',
        ),
        title: context.l10n.reportOnTwitch,
        fallbackUrl: url,
      ),
      null => null,
    },
  );
  // Its own Observer: the data changes without the stack changing.
  return Observer(
    builder: (context) => switch (item.kind) {
      HighlightKind.poll => switch (store.poll) {
        final poll? => PollCard(poll: poll, card: cardFor(context)),
        null => const SizedBox.shrink(),
      },
      HighlightKind.prediction => switch (store.prediction) {
        final prediction? => PredictionCard(
          prediction: prediction,
          card: cardFor(context),
        ),
        null => const SizedBox.shrink(),
      },
      HighlightKind.pinned => switch (store.pinned) {
        final pin? => PinnedCard(
          pin: pin,
          card: cardFor(context),
          message: pinnedMessage?.call(context, pin),
          onUnpin: store.canUnpin ? () => unawaited(store.unpin()) : null,
        ),
        null => const SizedBox.shrink(),
      },
      HighlightKind.raid => switch (store.raid) {
        final raid? => RaidCard(
          raid: raid,
          sourceName:
              store.channelName ?? login ?? context.l10n.highlightThisChannel,
          sourceLogin: login,
          now: store.serverNow,
          onWatch: () {
            if (store.stayingOnRaid) {
              unawaited(
                store.joinRaidAgain().then(viewerActionReporter(context)),
              );
            }
            onWatchRaid(raid.raid);
          },
          onStay: store.onGoAlong == null
              ? null
              : () {
                  void stay() => unawaited(
                    store.stayOnRaid().then(
                      viewerActionReporter(context, retry: stay),
                    ),
                  );
                  stay();
                },
          onDismiss: dismissible ? store.dismissCurrent : null,
          onOpen: compact ? onToggle : null,
          staying: store.stayingOnRaid,
          leaving: store.departing,
          compact: compact,
        ),
        null => const SizedBox.shrink(),
      },
      HighlightKind.giftBomb => switch (store.giftBomb) {
        final banner? => GiftBombPin(
          banner: banner,
          now: store.serverNow,
          onDismiss: dismissible ? store.dismissCurrent : null,
          compact: compact,
        ),
        null => const SizedBox.shrink(),
      },
      HighlightKind.incomingRaid => switch (store.incomingRaid) {
        final banner? => IncomingRaidPin(
          raid: banner.raid,
          onDismiss: dismissible ? store.dismissCurrent : null,
        ),
        null => const SizedBox.shrink(),
      },
    },
  );
}

/// The community highlight above chat: one card, "2 / 3" paging when more
/// are up, and a "New" pill when one arrived behind an expanded card.
///
/// [compact] (landscape side chat, or under a running hype train on a
/// phone) keeps the card collapsed; a tap opens [onOpenDetails] instead.
class HighlightSlot extends StatelessWidget {
  const HighlightSlot({
    super.key,
    required this.store,
    required this.onWatchRaid,
    this.compact = false,
    this.onOpenDetails,
    this.pinnedMessage,
  });

  final CommunityHighlightsStore store;
  final ValueChanged<OutgoingRaid> onWatchRaid;
  final bool compact;
  final VoidCallback? onOpenDetails;
  final PinnedMessageBuilder? pinnedMessage;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Observer(
      builder: (context) {
        final stack = store.stack;
        final item = stack.current;
        if (item == null) return const SizedBox.shrink();
        final card = buildHighlightCard(
          store,
          item,
          expanded: !compact && item.expanded,
          onToggle: compact
              ? (onOpenDetails ?? store.toggleExpanded)
              : store.toggleExpanded,
          onWatchRaid: onWatchRaid,
          pinnedMessage: pinnedMessage,
          compact: compact,
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedSwitcher(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              child: KeyedSubtree(
                key: ValueKey('${item.kind.name}:${item.id}'),
                child: card,
              ),
            ),
            if (stack.items.length > 1) HighlightPager(store: store),
          ],
        );
      },
    );
  }
}

/// The glyph for a highlight kind.
SheetGlyphKind highlightGlyph(HighlightKind kind) => switch (kind) {
  HighlightKind.poll => SheetGlyphKind.poll,
  HighlightKind.prediction => SheetGlyphKind.trophy,
  HighlightKind.pinned => SheetGlyphKind.pin,
  HighlightKind.raid => SheetGlyphKind.people,
  HighlightKind.giftBomb => SheetGlyphKind.gift,
  HighlightKind.incomingRaid => SheetGlyphKind.people,
};

/// "‹ 2 / 3 ›" and the "New poll" pill (a 40 dp
/// row under the card).
class HighlightPager extends StatelessWidget {
  const HighlightPager({super.key, required this.store});

  final CommunityHighlightsStore store;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    Widget arrow({
      required String tooltip,
      required SheetGlyphKind glyph,
      required VoidCallback? onPressed,
    }) => IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        fixedSize: const Size(40, 40),
        minimumSize: const Size(40, 40),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: SheetGlyph(
        glyph,
        size: 18,
        strokeWidth: 2,
        color: onPressed == null ? colors.pagerOff : colors.text,
      ),
    );
    return Observer(
      builder: (context) {
        final stack = store.stack;
        final count = stack.items.length;
        final index = stack.currentIndex;
        final behind = stack.unseen;
        return SizedBox(
          height: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 2,
            children: [
              arrow(
                tooltip: context.l10n.highlightPrevious,
                glyph: SheetGlyphKind.chevronLeft,
                onPressed: index > 0 ? () => store.select(index - 1) : null,
              ),
              Text(
                '${index + 1} / $count',
                semanticsLabel: context.l10n.highlightPosition(
                  index: index + 1,
                  count: count,
                ),
                style: SheetText.tabular(
                  TextStyle(
                    fontFamily: OnsetTokens.bodyFamily,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: colors.body,
                  ),
                ),
              ),
              arrow(
                tooltip: context.l10n.highlightNext,
                glyph: SheetGlyphKind.chevronRight,
                onPressed: index + 1 < count
                    ? () => store.select(index + 1)
                    : null,
              ),
              if (behind != null)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: HighlightNewPill(
                    kind: behind.kind,
                    onPressed: () => store.select(stack.items.indexOf(behind)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// "New prediction": a 30 dp signal pill that pops in when a highlight
/// arrived behind an expanded card.
class HighlightNewPill extends StatefulWidget {
  const HighlightNewPill({
    super.key,
    required this.kind,
    required this.onPressed,
  });

  final HighlightKind kind;
  final VoidCallback onPressed;

  @override
  State<HighlightNewPill> createState() => _HighlightNewPillState();
}

class _HighlightNewPillState extends State<HighlightNewPill>
    with SingleTickerProviderStateMixin {
  late final _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  // Built once, disposed with the pill: not a new listener per build.
  late final _curved = CurvedAnimation(
    parent: _pop,
    curve: OnsetMotion.standard,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pop.status == AnimationStatus.dismissed) {
      _pop.duration = motionDuration(
        context,
        const Duration(milliseconds: 220),
      );
      _pop.forward();
    }
  }

  @override
  void dispose() {
    _curved.dispose();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = SheetColors.accentOf(context);
    final onAccent = SheetColors.onAccentOf(context);
    final curved = _curved;
    final label = context.l10n.highlightNew(kind: widget.kind.name);
    Widget pill = Semantics(
      button: true,
      label: label,
      onTap: widget.onPressed,
      excludeSemantics: true,
      child: Material(
        color: accent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onPressed,
          child: Container(
            height: 30,
            padding: const EdgeInsetsDirectional.only(start: 9, end: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                SheetGlyph(
                  highlightGlyph(widget.kind),
                  size: 14,
                  strokeWidth: 2.2,
                  color: onAccent,
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: OnsetTokens.bodyFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: onAccent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    pill = FadeTransition(opacity: curved, child: pill);
    if (reduceMotionOf(context)) return pill;
    return ScaleTransition(
      scale: Tween(begin: 0.97, end: 1.0).animate(curved),
      child: pill,
    );
  }
}

/// A small pill over the video when chat is hidden: the highlight's kind
/// (and how many are up); a tap opens the details.
class HighlightVideoPill extends StatelessWidget {
  const HighlightVideoPill({
    super.key,
    required this.store,
    required this.onTap,
  });

  final CommunityHighlightsStore store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final item = store.current;
        if (item == null) return const SizedBox.shrink();
        final count = store.stack.items.length;
        final label = highlightLabel(item.kind, context.l10n);
        return Semantics(
          button: true,
          label: count > 1
              ? context.l10n.highlightAndMore(label: label, count: count - 1)
              : label,
          child: Material(
            color: Colors.black.withValues(alpha: 0.6),
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 40),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ExcludeSemantics(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 6,
                      children: [
                        Icon(
                          highlightIcon(item.kind),
                          size: 18,
                          color: Colors.white,
                        ),
                        Text(
                          count > 1 ? '$label +${count - 1}' : label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The highlights in a bottom sheet (from a compact card or the video
/// pill), expanded; it closes by itself when nothing is up any more.
Future<void> showHighlightDetails(
  BuildContext context,
  CommunityHighlightsStore store, {
  required ValueChanged<OutgoingRaid> onWatchRaid,
  PinnedMessageBuilder? pinnedMessage,
}) => showOnsetSheet<void>(
  context: context,
  constraints: const BoxConstraints(maxWidth: 480),
  builder: (context) => _ClosesWhenEmpty(
    store: store,
    child: SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
          child: Observer(
            builder: (context) {
              final item = store.current;
              if (item == null) return const SizedBox.shrink();
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  buildHighlightCard(
                    store,
                    item,
                    expanded: true,
                    onToggle: () {},
                    onWatchRaid: (raid) {
                      Navigator.of(context).pop();
                      onWatchRaid(raid);
                    },
                    pinnedMessage: pinnedMessage,
                    dismissible: false,
                  ),
                  if (store.stack.items.length > 1)
                    HighlightPager(store: store),
                ],
              );
            },
          ),
        ),
      ),
    ),
  ),
);

class _ClosesWhenEmpty extends StatefulWidget {
  const _ClosesWhenEmpty({required this.store, required this.child});

  final CommunityHighlightsStore store;
  final Widget child;

  @override
  State<_ClosesWhenEmpty> createState() => _ClosesWhenEmptyState();
}

class _ClosesWhenEmptyState extends State<_ClosesWhenEmpty> {
  late final ReactionDisposer _dispose;

  @override
  void initState() {
    super.initState();
    _dispose = reaction((_) => widget.store.visible, (bool visible) {
      if (!visible && mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
