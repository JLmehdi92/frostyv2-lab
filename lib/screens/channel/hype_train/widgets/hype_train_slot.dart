import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/screens/channel/hype_train/hype_train_timings.dart';
import 'package:frosty/screens/channel/hype_train/stores/hype_train_store.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_approaching_banner.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_banner.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_end_strip.dart';
import 'package:frosty/screens/channel/hype_train/widgets/hype_train_sheet.dart';
import 'package:frosty/utils/link_router.dart';
import 'package:mobx/mobx.dart';

/// Where the hype train lives on screen: nothing when there is no train,
/// else the approaching banner, the banner (or its pill) or the end strip.
/// While mounted it is the store's presenter.
class HypeTrainSlot extends StatefulWidget {
  const HypeTrainSlot({
    super.key,
    required this.store,
    this.compact = false,
    this.onLearnMore,
    this.onOpenDetails,
  });

  final HypeTrainStore store;

  /// Opens the hype train guide; defaults to the in-app browser.
  final VoidCallback? onLearnMore;

  /// Compact: the details open here (a sheet) instead of below.
  final VoidCallback? onOpenDetails;

  /// Landscape: a one-line banner and short sequences.
  final bool compact;

  @override
  State<HypeTrainSlot> createState() => _HypeTrainSlotState();
}

class _HypeTrainSlotState extends State<HypeTrainSlot> {
  late ReactionDisposer _collapsedReaction;
  var _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    widget.store.attachPresenter();
    _collapsedReaction = reaction(
      (_) => widget.store.collapsed,
      (_) => _updatePresentation(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _updatePresentation();
  }

  @override
  void didUpdateWidget(HypeTrainSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.detachPresenter();
      widget.store.attachPresenter();
    }
    _updatePresentation();
  }

  void _updatePresentation() => widget.store.updatePresentation(
    compact: widget.compact || widget.store.collapsed,
    reduceMotion: _reduceMotion,
  );

  @override
  void dispose() {
    _collapsedReaction();
    widget.store.detachPresenter();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return AnimatedSize(
      duration: HtTimings.short,
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: Observer(
        builder: (context) {
          final openHere = widget.compact ? widget.onOpenDetails : null;
          final Widget child;
          final String key;
          switch (store.phase) {
            case HtPhase.hidden:
              return const SizedBox(width: double.infinity, height: 0);
            case HtPhase.approaching:
              key = 'approaching';
              child = HypeTrainApproachingBanner(store: store, onTap: openHere);
            case HtPhase.ongoing || HtPhase.ending:
              key = store.collapsed ? 'pill' : 'banner';
              child = store.collapsed
                  ? HypeTrainPill(store: store)
                  : HypeTrainBanner(
                      store: store,
                      compact: widget.compact,
                      onTap: openHere,
                    );
            case HtPhase.rewards || HtPhase.expired:
              key = 'strip';
              child = HypeTrainEndStrip(store: store);
          }
          final switcher = AnimatedSwitcher(
            duration: HtTimings.short,
            child: KeyedSubtree(key: ValueKey('ht-slot-$key'), child: child),
          );
          if (!store.expanded || widget.compact || store.collapsed) {
            return switcher;
          }
          // The details open below the banner, over the oldest messages.
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              switcher,
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                ),
                child: Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    child: HypeTrainSheet(
                      store: store,
                      onLearnMore:
                          widget.onLearnMore ??
                          () =>
                              LinkRouter.open(htHelpUrl, launchExternal: false),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
