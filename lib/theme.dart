import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared shadow for overlay controls and text on top of video content.
const kOverlayShadow = [
  Shadow(
    offset: Offset(0, 1),
    blurRadius: 4,
    color: Color.fromRGBO(0, 0, 0, 0.3),
  ),
];

/// Design tokens for the "Noir & Signal" visual system.
///
/// The rules these encode, in short:
/// - Backgrounds are pure neutral; surfaces all sit at the *same* elevation.
///   There is no elevation scale — depth is expressed with hairlines, never
///   with tints or drop shadows.
/// - [kAccent] means "live". It is used for the live badge, the active
///   navigation icon, the active tab underline, a selected check and an enabled
///   toggle — nothing else. Metadata stays neutral grey, otherwise the accent
///   is everywhere and stops signalling anything.
/// - Red is not part of the chrome. It survives only where it carries meaning:
///   the follower-only chat mode and destructive actions.
class OnsetTokens {
  const OnsetTokens._();

  // Neutrals ─────────────────────────────────────────────────────────────────
  static const backgroundDark = Color(0xFF0A0A0A);
  static const surfaceDark = Color(0xFF141414);
  static const backgroundLight = Color(0xFFF8F8F8);
  static const surfaceLight = Color(0xFFFFFFFF);

  /// Hairline used for every border and separator in the app.
  static const hairlineWidth = 0.5;
  static const hairlineDark = Color(0x14FFFFFF);
  static const hairlineLight = Color(0x14000000);

  // Accent ───────────────────────────────────────────────────────────────────
  /// Electric lime. Reserved for the live state and active selection.
  static const accent = Color(0xFFC8FF3D);

  // Type ─────────────────────────────────────────────────────────────────────
  /// Inter for everything: the free face closest to Twitch's own (Roobert is
  /// licensed). Headings, body and numbers share it, as on Twitch.
  static const displayFamily = 'Inter';
  static const bodyFamily = 'Inter';

  /// Every number the user reads (viewer counts, uptime, latency,
  /// resolutions, chat timestamps) uses Inter's tabular figures, so counters
  /// stop jittering as their digits change.
  static const monoFamily = 'Inter';

  /// The heading weight for [weight] on the 100–900 scale, rounded to the
  /// nearest weight Inter ships.
  static FontWeight displayWeight(double weight) =>
      FontWeight.values[((weight / 100).round() - 1).clamp(0, 8)];

  // Shape ────────────────────────────────────────────────────────────────────
  static const radiusCard = 12.0;
  static const radiusDialog = 16.0;
  static const radiusSmall = 8.0;

  /// Full pill, used by text inputs.
  static const radiusPill = 100.0;

  // Noir & Signal 2.0 ─────────────────────────────────────────────────────────
  // Added by the redesign, next to the values above (which keep their names
  // and values). From the design system: depth is three greys and a
  // hairline, never a shadow.

  /// The third grey, above [surfaceDark]: chips, pressed cards, secondary
  /// buttons.
  static const raisedDark = Color(0xFF1E1E1E);

  /// Loading skeletons on the dark ground, and the highlight of their sheen.
  /// Lighter than the #161616, which vanished on a sheet or card
  /// ([surfaceDark]): this reads on both, and the sheen stays a hint.
  static const skeletonDark = Color(0xFF232323);
  static const skeletonSheenDark = Color(0xFF2F2F2F);

  /// Text tiers on the dark ground. Primary for names and titles, body for
  /// live titles and chat, secondary for metadata (the same grey as
  /// [OnsetColors.metadata]), tertiary for inactive tabs and fine print.
  static const textPrimaryDark = Color(0xFFF5F5F5);
  static const textBodyDark = Color(0xFFD6D6D6);
  static const textSecondaryDark = Color(0xFFA1A1A1);
  static const textTertiaryDark = Color(0xFF8A8A8A);

  /// Hairlines on raised surfaces (12 %) and on secondary buttons (16 %).
  static const hairlineRaisedDark = Color(0x1FFFFFFF);
  static const hairlineStrongDark = Color(0x29FFFFFF);

  /// The signal at 10 %: the fill of a selected chip outlined in [accent].
  static const accentTint = Color(0x1AC8FF3D);

  /// Subs, gifts and the hype train — never a generic "OK".
  static const hype = Color(0xFF12A87A);

  /// Green text on a [hype]-tinted fill (the "Subscribe" button).
  static const hypeText = Color(0xFF3DDBA6);

  /// [hypeText] for the light theme: the hype green darkened to 4.5:1 on a
  /// light [hype] tint (Subscribe, the watch streak, the hype train sheet).
  /// Sub and gift notices use their own lime (`OnsetColors.subNoticeText`).
  static const hypeTextLight = Color(0xFF0A7957);

  /// Destructive actions only.
  static const danger = Color(0xFFFF5A5F);

  /// Hero cards and sheets: the top of the 8 / 12 / 16 / 24 / pill scale
  /// ([radiusSmall], [radiusCard], [radiusDialog], [radiusLarge],
  /// [radiusPill]).
  static const radiusLarge = 24.0;

  /// The "LIVE" badge.
  static const radiusBadge = 6.0;
}

/// The 4-pt spacing grid of Noir & Signal 2.0: 4 · 8 · 12 · 16 · 24 · 32,
/// plus a 2-pt hairline step.
abstract final class OnsetSpacing {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Screen edge on a phone, and on a tablet (a tablet keeps a wider
  /// margin instead of stretching the phone layout).
  static const gutterPhone = 16.0;
  static const gutterTablet = 28.0;
}

/// The type scale of Noir & Signal 2.0, all Inter. Big titles are tightened,
/// small text is opened up, and numbers that change use tabular figures so
/// they keep their width.
///
/// Styles carry no colour: they are merged onto the theme's (`copyWith` or
/// `DefaultTextStyle.merge`), so the scale serves the light theme too.
abstract final class OnsetType {
  static const _inter = OnsetTokens.displayFamily;
  static const _tabular = FontFeature.tabularFigures();

  /// Hero numbers and empty-state headlines.
  static const display = TextStyle(
    fontFamily: _inter,
    fontSize: 34,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.035 * 34,
    height: 1.05,
  );

  /// The title of a screen.
  static const screenTitle = TextStyle(
    fontFamily: _inter,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.02 * 24,
  );

  /// A section ("Continue watching").
  static const section = TextStyle(
    fontFamily: _inter,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.015 * 18,
  );

  /// A channel name on a card.
  static const channelName = TextStyle(
    fontFamily: _inter,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.01 * 16,
  );

  /// Live titles and chat.
  static const body = TextStyle(
    fontFamily: _inter,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.5,
  );

  /// Viewer counts, uptime, latency.
  static const meta = TextStyle(
    fontFamily: _inter,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    fontFeatures: [_tabular],
  );

  /// Uppercase labels (the caller upper-cases the string).
  static const label = TextStyle(
    fontFamily: _inter,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.14 * 11,
  );

  /// The "LIVE" badge.
  static const badge = TextStyle(
    fontFamily: _inter,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.06 * 11,
  );

  /// The "ONSET" wordmark in the header.
  static const wordmark = TextStyle(
    fontFamily: _inter,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.035 * 20,
  );

  /// [style] with tabular figures, for any number that changes in place.
  static TextStyle tabular(TextStyle style) {
    final features = style.fontFeatures ?? const <FontFeature>[];
    if (features.contains(_tabular)) return style;
    return style.copyWith(fontFeatures: [...features, _tabular]);
  }
}

/// App-specific semantic colors that extend Material's [ColorScheme].
///
/// Colors that map to Material 3 roles use [ColorScheme] directly:
/// - Links → [ColorScheme.primary]
/// - Mentions → [ColorScheme.error]
/// - First-time chatters → [ColorScheme.tertiary]
///
/// Access via `Theme.of(context).extension<OnsetColors>()!` or the
/// `context.onsetColors` convenience extension.
class OnsetColors extends ThemeExtension<OnsetColors> {
  final Color highlightedMessage;
  final Color emoteOnly;
  final Color followersOnly;
  final Color slowMode;
  final Color subOnly;
  final Color uniqueMode;
  final Color overlayOnSurface;

  /// The live state: badges, dots, the "LIVE" pill. Always the accent.
  final Color live;

  /// Every number the user reads. Deliberately unaccented.
  final Color metadata;

  /// Hairline borders and separators.
  final Color hairline;

  /// The accent bar of a sub or gift notice. Twitch draws these in its own
  /// purple; this app draws them in the signal lime,
  /// darkened on the light theme. Green stays with the hype train.
  final Color subNoticeAccent;

  /// The tinted background of a sub or gift notice: [subNoticeAccent] over
  /// the theme's background.
  final Color subNoticeBackground;

  /// Lime text that stays readable on [subNoticeBackground].
  final Color subNoticeText;

  const OnsetColors({
    required this.highlightedMessage,
    required this.emoteOnly,
    required this.followersOnly,
    required this.slowMode,
    required this.subOnly,
    required this.uniqueMode,
    required this.overlayOnSurface,
    required this.live,
    required this.metadata,
    required this.hairline,
    required this.subNoticeAccent,
    required this.subNoticeBackground,
    required this.subNoticeText,
  });

  static const light = OnsetColors(
    // Was Twitch's own #9146ff. Shifted to a colder violet so the app stops
    // borrowing the identity it is trying to move away from.
    highlightedMessage: Color(0xFFB15CFF),
    emoteOnly: Color(0xFFE59A2E),
    followersOnly: Color(0xFFD9534F),
    slowMode: Color(0xFF2C7BE5),
    subOnly: Color(0xFF2E9E5B),
    uniqueMode: Color(0xFF9B4DCA),
    overlayOnSurface: Colors.white,
    // Lime on white is unreadable, so the light theme darkens it rather than
    // falling back to red, which the system reserves for other meanings.
    live: Color(0xFF6B9E00),
    metadata: Color(0xFF6B6B6B),
    hairline: OnsetTokens.hairlineLight,
    // The lime darkened until a 4 dp bar shows on white.
    subNoticeAccent: Color(0xFF6B8A00),
    // The accent at 8% over the light background.
    subNoticeBackground: Color(0xFFEDEFE4),
    // Darkened until it passes 4.5:1 on the tint (5.6:1).
    subNoticeText: Color(0xFF4F6600),
  );

  static const dark = OnsetColors(
    highlightedMessage: Color(0xFFB15CFF),
    emoteOnly: Color(0xFFFFCC80),
    followersOnly: Color(0xFFE57373),
    slowMode: Color(0xFF64B5F6),
    subOnly: Color(0xFF81C784),
    uniqueMode: Color(0xFFBA68C8),
    overlayOnSurface: Colors.white,
    live: OnsetTokens.accent,
    metadata: OnsetTokens.textSecondaryDark,
    hairline: OnsetTokens.hairlineDark,
    subNoticeAccent: OnsetTokens.accent,
    // The accent at 7% over the dark background.
    subNoticeBackground: Color(0xFF171B0E),
    subNoticeText: OnsetTokens.accent,
  );

  @override
  OnsetColors copyWith({
    Color? highlightedMessage,
    Color? emoteOnly,
    Color? followersOnly,
    Color? slowMode,
    Color? subOnly,
    Color? uniqueMode,
    Color? overlayOnSurface,
    Color? live,
    Color? metadata,
    Color? hairline,
    Color? subNoticeAccent,
    Color? subNoticeBackground,
    Color? subNoticeText,
  }) {
    return OnsetColors(
      highlightedMessage: highlightedMessage ?? this.highlightedMessage,
      emoteOnly: emoteOnly ?? this.emoteOnly,
      followersOnly: followersOnly ?? this.followersOnly,
      slowMode: slowMode ?? this.slowMode,
      subOnly: subOnly ?? this.subOnly,
      uniqueMode: uniqueMode ?? this.uniqueMode,
      overlayOnSurface: overlayOnSurface ?? this.overlayOnSurface,
      live: live ?? this.live,
      metadata: metadata ?? this.metadata,
      hairline: hairline ?? this.hairline,
      subNoticeAccent: subNoticeAccent ?? this.subNoticeAccent,
      subNoticeBackground: subNoticeBackground ?? this.subNoticeBackground,
      subNoticeText: subNoticeText ?? this.subNoticeText,
    );
  }

  @override
  OnsetColors lerp(OnsetColors? other, double t) {
    if (other is! OnsetColors) return this;
    return OnsetColors(
      highlightedMessage: Color.lerp(
        highlightedMessage,
        other.highlightedMessage,
        t,
      )!,
      emoteOnly: Color.lerp(emoteOnly, other.emoteOnly, t)!,
      followersOnly: Color.lerp(followersOnly, other.followersOnly, t)!,
      slowMode: Color.lerp(slowMode, other.slowMode, t)!,
      subOnly: Color.lerp(subOnly, other.subOnly, t)!,
      uniqueMode: Color.lerp(uniqueMode, other.uniqueMode, t)!,
      overlayOnSurface: Color.lerp(
        overlayOnSurface,
        other.overlayOnSurface,
        t,
      )!,
      live: Color.lerp(live, other.live, t)!,
      metadata: Color.lerp(metadata, other.metadata, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      subNoticeAccent: Color.lerp(subNoticeAccent, other.subNoticeAccent, t)!,
      subNoticeBackground: Color.lerp(
        subNoticeBackground,
        other.subNoticeBackground,
        t,
      )!,
      subNoticeText: Color.lerp(subNoticeText, other.subNoticeText, t)!,
    );
  }
}

/// Text styles that sit outside Material's scale: the monospace metadata style
/// and the wide-tracked uppercase label used for categories and section
/// headers.
class OnsetTextStyles extends ThemeExtension<OnsetTextStyles> {
  /// Viewer counts, uptime, latency, resolutions, chat timestamps.
  final TextStyle metadata;

  /// Category names and section headers: uppercase, small, widely tracked.
  final TextStyle label;

  const OnsetTextStyles({required this.metadata, required this.label});

  static const _mono = TextStyle(
    fontFamily: OnsetTokens.monoFamily,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static OnsetTextStyles resolve(Color metadataColor) => OnsetTextStyles(
    metadata: _mono.copyWith(fontSize: 13, color: metadataColor),
    label: _mono.copyWith(
      fontSize: 11,
      letterSpacing: 1.2,
      color: metadataColor,
    ),
  );

  @override
  OnsetTextStyles copyWith({TextStyle? metadata, TextStyle? label}) =>
      OnsetTextStyles(
        metadata: metadata ?? this.metadata,
        label: label ?? this.label,
      );

  @override
  OnsetTextStyles lerp(OnsetTextStyles? other, double t) {
    if (other is! OnsetTextStyles) return this;
    return OnsetTextStyles(
      metadata: TextStyle.lerp(metadata, other.metadata, t)!,
      label: TextStyle.lerp(label, other.label, t)!,
    );
  }
}

class OnsetThemes {
  final Color colorSchemeSeed;

  const OnsetThemes({required this.colorSchemeSeed});

  ThemeData get light => createBaseTheme(
    colorScheme: ColorScheme.fromSeed(seedColor: colorSchemeSeed),
    backgroundColor: OnsetTokens.backgroundLight,
    surfaceColor: OnsetTokens.surfaceLight,
  );

  ThemeData get dark => createBaseTheme(
    colorScheme: ColorScheme.fromSeed(
      seedColor: colorSchemeSeed,
      brightness: Brightness.dark,
    ),
    backgroundColor: OnsetTokens.backgroundDark,
    surfaceColor: OnsetTokens.surfaceDark,
  );

  ThemeData createBaseTheme({
    required ColorScheme colorScheme,
    Color? backgroundColor,
    Color? surfaceColor,
  }) {
    final isDark = colorScheme.brightness == Brightness.dark;
    final onsetColors = isDark ? OnsetColors.dark : OnsetColors.light;

    final borderColor = onsetColors.hairline;
    const borderWidth = OnsetTokens.hairlineWidth;

    final surface = surfaceColor ?? colorScheme.surface;

    return ThemeData(
      extensions: [onsetColors, OnsetTextStyles.resolve(onsetColors.metadata)],
      colorScheme: colorScheme,
      fontFamily: OnsetTokens.bodyFamily,
      splashFactory: Platform.isIOS ? NoSplash.splashFactory : null,
      scaffoldBackgroundColor: backgroundColor,
      // Flat by construction: depth comes from hairlines, never from tints or
      // drop shadows.
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        surfaceTintColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(
            Radius.circular(OnsetTokens.radiusCard),
          ),
          side: BorderSide(color: borderColor, width: borderWidth),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        elevation: 0,
        backgroundColor: backgroundColor,
        surfaceTintColor: backgroundColor,
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(surface),
          surfaceTintColor: WidgetStatePropertyAll(surface),
          elevation: const WidgetStatePropertyAll(0),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 4),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: const BorderRadius.all(
                Radius.circular(OnsetTokens.radiusCard),
              ),
              side: BorderSide(color: borderColor, width: borderWidth),
            ),
          ),
        ),
      ),
      menuButtonTheme: MenuButtonThemeData(
        style: MenuItemButton.styleFrom(visualDensity: VisualDensity.compact),
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: backgroundColor,
        surfaceTintColor: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(
            Radius.circular(OnsetTokens.radiusDialog),
          ),
          side: BorderSide(color: borderColor, width: borderWidth),
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: backgroundColor,
        surfaceTintColor: backgroundColor,
        // Titles are left-aligned everywhere; a centred title would read as a
        // different app on every second screen.
        centerTitle: false,
        titleSpacing: 0,
        // Declared once here rather than per screen. A locally-set
        // systemOverlayStyle replaces this object wholesale, so any screen
        // that sets its own would silently drop the navigation bar colour and
        // let Android paint its default bar under our background.
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: backgroundColor,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: isDark
              ? Brightness.light
              : Brightness.dark,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        // Rows are dense: the chat settings page alone carries ~30 of them.
        visualDensity: VisualDensity.compact,
        minVerticalPadding: 10,
      ),
      // Material 3 gives ElevatedButton a real elevation and a surface tint,
      // which is the one shadow left in the app (the chat "resume scroll"
      // button). Flattened like every other surface.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: surface,
          foregroundColor: colorScheme.onSurface,
          surfaceTintColor: surface,
          shadowColor: Colors.transparent,
          side: BorderSide(color: borderColor, width: borderWidth),
        ),
      ),
      // The primary call to action — "Connect with Twitch", "Save", "Yes".
      //
      // Left unconfigured it takes [ColorScheme.primary], which Material 3
      // derives by running the accent through its tonal palette. That
      // desaturates the lime into a sage green: measured on device at
      // #BDCE8B against the #C8FF3D the toggles and live badges show, so the
      // main button was visibly off-accent next to an enabled switch on the
      // same screen. Bound to the accent directly instead, exactly like
      // [switchTheme], [checkboxTheme] and [radioTheme] below.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: onsetColors.live,
          foregroundColor: isDark ? OnsetTokens.backgroundDark : Colors.white,
          disabledBackgroundColor: colorScheme.onSurface.withValues(
            alpha: 0.12,
          ),
          shadowColor: Colors.transparent,
        ),
      ),
      // Left unconfigured, a selected segment fills with
      // [ColorScheme.secondaryContainer] — a tinted container that reintroduces
      // the Material palette. Selection is lime here, like every other
      // selected state.
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? onsetColors.live
                : surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? (isDark ? OnsetTokens.backgroundDark : Colors.white)
                : colorScheme.onSurface,
          ),
          side: WidgetStatePropertyAll(
            BorderSide(color: borderColor, width: borderWidth),
          ),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(
                Radius.circular(OnsetTokens.radiusSmall),
              ),
            ),
          ),
        ),
      ),
      // The default tile draws a full-width divider above and below itself when
      // expanded, which is a second, heavier separator language next to the
      // hairline.
      expansionTileTheme: const ExpansionTileThemeData(
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        shape: Border(),
        collapsedShape: Border(),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? (isDark ? OnsetTokens.backgroundDark : Colors.white)
              : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? onsetColors.live : null,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? Colors.transparent : null,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.onSurface,
        thumbColor: colorScheme.onSurface,
        inactiveTrackColor: colorScheme.onSurface.withValues(alpha: 0.16),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? onsetColors.live : null,
        ),
        checkColor: WidgetStatePropertyAll(
          isDark ? OnsetTokens.backgroundDark : Colors.white,
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? onsetColors.live : null,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: onsetColors.live,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: surface,
        showCheckmark: false,
        // A selected chip is marked by a lime outline rather than by a filled
        // background, so chat tabs and chat-mode chips read as "active" the
        // same way the navigation and tab bars do.
        side: WidgetStateBorderSide.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? BorderSide(color: onsetColors.live)
              : BorderSide(color: borderColor, width: borderWidth),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(OnsetTokens.radiusSmall),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.normal,
        ),
        border: _pill(BorderSide(color: borderColor, width: borderWidth)),
        enabledBorder: _pill(
          BorderSide(color: borderColor, width: borderWidth),
        ),
        disabledBorder: _pill(
          BorderSide(color: borderColor, width: borderWidth),
        ),
        focusedBorder: _pill(
          BorderSide(color: colorScheme.onSurface.withValues(alpha: 0.4)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: backgroundColor,
        surfaceTintColor: backgroundColor,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        indicatorColor: Colors.transparent,
        indicatorShape: const CircleBorder(),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        tabAlignment: TabAlignment.start,
        indicatorColor: onsetColors.live,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: colorScheme.onSurface,
        unselectedLabelColor: onsetColors.metadata,
      ),
      tooltipTheme: TooltipThemeData(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        showDuration: const Duration(seconds: 2),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.all(
            Radius.circular(OnsetTokens.radiusCard),
          ),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        textStyle: TextStyle(color: colorScheme.onSurface),
      ),
      snackBarTheme: SnackBarThemeData(
        showCloseIcon: true,
        elevation: 0,
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: borderColor, width: borderWidth),
          borderRadius: const BorderRadius.all(
            Radius.circular(OnsetTokens.radiusCard),
          ),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: DividerThemeData(
        thickness: borderWidth,
        space: borderWidth,
        color: borderColor,
      ),
      textTheme: TextTheme(
        // Alert dialog title
        headlineSmall: TextStyle(
          fontFamily: OnsetTokens.displayFamily,
          fontWeight: OnsetTokens.displayWeight(650),
          fontSize: 18,
          letterSpacing: -0.019,
        ),

        // App bar title
        titleLarge: TextStyle(
          fontFamily: OnsetTokens.displayFamily,
          fontWeight: OnsetTokens.displayWeight(700),
          fontSize: 24,
          letterSpacing: -0.4,
        ),

        // Section titles
        titleMedium: TextStyle(
          fontFamily: OnsetTokens.displayFamily,
          fontWeight: OnsetTokens.displayWeight(600),
          letterSpacing: -0.011,
        ),

        // Tab bar title
        titleSmall: TextStyle(
          fontFamily: OnsetTokens.displayFamily,
          fontWeight: OnsetTokens.displayWeight(600),
          fontSize: 16,
          letterSpacing: -0.011,
        ),

        // Labels
        labelLarge: const TextStyle(
          fontWeight: FontWeight.w500,
          letterSpacing: -0.006,
        ),
        labelMedium: const TextStyle(
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
        ),
        labelSmall: const TextStyle(
          fontWeight: FontWeight.w500,
          letterSpacing: 0.005,
        ),

        // Body text
        bodyLarge: const TextStyle(
          fontWeight: FontWeight.w500,
          letterSpacing: -0.011,
        ),
        bodyMedium: const TextStyle(letterSpacing: -0.006),
        bodySmall: const TextStyle(letterSpacing: 0),
      ),
    );
  }

  static OutlineInputBorder _pill(BorderSide side) => OutlineInputBorder(
    borderRadius: const BorderRadius.all(
      Radius.circular(OnsetTokens.radiusPill),
    ),
    borderSide: side,
  );
}
