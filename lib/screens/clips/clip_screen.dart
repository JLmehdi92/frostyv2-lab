import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/apis/twitch_account_gql_service.dart';
import 'package:onset/apis/twitch_clip_service.dart';
import 'package:onset/apis/twitch_vod_service.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/clip.dart';
import 'package:onset/models/vod.dart';
import 'package:onset/screens/channel/video/overlay_common.dart';
import 'package:onset/screens/clips/clip_download.dart';
import 'package:onset/screens/clips/clip_story_screen.dart';
import 'package:onset/screens/clips/stores/channel_clips_store.dart';
import 'package:onset/screens/clips/stores/clip_player_store.dart';
import 'package:onset/screens/clips/widgets/clip_comments_sheet.dart';
import 'package:onset/screens/clips/widgets/clip_info_panel.dart';
import 'package:onset/screens/clips/widgets/more_clips_sliver.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/vod/player_media.dart';
import 'package:onset/screens/vod/stores/vod_chat_replay_store.dart';
import 'package:onset/screens/vod/stores/web_vod_store.dart';
import 'package:onset/screens/vod/vod_overlay.dart';
import 'package:onset/screens/vod/vod_player_controller.dart';
import 'package:onset/screens/vod/vod_screen.dart';
import 'package:onset/screens/vod/widgets/video_back_button.dart';
import 'package:onset/screens/vod/widgets/video_kit.dart';
import 'package:onset/screens/vod/widgets/vod_chat_replay.dart';
import 'package:onset/screens/vod/widgets/vod_error_view.dart';
import 'package:onset/services/playback_focus.dart';
import 'package:onset/stores/mini_player_store.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/utils/pip_callbacks.dart';
import 'package:onset/widgets/alert_message.dart';
import 'package:onset/widgets/share_sheet.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/skeleton_loader.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_pip_mode/actions/pip_actions_layout.dart';
import 'package:simple_pip_mode/pip_widget.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Builds the player for a clip (tests pass a fake); [web] asks for the
/// embed fallback.
typedef ClipPlayerFactory =
    VodPlayerController Function(String slug, Clip? clip, {required bool web});

/// The public link of a clip.
String clipShareLink(String slug) => 'https://clips.twitch.tv/$slug';

/// Watches a clip inside the app: native player (media_kit), loop, quality,
/// speed, the clip's details and a jump into the full VOD.
class ClipScreen extends StatefulWidget {
  static const routeName = 'ClipScreen';

  const ClipScreen({
    super.key,
    required this.slug,
    this.clip,
    @visibleForTesting this.playerFactory,
    @visibleForTesting this.replayFactory,
  });

  /// The clip's slug (validated by the caller: links and lists).
  final String slug;

  /// Known metadata (from a list); fetched when null.
  final Clip? clip;

  final ClipPlayerFactory? playerFactory;
  final VodReplayFactory? replayFactory;

  static Future<void> open(
    BuildContext context, {
    required String slug,
    Clip? clip,
  }) => Navigator.push(
    context,
    MaterialPageRoute(
      settings: const RouteSettings(name: routeName),
      builder: (context) => ClipScreen(slug: slug, clip: clip),
    ),
  );

  @override
  State<ClipScreen> createState() => _ClipScreenState();
}

class _ClipScreenState extends State<ClipScreen> {
  late final SettingsStore _settings = context.settingsStore;
  late final TwitchClipService _service = context.twitchClipService;
  late final MiniPlayerStore _miniPlayer = context.miniPlayerStore;

  final _pipKey = GlobalKey<PipWidgetState>();

  /// One video widget moved between the portrait, landscape and PiP trees.
  final _videoKey = GlobalKey();

  Clip? _clip;

  ClipExtras? _extras;

  /// The metadata could not be loaded (null while loading or loaded).
  VodPlaybackProblem? _loadProblem;

  /// The details could not be fetched (the clip itself may still play).
  var _detailsFailed = false;

  late VodPlayerController _player;

  /// The chat of the clip's VOD, replayed in step with the clip.
  VodChatReplayStore? _replay;

  var _replayMissing = false;

  /// The channel's other clips, shown when there is no chat replay.
  ChannelClipsStore? _moreClips;
  final _disposers = <ReactionDisposer>[];

  var _fillScreen = false;
  var _forceWeb = false;
  bool? _immersive;

  /// Whether the video was playing when another player took focus.
  var _playingBeforeFocusLoss = false;

  bool get _hasFocus => identical(PlaybackFocus.shared.top, this);

  @override
  void initState() {
    super.initState();
    _clip = widget.clip;
    // One player at a time: the mini player closes and a stream or VOD
    // beneath pauses until this screen closes.
    _miniPlayer.close();
    PlaybackFocus.shared
      ..register(this, onLost: _onFocusLost, onRegained: _onFocusRegained)
      ..claim(this);
    if (_settings.keepScreenAwake) WakelockPlus.enable();
    _player = _buildPlayer();
    unawaited(_loadExtras());
    final clip = _clip;
    if (clip == null) {
      unawaited(_loadMetadata());
    } else {
      _loadMoreClips(clip);
      unawaited(_loadReplay(clip));
    }
  }

  Future<void> _loadMetadata() async {
    try {
      final clip = await _service.getClip(widget.slug);
      if (!mounted) return;
      setState(() {
        _clip = clip;
        _detailsFailed = false;
        _loadProblem = clip == null ? VodPlaybackProblem.notFound : null;
      });
      if (clip == null) {
        // Deleted: nothing must keep playing behind the message.
        _player.pause();
        return;
      }
      _loadMoreClips(clip);
      unawaited(_loadReplay(clip));
    } catch (e) {
      // The clip may still play: only the details are missing.
      debugPrint('ClipScreen metadata failed: $e');
      if (mounted) setState(() => _detailsFailed = true);
    }
  }

  Future<void> _loadExtras() async {
    try {
      final extras = await _service.getClipExtras(widget.slug);
      if (mounted && extras != null) setState(() => _extras = extras);
    } catch (e) {
      debugPrint('ClipScreen extras failed: $e');
    }
  }

  void _openPortrait(Clip clip) => unawaited(
    ClipStoryScreen.open(
      context,
      clips: [clip],
      title: clip.broadcasterDisplayName.isNotEmpty
          ? clip.broadcasterDisplayName
          : clip.broadcasterLogin,
      portrait: true,
      routeName: 'PortraitClip',
    ),
  );

  void _openComments() {
    final token = context.authStore.twitchWebToken ?? '';
    final account = context.read<TwitchAccountGqlService?>();
    final slug = widget.slug;
    unawaited(
      showOnsetSheet<void>(
        context: context,
        builder: (_) => ClipCommentsSheet(
          load: (cursor) =>
              _service.getClipComments(slug, cursor: cursor, authToken: token),
          actions: account == null || token.isEmpty
              ? null
              : ClipCommentActions(
                  eligibility: () =>
                      account.commentEligibility(slug: slug, authToken: token),
                  post: (body) => account.postComment(
                    slug: slug,
                    body: body,
                    authToken: token,
                  ),
                  setLiked: (id, liked) => account.setCommentLiked(
                    slug: slug,
                    commentId: id,
                    liked: liked,
                    authToken: token,
                  ),
                ),
        ),
      ),
    );
  }

  void _retryDetails() {
    setState(() => _detailsFailed = false);
    unawaited(_loadMetadata());
  }

  /// The VOD's chat when the VOD still exists (anonymous, best effort).
  Future<void> _loadReplay(Clip clip) async {
    final vodId = clip.vodId;
    if (_replay != null) return;
    if (vodId == null || clip.vodOffsetSeconds == null) {
      _markReplayMissing();
      return;
    }
    final vodService = context.twitchVodService;
    final Vod? vod;
    try {
      vod = await vodService.getVideo(vodId);
    } catch (e) {
      debugPrint('ClipScreen: no VOD for the chat replay: $e');
      _markReplayMissing();
      return;
    }
    if (!mounted || _replay != null) return;
    if (vod == null) {
      _markReplayMissing();
      return;
    }
    final factory = widget.replayFactory;
    setState(() {
      _replay = factory != null
          ? factory(vod!)
          : createVodChatReplay(context, vod!);
    });
    _bindReplay();
  }

  void _markReplayMissing() {
    if (mounted) setState(() => _replayMissing = true);
  }

  /// Feeds the replay the VOD second under the clip's playback.
  void _bindReplay() {
    for (final dispose in _disposers) {
      dispose();
    }
    _disposers.clear();
    final replay = _replay;
    final offset = _clip?.vodOffsetSeconds;
    if (replay == null || offset == null) return;
    final player = _player;
    _disposers
      ..add(
        reaction(
          (_) => player.positionSeconds,
          (int second) => replay.onPositionSecond(offset + second),
          fireImmediately: true,
        ),
      )
      ..add(
        reaction(
          (_) => player.playbackRate,
          (double rate) => replay.playbackRate = rate,
          fireImmediately: true,
        ),
      );
  }

  VodPlayerController _buildPlayer() {
    final player = _createPlayer();
    // A player built while another one is on top must stay silent.
    if (!_hasFocus) player.setFocused(false);
    return player;
  }

  /// The native media_kit player, or the Twitch clip embed in a WebView once
  /// the native one failed.
  VodPlayerController _createPlayer() {
    final factory = widget.playerFactory;
    final VodPlayerController player;
    if (factory != null) {
      player = factory(widget.slug, _clip, web: _forceWeb);
    } else if (_forceWeb) {
      player = WebVodStore.forUrl(
        webClipEmbedUrl(widget.slug),
        knownLength: _clip?.duration,
        autoPipAllowed: () => _settings.autoPictureInPicture,
      );
    } else {
      player = ClipPlayerStore(
        slug: widget.slug,
        clipService: _service,
        settingsStore: _settings,
        knownLength: _clip?.duration,
      );
    }
    if (_forceWeb) {
      if (player is LoopingPlayer) {
        unawaited(_applySavedLoop(player as LoopingPlayer));
      }
      return player;
    }
    void fallback() {
      if (!mounted || !identical(_player, player)) return;
      _switchToWeb();
    }

    player.onFatalError = fallback;
    player.ready.catchError((Object _) => fallback());
    return player;
  }

  void _switchToWeb() {
    final old = _player;
    setState(() {
      _forceWeb = true;
      _player = _buildPlayer();
    });
    _bindReplay();
    old.dispose();
  }

  /// Rebuilds the player (a retry after a failure).
  void _retry() {
    final old = _player;
    setState(() => _player = _buildPlayer());
    _bindReplay();
    old.dispose();
    if (_clip == null) unawaited(_loadMetadata());
  }

  void _onFocusLost() {
    final player = _player;
    player.setFocused(false);
    // A player still loading would start on its own: treat it as playing.
    _playingBeforeFocusLoss =
        !player.paused || player.status == VodPlaybackStatus.loading;
    if (!player.paused) player.pause();
  }

  void _onFocusRegained() {
    // Runs after the frame: the screen above may be closing together with
    // this one, and must finish disposing first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_miniPlayer.visible) {
        _player.setFocused(true);
        if (_playingBeforeFocusLoss) _player.play();
        reclaimPipCallbacks(_pipKey);
      }
      _playingBeforeFocusLoss = false;
      if (_settings.keepScreenAwake) WakelockPlus.enable();
      // The screen that closed reset the system bars.
      setState(() => _immersive = null);
    });
  }

  void _syncSystemUi({required bool immersive}) {
    if (_immersive == immersive) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _immersive == immersive) return;
      _immersive = immersive;
      setImmersiveSystemUi(immersive);
    });
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: clipShareLink(widget.slug)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: AlertMessage(
          message: context.l10n.clipLinkCopied,
          centered: false,
        ),
      ),
    );
  }

  /// The full VOD at the clip's start; Back returns to the clip.
  VoidCallback? _watchFullVideo(Clip clip) {
    final vodId = clip.vodId;
    final offset = clip.vodOffset;
    if (vodId == null || offset == null) return null;
    return () => VodScreen.open(context, vodId: vodId, startAt: offset);
  }

  PlayerMedia _media() {
    final clip = _clip;
    return PlayerMedia(
      title: clip?.title ?? '',
      ownerId: clip?.broadcasterId ?? '',
      ownerLogin: clip?.broadcasterLogin ?? '',
      ownerDisplayName: clip?.broadcasterDisplayName ?? '',
      shareLabel: context.l10n.clipCopyClipLink,
      shareLink: (_) => clipShareLink(widget.slug),
    );
  }

  Widget _buildVideo() {
    final player = _player;
    final Widget video;
    if (player is ClipPlayerStore) {
      video = player.buildVideo(fill: _fillScreen);
    } else if (player is WebVodStore) {
      video = ColoredBox(
        color: Colors.black,
        child: WebViewWidget(controller: player.webViewController),
      );
    } else {
      video = const ColoredBox(color: Colors.black);
    }
    return KeyedSubtree(key: _videoKey, child: video);
  }

  /// Black area with a back button, for when nothing can play.
  Widget _withBackButton(Widget child) => VideoBackButtonLayer(child: child);

  VoidCallback? _subscribeAction() =>
      subscribeOpener(context, _clip?.broadcasterLogin ?? '');

  Widget _buildPlayerArea({required bool landscape}) {
    final loadProblem = _loadProblem;
    if (loadProblem != null) {
      return _withBackButton(
        VodErrorView(
          problem: loadProblem,
          subject: PlaybackSubject.clip,
          onRetry: _retry,
          onSubscribe: _subscribeAction(),
        ),
      );
    }
    final player = _player;
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildVideo(),
        Observer(
          builder: (context) {
            final problem = player.problem;
            if (player.status == VodPlaybackStatus.problem && problem != null) {
              return _withBackButton(
                VodErrorView(
                  problem: problem,
                  subject: PlaybackSubject.clip,
                  onRetry: _retry,
                  onSubscribe: _subscribeAction(),
                ),
              );
            }
            if (player.status == VodPlaybackStatus.failed) {
              return _withBackButton(
                VodErrorView(
                  problem: VodPlaybackProblem.unknown,
                  subject: PlaybackSubject.clip,
                  onRetry: _retry,
                ),
              );
            }
            final store = player is ClipPlayerStore ? player : null;
            final loop = player is LoopingPlayer
                ? player as LoopingPlayer
                : null;
            return VodOverlay(
              controller: player,
              media: _media(),
              settings: _settings,
              skipButtons: false,
              looping: loop?.looping,
              onToggleLoop: loop == null ? null : () => _toggleLoop(loop),
              // The embed letterboxes by itself.
              fillScreen: store == null ? null : _fillScreen,
              onToggleFillScreen: store == null
                  ? null
                  : () => setState(() => _fillScreen = !_fillScreen),
              isLandscape: landscape,
            );
          },
        ),
      ],
    );
  }

  Widget _buildDetails() {
    final clip = _clip;
    if (clip == null) {
      if (_detailsFailed) {
        return VideoPaneNotice(
          message: context.l10n.clipDetailsFailed,
          onRetry: _retryDetails,
        );
      }
      return _loadProblem == null
          ? const _DetailsSkeleton()
          : const SizedBox.shrink();
    }
    return ClipInfoPanel(
      clip: clip,
      onCopyLink: _copyLink,
      onShare: () => showShareSheet(
        context,
        url: clipShareLink(widget.slug),
        channelId: clip.broadcasterId,
        channelName: clip.broadcasterDisplayName,
      ),
      onWatchFullVideo: _watchFullVideo(clip),
      onDownload: () => unawaited(
        downloadClip(context, service: _service, slug: widget.slug),
      ),
      autoClip: _extras?.autoClip ?? false,
      onWatchPortrait: _extras?.hasPortrait ?? false
          ? () => _openPortrait(clip)
          : null,
      onComments: _openComments,
    );
  }

  /// The details, then the chat replay filling the rest when there is one,
  /// else the channel's other clips.
  Widget _buildInfoAndChat() {
    final replay = _replay;
    if (replay == null) {
      final clip = _clip;
      final moreClips = _moreClips;
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildDetails()),
          if (_replayMissing)
            const SliverToBoxAdapter(child: _NoRecordedChat()),
          if (clip != null && moreClips != null)
            MoreClipsSliver(
              store: moreClips,
              current: clip,
              onOpen: _openOtherClip,
            ),
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom + 16,
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // At most a third of the room (it scrolls), so large text on a small
        // phone still leaves the chat its place.
        Flexible(child: SingleChildScrollView(child: _buildDetails())),
        Expanded(
          flex: 2,
          child: SafeArea(
            top: false,
            child: VodChatReplay(
              store: replay,
              syncLabel: context.l10n.clipSyncedToClip,
            ),
          ),
        ),
      ],
    );
  }

  /// Loop on or off, remembered for the next clips (whatever the player).
  void _toggleLoop(LoopingPlayer player) {
    player.toggleLoop();
    final looping = player.looping;
    unawaited(
      SharedPreferences.getInstance().then(
        (prefs) => prefs.setBool(kClipLoopKey, looping),
      ),
    );
  }

  /// The remembered loop, for a player that does not read it itself.
  Future<void> _applySavedLoop(LoopingPlayer player) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(kClipLoopKey) == true && !player.looping) {
      player.toggleLoop();
    }
  }

  /// Replaces this clip with [clip], so clips never pile up on the stack.
  void _openOtherClip(Clip clip) => Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      settings: const RouteSettings(name: ClipScreen.routeName),
      builder: (context) => ClipScreen(
        slug: clip.slug,
        clip: clip,
        playerFactory: widget.playerFactory,
        replayFactory: widget.replayFactory,
      ),
    ),
  );

  /// Starts loading the channel's other clips (once the clip is known).
  void _loadMoreClips(Clip clip) {
    if (clip.broadcasterLogin.isEmpty || _moreClips != null) return;
    _moreClips = ChannelClipsStore(
      login: clip.broadcasterLogin,
      clipService: _service,
    );
    unawaited(_moreClips!.load());
  }

  Widget _buildPortrait() => SafeArea(
    bottom: false,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: _buildPlayerArea(landscape: false),
        ),
        Expanded(child: _buildInfoAndChat()),
      ],
    ),
  );

  /// The video alone, on a tablet as on a phone: the full-screen button
  /// rotates back to portrait, where the details and the chat replay live.
  Widget _buildLandscape() =>
      ColoredBox(color: Colors.black, child: _buildPlayerArea(landscape: true));

  @override
  Widget build(BuildContext context) {
    // "Force vertical chat" is for live chat; a clip in landscape always
    // gets the landscape layout (a 16:9 player would not fit above).
    final landscape = context.isLandscape;
    _syncSystemUi(immersive: landscape);

    final theme = Theme.of(context);
    // No app bar to set the system bars: the theme's in portrait, light
    // icons over the black of landscape.
    final page = AnnotatedRegion<SystemUiOverlayStyle>(
      value: landscape ? SystemUiOverlayStyle.light : theme.systemOverlayStyle,
      child: Scaffold(
        backgroundColor: landscape ? Colors.black : null,
        body: landscape ? _buildLandscape() : _buildPortrait(),
      ),
    );

    if (!Platform.isAndroid) return page;
    // Always present (keyed) so the page never remounts, and so PiP events
    // can be pointed back at it.
    return PipWidget(
      key: _pipKey,
      pipLayout: PipActionsLayout.mediaOnlyPause,
      onPipAction: (_) => _player.togglePlay(),
      onPipEntered: _player.onPipEntered,
      onPipExited: _player.onPipExited,
      pipChild: _buildVideo(),
      child: page,
    );
  }

  @override
  void dispose() {
    try {
      for (final dispose in _disposers) {
        dispose();
      }
      _player.dispose();
      _replay?.dispose();
      _moreClips?.dispose();
      // A clip replaced by another one (More clips) leaves the system bars
      // and rotation to the screen now on top.
      if (_hasFocus) {
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: SystemUiOverlay.values,
        );
        SystemChrome.setPreferredOrientations([]);
      }
    } finally {
      // Last: the screen beneath resumes (after this frame) once released.
      final wasTop = _hasFocus;
      PlaybackFocus.shared.release(this);
      if (wasTop && PlaybackFocus.shared.top == null) WakelockPlus.disable();
      super.dispose();
    }
  }
}

/// The details loading: the title and two lines under the global sheen.
class _DetailsSkeleton extends StatelessWidget {
  const _DetailsSkeleton();

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(6);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          SkeletonLoader(width: 260, height: 16, borderRadius: radius),
          SkeletonLoader(width: 180, height: 12, borderRadius: radius),
          Row(
            spacing: 10,
            children: [
              const SkeletonLoader(
                width: 32,
                height: 32,
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              SkeletonLoader(width: 120, height: 12, borderRadius: radius),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoRecordedChat extends StatelessWidget {
  const _NoRecordedChat();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          Icon(Icons.speaker_notes_off_outlined, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.clipNoRecordedChat,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
