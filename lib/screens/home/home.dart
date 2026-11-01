import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_directory_service.dart';
import 'package:onset/l10n/enum_labels.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/activity/activity_screen.dart';
import 'package:onset/screens/activity/stores/activity_store.dart';
import 'package:onset/screens/channel/channel.dart';
import 'package:onset/screens/clips/clips_feed_screen.dart';
import 'package:onset/screens/clips/stores/clips_feed_store.dart';
import 'package:onset/screens/home/language_prompt.dart';
import 'package:onset/screens/home/live_feed/live_feed.dart';
import 'package:onset/screens/home/live_feed/stores/live_feed_store.dart';
import 'package:onset/screens/home/search/search.dart';
import 'package:onset/screens/home/shell/onset_shell.dart';
import 'package:onset/screens/home/shell/shell_pages.dart';
import 'package:onset/screens/home/stores/home_store.dart';
import 'package:onset/screens/home/stream_list/stores/stream_list_store.dart';
import 'package:onset/screens/home/stream_list/streams_list.dart';
import 'package:onset/screens/home/top/browse_page.dart';
import 'package:onset/screens/settings/profile_tab.dart';
import 'package:onset/screens/settings/settings.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/release_notes.dart';
import 'package:onset/screens/whispers/whisper_conversation.dart';
import 'package:onset/screens/whispers/whisper_notice.dart';
import 'package:onset/screens/whispers/whispers_screen.dart';
import 'package:onset/stores/mini_player_store.dart';
import 'package:onset/stores/whisper_store.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/launch/launch_intro.dart';
import 'package:onset/widgets/onset_update_prompt.dart';
import 'package:onset/widgets/profile_picture.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_pip_mode/simple_pip.dart';

/// The app's first page: the navigation shell
/// around Home (Following, Live, Clips), Browse
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

  /// The clips feed's list and the clip shown, made when Clips is first
  /// shown and kept across its visits (the feed itself, with its players,
  /// lives only while it is on screen). Another browse language starts a
  /// new one.
  ClipsFeedStore? _clipsFeed;

  ClipsFeedStore get _clips {
    final language = _settingsStore.streamLanguage;
    final kept = _clipsFeed;
    if (kept != null && kept.language == language) return kept;
    return _clipsFeed = ClipsFeedStore(
      clipService: context.twitchClipService,
      language: language,
    );
  }

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

  /// Opens the release notes after an update whose version they have an
  /// entry for (see [shouldShowReleaseNotes]); a first launch only notes the
  /// version.
  Future<void> checkAndShowReleaseNotes() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final prefs = await SharedPreferences.getInstance();

    final currentVersion = packageInfo.version;
    final storedVersion = prefs.getString('last_shown_version');

    final notes = await ReleaseNotes.read();
    if (notes == null) {
      // Unreadable. A first launch never shows notes anyway: remember its
      // version, or every later update would look like a first launch. After
      // an update, decide nothing: the old version stays, the next launch
      // tries again.
      if (storedVersion == null) {
        await prefs.setString('last_shown_version', currentVersion);
      }
      return;
    }

    if (!shouldShowReleaseNotes(
      lastShown: storedVersion,
      current: currentVersion,
      notes: notes,
    )) {
      if (storedVersion != currentVersion) {
        await prefs.setString('last_shown_version', currentVersion);
      }
      return;
    }

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
        // Opened by itself: "Updated to <current>", "You were on <stored>".
        builder: (context) =>
            ReleaseNotes(updatedTo: currentVersion, updatedFrom: storedVersion),
      ),
    ).then((_) => prefs.setString('last_shown_version', currentVersion));
  }

  @override
  void initState() {
    super.initState();
    // Answered before: the update offer has nothing to wait for.
    if (context.read<SettingsStore>().languagePromptVersion >=
        kLanguagePromptVersion) {
      _settleLanguage();
    }
    _whispers = _whisperStore.incoming.listen(_onWhisper);
    _disposeAccount = reaction((_) => _whisperStore.me, _onAccount);
    OnsetShell.routeObserver.addListener(_onRoutes);
    _lifecycle = AppLifecycleListener(onResume: _checkPip);
    // Nothing plays under the launch intro (the clips may be the start tab).
    LaunchIntro.running.addListener(_onIntro);
    // A notice about the account's token (made for another app), once.
    _disposeTokenNotice = reaction(
      (_) => _authStore.tokenNotice,
      _showTokenNotice,
      fireImmediately: true,
    );
  }

  late final ReactionDisposer _disposeTokenNotice;

  Future<void> _showTokenNotice(TokenNotice? notice) async {
    if (notice == null) return;
    // Not under the launch intro's tile.
    await LaunchIntro.landed();
    if (!mounted) return;
    _authStore.clearTokenNotice();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(notice.label(context.l10n)),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  void _onIntro() => _update(() {});

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

  /// What Home does once it is in front: free the orientation, ask the
  /// language once, then show the release notes. Home can be built under a
  /// page (the first run's landing with a deep-linked channel kept on top):
  /// then none of them may undo that page's orientation or open over it,
  /// and they wait.
  var _orientationPending = true;
  var _languagePending = true;
  var _notesPending = true;

  void _inFront() {
    if (_orientationPending) {
      _orientationPending = false;
      SystemChrome.setPreferredOrientations([]);
    }
    if (_languagePending || _notesPending) unawaited(_greet());
  }

  /// The language question, then the release notes; one run at a time
  /// (Home comes back in front while the question is open).
  var _greeting = false;

  Future<void> _greet() async {
    if (_greeting) return;
    _greeting = true;
    try {
      if (_languagePending && !await _askLanguageOnce()) return;
      if (_notesPending && mounted) {
        _notesPending = false;
        await checkAndShowReleaseNotes();
      }
    } finally {
      _greeting = false;
    }
  }

  /// Completes once the language question is settled (answered now, or
  /// before): the update offer waits for it ([beforeUpdateOffer]).
  final _languageSettled = Completer<void>();

  @override
  Future<void> beforeUpdateOffer() => _languageSettled.future;

  void _settleLanguage() {
    if (!_languageSettled.isCompleted) _languageSettled.complete();
  }

  /// Asks the language of an install from before French
  /// ([SettingsStore.languagePromptVersion] under [kLanguagePromptVersion]):
  /// after the launch intro has landed, and only with Home in front. New
  /// installs answered on the onboarding's Intro. Says whether the question
  /// is settled (else Home asks when it is in front again).
  Future<bool> _askLanguageOnce() async {
    final settings = context.read<SettingsStore>();
    if (settings.languagePromptVersion >= kLanguagePromptVersion) {
      _languagePending = false;
      _settleLanguage();
      return true;
    }
    await LaunchIntro.landed();
    if (!mounted || _covered) return false;
    _languagePending = false;
    await showLanguagePrompt(context, settings: settings);
    _settleLanguage();
    return mounted;
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
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    final notice = messenger.showSnackBar(
      whisperNotice(
        context,
        whisper,
        store: _whisperStore,
        onOpen: () => WhisperConversation.open(
          context,
          store: _whisperStore,
          userId: whisper.fromUserId,
          login: whisper.fromLogin,
          displayName: whisper.fromName,
        ),
      ),
    );
    _whisperNotice = notice;
    // Shown first (the others were cleared): it is the current one until
    // it closes.
    unawaited(
      notice.closed.then((_) {
        if (identical(_whisperNotice, notice)) _whisperNotice = null;
      }),
    );
  }

  /// The whisper notice on screen, if any.
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _whisperNotice;

  late final ReactionDisposer _disposeAccount;

  /// Another account (or none): the previous one's notice goes.
  void _onAccount(String? _) {
    final notice = _whisperNotice;
    _whisperNotice = null;
    notice?.close();
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
          SnackBar(
            content: Text(context.l10n.homeOpenChannelFailed(login: login)),
          ),
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
          tabs: [for (final f in feeds) f.label(context.l10n)],
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
          title: context.l10n.shellSectionBrowse,
          showSearch: false,
          showWhispers: loggedIn,
          searchField: true,
          tabs: [for (final tab in tabs) tab.label(context.l10n)],
          tabIndex: tabs.indexOf(_homeStore.browseTab),
          onTab: (i) => _homeStore.selectBrowseTab(tabs[i]),
        );
      case ShellSection.activity:
        final tabs = _homeStore.activityTabs;
        // On a tablet the whispers are a column beside the notifications:
        // no tabs.
        final tabbed = tabs.length > 1 && !context.isLargeScreen;
        return ShellHeader(
          title: context.l10n.shellSectionActivity,
          showMark: false,
          largeTitle: true,
          showWhispers: false,
          tabs: tabbed
              ? [for (final tab in tabs) tab.label(context.l10n)]
              : const [],
          tabBadges: tabbed
              ? [
                  for (final tab in tabs)
                    activityTabBadge(
                      tab,
                      store: _activityStore,
                      whispers: _whisperStore,
                    ),
                ]
              : null,
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

  Widget _homePage(ShellSection section, HomeFeed feed) {
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
        final onScreen = section == ShellSection.home;
        // Only the feed chosen plays: leaving it stops the preview at once
        // (not after the fade).
        final liveActive =
            page == HomeFeed.live &&
            feed == HomeFeed.live &&
            onScreen &&
            !_covered;
        // The clips the same way, and never under the launch intro.
        final clipsActive =
            page == HomeFeed.clips &&
            feed == HomeFeed.clips &&
            onScreen &&
            !_covered &&
            !LaunchIntro.running.value;
        return _ShellPageMedia(
          header: _headerFor(ShellSection.home, page, page: true),
          child: _memo(
            page,
            (page == HomeFeed.clips && onScreen, liveActive, clipsActive),
            () => switch (page) {
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
                        store: _clips,
                        active: clipsActive,
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
    ShellSection section,
    ShellSection page,
    HomeFeed feed,
  ) {
    if (page == ShellSection.home) return _homePage(section, feed);
    final loggedIn = _authStore.isLoggedIn;
    final activityTab = _homeStore.activityTab;
    final browseTab = _homeStore.browseTab;
    final active = section == ShellSection.activity && !_covered;
    return _ShellPageMedia(
      header: _headerFor(page, feed, page: true),
      child: _memo(
        page,
        switch (page) {
          ShellSection.activity => (loggedIn, activityTab, active),
          ShellSection.browse => browseTab,
          _ => null,
        },
        () => switch (page) {
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

          // Two aspects only: Home stays mounted under every page pushed
          // over it, and the whole screen's metrics change on each frame
          // of a keyboard sliding in there (a channel's chat).
          final chrome = ShellMetrics.chromeFor(
            MediaQuery.sizeOf(context),
            MediaQuery.paddingOf(context),
            header,
          );
          if (!_covered) _publishChrome(chrome);

          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: _systemBars(context, header),
            child: PopScope(
              canPop: _homeStore.canLeave,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop) _homeStore.handleBack();
              },
              child: _ScreenMedia(
                builder: (context, media, body) => Scaffold(
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
                    child: body,
                  ),
                ),
                body: OnsetShell(
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
                        _page(context, section, page, feed),
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
      systemNavigationBarColor: OnsetTokens.backgroundDark,
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
    LaunchIntro.running.removeListener(_onIntro);
    _disposeTokenNotice();
    _lifecycle.dispose();
    _miniPlayer.setShellChrome(null);
    _whispers?.cancel();
    _disposeAccount();
    _search?.dispose();
    _homeStore.dispose();
    _liveFeed?.dispose();
    super.dispose();
  }
}

/// Builds Home's [Scaffold] with the screen's own [MediaQueryData] and the
/// shell as its [body].
///
/// Only this widget depends on the whole of it: Home stays mounted under
/// every page pushed over it, and a keyboard sliding in there (a channel's
/// chat) changes the screen's insets on every frame. The shell, built once
/// by Home and passed in as [body], is then left alone.
class _ScreenMedia extends StatelessWidget {
  const _ScreenMedia({required this.builder, required this.body});

  final Widget Function(BuildContext context, MediaQueryData media, Widget body)
  builder;
  final Widget body;

  @override
  Widget build(BuildContext context) =>
      builder(context, MediaQuery.of(context), body);
}

/// A shell page's metrics under [header] ([ShellMetrics.page]), over the
/// page [child].
///
/// The page is built (and kept) apart from them: when the screen's metrics
/// change, this widget alone is rebuilt, and the page only where it reads
/// what changed.
class _ShellPageMedia extends StatelessWidget {
  const _ShellPageMedia({required this.header, required this.child});

  final ShellHeader header;
  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: ShellMetrics.page(MediaQuery.of(context), header),
    child: child,
  );
}
