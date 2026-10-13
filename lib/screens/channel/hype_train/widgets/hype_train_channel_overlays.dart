import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/screens/channel/chat/stores/chat_tabs_store.dart';
import 'package:frosty/screens/channel/hype_train/hype_train_placement.dart';
import 'package:frosty/screens/channel/hype_train/stores/hype_train_store.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_sheet.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_slot.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_video_pill.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/utils/context_extensions.dart';
import 'package:frosty/utils/link_router.dart';
import 'package:frosty/utils/modal_bottom_sheet.dart';
import 'package:mobx/mobx.dart';

/// The keyboard, read from the view: the channel `Scaffold` removes the
/// inset from its body.
bool _keyboardOpen(BuildContext context) =>
    View.of(context).viewInsets.bottom > 0;

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
) => showModalBottomSheetWithProperFocus<void>(
  context: context,
  isScrollControlled: true,
  constraints: const BoxConstraints(maxWidth: 480),
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

/// The hype train above chat, under the chat tab bar. It covers only the
/// oldest messages (chat is newest at the bottom); its details never reach
/// the chat input and close while typing.
class HypeTrainChatOverlay extends StatefulWidget {
  const HypeTrainChatOverlay({
    super.key,
    required this.store,
    required this.settingsStore,
    required this.chatTabsStore,
    this.chatInputFocus,
    this.bottomBarHeight = 0,
  });

  final HypeTrainStore store;
  final SettingsStore settingsStore;
  final ChatTabsStore chatTabsStore;

  /// The chat text field: while it has focus the details stay closed.
  final FocusNode? chatInputFocus;

  /// Space the chat input takes at the bottom.
  final double bottomBarHeight;

  @override
  State<HypeTrainChatOverlay> createState() => _HypeTrainChatOverlayState();
}

class _HypeTrainChatOverlayState extends State<HypeTrainChatOverlay> {
  bool get _typing => widget.chatInputFocus?.hasFocus ?? false;

  @override
  void initState() {
    super.initState();
    widget.chatInputFocus?.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(HypeTrainChatOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chatInputFocus != widget.chatInputFocus) {
      oldWidget.chatInputFocus?.removeListener(_onFocus);
      widget.chatInputFocus?.addListener(_onFocus);
    }
  }

  void _onFocus() {
    if (!mounted) return;
    if (_typing && widget.store.expanded) widget.store.toggleExpanded();
    setState(() {});
  }

  @override
  void dispose() {
    widget.chatInputFocus?.removeListener(_onFocus);
    super.dispose();
  }

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
          final largeScreen = context.isLargeScreen;
          // A wide chat (a tablet's expanded column) has room for the full
          // banner.
          final compact =
              placement == HtPlacement.bannerCompact &&
              !(largeScreen && constraints.maxWidth >= _fullBannerMinWidth);
          final chatOnly = !settings.showVideo;
          final top =
              (chatOnly ? context.safePaddingTop : 0) +
              (widget.chatTabsStore.showTabBar ? 48 : 0);
          // The banner is about 80 px; the details take what is left above
          // the chat input, at most 60% of chat.
          final room =
              constraints.maxHeight - top - 6 - 80 - widget.bottomBarHeight - 8;
          final detailsMax = _typing || _keyboardOpen(context)
              ? 0.0
              : room.clamp(0.0, constraints.maxHeight * 0.6);
          return Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.fromLTRB(8, top + 6, 8, 0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: largeScreen ? _maxBannerWidth : double.infinity,
                ),
                child: HypeTrainSlot(
                  store: widget.store,
                  compact: compact,
                  detailsMaxHeight: detailsMax,
                  onLearnMore: () => _openGuide(settings),
                  onOpenDetails: () =>
                      showHypeTrainDetails(context, widget.store, settings),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The pill over the video when landscape full screen hides chat. Put it
/// directly in the video `Stack`.
class HypeTrainVideoOverlay extends StatelessWidget {
  const HypeTrainVideoOverlay({
    super.key,
    required this.store,
    required this.settingsStore,
  });

  final HypeTrainStore store;
  final SettingsStore settingsStore;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        if (_placement(context, settingsStore) != HtPlacement.pill ||
            !store.visible) {
          return const SizedBox.shrink();
        }
        final pill = HypeTrainVideoPill(
          store: store,
          onTap: () => showHypeTrainDetails(context, store, settingsStore),
        );
        // Where chat would be, below the overlay's top bar.
        return settingsStore.landscapeChatLeftSide
            ? Positioned(top: 56, left: 12, child: pill)
            : Positioned(top: 56, right: 12, child: pill);
      },
    );
  }
}
