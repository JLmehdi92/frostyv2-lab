import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScaffold extends StatelessWidget {
  final String header;
  final String? subtitle;
  final String? disclaimer;

  /// Whether [disclaimer] holds a number rather than a sentence.
  ///
  /// The slot carries both: the intro screen puts the version string in it,
  /// the login screen a paragraph of prose. Numbers are monospace in this
  /// system, prose is not — rendering a sentence in Space Mono reads as a
  /// terminal dump. The caller knows which it is passing, so it says so.
  final bool disclaimerIsMetadata;

  final Widget? content;
  final String? buttonText;
  final Widget? buttonIcon;
  final Widget route;
  final Widget? skipRoute;
  final bool showLogo;
  final bool isLast;

  const OnboardingScaffold({
    super.key,
    required this.header,
    this.subtitle,
    this.disclaimer,
    this.disclaimerIsMetadata = false,
    this.content,
    this.buttonText,
    this.buttonIcon,
    required this.route,
    this.skipRoute,
    this.showLogo = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    // A tablet may sit in landscape on a stand or keyboard cover.
    SystemChrome.setPreferredOrientations(
      context.isLargeScreen
          ? const []
          : const [
              DeviceOrientation.portraitUp,
              DeviceOrientation.portraitDown,
            ],
    );

    if (isLast) {
      SharedPreferences.getInstance().then(
        (prefs) => prefs.setBool('first_run', false),
      );
    }

    return Scaffold(
      appBar: AppBar(shape: const Border()),
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                child: Column(
                  spacing: 24,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 12,
                      children: [
                        if (showLogo) ...[
                          Image.asset('assets/icons/onset-mark.png', height: 80),
                        ],
                        Text(
                          header,
                          style: TextStyle(
                            fontFamily: FrostyTokens.displayFamily,
                            fontVariations: FrostyTokens.displayWeight(700),
                            fontSize: 48,
                            letterSpacing: -0.03 * 48,
                          ),
                        ),
                      ],
                    ),
                    if (subtitle != null) ...[
                      Text(
                        subtitle!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: context.frostyColors.metadata,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: content == null ? 20 : 0,
                  ),
                  child: content ?? const SizedBox(),
                ),
              ),
              if (disclaimer != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(
                    disclaimer!,
                    textAlign: TextAlign.center,
                    style: disclaimerIsMetadata
                        ? context.frostyText.metadata.copyWith(fontSize: 12)
                        : context.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: context.frostyColors.metadata,
                          ),
                  ),
                ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => isLast
                      ? Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => route),
                          (_) => false,
                        )
                      : Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => route),
                        ),
                  icon: buttonIcon ?? const SizedBox(),
                  label: Text(buttonText ?? 'Next'),
                ),
              ),
              if (skipRoute != null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => skipRoute!),
                    ),
                    child: const Text('Skip'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
