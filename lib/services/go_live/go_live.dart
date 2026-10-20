import 'package:frosty/apis/base_api_client.dart';
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
  static const _problemKey = 'go_live_problem';
  static const _checkedAtKey = 'go_live_checked_at';
  static const _announcedKey = 'go_live_announced';

  static Future<GoLivePrefs> load() async =>
      GoLivePrefs(await SharedPreferences.getInstance());

  /// Reads again what the other isolate (the background check, or the app)
  /// wrote since: each keeps its own copy of the preferences.
  Future<void> reload() => _prefs.reload();

  bool get enabled => _prefs.getBool(_enabledKey) ?? false;

  /// Turning it on starts afresh: who went live while it was off is not
  /// announced.
  Future<void> setEnabled(bool value) async {
    if (value && !enabled) await setSeen(null);
    await _prefs.setBool(_enabledKey, value);
  }

  /// Why the last background check could not run (shown in the settings);
  /// null when it ran.
  String? get problem => _prefs.getString(_problemKey);
  Future<void> setProblem(String? problem) async {
    if (problem == null) {
      await _prefs.remove(_problemKey);
    } else {
      await _prefs.setString(_problemKey, problem);
    }
  }

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

  /// When a check (the app's or the background one) last started.
  DateTime? get checkedAt {
    final ms = _prefs.getInt(_checkedAtKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setCheckedAt(DateTime at) =>
      _prefs.setInt(_checkedAtKey, at.millisecondsSinceEpoch);

  /// Whether a check started less than [gap] before [now] (a clock set
  /// back does not count).
  bool checkedWithin(Duration gap, DateTime now) {
    final last = checkedAt;
    return last != null && !now.isBefore(last) && now.difference(last) < gap;
  }

  /// The broadcast (its `started_at`) last announced for each channel id:
  /// one notice per broadcast, like Twitch's own.
  Map<String, String> get announced => {
    for (final entry in _prefs.getStringList(_announcedKey) ?? const [])
      if (entry.indexOf('@') case final at when at > 0)
        entry.substring(0, at): entry.substring(at + 1),
  };

  Future<void> setAnnounced(Map<String, String> announced) =>
      _prefs.setStringList(_announcedKey, [
        for (final MapEntry(:key, :value) in announced.entries) '$key@$value',
      ]);
}

/// The streams to announce: live now, not at the last check ([wasLive]),
/// not [muted], and not a broadcast already [announced] (a channel seen
/// going off and back on in the same broadcast). Nothing before a first
/// check, so turning the feature on does not announce everyone already
/// live.
List<StreamTwitch> newlyLive({
  required Set<String>? wasLive,
  required List<StreamTwitch> live,
  Set<String> muted = const {},
  Map<String, String> announced = const {},
}) {
  if (wasLive == null) return const [];
  return [
    for (final stream in live)
      if (!wasLive.contains(stream.userId) &&
          !muted.contains(stream.userId) &&
          (stream.startedAt.isEmpty ||
              announced[stream.userId] != stream.startedAt))
        stream,
  ];
}

/// A notice for someone who went live.
typedef GoLiveNotice = ({
  String userId,
  String login,
  String title,
  String body,
  String startedAt,
});

GoLiveNotice goLiveNotice(StreamTwitch stream) => (
  userId: stream.userId,
  login: stream.userLogin,
  startedAt: stream.startedAt,
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

/// A check this soon after another (the app's or the background one) is
/// skipped: the other just did the work.
const kGoLiveMinGap = Duration(seconds: 60);

/// How long a broadcast is remembered as announced.
const _announcedFor = Duration(hours: 24);

/// One check: reads the viewer's live followed channels, announces the
/// ones that just went live through [notify], then remembers who is live.
/// Returns how many were announced. Throws when Twitch cannot be read or
/// [notify] fails (the last state is kept, so nothing is lost; a channel
/// announced twice replaces its own notice). Skipped (0) when a check
/// started less than [minGap] ago.
Future<int> checkGoLive({
  required TwitchApi api,
  required GoLivePrefs prefs,
  required Future<void> Function(List<GoLiveNotice> notices, int more) notify,
  Duration? minGap,
  DateTime Function() now = DateTime.now,
}) async {
  final userId = prefs.userId;
  if (!prefs.enabled || userId == null) return 0;
  final startedAt = now();
  if (minGap != null && prefs.checkedWithin(minGap, startedAt)) return 0;
  // Claimed before reading Twitch, so a check starting meanwhile skips.
  await prefs.setCheckedAt(startedAt);
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
  final announced = prefs.announced;
  final fresh = newlyLive(
    wasLive: prefs.seen,
    live: live,
    muted: prefs.muted,
    announced: announced,
  );
  if (fresh.isNotEmpty) {
    final shown = fresh.take(kMaxGoLiveNotices).map(goLiveNotice).toList();
    await notify(shown, fresh.length - shown.length);
  }
  await prefs.setSeen({for (final stream in live) stream.userId});
  final since = startedAt.subtract(_announcedFor);
  await prefs.setAnnounced({
    for (final MapEntry(:key, :value) in announced.entries)
      if (DateTime.tryParse(value)?.isAfter(since) ?? false) key: value,
    for (final stream in fresh)
      if (stream.startedAt.isNotEmpty) stream.userId: stream.startedAt,
  });
  return fresh.length;
}

/// The app's own check, while it is alive (`GoLivePoller`): the same
/// state and dedupe as the background one, read afresh since that one may
/// have run meanwhile. Skipped when logged out or right after another
/// check.
Future<int> checkGoLiveInApp({
  required TwitchApi api,
  required GoLivePrefs prefs,
  required bool loggedIn,
  required Future<void> Function(List<GoLiveNotice> notices, int more) notify,
  DateTime Function() now = DateTime.now,
}) async {
  if (!loggedIn) return 0;
  await prefs.reload();
  return checkGoLive(
    api: api,
    prefs: prefs,
    notify: notify,
    minGap: kGoLiveMinGap,
    now: now,
  );
}

/// The problem kept when Twitch refuses the token.
const kGoLiveLoggedOut = 'Log in again to get go-live notifications.';

/// One background run. True when done (or nothing to do), false to ask
/// the system to retry later. A refused token pauses the notices until the
/// next log in and says so once.
Future<bool> runGoLiveTask({
  required Future<String?> Function() readToken,
  required TwitchApi Function(String token) buildApi,
  required GoLivePrefs prefs,
  required Future<void> Function(List<GoLiveNotice> notices, int more) notify,
  required Future<void> Function(String message) notifyProblem,
  required void Function(Object error, StackTrace stack) report,
  DateTime Function() now = DateTime.now,
}) async {
  if (!prefs.enabled) return true;
  // The app checked a moment ago (it checks often while open).
  if (prefs.checkedWithin(kGoLiveMinGap, now())) return true;
  final token = await readToken();
  if (token == null) return true;
  try {
    await checkGoLive(
      api: buildApi(token),
      prefs: prefs,
      notify: notify,
      now: now,
    );
    await prefs.setProblem(null);
    return true;
  } on UnauthorizedException {
    if (prefs.problem != kGoLiveLoggedOut) {
      await prefs.setProblem(kGoLiveLoggedOut);
      await notifyProblem(kGoLiveLoggedOut);
    }
    return true;
  } catch (error, stack) {
    // A network hiccup is expected now and then; anything else is a bug
    // or a Twitch change.
    if (error is! NetworkException && error is! TimeoutException) {
      report(error, stack);
    }
    return false;
  }
}
