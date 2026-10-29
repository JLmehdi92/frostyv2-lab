import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/home/home_store.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:mobx/mobx.dart';
import 'package:mocktail/mocktail.dart';

class FakeAuthStore extends Mock implements AuthStore {
  FakeAuthStore(bool loggedIn) : _loggedIn = Observable(loggedIn);

  final Observable<bool> _loggedIn;

  @override
  bool get isLoggedIn => _loggedIn.value;

  void setLoggedIn(bool value) => runInAction(() => _loggedIn.value = value);
}

void main() {
  group('Open the app on', () {
    test('each choice opens its section and Home tab', () {
      expect(startPlace(HomeTab.following, loggedIn: true), (
        section: ShellSection.home,
        feed: HomeFeed.following,
      ));
      expect(startPlace(HomeTab.live, loggedIn: true), (
        section: ShellSection.home,
        feed: HomeFeed.live,
      ));
      expect(startPlace(HomeTab.clips, loggedIn: true), (
        section: ShellSection.home,
        feed: HomeFeed.clips,
      ));
      expect(
        startPlace(HomeTab.browse, loggedIn: true).section,
        ShellSection.browse,
      );
      // Logged out there is no Following: Live instead.
      expect(startPlace(HomeTab.following, loggedIn: false), (
        section: ShellSection.home,
        feed: HomeFeed.live,
      ));
    });

    test('the app opens on the chosen tab', () {
      final store = HomeStore(
        authStore: FakeAuthStore(true),
        startTab: HomeTab.browse,
      );
      expect(store.section, ShellSection.browse);
      expect(store.feed, HomeFeed.following);
      store.dispose();
    });

    test('logging in or out drops the tabs that need an account, never the '
        'section on screen', () {
      final auth = FakeAuthStore(true);
      final store = HomeStore(authStore: auth);
      store
        ..selectFeed(HomeFeed.clips)
        ..selectActivityTab(ActivityTab.whispers)
        ..selectSection(ShellSection.profile);

      auth.setLoggedIn(false);
      // Logging out from Profile keeps Profile; Following and Whispers go.
      expect(store.section, ShellSection.profile);
      expect(store.feed, HomeFeed.live);
      expect(store.activityTab, ActivityTab.notifications);

      // Logging in away from Home: Home opens on its start tab, as at
      // launch.
      auth.setLoggedIn(true);
      expect(store.section, ShellSection.profile);
      expect(store.feed, HomeFeed.following);
      expect(store.activityTab, ActivityTab.notifications);
      store.dispose();
    });

    test('a session restored behind the viewer (an offline launch back '
        'online) leaves Live and Clips where they are', () {
      final auth = FakeAuthStore(false);
      final store = HomeStore(authStore: auth)..selectFeed(HomeFeed.clips);
      auth.setLoggedIn(true);
      expect(store.section, ShellSection.home);
      expect(store.feed, HomeFeed.clips);

      store.selectFeed(HomeFeed.live);
      auth
        ..setLoggedIn(false)
        ..setLoggedIn(true);
      expect(store.feed, HomeFeed.live);
      store.dispose();
    });

    test('leaving Home on Clips stops them: back on Home, the start tab', () {
      final store = HomeStore(authStore: FakeAuthStore(true));
      store
        ..selectFeed(HomeFeed.clips)
        ..selectSection(ShellSection.browse);
      expect(store.feed, HomeFeed.following);
      store.selectSection(ShellSection.home);
      expect(store.feed, HomeFeed.following);
      store.dispose();

      // Opening on Clips: the rest tab is the first one.
      final clips = HomeStore(
        authStore: FakeAuthStore(false),
        startTab: HomeTab.clips,
      );
      expect(clips.feed, HomeFeed.clips);
      clips.selectSection(ShellSection.activity);
      expect(clips.feed, HomeFeed.live);
      clips.dispose();
    });

    test('opened on Browse: Back leaves from Browse, and leads there', () {
      final store = HomeStore(
        authStore: FakeAuthStore(true),
        startTab: HomeTab.browse,
      );
      expect(store.canLeave, isTrue);
      expect(store.handleBack(), isFalse);
      expect(store.section, ShellSection.browse);

      // From Home's clips: back to Browse, and the clips stop.
      store
        ..selectSection(ShellSection.home)
        ..selectFeed(HomeFeed.clips);
      expect(store.canLeave, isFalse);
      expect(store.handleBack(), isTrue);
      expect(store.section, ShellSection.browse);
      expect(store.feed, HomeFeed.following);
      expect(store.canLeave, isTrue);

      // From Activity too.
      store.selectSection(ShellSection.activity);
      expect(store.handleBack(), isTrue);
      expect(store.section, ShellSection.browse);
      store.dispose();
    });

    test('opened on Home: Back still leads to Home, then to its tab', () {
      final store = HomeStore(authStore: FakeAuthStore(true))
        ..selectSection(ShellSection.browse);
      expect(store.canLeave, isFalse);
      expect(store.handleBack(), isTrue);
      expect(store.section, ShellSection.home);
      expect(store.canLeave, isTrue);
      store.selectFeed(HomeFeed.live);
      expect(store.canLeave, isFalse);
      expect(store.handleBack(), isTrue);
      expect(store.feed, HomeFeed.following);
      expect(store.canLeave, isTrue);
      store.dispose();
    });

    test('the choices of the setting are the new places', () {
      expect(
        [for (final tab in HomeTab.values) tab.label],
        ['Following', 'Live', 'Clips', 'Browse'],
      );
    });

    test('Following by default', () {
      final store = HomeStore(authStore: FakeAuthStore(true));
      expect(store.section, ShellSection.home);
      expect(store.feed, HomeFeed.following);
      store.dispose();
    });

    test('the setting is saved, read back and reset', () {
      expect(SettingsStore.fromJson({}).startTab, HomeTab.following);
      final store = SettingsStore.fromJson({})..startTab = HomeTab.clips;
      expect(SettingsStore.fromJson(store.toJson()).startTab, HomeTab.clips);
      expect(
        SettingsStore.fromJson({'startTab': 'nowhere'}).startTab,
        HomeTab.following,
      );
      store.resetGeneralSettings();
      expect(store.startTab, HomeTab.following);
    });

    test('values saved before the shell move to their new places', () {
      // Top (top streams + categories) is Home's Live tab now, Search is
      // in Browse.
      expect(
        SettingsStore.fromJson({'startTab': 'top'}).startTab,
        HomeTab.live,
      );
      expect(
        SettingsStore.fromJson({'startTab': 'search'}).startTab,
        HomeTab.browse,
      );
      expect(
        SettingsStore.fromJson({'startTab': 'following'}).startTab,
        HomeTab.following,
      );
      // Saved again under the new name.
      final migrated = SettingsStore.fromJson({'startTab': 'top'});
      expect(migrated.toJson()['startTab'], 'live');
    });
  });

  group('tabs', () {
    test('logged out: Live and Clips only, no Whispers in Activity', () {
      final store = HomeStore(authStore: FakeAuthStore(false));
      expect(store.feeds, [HomeFeed.live, HomeFeed.clips]);
      expect(store.activityTabs, [ActivityTab.notifications]);
      expect(store.selectFeed(HomeFeed.following), isFalse);
      expect(store.feed, HomeFeed.live);
      expect(store.selectActivityTab(ActivityTab.whispers), isFalse);
      store.dispose();
    });

    test('selecting says whether anything changed', () {
      final store = HomeStore(authStore: FakeAuthStore(true));
      expect(store.selectSection(ShellSection.browse), isTrue);
      expect(store.selectSection(ShellSection.browse), isFalse);
      expect(store.selectFeed(HomeFeed.clips), isTrue);
      expect(store.selectFeed(HomeFeed.clips), isFalse);
      expect(store.selectActivityTab(ActivityTab.whispers), isTrue);
      expect(store.activityTab, ActivityTab.whispers);
      store.dispose();
    });

    testWidgets('a second tap scrolls the list on screen to the top', (
      tester,
    ) async {
      final store = HomeStore(authStore: FakeAuthStore(true));
      addTearDown(store.dispose);
      Widget list(ScrollController controller) => ListView.builder(
        controller: controller,
        itemCount: 100,
        itemBuilder: (_, i) => SizedBox(height: 50, child: Text('$i')),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Row(
            children: [
              Expanded(child: list(store.followedScrollController)),
              Expanded(child: list(store.liveScrollController)),
              Expanded(child: list(store.categoriesScrollController)),
            ],
          ),
        ),
      );
      store.followedScrollController.jumpTo(1000);
      store.liveScrollController.jumpTo(1000);
      store.categoriesScrollController.jumpTo(1000);

      store.selectSection(ShellSection.home);
      await tester.pumpAndSettle();
      expect(store.followedScrollController.offset, 0);
      expect(store.liveScrollController.offset, 1000);

      store.selectFeed(HomeFeed.live);
      store.selectFeed(HomeFeed.live);
      await tester.pumpAndSettle();
      expect(store.liveScrollController.offset, 0);

      store.selectSection(ShellSection.browse);
      await tester.pumpAndSettle();
      expect(store.categoriesScrollController.offset, 1000);
      store.selectSection(ShellSection.browse);
      await tester.pumpAndSettle();
      expect(store.categoriesScrollController.offset, 0);
    });
  });

  group("Android's back", () {
    test('another section goes back to Home, then the app closes', () {
      final store = HomeStore(authStore: FakeAuthStore(true));
      store.selectSection(ShellSection.profile);
      expect(store.handleBack(), isTrue);
      expect(store.section, ShellSection.home);
      expect(store.handleBack(), isFalse);
      store.dispose();
    });

    test('another Home tab goes back to the start one first', () {
      final store = HomeStore(authStore: FakeAuthStore(true));
      store.selectFeed(HomeFeed.clips);
      expect(store.handleBack(), isTrue);
      expect(store.feed, HomeFeed.following);
      expect(store.handleBack(), isFalse);
      store.dispose();
    });

    test('opening on Clips, back stops them before leaving', () {
      final store = HomeStore(
        authStore: FakeAuthStore(true),
        startTab: HomeTab.clips,
      );
      expect(store.canLeave, isFalse);
      expect(store.handleBack(), isTrue);
      expect(store.feed, HomeFeed.following);
      expect(store.canLeave, isTrue);
      store.dispose();
    });

    test('opening on Live, Live is where back ends', () {
      final store = HomeStore(
        authStore: FakeAuthStore(true),
        startTab: HomeTab.live,
      );
      store.selectFeed(HomeFeed.following);
      expect(store.handleBack(), isTrue);
      expect(store.feed, HomeFeed.live);
      expect(store.handleBack(), isFalse);
      store.dispose();
    });
  });

  group('Browse tabs', () {
    testWidgets('a tab is kept across sections; a second tap goes back up', (
      tester,
    ) async {
      final store = HomeStore(authStore: FakeAuthStore(true));
      addTearDown(store.dispose);
      expect(store.browseTab, BrowseTab.categories);
      expect(store.selectBrowseTab(BrowseTab.live), isTrue);
      store
        ..selectSection(ShellSection.browse)
        ..selectSection(ShellSection.home)
        ..selectSection(ShellSection.browse);
      expect(store.browseTab, BrowseTab.live);

      // The live channels scrolled down: tapping their tab, or Browse,
      // brings them back to the top; the categories stay where they were.
      await tester.pumpWidget(
        MaterialApp(
          home: Row(
            children: [
              for (final controller in [
                store.categoriesScrollController,
                store.browseLiveScrollController,
              ])
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemExtent: 100,
                    itemCount: 100,
                    itemBuilder: (context, index) => Text('$index'),
                  ),
                ),
            ],
          ),
        ),
      );
      store.categoriesScrollController.jumpTo(500);
      store.browseLiveScrollController.jumpTo(500);
      expect(store.selectBrowseTab(BrowseTab.live), isFalse);
      await tester.pumpAndSettle();
      expect(store.browseLiveScrollController.offset, 0);
      expect(store.categoriesScrollController.offset, 500);

      store.browseLiveScrollController.jumpTo(500);
      expect(store.selectSection(ShellSection.browse), isFalse);
      await tester.pumpAndSettle();
      expect(store.browseLiveScrollController.offset, 0);
      expect(store.categoriesScrollController.offset, 500);
    });
  });
}
