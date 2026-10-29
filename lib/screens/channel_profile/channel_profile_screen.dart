import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/models/channel_profile.dart';
import 'package:onset/models/user.dart';
import 'package:onset/models/vod.dart';
import 'package:onset/screens/channel/channel.dart';
import 'package:onset/screens/channel/stores/channel_info_store.dart';
import 'package:onset/screens/channel_profile/stores/channel_profile_store.dart';
import 'package:onset/screens/channel_profile/widgets/profile_about_tab.dart';
import 'package:onset/screens/channel_profile/widgets/profile_header.dart';
import 'package:onset/screens/channel_profile/widgets/profile_home_tab.dart';
import 'package:onset/screens/channel_profile/widgets/profile_live_card.dart';
import 'package:onset/screens/channel_profile/widgets/profile_parts.dart';
import 'package:onset/screens/channel_profile/widgets/profile_schedule_tab.dart';
import 'package:onset/screens/channel_profile/widgets/profile_videos_tab.dart';
import 'package:onset/screens/clips/stores/channel_clips_store.dart';
import 'package:onset/screens/clips/widgets/channel_clips_tab.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/vod/stores/channel_videos_store.dart';
import 'package:onset/services/notifications/schedule_reminders.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/utils/link_router.dart';
import 'package:onset/utils/modal_bottom_sheet.dart';
import 'package:onset/utils/share_link.dart';
import 'package:onset/widgets/alert_message.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';
import 'package:onset/widgets/skeleton_loader.dart';
import 'package:onset/widgets/state_views.dart';
import 'package:onset/widgets/user_actions_modal.dart';
import 'package:provider/provider.dart';

/// The profile's tabs, in the boards' order.
enum ProfileTab {
  home('Home'),
  videos('Videos'),
  clips('Clips'),
  schedule('Schedule'),
  about('About');

  const ProfileTab(this.label);

  final String label;
}

/// A channel's profile page (boards Profil and ProfilTablette).
///
/// On a phone, the banner folds into a bar (Back, the name, Share, More)
/// over the avatar, the name, the channel's stream, Watch, Follow and
/// Subscribe; the tabs stay pinned under the bar. On a tablet, the banner
/// stays, the profile is a column on the left and the tabs fill the right.
/// Home, Videos, Clips, Schedule and About in both.
class ChannelProfileScreen extends StatefulWidget {
  static const routeName = 'ChannelProfile';

  const ChannelProfileScreen({
    super.key,
    required this.login,
    this.userId,
    this.displayName,
    this.initialTab = ProfileTab.home,
    this.fromChannel = false,
  });

  final String login;

  /// Known by the caller: Chat and More work before (or without) the
  /// profile.
  final String? userId;

  /// Shown until the profile loads.
  final String? displayName;
  final ProfileTab initialTab;

  /// Opened from this channel's screen: Watch and Chat go back to it.
  final bool fromChannel;

  /// From this width (on a large screen), the two-column tablet layout.
  static const tabletMinWidth = 720.0;

  static Future<void> open(
    BuildContext context, {
    required String login,
    String? userId,
    String? displayName,
    ProfileTab initialTab = ProfileTab.home,
    bool fromChannel = false,
  }) => Navigator.push(
    context,
    MaterialPageRoute(
      settings: const RouteSettings(name: routeName),
      builder: (context) => ChannelProfileScreen(
        login: login,
        userId: userId,
        displayName: displayName,
        initialTab: initialTab,
        fromChannel: fromChannel,
      ),
    ),
  );

  @override
  State<ChannelProfileScreen> createState() => _ChannelProfileScreenState();
}

class _ChannelProfileScreenState extends State<ChannelProfileScreen>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(
    length: ProfileTab.values.length,
    vsync: this,
    initialIndex: widget.initialTab.index,
  );

  late final _store = ChannelProfileStore(
    login: widget.login,
    profileService: context.twitchChannelProfileService,
    helixUser: (login) => context.twitchApi.getUser(userLogin: login),
  );

  /// Each video type's list, made the first time it shows (past broadcasts
  /// at once: Home shows them).
  final _videoStores = <VodType, ChannelVideosStore>{};
  var _videoType = VodType.archive;

  late final _clips = ChannelClipsStore(
    login: widget.login,
    clipService: context.twitchClipService,
  );

  /// Home's "Popular clips": this week's top, whatever the Clips tab picks.
  late final _homeClips = ChannelClipsStore(
    login: widget.login,
    clipService: context.twitchClipService,
  );

  /// What a phone's pinned bar and tabs cover of its tab lists.
  final _overlap = SliverOverlapAbsorberHandle();

  /// The height of a phone's header under the banner, as last laid out
  /// (a first guess until then).
  double? _headerHeight;

  /// A tablet's Home, Schedule and About lists (a phone's share the
  /// nested scroll view's).
  final _scrollControllers = {
    for (final tab in [ProfileTab.home, ProfileTab.schedule, ProfileTab.about])
      tab: ScrollController(),
  };

  /// Whether the viewer follows this channel, once its id is known.
  ChannelInfoStore? _follow;

  late final List<ReactionDisposer> _reactions;

  AuthStore? get _auth => context.read<AuthStore?>();

  ChannelVideosStore _videosOf(VodType type) => _videoStores.putIfAbsent(
    type,
    () => ChannelVideosStore(
      login: widget.login,
      type: type,
      vodService: context.twitchVodService,
    ),
  );

  @override
  void initState() {
    super.initState();
    unawaited(_store.load());
    // Home shows the next stream.
    unawaited(_store.loadSchedule());
    final auth = _auth;
    _reactions = [
      // Reminders follow the schedule as read: a moved segment's moves, a
      // cancelled one's goes.
      reaction((_) => _store.schedule, (ChannelSchedule? schedule) {
        if (schedule == null) return;
        unawaited(
          ScheduleReminders.shared?.sync(widget.login, schedule.segments),
        );
      }),
      // The follow is asked once the channel's id is known, again when the
      // viewer changes, never on the viewer's own channel.
      autorun((_) {
        final id = _store.userId ?? widget.userId;
        if (id != null) _syncFollow(id, _viewerOf(auth));
      }),
    ];
    _tabs.addListener(_onTab);
    _started = true;
  }

  /// Past [initState]: a change to what the page shows needs a build.
  var _started = false;

  /// The viewer [_follow] was last asked for.
  String? _followViewer;

  void _syncFollow(String id, UserTwitch? viewer) {
    final previous = _follow;
    if (viewer != null &&
        viewer.login.toLowerCase() == widget.login.toLowerCase()) {
      // Their own channel: nothing to follow, nothing to ask.
      _follow = null;
      _followViewer = viewer.id;
      if (previous != null) {
        previous.dispose();
        if (_started) setState(() {});
      }
      return;
    }
    if (previous != null && previous.channelId == id) {
      if (_followViewer != viewer?.id) {
        _followViewer = viewer?.id;
        previous.viewerChanged();
      }
      return;
    }
    final auth = _auth;
    _followViewer = viewer?.id;
    _follow = ChannelInfoStore(
      channelId: id,
      api: context.twitchApi,
      viewerId: () => _viewerOf(auth)?.id,
      // No player here to give the network to first.
      startDelay: Duration.zero,
    )..start();
    previous?.dispose();
    // Known at the opening, the first build shows it; known later, it
    // needs one.
    if (_started) setState(() {});
  }

  void _onTab() {
    if (ProfileTab.values[_tabs.index] == ProfileTab.schedule &&
        _store.schedule == null &&
        !_store.scheduleLoading) {
      unawaited(_store.loadSchedule());
    }
  }

  @override
  void dispose() {
    for (final dispose in _reactions) {
      dispose();
    }
    _tabs
      ..removeListener(_onTab)
      ..dispose();
    _store.dispose();
    for (final store in _videoStores.values) {
      store.dispose();
    }
    _clips.dispose();
    _homeClips.dispose();
    _follow?.dispose();
    _overlap.dispose();
    for (final controller in _scrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String get _name => _store.displayName ?? widget.displayName ?? widget.login;

  String? get _userId => _store.userId ?? widget.userId;

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AlertMessage(message: message, centered: false)),
    );
  }

  /// Pull to refresh; a failure over a shown profile is said, not silent.
  Future<void> _refresh() async {
    unawaited(_follow?.refreshFollowing());
    await _store.refresh();
    if (_store.error != null && _store.profile != null) {
      _say("Couldn't refresh this channel");
    }
  }

  /// Home's pull: the profile, the schedule and both grids.
  Future<void> _refreshHome() => Future.wait([
    _refresh(),
    _videosOf(VodType.archive).refresh(),
    _homeClips.refresh(),
  ]);

  void _openChannel() {
    if (widget.fromChannel) {
      Navigator.of(context).pop();
      return;
    }
    final id = _userId;
    if (id == null) {
      _say("Couldn't open this channel, check your connection");
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: VideoChat.routeName),
        builder: (context) =>
            VideoChat(userId: id, userName: _name, userLogin: widget.login),
      ),
    );
  }

  /// The finger is down on Watch or the live card: the token is on its way
  /// (nothing from the channel's own screen, it already plays).
  VoidCallback? get _preload =>
      widget.fromChannel ? null : () => preloadChannel(context, widget.login);

  /// The signed-in viewer's login (read in observers: signing in or out
  /// shows or hides Follow at once).
  String? get _viewerLogin => _viewerOf(_auth)?.login;

  /// The signed-in viewer (its details are only read once signed in).
  static UserTwitch? _viewerOf(AuthStore? auth) =>
      auth != null && auth.isLoggedIn ? auth.user.details : null;

  bool get _ownChannel =>
      _viewerLogin?.toLowerCase() == widget.login.toLowerCase();

  /// Follow: signed in, not on the viewer's own channel, once the id is
  /// known.
  ChannelInfoStore? get _followFor =>
      _viewerLogin == null || _ownChannel ? null : _follow;

  bool _showSubscribe(ChannelProfile? profile) => profileOffersSubscribe(
    profile: profile,
    login: widget.login,
    viewerLogin: _viewerLogin,
  );

  Future<void> _share() =>
      shareLink(context, 'https://www.twitch.tv/${widget.login}');

  void _more() {
    final id = _userId;
    if (id == null) return;
    final settings = context.settingsStore;
    showModalBottomSheetWithProperFocus(
      context: context,
      builder: (context) => UserActionsModal(
        authStore: context.authStore,
        name: _name,
        userLogin: widget.login,
        userId: id,
        showPinOption: true,
        isPinned: settings.pinnedChannelIds.contains(id),
        showProfile: false,
      ),
    );
  }

  void _openLink(String url) => unawaited(
    LinkRouter.open(
      url,
      launchExternal: context.settingsStore.launchUrlExternal,
    ),
  );

  void _back() => Navigator.of(context).maybePop();

  /// Share and More over the banner ([onBar]: on the folded bar).
  List<Widget> _actions({double onBar = 0, double disc = 0.45}) => [
    ProfileRoundButton(
      glyph: SheetGlyphKind.share,
      tooltip: 'Share',
      onPressed: () => unawaited(_share()),
      onBar: onBar,
      disc: disc,
    ),
    if (_userId != null)
      ProfileRoundButton(
        glyph: SheetGlyphKind.more,
        tooltip: 'More',
        onPressed: _more,
        onBar: onBar,
        disc: disc,
      ),
  ];

  // ---------------------------------------------------------------------
  // Tabs.

  /// One of Home, Schedule and About: padded, pull to refresh, its scroll
  /// position kept.
  Widget _scrollTab(
    ProfileTab tab,
    Widget child, {
    required bool nested,
    required List<Widget> leading,
    required double edgeOffset,
    Future<void> Function()? onRefresh,
  }) {
    final bottom = MediaQuery.paddingOf(context).bottom + 24;
    return RefreshIndicator.adaptive(
      onRefresh: onRefresh ?? _refresh,
      // Under a phone's pinned bar and tabs.
      edgeOffset: edgeOffset,
      child: CustomScrollView(
        key: PageStorageKey(tab.name),
        controller: nested ? null : _scrollControllers[tab],
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          ...leading,
          SliverPadding(
            padding: nested
                ? EdgeInsets.fromLTRB(
                    16 + MediaQuery.paddingOf(context).left,
                    14,
                    16 + MediaQuery.paddingOf(context).right,
                    bottom,
                  )
                : EdgeInsets.fromLTRB(0, 20, 0, bottom),
            sliver: SliverToBoxAdapter(child: child),
          ),
        ],
      ),
    );
  }

  Widget _status(String message, VoidCallback onRetry) =>
      FeedStatusView.error(message: message, onRetry: onRetry);

  List<Widget> _tabViews({
    required bool nested,
    required bool large,
    required List<Widget> leading,
    double edgeOffset = 0,
  }) {
    final profile = _store.profile;
    final retrying = _store.isLoading && profile == null;
    final error = _store.error;
    return [
      _scrollTab(
        ProfileTab.home,
        nested: nested,
        leading: leading,
        edgeOffset: edgeOffset,
        onRefresh: _refreshHome,
        ProfileHomeContent(
          login: widget.login,
          channelName: _name,
          profile: profile,
          videos: _videosOf(VodType.archive),
          clips: _homeClips,
          schedule: _store.schedule,
          reminders: ScheduleReminders.shared,
          onOpenChannel: _openChannel,
          onPreload: _preload,
          onViewAllVideos: () {
            setState(() => _videoType = VodType.archive);
            _tabs.animateTo(ProfileTab.videos.index);
          },
          onViewAllClips: () => _tabs.animateTo(ProfileTab.clips.index),
          showStream: large,
          large: large,
          status: error != null && profile == null && !retrying
              ? _status(error, () => unawaited(_store.load()))
              : null,
        ),
      ),
      KeyedSubtree(
        key: const PageStorageKey('videos'),
        child: ProfileVideosTab(
          type: _videoType,
          onType: (type) => setState(() => _videoType = type),
          storeFor: _videosOf,
          nested: nested,
          leadingSlivers: leading,
          refreshEdgeOffset: edgeOffset,
        ),
      ),
      KeyedSubtree(
        key: const PageStorageKey('clips'),
        child: ChannelClipsTab(
          store: _clips,
          nested: nested,
          leadingSlivers: leading,
          refreshEdgeOffset: edgeOffset,
        ),
      ),
      _scrollTab(
        ProfileTab.schedule,
        nested: nested,
        leading: leading,
        edgeOffset: edgeOffset,
        _scheduleContent(large: large),
      ),
      _scrollTab(
        ProfileTab.about,
        nested: nested,
        leading: leading,
        edgeOffset: edgeOffset,
        profile == null
            ? (_store.loaded && !retrying
                  ? _status(
                      error ?? 'No details',
                      () => unawaited(_store.load()),
                    )
                  : const _AboutSkeleton())
            : ProfileAboutContent(profile: profile, onOpenLink: _openLink),
      ),
    ];
  }

  Widget _scheduleContent({required bool large}) {
    final schedule = _store.schedule;
    if (schedule != null) {
      return ProfileScheduleContent(
        schedule: schedule,
        now: DateTime.now(),
        reminders: ScheduleReminders.shared,
        login: widget.login,
        channelName: _name,
        large: large,
      );
    }
    final error = _store.scheduleError;
    if (error != null && !_store.scheduleLoading) {
      return _status(error, () => unawaited(_store.loadSchedule()));
    }
    return const _ScheduleSkeleton();
  }

  // ---------------------------------------------------------------------
  // Layouts.

  void _onHeaderHeight(double height) {
    if (!mounted || (_headerHeight ?? -1) == height) return;
    setState(() => _headerHeight = height);
  }

  Widget _phone(BuildContext context) {
    final media = MediaQuery.of(context);
    final profile = _store.profile;
    final loading = profile == null && !_store.loaded;
    final name = _name;
    final bannerHeight = (media.size.height * 0.2).clamp(96.0, 168.0);
    final tabsHeight =
        ProfileTabBar.heightFor(large: false) - 15 + media.textScaler.scale(15);
    final follow = _followFor;
    final showSubscribe = _showSubscribe(profile);
    // Until laid out: the name's row, the actions, and the stream card
    // once there is one.
    final guess =
        58.0 +
        58 +
        (profile != null && !ProfileStreamFacts(profile).isEmpty ? 97 : 0) +
        (media.textScaler.scale(24) - 24);
    return NestedScrollView(
      headerSliverBuilder: (context, _) => [
        SliverOverlapAbsorber(
          handle: _overlap,
          sliver: SliverPersistentHeader(
            pinned: true,
            delegate: ProfilePhoneHeader(
              topPadding: media.padding.top,
              bannerHeight: bannerHeight,
              contentHeight: _headerHeight ?? guess,
              tabsHeight: tabsHeight,
              title: name,
              banner: ProfileBanner(profile: profile),
              content: ProfileMeasured(
                onHeight: _onHeaderHeight,
                child: ProfileHeader(
                  login: widget.login,
                  displayName: name,
                  profile: profile,
                  loading: loading,
                  onOpenChannel: _openChannel,
                  onPreload: _preload,
                  follow: follow,
                  showSubscribe: showSubscribe,
                ),
              ),
              tabs: ProfileTabBar(
                controller: _tabs,
                labels: [for (final tab in ProfileTab.values) tab.label],
                padding: EdgeInsetsDirectional.only(
                  start: 16 + media.padding.left,
                ),
              ),
              actions: (onBar) => _actions(onBar: onBar),
              onBack: _back,
            ),
          ),
        ),
      ],
      body: TabBarView(
        controller: _tabs,
        children: _tabViews(
          nested: true,
          large: false,
          leading: [SliverOverlapInjector(handle: _overlap)],
          edgeOffset:
              media.padding.top + ProfilePhoneHeader.barHeight + tabsHeight,
        ),
      ),
    );
  }

  Widget _tablet(BuildContext context, double width) {
    final padding = MediaQuery.paddingOf(context);
    final profile = _store.profile;
    final loading = profile == null && !_store.loaded;
    final name = _name;
    final railWidth = width >= 1100 ? 330.0 : 280.0;
    final start = 32 + padding.left;
    final paneStart = start + railWidth + 38;
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: padding.top + 230,
          child: ProfileBanner(profile: profile, large: true),
        ),
        PositionedDirectional(
          start: start,
          top: padding.top + 150,
          bottom: 0,
          width: railWidth,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: padding.bottom + 24),
            child: ProfileRail(
              login: widget.login,
              displayName: name,
              profile: profile,
              loading: loading,
              onOpenChannel: _openChannel,
              onPreload: _preload,
              onOpenLink: _openLink,
              follow: _followFor,
              showSubscribe: _showSubscribe(profile),
            ),
          ),
        ),
        PositionedDirectional(
          start: paneStart,
          end: 32 + padding.right,
          top: padding.top + 196,
          bottom: 0,
          child: MediaQuery.removePadding(
            context: context,
            removeLeft: true,
            removeRight: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProfileTabBar(
                  controller: _tabs,
                  labels: [for (final tab in ProfileTab.values) tab.label],
                  large: true,
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: _tabViews(
                      nested: false,
                      large: true,
                      leading: const [],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        PositionedDirectional(
          start: 20 + padding.left,
          top: padding.top + 16,
          child: ProfileRoundButton(
            glyph: SheetGlyphKind.chevronLeft,
            tooltip: 'Back',
            onPressed: _back,
            disc: 0.5,
          ),
        ),
        PositionedDirectional(
          end: 20 + padding.right,
          top: padding.top + 16,
          child: Row(spacing: 8, children: _actions(disc: 0.5)),
        ),
      ],
    );
  }

  Widget _notFound(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return Stack(
      children: [
        Positioned.fill(
          child: _status('Channel not found', () => unawaited(_store.load())),
        ),
        PositionedDirectional(
          start: 8 + padding.left,
          top: padding.top + 6,
          child: ProfileRoundButton(
            glyph: SheetGlyphKind.chevronLeft,
            tooltip: 'Back',
            onPressed: _back,
            onBar: 1,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Observer(
        builder: (context) {
          if (_store.notFound) {
            return AnnotatedRegion(
              value: profileOverlayStyle(context, collapsed: true),
              child: _notFound(context),
            );
          }
          // The page fills the window: its width picks the layout.
          final width = MediaQuery.sizeOf(context).width;
          final tablet =
              context.isLargeScreen &&
              width >= ChannelProfileScreen.tabletMinWidth;
          if (!tablet) return _phone(context);
          return AnnotatedRegion(
            value: profileOverlayStyle(context, collapsed: false),
            child: _tablet(context, width),
          );
        },
      ),
    );
  }
}

/// The schedule loading: two cards' shapes.
class _ScheduleSkeleton extends StatelessWidget {
  const _ScheduleSkeleton();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 12,
    children: [
      SkeletonLoader(
        height: 80,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      SkeletonLoader(
        height: 80,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ],
  );
}

/// About loading: the title and a few lines.
class _AboutSkeleton extends StatelessWidget {
  const _AboutSkeleton();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 10,
    children: [
      SkeletonLoader(width: 180, height: 18),
      SkeletonLoader(width: 220, height: 12),
      SkeletonLoader(height: 12),
      SkeletonLoader(height: 12),
      SkeletonLoader(width: 160, height: 12),
    ],
  );
}
