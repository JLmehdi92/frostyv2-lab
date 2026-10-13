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

HtPlacement _placement(BuildContext context, SettingsStore settings) =>
    hypeTrainPlacement(
      landscape: context.isLandscape,
      forceVertical: settings.landscapeForceVerticalChat,
      fullScreen: settings.fullScreen,
      overlayChat: settings.fullScreenChatOverlay,
      showVideo: settings.showVideo,
      keyboardOpen: MediaQuery.viewInsetsOf(context).bottom > 0,
    );

void _openGuide(SettingsStore settings) =>
    LinkRouter.open(htHelpUrl, launchExternal: settings.launchUrlExternal);

/// The details as a bottom sheet (landscape, or from the pill).
Future<void> showHypeTrainDetails(
  BuildContext context,
  HypeTrainStore store,
  SettingsStore settings,
) => showModalBottomSheetWithProperFocus<void>(
  context: context,
  isScrollControlled: true,
  constraints: const BoxConstraints(maxWidth: 480),
  builder: (context) => SafeArea(
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
);

/// The hype train above chat, under the chat tab bar. It covers only the
/// oldest messages (chat is newest at the bottom).
class HypeTrainChatOverlay extends StatelessWidget {
  const HypeTrainChatOverlay({
    super.key,
    required this.store,
    required this.settingsStore,
    required this.chatTabsStore,
  });

  final HypeTrainStore store;
  final SettingsStore settingsStore;
  final ChatTabsStore chatTabsStore;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final placement = _placement(context, settingsStore);
        if (placement == HtPlacement.none || placement == HtPlacement.pill) {
          return const SizedBox.shrink();
        }
        final compact = placement == HtPlacement.bannerCompact;
        final chatOnly = !settingsStore.showVideo;
        final top =
            (chatOnly ? context.safePaddingTop : 0) +
            (chatTabsStore.showTabBar ? 48 : 0);
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(8, top + 6, 8, 0),
            child: HypeTrainSlot(
              store: store,
              compact: compact,
              onLearnMore: () => _openGuide(settingsStore),
              onOpenDetails: () =>
                  showHypeTrainDetails(context, store, settingsStore),
            ),
          ),
        );
      },
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
        // Where chat would be.
        return settingsStore.landscapeChatLeftSide
            ? Positioned(top: 48, left: 8, child: pill)
            : Positioned(top: 48, right: 8, child: pill);
      },
    );
  }
}
