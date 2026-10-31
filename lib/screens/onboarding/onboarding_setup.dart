import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/l10n/enum_labels.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/screens/onboarding/onboarding_accent_picker.dart';
import 'package:onset/screens/onboarding/onboarding_parts.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/common_utils.dart';
import 'package:onset/widgets/motion/haptics.dart';
import 'package:onset/widgets/motion/motion.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';
import 'package:onset/widgets/onset_cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

const _robotty = 'https://recent-messages.robotty.de/';

/// Where the login of the onboarding stands, as Setup tells it.
enum OnboardingLogin {
  /// Not tried, or done: the store says who is logged in.
  none,

  /// Twitch handed a token back and the login is under way.
  pending,

  /// Twitch handed a token back but the login did not go through.
  failed,
}

/// Step 3, Setup: who is logged
/// in, a small live preview that follows the theme and the accent, the
/// theme, the accent colour, the chat history and the crash reports.
class OnboardingSetupStep extends StatefulWidget {
  const OnboardingSetupStep({
    super.key,
    required this.layout,
    required this.accent,
    required this.settings,
    required this.auth,
    required this.login,
    required this.preview,
    required this.onNext,
  });

  final OnboardingStepLayout layout;
  final Color accent;
  final SettingsStore settings;
  final AuthStore auth;

  /// Where the login stands.
  final OnboardingLogin login;

  /// The live channel the preview shows, when one could be had.
  final StreamTwitch? preview;

  final VoidCallback onNext;

  @override
  State<OnboardingSetupStep> createState() => _OnboardingSetupStepState();
}

class _OnboardingSetupStepState extends State<OnboardingSetupStep> {
  late final _robottyLink = TapGestureRecognizer()..onTap = _openRobotty;

  void _openRobotty() => launchUrl(
    Uri.parse(_robotty),
    mode: widget.settings.launchUrlExternal
        ? LaunchMode.externalApplication
        : LaunchMode.inAppBrowserView,
  );

  @override
  void dispose() {
    _robottyLink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tablet = widget.layout.tablet;
    final settings = widget.settings;
    final accent = widget.accent;
    final l = context.l10n;
    return OnboardingStepFrame(
      layout: widget.layout,
      content: [
        StepRise(
          order: 1,
          child: Semantics(
            header: true,
            child: Text(
              l.onboardingSetupTitle,
              style: OnboardingType.title(tablet: tablet),
            ),
          ),
        ),
        SizedBox(height: tablet ? 12 : 10),
        StepRise(
          order: 2,
          child: Text(
            l.onboardingSetupLead,
            style: OnboardingType.lead(tablet: tablet),
          ),
        ),
        const SizedBox(height: 14),
        StepRise(
          order: 3,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: _AccountPill(
              auth: widget.auth,
              accent: accent,
              login: widget.login,
            ),
          ),
        ),
        const SizedBox(height: 16),
        StepRise(
          order: 4,
          child: Container(
            decoration: onboardingCard(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Observer(
              builder: (context) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: _Preview(
                      stream: widget.preview,
                      accent: accent,
                      light: switch (settings.themeType) {
                        ThemeType.light => true,
                        ThemeType.dark => false,
                        ThemeType.system =>
                          MediaQuery.platformBrightnessOf(context) ==
                              Brightness.light,
                      },
                      tablet: tablet,
                    ),
                  ),
                  _Divided(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 14),
                      child: _ThemeChoice(
                        value: settings.themeType,
                        onChanged: (theme) => settings.themeType = theme,
                      ),
                    ),
                  ),
                  _Divided(
                    child: _AccentRow(
                      accent: accent,
                      onTap: () => showOnboardingAccentPicker(
                        context,
                        tablet: tablet,
                        initial: Color(settings.accentColor),
                        onChanged: (color) =>
                            settings.accentColor = color.toARGB32(),
                      ),
                    ),
                  ),
                  _Divided(
                    child: _SwitchRow(
                      title: l.onboardingSetupHistoryTitle,
                      accent: accent,
                      detail: Text.rich(
                        TextSpan(
                          children: l10nSpans(
                            l.onboardingSetupHistoryDetail(link: l10nMark(0)),
                            [
                              TextSpan(
                                text: 'recent-messages.robotty.de',
                                recognizer: _robottyLink,
                                semanticsLabel: _robotty,
                                style: TextStyle(
                                  color: OnboardingColors.text,
                                  decoration: TextDecoration.underline,
                                  decorationColor: accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        style: OnboardingType.rowDetail,
                      ),
                      value: settings.showRecentMessages,
                      onChanged: (value) => settings.showRecentMessages = value,
                    ),
                  ),
                  _Divided(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: _SwitchRow(
                        title: l.onboardingSetupCrashTitle,
                        accent: accent,
                        detail: Text(
                          l.onboardingSetupCrashDetail,
                          style: OnboardingType.rowDetail,
                        ),
                        value: settings.shareCrashLogsAndAnalytics,
                        onChanged: (value) {
                          // The app follows it (syncFirebaseCollection).
                          settings.shareCrashLogsAndAnalytics = value;
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
      footer: OnboardingFooter(
        tablet: tablet,
        primary: StepRise(
          order: tablet ? 6 : 5,
          child: OnboardingButton(
            label: l.commonNext,
            accent: accent,
            trailing: OnboardingGlyphKind.arrowRight,
            onPressed: widget.onNext,
          ),
        ),
      ),
    );
  }
}

/// A card row under a 0.5 dp divider.
class _Divided extends StatelessWidget {
  const _Divided({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(
            color: OnboardingColors.divider,
            width: OnsetTokens.hairlineWidth,
          ),
        ),
      ),
      child: child,
    );
  }
}

/// "Logged in as …", or how to log in later.
class _AccountPill extends StatelessWidget {
  const _AccountPill({
    required this.auth,
    required this.accent,
    required this.login,
  });

  final AuthStore auth;
  final Color accent;
  final OnboardingLogin login;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        // This login failing is said even when an account was logged in
        // already.
        final details = auth.isLoggedIn && login != OnboardingLogin.failed
            ? auth.user.details
            : null;
        final Widget leading;
        final List<Widget> content;
        if (details != null) {
          final name = getReadableName(details.displayName, details.login);
          leading = ClipOval(
            child: SizedBox.square(
              dimension: 24,
              child: details.profileImageUrl.isEmpty
                  ? const ColoredBox(color: OnboardingColors.raised)
                  : OnsetCachedNetworkImage(
                      imageUrl: details.profileImageUrl,
                      memCacheWidth: 72,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          const ColoredBox(color: OnboardingColors.raised),
                      errorWidget: (_, _, _) =>
                          const ColoredBox(color: OnboardingColors.raised),
                    ),
            ),
          );
          content = [
            Flexible(
              child: Text.rich(
                TextSpan(
                  children: l10nSpans(
                    context.l10n.onboardingSetupLoggedInAs(name: l10nMark(0)),
                    [
                      TextSpan(
                        text: name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: OnboardingColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: OnboardingColors.body,
                ),
              ),
            ),
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: OnboardingGlyph(
                OnboardingGlyphKind.check,
                size: 10,
                strokeWidth: 3,
                color: onAccentFor(accent),
              ),
            ),
          ];
        } else if (login == OnboardingLogin.pending) {
          leading = SizedBox.square(
            dimension: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: accent,
              value: reduceMotionOf(context) ? 0.25 : null,
            ),
          );
          content = [
            Flexible(
              child: Text(
                context.l10n.loginSigningIn,
                style: const TextStyle(
                  fontSize: 13,
                  color: OnboardingColors.secondary,
                ),
              ),
            ),
          ];
        } else {
          leading = const OnboardingGlyph(
            OnboardingGlyphKind.user,
            size: 14,
            strokeWidth: 2,
            color: OnboardingColors.secondary,
          );
          content = [
            Flexible(
              child: Text(
                login == OnboardingLogin.failed
                    ? context.l10n.onboardingSetupLoginFailed
                    : context.l10n.onboardingSetupNotLoggedIn,
                style: const TextStyle(
                  fontSize: 13,
                  color: OnboardingColors.secondary,
                ),
              ),
            ),
          ];
        }
        return Semantics(
          liveRegion: true,
          child: Container(
            constraints: const BoxConstraints(minHeight: 32),
            padding: EdgeInsetsDirectional.fromSTEB(
              details != null ? 4 : 10,
              4,
              12,
              4,
            ),
            decoration: BoxDecoration(
              color: OnboardingColors.surface,
              borderRadius: BorderRadius.circular(OnsetTokens.radiusPill),
              border: Border.all(
                color: OnboardingColors.ringStrong,
                width: OnsetTokens.hairlineWidth,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [leading, ...content],
            ),
          ),
        );
      },
    );
  }
}

/// The live preview: a channel as the app will draw it, on the theme's
/// ground with the accent's badge.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.stream,
    required this.accent,
    required this.light,
    required this.tablet,
  });

  final StreamTwitch? stream;
  final Color accent;
  final bool light;
  final bool tablet;

  @override
  Widget build(BuildContext context) {
    final duration = motionDuration(context, const Duration(milliseconds: 260));
    final text = light ? OnsetTokens.backgroundDark : OnboardingColors.text;
    final meta = light ? const Color(0xFF5C5C5C) : OnboardingColors.secondary;
    final stream = this.stream;
    final width = tablet ? 128.0 : 96.0;
    final height = tablet ? 72.0 : 54.0;
    final l = context.l10n;
    final name = stream == null
        ? l.onboardingSetupPreviewChannel
        : getReadableName(stream.userName, stream.userLogin);
    final detail = stream == null
        ? l.onboardingSetupPreviewDetail
        : [
            if (stream.gameName.isNotEmpty) stream.gameName,
            formatViewers(stream.viewerCount, compact: false),
          ].join(' · ');
    // An AnimatedDefaultTextStyle replaces the inherited style: the family
    // is said again.
    final textStyle = TextStyle(
      fontFamily: OnsetTokens.bodyFamily,
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: text,
    );
    return Semantics(
      label: l.onboardingSetupPreviewSemantics(name: name, detail: detail),
      excludeSemantics: true,
      child: AnimatedContainer(
        key: const Key('setup-preview'),
        duration: duration,
        curve: OnsetMotion.standard,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: light ? Colors.white : OnsetTokens.backgroundDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: light ? const Color(0x1A000000) : const Color(0x1AFFFFFF),
            width: OnsetTokens.hairlineWidth,
          ),
        ),
        child: Row(
          spacing: 12,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: width,
                height: height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (stream == null)
                      const _PlaceholderPicture()
                    else
                      OnsetCachedNetworkImage(
                        imageUrl: stream.thumbnailUrl.replaceFirst(
                          '-{width}x{height}',
                          '-320x180',
                        ),
                        memCacheWidth: 320,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => const _PlaceholderPicture(),
                        errorWidget: (_, _, _) => const _PlaceholderPicture(),
                      ),
                    Positioned(
                      left: 5,
                      top: 5,
                      child: AnimatedContainer(
                        duration: duration,
                        height: 16,
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          l.commonLiveBadge,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.54,
                            color: onAccentFor(accent),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // "Preview" on top, so the name and the detail have the row's
            // whole width (French runs longer).
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: duration,
                    style: TextStyle(
                      fontFamily: OnsetTokens.bodyFamily,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.26,
                      color: meta,
                    ),
                    child: Text(l.onboardingSetupPreviewBadge),
                  ),
                  AnimatedDefaultTextStyle(
                    duration: duration,
                    style: textStyle,
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AnimatedDefaultTextStyle(
                    duration: duration,
                    style: OnsetType.tabular(
                      TextStyle(
                        fontFamily: OnsetTokens.bodyFamily,
                        fontSize: 12,
                        color: meta,
                      ),
                    ),
                    // The stand-in wraps rather than being cut; a live
                    // channel's category can be long and is cut.
                    child: Text(
                      detail,
                      maxLines: stream == null ? null : 1,
                      overflow: stream == null
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A picture's stand-in: a quiet two-tone ground, no artwork.
class _PlaceholderPicture extends StatelessWidget {
  const _PlaceholderPicture();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1F1F1F), Color(0xFF121212)],
        ),
      ),
    );
  }
}

/// Theme: System / Light / Dark, a pill with a sliding white indicator.
class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({required this.value, required this.onChanged});

  final ThemeType value;
  final ValueChanged<ThemeType> onChanged;

  static String _note(AppLocalizations l, ThemeType theme) => switch (theme) {
    ThemeType.system => l.onboardingSetupThemeSystemNote,
    ThemeType.light => l.onboardingSetupThemeLightNote,
    ThemeType.dark => l.onboardingSetupThemeDarkNote,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final reduce = reduceMotionOf(context);
    final slide = reduce ? Duration.zero : const Duration(milliseconds: 320);
    final tint = reduce
        ? OnsetMotion.reducedFade
        : const Duration(milliseconds: 200);
    final index = value.index;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                l.onboardingSetupThemeTitle,
                style: OnboardingType.rowTitle,
              ),
            ),
            Text(
              _note(l, value),
              style: const TextStyle(
                fontSize: 12,
                color: OnboardingColors.tertiary,
              ),
            ),
          ],
        ),
        Semantics(
          container: true,
          label: l.onboardingSetupThemeTitle,
          child: Container(
            height: 44,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: OnboardingColors.raised,
              borderRadius: BorderRadius.circular(OnsetTokens.radiusPill),
              border: Border.all(
                color: OnboardingColors.ring,
                width: OnsetTokens.hairlineWidth,
              ),
            ),
            child: Stack(
              children: [
                AnimatedAlign(
                  duration: slide,
                  curve: OnsetMotion.standard,
                  alignment: Alignment(-1 + index.toDouble(), 0),
                  child: FractionallySizedBox(
                    widthFactor: 1 / 3,
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: OnboardingColors.text,
                        borderRadius: BorderRadius.circular(
                          OnsetTokens.radiusPill,
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (final theme in ThemeType.values)
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: theme == value,
                          inMutuallyExclusiveGroup: true,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (theme == value) return;
                              Haptics.selection();
                              onChanged(theme);
                            },
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: tint,
                                style: TextStyle(
                                  fontFamily: OnsetTokens.bodyFamily,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: theme == value
                                      ? OnsetTokens.backgroundDark
                                      : OnboardingColors.body,
                                ),
                                child: Text(theme.label(l)),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// "Accent color", its hex code and swatch: opens the picker.
class _AccentRow extends StatelessWidget {
  const _AccentRow({required this.accent, required this.onTap});

  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hex = hexOf(accent);
    return Semantics(
      button: true,
      label: context.l10n.accentColorSemantics(hex: hex),
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 56,
          child: Row(
            spacing: 12,
            children: [
              Expanded(
                child: Text(
                  context.l10n.accentColorTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: OnboardingColors.text,
                  ),
                ),
              ),
              Text(
                hex,
                style: OnsetType.tabular(
                  const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: OnboardingColors.secondary,
                  ),
                ),
              ),
              AnimatedContainer(
                duration: motionDuration(
                  context,
                  const Duration(milliseconds: 260),
                ),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(color: OnboardingColors.surface, spreadRadius: 2),
                    BoxShadow(color: Color(0xE6F5F5F5), spreadRadius: 3.5),
                  ],
                ),
              ),
              const OnboardingGlyph(
                OnboardingGlyphKind.chevronRight,
                size: 16,
                strokeWidth: 2,
                color: OnboardingColors.tertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A setting with its explanation and the switch.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.detail,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  final String title;
  final Widget detail;
  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Text(title, style: OnboardingType.rowTitle),
                detail,
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -8),
            child: OnboardingSwitch(
              value: value,
              accent: accent,
              label: title,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
