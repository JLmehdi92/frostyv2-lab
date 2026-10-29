import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/models/stream.dart';

/// What the channel screen says about the viewer and this channel beyond
/// the stream itself: whether they follow it (the "Follow" / "Following"
/// button) and, beside a tablet's video, their other followed channels live
/// now (board Tablette, "Also live from your follows").
///
/// Asked once, [headStart] after the screen opens, so it never competes
/// with the player's own requests; any failure leaves the defaults (the
/// button says "Follow", the row stays hidden).
class ChannelInfoStore {
  ChannelInfoStore({
    required this.channelId,
    required TwitchApi api,
    required String? Function() viewerId,
    this.startDelay = headStart,
  }) : _api = api,
       _viewerId = viewerId;

  /// How long the player gets the network to itself.
  static const headStart = Duration(seconds: 2);

  /// The most "also live" channels kept.
  static const alsoLiveLimit = 6;

  /// How long [start] waits: [headStart] beside a player, nothing on a
  /// screen without one (the channel profile).
  final Duration startDelay;

  final String channelId;
  final TwitchApi _api;
  final String? Function() _viewerId;

  /// Null until known (or when it cannot be known).
  final following = ValueNotifier<bool?>(null);

  final alsoLive = ValueNotifier<List<StreamTwitch>>(const []);

  Timer? _timer;
  var _ready = false;
  var _alsoLiveWanted = false;

  /// True once "also live" was had for the current viewer, or while it is
  /// being asked; a failure leaves it false so the next refresh asks again.
  var _alsoLiveDone = false;
  var _alsoLiveLoading = false;
  var _disposed = false;

  void start() {
    _timer ??= Timer(startDelay, () {
      _ready = true;
      refresh();
    });
  }

  /// Reads everything again: the follow, and "also live" when it is wanted
  /// and not had yet (after a failure, or after the viewer changed).
  void refresh() {
    if (_disposed || !_ready) return;
    unawaited(refreshFollowing());
    if (_alsoLiveWanted) unawaited(_loadAlsoLive());
  }

  /// The signed-in viewer changed (known late on a cold start, signed in or
  /// out): what they follow is read again, once the head start is over.
  void viewerChanged() {
    if (_disposed) return;
    // What was read was the previous account's.
    following.value = null;
    alsoLive.value = const [];
    _alsoLiveDone = false;
    refresh();
  }

  /// Reads the follow again (after the viewer came back from twitch.tv).
  Future<void> refreshFollowing() async {
    if (_disposed) return;
    final viewer = _viewerId();
    if (viewer == null) return;
    try {
      final follows = await _api.isFollowing(
        userId: viewer,
        broadcasterId: channelId,
      );
      // Dropped when the account changed meanwhile: never one account's
      // follows on another's screen.
      if (!_disposed && _viewerId() == viewer) following.value = follows;
    } catch (error) {
      debugPrint('Follow state unavailable: $error');
    }
  }

  /// The tablet's info area is on screen: its "also live" row is wanted.
  void wantAlsoLive() {
    _alsoLiveWanted = true;
    if (_ready) unawaited(_loadAlsoLive());
  }

  Future<void> _loadAlsoLive() async {
    if (_alsoLiveDone || _alsoLiveLoading || _disposed) return;
    final viewer = _viewerId();
    if (viewer == null) return;
    _alsoLiveLoading = true;
    var askAgain = false;
    try {
      final streams = await _api.getFollowedStreams(
        id: viewer,
        first: alsoLiveLimit + 1,
        quiet: true,
      );
      if (_disposed) return;
      if (_viewerId() != viewer) {
        // Another account now: its own list is asked for.
        askAgain = true;
        return;
      }
      alsoLive.value = List.unmodifiable(
        streams.data
            .where((stream) => stream.userId != channelId)
            .take(alsoLiveLimit),
      );
      _alsoLiveDone = true;
    } catch (error) {
      debugPrint('Followed live channels unavailable: $error');
    } finally {
      _alsoLiveLoading = false;
      if (askAgain) unawaited(_loadAlsoLive());
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    following.dispose();
    alsoLive.dispose();
  }
}
