import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/apis/twitch_vod_service.dart';
import 'package:onset/models/clip.dart';
import 'package:onset/screens/channel/video/web_content_gate.dart';
import 'package:onset/screens/vod/vod_player_controller.dart';
import 'package:onset/screens/vod/vod_time.dart';
import 'package:simple_pip_mode/simple_pip.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

part 'web_vod_store.g.dart';

/// The Twitch embed URL for a VOD. [vodId] must be a VOD id (`123` or
/// `v123`), otherwise an [ArgumentError] is thrown.
String webVodEmbedUrl({required String vodId, required Duration startAt}) {
  final id = TwitchVodService.tryNormalizeVodId(vodId);
  if (id == null) throw ArgumentError.value(vodId, 'vodId', 'Not a VOD id');
  return Uri.https('player.twitch.tv', '/', {
    'video': 'v$id',
    'autoplay': 'true',
    'muted': 'false',
    'parent': 'onset',
    if (startAt.inSeconds > 0) 'time': formatVodTimeForShare(startAt),
  }).toString();
}

/// The Twitch clip embed URL for [slug]. [slug] must be a clip slug,
/// otherwise an [ArgumentError] is thrown.
String webClipEmbedUrl(String slug) {
  if (!isValidClipSlug(slug)) {
    throw ArgumentError.value(slug, 'slug', 'Not a clip slug');
  }
  return Uri.https('clips.twitch.tv', '/embed', {
    'clip': slug,
    'autoplay': 'true',
    'muted': 'false',
    'parent': 'onset',
  }).toString();
}

class WebVodStore = WebVodStoreBase with _$WebVodStore;

/// Plays a VOD in the Twitch embed player inside a WebView: the fallback
/// when the native player cannot run (iOS, the "Twitch web" engine setting,
/// or a native failure). Still in the app, still with the chat replay.
///
/// The `<video>` element is polled once a second for position, duration
/// and state, and driven directly for seek, rate, play/pause and sound.
abstract class WebVodStoreBase
    with Store
    implements VodPlayerController, LoopingPlayer, WebPagePlayer {
  ///
  /// [acceptContentGate]: the viewer already accepted the video's
  /// mature-content warning (or turned warnings off), so Twitch's own
  /// warning in the page may be clicked for them.
  WebVodStoreBase({
    required String vodId,
    Duration startAt = Duration.zero,
    Duration? knownLength,
    bool acceptContentGate = false,
    @visibleForTesting WebViewController? controller,
  }) : this.forUrl(
         webVodEmbedUrl(vodId: vodId, startAt: startAt),
         startAt: startAt,
         knownLength: knownLength,
         acceptContentGate: acceptContentGate,
         controller: controller,
       );

  /// Any Twitch embed with a `<video>` element ([url] built by
  /// [webVodEmbedUrl] or [webClipEmbedUrl], never from untrusted text).
  WebVodStoreBase.forUrl(
    String url, {
    Duration startAt = Duration.zero,
    Duration? knownLength,
    bool acceptContentGate = false,
    @visibleForTesting WebViewController? controller,
  }) : _knownLength = knownLength,
       _position = startAt {
    webViewController = controller ?? _createController(url);
    _scheduleOverlayHide();
    if (acceptContentGate) this.acceptContentGate();
    if (Platform.isAndroid) {
      _disposeAutoPip = autorun((_) async {
        // Another player on top owns auto-PiP.
        if (!_focused) return;
        final available = !paused && await SimplePip.isAutoPipAvailable;
        if (_disposed) return;
        if (available) {
          pip.setAutoPipMode();
        } else {
          pip.setAutoPipMode(autoEnter: false);
        }
      });
    }
  }

  ReactionDisposer? _disposeAutoPip;

  /// Last play state given to the PiP window, to tell it only of changes.
  bool? _pipPlaying;

  late final WebViewController webViewController;
  final Duration? _knownLength;

  /// Android picture-in-picture controller.
  final pip = SimplePip();

  @override
  void Function()? onFatalError;

  @override
  final Future<void> ready = Future.value();

  @override
  final VodPlaybackProblem? problem = null;

  @override
  final List<String> qualities = const ['Auto'];

  @override
  final String quality = 'Auto';

  Timer? _overlayTimer;
  var _disposed = false;

  /// Polls report the old position for a moment after a seek.
  Duration? _seekTarget;
  DateTime? _seekGuardUntil;

  @readonly
  var _status = VodPlaybackStatus.loading;

  @readonly
  Duration _position;

  @readonly
  Duration? _reportedDuration;

  @readonly
  var _buffered = Duration.zero;

  @readonly
  var _playbackRate = 1.0;

  @readonly
  var _muted = false;

  @readonly
  var _volume = 1.0;

  @readonly
  var _overlayVisible = true;

  @readonly
  var _isInPipMode = false;

  @readonly
  var _looping = false;

  /// Twitch's own warning (or another of its interstitials) is on screen in
  /// the page: our controls must step aside so its buttons can be tapped.
  @readonly
  var _webGateVisible = false;

  /// The viewer accepted the mature-content warning: the page may click
  /// Twitch's for them (kept across page reloads by the bridge).
  var _gateAccepted = false;

  @observable
  var _focused = true;

  @override
  @action
  void setFocused(bool focused) => _focused = focused;

  @override
  @computed
  Duration get duration => _reportedDuration ?? _knownLength ?? Duration.zero;

  @override
  @computed
  int get positionSeconds => _position.inSeconds;

  @override
  bool get paused =>
      _status != VodPlaybackStatus.playing &&
      _status != VodPlaybackStatus.buffering;

  @override
  bool get ended => _status == VodPlaybackStatus.ended;

  WebViewController _createController(String url) {
    final PlatformWebViewControllerCreationParams params =
        WebViewPlatform.instance is WebKitWebViewPlatform
        ? WebKitWebViewControllerCreationParams(
            allowsInlineMediaPlayback: true,
            mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
          )
        : const PlatformWebViewControllerCreationParams();
    final controller = WebViewController.fromPlatformCreationParams(params)
      ..setBackgroundColor(Colors.black)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'VodState',
        onMessageReceived: (message) => onStateMessage(message.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => unawaited(
            _installBridge().then(_applyLoop).then(_applyGateConsent),
          ),
        ),
      );
    if (controller.platform is AndroidWebViewController) {
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
    unawaited(controller.loadRequest(Uri.parse(url)));
    return controller;
  }

  /// Hides the embed's own controls (ours sit on top) and starts reporting
  /// the `<video>` state once a second.
  Future<void> _installBridge() => _run(bridgeScript);

  /// The page side of the bridge. It also reports whether Twitch's warning
  /// (or another interstitial) is up, and clicks the warning's button only
  /// once the viewer accepted ours (`window._onsetGateOk`).
  @visibleForTesting
  static const bridgeScript =
      '''
    (() => {
      if (!document.getElementById('onset-vod-styles')) {
        const style = document.createElement('style');
        style.id = 'onset-vod-styles';
        style.textContent = `
          .top-bar,
          .player-controls,
          #channel-player-disclosures,
          [data-a-target="player-overlay-preview-background"],
          [data-a-target="player-overlay-video-stats"] {
            display: none !important;
          }`;
        document.head.appendChild(style);
      }
      if (window._onsetVodPoll) return;
      const num = (x) => (typeof x === 'number' && isFinite(x)) ? x : null;
$kTwitchWebGateShownJs
      window._onsetVodPoll = setInterval(() => {
        const g = onsetGateShown();
        if (g && window._onsetGateOk === true) {
          const button =
            document.querySelector(
              'button[data-a-target*="content-classification-gate"]',
            ) ||
            document.querySelector(
              'button[data-a-target="player-overlay-mature-accept"]',
            );
          if (button) button.click();
        }
        const v = document.querySelector('video');
        if (!v) {
          VodState.postMessage(JSON.stringify({ g }));
          return;
        }
        if (typeof window._onsetLoop === 'boolean') v.loop = window._onsetLoop;
        let b = null;
        try {
          if (v.buffered.length) b = v.buffered.end(v.buffered.length - 1);
        } catch (_) {}
        VodState.postMessage(JSON.stringify({
          t: num(v.currentTime), d: num(v.duration), p: v.paused,
          e: v.ended, r: num(v.playbackRate), b: num(b),
          w: !v.paused && v.readyState < 3, g,
        }));
      }, 1000);
    })();
  ''';

  /// Lets the page click Twitch's warning: called once the viewer accepted
  /// ours, never on its own.
  void acceptContentGate() {
    _gateAccepted = true;
    _applyGateConsent();
  }

  void _applyGateConsent([void _]) {
    if (_gateAccepted) unawaited(_run('window._onsetGateOk = true;'));
  }

  /// Applies a state report from the page. Malformed reports are ignored.
  @visibleForTesting
  @action
  void onStateMessage(String json) {
    // The page can report once more after the screen closed.
    if (_disposed) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } catch (_) {
      return;
    }
    if (decoded is! Map) return;
    final g = decoded['g'];
    if (g is bool) _webGateVisible = g;
    final t = decoded['t'];
    if (t is! num || t < 0 || !t.isFinite) return;
    final at = Duration(milliseconds: (t * 1000).round());

    final target = _seekTarget;
    final guard = _seekGuardUntil;
    final guarding =
        target != null && guard != null && DateTime.now().isBefore(guard);
    if (!guarding || (at - target).abs() < const Duration(seconds: 2)) {
      _seekTarget = null;
      _position = at;
    }

    final d = decoded['d'];
    if (d is num && d > 0 && d.isFinite) {
      _reportedDuration = Duration(milliseconds: (d * 1000).round());
    }
    final b = decoded['b'];
    if (b is num && b >= 0 && b.isFinite) {
      _buffered = Duration(milliseconds: (b * 1000).round());
    }
    final r = decoded['r'];
    if (r is num && kVodPlaybackRates.contains(r.toDouble())) {
      _playbackRate = r.toDouble();
    }

    final wasPaused = paused;
    if (decoded['e'] == true) {
      _status = VodPlaybackStatus.ended;
      _overlayVisible = true;
    } else if (decoded['p'] == true) {
      _status = VodPlaybackStatus.paused;
    } else if (decoded['w'] == true) {
      _status = VodPlaybackStatus.buffering;
    } else {
      _status = VodPlaybackStatus.playing;
      // The embed auto-plays after a reload, even under another player.
      if (!_focused) pause();
    }
    if (wasPaused && !paused && _overlayVisible) _scheduleOverlayHide();
    if (Platform.isAndroid && _pipPlaying != !paused) {
      _pipPlaying = !paused;
      pip.setIsPlaying(!paused);
    }
  }

  Future<void> _run(String script) async {
    if (_disposed) return;
    try {
      await webViewController.runJavaScript(script);
    } catch (e) {
      debugPrint('WebVodStore script failed: $e');
    }
  }

  /// Runs [body] with `v` bound to the page's `<video>` element. [body] is
  /// built only from numbers and literals, never from untrusted text.
  void _onVideo(String body) => unawaited(
    _run(
      "(() => { const v = document.querySelector('video'); "
      'if (v) { $body } })();',
    ),
  );

  // --- Controls -------------------------------------------------------------

  @override
  @action
  void play() {
    // Asked for by the viewer: this player takes focus back.
    _focused = true;
    if (ended) seekTo(Duration.zero);
    _onVideo('v.play();');
  }

  @override
  void pause() => _onVideo('v.pause();');

  @override
  void togglePlay() => paused ? play() : pause();

  @override
  @action
  void seekTo(Duration target) {
    final end = duration - const Duration(seconds: 1);
    var clamped = target < Duration.zero ? Duration.zero : target;
    if (end > Duration.zero && clamped > end) clamped = end;
    _position = clamped;
    _seekTarget = clamped;
    _seekGuardUntil = DateTime.now().add(const Duration(seconds: 3));
    if (_status == VodPlaybackStatus.ended) {
      _status = VodPlaybackStatus.paused;
    }
    final seconds = (clamped.inMilliseconds / 1000).toStringAsFixed(3);
    _onVideo('v.currentTime = $seconds;');
    showOverlay();
  }

  @override
  void seekBy(Duration delta) => seekTo(_position + delta);

  @override
  @action
  void setPlaybackRate(double rate) {
    if (!kVodPlaybackRates.contains(rate)) return;
    _playbackRate = rate;
    _onVideo('v.playbackRate = ${rate.toStringAsFixed(2)};');
  }

  /// The embed picks its quality itself (Auto).
  @override
  void setQuality(String quality) {}

  /// Plays the video over and over (the clip fallback's loop toggle); kept
  /// across page reloads by the bridge.
  @action
  void setLooping(bool looping) {
    _looping = looping;
    _applyLoop();
  }

  @override
  void toggleLoop() => setLooping(!_looping);

  /// [looping] is a boolean, never text: the script stays a literal.
  void _applyLoop([void _]) {
    final looping = _looping;
    unawaited(_run('window._onsetLoop = $looping;'));
    _onVideo('v.loop = $looping;');
  }

  @override
  @action
  void toggleMute() {
    _muted = !_muted;
    _onVideo('v.muted = $_muted;');
  }

  @override
  @action
  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    final unmute = _muted;
    _muted = false;
    _onVideo(
      'v.volume = ${_volume.toStringAsFixed(2)};'
      '${unmute ? ' v.muted = false;' : ''}',
    );
  }

  // --- Overlay & PiP ---------------------------------------------------------

  @override
  @action
  void handleVideoTap() {
    _overlayTimer?.cancel();
    if (_overlayVisible && !paused) {
      _overlayVisible = false;
    } else {
      showOverlay();
    }
  }

  @override
  @action
  void showOverlay() {
    _overlayVisible = true;
    _scheduleOverlayHide();
  }

  void _scheduleOverlayHide() {
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(seconds: 5), () {
      if (!_disposed && !paused) runInAction(() => _overlayVisible = false);
    });
  }

  @override
  void requestPictureInPicture() {
    if (Platform.isAndroid) pip.enterPipMode(autoEnter: true);
  }

  @override
  @action
  void onPipEntered() => _isInPipMode = true;

  @override
  @action
  void onPipExited() => _isInPipMode = false;

  @override
  Future<Duration?> currentPositionForSave() async => _position;

  @override
  void dispose() {
    // The native WebView outlives this store: silence and unload the page
    // (as the live web player does) before the bridge goes quiet.
    _onVideo('v.pause();');
    unawaited(
      webViewController
          .loadRequest(Uri.parse('about:blank'))
          .catchError((Object e) => debugPrint('WebVodStore unload: $e')),
    );
    _disposed = true;
    _overlayTimer?.cancel();
    _disposeAutoPip?.call();
    if (Platform.isAndroid) pip.setAutoPipMode(autoEnter: false);
  }
}
