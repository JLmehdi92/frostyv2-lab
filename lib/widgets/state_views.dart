import 'package:flutter/material.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/motion/press_scale.dart';
import 'package:onset/widgets/state_glyph.dart';

/// The app's words for a connection problem: the feeds' own message, and
/// the network error every API call reports (`NetworkException`).
bool isConnectionProblem(String message) =>
    message == 'Unable to connect to Twitch' ||
    message == 'No internet connection. Please check your network.';

/// Dark or light text on [fill], whichever reads better (the accent can
/// be any colour the viewer picked).
Color onFillColor(Color fill) {
  final luminance = fill.computeLuminance();
  final onBlack = (luminance + 0.05) / 0.05;
  final onWhite = 1.05 / (luminance + 0.05);
  return onBlack >= onWhite ? OnsetTokens.backgroundDark : Colors.white;
}

/// The message of an empty, failed or logged-out screen: a mark, the app's
/// message as it words it and, when it can help, one action ("Try again"
/// does what pulling to refresh does).
class FeedStatusView extends StatelessWidget {
  const FeedStatusView({
    super.key,
    required this.message,
    this.detail,
    this.icon,
    this.glyph,
    this.action,
    this.onAction,
    this.actionGlyph,
    this.actionIcon,
    this.signalOff = false,
    this.primaryAction = false,
  }) : _standardAction = null;

  /// Nothing to show: the message under the signal turned off, or, with
  /// [glyph], under that glyph in its disc (Activity's bell), with an
  /// optional [detail] below.
  const FeedStatusView.empty({
    super.key,
    required this.message,
    this.detail,
    this.glyph,
  }) : icon = null,
       action = null,
       _standardAction = null,
       onAction = null,
       actionGlyph = null,
       actionIcon = null,
       signalOff = glyph == null,
       primaryAction = false;

  /// Something failed: the network mark for a connection problem (the
  /// app's own message, as it words it), else the alert, and "Try again".
  FeedStatusView.error({
    super.key,
    required this.message,
    required VoidCallback onRetry,
  }) : detail = null,
       icon = null,
       glyph = isConnectionProblem(message)
           ? StateGlyphKind.offline
           : StateGlyphKind.alert,
       action = null,
       _standardAction = _tryAgain,
       onAction = onRetry,
       actionGlyph = StateGlyphKind.retry,
       actionIcon = null,
       signalOff = false,
       primaryAction = false;

  /// Logged out: what an account would give ("Log in to …")
  /// and "Connect with Twitch".
  const FeedStatusView.signIn({
    super.key,
    required this.message,
    required VoidCallback onConnect,
  }) : detail = null,
       icon = null,
       glyph = StateGlyphKind.account,
       action = null,
       _standardAction = _connectWithTwitch,
       onAction = onConnect,
       actionGlyph = null,
       actionIcon = null,
       signalOff = false,
       primaryAction = true;

  final String message;

  /// A second, quieter line under [message].
  final String? detail;

  /// A Material icon in the disc (when there is no glyph for it).
  final IconData? icon;

  /// A glyph in the disc.
  final StateGlyphKind? glyph;
  final String? action;

  /// The action of [FeedStatusView.error] and [FeedStatusView.signIn], in
  /// the language on screen (read in [build], [action] being null).
  final String Function(AppLocalizations l)? _standardAction;

  static String _tryAgain(AppLocalizations l) => l.commonTryAgain;

  static String _connectWithTwitch(AppLocalizations l) =>
      l.commonConnectWithTwitch;

  final VoidCallback? onAction;
  final StateGlyphKind? actionGlyph;
  final IconData? actionIcon;
  final bool signalOff;

  /// The action is the screen's way forward (the accent pill).
  final bool primaryAction;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final large = context.isLargeScreen;
    // Activity's empty state: a smaller disc and a second line.
    final quiet =
        !signalOff &&
        this.action == null &&
        _standardAction == null &&
        this.detail != null;
    final markSize = quiet ? 64.0 : (large ? 88.0 : 72.0);
    final Widget mark;
    if (signalOff) {
      mark = SignalOffMark(size: large ? 104 : 88);
    } else {
      final glyph = this.glyph;
      final iconSize = quiet ? 28.0 : (large ? 34.0 : 30.0);
      mark = Container(
        width: markSize,
        height: markSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.surface,
          border: Border.all(
            color: colors.pillBorder,
            width: OnsetTokens.hairlineWidth,
          ),
        ),
        child: glyph != null
            ? StateGlyph(glyph, color: colors.secondary, size: iconSize)
            : Icon(
                icon ?? Icons.info_outline_rounded,
                size: iconSize,
                color: colors.secondary,
              ),
      );
    }
    final action = this.action ?? _standardAction?.call(context.l10n);
    final detail = this.detail;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: quiet ? 12 : (large ? 18 : 16),
          children: [
            ExcludeSemantics(child: mark),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: large ? 360 : 260),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: quiet
                      ? 18
                      : signalOff
                      ? (large ? 20 : 17)
                      : (large ? 20 : 16),
                  height: quiet ? 1.3 : 1.4,
                  fontWeight: signalOff || quiet || large
                      ? FontWeight.w700
                      : FontWeight.w600,
                  letterSpacing: -0.015 * 17,
                  color: colors.text,
                ),
              ),
            ),
            if (detail != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: colors.secondary,
                  ),
                ),
              ),
            if (action != null)
              primaryAction
                  ? _PrimaryPill(label: action, onPressed: onAction)
                  : StatePill(
                      label: action,
                      onPressed: onAction,
                      glyph: actionGlyph,
                      icon: actionIcon ?? Icons.visibility_outlined,
                      height: large ? 48 : 44,
                    ),
          ],
        ),
      ),
    );
  }
}

/// The signal turned off: a ring, a disc, a dark dot.
class SignalOffMark extends StatelessWidget {
  const SignalOffMark({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: colors.hairline,
            width: OnsetTokens.hairlineWidth,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.surface,
              border: Border.all(
                color: colors.pillBorder,
                width: OnsetTokens.hairlineWidth,
              ),
            ),
            child: Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF3A3A3A)
                      : const Color(0xFFC4C4C4),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The states' raised pill ("Try again"): `#1E1E1E`, a 16 % hairline, a
/// glyph and the label 14/600.
class StatePill extends StatelessWidget {
  const StatePill({
    super.key,
    required this.label,
    required this.onPressed,
    this.glyph,
    this.icon,
    this.height = 44,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final StateGlyphKind? glyph;
  final IconData? icon;
  final double height;

  /// The inline size (36 dp, 13/600), for a status inside a list.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final glyph = this.glyph;
    final iconSize = compact ? 15.0 : 17.0;
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: Size(0, compact ? 36 : height),
        padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 20),
        backgroundColor: colors.raised,
        foregroundColor: colors.text,
        side: BorderSide(
          color: colors.pillBorder,
          width: OnsetTokens.hairlineWidth,
        ),
        shape: const StadiumBorder(),
        textStyle: TextStyle(
          fontSize: compact ? 13 : 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      icon: glyph != null
          ? StateGlyph(
              glyph,
              color: colors.text,
              size: iconSize,
              strokeWidth: 2,
            )
          : Icon(icon ?? Icons.refresh_rounded, size: iconSize),
      label: Text(label),
    );
  }
}

/// The accent pill of a way forward ("Connect with Twitch").
class _PrimaryPill extends StatelessWidget {
  const _PrimaryPill({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = context.onsetColors.live;
    return PressScale(
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          backgroundColor: accent,
          foregroundColor: onFillColor(accent),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }
}

/// A status inside a list or a section (a search section that failed or
/// found nothing, a refresh that failed over a list already there): the
/// mark, the app's message and, when it can be retried, "Try again".
class InlineStatus extends StatelessWidget {
  const InlineStatus({
    super.key,
    required this.message,
    this.glyph = StateGlyphKind.alert,
    this.onRetry,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  /// A failure: the network mark for a connection problem.
  InlineStatus.error({
    super.key,
    required this.message,
    this.onRetry,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  }) : glyph = isConnectionProblem(message)
           ? StateGlyphKind.offline
           : StateGlyphKind.alert;

  final String message;

  /// Null for nothing found (no mark beside the message).
  final StateGlyphKind? glyph;
  final VoidCallback? onRetry;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final glyph = this.glyph;
    final onRetry = this.onRetry;
    return Padding(
      padding: padding,
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (glyph != null) ...[
                  StateGlyph(glyph, color: colors.secondary, size: 18),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                      color: colors.secondary,
                    ),
                  ),
                ),
              ],
            ),
            if (onRetry != null)
              StatePill(
                label: context.l10n.commonTryAgain,
                onPressed: onRetry,
                glyph: StateGlyphKind.retry,
                compact: true,
              ),
          ],
        ),
      ),
    );
  }
}
