import 'package:flutter/widgets.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/widgets/motion/motion.dart';

part 'home_store.g.dart';

/// The sections of the navigation shell: the bottom bar on a phone, the
/// pill in the tablet's top bar (Profile is the avatar there). Their names
/// are in lib/l10n/enum_labels.dart, like those of the tabs below.
enum ShellSection { home, browse, activity, profile }

/// Home's top tabs.
enum HomeFeed { following, live, clips }

/// Browse's tabs.
enum BrowseTab { categories, live }

/// Activity's tabs (Whispers only when logged in).
enum ActivityTab { notifications, whispers }

enum ShellPlace { browse, following, activity }

/// Where [tab] opens the shell: its section and, for Home, its top tab.
/// Logged out there is no Following, so it opens on Live.
({ShellSection section, HomeFeed feed}) startPlace(
  HomeTab tab, {
  required bool loggedIn,
}) => switch (tab) {
  HomeTab.following => (
    section: ShellSection.home,
    feed: loggedIn ? HomeFeed.following : HomeFeed.live,
  ),
  HomeTab.live => (section: ShellSection.home, feed: HomeFeed.live),
  HomeTab.clips => (section: ShellSection.home, feed: HomeFeed.clips),
  HomeTab.browse => (
    section: ShellSection.browse,
    feed: loggedIn ? HomeFeed.following : HomeFeed.live,
  ),
};

/// The navigation shell's state: the section and Home tab on screen,
/// scroll to top on a second tap, and where Android's back goes.
class HomeStore = HomeStoreBase with _$HomeStore;

abstract class HomeStoreBase with Store {
  final AuthStore authStore;

  /// The tab shown at launch and after logging in or out.
  final HomeTab startTab;

  /// Following's list, scrolled to the top by a second tap.
  final followedScrollController = ScrollController();

  /// Live's feed (the top streams, a page each): a second tap goes back to
  /// the first.
  final liveScrollController = PageController();

  /// Browse's categories.
  final categoriesScrollController = ScrollController();

  /// Browse's live channels (the top streams).
  final browseLiveScrollController = ScrollController();

  /// The section on screen.
  @readonly
  var _section = ShellSection.home;

  /// Home's top tab.
  @readonly
  var _feed = HomeFeed.following;

  /// Activity's tab.
  @readonly
  var _activityTab = ActivityTab.notifications;

  /// Browse's tab.
  @readonly
  var _browseTab = BrowseTab.categories;

  /// Home's tabs: no Following when logged out.
  @computed
  List<HomeFeed> get feeds => [
    if (authStore.isLoggedIn) HomeFeed.following,
    HomeFeed.live,
    HomeFeed.clips,
  ];

  /// Activity's tabs: Whispers need an account.
  @computed
  List<ActivityTab> get activityTabs => [
    ActivityTab.notifications,
    if (authStore.isLoggedIn) ActivityTab.whispers,
  ];

  late final ReactionDisposer _disposeReaction;

  HomeStoreBase({required this.authStore, this.startTab = HomeTab.following}) {
    final place = startPlace(startTab, loggedIn: authStore.isLoggedIn);
    _section = place.section;
    _feed = place.feed;
    // Following and Whispers come and go with the account: a tab that is
    // gone gives way (Home to its start tab, Activity to Notifications).
    // Logging in while away from Home (Profile, a login page) opens Home
    // on its start tab, as a launch would; while Home is on screen (a
    // session restored behind the viewer, an offline launch back online)
    // Live and the clips stay where they are. The section on screen stays
    // (logging out from Profile keeps Profile).
    _disposeReaction = reaction(
      (_) => authStore.isLoggedIn,
      (bool loggedIn) => _resetTabs(),
    );
  }

  @action
  void _resetTabs() {
    if (!feeds.contains(_feed) ||
        (authStore.isLoggedIn && _section != ShellSection.home)) {
      _feed = _restFeed;
    }
    if (!activityTabs.contains(_activityTab)) {
      _activityTab = ActivityTab.notifications;
    }
  }

  /// Home's tab when it is not the clips feed: the clips play, so they only
  /// start when chosen, never by coming back to Home.
  HomeFeed get _restFeed {
    final home = _homeFeed;
    return home == HomeFeed.clips ? feeds.first : home;
  }

  /// Home's start tab.
  HomeFeed get _homeFeed =>
      startPlace(startTab, loggedIn: authStore.isLoggedIn).feed;

  /// The section the app opens on (Browse when "Open the app on" says so).
  ShellSection get _startSection =>
      startPlace(startTab, loggedIn: authStore.isLoggedIn).section;

  /// Opens [section]; tapping the one on screen scrolls it to the top.
  /// Returns whether the section changed.
  @action
  bool selectSection(ShellSection section) {
    if (section != _section) {
      // Leaving the clips stops them; coming back must not start them
      // again behind the viewer's back (nor close their mini player).
      if (_section == ShellSection.home && _feed == HomeFeed.clips) {
        _feed = _restFeed;
      }
      _section = section;
      return true;
    }
    switch (section) {
      case ShellSection.home:
        _scrollToTop(_controllerOf(_feed));
      case ShellSection.browse:
        _scrollToTop(_browseController(_browseTab));
      case ShellSection.activity || ShellSection.profile:
        break;
    }
    return false;
  }

  /// Opens Home's [feed]; tapping the one on screen scrolls it to the top.
  /// Returns whether the tab changed.
  @action
  bool selectFeed(HomeFeed feed) {
    if (!feeds.contains(feed)) return false;
    if (feed != _feed) {
      _feed = feed;
      return true;
    }
    _scrollToTop(_controllerOf(feed));
    return false;
  }

  /// Opens Browse's [tab]; tapping the one on screen scrolls it to the top.
  /// Returns whether the tab changed.
  @action
  bool selectBrowseTab(BrowseTab tab) {
    if (tab != _browseTab) {
      _browseTab = tab;
      return true;
    }
    _scrollToTop(_browseController(tab));
    return false;
  }

  @action
  void openPlace(ShellPlace place) {
    final section = switch (place) {
      ShellPlace.browse => ShellSection.browse,
      ShellPlace.following => ShellSection.home,
      ShellPlace.activity => ShellSection.activity,
    };
    if (section != _section) selectSection(section);
    if (place == ShellPlace.following) {
      final feed = feeds.contains(HomeFeed.following)
          ? HomeFeed.following
          : HomeFeed.live;
      if (feed != _feed) selectFeed(feed);
    }
  }

  ScrollController _browseController(BrowseTab tab) => switch (tab) {
    BrowseTab.categories => categoriesScrollController,
    BrowseTab.live => browseLiveScrollController,
  };

  /// Opens Activity's [tab]. Returns whether it changed.
  @action
  bool selectActivityTab(ActivityTab tab) {
    if (tab == _activityTab || !activityTabs.contains(tab)) return false;
    _activityTab = tab;
    return true;
  }

  /// Whether Android's back leaves the app: on the section it opens on
  /// (Home on its start tab, or Browse).
  @computed
  bool get canLeave =>
      _section == _startSection &&
      (_section != ShellSection.home || _feed == _restFeed);

  /// Android's back: another section goes back to the one the app opens on
  /// (Home, or Browse), another Home tab to the start one (never to the
  /// clips, which play); only then does the app close (false).
  @action
  bool handleBack() {
    final start = _startSection;
    if (_section != start) {
      // Leaving the clips stops them, as when another section is chosen.
      if (_section == ShellSection.home && _feed == HomeFeed.clips) {
        _feed = _restFeed;
      }
      _section = start;
      return true;
    }
    if (_section != ShellSection.home) return false;
    final rest = _restFeed;
    if (_feed != rest) {
      _feed = rest;
      return true;
    }
    return false;
  }

  ScrollController? _controllerOf(HomeFeed feed) => switch (feed) {
    HomeFeed.following => followedScrollController,
    HomeFeed.live => liveScrollController,
    HomeFeed.clips => null,
  };

  void _scrollToTop(ScrollController? controller) {
    if (controller == null || !controller.hasClients) return;
    controller.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: OnsetMotion.standard,
    );
  }

  void dispose() {
    _disposeReaction();
    followedScrollController.dispose();
    liveScrollController.dispose();
    categoriesScrollController.dispose();
    browseLiveScrollController.dispose();
  }
}
