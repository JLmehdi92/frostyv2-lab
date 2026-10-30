import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/screens/home/shell/onset_shell.dart';
import 'package:onset/screens/home/shell/shell_pages.dart';
import 'package:onset/screens/home/shell/shell_tabs.dart';
import 'package:onset/screens/home/stores/home_store.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/launch/launch_intro.dart';
import 'package:onset/widgets/launch/onset_mark.dart';

class FakeAuthStore extends Mock implements AuthStore {
  FakeAuthStore(bool loggedIn) : _loggedIn = Observable(loggedIn);

  final Observable<bool> _loggedIn;

  @override
  bool get isLoggedIn => _loggedIn.value;
}

const _phone = Size(390, 844);
const _landscapePhone = Size(844, 390);
const _tablet = Size(1280, 854);
const _tabletPortrait = Size(854, 1280);

/// A page that says when it goes.
class _Page extends StatefulWidget {
  final String name;
  final List<String> disposed;

  const _Page(this.name, this.disposed);

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  @override
  void dispose() {
    widget.disposed.add(widget.name);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Pads itself with the media query, like the app's lists.
    return ListView.builder(
      key: ValueKey('list-${widget.name}'),
      itemCount: 40,
      itemBuilder: (context, i) =>
          SizedBox(height: 60, child: Text('${widget.name} $i')),
    );
  }
}

class _Harness {
  final HomeStore store;
  final List<String> disposed = [];
  final List<String> haptics = [];
  int whispersOpened = 0;
  int searches = 0;
  final badge = Observable(0);
  final unread = Observable(0);
  final refused = Observable(false);
  final pip = Observable(false);
  final bool loggedIn;

  _Harness({this.loggedIn = true})
    : store = HomeStore(authStore: FakeAuthStore(loggedIn));

  ShellHeader header(ShellSection section, HomeFeed feed) => switch (section) {
    ShellSection.home => ShellHeader(
      showWhispers: loggedIn,
      tabs: [for (final f in store.feeds) f.label],
      tabIndex: store.feeds.indexOf(feed),
      onTab: (i) => store.selectFeed(store.feeds[i]),
      overVideo: feed == HomeFeed.clips,
    ),
    ShellSection.browse => const ShellHeader(
      title: 'Browse',
      showSearch: false,
      searchField: true,
    ),
    ShellSection.activity => const ShellHeader(
      title: 'Activity',
      showMark: false,
      largeTitle: true,
      showWhispers: false,
    ),
    ShellSection.profile => const ShellHeader(),
  };

  Widget app({
    ThemeMode mode = ThemeMode.dark,
    bool reduceMotion = false,
    bool intro = false,
  }) {
    final themes = OnsetThemes(colorSchemeSeed: OnsetTokens.accent);
    return MaterialApp(
      builder: intro
          ? (context, child) => LaunchIntro(
              play: true,
              slotKey: OnsetShell.markKey,
              child: child!,
            )
          : null,
      theme: themes.light,
      darkTheme: themes.dark,
      themeMode: mode,
      home: Builder(
        builder: (context) {
          final media = MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion);
          return MediaQuery(
            data: media,
            child: Scaffold(
              body: Observer(
                builder: (context) {
                  final section = store.section;
                  final feed = store.feed;
                  return OnsetShell(
                    chromeHidden: pip.value,
                    section: section,
                    onSection: store.selectSection,
                    header: header(section, feed),
                    onSearch: () => searches++,
                    activityBadge: badge.value,
                    whispers: loggedIn
                        ? ShellWhispers(
                            unread: unread.value,
                            refused: refused.value,
                            onOpen: () => whispersOpened++,
                          )
                        : null,
                    body: ShellPages<ShellSection>(
                      pages: ShellSection.values,
                      current: section,
                      builder: (context, page) => page == ShellSection.home
                          ? ShellPages<HomeFeed>(
                              pages: store.feeds,
                              current: feed,
                              motion: ShellPagesMotion.lateral,
                              keepAlive: (f) => f != HomeFeed.clips,
                              builder: (context, f) => MediaQuery(
                                data: ShellMetrics.page(
                                  media,
                                  header(ShellSection.home, f),
                                ),
                                child: _Page(f.label, disposed),
                              ),
                            )
                          : MediaQuery(
                              data: ShellMetrics.page(
                                media,
                                header(page, feed),
                              ),
                              child: _Page(page.label, disposed),
                            ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    Size size = _phone,
    ThemeMode mode = ThemeMode.dark,
    bool reduceMotion = false,
    bool intro = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    addTearDown(store.dispose);
    await tester.pumpWidget(
      app(mode: mode, reduceMotion: reduceMotion, intro: intro),
    );
    if (!intro) await tester.pumpAndSettle();
  }
}

Finder _nav(ShellSection section) =>
    find.byKey(ValueKey('nav-${section.name}'));

/// Whether [section]'s item says it is selected.
bool _selected(WidgetTester tester, ShellSection section) {
  final node = tester.getSemantics(_nav(section));
  return node.flagsCollection.isSelected == Tristate.isTrue;
}

Color? _textColor(WidgetTester tester, String text) {
  final widget = tester.widget<Text>(find.text(text).last);
  return widget.style?.color ??
      tester
          .widget<DefaultTextStyle>(
            find
                .ancestor(
                  of: find.text(text).last,
                  matching: find.byType(DefaultTextStyle),
                )
                .first,
          )
          .style
          .color;
}

void main() {
  group('phone (390 × 844)', () {
    testWidgets('header: the mark, ONSET, search, whispers, the Home tabs', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester);

      expect(tester.takeException(), isNull);
      final mark = find.byKey(OnsetShell.markKey);
      expect(mark, findsOneWidget);
      expect(tester.widget(mark), isA<OnsetMarkTile>());
      // Where the launch intro lands its tile: 16 dp in, centred in the
      // 56 dp title row.
      expect(tester.getRect(mark), const Rect.fromLTWH(16, 14, 28, 28));
      expect(find.text('ONSET'), findsOneWidget);
      expect(find.byTooltip('Search'), findsOneWidget);
      expect(find.byTooltip('Whispers'), findsOneWidget);
      for (final tab in ['Following', 'Live', 'Clips']) {
        expect(find.text(tab), findsOneWidget);
      }
      // The four sections in the floating bar.
      for (final section in ShellSection.values) {
        expect(_nav(section), findsOneWidget);
      }
      expect(_selected(tester, ShellSection.home), isTrue);
      expect(_selected(tester, ShellSection.browse), isFalse);

      // The floating bar: 14 dp from the edges, 64 high, radius 24.
      final bar = tester.getRect(find.byKey(const ValueKey('shell-nav')));
      expect(bar, const Rect.fromLTRB(14, 844 - 14 - 64, 390 - 14, 844 - 14));
      expect(tester.getSize(_nav(ShellSection.home)), const Size(72, 50));
    });

    testWidgets('the tabs switch Home with a selection haptic', (tester) async {
      final h = _Harness();
      await h.pump(tester);
      expect(find.text('Following 0'), findsOneWidget);
      final indicator = find.byKey(const ValueKey('tab-indicator'));
      final before = tester.getRect(indicator);

      await tester.tap(find.text('Live'));
      await tester.pumpAndSettle();
      expect(h.store.feed, HomeFeed.live);
      expect(find.text('Live 0'), findsOneWidget);
      // Following is kept (its scroll, its list), off screen.
      expect(find.text('Following 0', skipOffstage: false), findsOneWidget);
      expect(find.text('Following 0'), findsNothing);
      expect(h.haptics, ['HapticFeedbackType.selectionClick']);
      // The underline slid under Live.
      final after = tester.getRect(indicator);
      expect(after.left, greaterThan(before.left));
      expect(after.left, closeTo(tester.getRect(find.text('Live')).left, 0.5));
      expect(after.height, 2.5);

      // The tab on screen again: no haptic, nothing changes.
      await tester.tap(find.text('Live'));
      await tester.pumpAndSettle();
      expect(h.haptics, hasLength(1));
    });

    testWidgets('the bar switches sections; only the active item is lime', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester);

      await tester.tap(_nav(ShellSection.browse));
      await tester.pumpAndSettle();
      expect(h.store.section, ShellSection.browse);
      expect(find.text('Browse 0'), findsOneWidget);
      expect(_selected(tester, ShellSection.browse), isTrue);
      expect(_selected(tester, ShellSection.home), isFalse);
      expect(h.haptics, ['HapticFeedbackType.selectionClick']);

      final browseItem = tester.widget<AnimatedContainer>(
        _nav(ShellSection.browse),
      );
      final homeItem = tester.widget<AnimatedContainer>(
        _nav(ShellSection.home),
      );
      expect(
        (browseItem.decoration! as BoxDecoration).color,
        OnsetTokens.accent.withValues(alpha: 0.13),
      );
      expect((homeItem.decoration! as BoxDecoration).color!.a, 0);
      expect(_textColor(tester, 'Browse'), OnsetTokens.accent);
      expect(_textColor(tester, 'Home'), OnsetTokens.textSecondaryDark);

      // Browse's header: its title, its search field, no Home tabs.
      expect(find.text('Following'), findsNothing);
      expect(
        find.text('Search channels, categories or videos'),
        findsOneWidget,
      );
      await tester.tap(find.text('Search channels, categories or videos'));
      expect(h.searches, 1);

      await tester.tap(_nav(ShellSection.activity));
      await tester.pumpAndSettle();
      expect(find.text('Activity 0'), findsOneWidget);
      // Activity's board: a title, no mark, no whispers button.
      expect(find.byKey(OnsetShell.markKey), findsNothing);
      expect(find.byTooltip('Whispers'), findsNothing);

      await tester.tap(_nav(ShellSection.profile));
      await tester.pumpAndSettle();
      expect(find.text('Profile 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the Activity count sits on its item', (tester) async {
      final h = _Harness();
      await h.pump(tester);
      expect(find.byKey(const ValueKey('activity-badge')), findsNothing);

      runInAction(() => h.badge.value = 3);
      await tester.pump();
      expect(
        find.descendant(
          of: _nav(ShellSection.activity),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Activity, 3 new'), findsOneWidget);

      runInAction(() => h.badge.value = 250);
      await tester.pump();
      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('whispers: a dot when unread, and they open', (tester) async {
      final h = _Harness();
      await h.pump(tester);
      expect(find.byKey(const ValueKey('whispers-dot')), findsNothing);

      runInAction(() => h.unread.value = 2);
      await tester.pump();
      expect(find.byKey(const ValueKey('whispers-dot')), findsOneWidget);
      expect(find.byTooltip('Whispers (2 unread)'), findsOneWidget);

      await tester.tap(find.byTooltip('Whispers (2 unread)'));
      expect(h.whispersOpened, 1);

      // Refused by Twitch: a red dot, and the tooltip says why.
      runInAction(() => h.refused.value = true);
      await tester.pump();
      expect(
        find.byTooltip('Whispers (log in again to get them)'),
        findsOneWidget,
      );
      final dot = tester.widget<Container>(
        find.byKey(const ValueKey('whispers-dot')),
      );
      expect((dot.decoration! as BoxDecoration).color, OnsetTokens.danger);
    });

    testWidgets('logged out: no whispers, Home has Live and Clips', (
      tester,
    ) async {
      final h = _Harness(loggedIn: false);
      await h.pump(tester);
      expect(find.byTooltip('Whispers'), findsNothing);
      expect(find.text('Following'), findsNothing);
      expect(find.text('Live 0'), findsOneWidget);
    });

    testWidgets('pages scroll under the chrome, and their end clears the bar', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester);
      // The first item starts under the header (56 + 44).
      expect(tester.getTopLeft(find.text('Following 0')).dy, 100);

      await tester.drag(
        find.byKey(const ValueKey('list-Following')),
        const Offset(0, -5000),
      );
      await tester.pumpAndSettle();
      final last = tester.getRect(find.text('Following 39'));
      final bar = tester.getRect(_nav(ShellSection.home));
      // Above the floating bar (bar top is 844 - 14 - 64).
      expect(last.bottom, lessThanOrEqualTo(844 - 14 - 64));
      expect(last.bottom, lessThan(bar.top));
    });

    testWidgets('Clips: tabs over a gradient, no blur over the video', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester);
      expect(find.byType(BackdropFilter), findsNWidgets(2));

      await tester.tap(find.text('Clips'));
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('ONSET'), findsNothing);
      expect(find.text('Following'), findsOneWidget);

      // The gradient takes no touches: they reach the feed under it, the
      // tabs keep theirs.
      final item = tester.getCenter(find.text('Clips 0'));
      expect(item.dy, lessThan(130));
      final path = tester.hitTestOnBinding(Offset(300, item.dy)).path;
      final list = tester.renderObject(
        find.byKey(const ValueKey('list-Clips')),
      );
      expect(path.any((entry) => entry.target == list), isTrue);
      await tester.tap(find.text('Live'));
      await tester.pumpAndSettle();
      expect(h.store.feed, HomeFeed.live);
    });

    testWidgets('a page that is not kept goes when left', (tester) async {
      final h = _Harness();
      await h.pump(tester);
      await tester.tap(find.text('Clips'));
      await tester.pumpAndSettle();
      expect(find.text('Clips 0'), findsOneWidget);

      await tester.tap(find.text('Live'));
      await tester.pumpAndSettle();
      expect(h.disposed, ['Clips']);
      expect(find.text('Clips 0', skipOffstage: false), findsNothing);
      // Kept pages stay.
      expect(find.text('Following 0', skipOffstage: false), findsOneWidget);
    });

    testWidgets('a change slides in on a spring', (tester) async {
      final h = _Harness();
      await h.pump(tester);
      await tester.tap(find.text('Live'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final opacity = tester.widget<Opacity>(
        find
            .ancestor(of: find.text('Live 0'), matching: find.byType(Opacity))
            .first,
      );
      expect(opacity.opacity, inExclusiveRange(0, 1));
      final travels = tester
          .widgetList<Transform>(
            find.ancestor(
              of: find.text('Live 0'),
              matching: find.byType(Transform),
            ),
          )
          .map((t) => t.transform.getTranslation().x)
          .toList();
      expect(travels.any((x) => x > 0), isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets('reduce motion: a short cross-fade, nothing travels', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester, reduceMotion: true);
      await tester.tap(find.text('Live'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final opacity = tester.widget<Opacity>(
        find
            .ancestor(of: find.text('Live 0'), matching: find.byType(Opacity))
            .first,
      );
      expect(opacity.opacity, inExclusiveRange(0, 1));
      for (final transform in tester.widgetList<Transform>(
        find.ancestor(
          of: find.text('Live 0'),
          matching: find.byType(Transform),
        ),
      )) {
        expect(transform.transform.getTranslation().x, 0);
        expect(transform.transform.getTranslation().y, 0);
      }
      // Done within the short fade.
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester
            .widget<Opacity>(
              find
                  .ancestor(
                    of: find.text('Live 0'),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity,
        1,
      );
      // The underline jumps rather than slides.
      final tabs = tester.widget<AnimatedPositioned>(
        find.byKey(const ValueKey('tab-indicator')),
      );
      expect(tabs.duration, Duration.zero);
    });

    testWidgets('the light theme: its own colours, dark lime for active', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester, mode: ThemeMode.light);
      expect(tester.takeException(), isNull);
      // The light theme's live colour (lime is unreadable on white).
      const live = Color(0xFF6B9E00);
      expect(_textColor(tester, 'Home'), live);
      expect(_textColor(tester, 'Browse'), const Color(0xFF6B6B6B));
      final home = tester.widget<AnimatedContainer>(_nav(ShellSection.home));
      expect(
        (home.decoration! as BoxDecoration).color,
        live.withValues(alpha: 0.13),
      );
      // The glass: the light ground at 78 %, a white bar at 86 %.
      final header = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(BackdropFilter).first,
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(
        (header.decoration as BoxDecoration).color,
        OnsetTokens.backgroundLight.withValues(alpha: 0.78),
      );
      final bar = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(BackdropFilter).last,
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect((bar.decoration as BoxDecoration).color, const Color(0xDBFFFFFF));
      // Tabs: dark active, grey idle; the underline in the light live.
      expect(
        _textColor(tester, 'Following'),
        isNot(OnsetTokens.textPrimaryDark),
      );
      expect(_textColor(tester, 'Live'), const Color(0xFF6B6B6B));
      final line = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byKey(const ValueKey('tab-indicator')),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect((line.decoration as BoxDecoration).color, live);
    });

    testWidgets('the light tablet bar: a dark pill item, dark lime badge', (
      tester,
    ) async {
      final h = _Harness();
      await h.pump(tester, size: _tablet, mode: ThemeMode.light);
      runInAction(() => h.badge.value = 2);
      await tester.pump();
      final home = tester.widget<AnimatedContainer>(_nav(ShellSection.home));
      expect(
        (home.decoration! as BoxDecoration).color,
        OnsetTokens.backgroundDark,
      );
      expect(_textColor(tester, 'Home'), OnsetTokens.textPrimaryDark);
      final badge = tester.widget<Container>(
        find.byKey(const ValueKey('activity-badge')),
      );
      expect(
        (badge.decoration! as BoxDecoration).color,
        const Color(0xFF6B9E00),
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('landscape phone: no overflow', (tester) async {
    final h = _Harness();
    await h.pump(tester, size: _landscapePhone);
    expect(tester.takeException(), isNull);
    await tester.tap(_nav(ShellSection.browse));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // The bar keeps its board width instead of stretching.
    final bar = tester.getRect(find.byKey(const ValueKey('shell-nav')));
    expect(bar.width, ShellMetrics.navMaxWidth);
    expect(bar.center.dx, 844 / 2);
  });

  for (final size in [_tablet, _tabletPortrait]) {
    group('tablet (${size.width.toInt()} × ${size.height.toInt()})', () {
      testWidgets('top bar: mark, pill, search, whispers, avatar', (
        tester,
      ) async {
        final h = _Harness();
        await h.pump(tester, size: size);
        expect(tester.takeException(), isNull);

        final mark = find.byKey(OnsetShell.markKey);
        expect(tester.getRect(mark), const Rect.fromLTWH(28, 21, 30, 30));
        // The pill holds Home, Browse, Activity; Profile is the avatar.
        expect(find.text('Home'), findsOneWidget);
        expect(find.text('Browse'), findsOneWidget);
        expect(find.text('Activity'), findsOneWidget);
        expect(find.text('Profile'), findsNothing);
        expect(find.byTooltip('Profile'), findsOneWidget);
        // The field, or a round button when the bar is squeezed.
        expect(find.bySemanticsLabel('Search'), findsOneWidget);
        expect(find.byTooltip('Whispers'), findsOneWidget);
        // The pill is centred.
        final pill = tester.getRect(
          find
              .ancestor(
                of: _nav(ShellSection.home),
                matching: find.byType(Container),
              )
              .first,
        );
        expect(pill.center.dx, closeTo(size.width / 2, 40));
        // The active pill item: light fill, dark text.
        final home = tester.widget<AnimatedContainer>(_nav(ShellSection.home));
        expect(
          (home.decoration! as BoxDecoration).color,
          OnsetTokens.textPrimaryDark,
        );
        expect(_textColor(tester, 'Home'), OnsetTokens.backgroundDark);

        // Pages sit under the bar and the tabs (72 + 46).
        expect(tester.getTopLeft(find.text('Following 0')).dy, 118);
        // No floating bottom bar on a tablet.
        expect(find.byType(BackdropFilter), findsNothing);
      });

      testWidgets('the pill, the avatar and the tabs switch', (tester) async {
        final h = _Harness();
        await h.pump(tester, size: size);

        await tester.tap(find.text('Live'));
        await tester.pumpAndSettle();
        expect(h.store.feed, HomeFeed.live);

        await tester.tap(find.text('Browse'));
        await tester.pumpAndSettle();
        expect(h.store.section, ShellSection.browse);
        expect(find.text('Browse 0'), findsOneWidget);
        expect(find.byType(ShellTabs), findsNothing);

        await tester.tap(find.byTooltip('Profile'));
        await tester.pumpAndSettle();
        expect(h.store.section, ShellSection.profile);
        expect(_selected(tester, ShellSection.profile), isTrue);

        runInAction(() => h.badge.value = 3);
        await tester.pump();
        expect(find.bySemanticsLabel('Activity, 3 new'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Search'));
        expect(h.searches, 1);
        expect(tester.takeException(), isNull);
      });
    });
  }

  for (final size in [_phone, _tablet]) {
    testWidgets('the launch intro lands its tile on the header mark '
        '(${size.width.toInt()} wide)', (tester) async {
      final h = _Harness();
      await h.pump(tester, size: size, intro: true);
      await tester.pump();
      await tester.pump(LaunchIntro.duration * 0.79);
      final tile = tester.getRect(find.byKey(LaunchIntro.tileKey));
      final mark = tester.getRect(find.byKey(OnsetShell.markKey));
      expect(tile.left, closeTo(mark.left, 0.5));
      expect(tile.top, closeTo(mark.top, 0.5));
      expect(tile.width, closeTo(mark.width, 0.5));
      await tester.pumpAndSettle();
      expect(find.byKey(LaunchIntro.overlayKey), findsNothing);
    });
  }

  testWidgets('crossing the tablet size keeps every page and its scroll', (
    tester,
  ) async {
    final h = _Harness();
    await h.pump(tester, size: _tablet);
    await tester.tap(find.text('Live'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Following'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('list-Following')),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    double offset() => tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byKey(const ValueKey('list-Following')),
            matching: find.byType(Scrollable),
          ),
        )
        .position
        .pixels;
    final before = offset();
    expect(before, greaterThan(0));

    // A fold, a split screen, picture-in-picture: the window turns phone.
    tester.view.physicalSize = _phone;
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('shell-nav')), findsOneWidget);
    expect(h.disposed, isEmpty);
    expect(offset(), before);

    tester.view.physicalSize = _tablet;
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('shell-nav')), findsNothing);
    expect(h.disposed, isEmpty);
    expect(offset(), before);
  });

  for (final size in [_phone, _tablet]) {
    testWidgets('picture-in-picture: the page alone, kept '
        '(${size.width.toInt()} wide)', (tester) async {
      final h = _Harness();
      await h.pump(tester, size: size);
      runInAction(() => h.pip.value = true);
      await tester.pump();
      expect(find.byKey(OnsetShell.markKey), findsNothing);
      expect(find.byType(ShellTabs), findsNothing);
      expect(find.byKey(const ValueKey('shell-nav')), findsNothing);
      expect(find.byTooltip('Profile'), findsNothing);
      expect(tester.getRect(find.byKey(const ValueKey('shell-body'))).top, 0);
      expect(h.disposed, isEmpty);

      runInAction(() => h.pip.value = false);
      await tester.pump();
      expect(find.byKey(OnsetShell.markKey), findsOneWidget);
      expect(h.disposed, isEmpty);
    });
  }

  group('ShellMetrics', () {
    test('the phone chrome: header from the top, the bar from the bottom', () {
      const media = MediaQueryData(
        size: _phone,
        padding: EdgeInsets.only(top: 24, bottom: 16),
      );
      expect(
        ShellMetrics.chrome(media, const ShellHeader(tabs: ['A', 'B'])),
        const EdgeInsets.only(top: 24 + 100, bottom: 22 + 64),
      );
      expect(
        ShellMetrics.chrome(media, const ShellHeader()),
        const EdgeInsets.only(top: 24 + 56, bottom: 22 + 64),
      );
      expect(
        ShellMetrics.chrome(media, const ShellHeader(searchField: true)).top,
        24 + 108,
      );
      final page = ShellMetrics.page(media, const ShellHeader(tabs: ['A']));
      expect(page.padding.top, 124);
      expect(page.padding.bottom, 22 + 64 + ShellMetrics.navGap);
    });

    test('the tablet chrome: the top bar only', () {
      const media = MediaQueryData(
        size: _tablet,
        padding: EdgeInsets.only(top: 24, bottom: 16),
      );
      expect(
        ShellMetrics.chrome(media, const ShellHeader(tabs: ['A'])),
        const EdgeInsets.only(top: 24 + 72 + 46, bottom: 16),
      );
      final page = ShellMetrics.page(media, const ShellHeader(tabs: ['A']));
      expect(page.padding.top, 0);
      expect(page.padding.bottom, 16);
    });
  });
}
