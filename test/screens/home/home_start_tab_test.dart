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
  test('tabs sit where the bar puts them', () {
    expect(HomeTab.following.indexWhen(loggedIn: true), 0);
    expect(HomeTab.top.indexWhen(loggedIn: true), 1);
    expect(HomeTab.search.indexWhen(loggedIn: true), 2);
    // Logged out: Top, Search.
    expect(HomeTab.following.indexWhen(loggedIn: false), 0);
    expect(HomeTab.top.indexWhen(loggedIn: false), 0);
    expect(HomeTab.search.indexWhen(loggedIn: false), 1);
  });

  test('the app opens on the chosen tab, and goes back to it on login', () {
    final auth = FakeAuthStore(true);
    final store = HomeStore(authStore: auth, startTab: HomeTab.search);
    expect(store.selectedIndex, 2);

    store.handleTap(0);
    auth.setLoggedIn(false);
    expect(store.selectedIndex, 1);

    auth.setLoggedIn(true);
    expect(store.selectedIndex, 2);
    store.dispose();
  });

  test('Following by default', () {
    final store = HomeStore(authStore: FakeAuthStore(true));
    expect(store.selectedIndex, 0);
    store.dispose();
  });

  test('the setting is saved, read back and reset', () {
    expect(SettingsStore.fromJson({}).startTab, HomeTab.following);
    final store = SettingsStore.fromJson({})..startTab = HomeTab.top;
    expect(SettingsStore.fromJson(store.toJson()).startTab, HomeTab.top);
    expect(
      SettingsStore.fromJson({'startTab': 'nowhere'}).startTab,
      HomeTab.following,
    );
    store.resetGeneralSettings();
    expect(store.startTab, HomeTab.following);
  });
}
