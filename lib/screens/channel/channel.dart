import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/models/community_highlights.dart';
import 'package:frosty/screens/channel/channel_top_overlays.dart';
import 'package:frosty/screens/channel/chat/stores/chat_store.dart';
import 'package:frosty/screens/channel/chat/stores/chat_tabs_store.dart';
import 'package:frosty/screens/channel/chat/widgets/chat_tabs.dart';
import 'package:frosty/screens/channel/community_highlights/stores/community_highlights_store.dart';
import 'package:frosty/screens/channel/community_highlights/widgets/pinned_chat_text.dart';
import 'package:frosty/screens/channel/hype_train/stores/hype_train_store.dart';
import 'package:frosty/screens/channel/portrait_split.dart';
import 'package:frosty/screens/channel/video/ivs_stats_panel.dart';
import 'package:frosty/screens/channel/video/ivs_video.dart';
import 'package:frosty/screens/channel/video/native_video.dart';
import 'package:frosty/screens/channel/video/overlay_common.dart';
import 'package:frosty/screens/channel/video/pinch_to_fill.dart';
import 'package:frosty/screens/channel/video/player_controller.dart';
import 'package:frosty/screens/channel/video/player_engine_resolver.dart';
import 'package:frosty/screens/channel/video/stores/ivs_video_store.dart';
import 'package:frosty/screens/channel/video/stores/native_video_store.dart';
import 'package:frosty/screens/channel/video/stream_info_bar.dart';
import 'package:frosty/screens/channel/video/video.dart';
import 'package:frosty/screens/channel/video/video_overlay.dart';
import 'package:frosty/screens/channel/video/video_store.dart';
import 'package:frosty/screens/channel_profile/channel_profile_screen.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/vod/channel_videos.dart';
import 'package:frosty/services/playback_focus.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/utils/pip_callbacks.dart';
import 'package:frosty/widgets/blurred_container.dart';
import 'package:frosty/widgets/draggable_divider.dart';
import 'package:frosty/widgets/frosty_notification.dart';
import 'package:mobx/mobx.dart';
import 'package:simple_pip_mode/actions/pip_actions_layout.dart';
import 'package:simple_pip_mode/pip_widget.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Creates a widget that shows the video stream (if live) and chat of the given user.
class VideoChat extends StatefulWidget {
  static const routeName = 'VideoChat';

  final String userId;
  final String userName;
  final String userLogin;

  const VideoChat({
    super.key,
    required this.userId,
    required this.userName,
    required this.userLogin,
  });

  @override
  State<VideoChat> createState() => _VideoChatState();
}

class _VideoChatState extends State<VideoChat>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _videoKey = GlobalKey();
  final _chatKey = GlobalKey();

  // PiP drag state - essential only
  double _pipDragDistance = 0;
  bool _isPipDragging = false;

  /// Two fingers on the landscape video: the swipe to picture-in-picture
  /// and the tap stand down (see [PinchToFill]).
  final _pinching = ValueNotifier(false);

  /// The portrait video size while its handle is dragged; saved to the
  /// settings once, when the drag ends.
  final _portraitDragScale = ValueNotifier<double?>(null);
  bool _isInPipTriggerZone =
      false; // Track when in trigger zone for haptic feedback

  // Divider drag state for synchronizing animation
  bool _isDividerDragging = false;

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
  bool _adoptionResolved = false;

  void _resolveAdoption() {
    if (_adoptionResolved) return;
    _adoptionResolved = true;
    final mini = context.miniPlayerStore;
    if (mini.visible && mini.userLogin == widget.userLogin) {
      final released = mini.release();
      _adoptedPlayer = released.player;
      _adoptedChat = released.chat;
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
          primaryChannelId: widget.userId,
          primaryChannelLogin: widget.userLogin,
          primaryDisplayName: widget.userName,
        );
  }();

  late PlayerController _videoStore = _buildPlayerController();

  /// True once the live player has been handed to the mini window, so this
  /// screen must not dispose it when it pops.
  bool _handedOff = false;

  /// The primary (video) channel's hype train, whatever chat tab is open;
  /// null while the setting is off. Never handed to the mini window.
  HypeTrainStore? _hypeTrainStore;
  ReactionDisposer? _hypeTrainSettingReaction;

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

  void _syncHighlightsStore() {
    final show = context.settingsStore.showCommunityHighlights;
    if (show && _highlightsStore == null) {
      // Read from the window: no inherited lookups in initState.
      final view = WidgetsBinding.instance.platformDispatcher.implicitView;
      _highlightsStore = CommunityHighlightsStore(
        channelId: widget.userId,
        channelLogin: widget.userLogin,
        service: context.twitchCommunityHighlightsService,
        realtime: context.realtimeClient,
        expandNew:
            view != null &&
            isLargeScreenSize(view.physicalSize / view.devicePixelRatio),
      );
    } else if (!show && _highlightsStore != null) {
      _highlightsStore!.dispose();
      _highlightsStore = null;
    }
  }

  /// "Watch" on an outgoing raid: the target replaces this channel.
  void _watchRaid(OutgoingRaid raid) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        settings: const RouteSettings(name: VideoChat.routeName),
        builder: (context) => VideoChat(
          userId: raid.targetId,
          userName: raid.targetDisplayName,
          userLogin: raid.targetLogin,
        ),
      ),
    );
  }

  /// A pinned message as the video channel's chat shows it (badges, colour,
  /// Twitch and 7TV/BTTV/FFZ emotes); plain text until that chat is up.
  Widget? _pinnedMessage(BuildContext context, PinnedChatMessage pin) {
    final chat = _chatTabsStore.tabs
        .where((tab) => tab.isPrimary)
        .firstOrNull
        ?.chatStore;
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

  @override
  void initState() {
    super.initState();
    _alive.add(this);

    // Build the player first — this adopts the live player back from the mini
    // window when we're restoring this same channel (seamless, no reload).
    final store = _videoStore;

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

    // If the native engine fails to load the stream (offline, geo-block, or a
    // Twitch API change), fall back to the WebView engine for this session so
    // the player never dies silently.
    void fallbackToWeb() {
      // Only once, and only for the store this callback was attached to.
      if (!mounted || !identical(_videoStore, store)) return;
      setState(() {
        store.dispose();
        _videoStore = _buildPlayerController(forceWeb: true);
      });
    }

    if (store is NativeVideoStore) {
      store.ready.catchError((Object _) => fallbackToWeb());
    } else if (store is IvsVideoStore) {
      store.onFatalError = fallbackToWeb;
      store.ready.catchError((Object _) => fallbackToWeb());
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
    _syncHighlightsStore();
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      _videoStore.handleAppResume();
      _hypeTrainStore?.handleAppResume();
    }
  }

  void _handlePipDragStart(DragStartDetails details) {
    // Disable drag gesture when already in PiP mode or video is not playing
    if (_videoStore.isInPipMode || _videoStore.paused || _pinching.value) {
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
    final store = _videoStore;
    // Only the IVS (texture) engine can hand its live player to the mini.
    if (store is! IvsVideoStore) {
      store.requestPictureInPicture();
      return;
    }
    // Detach the channel-specific fallback so it can't fire after we pop.
    store.onFatalError = null;
    _handedOff = true;
    context.miniPlayerStore.adopt(
      player: store,
      chatTabsStore: _chatTabsStore,
      userLogin: widget.userLogin,
      userId: widget.userId,
      displayName: widget.userName,
    );
    Navigator.of(context).pop();
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
                          child: const Center(
                            child: Text(
                              'Swipe down to enter picture-in-picture',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
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

  /// Convenience getter for the currently active chat store.
  ChatStore get _chatStore => _chatTabsStore.activeChatStore;

  /// Cycles the landscape chat display the way the Twitch app does on a
  /// double-tap of the video: chat overlay → side column → hidden → overlay.
  void _cycleLandscapeChatMode() {
    final settingsStore = _chatTabsStore.settingsStore;
    HapticFeedback.lightImpact();
    if (!settingsStore.fullScreen) {
      // Column → Hidden
      settingsStore.fullScreen = true;
      settingsStore.fullScreenChatOverlay = false;
    } else if (settingsStore.fullScreenChatOverlay) {
      // Overlay → Column
      settingsStore.fullScreen = false;
      if (context.isLargeScreen) releaseOrientationLock();
    } else {
      // Hidden → Overlay
      settingsStore.fullScreenChatOverlay = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsStore = _chatTabsStore.settingsStore;

    final store = _videoStore;
    final player = GestureDetector(
      onLongPress: _videoStore.handleToggleOverlay,
      child: store is IvsVideoStore
          ? IvsTextureVideo(key: _videoKey, videoStore: store)
          : store is NativeVideoStore
              ? NativeVideo(key: _videoKey, videoStore: store)
              : Video(key: _videoKey, videoStore: store as VideoStore),
    );

    final overlayGestures = GestureDetector(
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

    // Landscape, the IVS picture can be pinched to fill or fit the screen.
    final overlay = store is IvsVideoStore && context.isLandscape
        ? PinchToFill(
            onPinch: store.setFillScreen,
            pinching: _pinching,
            child: overlayGestures,
          )
        : overlayGestures;

    final video = Observer(
      builder: (context) {
        return Stack(
          children: [
            player,
            if (_videoStore.settingsStore.showOverlay) overlay,
            ChannelVideoTopOverlay(
              hypeTrain: _hypeTrainStore,
              highlights: _highlightsStore,
              settingsStore: settingsStore,
              onWatchRaid: _watchRaid,
              pinnedMessage: _pinnedMessage,
            ),
            if (_videoStore case final IvsVideoStore ivs
                when ivs.statsVisible && !ivs.isInPipMode)
              Positioned.fill(
                left: 8,
                top: 48,
                right: 8,
                bottom: 8,
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: IvsStatsPanel(store: ivs),
                  ),
                ),
              ),
          ],
        );
      },
    );

    final chat = Observer(
      builder: (context) {
        final bool chatOnly = !settingsStore.showVideo;

        return Stack(
          children: [
            ChatTabs(
              key: _chatKey,
              chatTabsStore: _chatTabsStore,
              // In chat-only mode, account for the blurred AppBar height
              listPadding: chatOnly
                  ? EdgeInsets.only(top: context.safePaddingTop)
                  : null,
            ),
            ChannelChatTopOverlay(
              hypeTrain: _hypeTrainStore,
              highlights: _highlightsStore,
              onWatchRaid: _watchRaid,
              pinnedMessage: _pinnedMessage,
              settingsStore: settingsStore,
              chatTabsStore: _chatTabsStore,
              chatInputFocus: _chatStore.textFieldFocusNode,
              bottomBarHeight: _chatStore.bottomBarHeight,
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
                          child: FrostyNotification(
                            message: _chatStore.notification!,
                            onDismissed: _chatStore.clearNotification,
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
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness:
                  context.theme.brightness == Brightness.dark
                  ? Brightness.light
                  : Brightness.dark,
            ),
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
                tooltip: 'Videos',
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
          extendBody: true,
          extendBodyBehindAppBar: true,
          appBar: chatOnlyBlurredAppBar,
          body: Observer(
            builder: (context) {
              if (context.isLandscape &&
                  !settingsStore.landscapeForceVerticalChat) {
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
                  child: Theme(
                    data: FrostyThemes(
                      colorSchemeSeed: Color(settingsStore.accentColor),
                    ).dark,
                    child: DefaultTextStyle(
                      style: context.defaultTextStyle.copyWith(
                        color: context.frostyColors.overlayOnSurface,
                      ),
                      child: landscapeChat,
                    ),
                  ),
                );

                return ColoredBox(
                  color: settingsStore.showVideo
                      ? Colors.black
                      : context.scaffoldColor,
                  child: settingsStore.showVideo
                      ? settingsStore.fullScreen
                            ? Stack(
                                children: [
                                  _buildPipGestureWrapper(child: player),
                                  if (settingsStore.showOverlay)
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        final totalWidth = constraints.maxWidth;
                                        final chatWidth = _chatStore.expandChat
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
                                                      Expanded(child: overlay),
                                                    ]
                                                  : [
                                                      Expanded(child: overlay),
                                                      overlayChat,
                                                    ],
                                            ),
                                            if (settingsStore
                                                .fullScreenChatOverlay)
                                              Positioned(
                                                top: 0,
                                                bottom: 0,
                                                left:
                                                    settingsStore
                                                        .landscapeChatLeftSide
                                                    ? (totalWidth * chatWidth) -
                                                          12
                                                    : null,
                                                right:
                                                    !settingsStore
                                                        .landscapeChatLeftSide
                                                    ? (totalWidth * chatWidth) -
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
                                    onWatchRaid: _watchRaid,
                                    pinnedMessage: _pinnedMessage,
                                  ),
                                ],
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
                                          : context.scaffoldColor,
                                      child: chat,
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
                                                    child:
                                                        _buildPipGestureWrapper(
                                                          child: video,
                                                        ),
                                                  ),
                                                ]
                                              : [
                                                  Expanded(
                                                    child:
                                                        _buildPipGestureWrapper(
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
                      final scale = dragScale ?? videoScale;
                      final videoHeight = portraitVideoHeight(width, scale);
                      return Stack(
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
                                    settingsStore.portraitVideoScale = scale;
                                    _portraitDragScale.value = null;
                                  },
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

    // If on Android, use PiPSwitcher to enable PiP functionality.
    if (Platform.isAndroid) {
      return PipWidget(
        key: _pipKey,
        pipLayout: PipActionsLayout.mediaOnlyPause,
        onPipAction: (_) => _videoStore.handlePausePlay(),
        onPipEntered: () {
          final store = _videoStore;
          if (store is IvsVideoStore) store.onPipEntered();
        },
        onPipExited: () {
          final store = _videoStore;
          if (store is IvsVideoStore) store.onPipExited();
        },
        pipChild: player,
        child: videoChat,
      );
    }

    return videoChat;
  }

  @override
  void dispose() {
    // Remove observer for app lifecycle events
    WidgetsBinding.instance.removeObserver(this);

    PlaybackFocus.shared.release(this);

    // Always: the mini window shows no hype train or highlights, and
    // restoring the channel builds new stores (which refetch).
    _hypeTrainSettingReaction?.call();
    _hypeTrainStore?.dispose();
    _highlightsSettingReaction?.call();
    _highlightsStore?.dispose();

    // Skip disposal when handed to the mini window — the player and the live
    // chat (with its history) live on there.
    if (!_handedOff) {
      _chatTabsStore.dispose();
      _videoStore.dispose();
    }

    _animationController.dispose();
    _pinching.dispose();
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
