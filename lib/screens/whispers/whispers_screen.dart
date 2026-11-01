import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/settings/account/account_settings.dart';
import 'package:onset/screens/whispers/whisper_conversation.dart';
import 'package:onset/screens/whispers/whisper_kit.dart';
import 'package:onset/stores/whisper_store.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/motion/motion.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';
import 'package:onset/widgets/state_glyph.dart';
import 'package:onset/widgets/state_views.dart';

export 'package:onset/screens/whispers/whisper_kit.dart' show whisperStatusHint;

/// Someone to whisper with.
@immutable
class WhisperTarget {
  const WhisperTarget({
    required this.userId,
    required this.login,
    required this.displayName,
  });

  WhisperTarget.of(WhisperThread thread)
    : userId = thread.userId,
      login = thread.login,
      displayName = thread.displayName;

  final String userId;
  final String login;
  final String displayName;

  @override
  bool operator ==(Object other) =>
      other is WhisperTarget && other.userId == userId;

  @override
  int get hashCode => userId.hashCode;
}

/// The viewer's whispers: on a
/// phone the conversations, a conversation sliding over them; on a tablet
/// the conversations beside the one on screen.
///
/// One structure for both: the conversation on screen (and its draft)
/// survives the window crossing the tablet size.
class WhispersScreen extends StatefulWidget {
  const WhispersScreen({
    super.key,
    required this.store,
    this.initial,
    this.conversationOnly = false,
  });

  final WhisperStore store;

  /// The conversation open at first.
  final WhisperTarget? initial;

  /// Opened for [initial] alone (from a chat, a notice): on a phone, back
  /// leaves the page instead of showing the conversations.
  final bool conversationOnly;

  static const routeName = '/whispers';

  /// Opens the whispers, on [select]'s conversation when given.
  static Future<void> open(
    BuildContext context,
    WhisperStore store, {
    WhisperTarget? select,
  }) => Navigator.push(
    context,
    MaterialPageRoute(
      settings: const RouteSettings(name: routeName),
      builder: (context) => WhispersScreen(store: store, initial: select),
    ),
  );

  @override
  State<WhispersScreen> createState() => _WhispersScreenState();
}

class _WhispersScreenState extends State<WhispersScreen>
    with SingleTickerProviderStateMixin {
  /// The conversation chosen (on a tablet, the first one when none was).
  WhisperTarget? _selected;

  /// A conversation is open over the phone's list.
  var _open = false;

  /// The phone's slide: 0 the list, 1 the conversation over it.
  late final AnimationController _slide;

  /// The conversations' keys: a conversation keeps its state when the
  /// window crosses the tablet size.
  final _keys = <String, GlobalKey>{};

  /// The tablet opens the most recent conversation by itself,
  /// until the viewer closes one: then the pane waits for a choice, so a
  /// conversation is never read without being opened.
  var _autoOpen = true;

  /// The conversation follows a finger dragging it from the left edge:
  /// the slide is linear, under the finger, until it settles.
  var _dragging = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
    _open = widget.initial != null;
    _slide = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
      value: _open ? 1 : 0,
    );
    // Another account (or none): the conversation on screen was the
    // previous one's, it closes.
    _disposeAccount = reaction((_) => widget.store.me, (_) {
      if (!mounted) return;
      setState(() {
        _selected = null;
        _open = false;
        _autoOpen = true;
        _dragging = false;
      });
      _slide.value = 0;
    });
  }

  late final ReactionDisposer _disposeAccount;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Chosen on a tablet, then the window became a phone: the
    // conversation is over the list at once.
    if (!context.isLargeScreen && _open && !_slide.isAnimating) {
      _slide.value = 1;
    }
  }

  @override
  void dispose() {
    _disposeAccount();
    _slide.dispose();
    super.dispose();
  }

  void _select(WhisperTarget target) {
    _slide.duration = motionDuration(
      context,
      const Duration(milliseconds: 340),
    );
    setState(() {
      _selected = target;
      _open = true;
    });
    if (!context.isLargeScreen) _slide.forward();
  }

  /// The phone's back: the conversation slides away, then is closed.
  Future<void> _back() async {
    if (widget.conversationOnly) {
      await Navigator.maybePop(context);
      return;
    }
    _slide.duration = motionDuration(
      context,
      const Duration(milliseconds: 340),
    );
    setState(() {
      _open = false;
      _autoOpen = false;
    });
    await _slide.reverse();
    _closed();
  }

  /// The conversation slid away: it is no longer chosen (a window that
  /// becomes a tablet does not open it again).
  void _closed() {
    if (!mounted || _open) return;
    setState(() {
      _selected = null;
      _dragging = false;
    });
  }

  // A swipe from the left edge closes the conversation, following the
  // finger (the page's own back gesture would leave the whispers).

  void _dragStart(DragStartDetails details) {
    if (!_open) return;
    _slide.stop();
    setState(() => _dragging = true);
  }

  void _dragUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    final width = MediaQuery.sizeOf(context).width;
    _slide.value -= (details.primaryDelta ?? 0) / width;
  }

  Future<void> _dragEnd(double velocity) async {
    if (!_dragging) return;
    // A flick decides; otherwise where the finger let go.
    final close = velocity > 700 || (velocity > -700 && _slide.value < 0.5);
    final value = _slide.value;
    if (close) {
      setState(() {
        _open = false;
        _autoOpen = false;
      });
      await _slide.animateTo(
        0,
        duration: Duration(milliseconds: (340 * value).round()),
        curve: OnsetMotion.standard,
      );
      _closed();
    } else {
      await _slide.animateTo(
        1,
        duration: Duration(milliseconds: (340 * (1 - value)).round()),
        curve: OnsetMotion.standard,
      );
      if (mounted) setState(() => _dragging = false);
    }
  }

  GlobalKey _keyOf(WhisperTarget target) =>
      _keys.putIfAbsent(target.userId, GlobalKey.new);

  Widget _conversation(WhisperTarget target, {required bool pane}) =>
      WhisperConversation(
        key: _keyOf(target),
        store: widget.store,
        userId: target.userId,
        login: target.login,
        displayName: target.displayName,
        pane: pane,
        onBack: _back,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final large = context.isLargeScreen;
    final bars =
        theme.appBarTheme.systemOverlayStyle ??
        (theme.brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: bars,
      child: PopScope(
        // On a phone, back closes the conversation first.
        canPop: large || !_open || widget.conversationOnly,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: Observer(
            builder: (context) {
              if (widget.store.status == WhisperStatus.off) {
                return _LoggedOut(onBack: () => Navigator.maybePop(context));
              }
              return large ? _tablet(context) : _phone(context);
            },
          ),
        ),
      ),
    );
  }

  Widget _phone(BuildContext context) {
    final selected = _selected;
    final ground = Theme.of(context).scaffoldBackgroundColor;
    final colors = WhisperColors.of(context);
    final reduce = reduceMotionOf(context);
    return AnimatedBuilder(
      animation: _slide,
      builder: (context, _) {
        final t = _dragging
            ? _slide.value
            : OnsetMotion.standard.transform(_slide.value);
        final showList =
            (!widget.conversationOnly || selected == null) && _slide.value < 1;
        final showConversation =
            selected != null && (_open || _slide.value > 0);
        return Stack(
          children: [
            if (showList)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: _open,
                  child: Transform.translate(
                    offset: Offset(
                      reduce ? 0 : -0.28 * MediaQuery.sizeOf(context).width * t,
                      0,
                    ),
                    child: Opacity(
                      opacity: reduce ? 1 - t : 1 - 0.6 * t,
                      child: ColoredBox(
                        color: ground,
                        child: _ListPage(store: widget.store, onOpen: _select),
                      ),
                    ),
                  ),
                ),
              ),
            if (showConversation)
              Positioned.fill(
                child: FractionalTranslation(
                  translation: Offset(reduce ? 0 : 1 - t, 0),
                  child: Opacity(
                    opacity: reduce ? t : 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: ground,
                        boxShadow: _slide.value < 1 && !reduce
                            ? [
                                BoxShadow(
                                  color: colors.shadow,
                                  offset: const Offset(-18, 0),
                                  blurRadius: 40,
                                ),
                              ]
                            : null,
                      ),
                      child: _conversation(selected, pane: false),
                    ),
                  ),
                ),
              ),
            if (showConversation && !widget.conversationOnly)
              Positioned(
                key: const ValueKey('whisper-edge-swipe'),
                left: 0,
                top: 0,
                bottom: 0,
                width: 20 + MediaQuery.paddingOf(context).left,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  dragStartBehavior: DragStartBehavior.down,
                  onHorizontalDragStart: _dragStart,
                  onHorizontalDragUpdate: _dragUpdate,
                  onHorizontalDragEnd: (details) =>
                      unawaited(_dragEnd(details.velocity.pixelsPerSecond.dx)),
                  onHorizontalDragCancel: () => unawaited(_dragEnd(0)),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _tablet(BuildContext context) {
    final colors = WhisperColors.of(context);
    final padding = MediaQuery.paddingOf(context);
    final width = MediaQuery.sizeOf(context).width;
    final listWidth = width >= 1000 ? 372.0 : 320.0;
    final threads = widget.store.threads;
    // The first conversation on screen when none was chosen; kept, so a
    // whisper arriving elsewhere does not switch the pane.
    if (_selected == null && threads.isNotEmpty && _autoOpen) {
      _selected = WhisperTarget.of(threads.first);
    }
    final selected = _selected;
    final unread = widget.store.unreadCount;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        OnsetSpacing.gutterTablet + padding.left,
        padding.top + 12,
        OnsetSpacing.gutterTablet + padding.right,
        OnsetSpacing.gutterTablet + padding.bottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: listWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      WhisperBackButton(
                        color: colors.text,
                        onPressed: () => Navigator.maybePop(context),
                      ),
                      const SizedBox(width: 4),
                      // Smaller rather than cut in a narrow column at large
                      // text: the title stays whole.
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              context.l10n.whispersTitle,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.78,
                                color: colors.text,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        unread > 0
                            ? context.l10n.whispersUnreadCount(count: unread)
                            : context.l10n.whispersAllRead,
                        style: OnsetType.tabular(
                          TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: colors.secondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
                Expanded(
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    removeBottom: true,
                    removeLeft: true,
                    removeRight: true,
                    child: WhispersList(
                      store: widget.store,
                      onOpen: _select,
                      selectedUserId: selected?.userId,
                      rounded: true,
                      showEmpty: false,
                      noteMargin: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: colors.pane,
                borderRadius: BorderRadius.circular(OnsetTokens.radiusLarge),
                border: Border.all(
                  color: colors.paneRing,
                  width: OnsetTokens.hairlineWidth,
                ),
              ),
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                removeBottom: true,
                removeLeft: true,
                removeRight: true,
                child: selected != null
                    ? _conversation(selected, pane: true)
                    : threads.isEmpty
                    ? const _NoWhispers()
                    : FeedStatusView.empty(
                        message: context.l10n.whispersChoose,
                        glyph: StateGlyphKind.whisper,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The phone's list page: back and "Whispers" (20/700), then the
/// conversations.
class _ListPage extends StatelessWidget {
  const _ListPage({required this.store, required this.onOpen});

  final WhisperStore store;
  final ValueChanged<WhisperTarget> onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = WhisperColors.of(context);
    final padding = MediaQuery.paddingOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.only(
            top: padding.top,
            left: 4 + padding.left,
            right: 8 + padding.right,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: colors.hairline,
                width: OnsetTokens.hairlineWidth,
              ),
            ),
          ),
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                WhisperBackButton(
                  color: colors.text,
                  onPressed: () => Navigator.maybePop(context),
                ),
                const SizedBox(width: 2),
                // Smaller rather than cut in a narrow column at large text.
                Expanded(
                  child: Semantics(
                    header: true,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        context.l10n.whispersTitle,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          color: colors.text,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: WhispersList(store: store, onOpen: onOpen),
          ),
        ),
      ],
    );
  }
}

/// No conversation yet: the tablet's pane, and the list on a phone.
class _NoWhispers extends StatelessWidget {
  const _NoWhispers();

  @override
  Widget build(BuildContext context) {
    return FeedStatusView.empty(
      message: context.l10n.whispersEmpty,
      detail: context.l10n.whispersEmptyDetail,
      glyph: StateGlyphKind.whisper,
    );
  }
}

/// Logged out: back, and the invitation to connect.
class _LoggedOut extends StatelessWidget {
  const _LoggedOut({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = WhisperColors.of(context);
    return SafeArea(
      child: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              child: FeedStatusView.signIn(
                message: whisperStatusHint(WhisperStatus.off, context.l10n)!,
                onConnect: () => openLogin(context),
              ),
            ),
          ),
          Positioned(
            left: 4,
            top: 6,
            child: WhisperBackButton(color: colors.text, onPressed: onBack),
          ),
        ],
      ),
    );
  }
}

/// The conversations, most recent first (the phone's whispers, Activity's
/// Whispers tab, the tablet's list), with why whispers may not arrive
/// above them.
class WhispersList extends StatelessWidget {
  const WhispersList({
    super.key,
    required this.store,
    this.onOpen,
    this.selectedUserId,
    this.rounded = false,
    this.showEmpty = true,
    this.noteMargin = const EdgeInsets.fromLTRB(16, 8, 16, 8),
  });

  final WhisperStore store;

  /// Opens a conversation; alone on its page when null (Activity's tab).
  final ValueChanged<WhisperTarget>? onOpen;

  /// The conversation on screen beside the list (tablet).
  final String? selectedUserId;
  final bool rounded;

  /// No conversation: the empty state (the tablet shows it in its pane).
  final bool showEmpty;
  final EdgeInsetsGeometry noteMargin;

  void _open(BuildContext context, WhisperThread thread) {
    final onOpen = this.onOpen;
    if (onOpen != null) {
      onOpen(WhisperTarget.of(thread));
      return;
    }
    WhisperConversation.open(
      context,
      store: store,
      userId: thread.userId,
      login: thread.login,
      displayName: thread.displayName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return Observer(
      builder: (context) {
        final threads = store.threads;
        final note = WhisperStatusNote(store: store, margin: noteMargin);
        if (threads.isEmpty) {
          return ListView(
            padding: EdgeInsets.only(top: padding.top, bottom: padding.bottom),
            children: [
              note,
              if (showEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 72),
                  child: _NoWhispers(),
                ),
            ],
          );
        }
        return ListView.builder(
          padding: EdgeInsets.only(
            top: padding.top + (rounded ? 0 : 6),
            bottom: padding.bottom + 24,
            left: padding.left,
            right: padding.right,
          ),
          itemCount: threads.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) return note;
            final thread = threads[index - 1];
            return Padding(
              padding: EdgeInsets.only(bottom: rounded ? 2 : 0),
              child: WhisperThreadRow(
                key: ValueKey(thread.userId),
                thread: thread,
                selected: thread.userId == selectedUserId,
                rounded: rounded,
                onTap: () => _open(context, thread),
              ),
            );
          },
        );
      },
    );
  }
}
