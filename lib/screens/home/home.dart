import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/screens/activity/activity_screen.dart';
import 'package:frosty/screens/activity/stores/activity_store.dart';
import 'package:frosty/screens/channel/channel.dart';
import 'package:frosty/screens/clips/clips_feed_screen.dart';
import 'package:frosty/screens/home/home_store.dart';
import 'package:frosty/screens/home/search/search.dart';
import 'package:frosty/screens/home/shell/onset_shell.dart';
import 'package:frosty/screens/home/shell/shell_pages.dart';
import 'package:frosty/screens/home/stream_list/stream_list_store.dart';
import 'package:frosty/screens/home/stream_list/streams_list.dart';
import 'package:frosty/screens/home/top/categories/categories.dart';
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
import 'package:frosty/widgets/onset_update_prompt.dart';
import 'package:frosty/widgets/profile_picture.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// Home just left the clips and the feed is still fading out: the
  /// chrome stays as over a video (no blur over the clip) until it is gone.
  var _clipsLeaving = false;
  HomeFeed? _lastFeed;

  /// The clips feed is in picture-in-picture: the window shows the clip
  /// alone, without the shell's chrome.
  var _clipsInPip = false;

  /// setState, or after this frame when the tree is locked (a page being
  /// disposed reports from its dispose).
  void _update(VoidCallback change) {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _update(change));
      return;
    }
    setState(change);
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
      if (!mounted) return;

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
    SystemChrome.setPreferredOrientations([]);
    checkAndShowReleaseNotes();
    _whispers = _whisperStore.incoming.listen(_onWhisper);
    OnsetShell.routeObserver.addListener(_onRoutes);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    _onRoutes();
  }

  /// A page opened over the shell, or left it.
  void _onRoutes() {
    final route = _route;
    final covered = route != null && OnsetShell.routeObserver.covers(route);
    if (covered == _covered) return;
    if (covered) _miniPlayer.setShellChrome(null);
    // The chrome is published again by the next build.
    _update(() => _covered = covered);
  }

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
          overVideo: feed == HomeFeed.clips || (!page && _clipsLeaving),
        );
      case ShellSection.browse:
        return ShellHeader(
          title: 'Browse',
          showSearch: false,
          showWhispers: loggedIn,
          searchField: true,
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
        return ShellHeader(showWhispers: loggedIn);
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
        if (_clipsLeaving) _update(() => _clipsLeaving = false);
      },
      // The clips feed plays: it only exists while it is on screen.
      keepAlive: (page) => page != HomeFeed.clips,
      builder: (context, page) {
        final data = ShellMetrics.page(
          media,
          _headerFor(ShellSection.home, page, page: true),
        );
        final onScreen = section == ShellSection.home;
        return _memo(
          page,
          (data, page == HomeFeed.clips && onScreen),
          () => MediaQuery(
            data: data,
            child: switch (page) {
              HomeFeed.following => StreamsList(
                listType: ListType.followed,
                scrollController: _homeStore.followedScrollController,
              ),
              HomeFeed.live => StreamsList(
                listType: ListType.top,
                scrollController: _homeStore.liveScrollController,
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
    final active = section == ShellSection.activity && !_covered;
    return _memo(
      page,
      page == ShellSection.activity
          ? (data, loggedIn, activityTab, active)
          : data,
      () => MediaQuery(
        data: data,
        child: switch (page) {
          ShellSection.browse => Categories(
            scrollController: _homeStore.categoriesScrollController,
          ),
          ShellSection.activity => ActivityScreen(
            store: _activityStore,
            whispers: loggedIn ? _whisperStore : null,
            tab: activityTab,
            active: active,
            onOpenChannel: _openChannel,
          ),
          _ => Settings(settingsStore: _settingsStore, embedded: true),
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
          // Leaving the clips within Home: the feed fades out under the
          // header for a moment more.
          if (_lastFeed == HomeFeed.clips &&
              feed != HomeFeed.clips &&
              section == ShellSection.home) {
            _clipsLeaving = true;
          }
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
  /// to set them), with light icons and a dark navigation bar over the
  /// clips on a phone, where the header is a dark gradient over the video.
  SystemUiOverlayStyle _systemBars(BuildContext context, ShellHeader header) {
    final theme = Theme.of(context);
    final themed =
        theme.appBarTheme.systemOverlayStyle ??
        (theme.brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark);
    if (!header.overVideo || context.isLargeScreen || _clipsInPip) {
      return themed;
    }
    return themed.copyWith(
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: FrostyTokens.backgroundDark,
      systemNavigationBarIconBrightness: Brightness.light,
    );
  }

  @override
  void dispose() {
    OnsetShell.routeObserver.removeListener(_onRoutes);
    _miniPlayer.setShellChrome(null);
    _whispers?.cancel();
    _search?.dispose();
    _homeStore.dispose();
    super.dispose();
  }
}
