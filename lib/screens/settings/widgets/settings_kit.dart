import 'package:flutter/material.dart';
import 'package:onset/screens/settings/widgets/settings_glyph.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/motion/motion.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';

/// The colours of the profile and settings screens (boards Moi,
/// MoiDeconnecte, Parametres, ParametresTablette, ParametresDetails,
/// MiseAJour). The boards are drawn dark; the light values keep the same
/// tiers on a pale ground.
@immutable
class SettingsColors {
  const SettingsColors({
    required this.card,
    required this.cardRing,
    required this.tile,
    required this.tileIcon,
    required this.hairline,
    required this.text,
    required this.body,
    required this.secondary,
    required this.tertiary,
    required this.track,
    required this.trackRing,
    required this.stackIdle,
    required this.stackRing,
    required this.switchOff,
    required this.switchRing,
    required this.knobOff,
    required this.sliderTrack,
    required this.thumb,
    required this.danger,
    required this.dangerTint,
    required this.dangerFill,
    required this.well,
    required this.sheet,
    required this.dialog,
    required this.button,
    required this.buttonRing,
    required this.handle,
    required this.pressed,
  });

  /// A group's card: #141414.
  final Color card;

  /// Its 0.5 dp ring (white 8 %).
  final Color cardRing;

  /// The 32 dp tile behind a row's icon: #1E1E1E.
  final Color tile;
  final Color tileIcon;

  /// The line between two rows (white 8 %).
  final Color hairline;

  final Color text;
  final Color body;
  final Color secondary;
  final Color tertiary;

  /// The segmented choice's track: #0E0E0E, ringed white 10 %.
  final Color track;
  final Color trackRing;

  /// An unselected stacked choice: #1A1A1A, ringed white 8 %.
  final Color stackIdle;
  final Color stackRing;

  /// A switch turned off: #2A2A2A, ringed white 16 %, a #D6D6D6 knob.
  final Color switchOff;
  final Color switchRing;
  final Color knobOff;

  /// A slider's empty track and its thumb.
  final Color sliderTrack;
  final Color thumb;

  /// "Log out", "Clear": #FF6B6F, its tile tinted 12 %; the confirming
  /// button #FF5A5F.
  final Color danger;
  final Color dangerTint;
  final Color dangerFill;

  /// A card inside a card (the chat preview, the update notes): #0E0E0E.
  final Color well;

  /// A bottom sheet: #161616; a dialog: #1A1A1A.
  final Color sheet;
  final Color dialog;

  /// A quiet pill button (Cancel, My channel): #1E1E1E or #262626.
  final Color button;
  final Color buttonRing;

  final Color handle;

  /// A row under the finger.
  final Color pressed;

  static const dark = SettingsColors(
    card: OnsetTokens.surfaceDark,
    cardRing: Color(0x14FFFFFF),
    tile: OnsetTokens.raisedDark,
    tileIcon: OnsetTokens.textBodyDark,
    hairline: Color(0x14FFFFFF),
    text: OnsetTokens.textPrimaryDark,
    body: OnsetTokens.textBodyDark,
    secondary: OnsetTokens.textSecondaryDark,
    tertiary: OnsetTokens.textTertiaryDark,
    track: Color(0xFF0E0E0E),
    trackRing: Color(0x1AFFFFFF),
    stackIdle: Color(0xFF1A1A1A),
    stackRing: Color(0x14FFFFFF),
    switchOff: Color(0xFF2A2A2A),
    switchRing: Color(0x29FFFFFF),
    knobOff: OnsetTokens.textBodyDark,
    sliderTrack: Color(0xFF2A2A2A),
    thumb: OnsetTokens.textPrimaryDark,
    danger: Color(0xFFFF6B6F),
    dangerTint: Color(0x1FFF5A5F),
    dangerFill: OnsetTokens.danger,
    well: Color(0xFF0E0E0E),
    sheet: Color(0xFF161616),
    dialog: Color(0xFF1A1A1A),
    button: OnsetTokens.raisedDark,
    buttonRing: Color(0x1FFFFFFF),
    handle: Color(0x38FFFFFF),
    pressed: Color(0x0DFFFFFF),
  );

  static const light = SettingsColors(
    card: OnsetTokens.surfaceLight,
    cardRing: Color(0x14000000),
    tile: Color(0xFFF0F0F0),
    tileIcon: Color(0xFF3A3A3A),
    hairline: Color(0x14000000),
    text: Color(0xFF0A0A0A),
    body: Color(0xFF3A3A3A),
    secondary: Color(0xFF6B6B6B),
    tertiary: Color(0xFF6B6B6B),
    track: Color(0xFFF0F0F0),
    trackRing: Color(0x14000000),
    stackIdle: Color(0xFFF5F5F5),
    stackRing: Color(0x14000000),
    switchOff: Color(0xFFD6D6D6),
    switchRing: Color(0x14000000),
    knobOff: Color(0xFFFFFFFF),
    sliderTrack: Color(0xFFDADADA),
    thumb: Color(0xFFFFFFFF),
    danger: Color(0xFFC62828),
    dangerTint: Color(0x1FE5484D),
    dangerFill: Color(0xFFE5484D),
    well: Color(0xFFF5F5F5),
    sheet: OnsetTokens.surfaceLight,
    dialog: OnsetTokens.surfaceLight,
    button: Color(0xFFEFEFEF),
    buttonRing: Color(0x1A000000),
    handle: Color(0xFFD4D4D4),
    pressed: Color(0x0D000000),
  );

  static SettingsColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  /// The signal colour: on, selected, the one primary action.
  static Color accentOf(BuildContext context) => context.onsetColors.live;

  /// What reads on [accentOf]: near-black on a light accent, white on a dark
  /// one (whichever contrasts more).
  static Color onAccentOf(BuildContext context) {
    final luminance = accentOf(context).computeLuminance();
    final onBlack = (luminance + 0.05) / 0.05;
    final onWhite = 1.05 / (luminance + 0.05);
    return onBlack >= onWhite ? OnsetTokens.backgroundDark : Colors.white;
  }
}

/// The type of the profile and settings screens (Inter, the boards' sizes).
abstract final class SettingsText {
  /// "ACCOUNT", "MESSAGE SIZING": 11 / 600, 0.14 em, upper case.
  static const section = TextStyle(
    fontFamily: OnsetTokens.bodyFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.54,
    height: 1.3,
  );

  /// A setting: 15 / 500.
  static const row = TextStyle(
    fontFamily: OnsetTokens.bodyFamily,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  /// Its explanation: 12.5 / 1.45.
  static const detail = TextStyle(
    fontFamily: OnsetTokens.bodyFamily,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  /// The value at a row's end ("All languages", "3"): 13, tabular.
  static final value = OnsetType.tabular(
    const TextStyle(
      fontFamily: OnsetTokens.bodyFamily,
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.3,
    ),
  );

  /// A page's title next to its back button: 18 / 700.
  static const pageTitle = TextStyle(
    fontFamily: OnsetTokens.bodyFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.36,
    height: 1.2,
  );

  /// A dialog's title: 19 / 700.
  static const dialogTitle = TextStyle(
    fontFamily: OnsetTokens.bodyFamily,
    fontSize: 19,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.285,
    height: 1.25,
  );

  /// Body copy: 14 / 1.55.
  static const body = TextStyle(
    fontFamily: OnsetTokens.bodyFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.55,
  );
}

/// The duration of a settings control's change, a short fade under reduce
/// motion.
Duration settingsMotion(BuildContext context, int milliseconds) =>
    motionDuration(context, Duration(milliseconds: milliseconds));

/// "ACCOUNT", "THEME": a group's label.
class SettingsSectionLabel extends StatelessWidget {
  const SettingsSectionLabel(
    this.text, {
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 4),
  });

  final String text;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: SettingsText.section.copyWith(
          color: SettingsColors.of(context).secondary,
        ),
      ),
    ),
  );
}

/// A rounded card: #141414, 16 dp corners, the 0.5 dp ring.
class SettingsCard extends StatelessWidget {
  const SettingsCard({
    super.key,
    required this.child,
    this.radius = 16,
    this.padding,
    this.ring,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(
        color: ring ?? colors.cardRing,
        width: OnsetTokens.hairlineWidth,
      ),
    );
    return Material(
      color: colors.card,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );
  }
}

/// A group of settings: its label, then a card of rows separated by a
/// hairline. A group without [title] is a card alone ("Log out").
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  /// What a group weighs in a column (its rows, its label).
  int get weight => children.length + (title == null ? 0 : 1);

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    final rows = <Widget>[];
    for (final (index, child) in children.indexed) {
      if (index > 0) {
        rows.add(
          Divider(
            height: OnsetTokens.hairlineWidth,
            thickness: OnsetTokens.hairlineWidth,
            color: colors.hairline,
          ),
        );
      }
      rows.add(child);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        if (title case final title?) SettingsSectionLabel(title),
        SettingsCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows,
          ),
        ),
      ],
    );
  }
}

/// The 32 dp tile with a row's icon (tinted red for a destructive one).
class SettingsIconTile extends StatelessWidget {
  const SettingsIconTile(this.glyph, {super.key, this.danger = false});

  final SettingsGlyphKind glyph;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: danger ? colors.dangerTint : colors.tile,
        borderRadius: BorderRadius.circular(10),
      ),
      child: SettingsGlyph(
        glyph,
        color: danger ? colors.danger : colors.tileIcon,
      ),
    );
  }
}

/// What sits at the end of a [SettingsRow].
enum SettingsRowEnd {
  none,

  /// Opens a page or a sheet.
  chevron,

  /// Leaves the app (twitch.tv, a website).
  external,
}

/// A row of a settings card: an icon tile, its title (and a second line), a
/// value, what it leads to; 56 dp at least.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    this.glyph,
    this.subtitle,
    this.value,
    this.trailing,
    this.end = SettingsRowEnd.none,
    this.onTap,
    this.onLongPress,
    this.danger = false,
    this.strong = false,
    this.enabled = true,
    this.minHeight = 56,
    this.semanticsLabel,
  });

  final String title;
  final SettingsGlyphKind? glyph;
  final Widget? subtitle;

  /// At the end, before [end] ("All languages", "3").
  final String? value;
  final Widget? trailing;
  final SettingsRowEnd end;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool danger;

  /// A section row (General, Video): its title 600 instead of 500.
  final bool strong;
  final bool enabled;
  final double minHeight;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    final titleStyle = SettingsText.row.copyWith(
      color: danger ? colors.danger : colors.text,
      fontWeight: strong ? FontWeight.w600 : FontWeight.w500,
    );
    final endGlyph = switch (end) {
      SettingsRowEnd.none => null,
      SettingsRowEnd.chevron => SettingsGlyph(
        SettingsGlyphKind.chevronRight,
        strokeWidth: 2,
        color: colors.tertiary,
      ),
      SettingsRowEnd.external => SettingsGlyph(
        SettingsGlyphKind.external,
        size: 17,
        color: colors.tertiary,
      ),
    };
    final active = enabled && (onTap != null || onLongPress != null);
    return Semantics(
      button: onTap != null,
      enabled: active,
      label: semanticsLabel,
      child: InkWell(
        onTap: enabled ? onTap : null,
        onLongPress: enabled ? onLongPress : null,
        splashFactory: NoSplash.splashFactory,
        highlightColor: colors.pressed,
        child: Opacity(
          opacity: enabled ? 1 : 0.42,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
              child: LayoutBuilder(
                builder: (context, constraints) =>
                    _row(context, constraints.maxWidth, titleStyle, endGlyph),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    double rowWidth,
    TextStyle titleStyle,
    Widget? endGlyph,
  ) {
    final colors = SettingsColors.of(context);
    final value = this.value;
    return Row(
      spacing: 12,
      children: [
        if (glyph case final glyph?) SettingsIconTile(glyph, danger: danger),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 3,
            children: [
              Text(title, style: titleStyle),
              if (subtitle case final subtitle?)
                DefaultTextStyle.merge(
                  style: SettingsText.detail.copyWith(color: colors.secondary),
                  child: subtitle,
                ),
            ],
          ),
        ),
        if (value != null && value.isNotEmpty)
          ConstrainedBox(
            // The board's 46 % of the row at most.
            constraints: BoxConstraints(maxWidth: rowWidth * 0.46),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: SettingsText.value.copyWith(color: colors.secondary),
            ),
          ),
        ?trailing,
        ?endGlyph,
      ],
    );
  }
}

/// The boards' switch: a 46 × 28 track (the signal colour when on), a 22 dp
/// knob that slides (300 ms; a fade under reduce motion).
class SettingsSwitch extends StatelessWidget {
  const SettingsSwitch({super.key, required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    final accent = SettingsColors.accentOf(context);
    final reduce = reduceMotionOf(context);
    final slide = reduce ? Duration.zero : const Duration(milliseconds: 300);
    final fade = settingsMotion(context, 220);
    return ExcludeSemantics(
      child: AnimatedContainer(
        duration: fade,
        curve: OnsetMotion.standard,
        width: 46,
        height: 28,
        decoration: ShapeDecoration(
          color: value ? accent : colors.switchOff,
          shape: StadiumBorder(
            side: value
                ? BorderSide.none
                : BorderSide(
                    color: colors.switchRing,
                    width: OnsetTokens.hairlineWidth,
                  ),
          ),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: slide,
              curve: OnsetMotion.standard,
              top: 3,
              left: value ? 21 : 3,
              child: AnimatedContainer(
                duration: fade,
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value ? OnsetTokens.backgroundDark : colors.knobOff,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A pill button of the boards: 44 dp (48 with [large]), fully rounded.
enum SettingsButtonTone {
  /// The one primary action: the signal colour.
  primary,

  /// A destructive confirmation (Log out, Reset).
  danger,

  /// A quiet one (Cancel, Later, My channel).
  quiet,
}

class SettingsButton extends StatelessWidget {
  const SettingsButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.tone = SettingsButtonTone.quiet,
    this.large = false,
    this.icon,
    this.expand = false,
  });

  final String label;

  /// Null disables it.
  final VoidCallback? onPressed;
  final SettingsButtonTone tone;
  final bool large;
  final Widget? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    final (fill, foreground) = switch (tone) {
      SettingsButtonTone.primary => (
        SettingsColors.accentOf(context),
        SettingsColors.onAccentOf(context),
      ),
      SettingsButtonTone.danger => (
        colors.dangerFill,
        OnsetTokens.backgroundDark,
      ),
      SettingsButtonTone.quiet => (colors.button, colors.text),
    };
    final style = TextStyle(
      fontFamily: OnsetTokens.bodyFamily,
      fontSize: large ? 15 : 14,
      fontWeight: tone == SettingsButtonTone.quiet
          ? FontWeight.w600
          : FontWeight.w700,
    );
    final label = Text(
      this.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: fill,
        foregroundColor: foreground,
        disabledBackgroundColor: colors.switchOff,
        disabledForegroundColor: colors.tertiary,
        minimumSize: Size(expand ? double.infinity : 0, large ? 48 : 44),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: StadiumBorder(
          side: tone == SettingsButtonTone.quiet
              ? BorderSide(
                  color: colors.buttonRing,
                  width: OnsetTokens.hairlineWidth,
                )
              : BorderSide.none,
        ),
        textStyle: style,
        elevation: 0,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: icon == null
          ? label
          : Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                icon!,
                Flexible(child: label),
              ],
            ),
    );
  }
}

/// The boards' dialog: a 360 dp card (420 on a tablet), 24 dp corners,
/// #1A1A1A, a title (19 / 700), its text and the actions at the end.
class SettingsDialog extends StatelessWidget {
  const SettingsDialog({
    super.key,
    required this.title,
    this.message,
    this.content,
    required this.actions,
  });

  final String title;
  final String? message;
  final Widget? content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    return Dialog(
      backgroundColor: colors.dialog,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(20),
      // The keyboard's room at once: an animated inset lags the keyboard,
      // and a focused field revealed before the dialog shrinks ends up
      // under it.
      insetAnimationDuration: Duration.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OnsetTokens.radiusLarge),
        side: BorderSide(
          color: colors.cardRing,
          width: OnsetTokens.hairlineWidth,
        ),
      ),
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: title,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: context.isLargeScreen ? 420 : 360,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 14,
              children: [
                Text(
                  title,
                  style: SettingsText.dialogTitle.copyWith(color: colors.text),
                ),
                if (message case final message?)
                  Text(
                    message,
                    style: SettingsText.body.copyWith(color: colors.body),
                  ),
                ?content,
                Padding(
                  padding: const EdgeInsets.only(top: 4),
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

/// Asks [title] / [message] with "Cancel" and a destructive [confirm]
/// button; true when confirmed.
Future<bool> confirmSettingsAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirm,
  bool danger = true,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: kSheetScrim,
    builder: (context) => SettingsDialog(
      title: title,
      message: message,
      actions: [
        SettingsButton(
          label: 'Cancel',
          onPressed: () => Navigator.pop(context, false),
        ),
        SettingsButton(
          label: confirm,
          tone: danger ? SettingsButtonTone.danger : SettingsButtonTone.primary,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// A short note under or between groups (12.5, secondary).
class SettingsNote extends StatelessWidget {
  const SettingsNote(this.text, {super.key, this.padding});

  final String text;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding:
        padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Text(
      text,
      style: SettingsText.detail.copyWith(
        height: 1.5,
        color: SettingsColors.of(context).secondary,
      ),
    ),
  );
}
