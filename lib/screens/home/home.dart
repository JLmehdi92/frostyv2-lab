import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/apis/twitch_directory_service.dart';
import 'package:frosty/screens/activity/activity_screen.dart';
import 'package:frosty/screens/activity/stores/activity_store.dart';
import 'package:frosty/screens/channel/channel.dart';
import 'package:frosty/screens/clips/clips_feed_screen.dart';
import 'package:frosty/screens/home/home_store.dart';
import 'package:frosty/screens/home/live_feed/live_feed.dart';
import 'package:frosty/screens/home/live_feed/stores/live_feed_store.dart';
import 'package:frosty/screens/home/search/search.dart';
import 'package:frosty/screens/home/shell/onset_shell.dart';
import 'package:frosty/screens/home/shell/shell_pages.dart';
import 'package:frosty/screens/home/stream_list/stream_list_store.dart';
import 'package:frosty/screens/home/stream_list/streams_list.dart';
import 'package:frosty/screens/home/top/browse_page.dart';
import 'package:frosty/screens/settings/profile_tab.dart';
import 'package:frosty/screens/settings/settings.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/settings/widgets/release_notes.dart';
import 'package:frosty/screens/whispers/whisper_conversation.dart';
import 'package:frosty/screens/whispers/whispers_screen.dart';
import 'package:frosty/stores/mini_player_store.dart';
import 'package:frosty/stores/whisper_store.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/widgets/launch/launch_intro.dart';
import 'package:frosty/widgets/onset_update_prompt.dart';
import 'package:frosty/widgets/profile_picture.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_pip_mode/simple_pip.dart';

/// The app's first page: the navigation shell (boards Accueil and
/// TabletteAccueil) around Home (Following, Live, Clips), Browse
/// (categories and search), Activity and Profile (account and settings).
class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with OnsetUpdateChecks {
  late final _authStore = context.read<AuthStore>();
  late final _settingsStore = context.read<SettingsStore>();

  late final _whisperStore = context.read<WhisperStore>();
  StreamSubscription<IncomingWhisper>? _whispers;

  late final _activityStore = context.read<ActivityStore>();

  late final _miniPlayer = context.read<MiniPlayerStore>();

  late final _homeStore = HomeStore(
    authStore: _authStore,
    startTab: _settingsStore.startTab,
  );

  ModalRoute<void>? _route;

  /// Search, kept between its opens (it was a tab before the shell).
  SearchSession? _search;

  void _openSearch() => SearchScreen.open(
    context,
    session: _search ??= SearchSession(
      authStore: _authStore,
      twitchApi: context.read<TwitchApi>(),
    ),
  );

  /// A page covers the shell: the mini player is not bound by its chrome.
  var _covered = false;

  /// Home just left a video feed (the clips, the phone's Live) and it is
  /// still fading out: the chrome stays as over a video (no blur over the
  /// video) until it is gone.
  var _videoLeaving = false;
  HomeFeed? _lastFeed;

  /// The Live feed's list, made when Live is first shown (it loads).
  LiveFeedStore? _liveFeed;

  LiveFeedStore get _live => _liveFeed ??= LiveFeedStore(
    authStore: _authStore,
    settingsStore: _settingsStore,
    twitchApi: context.read<TwitchApi>(),
    directoryService: context.read<TwitchDirectoryService?>(),
  );

  /// Whether [feed] is a video page under the phone header: the clips, and
  /// Live on a phone (on a tablet its preview is a card under the bar).
  bool _isVideoFeed(HomeFeed? feed) =>
      feed == HomeFeed.clips ||
      (feed == HomeFeed.live && !context.isLargeScreen);

  /// The clips feed is in picture-in-picture: the window shows the clip
  /// alone, without the shell's chrome.
  var _clipsInPip = false;

  /// setState, or after this frame when the tree is locked (a page being
  /// disposed reports from its dispose).
  void _update(VoidCallback change) => _whenUnlocked(() => setState(change));

  /// Runs [action] now, or after this frame when the tree is locked. The
  /// action reads the state when it runs, not when it was asked for.
  void _whenUnlocked(VoidCallback action) {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance
        ..addPostFrameCallback((_) => _whenUnlocked(action))
        ..ensureVisualUpdate();
      return;
    }
    action();
  }

  Future<void> checkAndShowReleaseNotes() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final prefs = await SharedPreferences.getInstance();

    final currentVersion = packageInfo.version;
    final storedVersion = prefs.getString('last_shown_version');

    // Extract major.minor version (ignore patch)
    final currentMajorMinor = currentVersion.split('.').take(2).join('.');
    final storedMajorMinor = storedVersion?.split('.').take(2).join('.');

    if (storedMajorMinor == null || storedMajorMinor != currentMajorMinor) {
      // Straight from the onboarding, the tile is still flying into the
      // header: the notes wait for it to land, or they would cut it short.
      await LaunchIntro.landed();
      if (!mounted) return;
      // A page opened over Home meanwhile (a link): the notes wait until
      // Home is in front again.
      if (_covered) {
        _notesPending = true;
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: ReleaseNotes.routeName),
          builder: (context) => const ReleaseNotes(),
        ),
      ).then((_) => prefs.setString('last_shown_version', currentVersion));
    }
  }

  @override
  void initState() {
    super.initState();
    _whispers = _whisperStore.incoming.listen(_onWhisper);
    OnsetShell.routeObserver.addListener(_onRoutes);
    _lifecycle = AppLifecycleListener(onResume: _checkPip);
  }

  late final AppLifecycleListener _lifecycle;

  /// Back in front: if the feed's PiP exit went to another handler (the
  /// plugin keeps one), the chrome must not stay hidden.
  Future<void> _checkPip() async {
    if (!_clipsInPip) return;
    bool inPip;
    try {
      inPip = await SimplePip.isPipActivated;
    } catch (e) {
      debugPrint('PiP state unavailable: $e');
      inPip = false;
    }
    if (!inPip) _update(() => _clipsInPip = false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    _onRoutes();
  }

  /// What Home does once it is in front: free the orientation and show the
  /// release notes. Home can be built under a page (the first run's
  /// landing with a deep-linked channel kept on top): then neither may undo
  /// that page's orientation or open over it, and both wait.
  var _orientationPending = true;
  var _notesPending = true;

  void _inFront() {
    if (_orientationPending) {
      _orientationPending = false;
      SystemChrome.setPreferredOrientations([]);
    }
    if (_notesPending) {
      _notesPending = false;
      unawaited(checkAndShowReleaseNotes());
    }
  }

  /// A page opened over the shell, or left it.
  void _onRoutes() => _whenUnlocked(() {
    // Read now: a page pushed and popped while the frame was locked must
    // not leave the shell covered.
    final route = _route;
    final covered = route != null && OnsetShell.routeObserver.covers(route);
    if (!covered && route != null) _inFront();
    if (covered == _covered) return;
    if (covered) _miniPlayer.setShellChrome(null);
    // The chrome is published again by the next build.
    setState(() => _covered = covered);
  });

  /// Tells the mini player what the chrome covers, after this frame.
  void _publishChrome(EdgeInsets chrome) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _covered) return;
      _miniPlayer.setShellChrome(chrome);
    });
  }

  /// A whisper arrived: a notice wherever the viewer is (Home stays under
  /// every other screen), unless its conversation is open.
  void _onWhisper(IncomingWhisper whisper) {
    if (!mounted || _whisperStore.openUserId == whisper.fromUserId) return;
    // One notice at a time: a burst of whispers must not queue for long.
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${whisperPreview(whisper.fromName)} ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: whisperPreview(whisper.whisper.text)),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () => WhisperConversation.open(
              context,
              store: _whisperStore,
              userId: whisper.fromUserId,
              login: whisper.fromLogin,
              displayName: whisper.fromName,
            ),
          ),
        ),
      );
  }

  /// Opens a channel from Activity.
  Future<void> _openChannel(String login) async {
    try {
      final user = await context.read<TwitchApi>().getUser(userLogin: login);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: VideoChat.routeName),
          builder: (context) => VideoChat(
            userId: user.id,
            userName: user.displayName,
            userLogin: user.login,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Activity: could not open $login: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text("Couldn't open $login's channel.")),
        );
    }
  }

  /// The header of [section] (and, for Home, of its [feed]).
  ///
  /// [page]: the header a page is laid out under, which never waits for a
  /// leaving clip (the page must not move when the clip is gone).
  ShellHeader _headerFor(
    ShellSection section,
    HomeFeed feed, {
    bool page = false,
  }) {
    final loggedIn = _authStore.isLoggedIn;
    switch (section) {
      case ShellSection.home:
        final feeds = _homeStore.feeds;
        return ShellHeader(
          showWhispers: loggedIn,
          tabs: [for (final f in feeds) f.label],
          tabIndex: feeds.indexOf(feed),
          onTab: (i) => _homeStore.selectFeed(feeds[i]),
          overVideo: _isVideoFeed(feed) || (!page && _videoLeaving),
          tabsTrailing: feed == HomeFeed.live && context.isLargeScreen
              ? LiveFeedChips(
                  store: _live,
                  onSelect: (id) => selectLiveCategory(
                    _live,
                    _homeStore.liveScrollController,
                    id,
                  ),
                )
              : null,
        );
      case ShellSection.browse:
        const tabs = BrowseTab.values;
        return ShellHeader(
          title: 'Browse',
          showSearch: false,
          showWhispers: loggedIn,
          searchField: true,
          tabs: [for (final tab in tabs) tab.label],
          tabIndex: tabs.indexOf(_homeStore.browseTab),
          onTab: (i) => _homeStore.selectBrowseTab(tabs[i]),
        );
      case ShellSection.activity:
        final tabs = _homeStore.activityTabs;
        return ShellHeader(
          title: 'Activity',
          showMark: false,
          largeTitle: true,
          showWhispers: false,
          tabs: tabs.length < 2
              ? const []
              : [
                  for (final tab in tabs)
                    activityTabLabel(
                      tab,
                      store: _activityStore,
                      whispers: _whisperStore,
                    ),
                ],
          tabIndex: tabs.indexOf(_homeStore.activityTab),
          onTab: (i) => _homeStore.selectActivityTab(tabs[i]),
        );
      case ShellSection.profile:
        return ShellHeader(
          showWhispers: loggedIn,
          onSettings: () => Settings.open(context),
        );
    }
  }

  /// The pages built, with what they were built from: a rebuild of the
  /// shell (a count, a label) hands back the very same page, which Flutter
  /// then skips, so hidden lists are not rebuilt for a badge.
  final _builtPages = <Object, (Object?, Widget)>{};

  Widget _memo(Object key, Object? inputs, Widget Function() build) {
    final built = _builtPages[key];
    if (built != null && built.$1 == inputs) return built.$2;
    final page = build();
    _builtPages[key] = (inputs, page);
    return page;
  }

  Widget _homePage(MediaQueryData media, ShellSection section, HomeFeed feed) {
    return ShellPages<HomeFeed>(
      pages: _homeStore.feeds,
      current: feed,
      motion: ShellPagesMotion.lateral,
      onSettled: () {
        if (_videoLeaving) _update(() => _videoLeaving = false);
      },
      // The clips feed plays: it only exists while it is on screen.
      keepAlive: (page) => page != HomeFeed.clips,
      builder: (context, page) {
        final data = ShellMetrics.page(
          media,
          _headerFor(ShellSection.home, page, page: true),
        );
        final onScreen = section == ShellSection.home;
        // Only the feed chosen plays: leaving it stops the preview at once
        // (not after the fade).
        final liveActive =
            page == HomeFeed.live &&
            feed == HomeFeed.live &&
            onScreen &&
            !_covered;
        return _memo(
          page,
          (data, page == HomeFeed.clips && onScreen, liveActive),
          () => MediaQuery(
            data: data,
            child: switch (page) {
              HomeFeed.following => StreamsList(
                listType: ListType.followed,
                scrollController: _homeStore.followedScrollController,
              ),
              HomeFeed.live => LiveFeed(
                store: _live,
                controller: _homeStore.liveScrollController,
                // Off screen it is offstage too (no ticker): that stops
                // its preview as well.
                active: liveActive,
              ),
              HomeFeed.clips =>
                onScreen
                    ? ClipsFeedScreen(
                        onPipChanged: (pip) => _update(() => _clipsInPip = pip),
                      )
                    : const SizedBox.shrink(),
            },
          ),
        );
      },
    );
  }

  Widget _page(
    BuildContext context,
    MediaQueryData media,
    ShellSection section,
    ShellSection page,
    HomeFeed feed,
  ) {
    if (page == ShellSection.home) return _homePage(media, section, feed);
    final data = ShellMetrics.page(media, _headerFor(page, feed, page: true));
    final loggedIn = _authStore.isLoggedIn;
    final activityTab = _homeStore.activityTab;
    final browseTab = _homeStore.browseTab;
    final active = section == ShellSection.activity && !_covered;
    return _memo(
      page,
      switch (page) {
        ShellSection.activity => (data, loggedIn, activityTab, active),
        ShellSection.browse => (data, browseTab),
        _ => data,
      },
      () => MediaQuery(
        data: data,
        child: switch (page) {
          ShellSection.browse => BrowsePage(
            tab: browseTab,
            categoriesController: _homeStore.categoriesScrollController,
            liveController: _homeStore.browseLiveScrollController,
          ),
          ShellSection.activity => ActivityScreen(
            store: _activityStore,
            whispers: loggedIn ? _whisperStore : null,
            tab: activityTab,
            active: active,
            onOpenChannel: _openChannel,
          ),
          _ => ProfileTab(settingsStore: _settingsStore, authStore: _authStore),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return GestureDetector(
      onTap: FocusScope.of(context).unfocus,
      child: Observer(
        builder: (context) {
          final section = _homeStore.section;
          final feed = _homeStore.feed;
          // Leaving a video feed within Home: it fades out under the header
          // for a moment more.
          if (_isVideoFeed(_lastFeed) &&
              !_isVideoFeed(feed) &&
              section == ShellSection.home) {
            _videoLeaving = true;
          }
          // Home left: the feed is gone with it, nothing to wait for.
          if (section != ShellSection.home) _videoLeaving = false;
          _lastFeed = feed;
          final header = _headerFor(section, feed);
          final loggedIn = _authStore.isLoggedIn;
          final login = loggedIn ? _authStore.user.details?.login : null;

          final chrome = ShellMetrics.chrome(media, header);
          if (!_covered) _publishChrome(chrome);

          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: _systemBars(context, header),
            child: PopScope(
              canPop: _homeStore.canLeave,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop) _homeStore.handleBack();
              },
              child: Scaffold(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                // Room for the floating bar, so that snack bars float above
                // it; the shell draws the bar itself, over the page.
                extendBody: true,
                bottomNavigationBar: SizedBox(
                  height: _clipsInPip ? 0 : chrome.bottom,
                ),
                body: MediaQuery(
                  // The shell lays itself out on the screen's own padding.
                  data: media,
                  child: OnsetShell(
                    chromeHidden: _clipsInPip,
                    section: section,
                    onSection: _homeStore.selectSection,
                    header: header,
                    onSearch: _openSearch,
                    activityBadge: _activityStore.newCount,
                    whispers: loggedIn
                        ? ShellWhispers(
                            unread: _whisperStore.unreadCount,
                            refused:
                                _whisperStore.status == WhisperStatus.refused,
                            onOpen: () =>
                                WhispersScreen.open(context, _whisperStore),
                          )
                        : null,
                    avatar: login == null
                        ? null
                        : FittedBox(child: ProfilePicture(userLogin: login)),
                    body: ShellPages<ShellSection>(
                      pages: ShellSection.values,
                      current: section,
                      builder: (context, page) =>
                          _page(context, media, section, page, feed),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// The system bars over the shell: the theme's (the shell has no app bar
  /// to set them). Over the clips the navigation bar is dark with light
  /// icons, under the black clip, phone and tablet alike; on a phone the
  /// status bar too, over the dark gradient (a tablet's top bar stays
  /// opaque in the theme's colours).
  SystemUiOverlayStyle _systemBars(BuildContext context, ShellHeader header) {
    final theme = Theme.of(context);
    final themed =
        theme.appBarTheme.systemOverlayStyle ??
        (theme.brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark);
    if (!header.overVideo || _clipsInPip) return themed;
    final overClip = themed.copyWith(
      systemNavigationBarColor: FrostyTokens.backgroundDark,
      systemNavigationBarIconBrightness: Brightness.light,
    );
    if (context.isLargeScreen) return overClip;
    return overClip.copyWith(
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    );
  }

  @override
  void dispose() {
    OnsetShell.routeObserver.removeListener(_onRoutes);
    _lifecycle.dispose();
    _miniPlayer.setShellChrome(null);
    _whispers?.cancel();
    _search?.dispose();
    _homeStore.dispose();
    _liveFeed?.dispose();
    super.dispose();
  }
}
