import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/screens/channel/chat/emote_menu/emote_menu_panel.dart';
import 'package:onset/screens/channel/chat/emote_menu/recent_emotes_panel.dart';
import 'package:onset/screens/channel/chat/stores/chat_store.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';
import 'package:onset/widgets/sheet/onset_panel.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';

/// The emote menu (board ChaineTchatOutils): Recent, Twitch, 7TV, BTTV and
/// FFZ as underlined tabs, their sets as pills, the grid. Under the chat
/// input on a phone; in a panel above it on a tablet
/// (ChaineOutilsTablette), where it is [panel].
class EmoteMenu extends StatelessWidget {
  const EmoteMenu({super.key, required this.chatStore, this.panel = false});

  final ChatStore chatStore;
  final bool panel;

  /// The tablet panel (board ChaineOutilsTablette).
  static const panelSize = Size(376, 372);

  @override
  Widget build(BuildContext context) {
    final settings = chatStore.settings;
    return Observer(
      builder: (context) {
        final colors = SheetColors.of(context);
        final hasRecent = chatStore.assetsStore.recentEmotes.isNotEmpty;
        return EmoteTabsView(
          panel: panel,
          headers: [
            'Recent',
            if (settings.showTwitchEmotes) 'Twitch',
            if (settings.show7TVEmotes) '7TV',
            if (settings.showBTTVEmotes) 'BTTV',
            if (settings.showFFZEmotes) 'FFZ',
          ],
          tabActions: {
            if (hasRecent)
              0: IconButton(
                tooltip: 'Clear recent emotes',
                onPressed: () {
                  chatStore.assetsStore.recentEmotes.clear();
                  chatStore.updateNotification('Recent emotes cleared');
                },
                style: IconButton.styleFrom(
                  fixedSize: const Size(44, 44),
                  minimumSize: const Size(44, 44),
                  padding: EdgeInsets.zero,
                ),
                icon: SheetGlyph(
                  SheetGlyphKind.trash,
                  size: 19,
                  color: colors.secondary,
                ),
              ),
          },
          children: [
            RecentEmotesPanel(chatStore: chatStore),
            if (settings.showTwitchEmotes)
              EmoteMenuPanel(
                chatStore: chatStore,
                twitchEmotes: chatStore.assetsStore.userEmoteSectionToEmotes,
              ),
            ...[
              if (settings.show7TVEmotes) chatStore.assetsStore.sevenTVEmotes,
              if (settings.showBTTVEmotes) chatStore.assetsStore.bttvEmotes,
              if (settings.showFFZEmotes) chatStore.assetsStore.ffzEmotes,
            ].map(
              (emotes) => EmoteMenuPanel(chatStore: chatStore, emotes: emotes),
            ),
          ],
        );
      },
    );
  }
}

/// How an [EmoteTabsView] draws its tabs.
enum EmoteTabsStyle {
  /// The providers: text tabs with a signal underline.
  underline,

  /// The sets of a provider (Channel, Global…): pills.
  pills,
}

/// Tabs over pages that swipe, like the menu always had, drawn as the
/// board's underlined tabs (providers) or pills (sets).
class EmoteTabsView extends StatefulWidget {
  const EmoteTabsView({
    super.key,
    required this.headers,
    required this.children,
    this.tabActions = const {},
    this.style = EmoteTabsStyle.underline,
    this.panel = false,
  }) : assert(headers.length == children.length);

  final List<String> headers;
  final List<Widget> children;

  /// Actions keyed by tab index, shown at the end of the tabs while that
  /// tab is selected.
  final Map<int, Widget> tabActions;
  final EmoteTabsStyle style;

  /// The tablet panel's sizes.
  final bool panel;

  @override
  State<EmoteTabsView> createState() => _EmoteTabsViewState();
}

class _EmoteTabsViewState extends State<EmoteTabsView>
    with TickerProviderStateMixin {
  late TabController _tabController;

  void _handleTabChange() => setState(() {});

  void _initTabController(int length) {
    _tabController = TabController(length: length, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  @override
  void initState() {
    super.initState();
    _initTabController(widget.headers.length);
  }

  @override
  void didUpdateWidget(EmoteTabsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_tabController.length != widget.headers.length) {
      _tabController.removeListener(_handleTabChange);
      _tabController.dispose();
      _initTabController(widget.headers.length);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (index == _tabController.index) return;
    HapticFeedback.selectionClick();
    _tabController.animateTo(
      index,
      duration: motionDuration(context, kTabScrollDuration),
    );
  }

  Widget _underlineTabs(BuildContext context) {
    final colors = SheetColors.of(context);
    final accent = SheetColors.accentOf(context);
    final duration = motionDuration(context, const Duration(milliseconds: 200));
    final action = widget.tabActions[_tabController.index];
    return Container(
      height: widget.panel ? 48 : 46,
      padding: EdgeInsetsDirectional.only(start: 16, end: widget.panel ? 6 : 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colors.hairline,
            width: FrostyTokens.hairlineWidth,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: widget.panel ? 20 : 22,
                children: [
                  for (final (index, header) in widget.headers.indexed)
                    Builder(
                      builder: (context) {
                        final selected = index == _tabController.index;
                        return Semantics(
                          selected: selected,
                          button: true,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _select(index),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Text(
                                  header,
                                  style: TextStyle(
                                    fontFamily: FrostyTokens.bodyFamily,
                                    fontSize: 14,
                                    letterSpacing: -0.07,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: selected
                                        ? colors.text
                                        : colors.tertiary,
                                  ),
                                ),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: AnimatedOpacity(
                                    opacity: selected ? 1 : 0,
                                    duration: duration,
                                    child: Container(
                                      height: 2.5,
                                      decoration: BoxDecoration(
                                        color: accent,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          if (action != null) Center(child: action),
        ],
      ),
    );
  }

  Widget _pillTabs(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.fromLTRB(12, widget.panel ? 10 : 8, 12, 2),
      child: Row(
        spacing: 6,
        children: [
          for (final (index, header) in widget.headers.indexed)
            SheetChoicePill(
              label: header,
              role: SheetChoiceRole.tab,
              selected: index == _tabController.index,
              onSelected: () => _select(index),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Avoid layout overflow during animated height transitions
        // (e.g., when the emote menu is opening/closing and height is tiny).
        const minHeight = 48.0;
        if (constraints.maxHeight < minHeight) {
          return const SizedBox.expand();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            switch (widget.style) {
              EmoteTabsStyle.underline => _underlineTabs(context),
              EmoteTabsStyle.pills => _pillTabs(context),
            },
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: widget.children,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The emote menu in a tablet panel, above the chat input
/// (ChaineOutilsTablette). Shown while [open]; a tap anywhere but the
/// panel and the input closes it ([onClose]). Focusing the input closes
/// it too, as on a phone (the keyboard and the menu take turns).
class EmoteMenuPanelOverlay extends StatefulWidget {
  const EmoteMenuPanelOverlay({
    super.key,
    required this.chatStore,
    required this.open,
    required this.onClose,
    required this.placement,
  });

  final ChatStore chatStore;
  final bool open;
  final VoidCallback onClose;

  /// Where the panel goes; null when it does not fit (then the menu shows
  /// under the input, as on a phone).
  final PanelPlacement? Function() placement;

  @override
  State<EmoteMenuPanelOverlay> createState() => _EmoteMenuPanelOverlayState();
}

class _EmoteMenuPanelOverlayState extends State<EmoteMenuPanelOverlay> {
  final _portal = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    _portal.show();
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (context) {
        final placement = widget.open ? widget.placement() : null;
        final reduce = reduceMotionOf(context);
        return AnimatedSwitcher(
          duration: motionDuration(context, const Duration(milliseconds: 220)),
          reverseDuration: motionDuration(
            context,
            const Duration(milliseconds: 160),
          ),
          transitionBuilder: (child, animation) {
            final fade = FadeTransition(opacity: animation, child: child);
            if (reduce) return fade;
            return ScaleTransition(
              scale: Tween(begin: 0.97, end: 1.0).animate(animation),
              alignment: Alignment.bottomLeft,
              child: fade,
            );
          },
          layoutBuilder: (current, previous) =>
              Stack(children: [...previous, ?current]),
          child: placement == null
              ? const SizedBox.shrink(key: ValueKey('closed'))
              : Stack(
                  key: const ValueKey('open'),
                  children: [
                    Positioned.fromRect(
                      rect: placement.rect,
                      child: TextFieldTapRegion(
                        // Taps in a sheet the panel opened (an emote's
                        // details) do not count as outside: tested.
                        onTapOutside: (_) => widget.onClose(),
                        child: SheetPresentation(
                          panel: true,
                          child: OnsetPanelSurface(
                            side: placement.side,
                            nub: placement.nub,
                            child: Semantics(
                              container: true,
                              label: 'Emote menu',
                              explicitChildNodes: true,
                              child: EmoteMenu(
                                chatStore: widget.chatStore,
                                panel: true,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
      child: const SizedBox.shrink(),
    );
  }
}
