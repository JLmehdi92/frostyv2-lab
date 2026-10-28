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
  }) : _api = api,
       _viewerId = viewerId;

  /// How long the player gets the network to itself.
  static const headStart = Duration(seconds: 2);

  /// The most "also live" channels kept.
  static const alsoLiveLimit = 6;

  final String channelId;
  final TwitchApi _api;
  final String? Function() _viewerId;

  /// Null until known (or when it cannot be known).
  final following = ValueNotifier<bool?>(null);

  final alsoLive = ValueNotifier<List<StreamTwitch>>(const []);

  Timer? _timer;
  var _ready = false;
  var _alsoLiveWanted = false;
  var _alsoLiveAsked = false;
  var _disposed = false;

  void start() {
    _timer ??= Timer(headStart, () {
      _ready = true;
      unawaited(refreshFollowing());
      if (_alsoLiveWanted) unawaited(_loadAlsoLive());
    });
  }

  /// Reads the follow again (after the viewer came back from twitch.tv).
  Future<void> refreshFollowing() async {
    final viewer = _viewerId();
    if (viewer == null || _disposed) return;
    try {
      final follows = await _api.isFollowing(
        userId: viewer,
        broadcasterId: channelId,
      );
      if (!_disposed) following.value = follows;
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
    if (_alsoLiveAsked || _disposed) return;
    final viewer = _viewerId();
    if (viewer == null) return;
    _alsoLiveAsked = true;
    try {
      final streams = await _api.getFollowedStreams(
        id: viewer,
        first: alsoLiveLimit + 1,
      );
      if (_disposed) return;
      alsoLive.value = List.unmodifiable(
        streams.data
            .where((stream) => stream.userId != channelId)
            .take(alsoLiveLimit),
      );
    } catch (error) {
      debugPrint('Followed live channels unavailable: $error');
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    following.dispose();
    alsoLive.dispose();
  }
}
