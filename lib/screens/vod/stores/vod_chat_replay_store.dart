import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:frosty/apis/twitch_vod_service.dart';
import 'package:frosty/models/badges.dart';
import 'package:frosty/models/emotes.dart';
import 'package:frosty/models/irc.dart';
import 'package:frosty/models/vod.dart';
import 'package:frosty/models/vod_comment.dart';
import 'package:frosty/screens/channel/chat/stores/chat_assets_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/vod/vod_comment_cache.dart';
import 'package:frosty/screens/vod/vod_comment_to_irc.dart';
import 'package:frosty/screens/vod/vod_replay_filters.dart';
import 'package:mobx/mobx.dart';

part 'vod_chat_replay_store.g.dart';

enum ReplayStatus {
  /// Waiting for the comments around the current position.
  loading,

  /// Replaying.
  active,

  /// Twitch refused the comments (integrity check) or kept failing.
  unavailable,

  /// The video has no chat (uploads).
  notApplicable,
}

class VodChatReplayStore = VodChatReplayStoreBase with _$VodChatReplayStore;

/// Replays a VOD's chat in step with playback: comments are fetched by offset
/// a little ahead of the position, cached per second, and shown as the same
/// [IRCMessage]s live chat renders (badges, Twitch/7TV/BTTV/FFZ emotes,
/// colours, mentions). There is no IRC connection and nothing can be sent.
abstract class VodChatReplayStoreBase with Store {
  VodChatReplayStoreBase({
    required this.vod,
    required this.vodService,
    required this.assetsStore,
    required this.settings,
    required Map<String, String> headers,
    this.viewerLogin,
    List<String> Function()? blockedLogins,
    @visibleForTesting
    List<Duration> backoff = const [Duration(seconds: 1), Duration(seconds: 2)],
    @visibleForTesting
    Duration seekDebounce = const Duration(milliseconds: 250),
    @visibleForTesting Duration minFetchGap = const Duration(milliseconds: 300),
  }) : _blockedLogins = blockedLogins ?? (() => const []),
       _backoff = backoff,
       _seekDebounce = seekDebounce,
       _minFetchGap = minFetchGap {
    if (vod.type == VodType.upload) {
      _status = ReplayStatus.notApplicable;
      _assetsReady = Future.value();
      return;
    }
    _assetsReady = _loadAssets(headers);
    scrollController.addListener(_onScroll);
  }

  final Vod vod;
  final TwitchVodService vodService;

  /// Owned by this store: initialised here and disposed with it.
  final ChatAssetsStore assetsStore;
  final SettingsStore settings;

  /// Lower-case login of the signed-in viewer, for mention highlights.
  final String? viewerLogin;

  final List<String> Function() _blockedLogins;
  final List<Duration> _backoff;

  /// Seeks closer together than this (scrubbing) wait before fetching.
  final Duration _seekDebounce;

  /// Pause after a page that advanced replay by two seconds or less (a busy
  /// chat), so catching up does not burst requests.
  final Duration _minFetchGap;

  /// Same cap and purge size as live chat keeps on screen per batch.
  static const _messageLimit = 300;
  static const _messagesToRemove = 60;

  /// How many comments a seek shows from before the new position.
  static const _seekBacklog = 50;

  /// Seconds of comments kept ahead of playback at 1x.
  static const _leadSeconds = 15;

  /// A jump larger than this, or back by more than [_maxBackwardJitter], is
  /// a seek, not playback.
  static const _maxForwardStep = 3;
  static const _maxBackwardJitter = 1;

  /// Failures in a row before replay gives up until [retry].
  static const _maxFailures = 3;

  final _cache = VodCommentCache();
  final _shownKeys = <String>{};

  final scrollController = ScrollController();

  late final Future<void> _assetsReady;
  var _assetsInitialised = false;
  var _disposed = false;

  int? _lastSecond;
  int? _lastEvictSecond;

  /// The comments around a seek target are not shown yet.
  var _needsFill = false;

  /// Bumped by each seek so a page that lands late is cached, not shown.
  var _fetchGeneration = 0;
  int? _inFlight;
  Timer? _retryTimer;

  /// Defers a fetch until [_notBefore] (seek debounce, busy-chat spacing).
  Timer? _fetchTimer;
  DateTime? _notBefore;
  DateTime? _lastSeekAt;
  var _failures = 0;
  var _integrityBlocked = false;

  @readonly
  var _status = ReplayStatus.loading;

  final messages = ObservableList<IRCMessage>();

  @readonly
  var _autoScroll = true;

  /// Current playback rate; the prefetch lead scales with it.
  double playbackRate = 1.0;

  bool get _stopped =>
      _status == ReplayStatus.unavailable ||
      _status == ReplayStatus.notApplicable;

  // --- Assets ---------------------------------------------------------------

  Future<void> _loadAssets(Map<String, String> headers) async {
    try {
      await assetsStore.init();
      _assetsInitialised = true;
    } catch (e) {
      debugPrint('VodChatReplayStore assets init failed: $e');
      return;
    }
    if (_disposed) return;
    try {
      await assetsStore.assetsFuture(
        channelId: vod.ownerId,
        headers: headers,
        onEmoteError: _onEmoteError,
        onBadgeError: _onBadgeError,
        showTwitchEmotes: settings.showTwitchEmotes,
        showTwitchBadges: settings.showTwitchBadges,
        show7TVEmotes: settings.show7TVEmotes,
        showBTTVEmotes: settings.showBTTVEmotes,
        showBTTVBadges: settings.showBTTVBadges,
        showFFZEmotes: settings.showFFZEmotes,
        showFFZBadges: settings.showFFZBadges,
      );
    } catch (e) {
      debugPrint('VodChatReplayStore assets failed: $e');
    }
  }

  static List<Emote> _onEmoteError(dynamic error) {
    debugPrint(error.toString());
    return <Emote>[];
  }

  static List<ChatBadge> _onBadgeError(dynamic error) {
    debugPrint(error.toString());
    return <ChatBadge>[];
  }

  // --- Playback -------------------------------------------------------------

  /// Called with the playback position each time its whole second changes.
  @action
  void onPositionSecond(int second) {
    if (_disposed) return;
    final s = second < 0 ? 0 : second;
    final last = _lastSecond;
    _lastSecond = s;
    if (_stopped) return;
    if (last == null ||
        s - last > _maxForwardStep ||
        last - s > _maxBackwardJitter) {
      _seek(s);
    } else if (s > last) {
      if (_needsFill) {
        _fillIfCovered(s);
      } else {
        _show(_cache.commentsIn(last, s));
      }
      if (s - (_lastEvictSecond ?? s) > 300) _evict(s);
    }
    _maybeFetch(s);
  }

  void _seek(int s) {
    messages.clear();
    _shownKeys.clear();
    _fetchGeneration++;
    _inFlight = null;
    _retryTimer?.cancel();
    _fetchTimer?.cancel();
    final now = DateTime.now();
    final lastSeek = _lastSeekAt;
    _lastSeekAt = now;
    // Scrubbing: wait for the position to settle before asking Twitch.
    if (lastSeek != null &&
        now.difference(lastSeek) < const Duration(seconds: 1)) {
      _notBefore = now.add(_seekDebounce);
    } else {
      _notBefore = null;
    }
    _evict(s);
    _needsFill = true;
    if (!_fillIfCovered(s)) _status = ReplayStatus.loading;
  }

  /// Shows the comments leading up to [s] once its stretch is cached (or the
  /// position is past a finished video's end, where there is nothing to
  /// wait for).
  bool _fillIfCovered(int s) {
    final pastEnd = !vod.isRecording && s >= vod.lengthSeconds;
    if (!pastEnd && !_cache.isCovered(s)) return false;
    messages.clear();
    _shownKeys.clear();
    _needsFill = false;
    final upTo = pastEnd ? vod.lengthSeconds : s;
    _show(_cache.lastN(upTo, _seekBacklog));
    _status = ReplayStatus.active;
    return true;
  }

  /// Fills after a seek from the page fetched at [second] when playback
  /// already moved past what it covers (a busy chat on a slow network):
  /// its stretch, then whatever is cached up to [s]. Waiting for [s] itself
  /// to be covered could never catch up.
  void _fillFromPage(int second, int s) {
    final coveredEnd = _cache.firstUncoveredFrom(second) - 1;
    final upTo = coveredEnd < s ? coveredEnd : s;
    messages.clear();
    _shownKeys.clear();
    _needsFill = false;
    _show(_cache.lastN(upTo, _seekBacklog));
    _show(_cache.commentsIn(upTo, s));
    _status = ReplayStatus.active;
  }

  void _evict(int s) {
    _lastEvictSecond = s;
    _cache.evictFarFrom(s);
  }

  /// Makes another attempt after replay became unavailable through repeated
  /// failures. An integrity refusal is final.
  @action
  void retry() {
    if (_disposed || _integrityBlocked) return;
    if (_status != ReplayStatus.unavailable) return;
    _failures = 0;
    _status = ReplayStatus.loading;
    final s = _lastSecond;
    if (s == null) return;
    _seek(s);
    _maybeFetch(s);
  }

  /// Re-enables auto-scroll and jumps to the newest message.
  @action
  void resumeScroll() {
    _autoScroll = true;
    if (!scrollController.hasClients) return;
    scrollController.jumpTo(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) scrollController.jumpTo(0);
    });
  }

  void _onScroll() {
    // The list is reversed: offset 0 is the newest message.
    final atBottom = scrollController.position.pixels <= 0;
    if (atBottom != _autoScroll) runInAction(() => _autoScroll = atBottom);
  }

  // --- Fetching ---------------------------------------------------------------

  void _maybeFetch(int s) {
    if (_disposed || _stopped || _inFlight != null) return;
    if ((_retryTimer?.isActive ?? false) || (_fetchTimer?.isActive ?? false)) {
      return;
    }
    // Past a finished video's end, its last comments are what to show.
    final from = !vod.isRecording && s >= vod.lengthSeconds
        ? (vod.lengthSeconds - _leadSeconds).clamp(0, vod.lengthSeconds)
        : s;
    final target = _cache.firstUncoveredFrom(from);
    // Twitch answers an offset past the end with an error, and a recording
    // has nothing beyond the playback position yet.
    if (vod.isRecording ? target > s : target >= vod.lengthSeconds) return;
    if (target - from > (_leadSeconds * playbackRate).ceil()) return;
    final wait = _notBefore?.difference(DateTime.now());
    if (wait != null && wait > Duration.zero) {
      _fetchTimer = Timer(wait, () {
        final now = _lastSecond;
        if (now != null) runInAction(() => _maybeFetch(now));
      });
      return;
    }
    _notBefore = null;
    unawaited(_fetch(target));
  }

  /// End of coverage for a page with nothing after it. A recording keeps
  /// growing, so its last page only vouches for a short window.
  int _coverEnd(int requested) => vod.isRecording
      ? (vod.lengthSeconds > requested + 30
            ? vod.lengthSeconds
            : requested + 30)
      : vod.lengthSeconds;

  Future<void> _fetch(int second) async {
    final generation = _fetchGeneration;
    _inFlight = second;
    final VodCommentPage page;
    try {
      page = await vodService.getComments(vodId: vod.id, offsetSeconds: second);
    } catch (e) {
      if (_disposed || generation != _fetchGeneration) return;
      _onFetchError(e);
      return;
    }
    if (_disposed) return;
    // Cached even when stale: a seek back will find it.
    _cache.addPage(
      requestedSecond: second,
      page: page,
      videoLengthSeconds: _coverEnd(second),
    );
    if (generation != _fetchGeneration) return;
    _inFlight = null;
    _failures = 0;
    if (_cache.firstUncoveredFrom(second) - second <= 2) {
      _notBefore = DateTime.now().add(_minFetchGap);
    }
    runInAction(() {
      if (_stopped) return;
      final s = _lastSecond;
      if (s == null) return;
      if (_needsFill) {
        if (!_fillIfCovered(s) && second <= s) _fillFromPage(second, s);
      } else {
        _status = ReplayStatus.active;
        if (s >= second) _show(_cache.commentsIn(second - 1, s));
      }
    });
    final s = _lastSecond;
    if (s != null) runInAction(() => _maybeFetch(s));
  }

  void _onFetchError(Object error) {
    _inFlight = null;
    debugPrint('VodChatReplayStore comments failed: $error');
    if (error is VodApiException && error.isIntegrity) {
      _integrityBlocked = true;
      runInAction(() => _status = ReplayStatus.unavailable);
      return;
    }
    _failures++;
    if (_failures >= _maxFailures) {
      runInAction(() => _status = ReplayStatus.unavailable);
      return;
    }
    final delay = _backoff[(_failures - 1).clamp(0, _backoff.length - 1)];
    _retryTimer = Timer(delay, () {
      final s = _lastSecond;
      if (s != null) runInAction(() => _maybeFetch(s));
    });
  }

  // --- Showing ----------------------------------------------------------------

  void _show(List<VodComment> comments) {
    if (comments.isEmpty) return;
    final blocked = _blockedLogins();
    for (final comment in comments) {
      if (!_shownKeys.add(comment.key)) continue;
      final message = vodCommentToIrcMessage(
        comment,
        channelId: vod.ownerId,
        channelLogin: vod.ownerLogin,
        vodCreatedAt: vod.createdAt,
        viewerLogin: viewerLogin,
      );
      if (isReplayCommentHidden(
        message,
        blockedLogins: blocked,
        mutedWords: settings.mutedWords,
        matchWholeWord: settings.matchWholeWord,
        channelLogin: vod.ownerLogin,
        viewerLogin: viewerLogin,
      )) {
        continue;
      }
      if (messages.length >= _messageLimit) {
        messages.removeRange(0, _messagesToRemove);
      }
      messages.add(message);
    }
    // Only recent keys matter for de-duplication (pages overlap by seconds).
    while (_shownKeys.length > _messageLimit * 4) {
      _shownKeys.remove(_shownKeys.first);
    }
  }

  void dispose() {
    _disposed = true;
    _fetchGeneration++;
    _retryTimer?.cancel();
    _fetchTimer?.cancel();
    scrollController.dispose();
    unawaited(
      _assetsReady.then((_) {
        if (_assetsInitialised) assetsStore.dispose();
      }),
    );
  }
}
