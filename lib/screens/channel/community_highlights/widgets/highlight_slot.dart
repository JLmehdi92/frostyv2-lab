import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/models/community_highlights.dart';
import 'package:frosty/screens/channel/community_highlights/highlight_stack.dart';
import 'package:frosty/screens/channel/community_highlights/stores/community_highlights_store.dart';
import 'package:frosty/screens/channel/community_highlights/widgets/highlight_cards.dart';
import 'package:frosty/utils/modal_bottom_sheet.dart';
import 'package:frosty/widgets/twitch_web_page.dart';
import 'package:mobx/mobx.dart';

/// Renders a pinned message like chat (the channel screen passes its chat
/// renderer); null falls back to plain text.
typedef PinnedMessageBuilder =
    Widget? Function(BuildContext context, PinnedChatMessage pin);

/// What the viewer calls each kind.
String highlightLabel(HighlightKind kind) => switch (kind) {
  HighlightKind.poll => 'Poll',
  HighlightKind.prediction => 'Prediction',
  HighlightKind.pinned => 'Pinned',
  HighlightKind.raid => 'Raid',
  HighlightKind.giftBomb => 'Gift Subs',
};

IconData highlightIcon(HighlightKind kind) => switch (kind) {
  HighlightKind.poll => Icons.poll_outlined,
  HighlightKind.prediction => Icons.emoji_events_outlined,
  HighlightKind.pinned => Icons.push_pin_outlined,
  HighlightKind.raid => Icons.groups_outlined,
  HighlightKind.giftBomb => Icons.card_giftcard_rounded,
};

/// The card of [item], or nothing when its data is gone.
Widget buildHighlightCard(
  CommunityHighlightsStore store,
  HighlightItem item, {
  required bool expanded,
  required VoidCallback onToggle,
  required ValueChanged<OutgoingRaid> onWatchRaid,
  PinnedMessageBuilder? pinnedMessage,
  bool dismissible = true,
}) {
  final login = store.channelLogin;
  HighlightCardContext cardFor(BuildContext context) => HighlightCardContext(
    expanded: expanded,
    onToggle: onToggle,
    onDismiss: dismissible ? store.dismissCurrent : null,
    now: store.serverNow,
    onTakePart: login == null
        ? null
        : () => TwitchWebPage.open(
            context,
            title: 'Twitch chat',
            url: Uri.https('www.twitch.tv', '/popout/$login/chat'),
          ),
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
        ),
        null => const SizedBox.shrink(),
      },
      HighlightKind.raid => switch (store.raid) {
        final raid? => RaidCard(
          raid: raid,
          card: cardFor(context),
          onWatch: () => onWatchRaid(raid.raid),
          onStay: store.onGoAlong == null ? null : store.stayOnRaid,
          staying: store.stayingOnRaid,
        ),
        null => const SizedBox.shrink(),
      },
      HighlightKind.giftBomb => switch (store.giftBomb) {
        final banner? => GiftBombCard(banner: banner, card: cardFor(context)),
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

/// "‹ 2 / 3 ›" and the "New poll" pill.
class HighlightPager extends StatelessWidget {
  const HighlightPager({super.key, required this.store});

  final CommunityHighlightsStore store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Observer(
      builder: (context) {
        final stack = store.stack;
        final count = stack.items.length;
        final index = stack.currentIndex;
        final behind = stack.unseen;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Previous highlight',
              visualDensity: VisualDensity.compact,
              onPressed: index > 0 ? () => store.select(index - 1) : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Text(
              '${index + 1} / $count',
              semanticsLabel: 'Highlight ${index + 1} of $count',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            IconButton(
              tooltip: 'Next highlight',
              visualDensity: VisualDensity.compact,
              onPressed: index + 1 < count
                  ? () => store.select(index + 1)
                  : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
            if (behind != null)
              ActionChip(
                avatar: Icon(
                  highlightIcon(behind.kind),
                  size: 16,
                  color: scheme.onPrimary,
                ),
                label: Text('New ${highlightLabel(behind.kind).toLowerCase()}'),
                labelStyle: TextStyle(color: scheme.onPrimary),
                backgroundColor: scheme.primary,
                onPressed: () => store.select(stack.items.indexOf(behind)),
              ),
          ],
        );
      },
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
        final label = highlightLabel(item.kind);
        return Semantics(
          button: true,
          label: count > 1 ? '$label and ${count - 1} more' : label,
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
}) => showModalBottomSheetWithProperFocus<void>(
  context: context,
  isScrollControlled: true,
  constraints: const BoxConstraints(maxWidth: 480),
  builder: (context) => _ClosesWhenEmpty(
    store: store,
    child: SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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
