import 'package:flutter/foundation.dart';
import 'package:frosty/utils/twitch_links.dart';
import 'package:url_launcher/url_launcher.dart';

typedef UrlLauncher = Future<bool> Function(Uri url, {LaunchMode mode});

/// Opens links tapped in the app. Twitch videos and clips open in-app (never
/// in a browser, see [TwitchLink.opensInApp]); everything else is launched
/// as before.
abstract final class LinkRouter {
  /// Set by the app once its navigator exists; returns whether it handled
  /// the link.
  static Future<bool> Function(TwitchLink link)? inAppHandler;

  @visibleForTesting
  static UrlLauncher launcher = launchUrl;

  static Future<void> open(String text, {required bool launchExternal}) async {
    final link = TwitchLink.parseText(text);
    final handler = inAppHandler;
    if (link.opensInApp && handler != null && await handler(link)) {
      return;
    }
    await launcher(
      Uri.parse(text),
      mode: launchExternal
          ? LaunchMode.externalApplication
          : LaunchMode.inAppBrowserView,
    );
  }
}
