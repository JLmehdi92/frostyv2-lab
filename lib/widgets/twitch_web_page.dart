import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frosty/widgets/blurred_container.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// A twitch.tv page in the app, signed in with the session from the login
/// page (the WebView keeps its cookies): for what only twitch.tv itself may
/// do, such as reporting or following.
class TwitchWebPage extends StatelessWidget {
  const TwitchWebPage({super.key, required this.title, required this.url});

  final String title;
  final Uri url;

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
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: theme.brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
        ),
        leading: IconButton(
          tooltip: 'Back',
          icon: Icon(Icons.adaptive.arrow_back_rounded),
          onPressed: Navigator.of(context).pop,
        ),
        title: Text(title),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + kToolbarHeight,
              ),
              child: WebViewWidget(
                controller: WebViewController()
                  ..setJavaScriptMode(JavaScriptMode.unrestricted)
                  ..setNavigationDelegate(
                    NavigationDelegate(
                      onWebResourceError: (error) {
                        debugPrint('WebView error: ${error.description}');
                      },
                    ),
                  )
                  ..loadRequest(url),
              ),
            ),
          ),
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
