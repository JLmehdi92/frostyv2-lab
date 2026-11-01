import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';
import 'package:onset/models/community_highlights.dart';
import 'package:onset/screens/channel/chat/stores/chat_tabs_store.dart';
import 'package:onset/screens/channel/community_highlights/highlight_stack.dart';
import 'package:onset/screens/channel/community_highlights/stores/community_highlights_store.dart';
import 'package:onset/screens/channel/community_highlights/widgets/highlight_slot.dart';
import 'package:onset/screens/channel/hype_train/hype_train_placement.dart';
import 'package:onset/screens/channel/hype_train/stores/hype_train_store.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_sheet.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_slot.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_tokens.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_video_pill.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/utils/link_router.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';

/// Whether the keyboard is up, from the [ChannelKeyboardScope] above (a
/// dependency: the overlays follow it coming up and going away). Without
/// one (an overlay drawn alone), read from the view: the channel
/// `Scaffold` removes the inset from its body.
bool _keyboardOpen(BuildContext context) =>
    context.dependOnInheritedWidgetOfExactType<_KeyboardOpen>()?.open ??
    View.of(context).viewInsets.bottom > 0;

/// Tells the channel's overlays below it whether the software keyboard is
/// up. Put it above the channel's `Scaffold`, which removes the keyboard's
/// inset from its body (`MediaQuery.viewInsetsOf` reads 0 in there).
///
/// It reads the insets itself, so it is rebuilt on each frame of the
/// keyboard's slide; [child] is passed in as is, and the overlays are
/// told only when the keyboard comes up or goes away.
class ChannelKeyboardScope extends StatelessWidget {
  const ChannelKeyboardScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => _KeyboardOpen(
    open: MediaQuery.viewInsetsOf(context).bottom > 0,
    child: child,
  );
}

class _KeyboardOpen extends InheritedWidget {
  const _KeyboardOpen({required this.open, required super.child});

  final bool open;

  @override
  bool updateShouldNotify(_KeyboardOpen oldWidget) => open != oldWidget.open;
}

HtPlacement _placement(
  BuildContext context,
  SettingsStore settings, {
  bool typing = false,
}) => hypeTrainPlacement(
  landscape: context.isLandscape,
  forceVertical: settings.landscapeForceVerticalChat,
  fullScreen: settings.fullScreen,
  overlayChat: settings.fullScreenChatOverlay,
  showVideo: settings.showVideo,
  keyboardOpen: typing || _keyboardOpen(context),
  largeScreen: context.isLargeScreen,
);

/// Widest banner on a large screen, in dp (Twitch's tablet chat card).
const _maxBannerWidth = 560.0;

/// Narrowest chat that gets the full banner on a large screen.
const _fullBannerMinWidth = 480.0;

void _openGuide(SettingsStore settings) =>
    LinkRouter.open(htHelpUrl, launchExternal: settings.launchUrlExternal);

/// The details as a bottom sheet (landscape, or from the pill). It closes
/// by itself when the train is gone.
Future<void> showHypeTrainDetails(
  BuildContext context,
  HypeTrainStore store,
  SettingsStore settings,
) => showOnsetSheet<void>(
  context: context,
  constraints: const BoxConstraints(maxWidth: 480),
  // The details on the community green, the hype
  // train itself unchanged.
  background: htSheetBackground(Theme.of(context).brightness),
  builder: (context) => _ClosesWhenHidden(
    store: store,
    child: SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: SingleChildScrollView(
          child: HypeTrainSheet(
            store: store,
            onLearnMore: () => _openGuide(settings),
          ),
        ),
      ),
    ),
  ),
);

class _ClosesWhenHidden extends StatefulWidget {
  const _ClosesWhenHidden({required this.store, required this.child});

  final HypeTrainStore store;
  final Widget child;

  @override
  State<_ClosesWhenHidden> createState() => _ClosesWhenHiddenState();
}

class _ClosesWhenHiddenState extends State<_ClosesWhenHidden> {
  late final ReactionDisposer _dispose;

  @override
  void initState() {
    super.initState();
    _dispose = reaction((_) => widget.store.visible, (bool visible) {
      if (!visible && mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The top of chat, under the chat tab bar: the hype train, then the
/// community highlight. It covers only the oldest messages (chat is newest
/// at the bottom) and never reaches the chat input; the hype train details
/// close while typing.
class ChannelChatTopOverlay extends StatefulWidget {
  const ChannelChatTopOverlay({
    super.key,
    this.hypeTrain,
    this.highlights,
    required this.settingsStore,
    required this.chatTabsStore,
    this.onWatchRaid,
    this.pinnedMessage,
    this.chatInputFocus,
    this.bottomBarHeight = 0,
  });

  /// Null while its setting is off.
  final HypeTrainStore? hypeTrain;

  /// Null while its setting is off.
  final CommunityHighlightsStore? highlights;

  final SettingsStore settingsStore;
  final ChatTabsStore chatTabsStore;

  /// "Watch" on an outgoing raid.
  final ValueChanged<OutgoingRaid>? onWatchRaid;

  /// Renders a pinned message like chat.
  final PinnedMessageBuilder? pinnedMessage;

  /// The chat text field: while it has focus the details stay closed.
  final FocusNode? chatInputFocus;

  /// Space the chat input takes at the bottom.
  final double bottomBarHeight;

  @override
  State<ChannelChatTopOverlay> createState() => _ChannelChatTopOverlayState();
}

class _ChannelChatTopOverlayState extends State<ChannelChatTopOverlay> {
  bool get _typing => widget.chatInputFocus?.hasFocus ?? false;

  @override
  void initState() {
    super.initState();
    widget.chatInputFocus?.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(ChannelChatTopOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chatInputFocus != widget.chatInputFocus) {
      oldWidget.chatInputFocus?.removeListener(_onFocus);
      widget.chatInputFocus?.addListener(_onFocus);
    }
  }

  void _onFocus() {
    if (!mounted) return;
    final hypeTrain = widget.hypeTrain;
    if (_typing && hypeTrain != null && hypeTrain.expanded) {
      hypeTrain.toggleExpanded();
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.chatInputFocus?.removeListener(_onFocus);
    super.dispose();
  }

  void _watchRaid(OutgoingRaid raid) => widget.onWatchRaid?.call(raid);

  @override
  Widget build(BuildContext context) {
    final settings = widget.settingsStore;
    return LayoutBuilder(
      builder: (context, constraints) => Observer(
        builder: (context) {
          final placement = _placement(context, settings);
          if (placement == HtPlacement.none || placement == HtPlacement.pill) {
            return const SizedBox.shrink();
          }
          final hypeTrain = widget.hypeTrain;
          final highlights = widget.highlights;
          final largeScreen = context.isLargeScreen;
          final typing = _typing || _keyboardOpen(context);
          // A wide chat (a tablet's expanded column) has room for the full
          // banner and an expanded highlight.
          final wide =
              largeScreen && constraints.maxWidth >= _fullBannerMinWidth;
          final compact = placement == HtPlacement.bannerCompact && !wide;
          final trainUp = hypeTrain?.visible ?? false;
          // The hype train details take the room; the highlight comes back
          // when they close. Not a gift bomb or an incoming raid: they last
          // seconds, so waiting for the details would mean never seeing
          // them.
          final showHighlights =
              highlights != null &&
              (!(trainUp && hypeTrain!.expanded) ||
                  (highlights.current?.kind.shortLived ?? false));
          // On a phone the highlight stays one line under a running train,
          // and while typing.
          final highlightsCompact = compact || (!wide && (trainUp || typing));
          final chatOnly = !settings.showVideo;
          final top =
              (chatOnly ? context.safePaddingTop : 0) +
              (widget.chatTabsStore.showTabBar ? 48 : 0);
          // The banner is 74 dp, growing with the text; the details take
          // what is left above the chat input, at most 60% of chat.
          final room =
              constraints.maxHeight -
              top -
              6 -
              htBannerHeight(MediaQuery.textScalerOf(context)) -
              widget.bottomBarHeight -
              8;
          final detailsMax = typing
              ? 0.0
              : room.clamp(0.0, constraints.maxHeight * 0.6);
          // Nothing goes past the chat input.
          final maxHeight =
              (constraints.maxHeight - top - 6 - widget.bottomBarHeight - 8)
                  .clamp(0.0, double.infinity);
          return Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.fromLTRB(8, top + 6, 8, 0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: largeScreen ? _maxBannerWidth : double.infinity,
                  maxHeight: maxHeight,
                ),
                // A very short chat (the keyboard up) scrolls the tiers
                // instead of overflowing.
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (hypeTrain != null)
                        HypeTrainSlot(
                          store: hypeTrain,
                          compact: compact,
                          detailsMaxHeight: detailsMax,
                          onLearnMore: () => _openGuide(settings),
                          onOpenDetails: () => showHypeTrainDetails(
                            context,
                            hypeTrain,
                            settings,
                          ),
                        ),
                      if (trainUp && showHighlights && highlights.visible)
                        const SizedBox(height: 6),
                      if (showHighlights)
                        HighlightSlot(
                          store: highlights,
                          compact: highlightsCompact,
                          onWatchRaid: _watchRaid,
                          pinnedMessage: widget.pinnedMessage,
                          onOpenDetails: () => showHighlightDetails(
                            context,
                            highlights,
                            onWatchRaid: _watchRaid,
                            pinnedMessage: widget.pinnedMessage,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The pills over the video when landscape full screen hides chat: the
/// hype train, then the community highlight. Put it directly in the video
/// `Stack`.
class ChannelVideoTopOverlay extends StatelessWidget {
  const ChannelVideoTopOverlay({
    super.key,
    this.hypeTrain,
    this.highlights,
    required this.settingsStore,
    this.onWatchRaid,
    this.pinnedMessage,
  });

  final HypeTrainStore? hypeTrain;
  final CommunityHighlightsStore? highlights;
  final SettingsStore settingsStore;
  final ValueChanged<OutgoingRaid>? onWatchRaid;
  final PinnedMessageBuilder? pinnedMessage;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        if (_placement(context, settingsStore) != HtPlacement.pill) {
          return const SizedBox.shrink();
        }
        final hypeTrain = this.hypeTrain;
        final highlights = this.highlights;
        final pills = [
          if (hypeTrain != null && hypeTrain.visible)
            HypeTrainVideoPill(
              store: hypeTrain,
              onTap: () =>
                  showHypeTrainDetails(context, hypeTrain, settingsStore),
            ),
          if (highlights != null && highlights.visible)
            HighlightVideoPill(
              store: highlights,
              onTap: () => showHighlightDetails(
                context,
                highlights,
                onWatchRaid: (raid) => onWatchRaid?.call(raid),
                pinnedMessage: pinnedMessage,
              ),
            ),
        ];
        if (pills.isEmpty) return const SizedBox.shrink();
        final left = settingsStore.landscapeChatLeftSide;
        final column = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: left
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
          spacing: 8,
          children: pills,
        );
        // Where chat would be, below the overlay's top bar.
        return left
            ? Positioned(top: 56, left: 12, child: column)
            : Positioned(top: 56, right: 12, child: column);
      },
    );
  }
}
