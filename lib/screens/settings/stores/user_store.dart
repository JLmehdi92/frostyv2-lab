import 'package:mobx/mobx.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/models/user.dart';

part 'user_store.g.dart';

class UserStore = UserStoreBase with _$UserStore;

abstract class UserStoreBase with Store {
  final TwitchApi twitchApi;

  /// The current user's info.
  @readonly
  UserTwitch? _details;

  /// The user's list of blocked users.
  @readonly
  var _blockedUsers = ObservableList<UserBlockedTwitch>();

  ReactionDisposer? _disposeReaction;

  UserStoreBase({required this.twitchApi});

  /// Loads the current user. [details]: already read (a login checks its
  /// new token's user before making it the session), so the session switches
  /// at once, without another request that could fail half-way.
  @action
  Future<void> init({UserTwitch? details}) async {
    // Get and update the current user's info.
    _details = details ?? await twitchApi.getUserInfo();
    _disposeReaction?.call();

    // Get and update the current user's list of blocked users.
    // Don't use await because having a huge list of blocked users will block the UI.
    if (_details?.id != null) {
      twitchApi
          .getUserBlockedList(id: _details!.id)
          .then((blockedUsers) => _blockedUsers = blockedUsers.asObservable());
    }

    _disposeReaction = autorun(
      (_) => _blockedUsers.sort((a, b) => a.userLogin.compareTo(b.userLogin)),
    );
  }

  @action
  Future<void> block({
    required String targetId,
    required String displayName,
    BlockReason? reason,
    BlockSource? source,
  }) async {
    final success = await twitchApi.blockUser(
      userId: targetId,
      reason: reason,
      source: source,
    );

    if (success) {
      _blockedUsers.add(UserBlockedTwitch(targetId, displayName, displayName));
    }
  }

  @action
  Future<void> unblock({required String targetId}) async {
    final success = await twitchApi.unblockUser(userId: targetId);
    if (success) await refreshBlockedUsers();
  }

  @action
  Future<void> refreshBlockedUsers() async => _blockedUsers =
      (await twitchApi.getUserBlockedList(id: _details!.id)).asObservable();

  @action
  void dispose() {
    _details = null;
    _blockedUsers.clear();
    if (_disposeReaction != null) _disposeReaction!();
  }
}
