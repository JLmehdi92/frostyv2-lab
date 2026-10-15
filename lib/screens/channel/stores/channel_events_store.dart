import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:frosty/apis/twitch_points_service.dart';
import 'package:frosty/models/celebration.dart';
import 'package:frosty/models/community_points.dart';
import 'package:frosty/models/hermes.dart';
import 'package:frosty/services/hermes_client.dart';
import 'package:mobx/mobx.dart';

part 'channel_events_store.g.dart';

/// Names for the three point-spending actions.
///
/// Top level rather than static members: the MobX class alias
/// `ChannelEventsStore = ChannelEventsStoreBase with ...` does not carry
/// statics across, so a widget referring to them through the alias would not
/// compile.
const claimAction = 'claim';
const redeemAction = 'redeem';
const predictAction = 'predict';

/// Owns the real-time connection for the channel being watched.
///
/// One Hermes socket carries the channel features — celebrations, creator
/// goals, channel points — so this store is the single
/// place that knows about it. It is deliberately additive: if Hermes is
/// unreachable, every field stays null and the channel screen looks exactly as
/// it did before.
class ChannelEventsStore = ChannelEventsStoreBase with _$ChannelEventsStore;

abstract class ChannelEventsStoreBase with Store {
  final String channelId;

  final HermesClient _client;
  StreamSubscription<HermesEvent>? _subscription;

  /// Celebrations already played, so a replayed or duplicated event does not
  /// fire the same animation twice.
  final _playedCelebrations = <String>{};
  static const _maxRememberedCelebrations = 50;

  /// The channel's login, needed by GQL, which addresses channels by name.
  final String? channelLogin;

  /// The signed-in viewer, when there is one.
  ///
  /// Needed because the things that happen to *them* — the bonus chest above
  /// all — arrive on user-scoped topics, not on the channel's.
  final String? viewerId;

  final TwitchPointsService _pointsService;
  final Future<String?> Function()? _tokenProvider;

  ChannelEventsStoreBase({
    required this.channelId,
    this.channelLogin,
    this.viewerId,
    HermesClient? client,
    TwitchPointsService? pointsService,
    Future<String?> Function()? tokenProvider,
  }) : _client = client ?? HermesClient(tokenProvider: tokenProvider),
       _pointsService = pointsService ?? TwitchPointsService(Dio()),
       _tokenProvider = tokenProvider;

  /// Channel points, rewards and any running prediction.
  ///
  /// Fetched once over GQL, then kept current by the `community-points-*`
  /// topics: Twitch sends the balance only in updates, never in the real-time
  /// stream on its own, so a first read is unavoidable.
  @readonly
  CommunityPointsContext _points = CommunityPointsContext.empty;

  /// The celebration waiting to be played. The overlay clears it when done.
  @readonly
  Celebration? _celebration;

  /// The creator goal being tracked, kept raw: it is displayed as-is and has
  /// no behaviour of its own.
  @readonly
  Map<String, dynamic>? _creatorGoal;

  /// Starts listening. Safe to call more than once.
  Future<void> connect() async {
    if (_subscription != null) return;

    _subscription = _client.events.listen(
      _onEvent,
      onError: (Object error) => debugPrint('Channel events error: $error'),
    );

    final viewer = viewerId;
    await _client.subscribeAll([
      ...HermesTopics.forChannel(channelId),
      if (viewer != null) ...HermesTopics.forViewer(viewer),
    ]);

    // Not awaited: the balance appearing a moment later is fine, a channel
    // opening a moment later is not.
    unawaited(refreshPoints());

    _startPointsPolling();
  }

  Timer? _pointsPollTimer;

  /// Twitch offers the bonus chest for a couple of minutes at a time.
  ///
  /// A poll rather than a subscription, on purpose: the chest arrives on a
  /// user-scoped topic whose payload has never been captured, and a feature
  /// built on an unverified shape is how the hype train bar nearly shipped
  /// stuck at zero. The topic *is* subscribed as well, so its real payloads get
  /// logged — once one has been read, this can go.
  ///
  /// One request a minute against an endpoint the app already calls on every
  /// points event.
  void _startPointsPolling() {
    if (channelLogin == null) return;

    _pointsPollTimer?.cancel();
    _pointsPollTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => unawaited(_pollPoints()),
    );
  }

  /// A signed-out viewer has no balance nor chest: polling would only spend
  /// requests.
  Future<void> _pollPoints() async {
    final token = await _tokenProvider?.call();
    if (token == null || token.isEmpty) return;
    await refreshPoints();
  }

  /// The app went to the background: no socket nor poll while nobody looks.
  void pause() {
    _pointsPollTimer?.cancel();
    _pointsPollTimer = null;
    _pointsRefreshTimer?.cancel();
    _client.pause();
  }

  /// Back in front: reconnect, catch up on the balance, poll again.
  Future<void> resume() async {
    if (_subscription == null) return;
    await _client.resume();
    unawaited(refreshPoints());
    _startPointsPolling();
  }

  /// Reads the balance, the rewards and any prediction.
  ///
  /// Safe to call again — used both on open and after a points event, since
  /// Twitch's real-time updates carry the new balance but not the reward list.
  @action
  Future<void> refreshPoints() async {
    final login = channelLogin;
    if (login == null) return;

    final context = await _pointsService.fetchContext(
      userLogin: login,
      authToken: await _tokenProvider?.call(),
    );

    debugPrint(
      'Points for $login: balance=${context.balance} '
      'rewards=${context.rewards.length} '
      'predictions=${context.predictions.length} '
      'claim=${context.availableClaimId} '
      'name=${context.pointsName}',
    );

    runInAction(() => _points = context);
  }

  /// True while a redeem or a bet is in flight, so the sheet can disable its
  /// controls instead of letting a double tap spend twice.
  @readonly
  bool _pointsActionInFlight = false;

  /// Spends points on [reward].
  ///
  /// Returns the outcome rather than swallowing it: the caller shows it. A
  /// refusal here is information — especially the integrity one, which is the
  /// server saying no on purpose and will not change on a retry.
  @action
  Future<PointsActionResult> redeemReward(
    PointsReward reward, {
    String? userInput,
  }) => _runPointsAction(
    (token) => _pointsService.redeemReward(
      channelId: channelId,
      reward: reward,
      authToken: token,
      userInput: userInput,
    ),
    what: redeemAction,
  );

  /// Collects the bonus chest.
  ///
  /// **Twitch refuses this.** Measured on 2026-07-31 with the viewer's real
  /// token on a live chest: `failed integrity check`, every time. The question
  /// was open until then — the earlier measurement had not recorded whether it
  /// carried a real credential — and it is now closed.
  ///
  /// The call is kept rather than deleted: it is what produced the answer, it
  /// will report a different one if Twitch ever changes, and the UI uses the
  /// refusal to stop offering the action instead of hiding the whole feature.
  @action
  Future<PointsActionResult> claimBonus() {
    final claimId = _points.availableClaimId;
    if (claimId == null) {
      return Future.value(
        const PointsActionResult(PointsActionStatus.unknown, 'no_claim'),
      );
    }

    return _runPointsAction(
      (token) => _pointsService.claimBonus(
        channelId: channelId,
        claimId: claimId,
        authToken: token,
      ),
      what: claimAction,
    );
  }

  /// Backs [outcomeId] with [points].
  @action
  Future<PointsActionResult> placePrediction({
    required String eventId,
    required String outcomeId,
    required int points,
  }) => _runPointsAction(
    (token) => _pointsService.makePrediction(
      eventId: eventId,
      outcomeId: outcomeId,
      points: points,
      authToken: token,
    ),
    what: predictAction,
  );

  /// Shared plumbing for the write mutations: guard, token, classify, refresh.
  ///
  /// The in-flight flag is raised before the first `await`: reading the token
  /// yields, and a second tap landing in that gap would otherwise pass the
  /// guard too and reach Twitch with a fresh transaction id — charged twice.
  /// It is cleared in a `finally` so a thrown request cannot leave the sheet's
  /// controls disabled for the rest of the session.
  Future<PointsActionResult> _runPointsAction(
    Future<String?> Function(String token) send, {
    required String what,
  }) async {
    if (_pointsActionInFlight) {
      return const PointsActionResult(PointsActionStatus.unknown, 'busy');
    }

    runInAction(() => _pointsActionInFlight = true);
    try {
      final token = await _tokenProvider?.call();
      if (token == null || token.isEmpty) {
        // Caught here rather than sent: an empty Authorization header would
        // come back as a generic error, hiding the fact that the fix is to
        // sign in.
        return const PointsActionResult(
          PointsActionStatus.notAuthenticated,
          'no_token',
        );
      }

      final result = PointsActionResult.fromError(await send(token));

      // Only on success: a refused action changed nothing server-side, and a
      // refetch would just spend a request to confirm the balance is the same.
      if (result.isSuccess) await refreshPoints();

      // An integrity refusal is not a transient failure — it is Twitch saying
      // no to this client. Remembering it stops the control from inviting a
      // retry that cannot work: measured on 2026-07-31, eight taps in twelve
      // seconds all came back refused.
      if (result.status == PointsActionStatus.integrityRefused) {
        runInAction(() => _integrityBlocked.add(what));
      }

      debugPrint(
        'Points action [$what]: ${result.status.name} (${result.rawCode})',
      );
      return result;
    } finally {
      runInAction(() => _pointsActionInFlight = false);
    }
  }

  /// Actions Twitch has refused on integrity grounds this session.
  final _integrityBlocked = ObservableSet<String>();

  /// Whether [action] has already been refused, so the UI can stop offering it.
  bool isIntegrityBlocked(String action) => _integrityBlocked.contains(action);


  void _onEvent(HermesEvent event) {
    // A payload of an unexpected shape costs that event, never the
    // subscription: an exception escaping a stream listener is uncaught.
    try {
      _routeEvent(event);
    } catch (e) {
      debugPrint('Channel event dropped (${e.runtimeType})');
    }
  }

  void _routeEvent(HermesEvent event) {
    // Topics are suffixed with the id they concern, so a stale subscription
    // from a previous channel can never drive this one. The viewer's own
    // topics end with *their* id, not the channel's — filtering on the channel
    // alone would have dropped every one of them, including the chest.
    final viewer = viewerId;
    final isMine = viewer != null && event.topic.endsWith('.$viewer');
    if (!event.topic.endsWith('.$channelId') && !isMine) return;

    if (event.topic.startsWith('celebration-events')) {
      _applyCelebration(event);
    } else if (event.topic.startsWith('creator-goals-events')) {
      _applyGoal(event);
    } else if (event.topic.startsWith('community-points') ||
        event.topic.startsWith('predictions-')) {
      // The payloads differ per event and Twitch does not resend the reward
      // list, so a refetch is both simpler and more correct than trying to
      // patch the local copy from a partial update.
      _schedulePointsRefresh();
    } else {
      _capture(event);
    }
  }

  /// Prints the payload of a topic nothing consumes yet.
  ///
  /// Several topics are already subscribed — `leaderboard-events-v1` and
  /// `pinned-chat-updates-v1` among them — and their notifications were being
  /// dropped on the floor here, which is why no payload for them has ever been
  /// seen. Writing an interface for a shape nobody has observed is how the
  /// hype train bar nearly shipped stuck at zero, so these get logged and
  /// nothing more until a real one has been read.
  ///
  /// Runs in release too, deliberately. This is a personal build, the print
  /// only fires on a topic nothing consumes — which is rare — and it is the
  /// only route to payloads that have never been seen. Gating it on debug
  /// builds meant the one build actually used day to day captured nothing.
  void _capture(HermesEvent event) {
    // Payloads can carry other viewers' names and messages: never in a
    // release build.
    if (!kDebugMode) return;
    // One line, on purpose: logcat splits a multi-line print into separate
    // records, which would leave a grep for the topic matching a line that no
    // longer carries the payload. This survives `adb logcat | grep`.
    debugPrint(
      'ONSET_CAPTURE topic=${event.topic} type=${event.type} '
      'data=${jsonEncode(event.data)}',
    );
  }

  Timer? _pointsRefreshTimer;

  /// Coalesces bursts: a busy channel can emit several points events a second,
  /// and each one must not become its own request.
  void _schedulePointsRefresh() {
    _pointsRefreshTimer?.cancel();
    _pointsRefreshTimer = Timer(
      const Duration(seconds: 2),
      () => unawaited(refreshPoints()),
    );
  }

  @action
  void _applyCelebration(HermesEvent event) {
    if (event.type != 'alert_sets_celebration') return;

    final celebration = Celebration.tryParse(event.data);
    if (celebration == null) return;

    final id = celebration.eventId;
    if (id != null) {
      if (_playedCelebrations.contains(id)) return;

      if (_playedCelebrations.length >= _maxRememberedCelebrations) {
        _playedCelebrations.remove(_playedCelebrations.first);
      }
      _playedCelebrations.add(id);
    }

    _celebration = celebration;
  }

  @action
  void _applyGoal(HermesEvent event) {
    final goal = event.data['goal'];
    if (goal is Map<String, dynamic>) _creatorGoal = goal;
  }

  /// Called by the overlay once an animation has finished.
  @action
  void clearCelebration() => _celebration = null;

  /// Which effect the next preview will show.
  var _previewIndex = 0;

  /// Plays a celebration on demand, cycling through the effects.
  ///
  /// Real celebrations only fire when someone actually gifts a sub, which
  /// makes the animation impossible to review — or to tune — without waiting
  /// on someone else's money. This walks through every effect one long-press
  /// at a time.
  ///
  /// Deliberately not de-duplicated: it carries no event id, so it can be
  /// replayed as often as needed.
  @action
  void playPreviewCelebration() {
    const effects = [
      CelebrationEffect.fireworks,
      CelebrationEffect.extinctionEvent,
      CelebrationEffect.flamethrower,
      CelebrationEffect.rain,
      CelebrationEffect.float,
    ];
    const intensities = [
      CelebrationIntensity.cool,
      CelebrationIntensity.noice,
      CelebrationIntensity.omegaPog,
    ];

    final effect = effects[_previewIndex % effects.length];
    // Intensity advances more slowly, so each effect is seen at several sizes
    // rather than always at the same one.
    final intensity = intensities[(_previewIndex ~/ effects.length) %
        intensities.length];
    _previewIndex++;

    debugPrint('Celebration preview: ${effect.name} at ${intensity.name}');

    _celebration = Celebration(
      effect: effect,
      area: CelebrationArea.everywhere,
      intensity: intensity,
      duration: const Duration(seconds: 4),
    );
  }

  void dispose() {
    _pointsRefreshTimer?.cancel();
    _pointsPollTimer?.cancel();
    unawaited(_subscription?.cancel());
    _subscription = null;
    _client.dispose();
  }
}
