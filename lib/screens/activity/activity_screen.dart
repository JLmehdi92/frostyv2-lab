import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/l10n/enum_labels.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/activity/stores/activity_store.dart';
import 'package:onset/screens/home/stores/home_store.dart';
import 'package:onset/screens/vod/vod_time.dart';
import 'package:onset/screens/whispers/whisper_kit.dart';
import 'package:onset/screens/whispers/whispers_screen.dart';
import 'package:onset/services/notifications/activity_log.dart';
import 'package:onset/stores/whisper_store.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/motion/haptics.dart';
import 'package:onset/widgets/motion/motion.dart';
import 'package:onset/widgets/motion/press_scale.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';
import 'package:onset/widgets/profile_picture.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';
import 'package:onset/widgets/state_glyph.dart';
import 'package:onset/widgets/state_views.dart';

/// Twitch's Activity: the
/// notifications (here, those ONSET posted on this device: go-live,
/// mentions, reminders) and, when logged in, the whispers. A section of
/// the navigation shell; on a phone its header holds the tabs
/// ([activityTabBadge]), on a tablet the whispers are a column beside the
/// notifications.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({
    super.key,
    required this.store,
    required this.onOpenChannel,
    this.whispers,
    this.tab = ActivityTab.notifications,
    this.active = true,
    this.now = DateTime.now,
  });

  final ActivityStore store;

  /// The viewer's whispers; null when logged out (no Whispers tab).
  final WhisperStore? whispers;

  /// Opens a channel by login.
  final void Function(String login) onOpenChannel;

  /// The tab on screen on a phone (Whispers only with [whispers]).
  final ActivityTab tab;

  /// Whether Activity is the section on screen and nothing covers it:
  /// opening it, and anything arriving while it is open (and the app in
  /// front), clears the count on the bar.
  final bool active;

  final DateTime Function() now;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

/// The count after [tab]'s name in the header: its unread.
int activityTabBadge(
  ActivityTab tab, {
  required ActivityStore store,
  WhisperStore? whispers,
}) => switch (tab) {
  ActivityTab.notifications => store.unreadCount,
  ActivityTab.whispers => whispers?.unreadCount ?? 0,
};

class _ActivityScreenState extends State<ActivityScreen> {
  ReactionDisposer? _disposeSeen;
  late final AppLifecycleListener _lifecycle;

  /// On screen: the section is Activity, nothing covers it, the app is in
  /// front.
  bool get _seen =>
      widget.active &&
      (WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed) ==
          AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    if (_seen) _opened();
    // Seen while open: what arrives meanwhile does not count as new.
    _disposeSeen = reaction((_) => widget.store.newCount, (int count) {
      if (_seen && count > 0) unawaited(widget.store.markViewed());
    });
    // Back in front on Activity: what came meanwhile is seen now.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (widget.active) _opened();
      },
    );
  }

  @override
  void didUpdateWidget(ActivityScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _opened();
  }

  /// Seen: the bar's count goes, the unread stay bold until opened.
  void _opened() =>
      unawaited(widget.store.refresh().then((_) => widget.store.markViewed()));

  /// The phone's two tabs keep their scroll while the other one shows.
  final _notificationsScroll = ScrollController();
  final _whispersScroll = ScrollController();

  /// Whispers was shown on this phone page: it stays built (its list is
  /// in memory, nothing is loaded for it).
  var _whispersBuilt = false;

  @override
  void dispose() {
    _lifecycle.dispose();
    _disposeSeen?.call();
    _notificationsScroll.dispose();
    _whispersScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final whispers = widget.whispers;
    final notifications = _NotificationsList(
      store: widget.store,
      onOpenChannel: widget.onOpenChannel,
      now: widget.now,
      tablet: context.isLargeScreen,
    );
    if (context.isLargeScreen) {
      return _TabletActivity(
        notifications: notifications,
        store: widget.store,
        whispers: whispers,
      );
    }
    final showWhispers = whispers != null && widget.tab == ActivityTab.whispers;
    if (whispers == null) {
      _whispersBuilt = false;
    } else if (showWhispers) {
      _whispersBuilt = true;
    }
    // Both kept, each with its own scroll: switching tabs never resets
    // either. Each list scrolls with its own primary controller (as the
    // page's only list did).
    return IndexedStack(
      index: showWhispers ? 1 : 0,
      sizing: StackFit.expand,
      children: [
        TickerMode(
          enabled: !showWhispers,
          child: PrimaryScrollController(
            controller: _notificationsScroll,
            child: notifications,
          ),
        ),
        if (whispers != null && _whispersBuilt)
          TickerMode(
            enabled: showWhispers,
            child: PrimaryScrollController(
              controller: _whispersScroll,
              child: WhispersList(store: whispers),
            ),
          )
        else
          const SizedBox.shrink(),
      ],
    );
  }
}

/// The colours of Activity, dark and light.
@immutable
class _ActivityColors {
  const _ActivityColors({
    required this.ground,
    required this.card,
    required this.cardRing,
    required this.raised,
    required this.ring,
    required this.text,
    required this.body,
    required this.secondary,
    required this.tertiary,
    required this.menu,
  });

  final Color ground;
  final Color card;
  final Color cardRing;
  final Color raised;
  final Color ring;
  final Color text;
  final Color body;
  final Color secondary;
  final Color tertiary;
  final Color menu;

  /// The whispers' greys (one palette for the two columns), with the
  /// page's ground and the raised pill's ring.
  factory _ActivityColors.of(BuildContext context) {
    final theme = Theme.of(context);
    final shared = WhisperColors.of(context);
    final dark = theme.brightness == Brightness.dark;
    return _ActivityColors(
      ground: theme.scaffoldBackgroundColor,
      card: shared.card,
      cardRing: shared.paneRing,
      raised: shared.raised,
      ring: dark ? OnsetTokens.hairlineStrongDark : const Color(0x1F000000),
      text: shared.text,
      body: shared.body,
      secondary: shared.secondary,
      tertiary: shared.tertiary,
      menu: dark ? shared.raised : shared.card,
    );
  }
}

/// The notifications: "Most Recent" (the last day) then "Earlier", like
/// Twitch's; rows on a phone, cards on a tablet.
class _NotificationsList extends StatefulWidget {
  const _NotificationsList({
    required this.store,
    required this.onOpenChannel,
    required this.now,
    required this.tablet,
  });

  final ActivityStore store;
  final void Function(String login) onOpenChannel;
  final DateTime Function() now;
  final bool tablet;

  @override
  State<_NotificationsList> createState() => _NotificationsListState();
}

class _NotificationsListState extends State<_NotificationsList> {
  /// Rows folding away, kept on screen while they fold: the notification
  /// itself is removed at once (the fold is only the look), so leaving the
  /// list mid-fold cannot bring it back.
  final _folding = <String, ActivityEntry>{};

  void _open(ActivityEntry entry) {
    unawaited(widget.store.markRead(entry.id));
    final login = entry.login;
    if (login != null) widget.onOpenChannel(login);
  }

  /// "Remove notification": removed, and the row folds (300 ms).
  void _remove(ActivityEntry entry) {
    unawaited(widget.store.remove(entry.id));
    if (reduceMotionOf(context)) return;
    setState(() => _folding[entry.id] = entry);
  }

  /// Folded: the row goes (it comes back if storage refused the removal).
  void _folded(String id) {
    if (mounted) setState(() => _folding.remove(id));
  }

  Future<void> _menu(BuildContext rowContext, ActivityEntry entry) async {
    Haptics.selection();
    final bool? remove;
    if (widget.tablet) {
      remove = await _showPopover(rowContext, entry);
    } else {
      remove = await showOnsetSheet<bool>(
        context: rowContext,
        builder: (context) => _RemoveSheet(entry: entry),
      );
    }
    if (remove == true && mounted) _remove(entry);
  }

  /// The tablet's menu, at the row's top right.
  Future<bool?> _showPopover(BuildContext rowContext, ActivityEntry entry) {
    final colors = _ActivityColors.of(context);
    final box = rowContext.findRenderObject()! as RenderBox;
    final overlay =
        Navigator.of(rowContext).overlay!.context.findRenderObject()!
            as RenderBox;
    final topRight = box.localToGlobal(
      Offset(box.size.width - 18, 46),
      ancestor: overlay,
    );
    return showMenu<bool>(
      context: rowContext,
      position: RelativeRect.fromLTRB(
        topRight.dx - 230,
        topRight.dy,
        overlay.size.width - topRight.dx,
        overlay.size.height - topRight.dy,
      ),
      color: colors.menu,
      elevation: 12,
      constraints: const BoxConstraints(minWidth: 230),
      menuPadding: const EdgeInsets.all(6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.ring, width: OnsetTokens.hairlineWidth),
      ),
      items: [
        PopupMenuItem<bool>(
          value: true,
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              StateGlyph(StateGlyphKind.trash, color: colors.text, size: 18),
              const SizedBox(width: 10),
              Text(
                context.l10n.activityRemove,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tablet = widget.tablet;
    final colors = _ActivityColors.of(context);
    return Observer(
      builder: (context) {
        final store = widget.store;
        final stored = store.entries;
        final ids = {for (final e in stored) e.id};
        // The rows still folding away are shown in their place.
        final entries = [
          ...stored,
          for (final e in _folding.values)
            if (!ids.contains(e.id)) e,
        ]..sort((a, b) => b.at.compareTo(a.at));
        final at = widget.now();
        // Twitch splits at a day: "Most Recent", then "Earlier".
        final recent = [
          for (final e in entries)
            if (at.difference(e.at) <= const Duration(days: 1)) e,
        ];
        final earlier = [
          for (final e in entries)
            if (at.difference(e.at) > const Duration(days: 1)) e,
        ];
        final unread = store.unreadCount;

        Widget row(ActivityEntry entry) => _Folding(
          key: ValueKey(entry.id),
          folding: _folding.containsKey(entry.id),
          onFolded: () => _folded(entry.id),
          child: Builder(
            builder: (rowContext) => _EntryRow(
              entry: entry,
              now: at,
              tablet: tablet,
              colors: colors,
              onTap: () => _open(entry),
              onMenu: () => unawaited(_menu(rowContext, entry)),
            ),
          ),
        );

        final padding = MediaQuery.paddingOf(context);
        if (entries.isEmpty) {
          return RefreshIndicator.adaptive(
            edgeOffset: padding.top,
            onRefresh: store.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(
                top: padding.top + (tablet ? 72 : 96) - 24,
                bottom: padding.bottom,
              ),
              children: [
                FeedStatusView.empty(
                  message: context.l10n.activityEmpty,
                  detail: context.l10n.activityEmptyDetail,
                  glyph: StateGlyphKind.bell,
                ),
              ],
            ),
          );
        }

        final first = recent.isNotEmpty ? recent : earlier;
        final second = recent.isNotEmpty ? earlier : const <ActivityEntry>[];
        final List<Widget> children;
        if (tablet) {
          Widget card(String title, List<ActivityEntry> list) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colors.cardRing,
                  width: OnsetTokens.hairlineWidth,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionTitle(title: title, tablet: true, colors: colors),
                  ...list.map(row),
                ],
              ),
            ),
          );
          children = [
            card(context.l10n.activityMostRecent, first),
            if (second.isNotEmpty) card(context.l10n.activityEarlier, second),
          ];
        } else {
          children = [
            _SectionTitle(
              title: context.l10n.activityMostRecent,
              tablet: false,
              colors: colors,
              onMarkAll: unread > 0
                  ? () => unawaited(store.markAllRead())
                  : null,
            ),
            ...first.map(row),
            if (second.isNotEmpty) ...[
              _SectionTitle(
                title: context.l10n.activityEarlier,
                tablet: false,
                colors: colors,
              ),
              ...second.map(row),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: Text(
                context.l10n.activityNote,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: colors.tertiary),
              ),
            ),
          ];
        }
        return RefreshIndicator.adaptive(
          edgeOffset: padding.top,
          onRefresh: store.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              top: padding.top,
              bottom: padding.bottom + (tablet ? 28 : 0),
              left: tablet ? 0 : padding.left,
              right: tablet ? 0 : padding.right,
            ),
            children: children,
          ),
        );
      },
    );
  }
}

/// "Most Recent" / "Earlier", with "Mark all as read" on the phone's
/// first.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.tablet,
    required this.colors,
    this.onMarkAll,
  });

  final String title;
  final bool tablet;
  final _ActivityColors colors;
  final VoidCallback? onMarkAll;

  @override
  Widget build(BuildContext context) {
    final onMarkAll = this.onMarkAll;
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: tablet
          ? const EdgeInsets.fromLTRB(18, 6, 14, 6)
          : const EdgeInsets.fromLTRB(16, 14, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: TextStyle(
                  fontSize: tablet ? 16 : 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.015 * 15,
                  color: colors.text,
                ),
              ),
            ),
          ),
          // Large text: the button takes up to two thirds and its label
          // wraps, rather than pushing the row out of the screen.
          if (onMarkAll != null)
            Flexible(
              flex: 2,
              child: TextButton.icon(
                onPressed: onMarkAll,
                style: TextButton.styleFrom(
                  foregroundColor: colors.body,
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                icon: StateGlyph(
                  StateGlyphKind.checkAll,
                  color: colors.body,
                  size: 16,
                  strokeWidth: 2,
                ),
                label: Text(
                  context.l10n.activityMarkAllRead,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A row folding away (300 ms) before [onFolded] removes it.
class _Folding extends StatefulWidget {
  const _Folding({
    super.key,
    required this.folding,
    required this.onFolded,
    required this.child,
  });

  final bool folding;
  final VoidCallback onFolded;
  final Widget child;

  @override
  State<_Folding> createState() => _FoldingState();
}

class _FoldingState extends State<_Folding>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    value: 1,
  );

  /// Made once: a curve made in build would add a listener at each build.
  late final _size = CurvedAnimation(
    parent: _controller,
    curve: OnsetMotion.standard,
  );
  late final _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(1 / 3, 1),
  );

  @override
  void initState() {
    super.initState();
    if (widget.folding) _fold();
  }

  @override
  void didUpdateWidget(_Folding oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.folding && !oldWidget.folding) {
      _fold();
    } else if (!widget.folding && oldWidget.folding) {
      // Still there (storage refused the removal): back as it was.
      _controller.value = 1;
    }
  }

  void _fold() => unawaited(
    _controller.reverse().then((_) {
      if (mounted && widget.folding) widget.onFolded();
    }),
  );

  @override
  void dispose() {
    _size.dispose();
    _fade.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _size,
      axisAlignment: -1,
      child: FadeTransition(opacity: _fade, child: widget.child),
    );
  }
}

/// A notification: the channel's picture with the unread dot and the
/// kind's mark, bold while unread, then when and its category, like
/// Twitch's. A long press offers to remove it.
class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.now,
    required this.tablet,
    required this.colors,
    required this.onTap,
    required this.onMenu,
  });

  final ActivityEntry entry;
  final DateTime now;
  final bool tablet;
  final _ActivityColors colors;
  final VoidCallback onTap;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final unread = !entry.read;
    final l = context.l10n;
    final when = formatTimeAgo(entry.at, l, now: now);
    final rim = tablet ? colors.card : colors.ground;
    return Semantics(
      button: true,
      onLongPressHint: l.activityOptions,
      child: PressScale(
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            onLongPress: onMenu,
            splashFactory: NoSplash.splashFactory,
            child: Padding(
              padding: tablet
                  ? const EdgeInsets.symmetric(horizontal: 18, vertical: 14)
                  : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _EntryAvatar(
                    entry: entry,
                    size: tablet ? 48 : 44,
                    badge: tablet ? 22 : 20,
                    rim: rim,
                    colors: colors,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 3,
                        children: [
                          Text(
                            entry.titleIn(context.l10n),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: tablet ? 15 : 14,
                              height: 1.35,
                              letterSpacing: -0.07,
                              fontWeight: unread
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: unread ? colors.text : colors.secondary,
                            ),
                          ),
                          if (entry.bodyIn(context.l10n) case final body
                              when body.isNotEmpty)
                            Text(
                              body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: tablet ? 14 : 13,
                                height: 1.4,
                                color: unread ? colors.body : colors.tertiary,
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Text(
                              '$when • ${entry.kind.label(l)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.tertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (tablet) ...[
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: StateGlyph(
                        StateGlyphKind.chevronRight,
                        color: colors.tertiary,
                        size: 18,
                        strokeWidth: 2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The channel's picture (or the kind's mark without a channel), the
/// unread dot at its top left, the kind's mark at its bottom right.
class _EntryAvatar extends StatelessWidget {
  const _EntryAvatar({
    required this.entry,
    required this.size,
    required this.badge,
    required this.rim,
    required this.colors,
  });

  final ActivityEntry entry;
  final double size;
  final double badge;

  /// The ground the dots are cut out of.
  final Color rim;
  final _ActivityColors colors;

  StateGlyphKind get _glyph => switch (entry.kind) {
    ActivityKind.live => StateGlyphKind.live,
    ActivityKind.mention => StateGlyphKind.mention,
    ActivityKind.reminder => StateGlyphKind.calendar,
  };

  @override
  Widget build(BuildContext context) {
    final accent = context.onsetColors.live;
    final login = entry.login;
    final kindColor = entry.kind == ActivityKind.live ? accent : colors.body;
    final picture = login != null
        ? ProfilePicture(userLogin: login, radius: size / 2)
        : Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.raised,
              shape: BoxShape.circle,
            ),
            child: StateGlyph(_glyph, color: kindColor, size: size * 0.45),
          );
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ExcludeSemantics(child: picture),
          if (!entry.read)
            Positioned(
              left: -2,
              top: -2,
              child: Semantics(
                label: context.l10n.activityUnread,
                child: Container(
                  key: const ValueKey('activity-unread-dot'),
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: rim, width: 2.5),
                  ),
                ),
              ),
            ),
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              width: badge,
              height: badge,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.raised,
                shape: BoxShape.circle,
                border: Border.all(color: rim, width: 2),
              ),
              child: StateGlyph(
                _glyph,
                color: kindColor,
                size: badge / 2,
                strokeWidth: 2.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The phone's options: the notification, then "Remove
/// notification".
class _RemoveSheet extends StatelessWidget {
  const _RemoveSheet({required this.entry});

  final ActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final login = entry.login;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: colors.hairline,
                    width: OnsetTokens.hairlineWidth,
                  ),
                ),
              ),
              child: Row(
                children: [
                  if (login != null) ...[
                    ExcludeSemantics(
                      child: ProfilePicture(userLogin: login, radius: 14),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      entry.titleIn(context.l10n),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: colors.secondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            SheetRow(
              glyph: SheetGlyphKind.trash,
              label: context.l10n.activityRemove,
              onTap: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );
  }
}

/// Activity on a tablet: the notifications, and
/// beside them the whispers when logged in.
class _TabletActivity extends StatelessWidget {
  const _TabletActivity({
    required this.notifications,
    required this.store,
    required this.whispers,
  });

  final Widget notifications;
  final ActivityStore store;
  final WhisperStore? whispers;

  @override
  Widget build(BuildContext context) {
    final colors = _ActivityColors.of(context);
    final padding = MediaQuery.paddingOf(context);
    final width = MediaQuery.sizeOf(context).width;
    final whispers = this.whispers;
    final asideWidth = width >= 1100 ? 392.0 : 320.0;
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    context.l10n.activityTitle,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.9,
                      color: colors.text,
                    ),
                  ),
                ),
                Text(
                  context.l10n.activityNote,
                  style: TextStyle(fontSize: 13, color: colors.tertiary),
                ),
              ],
            ),
          ),
          Observer(
            builder: (context) {
              final unread = store.unreadCount;
              if (unread == 0) return const SizedBox.shrink();
              return _MarkAllPill(
                count: unread,
                colors: colors,
                onPressed: () => unawaited(store.markAllRead()),
              );
            },
          ),
        ],
      ),
    );
    final list = MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: notifications,
    );
    final Widget body;
    if (whispers == null) {
      body = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              Expanded(child: list),
            ],
          ),
        ),
      );
    } else {
      // The header spans the notifications only; the whispers start where
      // the first card does, whatever the header's height (text size).
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: header),
              SizedBox(width: 24 + asideWidth),
            ],
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: list),
                const SizedBox(width: 24),
                SizedBox(
                  width: asideWidth,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 28 + padding.bottom),
                    child: _WhispersColumn(store: whispers, colors: colors),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(
        OnsetSpacing.gutterTablet + padding.left,
        12,
        OnsetSpacing.gutterTablet + padding.right,
        0,
      ),
      child: body,
    );
  }
}

/// "Mark all as read" on a tablet: a raised pill with the unread count.
class _MarkAllPill extends StatelessWidget {
  const _MarkAllPill({
    required this.count,
    required this.colors,
    required this.onPressed,
  });

  final int count;
  final _ActivityColors colors;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          backgroundColor: colors.raised,
          foregroundColor: colors.text,
          side: BorderSide(
            color: colors.ring,
            width: OnsetTokens.hairlineWidth,
          ),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            StateGlyph(
              StateGlyphKind.checkAll,
              color: colors.text,
              size: 17,
              strokeWidth: 2,
            ),
            Text(context.l10n.activityMarkAllRead),
            WhisperCountPill(count: count),
          ],
        ),
      ),
    );
  }
}

/// The whispers beside the notifications: the
/// conversations, "See all" opening the whispers.
class _WhispersColumn extends StatelessWidget {
  const _WhispersColumn({required this.store, required this.colors});

  final WhisperStore store;
  final _ActivityColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.cardRing,
          width: OnsetTokens.hairlineWidth,
        ),
      ),
      child: Observer(
        builder: (context) {
          final threads = store.threads;
          final unread = store.unreadCount;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 12, 8),
                child: Row(
                  children: [
                    // The title and its count take what "See all" leaves
                    // (a Spacer would hold half of it back).
                    Expanded(
                      child: Row(
                        children: [
                          // Smaller rather than cut at large text.
                          Flexible(
                            child: Semantics(
                              header: true,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  context.l10n.whispersTitle,
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.25,
                                    color: colors.text,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (unread > 0) ...[
                            const SizedBox(width: 8),
                            WhisperCountPill(count: unread, size: 18),
                          ],
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => WhispersScreen.open(context, store),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.body,
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.only(left: 12, right: 8),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 4,
                        children: [
                          Text(context.l10n.commonSeeAll),
                          StateGlyph(
                            StateGlyphKind.chevronRight,
                            color: colors.body,
                            size: 16,
                            strokeWidth: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              WhisperStatusNote(
                store: store,
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              ),
              Expanded(
                child: threads.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                        child: Text(
                          context.l10n.activityNoWhispers,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: colors.secondary,
                          ),
                        ),
                      )
                    : MediaQuery.removePadding(
                        context: context,
                        removeTop: true,
                        removeBottom: true,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                          itemCount: threads.length,
                          itemBuilder: (context, index) {
                            final thread = threads[index];
                            return WhisperThreadRow(
                              key: ValueKey(thread.userId),
                              thread: thread,
                              compact: true,
                              rounded: true,
                              onTap: () => WhispersScreen.open(
                                context,
                                store,
                                select: WhisperTarget.of(thread),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
