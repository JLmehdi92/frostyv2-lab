import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onset/l10n/enum_labels.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/settings/widgets/settings_glyph.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/motion/motion.dart';
import 'package:onset/widgets/motion/press_scale.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// The pages of the settings: the
/// five sections, the account and its blocked users, and the chat filters
/// under Chat.
///
/// Their names are in lib/l10n/enum_labels.dart (`title`, `description`).
enum SettingsPageId {
  general(SettingsGlyphKind.general),
  video(SettingsGlyphKind.video),
  chat(SettingsGlyphKind.chat),
  notifications(SettingsGlyphKind.bell),
  other(SettingsGlyphKind.other),
  account(SettingsGlyphKind.user),
  blocked(SettingsGlyphKind.ban),
  chatFilters(SettingsGlyphKind.filter);

  const SettingsPageId(this.glyph);

  /// The sections under "Customize" (phone) and "Settings" (Profile).
  static const customize = [general, video, chat, notifications];

  /// The sections of the tablet's side column.
  static const sections = [general, video, chat, notifications, other];

  final SettingsGlyphKind glyph;

  /// The pages listed on their own in the tablet's side column.
  bool get isSection => this != chatFilters;

  /// Logged in only.
  bool get needsAccount => this == account || this == blocked;
}

/// Opens a settings page in its pane on a tablet: the side column's page
/// for a section, over the section for a page inside it. The pane names it
/// from [SettingsPageId] when it builds, so the title follows the language.
typedef SettingsOpener =
    void Function(SettingsPageId id, WidgetBuilder builder);

/// A settings page shown in the tablet's detail pane: two columns of groups
/// under the page's title, and where its links open.
class SettingsPaneScope extends InheritedWidget {
  const SettingsPaneScope({
    super.key,
    required super.child,
    required this.onOpen,
    this.columns = 2,
    this.title,
    this.description,
    this.backLabel,
    this.onBack,
  });

  final SettingsOpener onOpen;

  /// A page inside a section: "‹ Chat" above its title instead of the
  /// eyebrow.
  final String? backLabel;
  final VoidCallback? onBack;

  /// Groups side by side (1 when the pane is narrow).
  final int columns;

  /// The page's title and line under it, above its groups.
  final String? title;
  final String? description;

  static SettingsPaneScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsPaneScope>();

  @override
  bool updateShouldNotify(SettingsPaneScope oldWidget) =>
      columns != oldWidget.columns ||
      title != oldWidget.title ||
      description != oldWidget.description ||
      backLabel != oldWidget.backLabel ||
      onBack != oldWidget.onBack ||
      onOpen != oldWidget.onOpen;
}

/// Opens the settings page [id]: in the tablet's pane when there is one,
/// else pushed (phone) with its back button and title. Completes when the
/// pushed page is closed (at once in a pane).
///
/// The title is read from [id] each time the page builds, so switching the
/// language on Settings › General renames the page at once. The route is
/// named by [SettingsPageId.name], the same in every language, so analytics
/// count one screen whatever the language.
Future<void> openSettingsPage(
  BuildContext context, {
  required SettingsPageId id,
  required WidgetBuilder builder,
}) {
  final pane = SettingsPaneScope.maybeOf(context);
  if (pane != null) {
    pane.onOpen(id, builder);
    return Future.value();
  }
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      settings: RouteSettings(name: settingsRouteName(id)),
      builder: (context) => SettingsScaffold(
        title: id.title(context.l10n),
        body: builder(context),
      ),
    ),
  );
}

/// The route name of the settings page [id] when it is pushed: its id, not
/// its translated title.
String settingsRouteName(SettingsPageId id) => 'Settings/${id.name}';

/// Opens [url] the way links open in the app ("Open links in external
/// browser").
Future<void> launchSettingsLink(String url, {required bool external}) =>
    launchUrl(
      Uri.parse(url),
      mode: external
          ? LaunchMode.externalApplication
          : LaunchMode.inAppBrowserView,
    );

/// A settings page's groups, one under the other on a phone (padded by the
/// [MediaQuery] the page gets: its header above, the screen's edges); in a
/// tablet pane under the page's title and its jump chips, in two columns.
class SettingsGroupsView extends StatefulWidget {
  const SettingsGroupsView({
    super.key,
    required this.children,
    this.footer,
    this.onRefresh,
  });

  /// The groups (and cards) of the page, 22 dp apart.
  final List<Widget> children;

  /// Under every group (the version, a note).
  final Widget? footer;

  /// Pull to refresh.
  final RefreshCallback? onRefresh;

  @override
  State<SettingsGroupsView> createState() => _SettingsGroupsViewState();
}

class _SettingsGroupsViewState extends State<SettingsGroupsView> {
  final _controller = ScrollController();
  final _anchors = <int, GlobalKey>{};

  GlobalKey _anchor(int index) =>
      _anchors.putIfAbsent(index, () => GlobalKey(debugLabel: 'group $index'));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _jump(int index) {
    final target = _anchors[index]?.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: reduceMotionOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 360),
      curve: OnsetMotion.standard,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pane = SettingsPaneScope.maybeOf(context);
    final Widget scroll;
    if (pane == null) {
      final padding = MediaQuery.paddingOf(context);
      scroll = ListView(
        controller: _controller,
        physics: widget.onRefresh == null
            ? null
            : const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16 + padding.left,
          padding.top + 16,
          16 + padding.right,
          padding.bottom + 32,
        ),
        children: [
          for (final child in widget.children)
            Padding(padding: const EdgeInsets.only(bottom: 22), child: child),
          ?widget.footer,
        ],
      );
    } else {
      scroll = _pane(context, pane);
    }
    if (widget.onRefresh case final refresh?) {
      return RefreshIndicator.adaptive(onRefresh: refresh, child: scroll);
    }
    return scroll;
  }

  Widget _pane(BuildContext context, SettingsPaneScope pane) {
    final colors = SettingsColors.of(context);
    final groups = widget.children;
    final titled = [
      for (final (index, child) in groups.indexed)
        if (child is SettingsGroup && child.title != null)
          (index, child.title!),
    ];
    Widget anchored(int index) => Padding(
      key: _anchor(index),
      padding: const EdgeInsets.only(bottom: 22),
      child: groups[index],
    );

    final Widget body;
    if (pane.columns < 2 || groups.length < 2) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (var i = 0; i < groups.length; i++) anchored(i)],
      );
    } else {
      final split = _balancedSplit(groups);
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 20,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (var i = 0; i < split; i++) anchored(i)],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = split; i < groups.length; i++) anchored(i),
              ],
            ),
          ),
        ],
      );
    }
    return ListView(
      controller: _controller,
      physics: widget.onRefresh == null
          ? null
          : const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 40),
      children: [
        if (pane.title case final title?)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                if (pane.onBack case final onBack?)
                  Transform.translate(
                    offset: const Offset(-6, 0),
                    child: TextButton.icon(
                      onPressed: onBack,
                      style: TextButton.styleFrom(
                        foregroundColor: colors.body,
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.only(left: 6, right: 14),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                          fontFamily: OnsetTokens.bodyFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      icon: SettingsGlyph(
                        SettingsGlyphKind.chevronLeft,
                        strokeWidth: 2,
                        color: colors.body,
                      ),
                      label: Text(pane.backLabel ?? context.l10n.commonBack),
                    ),
                  )
                else
                  Text(
                    context.l10n.settingsTitle.toUpperCase(),
                    style: SettingsText.section.copyWith(
                      color: colors.secondary,
                    ),
                  ),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: OnsetTokens.bodyFamily,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.9,
                      height: 1.1,
                      color: colors.text,
                    ),
                  ),
                ),
                if (pane.description case final description?)
                  if (description.isNotEmpty)
                    Text(
                      description,
                      style: SettingsText.body.copyWith(
                        height: 1.4,
                        color: colors.secondary,
                      ),
                    ),
              ],
            ),
          ),
        if (titled.length > 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Semantics(
              label: context.l10n.settingsJumpToGroup,
              container: true,
              explicitChildNodes: true,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (index, title) in titled)
                    _JumpChip(label: title, onTap: () => _jump(index)),
                ],
              ),
            ),
          ),
        body,
        ?widget.footer,
      ],
    );
  }

  /// Where the second column starts: the groups keep their order, and the
  /// columns end as close as they can (CSS columns do the same).
  static int _balancedSplit(List<Widget> groups) {
    int weight(Widget child) => child is SettingsGroup ? child.weight : 1;
    final total = groups.fold<int>(0, (sum, child) => sum + weight(child));
    var best = 1;
    var bestGap = total;
    var left = 0;
    for (var i = 0; i < groups.length - 1; i++) {
      left += weight(groups[i]);
      final gap = (total - 2 * left).abs();
      if (gap < bestGap) {
        bestGap = gap;
        best = i + 1;
      }
    }
    return best;
  }
}

/// A chip that scrolls the pane to its group.
class _JumpChip extends StatelessWidget {
  const _JumpChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: PressScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: ShapeDecoration(
              color: colors.card,
              shape: StadiumBorder(
                side: BorderSide(
                  color: colors.buttonRing,
                  width: OnsetTokens.hairlineWidth,
                ),
              ),
            ),
            // Centred, yet as wide as its label: the container's own
            // alignment would stretch the pill across the Wrap's whole row.
            child: Align(
              widthFactor: 1,
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: OnsetTokens.bodyFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.body,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A settings page pushed on a phone: the glass header with its back
/// button and [title], the page scrolling under it.
class SettingsScaffold extends StatelessWidget {
  const SettingsScaffold({
    super.key,
    required this.title,
    required this.body,
    this.onBack,
  });

  /// The header's height under the status bar.
  static const headerHeight = 56.0;

  final String title;
  final Widget body;

  /// Back (the route's pop by default).
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final colors = SettingsColors.of(context);
    final ground = theme.scaffoldBackgroundColor;
    final themed =
        theme.appBarTheme.systemOverlayStyle ??
        (theme.brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: themed,
      child: Scaffold(
        backgroundColor: ground,
        body: Stack(
          children: [
            Positioned.fill(
              child: MediaQuery(
                data: media.copyWith(
                  padding: media.padding.copyWith(
                    top: media.padding.top + headerHeight,
                  ),
                ),
                child: body,
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              // No blur: this page can be pushed over the channel's video
              // (the chat's menu), and a blur would read it during the
              // transition. A nearly opaque fill stands in for the glass.
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: ground.withValues(alpha: 0.96),
                  border: Border(
                    bottom: BorderSide(
                      color: colors.hairline,
                      width: OnsetTokens.hairlineWidth,
                    ),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.only(
                    top: media.padding.top,
                    left: media.padding.left + 4,
                    right: media.padding.right + 16,
                  ),
                  child: SizedBox(
                    height: headerHeight,
                    child: Row(
                      spacing: 2,
                      children: [
                        SettingsBackButton(
                          onPressed:
                              onBack ?? () => Navigator.maybePop(context),
                        ),
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SettingsText.pageTitle.copyWith(
                                color: colors.text,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The 44 dp back chevron.
class SettingsBackButton extends StatelessWidget {
  const SettingsBackButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: context.l10n.commonBack,
    onPressed: onPressed,
    constraints: const BoxConstraints.tightFor(width: 44, height: 44),
    padding: EdgeInsets.zero,
    style: IconButton.styleFrom(splashFactory: NoSplash.splashFactory),
    icon: SettingsGlyph(
      SettingsGlyphKind.chevronLeft,
      size: 22,
      strokeWidth: 2,
      color: SettingsColors.of(context).text,
    ),
  );
}

/// "ONSET v1.0.0 (1)": the version, at the end of the settings and the
/// bottom of the tablet's side column.
class SettingsFooter extends StatefulWidget {
  const SettingsFooter({super.key});

  @override
  State<SettingsFooter> createState() => _SettingsFooterState();
}

class _SettingsFooterState extends State<SettingsFooter> {
  final _info = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    final style = OnsetType.tabular(
      TextStyle(
        fontFamily: OnsetTokens.bodyFamily,
        fontSize: 12,
        color: colors.tertiary,
      ),
    );
    return FutureBuilder<PackageInfo>(
      future: _info,
      builder: (context, snapshot) {
        final info = snapshot.data;
        return Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 8),
          child: Text(
            info == null ? '' : 'ONSET v${info.version} (${info.buildNumber})',
            textAlign: TextAlign.center,
            style: style,
          ),
        );
      },
    );
  }
}

/// Shows a settings list (a language, labels, muted keywords): a sheet on a
/// phone, a dialog on a tablet. [builder] makes its [SettingsSheetContent].
///
/// The keyboard never covers it: the sheet stands on the keyboard and is
/// bounded by the room left above it (its title and any field stay pinned,
/// the list scrolls); the dialog takes the keyboard's room at once.
Future<T?> showSettingsSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  final colors = SettingsColors.of(context);
  if (context.isLargeScreen) {
    return showDialog<T>(
      context: context,
      barrierColor: kSheetScrim,
      builder: (context) => Dialog(
        backgroundColor: colors.dialog,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(40),
        insetAnimationDuration: Duration.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OnsetTokens.radiusLarge),
          side: BorderSide(
            color: colors.cardRing,
            width: OnsetTokens.hairlineWidth,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460, maxHeight: 640),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SheetChrome(
              handle: false,
              background: colors.dialog,
              child: Builder(builder: builder),
            ),
          ),
        ),
      ),
    );
  }
  // The sheet route drops the status bar's padding: kept from here.
  final statusBar = MediaQuery.paddingOf(context).top;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: colors.sheet,
    barrierColor: kSheetScrim,
    elevation: 0,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(OnsetTokens.radiusLarge),
      ),
    ),
    builder: (context) {
      final media = MediaQuery.of(context);
      final keyboard = media.viewInsets.bottom;
      final height = keyboard > 0
          ? media.size.height - statusBar - 8 - keyboard
          : media.size.height * 0.82;
      return Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: math.max(0, height)),
          child: MediaQuery.removeViewInsets(
            context: context,
            removeBottom: true,
            child: SafeArea(
              top: false,
              child: _SheetChrome(
                handle: true,
                background: colors.sheet,
                child: Builder(builder: builder),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// How the surrounding sheet or dialog draws a [SettingsSheetContent].
class _SheetChrome extends InheritedWidget {
  const _SheetChrome({
    required this.handle,
    required this.background,
    required super.child,
  });

  final bool handle;
  final Color background;

  static _SheetChrome? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SheetChrome>();

  @override
  bool updateShouldNotify(_SheetChrome oldWidget) =>
      handle != oldWidget.handle || background != oldWidget.background;
}

/// A settings list in its sheet or dialog: the handle (phone), [title] and
/// "Done", then [pinned] (a field) all kept on top, and [slivers] scrolling
/// under them.
class SettingsSheetContent extends StatelessWidget {
  const SettingsSheetContent({
    super.key,
    required this.title,
    this.pinned,
    required this.slivers,
  });

  final String title;
  final Widget? pinned;
  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    final chrome = _SheetChrome.maybeOf(context);
    final handle = chrome?.handle ?? false;
    final top = Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (handle)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.handle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: SettingsText.pageTitle.copyWith(
                      letterSpacing: -0.27,
                      color: colors.text,
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: SettingsColors.accentOf(context),
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontFamily: OnsetTokens.bodyFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(context.l10n.commonDone),
              ),
            ],
          ),
        ],
      ),
    );
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: title,
      child: CustomScrollView(
        shrinkWrap: true,
        slivers: [
          PinnedHeaderSliver(
            child: ColoredBox(
              color: chrome?.background ?? colors.sheet,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [top, ?pinned],
              ),
            ),
          ),
          ...slivers,
        ],
      ),
    );
  }
}

/// A choice in a settings list: 48 dp, tinted in the signal colour with a
/// check when it is the one picked.
class SettingsChoiceRow extends StatelessWidget {
  const SettingsChoiceRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    final accent = SettingsColors.accentOf(context);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      selected: selected,
      button: true,
      child: Material(
        color: selected ? accent.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          highlightColor: colors.pressed,
          splashFactory: NoSplash.splashFactory,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: OnsetTokens.bodyFamily,
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? accent : colors.text,
                    ),
                  ),
                ),
                if (selected)
                  SettingsGlyph(
                    SettingsGlyphKind.check,
                    strokeWidth: 2.4,
                    color: accent,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A box ticked in a settings list (the labels to hide).
class SettingsCheckRow extends StatelessWidget {
  const SettingsCheckRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    final accent = SettingsColors.accentOf(context);
    return Semantics(
      checked: value,
      button: true,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(!value);
        },
        borderRadius: BorderRadius.circular(12),
        highlightColor: colors.pressed,
        splashFactory: NoSplash.splashFactory,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              spacing: 14,
              children: [
                AnimatedContainer(
                  duration: settingsMotion(context, 180),
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value ? accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    border: value
                        ? null
                        : Border.all(color: colors.tertiary, width: 1.5),
                  ),
                  child: value
                      ? SettingsGlyph(
                          SettingsGlyphKind.check,
                          size: 16,
                          strokeWidth: 3,
                          color: SettingsColors.onAccentOf(context),
                        )
                      : null,
                ),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: OnsetTokens.bodyFamily,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: colors.text,
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
