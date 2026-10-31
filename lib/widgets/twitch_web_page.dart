import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/widgets/blurred_container.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// A twitch.tv page in the app, signed in with the session from the login
/// page (the WebView keeps its cookies): for what only twitch.tv itself may
/// do, such as reporting or following.
class TwitchWebPage extends StatefulWidget {
  const TwitchWebPage({super.key, required this.title, required this.url});

  final String title;
  final Uri url;

  /// Stands in for the WebView (tests have no platform view).
  @visibleForTesting
  static Widget Function()? debugBody;

  /// Opens [url] when it is on twitch.tv.
  static Future<void> open(
    BuildContext context, {
    required String title,
    required Uri url,
  }) async {
    if (url.scheme != 'https' ||
        !(url.host == 'twitch.tv' || url.host.endsWith('.twitch.tv'))) {
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TwitchWebPage(title: title, url: url),
      ),
    );
  }

  @override
  State<TwitchWebPage> createState() => _TwitchWebPageState();
}

class _TwitchWebPageState extends State<TwitchWebPage> {
  // Made once: a new controller would reload the page on every rebuild
  // (the keyboard opening, a rotation), losing what was typed.
  late final _controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setNavigationDelegate(
      NavigationDelegate(
        onWebResourceError: (error) {
          debugPrint('WebView error: ${error.description}');
        },
      ),
    )
    ..loadRequest(widget.url);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: theme.brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
        ),
        leading: IconButton(
          tooltip: context.l10n.commonBack,
          icon: Icon(Icons.adaptive.arrow_back_rounded),
          onPressed: Navigator.of(context).pop,
        ),
        title: Text(widget.title),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(top: padding.top + kToolbarHeight),
              child:
                  TwitchWebPage.debugBody?.call() ??
                  WebViewWidget(controller: _controller),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: BlurredContainer(
              // The channel's video shows under the page while it slides.
              onlyWhenSettled: true,
              gradientDirection: GradientDirection.up,
              padding: EdgeInsets.only(
                top: padding.top,
                left: padding.left,
                right: padding.right,
              ),
              child: const SizedBox(height: kToolbarHeight),
            ),
          ),
        ],
      ),
    );
  }
}
