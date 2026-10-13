import 'package:frosty/screens/channel/chat/stores/chat_tabs_store.dart';
import 'package:frosty/screens/channel/video/stores/ivs_video_store.dart';
import 'package:mobx/mobx.dart';

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

  /// The live player powering the mini window (adopted from the channel).
  @readonly
  IvsVideoStore? _player;

  /// The live chat kept alive (connected, accumulating messages) while
  /// minimized, so its history survives restoring the channel.
  @readonly
  ChatTabsStore? _chatTabsStore;

  /// Adopts an already-playing [player] and its live [chatTabsStore] from the
  /// channel screen so both keep running seamlessly while minimized.
  @action
  void adopt({
    required IvsVideoStore player,
    required ChatTabsStore chatTabsStore,
    required String userLogin,
    required String userId,
    required String displayName,
  }) {
    if (_player != null && !identical(_player, player)) _player!.dispose();
    if (_chatTabsStore != null && !identical(_chatTabsStore, chatTabsStore)) {
      _chatTabsStore!.dispose();
    }
    _userLogin = userLogin;
    _userId = userId;
    _displayName = displayName;
    _player = player;
    _chatTabsStore = chatTabsStore;
    _visible = true;
  }

  /// Hands the live player and chat back to the caller (when restoring the full
  /// channel) without disposing them, and hides the mini window.
  @action
  ({IvsVideoStore? player, ChatTabsStore? chat}) release() {
    final player = _player;
    final chat = _chatTabsStore;
    _player = null;
    _chatTabsStore = null;
    _userLogin = null;
    _userId = null;
    _displayName = null;
    _visible = false;
    return (player: player, chat: chat);
  }

  /// Closes the mini player and releases its resources.
  @action
  void close() {
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
