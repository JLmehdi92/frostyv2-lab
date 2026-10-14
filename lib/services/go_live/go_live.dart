import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/models/stream.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the go-live check needs between runs, kept in plain preferences so
/// the background task (its own isolate, without the app's stores) reads
/// the same values as the settings screen.
class GoLivePrefs {
  GoLivePrefs(this._prefs);

  final SharedPreferences _prefs;

  static const _enabledKey = 'go_live_enabled';
  static const _mutedKey = 'go_live_muted';
  static const _userKey = 'go_live_user_id';
  static const _seenKey = 'go_live_seen';

  static Future<GoLivePrefs> load() async =>
      GoLivePrefs(await SharedPreferences.getInstance());

  bool get enabled => _prefs.getBool(_enabledKey) ?? false;
  Future<void> setEnabled(bool value) => _prefs.setBool(_enabledKey, value);

  /// The channels (ids) whose bell is off, like Twitch: every followed
  /// channel notifies unless muted.
  Set<String> get muted => {...?_prefs.getStringList(_mutedKey)};

  Future<void> setMuted(String channelId, bool muted) {
    final ids = this.muted;
    muted ? ids.add(channelId) : ids.remove(channelId);
    return _prefs.setStringList(_mutedKey, [...ids]);
  }

  /// The viewer whose followed channels are checked; null when logged out.
  String? get userId => _prefs.getString(_userKey);
  Future<void> setUserId(String? id) async {
    if (id == userId) return;
    // Another viewer follows other channels: start over without a burst.
    await setSeen(null);
    if (id == null) {
      await _prefs.remove(_userKey);
    } else {
      await _prefs.setString(_userKey, id);
    }
  }

  /// The followed channels live at the last check; null before the first.
  Set<String>? get seen {
    final ids = _prefs.getStringList(_seenKey);
    return ids == null ? null : {...ids};
  }

  Future<void> setSeen(Set<String>? ids) async {
    if (ids == null) {
      await _prefs.remove(_seenKey);
    } else {
      await _prefs.setStringList(_seenKey, [...ids]);
    }
  }
}

/// The streams to announce: live now, not at the last check ([wasLive]),
/// and not [muted]. Nothing before a first check, so turning the feature
/// on does not announce everyone already live.
List<StreamTwitch> newlyLive({
  required Set<String>? wasLive,
  required List<StreamTwitch> live,
  Set<String> muted = const {},
}) {
  if (wasLive == null) return const [];
  return [
    for (final stream in live)
      if (!wasLive.contains(stream.userId) && !muted.contains(stream.userId))
        stream,
  ];
}

/// A notice for someone who went live.
typedef GoLiveNotice = ({
  String userId,
  String login,
  String title,
  String body,
});

GoLiveNotice goLiveNotice(StreamTwitch stream) => (
  userId: stream.userId,
  login: stream.userLogin,
  title:
      '${stream.userName.isEmpty ? stream.userLogin : stream.userName} '
      'is live',
  body: [
    if (stream.title.trim().isNotEmpty) stream.title.trim(),
    if (stream.gameName.isNotEmpty) stream.gameName,
  ].join(' · '),
);

/// At most this many notices per check; more are summed up in one.
const kMaxGoLiveNotices = 5;

/// Pages of followed streams read per check (100 each).
const _maxPages = 3;

/// One check: reads the viewer's live followed channels, announces the
/// ones that just went live through [notify], and remembers who is live.
/// Returns how many were announced. Throws when Twitch cannot be read (the
/// last state is kept, so nothing is lost or announced twice).
Future<int> checkGoLive({
  required TwitchApi api,
  required GoLivePrefs prefs,
  required Future<void> Function(List<GoLiveNotice> notices, int more) notify,
}) async {
  final userId = prefs.userId;
  if (!prefs.enabled || userId == null) return 0;
  final live = <StreamTwitch>[];
  String? cursor;
  for (var page = 0; page < _maxPages; page++) {
    final streams = await api.getFollowedStreams(
      id: userId,
      cursor: cursor,
      first: 100,
    );
    live.addAll(streams.data);
    cursor = streams.pagination['cursor'];
    if (cursor == null || streams.data.isEmpty) break;
  }
  final fresh = newlyLive(wasLive: prefs.seen, live: live, muted: prefs.muted);
  await prefs.setSeen({for (final stream in live) stream.userId});
  if (fresh.isEmpty) return 0;
  final shown = fresh.take(kMaxGoLiveNotices).map(goLiveNotice).toList();
  await notify(shown, fresh.length - shown.length);
  return fresh.length;
}
