import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:onset/constants.dart';
import 'package:onset/services/integrity/integrity_token.dart';
import 'package:onset/services/twitch_web_token_service.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewIntegrityMinter {
  WebViewIntegrityMinter({
    required OverlayState? Function() overlay,
    this.deadline = const Duration(seconds: 15),
    DateTime Function()? now,
    Random? random,
  }) : _overlay = overlay,
       _now = now ?? DateTime.now,
       _random = random ?? Random.secure();

  final OverlayState? Function() _overlay;
  final Duration deadline;
  final DateTime Function() _now;
  final Random _random;

  static const channelName = 'OnsetIntegrity';

  static const desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36';

  static final startUrl = Uri.https('www.twitch.tv', '/');

  _Mint? _current;

  static bool shouldInject(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') return false;
    return uri.host == 'twitch.tv' || uri.host.endsWith('.twitch.tv');
  }

  String newNonce() => List.generate(
    16,
    (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  static String captureScript(String nonce) =>
      '''
(function () {
  if (window.__onsetIntegrity) return;
  window.__onsetIntegrity = true;
  var host = window.location.host;
  if (host !== 'twitch.tv' && !/\\.twitch\\.tv\$/.test(host)) return;
  var channel = window.$channelName;
  var sent = false;
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
    if (sent) return;
    try {
      var body = JSON.parse(text);
      if (!body || typeof body.token !== 'string') return;
      sent = true;
      channel.postMessage(JSON.stringify({
        nonce: '$nonce',
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
    if (sent) return;
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
    cancel();
    final mint = _Mint(newNonce());
    _current = mint;
    try {
      await _start(mint);
      return await mint.captured.future.timeout(deadline);
    } finally {
      if (identical(_current, mint)) _current = null;
      mint.release();
    }
  }

  void cancel() {
    final mint = _current;
    _current = null;
    if (mint == null) return;
    if (!mint.captured.isCompleted) {
      mint.captured.completeError(StateError('cancelled'));
    }
    mint.release();
  }

  Future<void> _start(_Mint mint) async {
    final controller = WebViewController();
    mint.controller = controller;
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setUserAgent(desktopUserAgent);
    await controller.addJavaScriptChannel(
      channelName,
      onMessageReceived: (message) => mint.accept(message.message, _now()),
    );
    await controller.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (request) =>
            TwitchWebTokenService.isTwitchPageUrl(request.url)
            ? NavigationDecision.navigate
            : NavigationDecision.prevent,
        onPageFinished: (url) {
          if (!shouldInject(url) || mint.released) return;
          unawaited(
            controller.runJavaScript(captureScript(mint.nonce)).catchError((
              Object e,
            ) {
              debugPrint('Integrity capture not injected: ${e.runtimeType}');
            }),
          );
        },
      ),
    );
    mint.host = _mountOffstage(controller);
    if (mint.released) return;
    await controller.loadRequest(startUrl);
  }

  OverlayEntry? _mountOffstage(WebViewController controller) {
    final overlay = _overlay();
    if (overlay == null || !overlay.mounted) return null;
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: 0,
        top: 0,
        width: 1,
        height: 1,
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: Opacity(
              opacity: 0.01,
              child: WebViewWidget(controller: controller),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    return entry;
  }
}

class _Mint {
  _Mint(this.nonce);

  final String nonce;
  final captured = Completer<IntegrityToken>();
  WebViewController? controller;
  OverlayEntry? host;
  var released = false;
  var answered = false;

  void accept(String message, DateTime now) {
    if (answered || released || captured.isCompleted) return;
    final token = IntegrityToken.fromCapture(message, nonce: nonce, now: now);
    if (token == null) return;
    answered = true;
    captured.complete(token);
  }

  void release() {
    if (released) return;
    released = true;
    final entry = host;
    host = null;
    if (entry != null && entry.mounted) entry.remove();
    final view = controller;
    controller = null;
    if (view == null) return;
    unawaited(
      view
          .removeJavaScriptChannel(WebViewIntegrityMinter.channelName)
          .then((_) => view.loadRequest(Uri.parse('about:blank')))
          .catchError((Object e) {
            debugPrint('Releasing the integrity page failed: ${e.runtimeType}');
          }),
    );
  }
}
