import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shows a modal bottom sheet that properly handles focus restoration.
///
/// This prevents Flutter from automatically restoring focus to text fields
/// after the sheet is dismissed by clearing the focus scope before opening.
///
/// Under a [SheetsUnderVideo] (the phone channel screen) the sheet starts
/// below the video and leaves it undimmed, so the live picture and its
/// latency stay in view.
Future<T?> showModalBottomSheetWithProperFocus<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useRootNavigator = false,
  bool isDismissible = true,
  bool enableDrag = true,
  Color? backgroundColor,
  double? elevation,
  ShapeBorder? shape,
  Clip? clipBehavior,
  BoxConstraints? constraints,
  Color? barrierColor,
  String? barrierLabel,
  AnimationController? transitionAnimationController,
  Offset? anchorPoint,
}) {
  final videoBottom = SheetsUnderVideo.of(context);

  // Clear focus and its history so it can't be auto-restored
  FocusScope.of(context).unfocus();

  final Future<T?> shown;
  if (videoBottom == null) {
    shown = showModalBottomSheet<T>(
      context: context,
      builder: builder,
      isScrollControlled: isScrollControlled,
      useRootNavigator: useRootNavigator,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: backgroundColor,
      elevation: elevation,
      shape: shape,
      clipBehavior: clipBehavior,
      constraints: constraints,
      barrierColor: barrierColor,
      barrierLabel: barrierLabel,
      transitionAnimationController: transitionAnimationController,
      anchorPoint: anchorPoint,
    );
  } else {
    final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
    final localizations = MaterialLocalizations.of(context);
    final theme = Theme.of(context);
    shown = navigator.push(
      _UnderVideoSheetRoute<T>(
        videoBottom: videoBottom,
        builder: (context) => SheetsUnderVideo(
          // A sheet opened from this one starts under the video too.
          top: videoBottom,
          child: _UnderVideo(
            videoBottom: videoBottom,
            child: Builder(builder: builder),
          ),
        ),
        capturedThemes: InheritedTheme.capture(
          from: context,
          to: navigator.context,
        ),
        isScrollControlled: isScrollControlled,
        barrierLabel: barrierLabel ?? localizations.scrimLabel,
        barrierOnTapHint: localizations.scrimOnTapHint(
          localizations.bottomSheetLabel,
        ),
        backgroundColor: backgroundColor,
        elevation: elevation,
        shape: shape,
        clipBehavior: clipBehavior,
        constraints: constraints,
        isDismissible: isDismissible,
        modalBarrierColor:
            barrierColor ?? theme.bottomSheetTheme.modalBarrierColor,
        enableDrag: enableDrag,
        transitionAnimationController: transitionAnimationController,
        anchorPoint: anchorPoint,
      ),
    );
  }

  return shown.whenComplete(() {
    // Additional safety: clear any focus that might have been restored
    if (context.mounted) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  });
}

/// Makes the sheets opened below it start under the video (approved
/// addition to the board ChaineLecteur): the phone channel screen puts it
/// around its portrait layout with the video's bottom edge.
class SheetsUnderVideo extends InheritedWidget {
  const SheetsUnderVideo({super.key, required this.top, required super.child});

  /// The video's bottom edge, from the top of the screen; null when sheets
  /// open as usual (no video, landscape, a tablet).
  final double? top;

  /// Between the video and the sheet's top edge (the boards' 12 dp).
  static const gap = 12.0;

  /// The video's bottom edge, when sheets should start under it. Read once
  /// when a sheet opens: no dependency, nothing rebuilds when it moves.
  static double? of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SheetsUnderVideo>()?.top;

  @override
  bool updateShouldNotify(SheetsUnderVideo oldWidget) => oldWidget.top != top;
}

/// Keeps a sheet's top edge [SheetsUnderVideo.gap] under the video. While
/// the keyboard is up the sheet may grow by its height: a sheet that makes
/// room for the keyboard keeps the space it had (the video is then partly
/// covered while typing, as every sheet did before).
class _UnderVideo extends StatelessWidget {
  const _UnderVideo({required this.videoBottom, required this.child});

  final double videoBottom;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final room =
        MediaQuery.sizeOf(context).height -
        videoBottom -
        SheetsUnderVideo.gap +
        MediaQuery.viewInsetsOf(context).bottom;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: math.max(0.0, room)),
      child: child,
    );
  }
}

/// A modal bottom sheet whose scrim stops at the video: the picture stays
/// as it is (no scrim, no blur over the video), a tap on it still closes
/// the sheet.
class _UnderVideoSheetRoute<T> extends ModalBottomSheetRoute<T> {
  _UnderVideoSheetRoute({
    required this.videoBottom,
    required super.builder,
    super.capturedThemes,
    super.barrierLabel,
    super.barrierOnTapHint,
    super.backgroundColor,
    super.elevation,
    super.shape,
    super.clipBehavior,
    super.constraints,
    super.modalBarrierColor,
    super.isDismissible,
    super.enableDrag,
    required super.isScrollControlled,
    super.transitionAnimationController,
    super.anchorPoint,
  });

  final double videoBottom;

  @override
  Widget buildModalBarrier() {
    final scrim = super.buildModalBarrier();
    return Stack(
      children: [
        Positioned.fill(
          child: ModalBarrier(
            dismissible: barrierDismissible,
            // The scrim below is the one screen readers are told about.
            barrierSemanticsDismissible: false,
          ),
        ),
        Positioned(
          top: videoBottom,
          left: 0,
          right: 0,
          bottom: 0,
          child: scrim,
        ),
      ],
    );
  }
}
