import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/screens/whispers/whisper_kit.dart';
import 'package:onset/screens/whispers/whispers_screen.dart';
import 'package:onset/stores/whisper_store.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/motion/haptics.dart';
import 'package:onset/widgets/motion/motion.dart';
import 'package:onset/widgets/motion/press_scale.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';
import 'package:onset/widgets/profile_picture.dart';
import 'package:onset/widgets/state_glyph.dart';
import 'package:onset/widgets/state_views.dart';

/// The whispers with one person, and a field to answer:
/// the phone's page over the list, or the tablet's
/// pane ([pane]).
///
/// While it is built, the conversation is open in [store]: its whispers
/// are read, and what arrives there is read already.
class WhisperConversation extends StatefulWidget {
  const WhisperConversation({
    super.key,
    required this.store,
    required this.userId,
    required this.login,
    required this.displayName,
    this.pane = false,
    this.onBack,
  });

  final WhisperStore store;
  final String userId;
  final String login;
  final String displayName;

  /// The tablet's pane: a 72 dp header with the login, the column
  /// centred, no back button.
  final bool pane;

  /// The phone's back button; leaves the page when null.
  final VoidCallback? onBack;

  static const routeName = '/whisper';

  /// Opens the conversation with someone: alone on a phone (back leaves
  /// it), beside the conversations on a tablet.
  static Future<void> open(
    BuildContext context, {
    required WhisperStore store,
    required String userId,
    required String login,
    required String displayName,
  }) => Navigator.push(
    context,
    route(store: store, userId: userId, login: login, displayName: displayName),
  );

  /// The conversation as a route, for a caller whose context is going away
  /// (a bottom sheet that closes first).
  static Route<void> route({
    required WhisperStore store,
    required String userId,
    required String login,
    required String displayName,
  }) => MaterialPageRoute(
    settings: const RouteSettings(name: routeName),
    builder: (context) => WhispersScreen(
      store: store,
      initial: WhisperTarget(
        userId: userId,
        login: login,
        displayName: displayName,
      ),
      conversationOnly: true,
    ),
  );

  @override
  State<WhisperConversation> createState() => _WhisperConversationState();
}

class _WhisperConversationState extends State<WhisperConversation> {
  late final WhisperThread _thread;
  final _text = TextEditingController();
  var _sending = false;
  String? _error;

  /// The whispers already on screen: those that come later slide in.
  late final Set<String> _known;
  final _arrivals = <String, DateTime>{};

  @override
  void initState() {
    super.initState();
    // Opened outside any build: it marks the whispers read.
    _thread = widget.store.open(
      userId: widget.userId,
      login: widget.login,
      displayName: widget.displayName,
    );
    _known = {for (final whisper in _thread.whispers) whisper.id};
  }

  @override
  void dispose() {
    widget.store.close(widget.userId);
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _text.text;
    if (text.trim().isEmpty || _sending) return;
    Haptics.light();
    setState(() {
      _sending = true;
      _error = null;
    });
    final error = await widget.store.send(_thread, text);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _error = error;
      // Keep a draft typed while it was sending.
      if (error == null && _text.text == text) _text.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = WhisperColors.of(context);
    final pane = widget.pane;
    final error = _error;
    final column = Column(
      children: [
        if (pane)
          _PaneHeader(
            login: widget.login,
            displayName: whisperPreview(widget.displayName),
            colors: colors,
          )
        else
          _PageHeader(
            login: widget.login,
            displayName: whisperPreview(widget.displayName),
            colors: colors,
            onBack: widget.onBack ?? () => Navigator.maybePop(context),
          ),
        Expanded(
          child: _Messages(
            thread: _thread,
            known: _known,
            arrivals: _arrivals,
            pane: pane,
            colors: colors,
          ),
        ),
        if (error != null)
          _Centered(
            enabled: pane,
            maxWidth: 760,
            child: Padding(
              padding: EdgeInsets.fromLTRB(pane ? 24 : 16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: OnsetTokens.danger,
                    ),
                  ),
                ),
              ),
            ),
          ),
        _Composer(
          controller: _text,
          name: whisperPreview(widget.displayName),
          sending: _sending,
          pane: pane,
          colors: colors,
          onSend: _send,
        ),
      ],
    );
    return Material(
      type: MaterialType.transparency,
      child: pane ? column : SafeArea(top: false, bottom: false, child: column),
    );
  }
}

/// Centres [child] in at most [maxWidth] when [enabled] (the tablet pane).
class _Centered extends StatelessWidget {
  const _Centered({
    required this.enabled,
    required this.maxWidth,
    required this.child,
  });

  final bool enabled;
  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// The phone's header: back, the picture (32) and the name (16/700).
class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.login,
    required this.displayName,
    required this.colors,
    required this.onBack,
  });

  final String login;
  final String displayName;
  final WhisperColors colors;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.only(top: top, left: 4, right: 12),
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
            WhisperBackButton(color: colors.text, onPressed: onBack),
            const SizedBox(width: 10),
            ExcludeSemantics(
              child: ProfilePicture(userLogin: login, radius: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.16,
                    color: colors.text,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The 44 dp round back button of the whispers' headers.
class WhisperBackButton extends StatelessWidget {
  const WhisperBackButton({
    super.key,
    required this.color,
    required this.onPressed,
  });

  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: onPressed,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      padding: EdgeInsets.zero,
      icon: StateGlyph(
        StateGlyphKind.back,
        color: color,
        size: 22,
        strokeWidth: 2,
      ),
    );
  }
}

/// The tablet pane's header: the picture (44), the name (17/700) and the
/// login.
class _PaneHeader extends StatelessWidget {
  const _PaneHeader({
    required this.login,
    required this.displayName,
    required this.colors,
  });

  final String login;
  final String displayName;
  final WhisperColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
          ExcludeSemantics(child: ProfilePicture(userLogin: login, radius: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              header: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: 2,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.25,
                      color: colors.text,
                    ),
                  ),
                  Text(
                    login,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: colors.tertiary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The whispers, newest at the bottom, under the note that only this
/// session's are kept.
class _Messages extends StatelessWidget {
  const _Messages({
    required this.thread,
    required this.known,
    required this.arrivals,
    required this.pane,
    required this.colors,
  });

  final WhisperThread thread;

  /// The whispers seen so far, and when the new ones arrived.
  final Set<String> known;
  final Map<String, DateTime> arrivals;
  final bool pane;
  final WhisperColors colors;

  /// How long after arriving a whisper still slides in when built.
  static const _freshFor = Duration(seconds: 1);

  static const _note =
      'Twitch keeps no history the app can show, so only this session’s '
      'whispers appear here.';

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final whispers = thread.whispers.toList();
        final count = whispers.length;
        // What arrived since the last look slides in, if it is built soon
        // (a whisper first built later, scrolled to, just shows).
        final now = clock.now();
        for (final whisper in whispers) {
          if (known.add(whisper.id)) arrivals[whisper.id] = now;
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = pane
                ? constraints.maxWidth.clamp(0.0, 720.0 + 48)
                : constraints.maxWidth;
            final side = pane ? 24.0 : 12.0;
            final inner = width - side * 2;
            return ListView.builder(
              reverse: true,
              padding: EdgeInsets.fromLTRB(
                side,
                pane ? 16 : 12,
                side,
                pane ? 12 : 10,
              ),
              itemCount: count + 1,
              findChildIndexCallback: (key) {
                if (key is! ValueKey<String>) return null;
                final index = whispers.indexWhere((w) => w.id == key.value);
                return index < 0 ? null : count - 1 - index;
              },
              itemBuilder: (context, i) {
                final Widget item;
                if (i == count) {
                  item = Padding(
                    padding: EdgeInsets.fromLTRB(24, 4, 24, pane ? 22 : 18),
                    child: Text(
                      _note,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: colors.tertiary,
                      ),
                    ),
                  );
                } else {
                  final index = count - 1 - i;
                  final whisper = whispers[index];
                  final older = index > 0 ? whispers[index - 1] : null;
                  final newer = index + 1 < count ? whispers[index + 1] : null;
                  // Only what arrives while the conversation is open
                  // slides in.
                  final arrived = arrivals.remove(whisper.id);
                  final fresh =
                      arrived != null &&
                      clock.now().difference(arrived) < _freshFor;
                  item = _Bubble(
                    whisper: whisper,
                    first: older == null || older.mine != whisper.mine,
                    last: newer == null || newer.mine != whisper.mine,
                    spaced: older != null && older.mine != whisper.mine,
                    maxWidth: inner * 0.75,
                    fresh: fresh,
                    colors: colors,
                  );
                }
                // Keyed at the root: a bubble keeps its state (its
                // entrance, a selection) when whispers arrive below it.
                return KeyedSubtree(
                  key: ValueKey(i == count ? '' : whispers[count - 1 - i].id),
                  child: _Centered(enabled: pane, maxWidth: 720, child: item),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// One whisper: the viewer's on the right in the light bubble, the other
/// person's on the left; the corners between whispers of a run are tight.
class _Bubble extends StatefulWidget {
  const _Bubble({
    required this.whisper,
    required this.first,
    required this.last,
    required this.spaced,
    required this.maxWidth,
    required this.fresh,
    required this.colors,
  });

  final Whisper whisper;

  /// The first and last of a run from the same side.
  final bool first;
  final bool last;

  /// A run starts here after the other side's: a gap above.
  final bool spaced;
  final double maxWidth;

  /// Arrived while on screen: the row opens (280 ms) instead of jumping.
  final bool fresh;
  final WhisperColors colors;

  @override
  State<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<_Bubble> with SingleTickerProviderStateMixin {
  AnimationController? _entrance;
  CurvedAnimation? _curve;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entrance == null && widget.fresh && !reduceMotionOf(context)) {
      final entrance = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 280),
      )..forward();
      _entrance = entrance;
      _curve = CurvedAnimation(parent: entrance, curve: OnsetMotion.standard);
    }
  }

  @override
  void dispose() {
    _curve?.dispose();
    _entrance?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final mine = widget.whisper.mine;
    const round = Radius.circular(18);
    const tight = Radius.circular(6);
    final radius = mine
        ? BorderRadius.only(
            topLeft: round,
            topRight: widget.first ? round : tight,
            bottomRight: widget.last ? round : tight,
            bottomLeft: round,
          )
        : BorderRadius.only(
            topLeft: widget.first ? round : tight,
            topRight: round,
            bottomRight: round,
            bottomLeft: widget.last ? round : tight,
          );
    Widget bubble = Padding(
      padding: EdgeInsets.only(top: widget.spaced ? 11 : 1, bottom: 1),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: widget.maxWidth),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            decoration: BoxDecoration(
              color: mine ? colors.mineFill : colors.theirFill,
              borderRadius: radius,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              spacing: 2,
              children: [
                SelectableText(
                  widget.whisper.text,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: mine ? colors.mineText : colors.theirText,
                  ),
                ),
                Text(
                  whisperTime(widget.whisper.sentAt),
                  style: OnsetType.tabular(
                    TextStyle(
                      fontSize: 11,
                      color: mine ? colors.mineTime : colors.theirTime,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final curve = _curve;
    if (curve != null) {
      bubble = SizeTransition(
        sizeFactor: curve,
        axisAlignment: -1,
        child: FadeTransition(opacity: curve, child: bubble),
      );
    }
    return bubble;
  }
}

/// The field (a 44 dp pill) and the send button, lit once there is
/// something to send.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.name,
    required this.sending,
    required this.pane,
    required this.colors,
    required this.onSend,
  });

  final TextEditingController controller;
  final String name;
  final bool sending;
  final bool pane;
  final WhisperColors colors;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final accent = context.onsetColors.live;
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: 8,
      children: [
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: colors.field,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: colors.fieldRing,
                width: OnsetTokens.hairlineWidth,
              ),
            ),
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              maxLength: TwitchApi.maxWhisperLength,
              buildCounter:
                  (
                    context, {
                    required currentLength,
                    required isFocused,
                    required maxLength,
                  }) => null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              cursorColor: accent,
              style: TextStyle(fontSize: 15, height: 1.35, color: colors.text),
              decoration: InputDecoration(
                hintText: 'Whisper $name',
                hintStyle: TextStyle(fontSize: 15, color: colors.tertiary),
                isCollapsed: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => _SendButton(
            ready: value.text.trim().isNotEmpty,
            sending: sending,
            accent: accent,
            colors: colors,
            onSend: onSend,
          ),
        ),
      ],
    );
    final padded = Padding(
      padding: pane
          ? const EdgeInsets.fromLTRB(20, 10, 20, 18)
          : const EdgeInsets.fromLTRB(12, 8, 12, 14),
      child: row,
    );
    if (pane) {
      return _Centered(enabled: true, maxWidth: 760, child: padded);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colors.hairline,
            width: OnsetTokens.hairlineWidth,
          ),
        ),
      ),
      child: SafeArea(top: false, child: padded),
    );
  }
}

/// Send: the accent disc once there is text (a ring turning while it
/// goes), a quiet one before.
class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.ready,
    required this.sending,
    required this.accent,
    required this.colors,
    required this.onSend,
  });

  final bool ready;
  final bool sending;
  final Color accent;
  final WhisperColors colors;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final lit = ready || sending;
    final fill = lit ? accent : colors.raised;
    final ink = lit ? onFillColor(accent) : colors.tertiary;
    return PressScale(
      enabled: ready && !sending,
      child: AnimatedContainer(
        duration: motionDuration(context, const Duration(milliseconds: 200)),
        curve: OnsetMotion.standard,
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
        child: IconButton(
          tooltip: 'Send',
          onPressed: ready && !sending ? onSend : null,
          padding: EdgeInsets.zero,
          style: IconButton.styleFrom(splashFactory: NoSplash.splashFactory),
          icon: sending
              ? SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ink,
                    backgroundColor: ink.withValues(alpha: 0.25),
                  ),
                )
              : StateGlyph(StateGlyphKind.send, color: ink, size: 19),
        ),
      ),
    );
  }
}
