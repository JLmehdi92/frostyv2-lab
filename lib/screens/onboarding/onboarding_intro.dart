import 'package:flutter/material.dart';
import 'package:frosty/screens/onboarding/onboarding_login.dart';
import 'package:frosty/screens/onboarding/onboarding_scaffold.dart';
import 'package:package_info_plus/package_info_plus.dart';

class OnboardingIntro extends StatelessWidget {
  const OnboardingIntro({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        return OnboardingScaffold(
          header: 'ONSET',
          subtitle:
              'A mobile Twitch client with 7TV, BetterTTV (BTTV), and FrankerFaceZ (FFZ) support.',
          showLogo: true,
          disclaimer: snapshot.hasData
              ? 'v${snapshot.data?.version} (${snapshot.data?.buildNumber})'
              : null,
          // A version string is a number, so it stays monospace.
          disclaimerIsMetadata: true,
          route: const OnboardingLogin(),
        );
      },
    );
  }
}
