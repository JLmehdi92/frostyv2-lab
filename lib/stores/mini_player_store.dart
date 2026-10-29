import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/screens/channel/chat/stores/chat_tabs_store.dart';
import 'package:onset/screens/channel/video/live_progress.dart';
import 'package:onset/screens/channel/video/stores/ivs_video_store.dart';

part 'mini_player_store.g.dart';

class MiniPlayerStore = MiniPlayerStoreBase with _$MiniPlayerStore;

/// Global, app-wide in-app mini player. Holds the live [IvsVideoStore] (and the
/// channel's [ChatTabsStore]) handed over from the channel screen so the *same*
/// player keeps playing — and the chat keeps its connection and message history
/// — in a floating window while the user navigates the rest of the app. No
/// reload, and no chat reset, on the way in or out.
abstract class MiniPlayerStoreBase with Store {
  /// Whether the floating mini player is currently shown.
  @readonly
  bool _visible = false;

  /// The channel currently in the mini player.
  @readonly
  String? _userLogin;

  @readonly
  String? _userId;

  @readonly
  String? _displayName;

  /// What the navigation shell's chrome covers from the top and bottom of
  /// the screen while the shell is the page on screen (null otherwise): the
  /// window keeps its corners inside, under the header and above the bar.
  @readonly
  EdgeInsets? _shellChrome;

  @action
  void setShellChrome(EdgeInsets? insets) {
    if (insets != _shellChrome) _shellChrome = insets;
  }

  /// The live player powering the mini window (adopted from the channel).
  @readonly
  IvsVideoStore? _player;

  /// The live chat kept alive (connected, accumulating messages) while
  /// minimized, so its history survives restoring the channel.
  @readonly
  ChatTabsStore? _chatTabsStore;

  /// Keeps recording where the viewer is in the broadcast while minimized
  /// (it follows [_player]); closed before the player goes.
  LiveProgressTracker? _liveProgress;

  void _closeLiveProgress() {
    final tracker = _liveProgress;
    _liveProgress = null;
    if (tracker != null) unawaited(tracker.close());
  }

  /// Adopts an already-playing [player] and its live [chatTabsStore] from the
  /// channel screen so both keep running seamlessly while minimized, with
  /// the [liveProgress] tracker following the player.
  @action
  void adopt({
    required IvsVideoStore player,
    required ChatTabsStore chatTabsStore,
    required String userLogin,
    required String userId,
    required String displayName,
    LiveProgressTracker? liveProgress,
  }) {
    if (_liveProgress != null && !identical(_liveProgress, liveProgress)) {
      _closeLiveProgress();
    }
    if (_player != null && !identical(_player, player)) _player!.dispose();
    if (_chatTabsStore != null && !identical(_chatTabsStore, chatTabsStore)) {
      _chatTabsStore!.dispose();
    }
    _userLogin = userLogin;
    _userId = userId;
    _displayName = displayName;
    _player = player;
    _chatTabsStore = chatTabsStore;
    _liveProgress = liveProgress;
    _visible = true;
  }

  /// Hands the live player, chat and progress tracker back to the caller
  /// (when restoring the full channel) without disposing them, and hides the
  /// mini window.
  @action
  ({
    IvsVideoStore? player,
    ChatTabsStore? chat,
    LiveProgressTracker? liveProgress,
  })
  release() {
    final player = _player;
    final chat = _chatTabsStore;
    final liveProgress = _liveProgress;
    _player = null;
    _chatTabsStore = null;
    _liveProgress = null;
    _userLogin = null;
    _userId = null;
    _displayName = null;
    _visible = false;
    return (player: player, chat: chat, liveProgress: liveProgress);
  }

  /// Closes the mini player and releases its resources.
  @action
  void close() {
    // Reads the position before the player goes.
    _closeLiveProgress();
    _player?.dispose();
    _chatTabsStore?.dispose();
    _player = null;
    _chatTabsStore = null;
    _userLogin = null;
    _userId = null;
    _displayName = null;
    _visible = false;
  }
}
