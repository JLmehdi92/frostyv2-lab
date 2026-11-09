import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/apis/twitch_channel_profile_service.dart';
import 'package:onset/apis/twitch_chat_history_service.dart';
import 'package:onset/apis/twitch_chat_rules_service.dart';
import 'package:onset/apis/twitch_community_service.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/apis/twitch_vod_service.dart';
import 'package:onset/apis/twitch_watch_streak_service.dart';
import 'package:onset/l10n/enum_labels.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/community_highlights.dart';
import 'package:onset/models/creator_goal.dart';
import 'package:onset/models/drop_campaign.dart';
import 'package:onset/models/playback_access_token.dart';
import 'package:onset/models/private_callout.dart';
import 'package:onset/models/raid_arrival.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/models/stream_push.dart';
import 'package:onset/models/vod.dart';
import 'package:onset/models/watch_streak.dart';
import 'package:onset/models/weekly_rewards.dart';
import 'package:onset/screens/channel/celebrations/celebration_overlay.dart';
import 'package:onset/screens/channel/celebrations/subtle_celebrations.dart';
import 'package:onset/screens/channel/channel_info.dart';
import 'package:onset/screens/channel/channel_top_overlays.dart';
import 'package:onset/screens/channel/chat/details/chat_details.dart';
import 'package:onset/screens/channel/chat/incoming_raid.dart';
import 'package:onset/screens/channel/chat/mod_tools/mod_events.dart';
import 'package:onset/screens/channel/chat/overlay_chat_frame.dart';
import 'package:onset/screens/channel/chat/overlay_chat_placement.dart';
import 'package:onset/screens/channel/chat/stores/chat_store.dart';
import 'package:onset/screens/channel/chat/stores/chat_tabs_store.dart';
import 'package:onset/screens/channel/chat/widgets/chat_bottom_bar.dart';
import 'package:onset/screens/channel/chat/widgets/chat_tabs.dart';
import 'package:onset/screens/channel/chat/widgets/drops_card.dart';
import 'package:onset/screens/channel/chat/widgets/overlay_chat_scope.dart';
import 'package:onset/screens/channel/community_highlights/gift_bomb_feed.dart';
import 'package:onset/screens/channel/community_highlights/pinned_notice.dart';
import 'package:onset/screens/channel/community_highlights/raid_departure.dart';
import 'package:onset/screens/channel/community_highlights/stores/community_highlights_store.dart';
import 'package:onset/screens/channel/community_highlights/widgets/pinned_chat_text.dart';
import 'package:onset/screens/channel/community_highlights/widgets/raid_heading_overlay.dart';
import 'package:onset/screens/channel/followed_channels_drawer.dart';
import 'package:onset/screens/channel/goals/creator_goal_banner.dart';
import 'package:onset/screens/channel/hype_train/stores/hype_train_store.dart';
import 'package:onset/screens/channel/landscape_chat_cycle.dart';
import 'package:onset/screens/channel/portrait_split.dart';
import 'package:onset/screens/channel/stores/channel_events_store.dart';
import 'package:onset/screens/channel/stores/channel_info_store.dart';
import 'package:onset/screens/channel/stores/follow_prompts.dart';
import 'package:onset/screens/channel/stream_end.dart';
import 'package:onset/screens/channel/tablet_video_column.dart';
import 'package:onset/screens/channel/video/content_warning_gate.dart';
import 'package:onset/screens/channel/video/free_preview.dart';
import 'package:onset/screens/channel/video/ivs_stats_panel.dart';
import 'package:onset/screens/channel/video/ivs_video.dart';
import 'package:onset/screens/channel/video/latency_pill.dart';
import 'package:onset/screens/channel/video/live_progress.dart';
import 'package:onset/screens/channel/video/native_video.dart';
import 'package:onset/screens/channel/video/overlay_common.dart';
import 'package:onset/screens/channel/video/pinch_to_fill.dart';
import 'package:onset/screens/channel/video/player_controller.dart';
import 'package:onset/screens/channel/video/player_engine_resolver.dart';
import 'package:onset/screens/channel/video/stores/ivs_video_store.dart';
import 'package:onset/screens/channel/video/stores/native_video_store.dart';
import 'package:onset/screens/channel/video/stores/video_store.dart';
import 'package:onset/screens/channel/video/stream_info_bar.dart';
import 'package:onset/screens/channel/video/video.dart';
import 'package:onset/screens/channel/video/video_overlay.dart';
import 'package:onset/screens/channel/video/web_content_gate.dart';
import 'package:onset/screens/channel_profile/channel_profile_screen.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/vod/channel_videos.dart';
import 'package:onset/screens/vod/vod_screen.dart';
import 'package:onset/services/playback_focus.dart';
import 'package:onset/services/realtime/twitch_eventsub_client.dart';
import 'package:onset/stores/whisper_store.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/common_utils.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/utils/link_router.dart';
import 'package:onset/utils/modal_bottom_sheet.dart';
import 'package:onset/utils/pip_callbacks.dart';
import 'package:onset/widgets/announce.dart';
import 'package:onset/widgets/blurred_container.dart';
import 'package:onset/widgets/draggable_divider.dart';
import 'package:onset/widgets/follow/follow_flow.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';
import 'package:onset/widgets/onset_notification.dart';
import 'package:onset/widgets/sheet/onset_panel.dart';
import 'package:onset/widgets/twitch_web_page.dart';
import 'package:provider/provider.dart';
import 'package:simple_pip_mode/actions/pip_actions_layout.dart';
import 'package:simple_pip_mode/pip_widget.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Creates a widget that shows the video stream (if live) and chat of the given user.
class VideoChat extends StatefulWidget {
  static const routeName = 'VideoChat';

  final String userId;
  final String userName;
  final String userLogin;

  /// The raid the viewer followed here, if they did: the "Heading to"
  /// overlay fades out, the chat welcomes them and the raid is pinned.
  final RaidArrival? raidArrival;

  final bool startChatOnly;
  final bool offerFollow;

  const VideoChat({
    super.key,
    required this.userId,
    required this.userName,
    required this.userLogin,
    this.raidArrival,
    this.startChatOnly = false,
    this.offerFollow = false,
  });

  static bool leaveForShell() {
    for (final state in _VideoChatState._alive.reversed) {
      if (!state.mounted) continue;
      if (state._videoStore.paused || !state.context.settingsStore.showVideo) {
        return true;
      }
      return state._handOffToMiniPlayer();
    }
    return true;
  }

  /// The page of [login]'s channel when it is open (the latest one), or
  /// null.
  static Route<dynamic>? routeOf(String login) {
    final name = login.toLowerCase();
    for (final state in _VideoChatState._alive.reversed) {
      if (state.widget.userLogin.toLowerCase() != name) continue;
      final route = ModalRoute.of(state.context);
      if (route != null && route.isActive) return route;
    }
    return null;
  }

  @override
  State<VideoChat> createState() => _VideoChatState();
}

class _VideoChatState extends State<VideoChat>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _videoKey = GlobalKey();
  final _chatKey = GlobalKey();

  /// Real-time channel events: celebrations, creator goals and channel
  /// points (the hype train has its own store below).
  ///
  /// Entirely additive — if Hermes never connects, every widget it feeds
  /// renders as an empty box and the screen is exactly what it was before.
  late final ChannelEventsStore _eventsStore = ChannelEventsStore(
    channelId: widget.userId,
    // GQL addresses channels by name, Hermes by id — both are needed.
    channelLogin: widget.userLogin,
    // The viewer's own id, for the topics that carry what happens to them
    // rather than to the channel — the bonus chest above all.
    viewerId: context.authStore.user.details?.id,
    tokenProvider: () async => context.authStore.twitchWebToken,
    // The viewer's watch streak, atop the points panel like Twitch.
    watchStreakService: context.read<TwitchWatchStreakService?>(),
    viewerActionsService: context.read<TwitchViewerActionsService?>(),
    communityService: context.read<TwitchCommunityService?>(),
    channelName: widget.userName,
    isChannelLive: () => _videoStore.streamInfo != null,
    paidPromotionOf: context.read<TwitchVodService?>()?.streamHasPaidPromotion,
  );

  /// Whether the viewer follows this channel and, beside a tablet's video,
  /// their other followed channels live now; asked once the player has had
  /// its head start, never on the video path.
  late final ChannelInfoStore _infoStore = () {
    final auth = context.authStore;
    return ChannelInfoStore(
      channelId: widget.userId,
      api: context.twitchApi,
      viewerId: () => auth.user.details?.id,
    );
  }();

  late final FollowPrompts _followPrompts = FollowPrompts(
    following: _infoStore.following,
    canFollow: () => mounted && FollowFlow.actionsOf(context) != null,
    onCallout: _showFollowCallout,
    onOfferFollow: () => unawaited(_offerFollow()),
    offerFollow: widget.offerFollow,
  );

  Future<void> _noticeRestriction() async {
    final profiles = context.read<TwitchChannelProfileService?>();
    if (profiles == null) return;
    final bool restricted;
    try {
      restricted = await profiles.isRestricted(widget.userId);
    } catch (_) {
      return;
    }
    if (!mounted || !restricted) return;
    _primaryChatStore?.addLocalNotice(
      L10n.current.channelRestrictedBanner(name: widget.userName),
    );
  }

  void _showFollowCallout() {
    final l = L10n.current;
    _primaryChatStore?.addLocalNotice(
      l.followCalloutLine(name: widget.userName),
      actionLabel: l.channelFollow,
      onAction: () => unawaited(_followFromPrompt()),
    );
  }

  Future<void> _offerFollow() async {
    if (!mounted || !await FollowFlow.confirmFollow(context, widget.userName)) {
      return;
    }
    await _followFromPrompt();
  }

  Future<void> _followFromPrompt() async {
    if (!mounted || _infoStore.following.value == true) return;
    final now = await FollowFlow.toggle(
      context,
      target: FollowTarget.channel,
      id: widget.userId,
      name: widget.userName,
      following: false,
      openOnTwitch: () async {
        await TwitchWebPage.open(
          context,
          title: widget.userName,
          url: Uri.https('www.twitch.tv', '/${widget.userLogin.toLowerCase()}'),
        );
        _infoStore.refresh();
      },
    );
    if (now != null) _infoStore.following.value = now;
  }

  /// Asks about the viewer again when they become known (a cold start) or
  /// change (signed in or out).
  ReactionDisposer? _viewerReaction;

  ReactionDisposer? _streamEndReaction;
  StreamTwitch? _liveStream;
  Vod? _latestBroadcast;
  var _streamEndEpoch = 0;
  late final _streamEnd = StreamEndLookup(
    api: context.twitchApi,
    vods: context.twitchVodService,
  );

  // PiP drag state - essential only
  double _pipDragDistance = 0;
  bool _isPipDragging = false;

  /// Two fingers on the landscape video: the swipe to picture-in-picture
  /// and the tap stand down (see [PinchToFill]).
  final _pinching = ValueNotifier(false);

  /// What the double tap on the landscape video shows next, and whether
  /// the side column on screen is the one it opened (full screen beside
  /// the chat: no info area under a tablet's video).
  late final _chatCycle = LandscapeChatCycle(_chatTabsStore.settingsStore);

  /// Where the mature-content warning stands. Pending until it has read
  /// the labels: the stream plays, but it may not leave the screen yet.
  ContentGate _contentGate = ContentGate.pending;

  /// The one content warning of the screen: every layout (portrait, side
  /// chat, full screen) draws the video inside it, and the key carries its
  /// state (the labels, an acceptance) from one layout to the next, so
  /// turning the phone never uncovers the stream nor asks Twitch again.
  final _contentGateKey = GlobalKey();

  /// Where the video is, so a tablet's anchored panels (user card, points,
  /// emote menu) keep it clear.
  final _panelAvoid = PanelAvoidHolder();

  /// The portrait video size while its handle is dragged; saved to the
  /// settings once, when the drag ends.
  final _portraitDragScale = ValueNotifier<double?>(null);
  bool _isInPipTriggerZone =
      false; // Track when in trigger zone for haptic feedback

  // Divider drag state for synchronizing animation
  bool _isDividerDragging = false;

  /// A tablet's side chat, a shade off the ground.
  static const _tabletChatColor = Color(0xFF0D0D0D);

  // Essential constants for good UX balance
  static const double _pipTriggerDistance = 80;
  static const double _pipMaxDragDistance = 150;

  // Animation controller for smooth spring-back
  late AnimationController _animationController;
  late Animation<double> _springBackAnimation;

  bool? _isImmersiveSystemUiEnabled;

  // Player + chat adopted back from the mini window when restoring this same
  // channel (resolved once, before the late stores below first initialize, so
  // the live player and the chat history both survive without a reset).
  IvsVideoStore? _adoptedPlayer;
  ChatTabsStore? _adoptedChat;
  LiveProgressTracker? _adoptedProgress;
  bool _adoptionResolved = false;

  void _resolveAdoption() {
    if (_adoptionResolved) return;
    _adoptionResolved = true;
    final mini = context.miniPlayerStore;
    if (mini.visible && mini.userLogin == widget.userLogin) {
      final released = mini.release();
      _adoptedPlayer = released.player;
      _adoptedChat = released.chat;
      _adoptedProgress = released.liveProgress;
    }
  }

  late final ChatTabsStore _chatTabsStore = () {
    _resolveAdoption();
    return _adoptedChat ??
        ChatTabsStore(
          twitchApi: context.twitchApi,
          bttvApi: context.bttvApi,
          ffzApi: context.ffzApi,
          sevenTVApi: context.sevenTVApi,
          authStore: context.authStore,
          settingsStore: context.settingsStore,
          globalAssetsStore: context.globalAssetsStore,
          whisperStore: context.read<WhisperStore>(),
          listenEvents: context.read<TwitchEventSubClient>().listen,
          chatRulesService: context.read<TwitchChatRulesService>(),
          chatHistoryService: context.read<TwitchChatHistoryService?>(),
          primaryChannelId: widget.userId,
          primaryChannelLogin: widget.userLogin,
          primaryDisplayName: widget.userName,
        );
  }();

  late PlayerController _videoStore = _buildPlayerController();

  /// Where the viewer is in this broadcast, kept like the official app does
  /// so its VOD can later start there.
  /// Handed to the mini window with the player, and back.
  late final LiveProgressTracker _liveProgress = () {
    _resolveAdoption();
    final adopted = _adoptedProgress;
    if (adopted != null) return adopted;
    final vodService = context.twitchVodService;
    return LiveProgressTracker(
      repository: LiveProgressRepository.shared,
      // The same viewer as the VOD screen and lists.
      viewer: () => vodService.viewerId?.call(),
      report: (streamId, offsetSec) => vodService.updateViewedVideo(
        videoId: streamId,
        type: WatchedVideoType.live,
        positionSec: offsetSec,
      ),
    );
  }();

  /// True once the live player has been handed to the mini window, so this
  /// screen must not dispose it when it pops.
  bool _handedOff = false;

  /// The primary (video) channel's hype train, whatever chat tab is open;
  /// null while the setting is off. Never handed to the mini window.
  HypeTrainStore? _hypeTrainStore;
  ReactionDisposer? _hypeTrainSettingReaction;

  FreePreviewController? _freePreview;
  VoidCallback? _useWebPlayer;

  Future<void> _startFreePreview(IvsVideoStore store) async {
    final endsAt = store.freePreviewEndsAt;
    if (!mounted || endsAt == null || !endsAt.isAfter(DateTime.now())) return;
    final preview = FreePreviewController(
      endsAt: endsAt,
      onExpired: () {
        if (identical(_videoStore, store) && !store.paused) {
          store.handlePausePlay();
        }
      },
    );
    setState(() => _freePreview = preview);
    final tier = await store.freePreviewTier();
    if (tier != null && identical(_freePreview, preview)) preview.tier = tier;
  }

  var _landscape = false;

  void _syncHypeTrainStore() {
    final show = context.settingsStore.showHypeTrain;
    if (show && _hypeTrainStore == null) {
      final authStore = context.authStore;
      _hypeTrainStore = HypeTrainStore(
        channelId: widget.userId,
        service: context.twitchHypeTrainService,
        realtime: context.realtimeClient,
        viewerId: () => authStore.user.details?.id,
      );
    } else if (!show && _hypeTrainStore != null) {
      _hypeTrainStore!.dispose();
      _hypeTrainStore = null;
    }
  }

  /// The primary (video) channel's polls, predictions, pinned message and
  /// outgoing raid; null while the setting is off. Never handed to the mini
  /// window.
  CommunityHighlightsStore? _highlightsStore;
  ReactionDisposer? _highlightsSettingReaction;

  /// Pins the gift bombs of the primary chat as banners; up while
  /// [_highlightsStore] is.
  ReactionDisposer? _giftBombFeed;

  /// Pins the raids on the primary chat's channel; up while
  /// [_highlightsStore] is.
  ReactionDisposer? _incomingRaidFeed;

  /// Calls off a departure as soon as its raid is cancelled; up while
  /// [_highlightsStore] is.
  ReactionDisposer? _raidCancelFeed;

  /// Turns celebrations into chat lines while "Celebrations on video" is
  /// Subtle.
  ReactionDisposer? _subtleCelebrations;

  StreamSubscription<PinnedChatMessage>? _newPins;

  void _sayPinned(PinnedChatMessage pin) {
    final text = pinnedNotice(pin, L10n.current);
    _primaryChatStore?.addLocalNotice(text);
    announce(context, text);
  }

  /// The video channel's own chat, once it is up.
  ChatStore? get _primaryChatStore =>
      _chatTabsStore.tabs.where((tab) => tab.isPrimary).firstOrNull?.chatStore;

  void _syncHighlightsStore() {
    final show = context.settingsStore.showCommunityHighlights;
    if (show && _highlightsStore == null) {
      // Read from the window: no inherited lookups in initState.
      final view = WidgetsBinding.instance.platformDispatcher.implicitView;
      _highlightsStore = CommunityHighlightsStore(
        channelId: widget.userId,
        channelLogin: widget.userLogin,
        channelName: widget.userName,
        service: context.twitchCommunityHighlightsService,
        realtime: context.realtimeClient,
        expandNew:
            view != null &&
            isLargeScreenSize(view.physicalSize / view.devicePixelRatio),
        onGoAlong: _goAlongWithRaid,
        isPinHidden: (id) =>
            context.settingsStore.hiddenPinnedChatIds.contains(id),
        onHidePin: context.settingsStore.hidePinnedChat,
        pollVoter: _pollVoter(),
        raidMembership: _raidMembership(),
      );
      _newPins = _highlightsStore!.newPins.listen(_sayPinned);
      _giftBombFeed = feedGiftBombs(
        latest: () => _primaryChatStore?.latestGiftBomb,
        show: (bomb) => _highlightsStore?.showGiftBomb(
          bomb,
          live: _primaryChatStore?.watchGiftBomb(bomb.key),
        ),
      );
      _raidCancelFeed = reaction(
        (_) => _highlightsStore?.raid?.cancelled ?? false,
        (bool cancelled) {
          if (cancelled) _departure.callOff();
        },
      );
      _incomingRaidFeed = reaction(
        (_) => _primaryChatStore?.latestIncomingRaid,
        (IncomingRaid? raid) {
          if (raid != null) _highlightsStore?.showIncomingRaid(raid);
        },
      );
    } else if (!show && _highlightsStore != null) {
      _giftBombFeed?.call();
      _giftBombFeed = null;
      _incomingRaidFeed?.call();
      _incomingRaidFeed = null;
      _raidCancelFeed?.call();
      _raidCancelFeed = null;
      unawaited(_newPins?.cancel());
      _newPins = null;
      _highlightsStore!.dispose();
      _highlightsStore = null;
    }
  }

  /// The raid left while this channel was on screen: go along with it, as
  /// Twitch does (not from behind a VOD, the mini player or PiP).
  PollVoter? _pollVoter() {
    final service = context.read<TwitchViewerActionsService?>();
    final auth = context.authStore;
    final userId = auth.user.details?.id;
    if (service == null || userId == null || auth.twitchWebToken == null) {
      return null;
    }
    return ({required pollId, required choiceId}) => service.voteInPoll(
      pollId: pollId,
      choiceId: choiceId,
      userId: userId,
      authToken: auth.twitchWebToken ?? '',
    );
  }

  RaidMembership? _raidMembership() {
    final service = context.read<TwitchViewerActionsService?>();
    final auth = context.authStore;
    if (service == null ||
        auth.user.details?.id == null ||
        auth.twitchWebToken == null) {
      return null;
    }
    return (raidId, {required join}) {
      final token = auth.twitchWebToken ?? '';
      return join
          ? service.joinRaid(raidId: raidId, authToken: token)
          : service.leaveRaid(raidId: raidId, authToken: token);
    };
  }

  void _goAlongWithRaid(OutgoingRaid raid) {
    if (!_canLeaveWithRaid()) return;
    _departToRaid(raid);
  }

  /// Whether this screen may leave for a raid's target now: on screen, not
  /// in PiP, and on top. Its own sheets and dialogs (the raid's details)
  /// close; a page on top (a VOD, settings) keeps the viewer where they are.
  bool _canLeaveWithRaid() {
    if (!mounted || _videoStore.isInPipMode) return false;
    final route = ModalRoute.of(context);
    if (route == null || !route.isActive) return false;
    if (!route.isCurrent) {
      Navigator.of(context).popUntil((r) => r == route || r is! PopupRoute);
    }
    return route.isCurrent;
  }

  /// Leaving with a raid: the "Heading to" overlay plays, then the switch.
  late final RaidDeparture _departure = RaidDeparture(
    // A raid called off meanwhile takes no one anywhere.
    canLeave: () =>
        !(_highlightsStore?.raid?.cancelled ?? false) && _canLeaveWithRaid(),
    onSwitch: (raid, arrival) => _watchRaid(raid, arrival: arrival),
    onChanged: () {
      if (!mounted) return;
      if (_departure.current == null) _highlightsStore?.markDeparting(null);
      setState(() {});
    },
  );

  /// The raid that brought the viewer here, while its overlay fades out.
  late RaidArrival? _arrival = widget.raidArrival;

  /// Ends the arrival on time, whether or not its overlay could show (chat
  /// only, PiP, a layout change).
  Timer? _arrivalTimer;

  /// "Go now" or "Watch" on an outgoing raid, or the raid leaving: the
  /// target's picture is hit on the card, "Heading to Y" plays over the
  /// video, then the target replaces this channel. Nothing changes on the
  /// video path meanwhile; the checks run again at the switch, so PiP or a
  /// page opened in between keeps the viewer here.
  void _departToRaid(OutgoingRaid raid) {
    if (!mounted) return;
    final started = _departure.start(
      raid,
      fromName: widget.userName,
      fromLogin: widget.userLogin,
      delay: reduceMotionOf(context)
          ? kRaidDepartureDelayReduced
          : kRaidDepartureDelay,
      now: DateTime.now(),
    );
    if (started) _highlightsStore?.markDeparting(raid);
  }

  /// The target replaces this channel.
  void _watchRaid(OutgoingRaid raid, {RaidArrival? arrival}) => _replaceWith(
    userId: raid.targetId,
    userName: raid.targetDisplayName,
    userLogin: raid.targetLogin,
    raidArrival: arrival,
  );

  /// The overlay of the raid that brought the viewer here has faded: the
  /// raid is pinned in the new chat like an incoming one.
  void _onArrived() {
    final arrival = _arrival;
    if (!mounted || arrival == null) return;
    setState(() => _arrival = null);
    _highlightsStore?.showIncomingRaid(
      IncomingRaid(
        raiderName: arrival.fromName,
        raiderLogin: arrival.fromLogin,
        viewers: arrival.viewers,
      ),
    );
  }

  /// A channel from "Also live from your follows" replaces this one, as a
  /// raid's target does (one player at a time).
  void _openChannel(StreamTwitch stream) => _replaceWith(
    userId: stream.userId,
    userName: stream.userName,
    userLogin: stream.userLogin,
  );

  void _replaceWith({
    required String userId,
    required String userName,
    required String userLogin,
    RaidArrival? raidArrival,
  }) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        settings: const RouteSettings(name: VideoChat.routeName),
        builder: (context) => VideoChat(
          userId: userId,
          userName: userName,
          userLogin: userLogin,
          raidArrival: raidArrival,
        ),
      ),
    );
  }

  /// The chat's details from the header of a tablet's side chat.
  void _openChatDetails() {
    showChatDetails(
      context,
      chatStore: _chatStore,
      onAddChat: () => addChatTab(context, _chatTabsStore),
    );
  }

  /// The signed-in viewer's login, for the widgets that read it in their
  /// own observers (Follow shows as soon as the account is known).
  String? _viewerLogin() => context.authStore.user.details?.login;

  void _openProfile() => ChannelProfileScreen.open(
    context,
    login: widget.userLogin,
    displayName: widget.userName,
    fromChannel: true,
  );

  /// A tablet beside its chat: the video first, the
  /// channel's info area under it while there is room for it.
  Widget _buildTabletVideoColumn(Widget video, {required bool infoArea}) {
    return Observer(
      // Only the IVS engine has a fill toggle to read.
      warnWhenNoObservables: false,
      builder: (context) => TabletVideoColumn(
        // A filled picture asks for the whole column, as it had before
        // the info area.
        fill: switch (_videoStore) {
          final IvsVideoStore ivs => ivs.fillScreen,
          _ => false,
        },
        infoArea: infoArea,
        video: _buildPipGestureWrapper(child: video),
        info: TabletChannelPanel(
          player: _videoStore,
          login: widget.userLogin,
          displayName: widget.userName,
          info: _infoStore,
          viewerLogin: _viewerLogin,
          onOpenChannel: _openChannel,
          watchStreak: () => _eventsStore.watchStreak?.value,
        ),
      ),
    );
  }

  /// A tablet's side chat: its header, then the chat.
  Widget _buildTabletChat(Widget chat, SettingsStore settingsStore) {
    final hairline = BorderSide(
      color: context.onsetColors.hairline,
      width: OnsetTokens.hairlineWidth,
    );
    final left = settingsStore.landscapeChatLeftSide;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          left: left ? BorderSide.none : hairline,
          right: left ? hairline : BorderSide.none,
        ),
      ),
      child: Column(
        children: [
          TabletChatHeader(settings: settingsStore, onMore: _openChatDetails),
          Expanded(child: ChatMoreInHeader(child: chat)),
        ],
      ),
    );
  }

  /// A pinned message as the video channel's chat shows it (badges, colour,
  /// Twitch and 7TV/BTTV/FFZ emotes); plain text until that chat is up.
  Widget? _pinnedMessage(BuildContext context, PinnedChatMessage pin) {
    final chat = _primaryChatStore;
    if (chat == null) return null;
    return PinnedChatText(
      pin: pin,
      assetsStore: chat.assetsStore,
      settings: context.settingsStore,
      channelId: widget.userId,
      channelLogin: widget.userLogin,
      viewerLogin: context.authStore.user.details?.login,
    );
  }

  /// Builds the video controller for the engine selected in settings.
  ///
  /// The native low-latency engine is the default; the Twitch WebView engine
  /// remains available as a fallback (and is forced via [forceWeb] when native
  /// playback fails at runtime).
  PlayerController _buildPlayerController({bool forceWeb = false}) {
    final engine = resolvePlayerEngine(
      setting: context.settingsStore.playerEngine,
      isAndroid: Platform.isAndroid,
      forceWeb: forceWeb,
    );
    if (engine == PlayerEngine.ivs) {
      // If this channel is currently playing in the mini window (restoring),
      // take that live player back instead of creating a new one — no reload.
      _resolveAdoption();
      final adopted = _adoptedPlayer;
      if (adopted != null) return adopted;
      return IvsVideoStore(
        userLogin: widget.userLogin,
        userId: widget.userId,
        twitchApi: context.twitchApi,
        authStore: context.authStore,
        settingsStore: context.settingsStore,
        // EventSub needs a logged-in viewer; otherwise polling only.
        listenEvents: context.authStore.isLoggedIn
            ? context.read<TwitchEventSubClient>().listen
            : null,
      );
    }
    if (engine == PlayerEngine.nativeLowLatency) {
      return NativeVideoStore(
        userLogin: widget.userLogin,
        userId: widget.userId,
        twitchApi: context.twitchApi,
        authStore: context.authStore,
        settingsStore: context.settingsStore,
      );
    }
    return VideoStore(
      userLogin: widget.userLogin,
      userId: widget.userId,
      twitchApi: context.twitchApi,
      authStore: context.authStore,
      settingsStore: context.settingsStore,
    );
  }

  SettingsStore? _chatOnlySettings;

  void _hideVideoForChatOnlyStart() {
    if (!widget.startChatOnly) return;
    final settings = context.settingsStore;
    runInAction(() => settings.chatOnlyForPage = true);
    _chatOnlySettings = settings;
  }

  void _restoreVideoAfterChatOnlyStart() {
    final settings = _chatOnlySettings;
    if (settings != null) runInAction(() => settings.chatOnlyForPage = false);
  }

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  bool get _hasFollowedDrawer =>
      !context.isLargeScreen && context.authStore.isLoggedIn;

  @override
  void initState() {
    super.initState();
    _alive.add(this);
    _hideVideoForChatOnlyStart();

    // Build the player first — this adopts the live player back from the mini
    // window when we're restoring this same channel (seamless, no reload).
    final store = _videoStore;
    // The warning has not read the labels yet (it says so once it has, or
    // clear when there is no video to cover).
    store.setContentGate(
      context.settingsStore.showVideo ? ContentGate.pending : ContentGate.clear,
    );
    if (!context.settingsStore.showVideo) _contentGate = ContentGate.clear;
    _liveProgress
      ..attach(store)
      ..start();

    // A *different* channel left in the mini is superseded by opening this one.
    context.miniPlayerStore.close();

    // Only one audible player: a VOD opened on top pauses this stream and
    // closing it resumes the stream.
    PlaybackFocus.shared
      ..register(
        this,
        onLost: _pauseForOtherPlayer,
        onRegained: _resumeAfterOtherPlayer,
      )
      ..claim(this);
    // Not awaited: the channel must open at the same speed it always did, and
    // a real-time connection failing is not a reason to delay playback.
    unawaited(_eventsStore.connect());
    _entitlementChanges = _eventsStore.entitlementChanges.listen(
      (_) => _refreshEmotesOfEveryTab(),
    );
    _shoutouts = _eventsStore.shoutouts.listen(_showShoutout);
    _streamPushes = _eventsStore.streamPushes.listen(_applyStreamPush);
    _goalsReached = _eventsStore.goalsReached.listen(_showGoalReached);
    _streakChanges = _eventsStore.watchStreakChanges.listen(
      _showWatchStreakChange,
    );
    _communityDrops = _eventsStore.communityDrops.listen(
      (campaign) => _primaryChatStore?.addLocalNotice(
        communityDropsLine(campaign, widget.userName, L10n.current),
      ),
    );
    _privateCallouts = _eventsStore.privateCallouts.listen(_showPrivateCallout);
    _predictionWins = _eventsStore.predictionWins.listen(_showPredictionWin);
    _communityMoments = _eventsStore.communityMoments.listen(
      (_) => _primaryChatStore?.addLocalNotice(
        L10n.current.momentChatLine(channel: widget.userName),
      ),
    );
    _infoStore.start();
    _followPrompts.start();
    unawaited(_noticeRestriction());
    _watchStreamEnd();
    final auth = context.authStore;
    _viewerReaction = reaction(
      (_) => auth.user.details?.id,
      (_) => _infoStore.viewerChanged(),
    );

    // If the native engine fails to load the stream (offline, geo-block, or a
    // Twitch API change), fall back to the WebView engine for this session so
    // the player never dies silently.
    void switchToWeb() {
      if (!mounted || !identical(_videoStore, store)) return;
      // Twitch refusing the stream (subscribers only, region, ban) is said,
      // since the web player may not play it either.
      final notice = store is IvsVideoStore ? store.refusalNotice : null;
      setState(() {
        _freePreview?.dispose();
        _freePreview = null;
        store.dispose();
        _videoStore = _buildPlayerController(forceWeb: true)
          ..setContentGate(_contentGate);
        _liveProgress.attach(_videoStore);
      });
      _watchStreamEnd();
      if (notice != null) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.channelWebFallback(
                notice: notice.text(context.l10n),
              ),
            ),
          ),
        );
      }
    }

    void fallbackToWeb() {
      // Only once, and only for the store this callback was attached to.
      if (!mounted || !identical(_videoStore, store)) return;
      final preview = _freePreview;
      if (preview != null &&
          store is IvsVideoStore &&
          (preview.expired ||
              store.refusalNotice?.refusal ==
                  PlaybackRefusal.subscribersOnly)) {
        preview.expire();
        return;
      }
      switchToWeb();
    }

    if (store is IvsVideoStore) {
      _useWebPlayer = switchToWeb;
      unawaited(
        store.ready.then((_) => _startFreePreview(store), onError: (_) {}),
      );
    }

    if (store is NativeVideoStore) {
      store.ready.catchError((Object _) => fallbackToWeb());
    } else if (store is IvsVideoStore) {
      store.onFatalError = fallbackToWeb;
      // A channel confirmed offline keeps the native player (it shows
      // offline and starts when the channel goes live).
      store.ready.catchError((Object _) async {
        if (!await store.offlineAtStart) fallbackToWeb();
      });
      // A player adopted back from the mini window may have failed while it
      // was minimised (no fallback there); fall back now that we can.
      if (store.status == IvsPlaybackStatus.failed) {
        WidgetsBinding.instance.addPostFrameCallback((_) => fallbackToWeb());
      }
    }

    // Initialize animation controller for smooth drag interactions
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    // Spring-back animation with smooth easing
    _springBackAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    // Attach listener to the controller (not the derived animation) so it
    // survives _springBackAnimation being reassigned in _animateSpringBack.
    _animationController.addListener(() {
      setState(() {
        _pipDragDistance = _springBackAnimation.value;
      });
    });

    // Register as observer for app lifecycle events
    WidgetsBinding.instance.addObserver(this);

    _syncHypeTrainStore();
    final settings = context.settingsStore;
    _hypeTrainSettingReaction = reaction((_) => settings.showHypeTrain, (_) {
      if (mounted) setState(_syncHypeTrainStore);
    });
    _subtleCelebrations = feedSubtleCelebrations(
      latest: () => _eventsStore.celebration,
      subtle: () =>
          settings.showCelebrations &&
          settings.celebrationsSubtle(landscape: _landscape),
      post: (line) => _primaryChatStore?.addLocalNotice(line),
      clear: _eventsStore.clearCelebration,
    );
    _syncHighlightsStore();
    if (widget.raidArrival case final arrival?) {
      _primaryChatStore?.addArrivalNotice(arrival);
      _arrivalTimer = Timer(kRaidArrivalFade, _onArrived);
    }
    _highlightsSettingReaction = reaction(
      (_) => settings.showCommunityHighlights,
      (_) {
        if (mounted) setState(_syncHighlightsStore);
      },
    );
  }

  /// Whether the stream was playing when another player took focus.
  var _playingBeforeFocusLoss = false;

  final _pipKey = GlobalKey<PipWidgetState>();

  void _pauseForOtherPlayer() {
    final store = _videoStore;
    if (store is IvsVideoStore) store.setFocusSuppressed(true);
    _playingBeforeFocusLoss = !store.paused;
    if (_playingBeforeFocusLoss) store.handlePausePlay();
  }

  void _resumeAfterOtherPlayer() {
    // Runs after the frame: the screen above may be closing together with
    // this one (popUntil), and must finish disposing first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final store = _videoStore;
      if (store is IvsVideoStore) store.setFocusSuppressed(false);
      if (_playingBeforeFocusLoss && store.paused) store.handlePausePlay();
      _playingBeforeFocusLoss = false;
      _reassertScreenState();
    });
  }

  /// The channel screens alive, oldest first.
  static final _alive = <_VideoChatState>[];

  /// What a closing player screen resets on its way out (auto-PiP, the
  /// wakelock, the PiP callbacks, the system bars), applied again.
  void _reassertScreenState() {
    final store = _videoStore;
    if (store is IvsVideoStore) store.reassertAutoPip();
    if (store is VideoStore) store.reassertAutoPip();
    if (store.settingsStore.keepScreenAwake) WakelockPlus.enable();
    reclaimPipCallbacks(_pipKey);
    setState(() => _isImmersiveSystemUiEnabled = null);
  }

  /// This screen replaced another (raid "Watch"), which reset the shared
  /// state after this one set it: set it again once that one is gone.
  void _reassertAfterReplaced() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      _reassertScreenState();
    });
  }

  void _watchStreamEnd() {
    _streamEndReaction?.call();
    final store = _videoStore;
    _streamEndReaction = reaction(
      (_) =>
          (live: store.streamInfo, offline: store.offlineChannelInfo != null),
      (state) => _onLiveState(state.live, offline: state.offline),
      fireImmediately: true,
    );
  }

  void _onLiveState(StreamTwitch? live, {required bool offline}) {
    if (live != null) {
      _streamEndEpoch++;
      _liveStream = live;
      if (_latestBroadcast != null) setState(() => _latestBroadcast = null);
      return;
    }
    if (!offline) return;
    final epoch = ++_streamEndEpoch;
    final ended = _liveStream;
    _liveStream = null;
    unawaited(_showLatestBroadcast(ended, epoch));
  }

  Future<void> _showLatestBroadcast(StreamTwitch? ended, int epoch) async {
    final login = widget.userLogin;
    final vod = ended == null
        ? await _streamEnd.latestBroadcast(login)
        : await _streamEnd.latestBroadcastIfOffline(login);
    if (!mounted || epoch != _streamEndEpoch || vod == null) return;
    setState(() => _latestBroadcast = vod);
    if (ended == null || !isVodOfBroadcast(vod, ended)) return;
    if (!_canSwitchToBroadcast) return;
    ScaffoldMessenger.maybeOf(context)
      ?..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(context.l10n.streamEndedPlayingBroadcast)),
      );
    unawaited(VodScreen.open(context, vodId: vod.id, vod: vod));
  }

  bool get _canSwitchToBroadcast =>
      ModalRoute.of(context)?.isCurrent == true &&
      !_videoStore.isInPipMode &&
      _videoStore.settingsStore.showVideo &&
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      _videoStore.handleAppResume();
      _hypeTrainStore?.handleAppResume();
      unawaited(_eventsStore.resume());
    } else if (state == AppLifecycleState.paused) {
      if (_videoStore case final IvsVideoStore store) {
        unawaited(store.handleAppBackground());
      }
      // Points and celebrations matter only on screen.
      _eventsStore.pause();
      unawaited(_liveProgress.save(report: true));
    }
  }

  /// Twitch's own content warning is up in the web player's page.
  bool get _webGateUp => switch (_videoStore) {
    WebPagePlayer(webGateVisible: true) => true,
    _ => false,
  };

  /// The player follows the mature-content warning: held paused while it
  /// covers the video (the cover hides the picture but the audio would go
  /// on), free again when it is clear, and kept on the screen until then.
  /// Chat only is not consent: the warning leaves with the video and says
  /// nothing, and the one built when the video comes back keeps a covered
  /// stream held while it reads the labels again.
  void _onContentGate(ContentGate gate) {
    if (!mounted) return;
    _contentGate = followContentGate(_contentGate, gate);
    _videoStore.setContentGate(_contentGate);
  }

  /// "Start watching": Twitch's own warning in the web player may go too.
  void _onContentAccepted() {
    if (_videoStore case final VideoStore web) {
      unawaited(web.acceptContentGate());
    }
  }

  void _handlePipDragStart(DragStartDetails details) {
    // Disable drag gesture when already in PiP mode or video is not playing,
    // and until the content warning is clear.
    if (_videoStore.isInPipMode ||
        _videoStore.paused ||
        _pinching.value ||
        !_contentGate.allowsLeaving) {
      return;
    }

    _animationController.stop(); // Stop any ongoing animation
    setState(() {
      _isPipDragging = true;
      _pipDragDistance = 0;
      _isInPipTriggerZone = false;
    });
  }

  void _handlePipDragUpdate(DragUpdateDetails details) {
    if (!_isPipDragging || _videoStore.isInPipMode || _videoStore.paused) {
      return;
    }
    // A second finger came down: this is a pinch, not a swipe.
    if (_pinching.value) {
      setState(() => _isPipDragging = false);
      _animateSpringBack();
      return;
    }

    setState(() {
      _pipDragDistance += details.delta.dy;
      _pipDragDistance = _pipDragDistance.clamp(0, _pipMaxDragDistance);

      // Check if we've entered or exited the trigger zone for haptic feedback
      final wasInTriggerZone = _isInPipTriggerZone;
      _isInPipTriggerZone = _pipDragDistance >= _pipTriggerDistance;

      // Provide haptic feedback when entering the trigger zone
      if (!wasInTriggerZone && _isInPipTriggerZone) {
        HapticFeedback.mediumImpact(); // Entering trigger zone
      }
      // Provide subtle haptic feedback when exiting the trigger zone
      else if (wasInTriggerZone && !_isInPipTriggerZone) {
        HapticFeedback.lightImpact(); // Exiting trigger zone
      }
    });
  }

  void _handlePipDragEnd(DragEndDetails details) {
    if (!_isPipDragging || _videoStore.isInPipMode || _videoStore.paused) {
      return;
    }

    final velocity = details.velocity.pixelsPerSecond.dy;
    final shouldTriggerPip =
        _pipDragDistance >= _pipTriggerDistance ||
        velocity > 600; // Simple velocity threshold

    if (shouldTriggerPip) {
      // Simple haptic feedback on success
      HapticFeedback.mediumImpact();
      _resetDragState();
      _minimizeToMiniPlayer();
    } else {
      // Animate back to original position
      _animateSpringBack();
    }
  }

  void _handlePipDragCancel() {
    if (!_isPipDragging) return;
    _animateSpringBack();
  }

  /// Minimizes the current channel into the floating in-app mini player and
  /// leaves the channel screen so the user can keep browsing/switching streams.
  void _minimizeToMiniPlayer() {
    // A covered stream (or one whose labels are still being read) stays
    // here until its warning is clear.
    if (!_contentGate.allowsLeaving) return;
    if (_videoStore is! IvsVideoStore) {
      _videoStore.requestPictureInPicture();
      return;
    }
    if (_handOffToMiniPlayer()) Navigator.of(context).pop();
  }

  bool _handOffToMiniPlayer() {
    if (!_contentGate.allowsLeaving) return false;
    final store = _videoStore;
    // Only the IVS (texture) engine can hand its live player to the mini.
    if (store is! IvsVideoStore) return false;
    // Detach the channel-specific fallback so it can't fire after we pop.
    store.onFatalError = null;
    _handedOff = true;
    context.miniPlayerStore.adopt(
      player: store,
      chatTabsStore: _chatTabsStore,
      userLogin: widget.userLogin,
      userId: widget.userId,
      displayName: widget.userName,
      liveProgress: _liveProgress,
    );
    return true;
  }

  void _resetDragState() {
    setState(() {
      _isPipDragging = false;
      _pipDragDistance = 0;
      _isInPipTriggerZone = false;
    });
  }

  void _animateSpringBack() {
    _springBackAnimation = Tween<double>(begin: _pipDragDistance, end: 0)
        .animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _animationController.reset();
    _animationController.forward().then((_) {
      _resetDragState();
    });
  }

  void _scheduleSystemUiModeSync({required bool immersive}) {
    if (_isImmersiveSystemUiEnabled == immersive) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isImmersiveSystemUiEnabled == immersive) return;

      _isImmersiveSystemUiEnabled = immersive;

      if (immersive) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: SystemUiOverlay.values,
        );
      }
    });
  }

  /// Wraps a video widget with PiP swipe-down gesture handling.
  ///
  /// Provides visual feedback (translate + scale), haptic feedback,
  /// and an instructional overlay during the drag gesture.
  Widget _buildPipGestureWrapper({required Widget child, double? aspectRatio}) {
    final wrappedChild = aspectRatio != null
        ? AspectRatio(aspectRatio: aspectRatio, child: child)
        : child;

    return AnimatedBuilder(
      animation: _animationController,
      child: wrappedChild,
      builder: (context, animatedChild) {
        final currentDragDistance = _isPipDragging
            ? _pipDragDistance
            : _springBackAnimation.value;

        final scaleFactor =
            1.0 - (currentDragDistance / _pipMaxDragDistance * 0.1);

        return Transform.translate(
          offset: Offset(0, currentDragDistance),
          child: Transform.scale(
            scale: scaleFactor.clamp(0.9, 1.0),
            child: Stack(
              children: [
                GestureDetector(
                  onPanStart: _handlePipDragStart,
                  onPanUpdate: _handlePipDragUpdate,
                  onPanEnd: _handlePipDragEnd,
                  onPanCancel: _handlePipDragCancel,
                  child: animatedChild,
                ),
                if (!_videoStore.isInPipMode)
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: !(_isPipDragging && _pipDragDistance > 0),
                      child: AnimatedOpacity(
                        opacity: (_isPipDragging && _pipDragDistance > 0)
                            ? 1.0
                            : 0.0,
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOut,
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.4),
                          child: Center(
                            child: Text(
                              context.l10n.channelSwipeDownForPip,
                              textAlign: TextAlign.center,
                              style: context.textTheme.bodyLarge?.copyWith(
                                color: context.onsetColors.overlayOnSurface,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  StreamSubscription<void>? _entitlementChanges;

  StreamSubscription<ShoutoutNotice>? _shoutouts;

  StreamSubscription<StreamPush>? _streamPushes;

  StreamSubscription<CreatorGoal>? _goalsReached;
  StreamSubscription<WatchStreakChange>? _streakChanges;

  StreamSubscription<DropCampaign>? _communityDrops;
  StreamSubscription<CommunityMoment>? _communityMoments;
  StreamSubscription<PrivateCallout>? _privateCallouts;
  StreamSubscription<PredictionWin>? _predictionWins;

  void _showPrivateCallout(PrivateCallout callout) {
    final l = L10n.current;
    final url = callout.actionUrl;
    _primaryChatStore?.addLocalNotice(
      l.privateCalloutLine(body: callout.body),
      actionLabel: url == null
          ? null
          : callout.actionLabel ?? l.privateCalloutOpen,
      onAction: url == null
          ? null
          : () => LinkRouter.open(
              url.toString(),
              launchExternal: false,
              confirm: true,
            ),
    );
  }

  void _showPredictionWin(PredictionWin win) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(context.l10n.predictionWon(count: win.points))),
    );
  }

  void _showWatchStreakChange(WatchStreakChange change) {
    if (!mounted) return;
    final text = watchStreakChangeText(
      change,
      streak: _eventsStore.watchStreak,
      l: context.l10n,
    );
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(text)));
  }

  void _showGoalReached(CreatorGoal goal) {
    if (!mounted) return;
    final presentation = goalReachedPresentation(
      routeCurrent: ModalRoute.of(context)?.isCurrent ?? false,
      resumed:
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
      pip: _videoStore.isInPipMode,
      fullScreen: context.isLandscape,
      typing: _chatStore.textFieldFocusNode.hasFocus,
    );
    switch (presentation) {
      case GoalReachedPresentation.none:
        return;
      case GoalReachedPresentation.notice:
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(context.l10n.goalReachedTitle),
            action: SnackBarAction(
              label: context.l10n.goalReachedDetails,
              onPressed: () => unawaited(showCreatorGoalDetails(context, goal)),
            ),
          ),
        );
      case GoalReachedPresentation.dialog:
        unawaited(showCreatorGoalDetails(context, goal));
    }
  }

  void _applyStreamPush(StreamPush push) {
    if (_videoStore case final StreamPushTarget target) {
      target.applyStreamPush(push);
    }
  }

  void _showShoutout(ShoutoutNotice shoutout) {
    for (final tab in _chatTabsStore.tabs) {
      final chat = tab.chatStore;
      if (chat != null && chat.channelId == widget.userId) {
        chat.addShoutout(shoutout);
      }
    }
  }

  void _refreshEmotesOfEveryTab() {
    for (final tab in _chatTabsStore.tabs) {
      tab.chatStore?.scheduleEmoteRefresh();
    }
  }

  /// Convenience getter for the currently active chat store.
  ChatStore get _chatStore => _chatTabsStore.activeChatStore;

  /// Cycles the landscape chat display the way the Twitch app does on a
  /// double-tap of the video: chat overlay → side column → hidden → overlay.
  void _cycleLandscapeChatMode() {
    HapticFeedback.lightImpact();
    _chatCycle.next();
    announce(context, _chatCycle.current.label(context.l10n));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Portrait has one layout: the double tap's side column ends there.
    if (context.isPortrait) _chatCycle.reset();
  }

  @override
  Widget build(BuildContext context) {
    _landscape = context.isLandscape;
    final settingsStore = _chatTabsStore.settingsStore;

    final store = _videoStore;
    // Its own layer: nothing drawn over it (controls, chat, the latency
    // pill) makes the picture repaint.
    final player = PanelAvoidTarget(
      holder: _panelAvoid,
      child: RepaintBoundary(
        child: GestureDetector(
          onLongPress: _videoStore.handleToggleOverlay,
          child: store is IvsVideoStore
              ? IvsTextureVideo(key: _videoKey, videoStore: store)
              : store is NativeVideoStore
              ? NativeVideo(key: _videoKey, videoStore: store)
              : Video(key: _videoKey, videoStore: store as VideoStore),
        ),
      ),
    );

    final gestures = GestureDetector(
      onLongPress: _videoStore.handleToggleOverlay,
      onDoubleTap: context.isLandscape ? _cycleLandscapeChatMode : null,
      onTap: () {
        // The end of a pinch is not a tap.
        if (_pinching.value) return;
        if (_chatStore.assetsStore.showEmoteMenu) {
          _chatStore.assetsStore.showEmoteMenu = false;
        } else {
          if (_chatStore.textFieldFocusNode.hasFocus) {
            _chatStore.unfocusInput();
          } else {
            _videoStore.handleVideoTap();
          }
        }
      },
      child: Observer(
        builder: (_) {
          final videoOverlay = VideoOverlay(
            videoStore: _videoStore,
            chatStore: _chatStore,
            settingsStore: settingsStore,
            onLongPressStats: _eventsStore.playPreviewCelebration,
            latestBroadcast: _latestBroadcast,
            onOpenFollowedChannels: _hasFollowedDrawer
                ? () => _scaffoldKey.currentState?.openDrawer()
                : null,
          );

          if (_videoStore.paused || _videoStore.streamInfo == null) {
            return videoOverlay;
          }

          return AnimatedOpacity(
            opacity: _videoStore.overlayVisible ? 1.0 : 0.0,
            curve: Curves.ease,
            duration: const Duration(milliseconds: 200),
            child: ColoredBox(
              color: Colors.transparent,
              child: IgnorePointer(
                ignoring: !_videoStore.overlayVisible,
                child: videoOverlay,
              ),
            ),
          );
        },
      ),
    );

    final overlayGestures = Observer(
      builder: (context) => VideoSurfaceSemantics(
        controlsVisible: _videoStore.overlayVisible,
        actions: {
          if (context.isLandscape)
            context.l10n.playerChangeChatLayout: _cycleLandscapeChatMode,
        },
        child: gestures,
      ),
    );

    // Landscape, the IVS picture can be pinched to fill or fit the screen.
    final overlay = store is IvsVideoStore && context.isLandscape
        ? PinchToFill(
            onPinch: store.setFillScreen,
            pinching: _pinching,
            child: overlayGestures,
          )
        : overlayGestures;

    // The latency stays over the video whether the controls show or not
    // (always readable, never under a menu), where
    // their top row leaves it room.
    final metrics = PlayerChromeMetrics.of(context);
    final chrome = Stack(
      fit: StackFit.expand,
      children: [
        overlay,
        Positioned(
          top: metrics.pillTop,
          right: metrics.pillEdge,
          child: Observer(
            builder: (context) {
              final show =
                  settingsStore.showLatency &&
                  _videoStore.streamInfo != null &&
                  !_videoStore.isInPipMode;
              if (!show) return const SizedBox.shrink();
              // While the controls are hidden a tap there brings them
              // back, as anywhere on the video; then it opens the stats.
              final controlsShown =
                  _videoStore.overlayVisible || _videoStore.paused;
              return IgnorePointer(
                ignoring: !controlsShown,
                child: LatencyPill(store: _videoStore, large: metrics.large),
              );
            },
          ),
        ),
      ],
    );

    // The IVS video stats, over the video under the controls' top row, in
    // every layout (the pill toggles them).
    final statsLayer = Observer(
      builder: (context) {
        if (_videoStore case final IvsVideoStore ivs
            when ivs.statsVisible && !ivs.isInPipMode) {
          return IgnorePointer(
            child: Padding(
              padding: EdgeInsets.fromLTRB(8, metrics.top + 44, 8, 8),
              child: Align(
                alignment: Alignment.topLeft,
                child: IvsStatsPanel(store: ivs),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );

    Widget gated(Widget child) => Observer(
      builder: (_) => ContentWarningGate(
        key: _contentGateKey,
        userId: widget.userId,
        displayName: widget.userName,
        onStateChanged: _onContentGate,
        onAccepted: _onContentAccepted,
        liveLabels: _eventsStore.contentLabels,
        paidPromotion: _eventsStore.paidPromotion,
        child: child,
      ),
    );

    final video = gated(
      Observer(
        builder: (context) {
          return Stack(
            children: [
              player,
              // Twitch's own warning left in the web player gets the taps.
              if (_videoStore.settingsStore.showOverlay && !_webGateUp) chrome,
              ChannelVideoTopOverlay(
                hypeTrain: _hypeTrainStore,
                highlights: _highlightsStore,
                settingsStore: settingsStore,
                onWatchRaid: _departToRaid,
                pinnedMessage: _pinnedMessage,
              ),
              Positioned.fill(child: statsLayer),
              // Over the picture only, under the content warning: it
              // hides nothing the warning covers and never plays a stream.
              Positioned.fill(
                child: RaidOverlayLayer(
                  departure: _departure.current,
                  arrival: _arrival,
                  inPip: _videoStore.isInPipMode,
                ),
              ),
              if (_freePreview case final preview?
                  when !_videoStore.isInPipMode)
                Positioned.fill(
                  child: FreePreviewLayer(
                    controller: preview,
                    name: getReadableName(widget.userName, widget.userLogin),
                    login: widget.userLogin,
                    onUseWebPlayer: () => _useWebPlayer?.call(),
                  ),
                ),
            ],
          );
        },
      ),
    );

    final chat = Observer(
      builder: (context) {
        final bool chatOnly = !settingsStore.showVideo;

        return Stack(
          children: [
            // Its own layer: messages arriving never repaint the video.
            RepaintBoundary(
              child: ChatTabs(
                key: _chatKey,
                chatTabsStore: _chatTabsStore,
                // In chat-only mode, account for the blurred AppBar height
                listPadding: chatOnly
                    ? EdgeInsets.only(top: context.safePaddingTop)
                    : null,
              ),
            ),
            ChannelChatTopOverlay(
              hypeTrain: _hypeTrainStore,
              highlights: _highlightsStore,
              onWatchRaid: _departToRaid,
              pinnedMessage: _pinnedMessage,
              settingsStore: settingsStore,
              chatTabsStore: _chatTabsStore,
              chatInputFocus: _chatStore.textFieldFocusNode,
              bottomBarHeight: _chatStore.bottomBarHeight,
              goals: () => _eventsStore.goals,
            ),
            Observer(
              builder: (_) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _chatStore.notification != null
                    ? Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: EdgeInsets.only(
                            top: chatOnly ? context.safePaddingTop : 0,
                          ),
                          child: OnsetNotification(
                            message: _chatStore.notification!,
                            onDismissed: _chatStore.clearNotification,
                            // Full screen in landscape: the chat (overlay
                            // or column) is drawn over the video.
                            overVideo:
                                !chatOnly &&
                                settingsStore.fullScreen &&
                                context.isLandscape,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          ],
        );
      },
    );

    final videoChat = Observer(
      builder: (context) {
        _scheduleSystemUiModeSync(
          immersive:
              context.isLandscape && !settingsStore.landscapeForceVerticalChat,
        );

        // Build a blurred AppBar when in chat-only mode (no video)
        PreferredSizeWidget? chatOnlyBlurredAppBar;
        if (!settingsStore.showVideo) {
          final streamInfo = _videoStore.streamInfo;

          chatOnlyBlurredAppBar = AppBar(
            centerTitle: false,
            elevation: 0,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            title: StreamInfoBar(
              streamInfo: streamInfo,
              offlineChannelInfo: _videoStore.offlineChannelInfo,
              displayName: _chatStore.displayName,
              isCompact: true,
              isOffline: streamInfo == null,
              isInSharedChatMode: _chatStore.isInSharedChatMode,
              showTextShadows: false,
              onTapChannel: () => ChannelProfileScreen.open(
                context,
                login: widget.userLogin,
                displayName: widget.userName,
                fromChannel: true,
              ),
            ),
            actions: [
              IconButton(
                tooltip: context.l10n.channelVideos,
                icon: const Icon(Icons.video_library_outlined),
                onPressed: () => ChannelVideosScreen.open(
                  context,
                  userLogin: widget.userLogin,
                  displayName: widget.userName,
                ),
              ),
            ],
            flexibleSpace: BlurredContainer(
              gradientDirection: GradientDirection.up,
              child: const SizedBox.expand(),
            ),
          );
        }

        return Scaffold(
          key: _scaffoldKey,
          drawer: _hasFollowedDrawer
              ? FollowedChannelsDrawer(currentLogin: widget.userLogin)
              : null,
          drawerEnableOpenDragGesture: false,
          extendBody: true,
          extendBodyBehindAppBar: true,
          appBar: chatOnlyBlurredAppBar,
          body: Observer(
            builder: (context) {
              if (context.isLandscape &&
                  !settingsStore.landscapeForceVerticalChat) {
                // Read here, not in the LayoutBuilder below: the Observer
                // only tracks what its own build reads.
                final plainSide = _chatCycle.plainSide;
                final landscapeChat = AnimatedContainer(
                  curve: Curves.ease,
                  duration: _isDividerDragging
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  width: _chatStore.expandChat
                      ? context.screenWidth / 2
                      : context.screenWidth * settingsStore.chatWidth,
                  color: settingsStore.fullScreen
                      ? Colors.black.withValues(
                          alpha: settingsStore.fullScreenChatOverlayOpacity,
                        )
                      : context.scaffoldColor,
                  child: chat,
                );

                final overlayChat = Visibility(
                  visible: settingsStore.fullScreenChatOverlay,
                  maintainState: true,
                  child: OverlayChatScope(
                    child: Theme(
                      data: OnsetThemes(
                        colorSchemeSeed: Color(settingsStore.accentColor),
                      ).dark,
                      child: DefaultTextStyle(
                        style: context.defaultTextStyle.copyWith(
                          color: context.onsetColors.overlayOnSurface,
                        ),
                        child: OverlayChatFrame(
                          width: _chatStore.expandChat
                              ? context.screenWidth / 2
                              : context.screenWidth * settingsStore.chatWidth,
                          placement: OverlayChatPlacement.clamped(
                            top: settingsStore.overlayChatTop,
                            height: settingsStore.overlayChatHeight,
                          ),
                          showHandles: _videoStore.overlayVisible,
                          leftSide: settingsStore.landscapeChatLeftSide,
                          onPlacementChanged: (placement) {
                            settingsStore
                              ..overlayChatTop = placement.top
                              ..overlayChatHeight = placement.height;
                          },
                          onLeftSideChanged: (left) =>
                              settingsStore.landscapeChatLeftSide = left,
                          child: landscapeChat,
                        ),
                      ),
                    ),
                  ),
                );

                return ColoredBox(
                  color: settingsStore.showVideo
                      ? Colors.black
                      : context.scaffoldColor,
                  child: settingsStore.showVideo
                      ? settingsStore.fullScreen
                            // Under the content warning like every layout:
                            // full screen is a saved choice, a channel can
                            // open straight into it.
                            ? gated(
                                Stack(
                                  children: [
                                    _buildPipGestureWrapper(child: player),
                                    if (settingsStore.showOverlay)
                                      LayoutBuilder(
                                        builder: (context, constraints) {
                                          final totalWidth =
                                              constraints.maxWidth;
                                          final placement =
                                              OverlayChatPlacement.clamped(
                                                top: settingsStore
                                                    .overlayChatTop,
                                                height: settingsStore
                                                    .overlayChatHeight,
                                              );
                                          final chatWidth =
                                              _chatStore.expandChat
                                              ? 0.5
                                              : settingsStore.chatWidth;

                                          final draggableDivider = Observer(
                                            builder: (_) => DraggableDivider(
                                              currentWidth: chatWidth,
                                              maxWidth: 0.6,
                                              isResizableOnLeft: settingsStore
                                                  .landscapeChatLeftSide,
                                              showHandle:
                                                  _videoStore.overlayVisible &&
                                                  settingsStore
                                                      .fullScreenChatOverlay,
                                              onDragStart: () {
                                                setState(() {
                                                  _isDividerDragging = true;
                                                });
                                              },
                                              onDrag: (newWidth) {
                                                if (!_chatStore.expandChat) {
                                                  settingsStore.chatWidth =
                                                      newWidth;
                                                }
                                              },
                                              onDragEnd: () {
                                                setState(() {
                                                  _isDividerDragging = false;
                                                });
                                              },
                                            ),
                                          );

                                          return Stack(
                                            children: [
                                              Row(
                                                children:
                                                    settingsStore
                                                        .landscapeChatLeftSide
                                                    ? [
                                                        overlayChat,
                                                        Expanded(
                                                          child: Stack(
                                                            fit:
                                                                StackFit.expand,
                                                            children: [
                                                              chrome,
                                                              statsLayer,
                                                            ],
                                                          ),
                                                        ),
                                                      ]
                                                    : [
                                                        Expanded(
                                                          child: Stack(
                                                            fit:
                                                                StackFit.expand,
                                                            children: [
                                                              chrome,
                                                              statsLayer,
                                                            ],
                                                          ),
                                                        ),
                                                        overlayChat,
                                                      ],
                                              ),
                                              if (settingsStore
                                                  .fullScreenChatOverlay)
                                                Positioned(
                                                  top:
                                                      constraints.maxHeight *
                                                      placement.top,
                                                  height:
                                                      constraints.maxHeight *
                                                      placement.height,
                                                  left:
                                                      settingsStore
                                                          .landscapeChatLeftSide
                                                      ? (totalWidth *
                                                                chatWidth) -
                                                            12
                                                      : null,
                                                  right:
                                                      !settingsStore
                                                          .landscapeChatLeftSide
                                                      ? (totalWidth *
                                                                chatWidth) -
                                                            12
                                                      : null,
                                                  child: draggableDivider,
                                                ),
                                            ],
                                          );
                                        },
                                      ),
                                    // Hidden chat: the hype train and the
                                    // highlights as pills.
                                    ChannelVideoTopOverlay(
                                      hypeTrain: _hypeTrainStore,
                                      highlights: _highlightsStore,
                                      settingsStore: settingsStore,
                                      onWatchRaid: _departToRaid,
                                      pinnedMessage: _pinnedMessage,
                                    ),
                                  ],
                                ),
                              )
                            : SafeArea(
                                bottom: false,
                                left:
                                    settingsStore.landscapeCutout !=
                                        LandscapeCutoutType.left &&
                                    settingsStore.landscapeCutout !=
                                        LandscapeCutoutType.both,
                                right:
                                    settingsStore.landscapeCutout !=
                                        LandscapeCutoutType.right &&
                                    settingsStore.landscapeCutout !=
                                        LandscapeCutoutType.both,
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final availableWidth = constraints.maxWidth;
                                    final chatWidth = _chatStore.expandChat
                                        ? 0.5
                                        : settingsStore.chatWidth;

                                    // A tablet puts its info area under the
                                    // video and a header on its chat.
                                    final tablet = context.isLargeScreen;

                                    // Create the landscape chat container with proper styling
                                    final chatContainer = AnimatedContainer(
                                      curve: Curves.ease,
                                      duration: _isDividerDragging
                                          ? Duration.zero
                                          : const Duration(milliseconds: 200),
                                      width: availableWidth * chatWidth,
                                      color: settingsStore.fullScreen
                                          ? Colors.black.withValues(
                                              alpha: settingsStore
                                                  .fullScreenChatOverlayOpacity,
                                            )
                                          : tablet &&
                                                context.theme.brightness ==
                                                    Brightness.dark
                                          ? _tabletChatColor
                                          : context.scaffoldColor,
                                      child: tablet
                                          ? _buildTabletChat(
                                              chat,
                                              settingsStore,
                                            )
                                          : chat,
                                    );

                                    final draggableDivider = Observer(
                                      builder: (_) => DraggableDivider(
                                        currentWidth: chatWidth,
                                        maxWidth: 0.6,
                                        isResizableOnLeft:
                                            settingsStore.landscapeChatLeftSide,
                                        showHandle: _videoStore.overlayVisible,
                                        onDragStart: () {
                                          setState(() {
                                            _isDividerDragging = true;
                                          });
                                        },
                                        onDrag: (newWidth) {
                                          if (!_chatStore.expandChat) {
                                            settingsStore.chatWidth = newWidth;
                                          }
                                        },
                                        onDragEnd: () {
                                          setState(() {
                                            _isDividerDragging = false;
                                          });
                                        },
                                      ),
                                    );

                                    return Stack(
                                      children: [
                                        Row(
                                          children:
                                              settingsStore
                                                  .landscapeChatLeftSide
                                              ? [
                                                  chatContainer,
                                                  Expanded(
                                                    child: tablet
                                                        ? _buildTabletVideoColumn(
                                                            video,
                                                            infoArea:
                                                                !plainSide,
                                                          )
                                                        : _buildPipGestureWrapper(
                                                            child: video,
                                                          ),
                                                  ),
                                                ]
                                              : [
                                                  Expanded(
                                                    child: tablet
                                                        ? _buildTabletVideoColumn(
                                                            video,
                                                            infoArea:
                                                                !plainSide,
                                                          )
                                                        : _buildPipGestureWrapper(
                                                            child: video,
                                                          ),
                                                  ),
                                                  chatContainer,
                                                ],
                                        ),
                                        Positioned(
                                          top: 0,
                                          bottom: 0,
                                          left:
                                              settingsStore
                                                  .landscapeChatLeftSide
                                              ? (availableWidth * chatWidth) -
                                                    12
                                              : null,
                                          right:
                                              !settingsStore
                                                  .landscapeChatLeftSide
                                              ? (availableWidth * chatWidth) -
                                                    12
                                              : null,
                                          child: draggableDivider,
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              )
                      : SafeArea(child: chat),
                );
              }
              // Read here, not in the LayoutBuilder below: the Observer only
              // tracks what its own build reads.
              final videoScale = settingsStore.portraitVideoScale;
              final chatHeight = settingsStore.portraitChatHeight;
              // What the SafeArea below takes at the top: inside it the
              // padding reads 0, and the video starts under it.
              final safeTop = MediaQuery.paddingOf(context).top;
              return SafeArea(
                // Keep chat-only scrolling under the blurred app bar, but
                // ensure video does not bleed into the system status bar.
                top: settingsStore.showVideo,
                bottom: false,
                child: ValueListenableBuilder(
                  valueListenable: _portraitDragScale,
                  builder: (context, dragScale, _) => LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final scale =
                          dragScale ??
                          portraitScaleFor(
                            chatHeight,
                            customScale: videoScale,
                            width: width,
                          );
                      final videoHeight = portraitVideoHeight(width, scale);
                      final large = context.isLargeScreen;
                      // On a phone, sheets start under the video so the
                      // live and its latency stay in view.
                      return SheetsUnderVideo(
                        top:
                            settingsStore.showVideo &&
                                context.isPortrait &&
                                !large
                            ? safeTop + videoHeight
                            : null,
                        child: Stack(
                          children: [
                            Column(
                              children: [
                                if (settingsStore.showVideo) ...[
                                  // Placeholder for video space
                                  SizedBox(height: videoHeight),
                                  PortraitSplitHandle(
                                    width: width,
                                    scale: scale,
                                    onChanged: (scale) =>
                                        _portraitDragScale.value = scale,
                                    onChangeEnd: (scale) {
                                      settingsStore
                                        ..portraitVideoScale = scale
                                        ..portraitChatHeight =
                                            portraitChatHeightAfterDrag(scale);
                                      _portraitDragScale.value = null;
                                    },
                                  ),
                                  // The channel under the video.
                                  ChannelInfoRow(
                                    player: _videoStore,
                                    login: widget.userLogin,
                                    displayName: widget.userName,
                                    info: _infoStore,
                                    viewerLogin: _viewerLogin,
                                    onOpenProfile: _openProfile,
                                    large: large,
                                  ),
                                ],
                                Expanded(child: chat),
                              ],
                            ),
                            if (settingsStore.showVideo)
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: videoHeight,
                                child: Center(
                                  child: SizedBox(
                                    width: videoHeight * 16 / 9,
                                    child: _buildPipGestureWrapper(
                                      child: video,
                                      aspectRatio: 16 / 9,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    // Celebrations float over everything, including the player, and never take
    // a tap. Wrapping here rather than inside the layout keeps the existing
    // composition untouched: with no celebration playing this Stack has a
    // single child and costs nothing.
    final celebratedVideoChat = Provider<ChannelEventsStore>.value(
      // Provided rather than passed down: the chat bottom bar is three widgets
      // deep, and threading a store through ChatTabs and ChatBottomBar purely
      // to show a balance would couple every layer in between to it.
      value: _eventsStore,
      child: Stack(
        children: [
          Positioned.fill(
            child: PanelAvoidScope(
              holder: _panelAvoid,
              // Above the Scaffold, which removes the keyboard from its body.
              child: ChannelKeyboardScope(child: videoChat),
            ),
          ),
          Positioned.fill(child: CelebrationOverlay(store: _eventsStore)),
        ],
      ),
    );

    // If on Android, use PiPSwitcher to enable PiP functionality.
    if (Platform.isAndroid) {
      return PipWidget(
        key: _pipKey,
        pipLayout: PipActionsLayout.mediaOnlyPause,
        // Nothing plays from the PiP window behind the content warning.
        onPipAction: (_) => pipPlayPause(_videoStore),
        onPipEntered: () {
          // The PiP window shows the player alone: a celebration playing
          // over the channel is over, not kept to replay on the way back.
          _eventsStore.clearCelebration();
          final store = _videoStore;
          if (store is IvsVideoStore) store.onPipEntered();
        },
        onPipExited: () {
          final store = _videoStore;
          if (store is IvsVideoStore) store.onPipExited();
        },
        pipChild: player,
        child: celebratedVideoChat,
      );
    }

    return celebratedVideoChat;
  }

  @override
  void dispose() {
    _restoreVideoAfterChatOnlyStart();
    // Remove observer for app lifecycle events
    WidgetsBinding.instance.removeObserver(this);

    PlaybackFocus.shared.release(this);

    // Reads the position before the player below is disposed. A player
    // handed to the mini window takes its tracker along.
    if (!_handedOff) unawaited(_liveProgress.close());

    // Always: the mini window shows no hype train or highlights, and
    // restoring the channel builds new stores (which refetch).
    _streamEndReaction?.call();
    _hypeTrainSettingReaction?.call();
    _hypeTrainStore?.dispose();
    _highlightsSettingReaction?.call();
    _giftBombFeed?.call();
    _incomingRaidFeed?.call();
    _raidCancelFeed?.call();
    unawaited(_newPins?.cancel());
    _highlightsStore?.dispose();
    _subtleCelebrations?.call();
    _departure.dispose();
    _arrivalTimer?.cancel();
    // Always disposed, even on hand-off to the mini window: the mini player
    // shows no hype train or celebration, and leaving the socket open would
    // keep a channel's events flowing after leaving it.
    unawaited(_entitlementChanges?.cancel());
    unawaited(_shoutouts?.cancel());
    unawaited(_streamPushes?.cancel());
    unawaited(_goalsReached?.cancel());
    unawaited(_streakChanges?.cancel());
    unawaited(_communityDrops?.cancel());
    unawaited(_communityMoments?.cancel());
    unawaited(_privateCallouts?.cancel());
    unawaited(_predictionWins?.cancel());
    _eventsStore.dispose();
    _viewerReaction?.call();
    _followPrompts.dispose();
    _freePreview?.dispose();
    _infoStore.dispose();

    // Skip disposal when handed to the mini window — the player and the live
    // chat (with its history) live on there.
    if (!_handedOff) {
      _chatTabsStore.dispose();
      _videoStore.dispose();
    }

    _animationController.dispose();
    _pinching.dispose();
    _chatCycle.dispose();
    _portraitDragScale.dispose();

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    SystemChrome.setPreferredOrientations([]);

    _alive.remove(this);
    if (_alive.isNotEmpty) _alive.last._reassertAfterReplaced();

    super.dispose();
  }
}
