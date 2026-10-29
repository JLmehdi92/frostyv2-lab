import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/apis/twitch_api.dart';

part 'create_clip_store.g.dart';

/// Where creating a clip is.
enum CreateClipStatus {
  idle,

  /// Clips are made on the viewer's account: they must log in.
  needsLogin,

  /// Reading which permissions the login has.
  checking,

  /// The login is from before clips: reconnecting grants `clips:edit`.
  missingScope,

  /// Asking Twitch for the clip.
  creating,

  /// Twitch is making the clip (it can already be edited on twitch.tv).
  rendering,

  /// The clip exists.
  ready,

  failed,
}

class CreateClipStore = CreateClipStoreBase with _$CreateClipStore;

/// Clips a live stream as the viewer, like the official app's Create Clip
/// panel: one request to Twitch (Helix), then a look every few seconds
/// until the clip exists, for at most a minute (Twitch's own advice).
abstract class CreateClipStoreBase with Store {
  CreateClipStoreBase({
    required this.twitchApi,
    required this.broadcasterId,
    required this.isLoggedIn,
    @visibleForTesting this.pollInterval = const Duration(seconds: 5),
    @visibleForTesting this.renderTimeout = const Duration(seconds: 60),
  });

  /// The scope Helix needs to create a clip.
  static const clipScope = 'clips:edit';

  final TwitchApi twitchApi;
  final String broadcasterId;
  final bool Function() isLoggedIn;
  final Duration pollInterval;
  final Duration renderTimeout;

  Timer? _poll;
  var _disposed = false;

  @readonly
  var _status = CreateClipStatus.idle;

  /// Why the clip could not be made (when [status] is failed).
  @readonly
  ClipCreateFailure? _failure;

  @readonly
  ClipCreation? _creation;

  @readonly
  String? _thumbnailUrl;

  bool get _busy =>
      _status == CreateClipStatus.checking ||
      _status == CreateClipStatus.creating ||
      _status == CreateClipStatus.rendering;

  /// Clips the stream now (once at a time).
  @action
  Future<void> start() async {
    if (_disposed || _busy) return;
    _failure = null;
    _creation = null;
    _thumbnailUrl = null;
    if (!isLoggedIn()) {
      _status = CreateClipStatus.needsLogin;
      return;
    }
    _status = CreateClipStatus.checking;
    try {
      final scopes = await twitchApi.getTokenScopes();
      if (_disposed) return;
      if (!scopes.contains(clipScope)) {
        runInAction(() => _status = CreateClipStatus.missingScope);
        return;
      }
    } catch (e) {
      // Unknown: Twitch's answer to the clip request will tell.
      debugPrint('Clip scope check failed: ${e.runtimeType}');
    }
    if (_disposed) return;
    runInAction(() => _status = CreateClipStatus.creating);
    try {
      final creation = await twitchApi.createClip(broadcasterId: broadcasterId);
      if (_disposed) return;
      runInAction(() {
        _creation = creation;
        _status = CreateClipStatus.rendering;
      });
      _watch(creation.id);
    } on ClipCreateException catch (e) {
      if (_disposed) return;
      runInAction(() {
        if (e.reason == ClipCreateFailure.missingScope) {
          _status = CreateClipStatus.missingScope;
        } else {
          _failure = e.reason;
          _status = CreateClipStatus.failed;
        }
      });
    } catch (e) {
      debugPrint('Clip request failed: ${e.runtimeType}');
      if (_disposed) return;
      runInAction(() {
        _failure = ClipCreateFailure.unknown;
        _status = CreateClipStatus.failed;
      });
    }
  }

  /// Looks for the clip every [pollInterval] until it exists or
  /// [renderTimeout] has passed; one look at a time.
  void _watch(String id) {
    final deadline = renderTimeout.inMilliseconds;
    var waited = 0;
    var looking = false;
    _poll?.cancel();
    _poll = Timer.periodic(pollInterval, (timer) async {
      if (_disposed) {
        timer.cancel();
        return;
      }
      if (looking) return;
      waited += pollInterval.inMilliseconds;
      looking = true;
      CreatedClip? made;
      try {
        made = await twitchApi.getCreatedClip(id);
      } catch (e) {
        debugPrint('Clip status check failed: ${e.runtimeType}');
      } finally {
        looking = false;
      }
      if (_disposed || !timer.isActive) return;
      if (made != null) {
        timer.cancel();
        final thumbnail = made.thumbnailUrl;
        runInAction(() {
          _thumbnailUrl = thumbnail;
          _status = CreateClipStatus.ready;
        });
      } else if (waited >= deadline) {
        timer.cancel();
        runInAction(() {
          _failure = ClipCreateFailure.unknown;
          _status = CreateClipStatus.failed;
        });
      }
    });
  }

  void dispose() {
    _disposed = true;
    _poll?.cancel();
  }
}
