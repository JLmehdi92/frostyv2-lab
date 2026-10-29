import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart' hide Listener;
import 'package:onset/apis/twitch_stream_service.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/screens/channel/video/content_warning_gate.dart';
import 'package:onset/screens/channel/video/player_glyph.dart';
import 'package:onset/screens/home/live_feed/live_preview.dart';
import 'package:onset/screens/home/live_feed/stores/live_feed_store.dart';
import 'package:onset/screens/home/stream_list/large_stream_card.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/screens/home/stream_list/stream_list_store.dart';
import 'package:onset/screens/home/stream_list/stream_tags.dart';
import 'package:onset/screens/home/stream_list/streams_list.dart';
import 'package:onset/screens/home/top/tags/tag_streams.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/vod/up_next.dart';
import 'package:onset/services/network_metering.dart';
import 'package:onset/services/playback_token_cache.dart';
import 'package:onset/stores/mini_player_store.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/utils/share_link.dart';
import 'package:onset/widgets/alert_message.dart';
import 'package:onset/widgets/launch/launch_intro.dart';
import 'package:onset/widgets/motion/haptics.dart';
import 'package:onset/widgets/motion/press_scale.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';
import 'package:onset/widgets/skeleton_loader.dart';
import 'package:onset/widgets/state_views.dart';
import 'package:onset/widgets/twitch_web_page.dart';
import 'package:provider/provider.dart';

/// Shows [categoryId]'s live channels in the feed (null: All), from the
/// first: the phone's chips and the tablet's (in the shell's tab row).
void selectLiveCategory(
  LiveFeedStore store,
  PageController controller,
  String? categoryId,
) {
  if (categoryId == store.categoryId) return;
  Haptics.selection();
  if (controller.hasClients) controller.jumpToPage(0);
  store.selectCategory(categoryId);
}

/// Home's Live feed (boards Live and LiveTablette): the top live channels
/// one at a time, a swipe up for the next, each with its muted preview.
///
/// - One preview plays at a time, never with sound until asked, and only
///   while the feed is on screen ([active], the shell's tab, the app in
///   front, no mini player) and the "Video Autoplaying" setting allows it;
///   otherwise the channel's picture shows, with a button to play it.
/// - A channel with content labels (mature content warnings on, not
///   accepted this session) never previews on its own: its picture shows
///   "Content warning · Play preview", which asks first (the channel's own
///   warning, [ContentWarningCover]); so does a channel whose labels Twitch
///   could not give.
/// - A tap (or "Watch with chat") opens the channel, after letting the
///   preview's decoder go; a long press opens its actions.
/// - Pull down on the first channel to refresh; the chips filter by
///   category; "Not interested" leaves a channel out for the session.
/// - On a tablet the preview is a card beside "Up next".
class LiveFeed extends StatefulWidget {
  const LiveFeed({
    super.key,
    required this.store,
    required this.controller,
    required this.active,
    @visibleForTesting this.preview,
    @visibleForTesting this.isMetered,
    @visibleForTesting this.meteredChanges,
    @visibleForTesting this.introRunning,
    @visibleForTesting this.channelRoute,
  });

  final LiveFeedStore store;

  /// The feed's pages (Home scrolls it back to the first on a second tap).
  final PageController controller;

  /// The feed is the page on screen and nothing covers it.
  final bool active;

  final LivePreviewController? preview;
  final Future<bool?> Function()? isMetered;

  /// The network's cost as it changes (default: [NetworkMetering]).
  final Stream<bool?>? meteredChanges;

  /// Whether the launch intro covers the app (default: [LaunchIntro]).
  final ValueListenable<bool>? introRunning;

  /// The channel's page (tests replace the channel screen).
  final Route<void> Function(StreamTwitch stream)? channelRoute;

  /// How many network answers changed a feed (tests: the same answer again
  /// must not rebuild it).
  @visibleForTesting
  static var debugMeteredUpdates = 0;

  @override
  State<LiveFeed> createState() => _LiveFeedState();
}

class _LiveFeedState extends State<LiveFeed> {
  late final _settings = context.read<SettingsStore>();
  late final _auth = context.read<AuthStore>();
  late final _mini = context.read<MiniPlayerStore?>();

  /// The usher service of the previews: its own client, the players'
  /// token cache (a preview's token is the channel's, ready when it opens).
  TwitchStreamService? _service;

  late final LivePreviewController _preview =
      widget.preview ??
      LivePreviewController(
        resolveUrl: (login, cancel) async {
          final service = _service ??= TwitchStreamService(
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 5),
                receiveTimeout: const Duration(seconds: 8),
              ),
            ),
            tokenCache: PlaybackTokenCache.shared,
          )..onWebTokenRejected = _auth.renewTwitchWebToken;
          final variants = await service.getStreamVariants(
            userLogin: login,
            authToken: _auth.twitchWebToken,
            cancelToken: cancel,
          );
          final variant = pickPreviewVariant(
            variants,
            targetHeight: _large ? 720 : 480,
          );
          if (variant == null) throw StateError('No video rendition');
          return variant.url;
        },
      );

  /// The pages, kept when the window crosses the tablet size.
  final _pagesKey = GlobalKey(debugLabel: 'live-feed-pages');

  late final AppLifecycleListener _lifecycle;
  final _disposers = <ReactionDisposer>[];

  var _foreground = true;
  var _tickers = true;
  var _large = false;

  /// "Wi-Fi only": whether the network costs data (null: unknown, asked).
  bool? _metered;
  var _meterAsked = false;

  /// A preview started by hand while autoplay is off.
  String? _playedByHand;

  /// The channel whose content warning is open over its picture (the
  /// viewer asked to play its preview).
  final _asking = ValueNotifier<String?>(null);

  /// What the pages need of the previews' content warnings.
  late final _gate = _PreviewGate(
    warningOf: _warningOf,
    asking: _asking,
    ask: (stream) {
      Haptics.light();
      _asking.value = stream.userLogin;
    },
    accept: (stream) {
      AcceptedContentWarnings.add(stream.userId);
      _asking.value = null;
      _playByHand(stream);
    },
    decline: () => _asking.value = null,
  );

  /// Whether [stream]'s preview may play without asking: the warnings off,
  /// its warning accepted this session, or Twitch says it has no labels.
  bool _previewClear(StreamTwitch stream) =>
      contentWarningConsented(
        warnMatureContent: _settings.warnMatureContent,
        channelId: stream.userId,
      ) ||
      (widget.store.labelsOf(stream.userId)?.isEmpty ?? false);

  /// The labels [stream]'s picture warns about instead of previewing (empty
  /// when Twitch could not say), or null: it may preview, or its labels are
  /// still being read (then it waits, without a warning).
  List<String>? _warningOf(StreamTwitch stream) {
    if (_previewClear(stream)) return null;
    if (!widget.store.knowsLabelsOf(stream.userId)) return null;
    return widget.store.labelsOf(stream.userId) ?? const [];
  }

  /// A channel opened from the feed is on screen (or still leaving): no
  /// preview may start under its player, whatever else changes meanwhile.
  var _channelOpen = false;

  /// The enlarged picture is open: its blurred backdrop must never cover a
  /// playing preview, so none plays until it is closed.
  var _dialogOpen = false;

  StreamSubscription<bool?>? _meteredChanges;

  late final ValueListenable<bool> _intro =
      widget.introRunning ?? LaunchIntro.running;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        _foreground = state == AppLifecycleState.resumed;
        if (_foreground) {
          _meterAsked = false;
          _refreshIfStale();
        }
        _sync();
      },
    );
    _disposers
      ..add(
        reaction((_) => widget.store.current?.userLogin, (String? login) {
          _playedByHand = null;
          _asking.value = null;
          _preview.show(login);
          _sync();
        }, fireImmediately: true),
      )
      // The labels of the channel on screen arrive, or the warnings are
      // switched: it may preview, or not.
      ..add(
        reaction((_) {
          final stream = widget.store.current;
          return (
            _settings.warnMatureContent,
            stream == null ? null : widget.store.knowsLabelsOf(stream.userId),
            stream == null ? null : widget.store.labelsOf(stream.userId),
          );
        }, (_) => _sync()),
      )
      ..add(reaction((_) => _settings.vodAutoplay, (_) => _sync()))
      ..add(reaction((_) => _settings.showThumbnails, (_) => _sync()))
      // The store moved (a refresh kept the channel elsewhere, another
      // language started over, a chip): the pages follow.
      ..add(reaction((_) => widget.store.index, _followIndex));
    // Leaving Wi-Fi stops a "Wi-Fi only" preview at once.
    _meteredChanges =
        (widget.meteredChanges ?? NetworkMetering.shared.changes()).listen((
          metered,
        ) {
          if (!mounted || (_meterAsked && metered == _metered)) return;
          LiveFeed.debugMeteredUpdates++;
          setState(() {
            _metered = metered;
            _meterAsked = true;
          });
          _sync();
        });
    // Nothing competes with the launch intro for the device.
    _intro.addListener(_onIntro);
    final mini = _mini;
    if (mini != null) {
      _disposers.add(reaction((_) => mini.visible, (_) => _sync()));
    }
  }

  void _onIntro() {
    // The intro reports from its own build: answered after that frame.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _sync());
    } else {
      _sync();
    }
  }

  void _followIndex(int index) {
    final controller = widget.controller;
    if (!controller.hasClients) return;
    final page = controller.page?.round();
    if (page != null && page != index) controller.jumpToPage(index);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Off the shell's screen (another tab or section): no ticker, no
    // preview.
    _tickers = TickerMode.of(context);
    _large = context.isLargeScreen;
    _sync();
  }

  @override
  void didUpdateWidget(LiveFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active == widget.active) return;
    // Back on the feed after a while: fresh channels, like every list.
    if (widget.active) _refreshIfStale();
    _sync();
  }

  /// Back on the feed after a while: the channels are refreshed, the one on
  /// screen kept where it is.
  void _refreshIfStale() {
    if (!widget.store.stale) return;
    unawaited(widget.store.refresh(keepPosition: true));
  }

  bool get _autoplay {
    final setting = _settings.vodAutoplay;
    if (setting == VodAutoplay.wifiOnly && !_meterAsked) {
      _meterAsked = true;
      final ask = widget.isMetered ?? NetworkMetering.shared.isMetered;
      unawaited(
        ask().then((metered) {
          if (!mounted) return;
          _metered = metered;
          _sync();
        }),
      );
    }
    return autoplayAllowed(setting, metered: _metered);
  }

  /// Whether a preview may play now, and tells the preview.
  void _sync() {
    if (!mounted) return;
    final stream = widget.store.current;
    final current = stream?.userLogin;
    // Thumbnails off: no picture, no preview unless asked for.
    final allowed =
        (_autoplay && _settings.showThumbnails) ||
        (current != null && current == _playedByHand);
    _preview.setActive(
      widget.active &&
          !_channelOpen &&
          !_dialogOpen &&
          !_intro.value &&
          _tickers &&
          _foreground &&
          !(_mini?.visible ?? false) &&
          allowed &&
          // A labelled channel (or one whose labels are not known) only
          // once the viewer said yes.
          stream != null &&
          _previewClear(stream),
    );
  }

  void _playByHand(StreamTwitch stream) {
    // A labelled channel asks first. One whose labels are still being read
    // is played by hand once they say it may be (else its warning shows).
    if (_warningOf(stream) != null) {
      _gate.ask(stream);
      return;
    }
    Haptics.light();
    setState(() => _playedByHand = stream.userLogin);
    _sync();
  }

  /// Opens [stream]'s channel, the preview's decoder let go first: the
  /// channel's player never shares the device with it.
  ///
  /// - Opening waits for the decoder to be gone, at most [_releaseCap]:
  ///   releasing libmpv takes a few frames, and a channel should never be
  ///   slower to open than that because of a preview.
  /// - Previews stay off until the channel's page is gone, its closing
  ///   transition included (its player lives until then).
  Future<void> _open(StreamTwitch stream) async {
    if (_channelOpen) return;
    _channelOpen = true;
    _preview.stop();
    try {
      await _preview.idle.timeout(_releaseCap, onTimeout: () {});
      if (!mounted) return;
      final route = widget.channelRoute?.call(stream) ?? streamRoute(stream);
      await Navigator.of(context).push(route);
      if (route is TransitionRoute) await route.completed;
    } finally {
      _channelOpen = false;
      _sync();
    }
  }

  static const _releaseCap = Duration(milliseconds: 100);

  void _notInterested(StreamTwitch stream) {
    Haptics.light();
    final name = getReadableName(stream.userName, stream.userLogin);
    widget.store.hide(stream.userId);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text("You won't see $name in Live for now"),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => widget.store.unhide(stream.userId),
          ),
        ),
      );
  }

  void _toTop() {
    if (widget.controller.hasClients) widget.controller.jumpToPage(0);
  }

  Future<void> _refresh() async {
    HapticFeedback.lightImpact();
    _toTop();
    await widget.store.refresh();
    _reportError();
  }

  /// A refresh that failed with channels still on screen says so, as every
  /// list does (the end page then offers to try again).
  void _reportError() {
    final error = widget.store.list.error;
    if (!mounted || error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AlertMessage(message: error, centered: false)),
    );
  }

  Future<void> _retry() async {
    await widget.store.retry();
    _reportError();
  }

  Future<void> _enlarge(StreamTwitch stream) async {
    if (!_settings.showThumbnails) {
      showStreamActions(context, stream);
      return;
    }
    if (_dialogOpen) return;
    // The preview goes before the dialog draws its first frame.
    _dialogOpen = true;
    _sync();
    try {
      await enlargeThumbnail(context, stream);
    } finally {
      _dialogOpen = false;
      _sync();
    }
  }

  void _selectCategory(String? id) =>
      selectLiveCategory(widget.store, widget.controller, id);

  @override
  void dispose() {
    _intro.removeListener(_onIntro);
    unawaited(_meteredChanges?.cancel());
    _lifecycle.dispose();
    for (final dispose in _disposers) {
      dispose();
    }
    if (widget.preview == null) _preview.dispose();
    _service?.close();
    _asking.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final large = context.isLargeScreen;
    if (large) return _tablet(context);
    // The phone feed is a video page: dark in either theme.
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        brightness: Brightness.dark,
        extensions: [
          OnsetColors.dark,
          OnsetTextStyles.resolve(OnsetColors.dark.metadata),
        ],
      ),
      child: ColoredBox(color: Colors.black, child: _phone(context)),
    );
  }

  // -----------------------------------------------------------------------
  // States.

  /// The feed's state when it has no channel to show (loading, empty,
  /// failed), or null.
  Widget? _state(BuildContext context) {
    final store = widget.store;
    final list = store.list;
    if (store.streams.isNotEmpty) return null;
    final error = list.error;
    if (list.isLoading && error == null) {
      return _large ? const _TabletSkeleton() : const _PhoneSkeleton();
    }
    if (error != null) {
      return FeedStatusView.error(
        message: error,
        onRetry: () => unawaited(_refresh()),
      );
    }
    if (list.hiddenByLabels > 0) {
      return FeedStatusView(
        message: 'Every stream here has a label you hide',
        icon: Icons.visibility_off_outlined,
        action: 'Show them',
        onAction: list.showLabeledStreams,
      );
    }
    return FeedStatusView.empty(
      message: store.categoryId == null ? 'No top streams' : 'No live streams',
    );
  }

  /// A state that can still be pulled to refresh.
  Widget _pullable(Widget child) => RefreshIndicator.adaptive(
    onRefresh: _refresh,
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: child,
        ),
      ),
    ),
  );

  /// The pages: one channel each, then the end of the list.
  Widget _pages({
    required Widget Function(BuildContext, StreamTwitch, int) page,
    double edgeOffset = 0,
  }) {
    return KeyedSubtree(
      key: _pagesKey,
      child: RefreshIndicator.adaptive(
        edgeOffset: edgeOffset,
        onRefresh: _refresh,
        child: Observer(
          builder: (context) {
            final streams = widget.store.streams;
            return PageView.builder(
              controller: widget.controller,
              scrollDirection: Axis.vertical,
              // The page after the last channel too: nothing plays there,
              // and the channel a new page brings in gets its preview.
              onPageChanged: widget.store.setIndex,
              itemCount: streams.length + 1,
              itemBuilder: (context, index) => index < streams.length
                  ? page(context, streams[index], index)
                  : _EndPage(
                      loading: widget.store.list.isLoading,
                      error: widget.store.list.error,
                      onRetry: () => unawaited(_retry()),
                      onBackToTop: () => widget.controller.animateToPage(
                        0,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                      ),
                    ),
            );
          },
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Phone (board Live).

  Widget _phone(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return Observer(
      builder: (context) {
        final state = _state(context);
        return Stack(
          fit: StackFit.expand,
          children: [
            if (state != null)
              Padding(
                padding: EdgeInsets.only(top: padding.top + 46),
                child: _pullable(state),
              )
            else
              _pages(
                edgeOffset: padding.top + 46,
                page: (context, stream, index) => _PhonePage(
                  stream: stream,
                  preview: _preview,
                  gate: _gate,
                  first: index == 0,
                  hasNext: index < widget.store.streams.length - 1,
                  loggedIn: _auth.isLoggedIn,
                  canPlayByHand: !_autoplay || !_settings.showThumbnails,
                  showThumbnail: _settings.showThumbnails,
                  onOpen: () => unawaited(_open(stream)),
                  onPreload: () => preloadStream(context, stream),
                  onActions: () => showStreamActions(context, stream),
                  onEnlarge: () => unawaited(_enlarge(stream)),
                  onNotInterested: () => _notInterested(stream),
                  onPlay: () => _playByHand(stream),
                ),
              ),
            Positioned(
              top: padding.top + 14,
              left: 0,
              right: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LiveFeedChips(
                    store: widget.store,
                    overVideo: true,
                    onSelect: _selectCategory,
                    padding: EdgeInsets.only(
                      left: OnsetSpacing.gutterPhone + padding.left,
                      right: OnsetSpacing.gutterPhone + padding.right,
                    ),
                  ),
                  if (state == null)
                    _HiddenNote(list: widget.store.list, overVideo: true),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // -----------------------------------------------------------------------
  // Tablet (board LiveTablette).

  Widget _tablet(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final size = MediaQuery.sizeOf(context);
    final portrait = size.height > size.width;
    return Observer(
      builder: (context) {
        final state = _state(context);
        if (state != null) {
          return Padding(
            padding: EdgeInsets.only(left: padding.left, right: padding.right),
            child: _pullable(state),
          );
        }
        final card = ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: ColoredBox(
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _pages(
                  page: (context, stream, index) => _TabletPage(
                    stream: stream,
                    preview: _preview,
                    gate: _gate,
                    loggedIn: _auth.isLoggedIn,
                    canPlayByHand: !_autoplay || !_settings.showThumbnails,
                    showThumbnail: _settings.showThumbnails,
                    onOpen: () => unawaited(_open(stream)),
                    onPreload: () => preloadStream(context, stream),
                    onActions: () => showStreamActions(context, stream),
                    onEnlarge: () => unawaited(_enlarge(stream)),
                    onNotInterested: () => _notInterested(stream),
                    onPlay: () => _playByHand(stream),
                  ),
                ),
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0x1AFFFFFF),
                        width: OnsetTokens.hairlineWidth,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        final upNext = _UpNext(
          store: widget.store,
          horizontal: portrait,
          onSelect: (index) => widget.controller.animateToPage(
            index,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          ),
        );
        return Padding(
          padding: EdgeInsets.fromLTRB(
            OnsetSpacing.gutterTablet + padding.left,
            20,
            OnsetSpacing.gutterTablet + padding.right,
            OnsetSpacing.gutterTablet + padding.bottom,
          ),
          child: portrait
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 20,
                  children: [
                    _HiddenNote(list: widget.store.list),
                    Expanded(child: card),
                    SizedBox(height: 190, child: upNext),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 24,
                  children: [
                    Expanded(flex: 860, child: card),
                    Expanded(
                      flex: 340,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _HiddenNote(list: widget.store.list),
                          Expanded(child: upNext),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

/// The category chips: "All" and the categories most live now (boards:
/// 32 dp pills; over the phone's video, glassless white on dark).
class LiveFeedChips extends StatelessWidget {
  const LiveFeedChips({
    super.key,
    required this.store,
    required this.onSelect,
    this.overVideo = false,
    this.padding = EdgeInsets.zero,
  });

  final LiveFeedStore store;
  final ValueChanged<String?> onSelect;
  final bool overVideo;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final chips = store.chips;
        final selected = store.categoryId;
        if (chips.isEmpty && selected == null) return const SizedBox.shrink();
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: padding,
          child: Row(
            spacing: 8,
            children: [
              _chip(context, 'All', selected == null, () => onSelect(null)),
              for (final chip in chips)
                _chip(
                  context,
                  chip.name,
                  selected == chip.id,
                  () => onSelect(chip.id),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(
    BuildContext context,
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    final colors = FeedColors.of(context);
    final dark = overVideo || Theme.of(context).brightness == Brightness.dark;
    final Color fill;
    final Color text;
    final Color? border;
    if (selected) {
      fill = dark ? OnsetTokens.textPrimaryDark : OnsetTokens.backgroundDark;
      text = dark ? OnsetTokens.backgroundDark : OnsetTokens.textPrimaryDark;
      border = null;
    } else if (overVideo) {
      fill = const Color(0x1FFFFFFF);
      text = OnsetTokens.textPrimaryDark;
      border = const Color(0x29FFFFFF);
    } else {
      fill = colors.surface;
      text = colors.text;
      border = colors.pillBorder;
    }
    return Semantics(
      button: true,
      selected: selected,
      child: PressScale(
        child: Material(
          color: fill,
          shape: StadiumBorder(
            side: border == null
                ? BorderSide.none
                : BorderSide(color: border, width: OnsetTokens.hairlineWidth),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "N streams hidden … Show", for the labels the viewer hides.
class _HiddenNote extends StatelessWidget {
  const _HiddenNote({required this.list, this.overVideo = false});

  final ListStore list;
  final bool overVideo;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final hidden = list.hiddenByLabels;
        if (hidden == 0) return const SizedBox.shrink();
        final banner = HiddenStreamsBanner(
          hidden: hidden,
          onShow: list.showLabeledStreams,
        );
        return overVideo
            ? Padding(padding: const EdgeInsets.only(top: 6), child: banner)
            : banner;
      },
    );
  }
}

/// What a page needs of the previews' content warnings (see
/// [_LiveFeedState._warningOf]).
class _PreviewGate {
  const _PreviewGate({
    required this.warningOf,
    required this.asking,
    required this.ask,
    required this.accept,
    required this.decline,
  });

  /// The labels a channel's picture warns about instead of previewing, or
  /// null (read inside an observer: the labels arrive later).
  final List<String>? Function(StreamTwitch stream) warningOf;

  /// The channel whose warning is open (its login).
  final ValueListenable<String?> asking;

  /// Opens the channel's warning.
  final void Function(StreamTwitch stream) ask;

  /// "Start watching": accepted for the session, the preview plays.
  final void Function(StreamTwitch stream) accept;

  /// "Go back": the warning closes, nothing plays.
  final VoidCallback decline;
}

/// A channel's picture, then its preview over it once the first frame is
/// on screen (only the channel the preview plays); for a labelled channel,
/// its content warning instead (see [_PreviewGate]).
class _PreviewSurface extends StatelessWidget {
  const _PreviewSurface({
    required this.stream,
    required this.preview,
    required this.gate,
    required this.showThumbnail,
  });

  final StreamTwitch stream;
  final LivePreviewController preview;
  final _PreviewGate gate;

  /// The "show thumbnails" setting: off, no picture (a preview asked for
  /// still plays).
  final bool showThumbnail;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (showThumbnail) StreamThumbnail(stream: stream, enlarge: false),
          ListenableBuilder(
            listenable: preview,
            builder: (context, _) {
              final backend = preview.backend;
              if (preview.failed && preview.targetLogin == stream.userLogin) {
                return const Center(
                  child: OverlayPill(
                    height: 26,
                    radius: 7,
                    padding: 10,
                    child: Text(
                      'Preview unavailable',
                      style: TextStyle(fontSize: 12, color: OverImage.text),
                    ),
                  ),
                );
              }
              if (backend == null || preview.playingLogin != stream.userLogin) {
                return const SizedBox.shrink();
              }
              return ValueListenableBuilder<bool>(
                valueListenable: backend.showing,
                builder: (context, showing, video) => AnimatedOpacity(
                  opacity: showing ? 1 : 0,
                  duration: motionDuration(
                    context,
                    const Duration(milliseconds: 250),
                  ),
                  child: video,
                ),
                child: backend.buildVideo(),
              );
            },
          ),
          Observer(
            builder: (context) {
              final labels = gate.warningOf(stream);
              if (labels == null) return const SizedBox.shrink();
              return ValueListenableBuilder<String?>(
                valueListenable: gate.asking,
                builder: (context, asking, _) {
                  if (asking != stream.userLogin) {
                    return Center(
                      child: _WarningPill(onPressed: () => gate.ask(stream)),
                    );
                  }
                  // Over the picture, it takes every tap (none opens the
                  // channel behind it by accident).
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    onLongPress: () {},
                    child: ContentWarningCover(
                      displayName: getReadableName(
                        stream.userName,
                        stream.userLogin,
                      ),
                      labels: labels,
                      onAccept: () => gate.accept(stream),
                      onBack: gate.decline,
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

/// "Content warning · Play preview" over a labelled channel's picture.
class _WarningPill extends StatelessWidget {
  const _WarningPill({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Content warning. Play preview',
      excludeSemantics: true,
      child: PressScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: const OverlayPill(
            height: 36,
            radius: 18,
            padding: 14,
            color: Color(0xB3000000),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                PlayerGlyph(
                  PlayerGlyphKind.eyeOff,
                  color: OverImage.text,
                  size: 16,
                  strokeWidth: 1.7,
                ),
                Flexible(
                  child: Text(
                    'Content warning · Play preview',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: OverImage.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A round action over the preview (boards: 48 / 50 dp, dark, hairline).
class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = 48,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: PressScale(
          child: Material(
            color: const Color(0x73000000),
            shape: const CircleBorder(
              side: BorderSide(
                color: Color(0x2EFFFFFF),
                width: OnsetTokens.hairlineWidth,
              ),
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(icon, size: 22, color: OverImage.text),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Unmute / mute (or, autoplay off, play) the preview of [stream].
class _SoundAction extends StatelessWidget {
  const _SoundAction({
    required this.stream,
    required this.preview,
    required this.canPlayByHand,
    required this.onPlay,
    this.size = 48,
  });

  final StreamTwitch stream;
  final LivePreviewController preview;
  final bool canPlayByHand;
  final VoidCallback onPlay;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: preview,
      builder: (context, _) {
        final playing = preview.playingLogin == stream.userLogin;
        final failed =
            preview.failed && preview.targetLogin == stream.userLogin;
        // Nothing to unmute: no dead button (its place is kept).
        if (failed || (!playing && !canPlayByHand)) {
          return SizedBox.square(dimension: size);
        }
        if (!playing) {
          return _RoundAction(
            icon: Icons.play_arrow_rounded,
            label: 'Play preview',
            onPressed: onPlay,
            size: size,
          );
        }
        final muted = preview.muted;
        return _RoundAction(
          icon: muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          label: muted ? 'Unmute' : 'Mute',
          size: size,
          onPressed: () {
            Haptics.light();
            unawaited(preview.toggleMute());
          },
        );
      },
    );
  }
}

/// "Muted preview", or "Sound on" once the viewer unmuted this one.
class _SoundLabel extends StatelessWidget {
  const _SoundLabel({
    required this.stream,
    required this.preview,
    required this.style,
    this.prefix = '',
  });

  final StreamTwitch stream;
  final LivePreviewController preview;
  final TextStyle style;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: preview,
      builder: (context, _) {
        final audible =
            !preview.muted && preview.playingLogin == stream.userLogin;
        return Text(
          '$prefix${audible ? 'Sound on' : 'Muted preview'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        );
      },
    );
  }
}

/// "N watching": the rolling count of a preview.
class _Watching extends StatelessWidget {
  const _Watching({required this.viewers, this.pill = false});

  final int viewers;
  final bool pill;

  @override
  Widget build(BuildContext context) {
    final text = Semantics(
      label: '${formatViewers(viewers, compact: false)} watching',
      child: ExcludeSemantics(
        child: RollingViewers(viewers: viewers, spelled: true, fontSize: 13),
      ),
    );
    return pill
        ? OverlayPill(height: 26, radius: 7, padding: 9, child: text)
        : text;
  }
}

/// The primary action: "Watch with chat" (boards: signal fill, 48 dp).
class _WatchButton extends StatelessWidget {
  const _WatchButton({
    required this.onPressed,
    required this.onDown,
    this.pill = false,
  });

  final VoidCallback onPressed;

  /// The finger is down (the channel's token is asked for).
  final VoidCallback onDown;
  final bool pill;

  @override
  Widget build(BuildContext context) {
    return Listener(onPointerDown: (_) => onDown(), child: _button());
  }

  Widget _button() {
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: OnsetTokens.accent,
        foregroundColor: OnsetTokens.backgroundDark,
        minimumSize: const Size(0, 48),
        padding: EdgeInsets.symmetric(horizontal: pill ? 22 : 16),
        shape: pill
            ? const StadiumBorder()
            : RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: OnsetTokens.bodyFamily,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      icon: const Icon(Icons.play_arrow_rounded, size: 18),
      label: const Text('Watch with chat'),
    );
  }
}

/// "Follow": the channel on twitch.tv (the app has no follow of its own,
/// like the actions menu's "Follow on Twitch").
class _FollowButton extends StatelessWidget {
  const _FollowButton({required this.stream, this.height = 32});

  final StreamTwitch stream;
  final double height;

  @override
  Widget build(BuildContext context) {
    final name = getReadableName(stream.userName, stream.userLogin);
    return Tooltip(
      message: 'Follow $name on Twitch',
      child: OutlinedButton(
        onPressed: () => TwitchWebPage.open(
          context,
          title: name,
          url: Uri.https('www.twitch.tv', '/${stream.userLogin}'),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: OverImage.text,
          backgroundColor: height > 40 ? const Color(0x4D000000) : null,
          minimumSize: Size(0, height),
          padding: EdgeInsets.symmetric(horizontal: height > 40 ? 18 : 14),
          side: const BorderSide(
            color: Color(0x4DFFFFFF),
            width: OnsetTokens.hairlineWidth,
          ),
          shape: const StadiumBorder(),
          textStyle: TextStyle(
            fontSize: height > 40 ? 14 : 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: const Text('Follow'),
      ),
    );
  }
}

/// The category under a channel's name, opening its streams.
class _CategoryLine extends StatelessWidget {
  const _CategoryLine({required this.stream});

  final StreamTwitch stream;

  @override
  Widget build(BuildContext context) {
    final open = openCategoryOf(context, stream);
    final language = stream.language.isEmpty || stream.language == 'other'
        ? null
        : stream.language.toUpperCase();
    final text = [
      if (stream.gameName.isNotEmpty) stream.gameName,
      ?language,
    ].join(' · ');
    if (text.isEmpty) return const SizedBox.shrink();
    return Semantics(
      button: open != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: open,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, color: OverImage.secondary),
        ),
      ),
    );
  }
}

/// One channel of the phone feed (board Live).
class _PhonePage extends StatelessWidget {
  const _PhonePage({
    required this.stream,
    required this.preview,
    required this.gate,
    required this.first,
    required this.hasNext,
    required this.loggedIn,
    required this.canPlayByHand,
    required this.showThumbnail,
    required this.onOpen,
    required this.onPreload,
    required this.onActions,
    required this.onEnlarge,
    required this.onNotInterested,
    required this.onPlay,
  });

  final StreamTwitch stream;
  final LivePreviewController preview;
  final _PreviewGate gate;
  final bool first;
  final bool hasNext;
  final bool loggedIn;
  final bool canPlayByHand;
  final bool showThumbnail;
  final VoidCallback onOpen;

  /// The finger is down on the way to the channel: its token is asked for.
  final VoidCallback onPreload;
  final VoidCallback onActions;

  /// A long press on the picture: enlarged, as on every card.
  final VoidCallback onEnlarge;
  final VoidCallback onNotInterested;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final name = getReadableName(stream.userName, stream.userLogin);
    final title = stream.title.trim();
    return Stack(
      fit: StackFit.expand,
      children: [
        // The stream, letterboxed in the space between the chips and the
        // channel's lines: never stretched, never cropped.
        Positioned(
          top: padding.top + 56,
          left: 0,
          right: 0,
          bottom: padding.bottom + 230,
          child: Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Semantics(
                label: '$name live preview. Opens the channel',
                button: true,
                onLongPressHint: showThumbnail ? 'enlarge' : 'Channel actions',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) => onPreload(),
                  onTap: onOpen,
                  onLongPress: onEnlarge,
                  child: _PreviewSurface(
                    stream: stream,
                    preview: preview,
                    gate: gate,
                    showThumbnail: showThumbnail,
                  ),
                ),
              ),
            ),
          ),
        ),
        // Gradients only: nothing is ever blurred over the video.
        const IgnorePointer(
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: 260,
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xBF000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
          ),
        ),
        const IgnorePointer(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: 420,
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xEB000000), Color(0x00000000)],
                    stops: [0.2, 1],
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 12 + padding.right,
          bottom: padding.bottom + 114,
          child: Column(
            spacing: 14,
            children: [
              _SoundAction(
                stream: stream,
                preview: preview,
                canPlayByHand: canPlayByHand,
                onPlay: onPlay,
              ),
              _RoundAction(
                icon: Icons.block_rounded,
                label: 'Not interested',
                onPressed: onNotInterested,
              ),
              _RoundAction(
                icon: Icons.ios_share_rounded,
                label: 'Share',
                onPressed: () => unawaited(
                  shareLink(
                    context,
                    'https://www.twitch.tv/${stream.userLogin}',
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: OnsetSpacing.gutterPhone + padding.left,
          right: 76 + padding.right,
          bottom: padding.bottom + 26,
          child: GestureDetector(
            // A long press on the channel's lines: its actions.
            behavior: HitTestBehavior.translucent,
            onLongPress: onActions,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              spacing: 10,
              children: [
                Row(
                  spacing: 8,
                  children: [
                    const LiveBadge(),
                    _Watching(viewers: stream.viewerCount),
                    Flexible(
                      child: _SoundLabel(
                        stream: stream,
                        preview: preview,
                        prefix: '· ',
                        style: const TextStyle(
                          fontSize: 13,
                          color: OverImage.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  spacing: 10,
                  children: [
                    RingedAvatar(
                      login: stream.userLogin,
                      size: 42,
                      ground: Colors.black,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: OnsetTokens.displayFamily,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.01 * 17,
                              color: OverImage.text,
                            ),
                          ),
                          _CategoryLine(stream: stream),
                        ],
                      ),
                    ),
                    if (loggedIn) _FollowButton(stream: stream),
                  ],
                ),
                if (title.isNotEmpty)
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: Color(0xFFEDEDED),
                    ),
                  ),
                if (stream.tags.isNotEmpty)
                  StreamTags(
                    tags: stream.tags,
                    onTap: (tag) => TagStreams.open(context, tag),
                  ),
                _WatchButton(onPressed: onOpen, onDown: onPreload),
              ],
            ),
          ),
        ),
        if (first && hasNext)
          Positioned(
            left: 0,
            right: 0,
            bottom: padding.bottom - 2,
            child: const IgnorePointer(child: _SwipeHint()),
          ),
      ],
    );
  }
}

/// "Swipe up for the next live", bobbing gently (still under reduce
/// motion; its ticker stops off screen).
class _SwipeHint extends StatefulWidget {
  const _SwipeHint();

  @override
  State<_SwipeHint> createState() => _SwipeHintState();
}

class _SwipeHintState extends State<_SwipeHint>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotionOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const label = Text(
      'SWIPE UP FOR THE NEXT LIVE',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.14 * 11,
        color: Color(0x8CFFFFFF),
      ),
    );
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(
            1 - (2 * _controller.value - 1).abs(),
          );
          return Transform.translate(offset: Offset(0, -6 * t), child: child);
        },
        child: label,
      ),
    );
  }
}

/// One channel of the tablet feed (board LiveTablette): the preview card.
class _TabletPage extends StatelessWidget {
  const _TabletPage({
    required this.stream,
    required this.preview,
    required this.gate,
    required this.loggedIn,
    required this.canPlayByHand,
    required this.showThumbnail,
    required this.onOpen,
    required this.onPreload,
    required this.onActions,
    required this.onEnlarge,
    required this.onNotInterested,
    required this.onPlay,
  });

  final StreamTwitch stream;
  final LivePreviewController preview;
  final _PreviewGate gate;
  final bool loggedIn;
  final bool canPlayByHand;
  final bool showThumbnail;
  final VoidCallback onOpen;

  /// The finger is down on the way to the channel: its token is asked for.
  final VoidCallback onPreload;
  final VoidCallback onActions;

  /// A long press on the picture: enlarged, as on every card.
  final VoidCallback onEnlarge;
  final VoidCallback onNotInterested;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final name = getReadableName(stream.userName, stream.userLogin);
    final title = stream.title.trim();
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Semantics(
              label: '$name live preview. Opens the channel',
              button: true,
              onLongPressHint: showThumbnail ? 'enlarge' : 'Channel actions',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => onPreload(),
                onTap: onOpen,
                onLongPress: onEnlarge,
                child: _PreviewSurface(
                  stream: stream,
                  preview: preview,
                  gate: gate,
                  showThumbnail: showThumbnail,
                ),
              ),
            ),
          ),
        ),
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x59000000),
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0xEB000000),
                ],
                stops: [0, 0.22, 0.45, 1],
              ),
            ),
          ),
        ),
        Positioned(
          left: 20,
          top: 20,
          right: 90,
          child: Row(
            spacing: 8,
            children: [
              const LiveBadge(large: true),
              _Watching(viewers: stream.viewerCount, pill: true),
              Flexible(
                child: OverlayPill(
                  height: 26,
                  radius: 7,
                  padding: 9,
                  child: _SoundLabel(
                    stream: stream,
                    preview: preview,
                    style: const TextStyle(
                      fontSize: 12,
                      color: OnsetTokens.textBodyDark,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 18,
          top: 0,
          bottom: 0,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 12,
              children: [
                _SoundAction(
                  stream: stream,
                  preview: preview,
                  canPlayByHand: canPlayByHand,
                  onPlay: onPlay,
                  size: 50,
                ),
                _RoundAction(
                  icon: Icons.block_rounded,
                  label: 'Not interested',
                  onPressed: onNotInterested,
                  size: 50,
                ),
                _RoundAction(
                  icon: Icons.ios_share_rounded,
                  label: 'Share',
                  size: 50,
                  onPressed: () => unawaited(
                    shareLink(
                      context,
                      'https://www.twitch.tv/${stream.userLogin}',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 24,
          child: GestureDetector(
            // A long press on the channel's lines: its actions.
            behavior: HitTestBehavior.translucent,
            onLongPress: onActions,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: 16,
              children: [
                RingedAvatar(
                  login: stream.userLogin,
                  size: 56,
                  ground: Colors.black,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    spacing: 5,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: OnsetTokens.displayFamily,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.025 * 24,
                          color: OverImage.text,
                        ),
                      ),
                      if (title.isNotEmpty)
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFFEDEDED),
                          ),
                        ),
                      _CategoryLine(stream: stream),
                      if (stream.tags.isNotEmpty)
                        StreamTags(
                          tags: stream.tags,
                          onTap: (tag) => TagStreams.open(context, tag),
                        ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 10,
                  children: [
                    if (loggedIn) _FollowButton(stream: stream, height: 48),
                    _WatchButton(
                      onPressed: onOpen,
                      onDown: onPreload,
                      pill: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// "Up next" beside the tablet preview (or under it, portrait): the next
/// channel as a card, the three after as fading rows.
class _UpNext extends StatelessWidget {
  const _UpNext({
    required this.store,
    required this.onSelect,
    this.horizontal = false,
  });

  final LiveFeedStore store;
  final ValueChanged<int> onSelect;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    return Observer(
      builder: (context) {
        final streams = store.streams;
        final from = store.index.clamp(0, streams.length) + 1;
        final next = [
          for (var i = from; i < streams.length && i < from + 4; i++)
            (i, streams[i]),
        ];
        final label = Text(
          'UP NEXT',
          style: OnsetType.label.copyWith(color: colors.secondary),
        );
        if (horizontal) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              label,
              Expanded(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: next.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (context, i) => SizedBox(
                    width: 190,
                    child: _UpNextRow(
                      stream: next[i].$2,
                      vertical: true,
                      onTap: () => onSelect(next[i].$1),
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 14,
          children: [
            label,
            if (next.isNotEmpty)
              _UpNextCard(
                stream: next.first.$2,
                onTap: () => onSelect(next.first.$1),
              ),
            for (final (j, (i, stream)) in next.skip(1).indexed)
              Opacity(
                opacity: const [0.85, 0.7, 0.55][j],
                child: _UpNextRow(stream: stream, onTap: () => onSelect(i)),
              ),
            const Spacer(),
            Text(
              'Swipe up on the preview, or tap a live in the list. Previews '
              'never start with sound.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: colors.tertiary,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _UpNextCard extends StatelessWidget {
  const _UpNextCard({required this.stream, required this.onTap});

  final StreamTwitch stream;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final name = getReadableName(stream.userName, stream.userLogin);
    return PressScale(
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colors.hairline,
            width: OnsetTokens.hairlineWidth,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          onLongPress: () => showStreamActions(context, stream),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 6,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        StreamThumbnail(stream: stream),
                        Positioned(
                          left: 8,
                          bottom: 8,
                          child: ViewerPill(
                            viewers: stream.viewerCount,
                            height: 22,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    spacing: 10,
                    children: [
                      RingedAvatar(login: stream.userLogin, size: 22),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colors.text,
                              ),
                            ),
                            Text(
                              [
                                stream.title.trim(),
                                if (stream.gameName.isNotEmpty) stream.gameName,
                              ].where((s) => s.isNotEmpty).join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UpNextRow extends StatelessWidget {
  const _UpNextRow({
    required this.stream,
    required this.onTap,
    this.vertical = false,
  });

  final StreamTwitch stream;
  final VoidCallback onTap;

  /// The picture above the lines (portrait's horizontal list).
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final colors = FeedColors.of(context);
    final name = getReadableName(stream.userName, stream.userLogin);
    final picture = ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: StreamThumbnail(stream: stream),
    );
    final lines = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 2,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
        ),
        Text(
          [
            if (stream.gameName.isNotEmpty) stream.gameName,
            formatViewers(stream.viewerCount),
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: OnsetType.tabular(
            TextStyle(fontSize: 12, color: colors.secondary),
          ),
        ),
      ],
    );
    return PressScale(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        onLongPress: () => showStreamActions(context, stream),
        child: vertical
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  AspectRatio(aspectRatio: 16 / 9, child: picture),
                  lines,
                ],
              )
            : Row(
                spacing: 10,
                children: [
                  SizedBox(width: 120, height: 68, child: picture),
                  Expanded(child: lines),
                ],
              ),
      ),
    );
  }
}

/// The page after the last channel: more are loading, or that was all.
class _EndPage extends StatelessWidget {
  const _EndPage({
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onBackToTop,
  });

  final bool loading;

  /// The last page (or the refresh) failed: the list may go on.
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onBackToTop;

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    final Widget content;
    if (loading) {
      content = const Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: [
          CircularProgressIndicator(color: OverImage.text),
          Text(
            'Loading more live channels',
            style: TextStyle(color: OverImage.text),
          ),
        ],
      );
    } else if (error != null) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: [
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: OverImage.text,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          OutlinedButton.icon(
            onPressed: onRetry,
            style: _endButtonStyle,
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: const Text('Try again'),
          ),
        ],
      );
    } else {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: [
          const Text(
            'That’s every live channel here for now',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: OverImage.text,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          OutlinedButton(
            onPressed: onBackToTop,
            style: _endButtonStyle,
            child: const Text('Back to the first'),
          ),
        ],
      );
    }
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(padding: const EdgeInsets.all(32), child: content),
      ),
    );
  }

  static final _endButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: OverImage.text,
    side: const BorderSide(color: Color(0x4DFFFFFF)),
    shape: const StadiumBorder(),
    minimumSize: const Size(0, 44),
  );
}

/// The phone feed, loading: the board's preview and lines in skeleton.
class _PhoneSkeleton extends StatelessWidget {
  const _PhoneSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 48, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: SkeletonLoader(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
          SizedBox(height: 40),
          SkeletonLoader(width: 140, height: 24),
          Row(
            spacing: 10,
            children: [
              SkeletonLoader(
                width: 42,
                height: 42,
                borderRadius: BorderRadius.all(Radius.circular(21)),
              ),
              SkeletonLoader(width: 120, height: 14),
            ],
          ),
          SkeletonLoader(width: 260, height: 14),
          SkeletonLoader(
            height: 48,
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
        ],
      ),
    );
  }
}

/// The tablet feed, loading: the preview card and "Up next".
class _TabletSkeleton extends StatelessWidget {
  const _TabletSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(28, 20, 28, 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 24,
        children: [
          Expanded(
            flex: 860,
            child: AspectRatio(
              aspectRatio: 860 / 600,
              child: SkeletonLoader(
                borderRadius: BorderRadius.all(Radius.circular(24)),
              ),
            ),
          ),
          Expanded(
            flex: 340,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 14,
              children: [
                SkeletonLoader(width: 70, height: 11),
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: SkeletonLoader(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
                SkeletonLoader(height: 68),
                SkeletonLoader(height: 68),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
