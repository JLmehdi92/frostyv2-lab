import 'package:flutter/widgets.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/apis/twitch_chat_rules_service.dart';
import 'package:onset/models/chat_rules.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'chat_rules_store.g.dart';

class ChatRulesStore = ChatRulesStoreBase with _$ChatRulesStore;

/// A channel's chat rules, and the official app's "Chat Rules" gate: the
/// first time a logged-in viewer goes to type in a channel with rules, the
/// rules sheet shows instead of the keyboard, until they tap "OK, Got it!".
/// Accepting is remembered on the device per viewer and channel, like
/// Twitch (`<viewer id><channel id>` in its preferences).
///
/// The rules come from anonymous GQL; any failure just shows nothing.
abstract class ChatRulesStoreBase with Store {
  ChatRulesStoreBase({
    required this.service,
    required this.channelId,
    required this.viewerId,
  });

  final TwitchChatRulesService service;
  final String channelId;

  /// The logged-in viewer's id, or null when not logged in.
  final String? Function() viewerId;

  static const _prefix = 'chat_rules_accepted_';

  Future<void>? _loading;
  SharedPreferences? _prefs;
  FocusNode? _focus;
  var _disposed = false;

  /// The channel's rules, once read (null before, or when they could not be).
  @readonly
  ChatRules? _rules;

  /// Bumped on accept, so [mustShowBeforeChatting] is recomputed.
  @observable
  var _acceptedVersion = 0;

  /// True while the rules sheet should be on screen in place of the input.
  @readonly
  var _prompting = false;

  String _key(String viewer) => '$_prefix${viewer}_$channelId';

  /// Whether the rules must show before the viewer may type.
  @computed
  bool get mustShowBeforeChatting {
    _acceptedVersion;
    final viewer = viewerId();
    final prefs = _prefs;
    if (viewer == null || prefs == null || _rules?.hasRules != true) {
      return false;
    }
    return prefs.getBool(_key(viewer)) != true;
  }

  /// Reads the rules (once; again after a failure only with a new store).
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object?>([
        service.getRules(channelId),
        SharedPreferences.getInstance(),
      ]);
      if (_disposed) return;
      runInAction(() {
        _prefs = results[1] as SharedPreferences;
        _rules = results[0] as ChatRules?;
      });
    } catch (e) {
      debugPrint('Chat rules unavailable: $e');
    }
  }

  /// Gates [focus], the chat input: gaining focus while the rules must
  /// show drops the focus and asks for the rules sheet.
  void attach(FocusNode focus) {
    _focus?.removeListener(_onFocus);
    _focus = focus..addListener(_onFocus);
  }

  void _onFocus() {
    final focus = _focus;
    if (focus == null || !focus.hasFocus || !mustShowBeforeChatting) return;
    focus.unfocus();
    runInAction(() => _prompting = true);
  }

  /// Gates a send that did not go through the input's focus (an emote
  /// picked, then sent): true, and the rules sheet asked for, while the
  /// rules must show first.
  bool gate() {
    if (!mustShowBeforeChatting) return false;
    runInAction(() => _prompting = true);
    return true;
  }

  /// The viewer closed the sheet without accepting: it shows again on the
  /// next try, like Twitch.
  @action
  void dismissPrompt() => _prompting = false;

  /// "OK, Got it!": remembered for this viewer and channel.
  Future<void> accept() async {
    final viewer = viewerId();
    runInAction(() => _prompting = false);
    if (viewer == null) return;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setBool(_key(viewer), true);
    if (_disposed) return;
    runInAction(() => _acceptedVersion++);
  }

  void dispose() {
    _disposed = true;
    _focus?.removeListener(_onFocus);
    _focus = null;
  }
}
