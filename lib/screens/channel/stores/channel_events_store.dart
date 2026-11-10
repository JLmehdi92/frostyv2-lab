import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/apis/twitch_community_service.dart';
import 'package:onset/apis/twitch_points_service.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/apis/twitch_watch_streak_service.dart';
import 'package:onset/models/celebration.dart';
import 'package:onset/models/channel_leaderboards.dart';
import 'package:onset/models/community_goal.dart';
import 'package:onset/models/community_points.dart';
import 'package:onset/models/creator_goal.dart';
import 'package:onset/models/drop_campaign.dart';
import 'package:onset/models/hermes.dart';
import 'package:onset/models/legendary_collection.dart';
import 'package:onset/models/private_callout.dart';
import 'package:onset/models/resub_notification.dart';
import 'package:onset/models/stream_push.dart';
import 'package:onset/models/unlockable_emote.dart';
import 'package:onset/models/watch_streak.dart';
import 'package:onset/models/weekly_rewards.dart';
import 'package:onset/screens/channel/chat/mod_tools/mod_events.dart';
import 'package:onset/services/hermes_client.dart';

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

  /// The channel's display name, for the panel's wording.
  final String? channelName;

  /// Whether the channel is live now (it changes how a suspended watch
  /// streak is saved); unknown counts as live.
  final bool Function()? isChannelLive;

  final TwitchPointsService _pointsService;
  final Future<String?> Function()? _tokenProvider;

  /// The viewer's watch streak here; none read without it.
  final TwitchWatchStreakService? _watchStreakService;

  final TwitchViewerActionsService? _viewerActionsService;

  @readonly
  var _sharingWatchStreak = false;

  @computed
  bool get canShareWatchStreak {
    final streak = _watchStreak;
    return _viewerActionsService != null &&
        streak != null &&
        streak.canShare &&
        streak.milestoneId != null;
  }

  @action
  Future<ViewerActionOutcome?> shareWatchStreak() async {
    final service = _viewerActionsService;
    final streak = _watchStreak;
    final milestoneId = streak?.milestoneId;
    if (_sharingWatchStreak ||
        service == null ||
        streak == null ||
        milestoneId == null ||
        !canShareWatchStreak) {
      return null;
    }
    _sharingWatchStreak = true;
    try {
      final token = await _tokenProvider?.call();
      if (token == null || token.isEmpty) return ViewerActionOutcome.signedOut;
      final outcome = await service.shareWatchStreak(
        channelId: channelId,
        milestoneId: milestoneId,
        authToken: token,
      );
      if (outcome == ViewerActionOutcome.done) {
        runInAction(() => _watchStreak = streak.shared());
      }
      return outcome;
    } finally {
      runInAction(() => _sharingWatchStreak = false);
    }
  }

  final TwitchCommunityService? _communityService;

  final _watchStreakChanges = StreamController<WatchStreakChange>.broadcast();

  Stream<WatchStreakChange> get watchStreakChanges =>
      _watchStreakChanges.stream;

  @readonly
  ResubNotification? _resubNotification;

  @readonly
  var _sharingResub = false;

  final _sharedResubTokens = <String>{};

  @computed
  bool get canShareResub =>
      _viewerActionsService != null &&
      _resubNotification != null &&
      channelLogin != null;

  Future<void> _refreshResub(String token) async {
    final service = _communityService;
    if (service == null) return;
    final resub = await service.getResubNotification(
      channelId: channelId,
      authToken: token,
    );
    runInAction(
      () => _resubNotification =
          resub == null || _sharedResubTokens.contains(resub.tokenId)
          ? null
          : resub,
    );
  }

  bool get hasCommunityGoals => _communityService != null;

  Future<List<CommunityGoal>?> loadCommunityGoals() async {
    final service = _communityService;
    if (service == null) return null;
    return service.getCommunityGoals(
      channelId: channelId,
      authToken: await _tokenProvider?.call(),
    );
  }

  Future<GoalContributionResult> contributeToGoal(
    CommunityGoal goal,
    int amount,
  ) async {
    final service = _viewerActionsService;
    if (service == null) return GoalContributionResult.failed;
    final token = await _tokenProvider?.call();
    if (token == null || token.isEmpty) return GoalContributionResult.signedOut;
    final result = await service.contributeToGoal(
      channelId: channelId,
      goalId: goal.id,
      amount: amount,
      authToken: token,
    );
    if (result == GoalContributionResult.contributed) await refreshPoints();
    return result;
  }

  bool get hasLeaderboards => _communityService != null;

  @readonly
  List<DropCampaign> _dropCampaigns = const [];

  @readonly
  String? _claimingDropId;

  DateTime? _dropsAskedAt;

  static const _dropsFreshFor = Duration(minutes: 1);

  final _announcedDropCampaigns = <String>{};

  final _communityDrops = StreamController<DropCampaign>.broadcast();

  Stream<DropCampaign> get communityDrops => _communityDrops.stream;

  Future<void> refreshDrops({bool force = false}) async {
    final service = _communityService;
    if (service == null) return;
    final askedAt = _dropsAskedAt;
    if (!force &&
        askedAt != null &&
        clock.now().difference(askedAt) < _dropsFreshFor) {
      return;
    }
    _dropsAskedAt = clock.now();
    final campaigns = await service.getDropCampaigns(
      channelId: channelId,
      authToken: await _tokenProvider?.call(),
    );
    if (campaigns == null) {
      _dropsAskedAt = null;
      return;
    }
    runInAction(() => _dropCampaigns = campaigns);
    if (isChannelLive?.call() == false) return;
    for (final campaign in campaigns) {
      if (_announcedDropCampaigns.add(campaign.id) &&
          !_communityDrops.isClosed) {
        _communityDrops.add(campaign);
      }
    }
  }

  @action
  Future<DropClaimResult?> claimDrop(TimedDrop drop) async {
    final service = _viewerActionsService;
    final instance = drop.progress?.dropInstanceId;
    if (service == null || instance == null || _claimingDropId != null) {
      return null;
    }
    _claimingDropId = drop.id;
    try {
      final token = await _tokenProvider?.call();
      if (token == null || token.isEmpty) return DropClaimResult.signedOut;
      final result = await service.claimDrop(
        dropInstanceId: instance,
        authToken: token,
      );
      if (result.isClaimed) await refreshDrops(force: true);
      return result;
    } finally {
      runInAction(() => _claimingDropId = null);
    }
  }

  @readonly
  WeeklyRewards? _weeklyRewards;

  Future<void> refreshWeeklyRewards() async {
    final service = _communityService;
    if (service == null) return;
    final token = await _tokenProvider?.call();
    if (token == null || token.isEmpty) return;
    try {
      final rewards = await service.getWeeklyRewards(
        channelId: channelId,
        authToken: token,
      );
      runInAction(() => _weeklyRewards = rewards);
    } catch (e) {
      debugPrint('Weekly rewards unreadable (${e.runtimeType})');
    }
  }

  @readonly
  LegendaryCollection? _legendaryCollection;

  Future<void> refreshLegendaryCollection() async {
    final service = _communityService;
    if (service == null) return;
    try {
      final collection = await service.getLegendaryCollection(
        channelId: channelId,
        authToken: await _tokenProvider?.call(),
      );
      runInAction(() => _legendaryCollection = collection);
    } catch (e) {
      debugPrint('Hype chests unreadable (${e.runtimeType})');
    }
  }

  @readonly
  var _openingChests = false;

  bool get canOpenChests => _viewerActionsService != null;

  @action
  Future<ChestOpening?> openChests() async {
    final service = _viewerActionsService;
    final before = _legendaryCollection;
    if (service == null ||
        before == null ||
        before.unopenedChests == 0 ||
        _openingChests) {
      return null;
    }
    _openingChests = true;
    try {
      final token = await _tokenProvider?.call();
      if (token == null || token.isEmpty) {
        return const ChestOpening(ViewerActionOutcome.signedOut);
      }
      final outcome = await service.openChests(
        channelId: channelId,
        freeCount: before.freeChests,
        paidCount: before.paidChests,
        authToken: token,
      );
      if (outcome != ViewerActionOutcome.done) return ChestOpening(outcome);
      await refreshLegendaryCollection();
      final after = _legendaryCollection;
      return ChestOpening(
        outcome,
        revealed: after == null ? const [] : after.newlyOwnedSince(before),
      );
    } finally {
      runInAction(() => _openingChests = false);
    }
  }

  @readonly
  CommunityMoment? _moment;

  @readonly
  var _claimingMoment = false;

  final _communityMoments = StreamController<CommunityMoment>.broadcast();

  final _privateCallouts = StreamController<PrivateCallout>.broadcast();

  Stream<PrivateCallout> get privateCallouts => _privateCallouts.stream;

  final _shownCallouts = <String>{};

  void _applyPrivateCallout(HermesEvent event) {
    final callout = PrivateCallout.fromEvent(event.data);
    if (callout == null || !_shownCallouts.add(callout.id)) return;
    if (!_privateCallouts.isClosed) _privateCallouts.add(callout);
  }

  final _predictionWins = StreamController<PredictionWin>.broadcast();

  Stream<PredictionWin> get predictionWins => _predictionWins.stream;

  final _celebratedWins = <String>{};

  void _applyPredictionWin(HermesEvent event) {
    if (!event.topic.startsWith('predictions-user-v1.')) return;
    final win = PredictionWin.fromEvent(event.type, event.data);
    if (win == null || !_celebratedWins.add(win.eventId)) return;
    if (!_predictionWins.isClosed) _predictionWins.add(win);
  }

  Stream<CommunityMoment> get communityMoments => _communityMoments.stream;

  bool get canClaimMoments => _viewerActionsService != null;

  void _applyMoment(HermesEvent event) {
    if (viewerId == null) return;
    final moment = CommunityMoment.fromEvent(event.data);
    if (moment == null || moment.id == _moment?.id) return;
    runInAction(() => _moment = moment);
    if (!_communityMoments.isClosed) _communityMoments.add(moment);
  }

  @action
  Future<MomentClaimResult?> claimMoment() async {
    final service = _viewerActionsService;
    final moment = _moment;
    if (service == null || moment == null || _claimingMoment) return null;
    _claimingMoment = true;
    try {
      final token = await _tokenProvider?.call();
      if (token == null || token.isEmpty) return MomentClaimResult.signedOut;
      final result = await service.claimMoment(
        momentId: moment.id,
        authToken: token,
      );
      if (result.isClaimed || result == MomentClaimResult.expired) {
        runInAction(() => _moment = null);
      }
      return result;
    } finally {
      runInAction(() => _claimingMoment = false);
    }
  }

  bool get canUnlockEmotes => _communityService != null;

  Future<List<UnlockableEmote>?> loadUnlockableEmotes() async =>
      _communityService?.getUnlockableEmotes(channelId: channelId);

  @action
  Future<PointsActionResult> unlockChosenEmote(
    PointsReward reward,
    String emoteId,
  ) async {
    final result = await _runPointsAction(
      (token) => _pointsService.unlockChosenEmote(
        channelId: channelId,
        cost: reward.cost,
        emoteId: emoteId,
        modified: reward.automaticType == 'CHOSEN_MODIFIED_SUB_EMOTE_UNLOCK',
        authToken: token,
      ),
      what: redeemAction,
    );
    if (result.isSuccess) _sayEntitlementsChanged();
    return result;
  }

  Future<ChannelLeaderboards?> loadLeaderboards() async {
    final service = _communityService;
    if (service == null) return null;
    final token = await _tokenProvider?.call();
    return service.getLeaderboards(channelId: channelId, authToken: token);
  }

  @action
  Future<ViewerActionOutcome?> shareResub({String? message}) async {
    final service = _viewerActionsService;
    final resub = _resubNotification;
    final login = channelLogin;
    if (_sharingResub || service == null || resub == null || login == null) {
      return null;
    }
    _sharingResub = true;
    try {
      final token = await _tokenProvider?.call();
      if (token == null || token.isEmpty) return ViewerActionOutcome.signedOut;
      final outcome = await service.shareResub(
        channelLogin: login,
        tokenId: resub.tokenId,
        message: message,
        authToken: token,
      );
      if (outcome == ViewerActionOutcome.done) {
        _sharedResubTokens.add(resub.tokenId);
        runInAction(() => _resubNotification = null);
        await _refreshResub(token);
      }
      return outcome;
    } finally {
      runInAction(() => _sharingResub = false);
    }
  }

  ChannelEventsStoreBase({
    required this.channelId,
    this.channelLogin,
    this.channelName,
    this.viewerId,
    this.isChannelLive,
    HermesClient? client,
    TwitchPointsService? pointsService,
    TwitchWatchStreakService? watchStreakService,
    TwitchViewerActionsService? viewerActionsService,
    TwitchCommunityService? communityService,
    Future<String?> Function()? tokenProvider,
    Future<bool> Function(String channelId)? paidPromotionOf,
  }) : _paidPromotionOf = paidPromotionOf,
       _client = client ?? HermesClient(tokenProvider: tokenProvider),
       _pointsService = pointsService ?? TwitchPointsService.withDefaults(),
       _watchStreakService = watchStreakService,
       _viewerActionsService = viewerActionsService,
       _communityService = communityService,
       _tokenProvider = tokenProvider;

  /// Channel points, rewards and any running prediction.
  ///
  /// Fetched once over GQL, then kept current by the `community-points-*`
  /// topics: Twitch sends the balance only in updates, never in the real-time
  /// stream on its own, so a first read is unavoidable.
  @readonly
  CommunityPointsContext _points = CommunityPointsContext.empty;

  /// The viewer's watch streak in this channel, as Twitch counts it (shown
  /// in the points panel, like Twitch). Null when Twitch did not give one.
  @readonly
  WatchStreak? _watchStreak;

  /// When the streak was last asked for, and whether that failed.
  DateTime? _watchStreakAskedAt;
  var _watchStreakFailed = false;

  /// A streak moves at most once per stream: once a minute is plenty.
  static const _watchStreakFreshFor = Duration(minutes: 1);

  /// After a refusal or an error, not asked again for a while.
  static const _watchStreakBackoff = Duration(minutes: 10);

  final Future<bool> Function(String channelId)? _paidPromotionOf;

  @readonly
  List<String>? _contentLabels;

  @readonly
  var _paidPromotion = false;

  Future<void> _readPaidPromotion() async {
    final read = _paidPromotionOf;
    if (read == null) return;
    try {
      final disclosed = await read(channelId);
      runInAction(() => _paidPromotion = disclosed);
    } catch (e) {
      debugPrint('Paid promotion unavailable: ${e.runtimeType}');
    }
  }

  @action
  void _applyContentLabels(HermesEvent event) {
    final list = event.data['content_classification_labels'];
    if (list is! List) return;
    _contentLabels = [
      for (final label in list)
        if (label is Map &&
            label['label_id'] is String &&
            label['is_enabled'] != false)
          label['label_id'] as String,
    ];
  }

  @readonly
  int? _bitsBalance;

  @readonly
  var _giftedSinceJoining = 0;

  final _countedGifts = <String>{};

  @action
  void _applyBitsBalance(HermesEvent event) {
    final balance = event.data['balance'];
    if (balance is num && balance.isFinite && balance >= 0) {
      _bitsBalance = balance.toInt();
    }
  }

  @action
  void _applySubGifts(HermesEvent event) {
    final data = event.data;
    final count = data['count'];
    final uuid = data['uuid'];
    if (event.type != 'mystery-gift-purchase' ||
        data['channel_id'] != channelId ||
        count is! num ||
        !count.isFinite ||
        count <= 0 ||
        uuid is! String ||
        !_countedGifts.add(uuid)) {
      return;
    }
    _giftedSinceJoining += count.toInt();
  }

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
      if (viewer != null) ...HermesTopics.forViewerInChannel(viewer, channelId),
    ]);

    // Not awaited: the balance appearing a moment later is fine, a channel
    // opening a moment later is not.
    unawaited(refreshPoints());
    unawaited(refreshWatchStreak());
    unawaited(refreshDrops());
    unawaited(refreshWeeklyRewards());
    unawaited(refreshLegendaryCollection());
    unawaited(_readPaidPromotion());

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

    // Debug only: the login, balance and claim id are the viewer's own.
    if (kDebugMode) {
      debugPrint(
        'Points for $login: balance=${context.balance} '
        'rewards=${context.rewards.length} '
        'predictions=${context.predictions.length} '
        'claim=${context.availableClaimId} '
        'name=${context.pointsName}',
      );
    }

    runInAction(() => _points = context);
  }

  /// Reads the viewer's watch streak (on connect and when the panel opens),
  /// at most once a minute, and not for ten minutes after a failure. Never
  /// throws.
  Future<void> refreshWatchStreak() async {
    final service = _watchStreakService;
    if (service == null) return;
    final askedAt = _watchStreakAskedAt;
    if (askedAt != null &&
        clock.now().difference(askedAt) <
            (_watchStreakFailed ? _watchStreakBackoff : _watchStreakFreshFor)) {
      return;
    }
    // Marked before the first await: the panel opening while the channel
    // connects must not ask twice.
    _watchStreakAskedAt = clock.now();
    _watchStreakFailed = false;
    final token = await _tokenProvider?.call();
    if (token == null || token.isEmpty) {
      _watchStreakAskedAt = null;
      return;
    }
    unawaited(_refreshResub(token));
    final streak = await service.getWatchStreak(
      channelId: channelId,
      authToken: token,
    );
    _watchStreakFailed = streak == null;
    final change = watchStreakChange(_watchStreak, streak);
    runInAction(() => _watchStreak = streak);
    if (change != null && !_watchStreakChanges.isClosed) {
      _watchStreakChanges.add(change);
    }
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
  }) async {
    final result = await _runPointsAction(
      (token) => _pointsService.redeemReward(
        channelId: channelId,
        reward: reward,
        authToken: token,
        userInput: userInput,
      ),
      what: redeemAction,
    );
    if (result.status == PointsActionStatus.success &&
        unlocksEmotes(reward.automaticType)) {
      _sayEntitlementsChanged();
    }
    return result;
  }

  final _entitlementChanges = StreamController<void>.broadcast();

  final _shoutouts = StreamController<ShoutoutNotice>.broadcast();

  Stream<ShoutoutNotice> get shoutouts => _shoutouts.stream;

  final _streamPushes = StreamController<StreamPush>.broadcast();

  Stream<StreamPush> get streamPushes => _streamPushes.stream;

  void _applyStreamPush(HermesEvent event) {
    final push = parseStreamPush(event.type, event.data);
    if (push != null && !_streamPushes.isClosed) _streamPushes.add(push);
  }

  void _applyShoutout(HermesEvent event) {
    final shoutout = parseShoutout(
      event.type,
      event.data,
      channelId: channelId,
    );
    if (shoutout != null && !_shoutouts.isClosed) _shoutouts.add(shoutout);
  }

  Stream<void> get entitlementChanges => _entitlementChanges.stream;

  void _sayEntitlementsChanged() {
    if (!_entitlementChanges.isClosed) _entitlementChanges.add(null);
  }

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

  final _predictionAccess = <String, PredictionAccess>{};

  Future<PredictionAccess> predictionAccess(String eventId) async {
    final known = _predictionAccess[eventId];
    if (known != null) return known;
    final token = await _tokenProvider?.call();
    if (token == null || token.isEmpty) return PredictionAccess.unknown;
    final PredictionAccess? access;
    try {
      access = await _pointsService.fetchPredictionAccess(
        eventId: eventId,
        authToken: token,
      );
    } catch (e) {
      debugPrint('Prediction access unreadable (${e.runtimeType})');
      return PredictionAccess.unknown;
    }
    if (access == null) return PredictionAccess.unknown;
    return _predictionAccess[eventId] = access;
  }

  void rememberPredictionRestriction(
    String eventId,
    PredictionRestriction restriction,
  ) {
    _predictionAccess[eventId] =
        (_predictionAccess[eventId] ?? PredictionAccess.unknown)
            .withRestriction(restriction);
  }

  Future<PointsActionResult> acceptPredictionTerms({
    bool temporaryBadgeEnabled = true,
  }) async {
    final token = await _tokenProvider?.call();
    if (token == null || token.isEmpty) {
      return const PointsActionResult(
        PointsActionStatus.notAuthenticated,
        'no_token',
      );
    }
    final result = PointsActionResult.fromError(
      await _pointsService.acceptPredictionTerms(
        temporaryBadgeEnabled: temporaryBadgeEnabled,
        authToken: token,
      ),
    );
    if (result.isSuccess) {
      _predictionAccess.updateAll((_, access) => access.withTermsAccepted());
    }
    return result;
  }

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
      return const PointsActionResult(
        PointsActionStatus.unknown,
        PointsActionResult.busyCode,
      );
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

  @visibleForTesting
  void applyEventForTest(HermesEvent event) => _routeEvent(event);

  void _routeEvent(HermesEvent event) {
    // Topics are suffixed with the id they concern, so a stale subscription
    // from a previous channel can never drive this one. The viewer's own
    // topics end with *their* id, not the channel's — filtering on the channel
    // alone would have dropped every one of them, including the chest.
    final viewer = viewerId;
    final isMine = viewer != null && event.topic.endsWith('.$viewer');
    if (!event.topic.endsWith('.$channelId') && !isMine) return;

    if (event.topic.startsWith('user-subscribe-events')) {
      _sayEntitlementsChanged();
    } else if (event.topic.startsWith('user-bits-updates')) {
      _applyBitsBalance(event);
    } else if (event.topic.startsWith('channel-sub-gifts')) {
      _applySubGifts(event);
    } else if (event.topic.startsWith('shoutout.')) {
      _applyShoutout(event);
    } else if (event.topic.startsWith('celebration-events')) {
      _applyCelebration(event);
    } else if (event.topic.startsWith('content-classification-labels')) {
      _applyContentLabels(event);
    } else if (HermesTopics.sendsFlatPayloads(event.topic)) {
      _applyStreamPush(event);
    } else if (event.topic.startsWith('community-moments-channel')) {
      _applyMoment(event);
    } else if (event.topic.startsWith('private-callout.')) {
      _applyPrivateCallout(event);
    } else if (event.topic.startsWith('creator-goals-events')) {
      _applyGoal(event);
    } else if (event.topic.startsWith('community-points') ||
        event.topic.startsWith('predictions-')) {
      _applyPredictionWin(event);
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
  /// Debug builds only: payloads can carry other viewers' names and
  /// messages, which have no business in a release build's log.
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
    final raw = event.data['goal'];
    if (raw is Map<String, dynamic>) _creatorGoal = raw;
    final goal = CreatorGoal.tryParse(raw, eventType: event.type);
    if (goal == null) return;
    final wasReached = _goals.any(
      (known) => known.id == goal.id && known.isReached,
    );
    _goals = mergeCreatorGoal(_goals, goal);
    if (goal.isReached &&
        !wasReached &&
        _celebratedGoals.add(goal.id) &&
        !_goalsReached.isClosed) {
      _goalsReached.add(goal);
    }
  }

  @readonly
  List<CreatorGoal> _goals = const [];

  final _celebratedGoals = <String>{};

  final _goalsReached = StreamController<CreatorGoal>.broadcast();

  Stream<CreatorGoal> get goalsReached => _goalsReached.stream;

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
    final intensity =
        intensities[(_previewIndex ~/ effects.length) % intensities.length];
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
    unawaited(_entitlementChanges.close());
    unawaited(_shoutouts.close());
    unawaited(_watchStreakChanges.close());
    unawaited(_communityDrops.close());
    unawaited(_communityMoments.close());
    unawaited(_privateCallouts.close());
    unawaited(_predictionWins.close());
    unawaited(_streamPushes.close());
    unawaited(_goalsReached.close());
    _pointsRefreshTimer?.cancel();
    _pointsPollTimer?.cancel();
    unawaited(_subscription?.cancel());
    _subscription = null;
    _client.dispose();
  }
}

class ChestOpening {
  const ChestOpening(this.outcome, {this.revealed = const []});

  final ViewerActionOutcome outcome;
  final List<LegendaryEmote> revealed;
}
