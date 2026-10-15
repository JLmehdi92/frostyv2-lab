import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/widgets/blurred_container.dart';
import 'package:frosty/widgets/frosty_scrollbar.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

class ReleaseNotes extends StatefulWidget {
  static const routeName = 'ReleaseNotes';

  const ReleaseNotes({super.key});

  @override
  State<ReleaseNotes> createState() => _ReleaseNotesState();
}

class _ReleaseNotesState extends State<ReleaseNotes> {
  final _scrollController = ScrollController();
  String releaseNotes = '';

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    rootBundle.loadString('assets/release-notes.md').then((changelog) {
      setState(() {
        releaseNotes = changelog;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
        title: const Text('Release notes'),
      ),
      body: Stack(
        children: [
          // Main scrollable content
          Positioned.fill(
            child: FrostyScrollbar(
              controller: _scrollController,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + kToolbarHeight,
              ),
              child: Markdown(
                padding: EdgeInsets.fromLTRB(
                  16 + MediaQuery.of(context).padding.left,
                  MediaQuery.of(context).padding.top + kToolbarHeight,
                  16 + MediaQuery.of(context).padding.right,
                  16,
                ),
                controller: _scrollController,
                data: releaseNotes,
                styleSheet: MarkdownStyleSheet(
                  h2: TextStyle(
                    fontFamily: FrostyTokens.displayFamily,
                    fontVariations: FrostyTokens.displayWeight(700),
                    fontSize: 20,
                  ),
                  h3: TextStyle(
                    fontFamily: FrostyTokens.displayFamily,
                    fontVariations: FrostyTokens.displayWeight(600),
                    fontSize: 16,
                  ),
                  h3Padding: const EdgeInsets.only(top: 16),
                  h4: TextStyle(
                    fontFamily: FrostyTokens.displayFamily,
                    fontVariations: FrostyTokens.displayWeight(600),
                    fontSize: 14,
                  ),
                  h4Padding: const EdgeInsets.only(top: 16),
                  p: const TextStyle(fontSize: 14),
                  // Le separateur horizontal du markdown ne sert qu'a espacer
                  // les versions : on le rend invisible plutot que de detourner
                  // une bordure de 32px, qui violait la hairline du systeme.
                  horizontalRuleDecoration: const BoxDecoration(),
                ),
                onTapLink: (text, href, title) {
                  if (href != null) {
                    launchUrlString(
                      href,
                      mode: context.read<SettingsStore>().launchUrlExternal
                          ? LaunchMode.externalApplication
                          : LaunchMode.inAppBrowserView,
                    );
                  }
                },
              ),
            ),
          ),
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
}
