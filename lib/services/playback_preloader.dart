import 'dart:async';

import 'package:dio/dio.dart';
import 'package:frosty/apis/twitch_stream_service.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/services/playback_token_cache.dart';

/// Asks for a stream's playback token as soon as its card is pressed, so the
/// native player finds it cached (or on its way, see
/// [PlaybackTokenCache.pending]) instead of waiting a GQL round trip after
/// the channel opens, like the official app's theatre preload.
class PlaybackPreloader {
  PlaybackPreloader(this._service);

  /// The app-wide preloader, sharing [PlaybackTokenCache.shared] with the
  /// players (replaced in tests).
  static PlaybackPreloader instance = PlaybackPreloader(
    TwitchStreamService(
      tokenCache: PlaybackTokenCache.shared,
      Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 8),
        ),
      ),
    ),
  );

  final TwitchStreamService _service;

  /// Preloads [login]'s token when the IVS engine will play it (the other
  /// engines do not use it).
  void preload({required String login, required PlayerEngine engine}) {
    if (engine != PlayerEngine.ivs || login.isEmpty) return;
    unawaited(_service.preload(login));
  }
}
