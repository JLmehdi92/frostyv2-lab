import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/screens/settings/account/account_settings.dart';
import 'package:onset/screens/settings/settings.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/settings_glyph.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';
import 'package:onset/screens/settings/widgets/settings_page.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/motion/motion.dart';
import 'package:onset/widgets/motion/press_scale.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';

/// A page opened inside a section on a tablet (Edit Chat Filters under
/// Chat).
@immutable
class SettingsSubPage {
  const SettingsSubPage({
    required this.id,
    required this.title,
    required this.parent,
    required this.builder,
  });

  final SettingsPageId id;
  final String title;
  final SettingsPageId parent;
  final WidgetBuilder builder;
}

/// Which settings page the tablet shows, kept by whoever owns the settings
/// (Profile, the pushed settings) so that it survives a rotation or a
/// change between the phone and tablet layouts.
class SettingsSelection extends ChangeNotifier {
  SettingsSelection({SettingsPageId page = SettingsPageId.general})
    : _page = page;

  SettingsPageId _page;
  SettingsSubPage? _sub;

  /// How many times the page changed (each change enters anew).
  var _turn = 0;

  SettingsPageId get page => _page;
  SettingsSubPage? get sub => _sub;
  int get turn => _turn;

  /// Shows the section [page].
  void select(SettingsPageId page) {
    if (page == _page && _sub == null) return;
    _page = page;
    _sub = null;
    _turn++;
    notifyListeners();
  }

  /// Opens [sub] over its section.
  void open(SettingsSubPage sub) {
    _sub = sub;
    notifyListeners();
  }

  /// Back from the page inside the section.
  void closeSub() {
    if (_sub == null) return;
    _sub = null;
    notifyListeners();
  }
}

/// The tablet's settings (board ParametresTablette): the side column (the
/// profile, the sections, the account, logging out, the version) and the
/// chosen page beside it, in two columns when there is room.
class SettingsMasterDetail extends StatelessWidget {
  const SettingsMasterDetail({
    super.key,
    required this.selection,
    required this.settingsStore,
    required this.authStore,
  });

  final SettingsSelection selection;
  final SettingsStore settingsStore;
  final AuthStore authStore;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - padding.horizontal - 56;
        final aside = width >= 1000 ? 330.0 : 280.0;
        final pane = width - aside - 32.5;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            28 + padding.left,
            12 + padding.top,
            28 + padding.right,
            0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: aside,
                child: _Aside(
                  selection: selection,
                  settingsStore: settingsStore,
                  authStore: authStore,
                ),
              ),
              const SizedBox(width: 16),
              Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: SizedBox(
                  width: FrostyTokens.hairlineWidth,
                  child: ColoredBox(color: SettingsColors.of(context).hairline),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _Pane(
                  selection: selection,
                  settingsStore: settingsStore,
                  authStore: authStore,
                  columns: pane >= 640 ? 2 : 1,
                  bottom: padding.bottom,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The page on screen: an account page without an account (logged out,
/// Twitch unreachable) shows General.
SettingsPageId _shown(SettingsPageId page, AuthStore authStore) =>
    page.needsAccount && !hasAccount(authStore) ? SettingsPageId.general : page;

class _Aside extends StatelessWidget {
  const _Aside({
    required this.selection,
    required this.settingsStore,
    required this.authStore,
  });

  final SettingsSelection selection;
  final SettingsStore settingsStore;
  final AuthStore authStore;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Semantics(
      label: 'Settings sections',
      container: true,
      explicitChildNodes: true,
      child: ListenableBuilder(
        listenable: selection,
        builder: (context, _) => Observer(
          builder: (context) {
            final loggedIn = hasAccount(authStore);
            final page = _shown(selection.page, authStore);
            Widget row(SettingsPageId id, {String? value}) => _AsideRow(
              page: id,
              selected: page == id,
              value: value,
              onTap: () => selection.select(id),
            );
            return ListView(
              padding: EdgeInsets.fromLTRB(0, 4, 0, 28 + bottom),
              children: [
                _ProfileCard(authStore: authStore),
                const SizedBox(height: 18),
                const SettingsSectionLabel(
                  'Settings',
                  padding: EdgeInsets.symmetric(horizontal: 12),
                ),
                const SizedBox(height: 6),
                for (final id in SettingsPageId.sections) row(id),
                if (loggedIn) ...[
                  const SizedBox(height: 18),
                  const SettingsSectionLabel(
                    'Account',
                    padding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                  const SizedBox(height: 6),
                  row(SettingsPageId.account),
                  row(
                    SettingsPageId.blocked,
                    value: '${authStore.user.blockedUsers.length}',
                  ),
                  const SizedBox(height: 18),
                  _LogoutRow(authStore: authStore),
                ],
                const SizedBox(height: 18),
                SettingsFooter(external: () => settingsStore.launchUrlExternal),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A section in the side column: 48 dp, tinted and ringed in the signal
/// colour when it is the one shown.
class _AsideRow extends StatelessWidget {
  const _AsideRow({
    required this.page,
    required this.selected,
    required this.onTap,
    this.value,
  });

  final SettingsPageId page;
  final bool selected;
  final VoidCallback onTap;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    final accent = SettingsColors.accentOf(context);
    final duration = settingsMotion(context, 220);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Semantics(
        button: true,
        selected: selected,
        label: page.title,
        value: value,
        excludeSemantics: true,
        child: PressScale(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: AnimatedContainer(
              duration: duration,
              curve: FrostyMotion.standard,
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: selected
                    ? accent.withValues(alpha: 0.10)
                    : accent.withValues(alpha: 0),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? accent.withValues(alpha: 0.45)
                      : accent.withValues(alpha: 0),
                  width: FrostyTokens.hairlineWidth,
                ),
              ),
              child: Row(
                spacing: 12,
                children: [
                  SettingsGlyph(
                    page.glyph,
                    color: selected ? accent : colors.secondary,
                  ),
                  Expanded(
                    child: Text(
                      page.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: FrostyTokens.bodyFamily,
                        fontSize: 15,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: selected ? colors.text : colors.body,
                      ),
                    ),
                  ),
                  if (value case final value?)
                    Text(
                      value,
                      style: SettingsText.value.copyWith(
                        color: colors.secondary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoutRow extends StatelessWidget {
  const _LogoutRow({required this.authStore});

  final AuthStore authStore;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    return Semantics(
      button: true,
      label: 'Log out',
      excludeSemantics: true,
      child: PressScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => confirmLogout(context, authStore),
          child: SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                spacing: 12,
                children: [
                  SettingsGlyph(SettingsGlyphKind.logout, color: colors.danger),
                  Text(
                    'Log out',
                    style: TextStyle(
                      fontFamily: FrostyTokens.bodyFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.danger,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The side column's top: the viewer and "My channel", or how to log in.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.authStore});

  final AuthStore authStore;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final colors = SettingsColors.of(context);
        final details = authStore.user.details;
        if (!hasAccount(authStore) || details == null) {
          return ProfileLoginCard(authStore: authStore);
        }
        return SettingsCard(
          radius: FrostyTokens.radiusLarge,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              Row(
                spacing: 14,
                children: [
                  SettingsAvatar(user: details, size: 60),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 3,
                      children: [
                        Text(
                          details.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: FrostyTokens.bodyFamily,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: colors.text,
                          ),
                        ),
                        Text(
                          accountLine(details),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: FrostyTokens.bodyFamily,
                            fontSize: 13,
                            color: colors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SettingsButton(
                label: 'My channel',
                expand: true,
                icon: SettingsGlyph(
                  SettingsGlyphKind.play,
                  size: 13,
                  color: colors.text,
                ),
                onPressed: () => openMyChannel(context, authStore),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Pane extends StatelessWidget {
  const _Pane({
    required this.selection,
    required this.settingsStore,
    required this.authStore,
    required this.columns,
    required this.bottom,
  });

  final SettingsSelection selection;
  final SettingsStore settingsStore;
  final AuthStore authStore;
  final int columns;
  final double bottom;

  void _open(SettingsPageId id, String title, WidgetBuilder builder) {
    if (id.isSection) {
      selection.select(id);
    } else {
      selection.open(
        SettingsSubPage(
          id: id,
          title: title,
          parent: selection.page,
          builder: builder,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotionOf(context);
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      removeLeft: true,
      removeRight: true,
      child: ListenableBuilder(
        listenable: selection,
        builder: (context, _) => Observer(
          builder: (context) {
            final page = _shown(selection.page, authStore);
            final sub = page == selection.page ? selection.sub : null;
            final section = SettingsPaneScope(
              key: ValueKey(('page', page, selection.turn)),
              onOpen: _open,
              columns: columns,
              title: page.title,
              description: page.description,
              child: Builder(
                builder: (context) => buildSettingsPage(
                  page,
                  settingsStore: settingsStore,
                  authStore: authStore,
                ),
              ),
            );
            return Stack(
              children: [
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: reduce
                        ? FrostyMotion.reducedFade
                        : const Duration(milliseconds: 300),
                    switchInCurve: FrostyMotion.standard,
                    switchOutCurve: FrostyMotion.standard,
                    layoutBuilder: (current, previous) =>
                        Stack(children: [?current]),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: reduce
                          ? child
                          : SlideTransition(
                              position: Tween(
                                begin: const Offset(0, 0.008),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey((page, selection.turn)),
                      child: section,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: _SubPageHost(
                    sub: sub,
                    builder: (sub) => ColoredBox(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: SettingsPaneScope(
                            onOpen: _open,
                            columns: 1,
                            title: sub.title,
                            backLabel: sub.parent.title,
                            onBack: selection.closeSub,
                            child: Builder(builder: sub.builder),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Slides a page inside a section in from the right (360 ms) and out
/// (260 ms); a fade under reduce motion.
class _SubPageHost extends StatefulWidget {
  const _SubPageHost({required this.sub, required this.builder});

  final SettingsSubPage? sub;
  final Widget Function(SettingsSubPage sub) builder;

  @override
  State<_SubPageHost> createState() => _SubPageHostState();
}

class _SubPageHostState extends State<_SubPageHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curved;

  /// The page drawn, kept while it slides out.
  SettingsSubPage? _shown;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
      reverseDuration: const Duration(milliseconds: 260),
      value: widget.sub == null ? 0 : 1,
    );
    _curved = CurvedAnimation(
      parent: _controller,
      curve: FrostyMotion.standard,
      reverseCurve: const Cubic(0.4, 0, 1, 1),
    );
    _shown = widget.sub;
  }

  @override
  void didUpdateWidget(_SubPageHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sub = widget.sub;
    final reduce = reduceMotionOf(context);
    _controller
      ..duration = reduce
          ? FrostyMotion.reducedFade
          : const Duration(milliseconds: 360)
      ..reverseDuration = reduce
          ? FrostyMotion.reducedFade
          : const Duration(milliseconds: 260);
    if (sub != null) {
      _shown = sub;
      _controller.forward();
    } else if (_shown != null) {
      _controller.reverse().whenCompleteOrCancel(() {
        if (mounted && widget.sub == null) setState(() => _shown = null);
      });
    }
  }

  @override
  void dispose() {
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    if (shown == null) return const SizedBox.shrink();
    final reduce = reduceMotionOf(context);
    final curved = _curved;
    final page = KeyedSubtree(
      key: ValueKey(('sub', shown.id)),
      child: widget.builder(shown),
    );
    return IgnorePointer(
      ignoring: widget.sub == null,
      child: reduce
          ? FadeTransition(opacity: curved, child: page)
          : SlideTransition(
              position: Tween(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(curved),
              child: page,
            ),
    );
  }
}
