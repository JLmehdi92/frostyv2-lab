import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/utils/modal_bottom_sheet.dart';
import 'package:onset/widgets/motion/motion.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';

/// The colours of the channel screen's sheets, menus, panels and dialogs
/// (boards ChaineTchatOutils, ChaineCarteUtilisateur, ChaineModeration,
/// ChaineDetailsTchat, ChainePoints, ChaineSondagePari, ChaineOutilsTablette).
///
/// The boards are drawn dark; the light values keep the same tiers on a
/// white ground (the pairs `FeedColors` set for the home screen).
class SheetColors {
  const SheetColors({
    required this.sheet,
    required this.panel,
    required this.dialog,
    required this.raised,
    required this.well,
    required this.chip,
    required this.field,
    required this.emoteMenu,
    required this.handle,
    required this.topHighlight,
    required this.hairline,
    required this.ring,
    required this.ringStrong,
    required this.text,
    required this.body,
    required this.secondary,
    required this.tertiary,
    required this.danger,
    required this.dangerFill,
    required this.dangerTint,
    required this.switchOff,
    required this.knobOff,
    required this.disabledFill,
    required this.disabledText,
    required this.pagerOff,
  });

  /// A sheet: #141414.
  final Color sheet;

  /// A sheet over a sheet ("More", the bet) and a tablet's anchored panel:
  /// #181818.
  final Color panel;

  /// A dialog card: #1E1E1E.
  final Color dialog;

  /// Raised controls inside a sheet (an icon tile, the chatters filter).
  final Color raised;

  /// A card inside a sheet (the message preview, the watch streak).
  final Color well;

  /// An unselected choice pill.
  final Color chip;

  /// A number field (the stake).
  final Color field;

  /// The emote menu under the chat input on a phone.
  final Color emoteMenu;

  /// The drag handle.
  final Color handle;

  /// The light edge along a sheet's top.
  final Color topHighlight;

  /// Separators.
  final Color hairline;

  /// The thin inner ring of pills and fields.
  final Color ring;

  /// The ring of an outlined pill (Unban, Warn).
  final Color ringStrong;

  final Color text;
  final Color body;
  final Color secondary;
  final Color tertiary;

  /// Text and icons of a destructive row (Delete, Clear chat, Ban).
  final Color danger;

  /// A destructive confirmation button.
  final Color dangerFill;

  /// The tint behind a destructive pill.
  final Color dangerTint;

  final Color switchOff;
  final Color knobOff;

  /// A primary button that cannot be pressed yet.
  final Color disabledFill;
  final Color disabledText;

  /// A pager arrow with nowhere to go.
  final Color pagerOff;

  static const dark = SheetColors(
    sheet: OnsetTokens.surfaceDark,
    panel: Color(0xFF181818),
    dialog: OnsetTokens.raisedDark,
    raised: OnsetTokens.raisedDark,
    well: Color(0xFF1A1A1A),
    chip: Color(0xFF222222),
    field: Color(0xFF101010),
    emoteMenu: Color(0xFF101010),
    handle: Color(0xFF3A3A3A),
    topHighlight: Color(0x24FFFFFF),
    hairline: Color(0x14FFFFFF),
    ring: Color(0x1AFFFFFF),
    ringStrong: Color(0x2EFFFFFF),
    text: OnsetTokens.textPrimaryDark,
    body: OnsetTokens.textBodyDark,
    secondary: OnsetTokens.textSecondaryDark,
    tertiary: OnsetTokens.textTertiaryDark,
    danger: Color(0xFFFF7A7F),
    dangerFill: OnsetTokens.danger,
    dangerTint: Color(0x24FF5A5F),
    switchOff: Color(0xFF2E2E2E),
    knobOff: OnsetTokens.textSecondaryDark,
    disabledFill: Color(0xFF2A2A2A),
    disabledText: OnsetTokens.textTertiaryDark,
    pagerOff: Color(0xFF4A4A4A),
  );

  static const light = SheetColors(
    sheet: OnsetTokens.surfaceLight,
    panel: OnsetTokens.surfaceLight,
    dialog: OnsetTokens.surfaceLight,
    raised: Color(0xFFF0F0F0),
    well: Color(0xFFF5F5F5),
    chip: Color(0xFFEFEFEF),
    field: Color(0xFFF5F5F5),
    emoteMenu: Color(0xFFF7F7F7),
    handle: Color(0xFFD4D4D4),
    topHighlight: Color(0x14000000),
    hairline: Color(0x14000000),
    ring: Color(0x1A000000),
    ringStrong: Color(0x2E000000),
    text: Color(0xFF0A0A0A),
    body: Color(0xFF3A3A3A),
    secondary: Color(0xFF6B6B6B),
    tertiary: Color(0xFF6B6B6B),
    danger: Color(0xFFC62828),
    dangerFill: Color(0xFFE5484D),
    dangerTint: Color(0x1FE5484D),
    switchOff: Color(0xFFD6D6D6),
    knobOff: Color(0xFFFFFFFF),
    disabledFill: Color(0xFFE6E6E6),
    disabledText: Color(0xFF9A9A9A),
    pagerOff: Color(0xFFC4C4C4),
  );

  static SheetColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  /// The signal colour (selection, the one primary action).
  static Color accentOf(BuildContext context) => context.onsetColors.live;

  /// Text on [accentOf].
  static Color onAccentOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? OnsetTokens.backgroundDark
      : Colors.white;

  /// A barely tinted ground for a selected pill.
  static Color accentTintOf(BuildContext context, {double alpha = 0.10}) =>
      accentOf(context).withValues(alpha: alpha);
}

/// The type of the sheets (Inter, the boards' sizes).
abstract final class SheetText {
  /// "Chat modes", "Clear chat?", a dialog's title: 18 / 700.
  static const title = TextStyle(
    fontFamily: OnsetTokens.bodyFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.27,
    height: 1.25,
  );

  /// A sub-view's title next to its back chevron: 17 / 700.
  static const subtitle = TextStyle(
    fontFamily: OnsetTokens.bodyFamily,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.25,
    height: 1.25,
  );

  /// A row: 15 / 500.
  static const row = TextStyle(
    fontFamily: OnsetTokens.bodyFamily,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  /// A row's second line: 12.5.
  static const rowDetail = TextStyle(
    fontFamily: OnsetTokens.bodyFamily,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );

  /// "RECENT MESSAGES", "REWARDS": 11 / 600, wide tracking, upper case.
  static const section = TextStyle(
    fontFamily: OnsetTokens.bodyFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.54,
    height: 1.3,
  );

  /// Body copy: 14 / 1.5.
  static const body = TextStyle(
    fontFamily: OnsetTokens.bodyFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// A pill's label: 13 / 600.
  static const pill = TextStyle(
    fontFamily: OnsetTokens.bodyFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// The status under an action ("You timed out …"): 12.5.
  static const status = TextStyle(
    fontFamily: OnsetTokens.bodyFamily,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    height: 1.35,
  );

  /// [style] with tabular figures, for numbers that change.
  static TextStyle tabular(TextStyle style) => OnsetType.tabular(style);
}

/// The radius of a sheet's top corners (24) and of a tablet panel (20).
const kSheetRadius = 24.0;
const kPanelRadius = 20.0;

/// The scrim under a sheet: black at 62 %.
const kSheetScrim = Color(0x9E000000);

/// Shows a channel-screen sheet with the boards' frame: #141414 (or
/// [panel] #181818 for a sheet over a sheet), 24 dp top corners, the light
/// top edge, the 36 × 4 handle, the 62 % scrim; [background] tints it (the
/// hype train's green). On a phone it still starts under the video
/// ([SheetsUnderVideo]).
Future<T?> showOnsetSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool panel = false,
  bool showHandle = true,
  bool enableDrag = true,
  bool isDismissible = true,
  BoxConstraints? constraints,
  Color? background,
}) {
  final colors = SheetColors.of(context);
  background ??= panel ? colors.panel : colors.sheet;
  return showModalBottomSheetWithProperFocus<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: background,
    showDragHandle: false,
    barrierColor: kSheetScrim,
    enableDrag: enableDrag,
    isDismissible: isDismissible,
    constraints: constraints,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(kSheetRadius)),
    ),
    builder: (context) => SheetFrame(
      showHandle: showHandle,
      child: Builder(builder: builder),
    ),
  );
}

/// What draws a sheet's top: the light edge and the handle. [child] is
/// what scrolls or sizes below it; the bottom system inset is kept clear.
class SheetFrame extends StatelessWidget {
  const SheetFrame({super.key, required this.child, this.showHandle = true});

  final Widget child;
  final bool showHandle;

  /// The handle's height with its padding (8 above, 4 below).
  static const handleExtent = 16.0;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colors.topHighlight,
            width: OnsetTokens.hairlineWidth,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showHandle) const SheetHandle(),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}

/// The 36 × 4 handle (8 above, 4 below).
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: SheetColors.of(context).handle,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

/// "RECENT MESSAGES", "REWARDS", "STREAM QUALITY": the section label.
class SheetSectionLabel extends StatelessWidget {
  const SheetSectionLabel(
    this.text, {
    super.key,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 6),
    this.color,
  });

  final String text;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: SheetText.section.copyWith(
          color: color ?? SheetColors.of(context).secondary,
        ),
      ),
    ),
  );
}

/// What sits at the end of a [SheetRow].
enum SheetRowEnd {
  none,

  /// Goes deeper (a sub-view, another sheet).
  chevron,

  /// Leaves the app (twitch.tv).
  external,
}

/// A row of a sheet: icon, label (and a second line), what it leads to;
/// 52 dp, 60 with a second line.
class SheetRow extends StatelessWidget {
  const SheetRow({
    super.key,
    required this.label,
    this.glyph,
    this.leading,
    this.detail,
    this.end = SheetRowEnd.none,
    this.trailing,
    this.onTap,
    this.danger = false,
    this.color,
    this.minHeight,
    this.semanticsLabel,
  });

  final String label;
  final SheetGlyphKind? glyph;

  /// Used instead of [glyph] (a colour dot, an image).
  final Widget? leading;
  final String? detail;
  final SheetRowEnd end;

  /// After the label, before [end] (a spinner, a time left, a switch).
  final Widget? trailing;
  final VoidCallback? onTap;

  /// A destructive action (Delete message, Clear chat).
  final bool danger;

  /// Overrides the label and icon colour (an active sleep timer).
  final Color? color;
  final double? minHeight;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final enabled = onTap != null;
    final labelColor = color ?? (danger ? colors.danger : colors.text);
    final iconColor = color ?? (danger ? colors.danger : colors.secondary);
    final endGlyph = switch (end) {
      SheetRowEnd.none => null,
      SheetRowEnd.chevron => SheetGlyph(
        SheetGlyphKind.chevronRight,
        size: 18,
        strokeWidth: 2,
        color: color ?? colors.tertiary,
      ),
      SheetRowEnd.external => SheetGlyph(
        SheetGlyphKind.external,
        size: 17,
        color: colors.tertiary,
      ),
    };
    final leading =
        this.leading ??
        (glyph == null ? null : SheetGlyph(glyph!, color: iconColor));
    return Semantics(
      button: enabled,
      enabled: enabled,
      label: semanticsLabel,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: minHeight ?? (detail == null ? 52 : 60),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Opacity(
                opacity: enabled ? 1 : 0.5,
                child: Row(
                  spacing: 14,
                  children: [
                    ?leading,
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 2,
                        children: [
                          Text(
                            label,
                            style: SheetText.row.copyWith(color: labelColor),
                          ),
                          if (detail case final detail?)
                            Text(
                              detail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SheetText.rowDetail.copyWith(
                                color: colors.secondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    ?trailing,
                    ?endGlyph,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A sub-view's top: a back chevron (44 dp) and its title, 48 dp high.
class SheetBackHeader extends StatelessWidget {
  const SheetBackHeader({super.key, required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, right: 8),
        child: Row(
          spacing: 2,
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: onBack,
              style: IconButton.styleFrom(
                minimumSize: const Size(44, 44),
                fixedSize: const Size(44, 44),
                padding: EdgeInsets.zero,
              ),
              icon: SheetGlyph(
                SheetGlyphKind.chevronLeft,
                size: 22,
                strokeWidth: 2,
                color: colors.text,
              ),
            ),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SheetText.subtitle.copyWith(color: colors.text),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The boards' switch: a 44 × 26 track (the signal colour when on), a
/// 20 dp knob that slides (260 ms, a cross-fade under reduce motion).
class OnsetSwitch extends StatelessWidget {
  const OnsetSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticsLabel,
  });

  final bool value;

  /// Null disables it.
  final ValueChanged<bool>? onChanged;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final accent = SheetColors.accentOf(context);
    final enabled = onChanged != null;
    final reduce = reduceMotionOf(context);
    final duration = reduce
        ? OnsetMotion.reducedFade
        : const Duration(milliseconds: 260);
    return Semantics(
      toggled: value,
      enabled: enabled,
      label: semanticsLabel,
      onTap: enabled ? () => onChanged!(!value) : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  onChanged!(!value);
                }
              : null,
          child: SizedBox(
            // A 44 dp target around the 26 dp track.
            width: 52,
            height: 44,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Opacity(
                opacity: enabled ? 1 : 0.5,
                child: AnimatedContainer(
                  duration: reduce
                      ? OnsetMotion.reducedFade
                      : const Duration(milliseconds: 200),
                  width: 44,
                  height: 26,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: value ? accent : colors.switchOff,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: AnimatedAlign(
                    duration: reduce ? Duration.zero : duration,
                    curve: OnsetMotion.standard,
                    alignment: value
                        ? AlignmentDirectional.centerEnd
                        : AlignmentDirectional.centerStart,
                    child: AnimatedContainer(
                      duration: duration,
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: value
                            ? SheetColors.onAccentOf(context)
                            : colors.knobOff,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The line under a moderation action: a thin running bar while it runs,
/// then what Twitch answered (a check when it went through).
class SheetStatusLine extends StatelessWidget {
  const SheetStatusLine({
    super.key,
    required this.busy,
    this.message,
    this.ok = true,
    this.padding = const EdgeInsets.fromLTRB(16, 6, 16, 0),
    this.minHeight = 30,
  });

  final bool busy;
  final String? message;
  final bool ok;
  final EdgeInsetsGeometry padding;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final message = this.message;
    final Widget content;
    if (busy) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(1),
        child: LinearProgressIndicator(
          minHeight: 2,
          color: SheetColors.accentOf(context),
          backgroundColor: colors.hairline,
        ),
      );
    } else if (message != null) {
      final color = ok ? colors.secondary : colors.danger;
      content = Semantics(
        liveRegion: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: SheetGlyph(
                ok ? SheetGlyphKind.check : SheetGlyphKind.warn,
                size: 14,
                strokeWidth: 2.2,
                color: color,
              ),
            ),
            Flexible(
              child: Text(
                message,
                style: SheetText.status.copyWith(color: color),
              ),
            ),
          ],
        ),
      );
    } else {
      content = const SizedBox.shrink();
    }
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: padding,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: AnimatedSwitcher(
            duration: motionDuration(
              context,
              const Duration(milliseconds: 260),
            ),
            child: KeyedSubtree(
              key: ValueKey(busy ? 'busy' : message),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// Which way a [SheetButton] reads.
enum SheetButtonTone {
  /// The one primary action: the signal colour.
  primary,

  /// A destructive confirmation (Ban, Clear).
  danger,

  /// A quiet one (Cancel).
  text,
}

/// The boards' pill buttons: 44 dp (48 with [large]), fully rounded.
class SheetButton extends StatelessWidget {
  const SheetButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.tone = SheetButtonTone.primary,
    this.large = false,
    this.icon,
    this.expand = false,
  });

  final String label;

  /// Null disables it (#2A2A2A, grey text).
  final VoidCallback? onPressed;
  final SheetButtonTone tone;
  final bool large;
  final Widget? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final height = large ? 48.0 : 44.0;
    final textStyle = SheetText.tabular(
      TextStyle(
        fontFamily: OnsetTokens.bodyFamily,
        fontSize: large ? 15 : 14,
        fontWeight: tone == SheetButtonTone.text
            ? FontWeight.w600
            : FontWeight.w700,
      ),
    );
    final child = icon == null
        ? Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)
        : Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              icon!,
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
    final size = Size(expand ? double.infinity : 0, height);
    if (tone == SheetButtonTone.text) {
      return TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: colors.text,
          minimumSize: size,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: const StadiumBorder(),
          textStyle: textStyle,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: child,
      );
    }
    final fill = tone == SheetButtonTone.danger
        ? colors.dangerFill
        : SheetColors.accentOf(context);
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: fill,
        foregroundColor: tone == SheetButtonTone.danger
            ? OnsetTokens.backgroundDark
            : SheetColors.onAccentOf(context),
        disabledBackgroundColor: colors.disabledFill,
        disabledForegroundColor: colors.disabledText,
        minimumSize: size,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: const StadiumBorder(),
        textStyle: textStyle,
        elevation: 0,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: child,
    );
  }
}

/// A choice pill (an emote set, a stake): 30 dp, or 36 with [large];
/// selected, it is ringed and tinted in the signal colour.
class SheetChoicePill extends StatelessWidget {
  const SheetChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.large = false,
    this.tabular = false,
    this.role = SheetChoiceRole.radio,
  });

  final String label;
  final bool selected;
  final VoidCallback? onSelected;
  final bool large;
  final bool tabular;
  final SheetChoiceRole role;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final accent = SheetColors.accentOf(context);
    final style = TextStyle(
      fontFamily: OnsetTokens.bodyFamily,
      fontSize: large ? 13 : 12,
      fontWeight: FontWeight.w600,
      color: selected ? accent : (large ? colors.text : colors.body),
    );
    final shape = StadiumBorder(
      side: selected
          ? BorderSide(color: accent, width: large ? 1 : 0.5)
          : BorderSide(color: colors.ring, width: OnsetTokens.hairlineWidth),
    );
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: role == SheetChoiceRole.radio,
      button: true,
      child: Material(
        color: selected ? SheetColors.accentTintOf(context) : colors.chip,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onSelected == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onSelected!();
                },
          child: Container(
            height: large ? 36 : 30,
            padding: EdgeInsets.symmetric(horizontal: large ? 14 : 12),
            alignment: Alignment.center,
            child: Text(
              label,
              maxLines: 1,
              style: tabular ? SheetText.tabular(style) : style,
            ),
          ),
        ),
      ),
    );
  }
}

/// How a [SheetChoicePill] is announced: one of a set, or a tab.
enum SheetChoiceRole { radio, tab }

/// The boards' dialog: a 326 dp card, 24 dp corners, #1E1E1E, a title
/// (18 / 700), its content and the actions at the end.
class OnsetDialog extends StatelessWidget {
  const OnsetDialog({
    super.key,
    required this.title,
    this.leading,
    this.message,
    this.content,
    required this.actions,
  });

  final String title;

  /// Before the title (a reward's tile).
  final Widget? leading;
  final String? message;
  final Widget? content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final titleText = Text(
      title,
      style: SheetText.title.copyWith(color: colors.text),
    );
    return Dialog(
      backgroundColor: colors.dialog,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kSheetRadius),
        side: BorderSide(color: colors.ring, width: OnsetTokens.hairlineWidth),
      ),
      // As AlertDialog does: the title names the dialog when it opens.
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: title,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 326),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                if (leading case final leading?)
                  Row(
                    spacing: 12,
                    children: [
                      leading,
                      Expanded(child: titleText),
                    ],
                  )
                else
                  titleText,
                if (message case final message?)
                  Text(
                    message,
                    style: SheetText.body.copyWith(color: colors.body),
                  ),
                ?content,
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: actions,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The text field of a dialog or a sheet: 48 dp, 12 dp corners, the
/// signal-coloured ring while focused.
class SheetTextField extends StatelessWidget {
  const SheetTextField({
    super.key,
    required this.controller,
    this.label,
    this.focusNode,
    this.autofocus = false,
    this.maxLength,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.counter = false,
    this.hint,
    this.textStyle,
    this.fill,
  });

  final TextEditingController controller;

  /// Above the field: 12 / 600.
  final String? label;
  final FocusNode? focusNode;
  final bool autofocus;
  final int? maxLength;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  /// "n / max" under the field.
  final bool counter;
  final String? hint;
  final TextStyle? textStyle;
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    final colors = SheetColors.of(context);
    final accent = SheetColors.accentOf(context);
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      keyboardType: keyboardType,
      inputFormatters: [
        if (maxLength case final max?) LengthLimitingTextInputFormatter(max),
        ...?inputFormatters,
      ],
      onChanged: onChanged,
      cursorColor: accent,
      style:
          textStyle ?? SheetText.body.copyWith(color: colors.text, height: 1.2),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: SheetText.body.copyWith(color: colors.tertiary),
        isDense: true,
        filled: true,
        fillColor: fill ?? colors.sheet,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: border(colors.ring, 1),
        enabledBorder: border(colors.ringStrong, 1),
        focusedBorder: border(accent.withValues(alpha: 0.55), 1),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        if (label case final label?)
          Text(
            label,
            style: TextStyle(
              fontFamily: OnsetTokens.bodyFamily,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.secondary,
            ),
          ),
        field,
        if (counter && maxLength != null)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => Text(
                // Characters, as the length limit counts them: an emoji
                // is one, not two UTF-16 units.
                '${controller.text.characters.length} / $maxLength',
                style: SheetText.tabular(
                  TextStyle(
                    fontFamily: OnsetTokens.bodyFamily,
                    fontSize: 11.5,
                    color: colors.tertiary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// An initial in a coloured disc, for someone the app has no picture of
/// (the chatters list, an @mention): the colour follows the name.
class InitialAvatar extends StatelessWidget {
  const InitialAvatar({super.key, required this.name, this.size = 28});

  final String name;
  final double size;

  /// The boards' palette for people without a picture.
  static const palette = [
    Color(0xFF7CB7FF),
    Color(0xFFFF9ECF),
    Color(0xFF7CF0FF),
    Color(0xFFFFD27A),
    Color(0xFFB6F27A),
    Color(0xFFFFB38A),
    Color(0xFFC9A7FF),
    Color(0xFF9EE6C2),
  ];

  static Color colorOf(String name) => name.isEmpty
      ? palette.first
      : palette[(name.codeUnitAt(0) + name.length) % palette.length];

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: colorOf(name)),
        child: Text(
          initial,
          style: TextStyle(
            fontFamily: OnsetTokens.bodyFamily,
            fontSize: size * 0.43,
            fontWeight: FontWeight.w800,
            height: 1,
            color: OnsetTokens.backgroundDark,
          ),
        ),
      ),
    );
  }
}
