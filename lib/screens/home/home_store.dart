import 'package:flutter/widgets.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/widgets/motion/motion.dart';
import 'package:mobx/mobx.dart';

part 'home_store.g.dart';

/// The sections of the navigation shell: the bottom bar on a phone, the
/// pill in the tablet's top bar (Profile is the avatar there).
enum ShellSection {
  home('Home'),
  browse('Browse'),
  activity('Activity'),
  profile('Profile');

  const ShellSection(this.label);

  final String label;
}

/// Home's top tabs.
enum HomeFeed {
  following('Following'),
  live('Live'),
  clips('Clips');

  const HomeFeed(this.label);

  final String label;
}

/// Activity's tabs (Whispers only when logged in).
enum ActivityTab {
  notifications('Notifications'),
  whispers('Whispers');

  const ActivityTab(this.label);

  final String label;
}

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

  /// Live's list (the top streams).
  final liveScrollController = ScrollController();

  /// Browse's categories.
  final categoriesScrollController = ScrollController();

  /// The section on screen.
  @readonly
  var _section = ShellSection.home;

  /// Home's top tab.
  @readonly
  var _feed = HomeFeed.following;

  /// Activity's tab.
  @readonly
  var _activityTab = ActivityTab.notifications;

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
    _goToStart(authStore.isLoggedIn);
    // Back to the start tab when logging in or out: Following and Whispers
    // come and go with the account.
    _disposeReaction = reaction((_) => authStore.isLoggedIn, _goToStart);
  }

  @action
  void _goToStart(bool loggedIn) {
    final place = startPlace(startTab, loggedIn: loggedIn);
    _section = place.section;
    _feed = place.feed;
    _activityTab = ActivityTab.notifications;
  }

  /// Home's tab Android's back returns to before leaving the app.
  HomeFeed get _homeFeed =>
      startPlace(startTab, loggedIn: authStore.isLoggedIn).feed;

  /// Opens [section]; tapping the one on screen scrolls it to the top.
  /// Returns whether the section changed.
  @action
  bool selectSection(ShellSection section) {
    if (section != _section) {
      _section = section;
      return true;
    }
    switch (section) {
      case ShellSection.home:
        _scrollToTop(_controllerOf(_feed));
      case ShellSection.browse:
        _scrollToTop(categoriesScrollController);
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

  /// Opens Activity's [tab]. Returns whether it changed.
  @action
  bool selectActivityTab(ActivityTab tab) {
    if (tab == _activityTab || !activityTabs.contains(tab)) return false;
    _activityTab = tab;
    return true;
  }

  /// Whether Android's back leaves the app (Home, on its start tab).
  @computed
  bool get canLeave => _section == ShellSection.home && _feed == _homeFeed;

  /// Android's back: another section goes back to Home, another Home tab
  /// to the start one; only then does the app close (false).
  @action
  bool handleBack() {
    if (_section != ShellSection.home) {
      _section = ShellSection.home;
      return true;
    }
    final home = _homeFeed;
    if (_feed != home) {
      _feed = home;
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
      curve: FrostyMotion.standard,
    );
  }

  void dispose() {
    _disposeReaction();
    followedScrollController.dispose();
    liveScrollController.dispose();
    categoriesScrollController.dispose();
  }
}
