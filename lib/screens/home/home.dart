import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/screens/home/home_store.dart';
import 'package:frosty/screens/home/search/search.dart';
import 'package:frosty/screens/home/stream_list/stream_list_store.dart';
import 'package:frosty/screens/home/stream_list/streams_list.dart';
import 'package:frosty/screens/home/top/top.dart';
import 'package:frosty/screens/settings/settings.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/settings/widgets/release_notes.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/widgets/blurred_container.dart';
import 'package:frosty/widgets/profile_picture.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late final _authStore = context.read<AuthStore>();

  late final _homeStore = HomeStore(
    authStore: _authStore,
    startTab: context.read<SettingsStore>().startTab,
  );

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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A large screen gets a side rail instead of a bottom bar stretched
    // across the whole width.
    final useRail = context.isLargeScreen;

    return GestureDetector(
      onTap: FocusScope.of(context).unfocus,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        extendBody: true,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          titleSpacing: 16,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: theme.brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
          ),
          flexibleSpace: Observer(
            builder: (_) {
              // Only show flexible space on Following tab (when logged in)
              final isOnFollowingTab =
                  _authStore.isLoggedIn && _homeStore.selectedIndex == 0;

              if (!isOnFollowingTab) return const SizedBox.shrink();

              return BlurredContainer(
                gradientDirection: GradientDirection.up,
                child: const SizedBox.expand(),
              );
            },
          ),
          title: Observer(
            builder: (_) {
              final titles = [
                if (_authStore.isLoggedIn) 'Following',
                'Top',
                'Search',
              ];

              return Text(titles[_homeStore.selectedIndex]);
            },
          ),
          actions: [
            Observer(
              builder: (_) {
                final isLoggedIn =
                    _authStore.isLoggedIn && _authStore.user.details != null;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    tooltip: 'Settings',
                    icon: isLoggedIn
                        ? ProfilePicture(
                            userLogin: _authStore.user.details!.login,
                            radius: 16,
                          )
                        : const Icon(Icons.settings_rounded),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        settings: const RouteSettings(name: Settings.routeName),
                        builder: (context) => Settings(
                          settingsStore: context.read<SettingsStore>(),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: Observer(
          builder: (_) {
            final pages = IndexedStack(
              index: _homeStore.selectedIndex,
              children: [
                if (_authStore.isLoggedIn)
                  StreamsList(
                    listType: ListType.followed,
                    scrollController: _homeStore.followedScrollController,
                  ),
                TopSection(homeStore: _homeStore),
                Search(scrollController: _homeStore.searchScrollController),
              ],
            );
            return HomeRailLayout(
              useRail: useRail,
              destinations: _destinations(theme),
              selectedIndex: _homeStore.selectedIndex,
              onDestinationSelected: _onDestinationSelected,
              child: pages,
            );
          },
        ),
        bottomNavigationBar: useRail
            ? null
            : BlurredContainer(
                gradientDirection: GradientDirection.down,
                child: Observer(
                  builder: (_) => Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(splashFactory: NoSplash.splashFactory),
                    child: NavigationBar(
                      backgroundColor: Colors.transparent,
                      surfaceTintColor: Colors.transparent,
                      elevation: 0,
                      destinations: [
                        for (final d in _destinations(theme))
                          NavigationDestination(
                            icon: d.icon,
                            selectedIcon: d.selectedIcon,
                            label: d.label,
                            tooltip: d.label,
                          ),
                      ],
                      selectedIndex: _homeStore.selectedIndex,
                      onDestinationSelected: _onDestinationSelected,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  void _onDestinationSelected(int index) {
    if (index != _homeStore.selectedIndex) {
      HapticFeedback.selectionClick();
    }
    _homeStore.handleTap(index);
  }

  /// Following (when logged in), Top and Search, for the bottom bar on
  /// phones and the rail on large screens.
  List<HomeDestination> _destinations(ThemeData theme) {
    final offset = _authStore.isLoggedIn ? 0 : -1;
    Color colorAt(int index) => _homeStore.selectedIndex == index + offset
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurfaceVariant;
    final selected = theme.colorScheme.onSurface;
    return [
      if (_authStore.isLoggedIn)
        (
          icon: Icon(Icons.favorite_border_rounded, color: colorAt(0)),
          selectedIcon: Icon(Icons.favorite_rounded, color: selected),
          label: 'Following',
        ),
      (
        icon: Icon(Icons.arrow_upward_rounded, color: colorAt(1)),
        selectedIcon: Icon(Icons.arrow_upward_rounded, color: selected),
        label: 'Top',
      ),
      (
        icon: Icon(Icons.search_rounded, color: colorAt(2)),
        selectedIcon: Icon(Icons.search_rounded, color: selected),
        label: 'Search',
      ),
    ];
  }

  @override
  void dispose() {
    _homeStore.dispose();
    super.dispose();
  }
}

/// A home tab, shown in the bottom bar or the rail.
typedef HomeDestination = ({Widget icon, Widget selectedIcon, String label});

/// The home pages, beside a navigation rail when [useRail] (large screens).
class HomeRailLayout extends StatelessWidget {
  const HomeRailLayout({
    super.key,
    required this.useRail,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.child,
  });

  final bool useRail;
  final List<HomeDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!useRail) return child;
    return Row(
      children: [
        SafeArea(
          right: false,
          child: NavigationRail(
            backgroundColor: Colors.transparent,
            labelType: NavigationRailLabelType.all,
            groupAlignment: -1,
            destinations: [
              for (final d in destinations)
                NavigationRailDestination(
                  icon: d.icon,
                  selectedIcon: d.selectedIcon,
                  label: Text(d.label),
                ),
            ],
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
          ),
        ),
        // The rail took the start-side inset (cutout).
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeLeft: Directionality.of(context) == TextDirection.ltr,
            removeRight: Directionality.of(context) == TextDirection.rtl,
            child: child,
          ),
        ),
      ],
    );
  }
}
