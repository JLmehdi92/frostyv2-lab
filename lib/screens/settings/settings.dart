import 'package:flutter/material.dart';
import 'package:frosty/screens/settings/account/widgets/profile_card.dart';
import 'package:frosty/screens/settings/chat_settings.dart';
import 'package:frosty/screens/settings/general_settings.dart';
import 'package:frosty/screens/settings/other_settings.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/settings/video_settings.dart';
import 'package:frosty/screens/settings/widgets/settings_tile_route.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/widgets/blurred_container.dart';
import 'package:frosty/widgets/frosty_scrollbar.dart';
import 'package:frosty/widgets/section_header.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:simple_icons/simple_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class Settings extends StatelessWidget {
  static const routeName = 'Settings';

  final SettingsStore settingsStore;

  /// Inside the navigation shell (the Profile section): no app bar of its
  /// own, the shell's header is above; the page scrolls under it.
  final bool embedded;

  const Settings({
    super.key,
    required this.settingsStore,
    this.embedded = false,
  });

  void _open(String url) => launchUrl(
    Uri.parse(url),
    mode: settingsStore.launchUrlExternal
        ? LaunchMode.externalApplication
        : LaunchMode.inAppBrowserView,
  );

  List<Widget> _links() => [
    IconButton(
      tooltip: 'Support Frosty',
      onPressed: () => _open('https://www.buymeacoffee.com/tommychow'),
      icon: const Icon(SimpleIcons.buymeacoffee),
    ),
    IconButton(
      tooltip: 'View source on GitHub',
      onPressed: () => _open('https://github.com/tommyxchow/frosty'),
      icon: const Icon(SimpleIcons.github),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barHeight = embedded ? 0.0 : kToolbarHeight;
    final content = _content(context, theme, barHeight);
    if (embedded) return content;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Back',
          icon: Icon(Icons.adaptive.arrow_back_rounded),
          onPressed: Navigator.of(context).pop,
        ),
        title: const Text('Settings'),
        actions: [..._links(), const SizedBox(width: 8)],
      ),
      body: Stack(
        children: [
          content,
          // Blurred app bar overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: BlurredContainer(
              gradientDirection: GradientDirection.up,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top,
                left: MediaQuery.of(context).padding.left,
                right: MediaQuery.of(context).padding.right,
              ),
              child: const SizedBox(height: kToolbarHeight),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, ThemeData theme, double barHeight) {
    final padding = MediaQuery.of(context).padding;
    return SafeArea(
      top: false,
      bottom: false,
      child: FrostyScrollbar(
        padding: EdgeInsets.only(top: padding.top + barHeight),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.only(top: padding.top + barHeight + 8),
              sliver: SliverList.list(
                children: [
                  const SectionHeader('Account', isFirst: true),
                  ProfileCard(authStore: context.read<AuthStore>()),
                  const SectionHeader('Customize'),
                  SettingsTileRoute(
                    leading: const Icon(Icons.settings_outlined),
                    title: 'General',
                    child: GeneralSettings(settingsStore: settingsStore),
                  ),
                  SettingsTileRoute(
                    leading: const Icon(Icons.tv_rounded),
                    title: 'Video',
                    child: VideoSettings(settingsStore: settingsStore),
                  ),
                  SettingsTileRoute(
                    leading: const Icon(Icons.chat_outlined),
                    title: 'Chat',
                    child: ChatSettings(settingsStore: settingsStore),
                  ),
                  const SectionHeader('Other'),
                  OtherSettings(settingsStore: settingsStore),
                ],
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    final version = snapshot.data?.version ?? '';
                    final buildNumber = snapshot.data?.buildNumber ?? '';
                    final mutedColor = context.frostyColors.metadata;
                    return Padding(
                      padding: EdgeInsets.only(
                        top: 16,
                        bottom: MediaQuery.of(context).padding.bottom,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // In the shell there is no app bar for them.
                          if (embedded)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: _links(),
                            ),
                          Text.rich(
                            TextSpan(
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: mutedColor,
                              ),
                              children: [
                                const TextSpan(text: 'Made by '),
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.baseline,
                                  baseline: TextBaseline.alphabetic,
                                  child: GestureDetector(
                                    onTap: () => _open('https://tommychow.com'),
                                    child: Text(
                                      'Tommy Chow',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: mutedColor,
                                            decoration:
                                                TextDecoration.underline,
                                            decorationColor: mutedColor,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (snapshot.hasData)
                            GestureDetector(
                              onTap: () => _open(
                                'https://github.com/tommyxchow/frosty/releases/tag/v$version',
                              ),
                              child: Text(
                                'v$version ($buildNumber)',
                                style: context.frostyText.metadata,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
