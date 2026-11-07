import 'package:flutter/foundation.dart';
import 'package:onset/utils/twitch_links.dart';
import 'package:url_launcher/url_launcher.dart';

typedef UrlLauncher = Future<bool> Function(Uri url, {LaunchMode mode});

/// Opens links tapped in the app. Twitch videos and clips open in-app (never
/// in a browser, see [TwitchLink.opensInApp]); other web links (http and
/// https, https when written without a scheme) are launched as before. Any
/// other scheme (`intent:`, `file:`,
/// `javascript:`, an app's own scheme…) is refused without a word: a link
/// in chat or on a channel's panels must not reach into the device.
bool isTwitchHost(Uri uri) {
  final host = uri.host.toLowerCase();
  return host == 'twitch.tv' || host.endsWith('.twitch.tv');
}

abstract final class LinkRouter {
  /// Set by the app once its navigator exists; returns whether it handled
  /// the link.
  static Future<bool> Function(TwitchLink link)? inAppHandler;

  @visibleForTesting
  static UrlLauncher launcher = launchUrl;

  static Future<bool> Function(Uri url)? externalLinkGate;

  static Future<void> open(
    String text, {
    required bool launchExternal,
    bool confirm = false,
  }) async {
    final link = TwitchLink.parseText(text);
    final handler = inAppHandler;
    if (link.opensInApp && handler != null && await handler(link)) {
      return;
    }
    var uri = Uri.tryParse(text);
    // A link written without a scheme in chat ("youtube.com/…") is https.
    if (uri != null && !uri.hasScheme) uri = Uri.tryParse('https://$text');
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return;
    }
    final gate = externalLinkGate;
    if (confirm && !isTwitchHost(uri) && gate != null && !await gate(uri)) {
      return;
    }
    await launcher(
      uri,
      mode: launchExternal
          ? LaunchMode.externalApplication
          : LaunchMode.inAppBrowserView,
    );
  }
}
