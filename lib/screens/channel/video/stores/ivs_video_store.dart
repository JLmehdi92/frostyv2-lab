import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/apis/twitch_stream_service.dart';
import 'package:frosty/models/channel.dart';
import 'package:frosty/models/stream.dart';
import 'package:frosty/screens/channel/video/player_controller.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:mobx/mobx.dart';
import 'package:simple_pip_mode/simple_pip.dart';

part 'ivs_video_store.g.dart';

class IvsVideoStore = IvsVideoStoreBase with _$IvsVideoStore;

/// Drives the native Amazon IVS player (the same engine the official Twitch
/// app uses) over a MethodChannel, exposing the shared [PlayerController]
/// surface so the existing overlay/channel can use it unchanged.
abstract class IvsVideoStoreBase with Store implements PlayerController {
  final String userLogin;
  final String userId;
  final TwitchApi twitchApi;
  final AuthStore authStore;

  @override
  final SettingsStore settingsStore;

  final TwitchStreamService _streamService;
  final bool _ownsStreamService;

  /// Android picture-in-picture controller.
  final pip = SimplePip();
  ReactionDisposer? _disposeAutoPipReaction;

  static const _textureManager = MethodChannel('frosty/ivs-texture-manager');

  /// The Flutter texture this store's IVS stream renders into (null until
  /// created). Owned by the store — not the widget — so the live player can
  /// move between the channel screen and the mini player without reloading.
  @readonly
  int? _textureId;

  /// Set by the [IvsVideo] widget once the native PlatformView is created.
  MethodChannel? _channel;

  /// Called when the IVS player hits a fatal error so the channel screen can
  /// fall back to the WebView engine.
  void Function()? onFatalError;

  /// The usher URL to hand to the native IVS player (null until resolved).
  @readonly
  String? _url;

  /// Completes when the usher URL is resolved, or throws so the channel can
  /// fall back to the WebView engine.
  late final Future<void> ready;

  Timer? _overlayTimer;
  int? _lastLatencySecond;

  @readonly
  List<String> _availableStreamQualities = [];

  @readonly
  int _streamQualityIndex = 0;

  @readonly
  var _paused = false;

  @readonly
  var _overlayVisible = true;

  @readonly
  StreamTwitch? _streamInfo;

  @readonly
  Channel? _offlineChannelInfo;

  @readonly
  String? _latency;

  @readonly
  var _isInPipMode = false;

  /// When true the video fills the screen (cropping a little off the edges)
  /// instead of fitting inside it with letterbox bars. Never distorts the
  /// image — both modes keep the 16:9 aspect ratio. Toggled by the tablet
  /// button so the picture fits the device screen (e.g. a 3:2 tablet).
  @readonly
  var _fillScreen = false;

  @action
  void toggleFillScreen() => _fillScreen = !_fillScreen;

  @override
  String get streamQuality =>
      _availableStreamQualities.elementAtOrNull(_streamQualityIndex) ?? 'Auto';

  IvsVideoStoreBase({
    required this.userLogin,
    required this.userId,
    required this.twitchApi,
    required this.authStore,
    required this.settingsStore,
    TwitchStreamService? streamService,
  }) : _ownsStreamService = streamService == null,
       _streamService = streamService ?? TwitchStreamService(Dio()) {
    if (settingsStore.autoSyncChatDelay) settingsStore.syncedChatDelay = 0.0;
    ready = _resolveUrl();
    unawaited(ready.then((_) => _createTexture()).catchError((Object _) {}));
    unawaited(updateStreamInfo());
    _scheduleOverlayHide();

    // Enable auto picture-in-picture so the stream keeps playing in a floating
    // window when the user leaves the app.
    if (Platform.isAndroid) {
      _disposeAutoPipReaction = autorun((_) async {
        if (settingsStore.showVideo && await SimplePip.isAutoPipAvailable) {
          pip.setAutoPipMode();
        } else {
          pip.setAutoPipMode(autoEnter: false);
        }
      });
    }
  }

  /// Updates the picture-in-picture state when the OS enters/exits PiP.
  @action
  void onPipEntered() => _isInPipMode = true;

  @action
  void onPipExited() => _isInPipMode = false;

  @action
  Future<void> _resolveUrl() async {
    _url = await _streamService.getUsherUrl(userLogin: userLogin);
  }

  /// Wires the per-view MethodChannel once the native SurfaceView exists.
  void attachPlatformView(int viewId) => _attachChannel('frosty/ivs/$viewId');

  /// Wires the per-texture MethodChannel for the texture-backed mini player.
  void attachTextureChannel(int textureId) =>
      _attachChannel('frosty/ivs-texture/$textureId');

  void _attachChannel(String name) {
    final channel = MethodChannel(name);
    _channel = channel;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'onEvent') {
        _onEvent(Map<String, dynamic>.from(call.arguments as Map));
      }
    });
  }

  /// Creates the native texture-backed IVS player once the usher URL resolves,
  /// then wires its control/event channel. The texture lives for as long as
  /// this store does.
  Future<void> _createTexture() async {
    if (_textureId != null) return;
    final url = _url;
    if (url == null) return;
    final id = await _textureManager.invokeMethod<int>('create', {'url': url});
    if (id == null) return;
    attachTextureChannel(id);
    runInAction(() => _textureId = id);
  }

  @action
  void _onEvent(Map<String, dynamic> e) {
    switch (e['type']) {
      case 'state':
        final state = e['state'] as String?;
        if (state == 'PLAYING') _paused = false;
        if (state == 'IDLE' || state == 'ENDED') _paused = true;
        if (Platform.isAndroid) pip.setIsPlaying(!_paused);
        break;
      case 'qualities':
        final list = (e['list'] as List).map((q) => q.toString()).toList();
        _availableStreamQualities = ['Auto', ...list];
        break;
      case 'quality':
        final name = e['name'] as String?;
        final index = _availableStreamQualities.indexOf(name ?? '');
        if (index != -1) _streamQualityIndex = index;
        break;
      case 'latency':
        final ms = (e['ms'] as num?)?.toInt() ?? -1;
        if (ms < 0) break;
        final seconds = (ms / 1000).clamp(0, 60).round();
        if (seconds == _lastLatencySecond) break;
        _lastLatencySecond = seconds;
        _latency = '${seconds}s';
        if (settingsStore.autoSyncChatDelay) {
          settingsStore.syncedChatDelay = seconds.toDouble();
        }
        break;
      case 'error':
        debugPrint('IVS error: ${e['code']} ${e['msg']}');
        onFatalError?.call();
        break;
    }
  }

  @override
  void handlePausePlay() {
    _channel?.invokeMethod(_paused ? 'play' : 'pause');
  }

  @override
  @action
  void setStreamQuality(String quality) {
    final index = _availableStreamQualities.indexOf(quality);
    if (index == -1) return;
    _streamQualityIndex = index;
    if (quality == 'Auto') {
      _channel?.invokeMethod('setAutoQuality');
    } else {
      _channel?.invokeMethod('setQuality', {'name': quality});
    }
  }

  @override
  Future<void> updateStreamQualities() async {
    // Qualities arrive via the 'qualities' event; nothing to refresh on demand.
  }

  @override
  @action
  Future<void> handleRefresh() async {
    _latency = null;
    _lastLatencySecond = null;
    try {
      final url = await _streamService.getUsherUrl(userLogin: userLogin);
      _url = url;
      await _channel?.invokeMethod('load', {'url': url});
      await updateStreamInfo(forceUpdate: true);
    } catch (e) {
      debugPrint('IvsVideoStore refresh failed: $e');
    }
  }

  @override
  @action
  void handleVideoTap() {
    _overlayTimer?.cancel();
    if (_overlayVisible) {
      _overlayVisible = false;
    } else {
      _overlayVisible = true;
      unawaited(updateStreamInfo(forceUpdate: true));
      _scheduleOverlayHide();
    }
  }

  @override
  void handleToggleOverlay() {}

  @override
  void handleAppResume() {
    if (!settingsStore.showVideo) unawaited(updateStreamInfo(forceUpdate: true));
  }

  @override
  void requestPictureInPicture() {
    if (Platform.isAndroid) pip.enterPipMode(autoEnter: true);
  }

  @override
  void togglePictureInPicture() => requestPictureInPicture();

  void _scheduleOverlayHide([Duration delay = const Duration(seconds: 5)]) {
    _overlayTimer?.cancel();
    _overlayTimer = Timer(
      delay,
      () => runInAction(() => _overlayVisible = false),
    );
  }

  @action
  Future<void> updateStreamInfo({bool forceUpdate = false}) async {
    try {
      _streamInfo = await twitchApi.getStream(userLogin: userLogin);
      _offlineChannelInfo = null;
    } catch (e) {
      _streamInfo = null;
      _paused = true;
      try {
        _offlineChannelInfo = await twitchApi.getChannel(userId: userId);
      } catch (_) {
        _offlineChannelInfo = null;
      }
    }
  }

  @override
  @action
  void dispose() {
    _overlayTimer?.cancel();
    _disposeAutoPipReaction?.call();
    if (Platform.isAndroid) pip.setAutoPipMode(autoEnter: false);
    final textureId = _textureId;
    if (textureId != null) {
      _textureManager.invokeMethod('dispose', {'textureId': textureId});
      _textureId = null;
    }
    _channel?.setMethodCallHandler(null);
    if (_ownsStreamService) _streamService.close();
  }
}
