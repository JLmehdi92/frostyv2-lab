import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:onset/screens/home/home_store.dart';
import 'package:onset/screens/home/shell/shell_glyph.dart';
import 'package:onset/screens/home/shell/shell_tabs.dart';
import 'package:onset/screens/settings/widgets/settings_glyph.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/launch/onset_mark.dart';
import 'package:onset/widgets/motion/haptics.dart';
import 'package:onset/widgets/motion/motion.dart';
import 'package:onset/widgets/motion/press_scale.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';

/// What the header shows for the page on screen.
@immutable
class ShellHeader {
  /// The title next to the mark: the "ONSET" wordmark by default.
  final String title;

  /// Whether the signal mark leads the title (Activity's board has none).
  final bool showMark;

  /// Activity's board uses a screen title (24) instead of the wordmark (20).
  final bool largeTitle;

  /// The search button (phone); Browse has its search field instead.
  final bool showSearch;

  /// The whispers button (logged in; Activity has a Whispers tab instead).
  final bool showWhispers;

  /// Browse's search field under the title row (phone).
  final bool searchField;

  /// The tabs under the title row, and the one selected.
  final List<String> tabs;
  final int tabIndex;

  /// A count after each tab (Activity's unread), none at 0.
  final List<int>? tabBadges;
  final ValueChanged<int>? onTab;

  /// The page is a video (the clips feed, the phone's Live feed): the phone
  /// header becomes a gradient with the tabs only, and nothing is blurred
  /// over it.
  final bool overVideo;

  /// At the end of the tablet's tab row (the Live feed's category chips).
  final Widget? tabsTrailing;

  /// The phone's settings button (Profile's board Moi); none when null.
  final VoidCallback? onSettings;

  const ShellHeader({
    this.title = 'ONSET',
    this.showMark = true,
    this.largeTitle = false,
    this.showSearch = true,
    this.showWhispers = true,
    this.searchField = false,
    this.tabs = const [],
    this.tabIndex = 0,
    this.tabBadges,
    this.onTab,
    this.overVideo = false,
    this.tabsTrailing,
    this.onSettings,
  });
}

/// The whispers button's state (null when logged out).
@immutable
class ShellWhispers {
  final int unread;

  /// Twitch refused the whispers: they cannot arrive until a new login.
  final bool refused;
  final VoidCallback onOpen;

  const ShellWhispers({
    required this.unread,
    required this.refused,
    required this.onOpen,
  });

  String get tooltip => refused
      ? 'Whispers (log in again to get them)'
      : unread > 0
      ? 'Whispers ($unread unread)'
      : 'Whispers';
}

/// The shell's measures, from the boards Accueil (phone) and
/// TabletteAccueil (tablet).
abstract final class ShellMetrics {
  // Phone.
  static const titleRow = 56.0;
  static const searchRow = 52.0;
  static const tabsRow = 44.0;
  static const videoTabsRow = 56.0;
  static const navHeight = 64.0;
  static const navInset = 14.0;
  static const navMaxWidth = 520.0;
  static const navFade = 120.0;

  /// Room between the floating nav and the last item of a list.
  static const navGap = 8.0;

  // Tablet.
  static const topBar = 72.0;
  static const tabletTabsRow = 46.0;
  static const tabletGutter = OnsetSpacing.gutterTablet;

  /// How far above the screen's bottom the floating nav sits.
  static double navBottom(EdgeInsets padding) =>
      math.max(navInset, padding.bottom + 6);

  /// The height the phone header covers, under the status bar.
  static double phoneHeader(ShellHeader header) {
    if (header.overVideo) return videoTabsRow;
    return titleRow +
        (header.searchField ? searchRow : 0) +
        (header.tabs.isNotEmpty ? tabsRow : 0);
  }

  /// The height of the tablet's top bar and tab row, under the status bar.
  static double tabletHeader(ShellHeader header) =>
      topBar + (header.tabs.isNotEmpty ? tabletTabsRow : 0);

  /// What the chrome covers on screen, from the edges: the header from the
  /// top, the floating nav from the bottom (phone). The mini player stays
  /// inside.
  static EdgeInsets chrome(MediaQueryData media, ShellHeader header) {
    final padding = media.padding;
    if (isLargeScreenSize(media.size)) {
      return EdgeInsets.only(
        top: padding.top + tabletHeader(header),
        bottom: padding.bottom,
      );
    }
    return EdgeInsets.only(
      top: padding.top + phoneHeader(header),
      bottom: navBottom(padding) + navHeight,
    );
  }

  /// The [media] a page under [header] is built with: on a phone the page
  /// scrolls under the glass header and the floating nav, so its padding is
  /// theirs (lists already pad themselves with it); on a tablet the top bar
  /// sits above the page.
  static MediaQueryData page(MediaQueryData media, ShellHeader header) {
    final padding = media.padding;
    final EdgeInsets pagePadding;
    if (isLargeScreenSize(media.size)) {
      pagePadding = padding.copyWith(top: 0);
    } else {
      final cover = chrome(media, header);
      pagePadding = padding.copyWith(
        top: cover.top,
        bottom: cover.bottom + navGap,
      );
    }
    return media.copyWith(
      padding: pagePadding,
      viewPadding: media.viewPadding.copyWith(
        top: pagePadding.top,
        bottom: math.max(media.viewPadding.bottom, pagePadding.bottom),
      ),
    );
  }
}

/// The colours of the chrome, from the boards (dark) and their light
/// counterparts.
@immutable
class _ShellPalette {
  final Color ground;
  final Color headerFill;
  final Color navFill;
  final Color pillFill;
  final Color hairline;
  final Color highlight;
  final Color text;
  final Color idle;
  final Color tabIdle;
  final Color pillIdle;
  final Color pillActive;
  final Color pillActiveText;
  final Color field;
  final Color fieldText;
  final Color avatarFill;
  final Color accent;
  final Color onAccent;

  const _ShellPalette({
    required this.ground,
    required this.headerFill,
    required this.navFill,
    required this.pillFill,
    required this.hairline,
    required this.highlight,
    required this.text,
    required this.idle,
    required this.tabIdle,
    required this.pillIdle,
    required this.pillActive,
    required this.pillActiveText,
    required this.field,
    required this.fieldText,
    required this.avatarFill,
    required this.accent,
    required this.onAccent,
  });

  /// Over a video: light glyphs, the dot's ring on the dark ground.
  _ShellPalette overVideo() => _ShellPalette(
    ground: OnsetTokens.backgroundDark,
    headerFill: headerFill,
    navFill: navFill,
    pillFill: pillFill,
    hairline: hairline,
    highlight: highlight,
    text: Colors.white,
    idle: idle,
    tabIdle: tabIdle,
    pillIdle: pillIdle,
    pillActive: pillActive,
    pillActiveText: pillActiveText,
    field: field,
    fieldText: fieldText,
    avatarFill: avatarFill,
    accent: accent,
    onAccent: onAccent,
  );

  factory _ShellPalette.of(BuildContext context) {
    final theme = Theme.of(context);
    final ground = theme.scaffoldBackgroundColor;
    final accent = context.onsetColors.live;
    if (theme.brightness == Brightness.dark) {
      return _ShellPalette(
        ground: ground,
        headerFill: ground.withValues(alpha: 0.74),
        navFill: const Color(0xD1181818),
        pillFill: const Color(0xD91C1C1C),
        hairline: const Color(0x12FFFFFF),
        highlight: const Color(0x24FFFFFF),
        text: OnsetTokens.textPrimaryDark,
        idle: OnsetTokens.textSecondaryDark,
        tabIdle: OnsetTokens.textTertiaryDark,
        pillIdle: OnsetTokens.textBodyDark,
        pillActive: OnsetTokens.textPrimaryDark,
        pillActiveText: OnsetTokens.backgroundDark,
        field: OnsetTokens.surfaceDark,
        fieldText: OnsetTokens.textTertiaryDark,
        avatarFill: const Color(0xFF2A2A2A),
        accent: accent,
        onAccent: OnsetTokens.backgroundDark,
      );
    }
    final scheme = theme.colorScheme;
    return _ShellPalette(
      ground: ground,
      headerFill: ground.withValues(alpha: 0.78),
      navFill: const Color(0xDBFFFFFF),
      pillFill: const Color(0xE6FFFFFF),
      hairline: OnsetTokens.hairlineLight,
      highlight: const Color(0x14000000),
      text: scheme.onSurface,
      idle: const Color(0xFF6B6B6B),
      tabIdle: const Color(0xFF6B6B6B),
      pillIdle: const Color(0xFF4A4A4A),
      pillActive: OnsetTokens.backgroundDark,
      pillActiveText: OnsetTokens.textPrimaryDark,
      field: OnsetTokens.surfaceLight,
      fieldText: const Color(0xFF6B6B6B),
      avatarFill: const Color(0xFFE6E6E6),
      accent: accent,
      onAccent: Colors.white,
    );
  }
}

/// ONSET's navigation shell: on a phone a glass header (the mark, search,
/// whispers, the page's tabs) and a floating bottom bar (Home, Browse,
/// Activity, Profile); on a tablet a top bar with a floating pill (Home,
/// Browse, Activity), the search field, whispers and the avatar (Profile),
/// then the page's tabs.
///
/// The shell draws the chrome only; [body] is the page, built with
/// [ShellMetrics.page] so that it pads itself under the chrome. Blur is
/// only ever behind the chrome, never over a video ([ShellHeader.overVideo]).
class OnsetShell extends StatelessWidget {
  /// The header's mark, where the launch intro lands its tile.
  static final markKey = GlobalKey(debugLabel: 'onset-header-mark');

  /// Tells the shell when a page covers it or leaves (the mini player's
  /// corners follow the chrome only while the shell is on screen).
  static final routeObserver = ShellCoverObserver();

  final ShellSection section;
  final ValueChanged<ShellSection> onSection;
  final ShellHeader header;
  final Widget body;
  final VoidCallback onSearch;

  /// Logged out: null (no whispers).
  final ShellWhispers? whispers;

  /// What came in Activity since it was last opened.
  final int activityBadge;

  /// The viewer's picture, or null (logged out).
  final Widget? avatar;

  /// Nothing but [body]: the clips feed is in picture-in-picture, where the
  /// window must show the clip alone.
  final bool chromeHidden;

  const OnsetShell({
    super.key,
    required this.section,
    required this.onSection,
    required this.header,
    required this.body,
    required this.onSearch,
    this.whispers,
    this.activityBadge = 0,
    this.avatar,
    this.chromeHidden = false,
  });

  void _select(ShellSection target) {
    if (target != section) Haptics.selection();
    onSection(target);
  }

  @override
  Widget build(BuildContext context) {
    final palette = _ShellPalette.of(context);
    final large = context.isLargeScreen;
    final padding = MediaQuery.paddingOf(context);
    // One structure for both layouts: the body keeps its place (and every
    // page its state) when the window crosses the tablet size (a fold, a
    // split screen, picture-in-picture).
    final bodyTop = chromeHidden || !large
        ? 0.0
        : padding.top + ShellMetrics.tabletHeader(header);
    return ColoredBox(
      color: palette.ground,
      child: Stack(
        children: [
          Positioned(
            key: const ValueKey('shell-body'),
            top: bodyTop,
            left: 0,
            right: 0,
            bottom: 0,
            child: body,
          ),
          if (!chromeHidden)
            if (large)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildTablet(context, palette),
              )
            else
              ..._buildPhone(context, palette),
        ],
      ),
    );
  }

  List<Widget> _buildPhone(BuildContext context, _ShellPalette palette) {
    final padding = MediaQuery.paddingOf(context);
    final navBottom = ShellMetrics.navBottom(padding);
    // Over the clips, the fade is always the dark ground: a pale band would
    // wash out the clip and its white captions in the light theme.
    final fade = header.overVideo ? OnsetTokens.backgroundDark : palette.ground;
    return [
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        height: ShellMetrics.navFade + navBottom - ShellMetrics.navInset,
        child: IgnorePointer(
          child: DecoratedBox(
            key: const ValueKey('shell-nav-fade'),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [fade, fade.withValues(alpha: 0)],
                stops: const [0.3, 1],
              ),
            ),
          ),
        ),
      ),
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: _PhoneHeader(
          header: header,
          palette: palette,
          whispers: whispers,
          onSearch: onSearch,
        ),
      ),
      Positioned(
        left: ShellMetrics.navInset + padding.left,
        right: ShellMetrics.navInset + padding.right,
        bottom: navBottom,
        height: ShellMetrics.navHeight,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: ShellMetrics.navMaxWidth,
            ),
            child: SizedBox(
              width: double.infinity,
              height: ShellMetrics.navHeight,
              child: _PhoneNav(
                section: section,
                onSelect: _select,
                palette: palette,
                activityBadge: activityBadge,
                avatar: avatar,
                blur: !header.overVideo,
              ),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildTablet(BuildContext context, _ShellPalette palette) {
    final padding = MediaQuery.paddingOf(context);
    final gutter = EdgeInsets.only(
      left: ShellMetrics.tabletGutter + padding.left,
      right: ShellMetrics.tabletGutter + padding.right,
    );
    return ColoredBox(
      color: palette.ground,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: padding.top),
          SizedBox(
            height: ShellMetrics.topBar,
            child: Padding(
              padding: gutter,
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _Brand(palette: palette, tablet: true),
                    ),
                  ),
                  const SizedBox(width: OnsetSpacing.lg),
                  _PillNav(
                    section: section,
                    onSelect: _select,
                    palette: palette,
                    activityBadge: activityBadge,
                  ),
                  const SizedBox(width: OnsetSpacing.lg),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 214),
                            child: LayoutBuilder(
                              // Squeezed (portrait, large text): the field
                              // becomes a round button.
                              builder: (context, constraints) =>
                                  constraints.maxWidth < 100
                                  ? Align(
                                      alignment: Alignment.centerRight,
                                      child: _SearchField(
                                        label: 'Search',
                                        height: 40,
                                        palette: palette,
                                        onTap: onSearch,
                                        compact: true,
                                      ),
                                    )
                                  : _SearchField(
                                      label: 'Search',
                                      height: 40,
                                      palette: palette,
                                      onTap: onSearch,
                                    ),
                            ),
                          ),
                        ),
                        if (whispers case final whispers?) ...[
                          const SizedBox(width: 10),
                          _WhispersButton(
                            whispers: whispers,
                            palette: palette,
                            circle: true,
                          ),
                        ],
                        const SizedBox(width: 10),
                        _ProfileButton(
                          active: section == ShellSection.profile,
                          palette: palette,
                          avatar: avatar,
                          onTap: () => _select(ShellSection.profile),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (header.tabs.isNotEmpty)
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: palette.hairline,
                    width: OnsetTokens.hairlineWidth,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ShellTabs(
                      labels: header.tabs,
                      badges: header.tabBadges,
                      index: header.tabIndex,
                      onSelect: header.onTab ?? (_) {},
                      height: ShellMetrics.tabletTabsRow,
                      fontSize: 17,
                      gap: 28,
                      bottomPadding: 12,
                      padding: gutter,
                      activeColor: palette.text,
                      idleColor: palette.tabIdle,
                      indicatorColor: palette.accent,
                    ),
                  ),
                  if (header.tabsTrailing case final trailing?)
                    // At most half the row: the tabs keep their room.
                    Flexible(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: gutter.right,
                          bottom: 7,
                        ),
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: trailing,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Follows the navigator's stack to say whether a page covers a route:
/// any page above it, even with a sheet or a dialog in between (a sheet's
/// "Report" opens a page over the sheet). Sheets, dialogs and menus alone
/// leave the route on screen.
class ShellCoverObserver extends NavigatorObserver with ChangeNotifier {
  final _routes = <Route<dynamic>>[];

  /// The routes above [route], lowest first (none when it is not known).
  List<Route<dynamic>> above(Route<dynamic> route) {
    final index = _routes.indexOf(route);
    return index < 0 ? const [] : List.unmodifiable(_routes.skip(index + 1));
  }

  /// Whether a page sits above [route].
  bool covers(Route<dynamic> route) {
    final index = _routes.indexOf(route);
    if (index < 0) return false;
    return _routes.skip(index + 1).any((r) => r is PageRoute);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    notifyListeners();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    notifyListeners();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    notifyListeners();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (newRoute != null) {
      if (index < 0) {
        _routes.add(newRoute);
      } else {
        _routes[index] = newRoute;
      }
    } else if (index >= 0) {
      _routes.removeAt(index);
    }
    notifyListeners();
  }
}

/// The mark and the title.
class _Brand extends StatelessWidget {
  final _ShellPalette palette;
  final bool tablet;
  final String title;
  final bool showMark;
  final bool large;

  const _Brand({
    required this.palette,
    required this.tablet,
    this.title = 'ONSET',
    this.showMark = true,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = large
        ? OnsetType.screenTitle.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.03 * 24,
            color: palette.text,
          )
        : OnsetType.wordmark.copyWith(
            fontSize: tablet ? 21 : 20,
            letterSpacing: -0.035 * (tablet ? 21 : 20),
            color: palette.text,
          );
    final markSize = tablet ? 30.0 : 28.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showMark) ...[
          OnsetMarkTile(
            key: OnsetShell.markKey,
            size: markSize,
            radius: tablet ? 9 : 8,
          ),
          const SizedBox(width: 9),
        ],
        Flexible(
          child: Text(
            title,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            semanticsLabel: title,
          ),
        ),
      ],
    );
  }
}

/// The phone's glass header.
class _PhoneHeader extends StatelessWidget {
  final ShellHeader header;
  final _ShellPalette palette;
  final ShellWhispers? whispers;
  final VoidCallback onSearch;

  const _PhoneHeader({
    required this.header,
    required this.palette,
    required this.whispers,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final side = EdgeInsets.only(left: padding.left, right: padding.right);
    final tabs = header.tabs.isEmpty
        ? null
        : ShellTabs(
            labels: header.tabs,
            badges: header.tabBadges,
            index: header.tabIndex,
            onSelect: header.onTab ?? (_) {},
            height: header.overVideo
                ? ShellMetrics.videoTabsRow
                : ShellMetrics.tabsRow,
            fontSize: 16,
            gap: header.overVideo ? 24 : 26,
            bottomPadding: header.overVideo ? 10 : 11,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            activeColor: header.overVideo ? Colors.white : palette.text,
            idleColor: header.overVideo
                ? Colors.white.withValues(alpha: 0.6)
                : palette.tabIdle,
            indicatorColor: palette.accent,
          );

    if (header.overVideo) {
      // Over a video feed: a gradient, never a blur over the video. Only
      // the tabs, search and whispers take touches; the rest of the band
      // is the feed's.
      final light = palette.overVideo();
      final whispers = this.whispers;
      return Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xEB0A0A0A), Color(0x000A0A0A)],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              top: padding.top,
              left: padding.left,
              right: padding.right,
              bottom: _videoFade - ShellMetrics.videoTabsRow,
            ),
            child: SizedBox(
              height: ShellMetrics.videoTabsRow,
              child: Row(
                children: [
                  Expanded(
                    child: Align(alignment: Alignment.bottomLeft, child: tabs),
                  ),
                  if (header.showSearch)
                    _HeaderButton(
                      tooltip: 'Search',
                      onPressed: onSearch,
                      child: ShellGlyph(
                        ShellGlyphKind.search,
                        color: light.text,
                        strokeWidth: 1.8,
                      ),
                    ),
                  if (header.showWhispers && whispers != null)
                    _WhispersButton(whispers: whispers, palette: light),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final whispers = this.whispers;
    final rows = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: ShellMetrics.titleRow,
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 8),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _Brand(
                      palette: palette,
                      tablet: false,
                      title: header.title,
                      showMark: header.showMark,
                      large: header.largeTitle,
                    ),
                  ),
                ),
                if (header.showSearch)
                  _HeaderButton(
                    tooltip: 'Search',
                    onPressed: onSearch,
                    child: ShellGlyph(
                      ShellGlyphKind.search,
                      color: palette.text,
                      strokeWidth: 1.8,
                    ),
                  ),
                if (header.showWhispers && whispers != null)
                  _WhispersButton(whispers: whispers, palette: palette),
                if (header.onSettings case final onSettings?)
                  _HeaderButton(
                    tooltip: 'Settings',
                    onPressed: onSettings,
                    child: SettingsGlyph(
                      SettingsGlyphKind.general,
                      size: 21,
                      strokeWidth: 1.8,
                      color: palette.text,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (header.searchField)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _SearchField(
              label: 'Search channels, categories or videos',
              height: 44,
              palette: palette,
              onTap: onSearch,
            ),
          ),
        ?tabs,
      ],
    );

    return ClipRect(
      child: BackdropFilter(
        filter: _glass(22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.headerFill,
            border: Border(
              bottom: BorderSide(
                color: palette.hairline,
                width: OnsetTokens.hairlineWidth,
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(top: padding.top).add(side),
            child: rows,
          ),
        ),
      ),
    );
  }
}

/// How far the gradient over the clips feed reaches (board Clips).
const _videoFade = 130.0;

/// The boards' material: a blur with a little more saturation.
ui.ImageFilter _glass(double sigma) => ui.ImageFilter.compose(
  outer: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
  inner: const ColorFilter.matrix(_saturate170),
);

/// CSS `saturate(170%)` (the Filter Effects matrix with s = 1.7).
const _saturate170 = <double>[
  1.5509, -0.5005, -0.0504, 0, 0, //
  -0.1491, 1.1995, -0.0504, 0, 0, //
  -0.1491, -0.5005, 1.6496, 0, 0, //
  0, 0, 0, 1, 0, //
];

/// A 44 × 44 header button.
class _HeaderButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback onPressed;
  final Widget child;

  const _HeaderButton({
    required this.tooltip,
    required this.onPressed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(splashFactory: NoSplash.splashFactory),
      icon: child,
    );
  }
}

/// Whispers: the bubble with a signal dot when some are unread, a red one
/// when Twitch refused them.
class _WhispersButton extends StatelessWidget {
  final ShellWhispers whispers;
  final _ShellPalette palette;

  /// The tablet's round button.
  final bool circle;

  const _WhispersButton({
    required this.whispers,
    required this.palette,
    this.circle = false,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = whispers.refused ? OnsetTokens.danger : palette.accent;
    final showDot = whispers.refused || whispers.unread > 0;
    final glyph = Stack(
      clipBehavior: Clip.none,
      children: [
        ShellGlyph(
          ShellGlyphKind.whispers,
          color: palette.text,
          size: circle ? 20 : 22,
          strokeWidth: 1.8,
        ),
        if (showDot)
          Positioned(
            top: -2,
            right: -3,
            child: Container(
              key: const ValueKey('whispers-dot'),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                border: Border.all(color: palette.ground, width: 2),
              ),
            ),
          ),
      ],
    );
    if (!circle) {
      return _HeaderButton(
        tooltip: whispers.tooltip,
        onPressed: whispers.onOpen,
        child: glyph,
      );
    }
    return Tooltip(
      message: whispers.tooltip,
      child: Semantics(
        button: true,
        label: whispers.tooltip,
        excludeSemantics: true,
        child: PressScale(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: whispers.onOpen,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.field,
                shape: BoxShape.circle,
                border: Border.all(
                  color: palette.highlight,
                  width: OnsetTokens.hairlineWidth,
                ),
              ),
              child: glyph,
            ),
          ),
        ),
      ),
    );
  }
}

/// A search field that opens Search (the phone's Browse, the tablet's top
/// bar).
class _SearchField extends StatelessWidget {
  final String label;
  final double height;
  final _ShellPalette palette;
  final VoidCallback onTap;

  /// Only the glyph, in a circle.
  final bool compact;

  const _SearchField({
    required this.label,
    required this.height,
    required this.palette,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Search',
      hint: label,
      excludeSemantics: true,
      child: PressScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            height: height,
            width: compact ? height : null,
            padding: compact
                ? null
                : EdgeInsets.symmetric(horizontal: height > 40 ? 16 : 14),
            alignment: compact ? Alignment.center : null,
            decoration: BoxDecoration(
              color: palette.field,
              borderRadius: BorderRadius.circular(OnsetTokens.radiusPill),
              border: Border.all(
                color: palette.highlight,
                width: OnsetTokens.hairlineWidth,
              ),
            ),
            child: compact
                ? ShellGlyph(
                    ShellGlyphKind.search,
                    color: palette.fieldText,
                    size: 16,
                    strokeWidth: 2,
                  )
                : Row(
                    children: [
                      ShellGlyph(
                        ShellGlyphKind.search,
                        color: palette.fieldText,
                        size: height > 40 ? 18 : 16,
                        strokeWidth: 2,
                      ),
                      SizedBox(width: height > 40 ? 10 : 8),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: OnsetType.body.copyWith(
                            fontSize: height > 40 ? 15 : 14,
                            height: 1.2,
                            color: palette.fieldText,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// The phone's floating bottom bar.
class _PhoneNav extends StatelessWidget {
  final ShellSection section;
  final ValueChanged<ShellSection> onSelect;
  final _ShellPalette palette;
  final int activityBadge;
  final Widget? avatar;

  /// False over a video: the bar stays opaque-ish instead.
  final bool blur;

  const _PhoneNav({
    required this.section,
    required this.onSelect,
    required this.palette,
    required this.activityBadge,
    required this.avatar,
    required this.blur,
  });

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(OnsetTokens.radiusLarge));
    final items = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final target in ShellSection.values)
            _NavItem(
              section: target,
              active: target == section,
              palette: palette,
              badge: target == ShellSection.activity ? activityBadge : 0,
              avatar: avatar,
              onTap: () => onSelect(target),
            ),
        ],
      ),
    );
    final fill = blur
        ? palette.navFill
        : palette.navFill.withValues(alpha: 0.94);
    Widget surface = DecoratedBox(
      decoration: BoxDecoration(color: fill, borderRadius: radius),
      child: CustomPaint(
        foregroundPainter: _TopHighlight(
          color: palette.highlight,
          radius: OnsetTokens.radiusLarge,
        ),
        child: items,
      ),
    );
    if (blur) {
      surface = BackdropFilter(filter: _glass(26), child: surface);
    }
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Main',
      child: DecoratedBox(
        key: const ValueKey('shell-nav'),
        decoration: const BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Color(0x80000000),
              blurRadius: 30,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(borderRadius: radius, child: surface),
      ),
    );
  }
}

/// The boards' `inset 0 0.5px 0` highlight along the top edge.
class _TopHighlight extends CustomPainter {
  final Color color;
  final double radius;

  const _TopHighlight({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = OnsetTokens.hairlineWidth
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color, color.withValues(alpha: 0)],
        stops: const [0, 1],
      ).createShader(Rect.fromLTWH(0, 0, size.width, radius / 2));
    canvas
      ..save()
      ..clipRect(Rect.fromLTWH(0, 0, size.width, radius / 2))
      ..drawRRect(
        RRect.fromRectAndRadius(rect.deflate(0.25), Radius.circular(radius)),
        paint,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_TopHighlight old) =>
      old.color != color || old.radius != radius;
}

String _badgeText(int count) => count > 99 ? '99+' : '$count';

String _sectionLabel(ShellSection section, int badge) =>
    section == ShellSection.activity && badge > 0
    ? 'Activity, $badge new'
    : section.label;

/// One item of the phone's bar: 72 × 50, the signal tint when active.
class _NavItem extends StatelessWidget {
  final ShellSection section;
  final bool active;
  final _ShellPalette palette;
  final int badge;
  final Widget? avatar;
  final VoidCallback onTap;

  const _NavItem({
    required this.section,
    required this.active,
    required this.palette,
    required this.badge,
    required this.avatar,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? palette.accent : palette.idle;
    final duration = motionDuration(context, const Duration(milliseconds: 200));
    final Widget icon = switch (section) {
      ShellSection.home => ShellGlyph(
        ShellGlyphKind.home,
        color: color,
        filled: active,
      ),
      ShellSection.browse => ShellGlyph(
        ShellGlyphKind.browse,
        color: color,
        filled: active,
      ),
      ShellSection.activity => ShellGlyph(
        ShellGlyphKind.activity,
        color: color,
        filled: active,
      ),
      ShellSection.profile => _Avatar(
        size: 24,
        ring: color,
        palette: palette,
        child: avatar,
      ),
    };
    return Flexible(
      child: Semantics(
        button: true,
        selected: active,
        inMutuallyExclusiveGroup: true,
        label: _sectionLabel(section, badge),
        excludeSemantics: true,
        child: Tooltip(
          message: _sectionLabel(section, badge),
          excludeFromSemantics: true,
          child: PressScale(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: AnimatedContainer(
                key: ValueKey('nav-${section.name}'),
                duration: duration,
                curve: OnsetMotion.standard,
                width: 72,
                height: 50,
                decoration: BoxDecoration(
                  color: active
                      ? palette.accent.withValues(alpha: 0.13)
                      : palette.accent.withValues(alpha: 0),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        icon,
                        const SizedBox(height: 3),
                        Text(
                          section.label,
                          maxLines: 1,
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontFamily: OnsetTokens.bodyFamily,
                            fontSize: 10,
                            height: 1.2,
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    if (badge > 0)
                      Positioned(
                        top: 3,
                        right: 17,
                        child: _CountBadge(
                          count: badge,
                          palette: palette,
                          size: 16,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The signal count of Activity.
class _CountBadge extends StatelessWidget {
  final int count;
  final _ShellPalette palette;
  final double size;

  const _CountBadge({
    required this.count,
    required this.palette,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('activity-badge'),
      constraints: BoxConstraints(minWidth: size),
      height: size,
      padding: EdgeInsets.symmetric(horizontal: size > 16 ? 5 : 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.accent,
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Text(
        _badgeText(count),
        textScaler: TextScaler.noScaling,
        style: OnsetType.tabular(
          TextStyle(
            fontFamily: OnsetTokens.bodyFamily,
            fontSize: size > 16 ? 11 : 10,
            height: 1,
            fontWeight: FontWeight.w800,
            color: palette.onAccent,
          ),
        ),
      ),
    );
  }
}

/// The viewer's picture in a ring (grey, signal when Profile is open).
class _Avatar extends StatelessWidget {
  final double size;
  final Color ring;
  final _ShellPalette palette;
  final Widget? child;

  const _Avatar({
    required this.size,
    required this.ring,
    required this.palette,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: palette.avatarFill,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: ring, spreadRadius: 1.5)],
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child:
          child ??
          Icon(Icons.person_rounded, size: size * 0.7, color: palette.idle),
    );
  }
}

/// The tablet's avatar: Profile.
class _ProfileButton extends StatelessWidget {
  final bool active;
  final _ShellPalette palette;
  final Widget? avatar;
  final VoidCallback onTap;

  const _ProfileButton({
    required this.active,
    required this.palette,
    required this.avatar,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: 'Profile',
      excludeSemantics: true,
      child: Tooltip(
        message: 'Profile',
        excludeFromSemantics: true,
        child: PressScale(
          child: GestureDetector(
            key: const ValueKey('nav-profile'),
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: SizedBox.square(
              dimension: 44,
              child: Center(
                child: _Avatar(
                  size: 36,
                  ring: active ? palette.accent : palette.idle,
                  palette: palette,
                  child: avatar,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The tablet's floating pill: Home, Browse, Activity.
class _PillNav extends StatelessWidget {
  final ShellSection section;
  final ValueChanged<ShellSection> onSelect;
  final _ShellPalette palette;
  final int activityBadge;

  const _PillNav({
    required this.section,
    required this.onSelect,
    required this.palette,
    required this.activityBadge,
  });

  @override
  Widget build(BuildContext context) {
    final duration = motionDuration(context, const Duration(milliseconds: 200));
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Main',
      child: Container(
        height: 46,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: palette.pillFill,
          borderRadius: BorderRadius.circular(OnsetTokens.radiusPill),
        ),
        foregroundDecoration: _PillHighlight(palette.highlight),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 2,
          children: [
            for (final target in const [
              ShellSection.home,
              ShellSection.browse,
              ShellSection.activity,
            ])
              _pillItem(target, duration),
          ],
        ),
      ),
    );
  }

  Widget _pillItem(ShellSection target, Duration duration) {
    final active = target == section;
    final color = active ? palette.pillActiveText : palette.pillIdle;
    final badge = target == ShellSection.activity ? activityBadge : 0;
    final glyph = switch (target) {
      ShellSection.home => ShellGlyphKind.home,
      ShellSection.browse => ShellGlyphKind.browse,
      _ => ShellGlyphKind.activity,
    };
    return Semantics(
      button: true,
      selected: active,
      inMutuallyExclusiveGroup: true,
      label: _sectionLabel(target, badge),
      excludeSemantics: true,
      child: PressScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSelect(target),
          child: AnimatedContainer(
            key: ValueKey('nav-${target.name}'),
            duration: duration,
            curve: OnsetMotion.standard,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: active
                  ? palette.pillActive
                  : palette.pillActive.withValues(alpha: 0),
              borderRadius: BorderRadius.circular(OnsetTokens.radiusPill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShellGlyph(
                  glyph,
                  color: color,
                  size: 16,
                  filled: active,
                  strokeWidth: 2,
                ),
                const SizedBox(width: 7),
                Text(
                  target.label,
                  maxLines: 1,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontFamily: OnsetTokens.bodyFamily,
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    color: color,
                  ),
                ),
                if (badge > 0) ...[
                  const SizedBox(width: 7),
                  _CountBadge(count: badge, palette: palette, size: 18),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The pill's top highlight, as a decoration.
class _PillHighlight extends Decoration {
  final Color color;

  const _PillHighlight(this.color);

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _PillHighlightPainter(color);
}

class _PillHighlightPainter extends BoxPainter {
  final Color color;

  _PillHighlightPainter(this.color);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    canvas
      ..save()
      ..translate(offset.dx, offset.dy);
    _TopHighlight(color: color, radius: size.height / 2).paint(canvas, size);
    canvas.restore();
  }
}
