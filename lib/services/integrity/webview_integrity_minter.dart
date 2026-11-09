import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:onset/constants.dart';
import 'package:onset/services/integrity/integrity_token.dart';
import 'package:onset/services/twitch_web_token_service.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewIntegrityMinter {
  const WebViewIntegrityMinter({this.deadline = const Duration(seconds: 15)});

  final Duration deadline;

  static const channelName = 'OnsetIntegrity';

  static String get _userAgent => defaultTargetPlatform == TargetPlatform.iOS
      ? 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1'
      : 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Mobile Safari/537.36';

  static final _startUrl = Uri.https('www.twitch.tv', '/');

  static String captureScript() =>
      '''
(function () {
  if (window.__onsetIntegrity) return;
  window.__onsetIntegrity = true;
  var channel = window.$channelName;
  var cookie = function (name) {
    var match = document.cookie.match(new RegExp('(?:^|; )' + name + '=([^;]*)'));
    return match ? decodeURIComponent(match[1]) : null;
  };
  var headerOf = function (headers, name) {
    if (!headers) return null;
    if (typeof headers.get === 'function') return headers.get(name);
    for (var key in headers) {
      if (key.toLowerCase() === name.toLowerCase()) return headers[key];
    }
    return null;
  };
  var report = function (text, deviceId) {
    try {
      var body = JSON.parse(text);
      channel.postMessage(JSON.stringify({
        token: body.token,
        expiration: body.expiration,
        deviceId: deviceId
      }));
    } catch (error) {}
  };
  var original = window.fetch;
  window.fetch = function (input, init) {
    var url = typeof input === 'string' ? input : (input && input.url) || '';
    var pending = original.apply(this, arguments);
    if (url.indexOf('gql.twitch.tv/integrity') !== -1) {
      var deviceId = headerOf(init && init.headers, 'X-Device-Id') || cookie('unique_id');
      pending.then(function (response) {
        return response.ok ? response.clone().text() : null;
      }).then(function (text) {
        if (text) report(text, deviceId);
      }).catch(function () {});
    }
    return pending;
  };
  var attempts = 0;
  var ask = function () {
    attempts += 1;
    var session = cookie('auth-token');
    var deviceId = cookie('unique_id');
    var again = function () {
      if (attempts < 5) setTimeout(ask, 2500);
    };
    if (!session || !deviceId) {
      again();
      return;
    }
    window.fetch('https://gql.twitch.tv/integrity', {
      method: 'POST',
      headers: {
        'Client-Id': '$kTwitchWebClientId',
        'Authorization': 'OAuth ' + session,
        'X-Device-Id': deviceId
      }
    }).then(function (response) {
      if (!response.ok) again();
    }).catch(again);
  };
  setTimeout(ask, 2500);
})();
''';

  Future<IntegrityToken> call() async {
    final captured = Completer<IntegrityToken>();
    final controller = WebViewController();
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setUserAgent(_userAgent);
    await controller.addJavaScriptChannel(
      channelName,
      onMessageReceived: (message) {
        final token = IntegrityToken.fromCapture(message.message);
        if (token != null && !captured.isCompleted) captured.complete(token);
      },
    );
    await controller.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (request) =>
            TwitchWebTokenService.isTwitchPageUrl(request.url)
            ? NavigationDecision.navigate
            : NavigationDecision.prevent,
        onPageFinished: (url) {
          if (Uri.tryParse(url)?.host != _startUrl.host) return;
          unawaited(
            controller.runJavaScript(captureScript()).catchError((Object e) {
              debugPrint('Integrity capture not injected: ${e.runtimeType}');
            }),
          );
        },
      ),
    );
    try {
      await controller.loadRequest(_startUrl);
      return await captured.future.timeout(deadline);
    } finally {
      unawaited(
        controller.loadRequest(Uri.parse('about:blank')).catchError((Object e) {
          debugPrint(
            'Releasing the integrity WebView failed: ${e.runtimeType}',
          );
        }),
      );
    }
  }
}
