import 'package:flutter/widgets.dart';

/// A tablet beside its chat (board Tablette): the video first, at the 16:9
/// size its column's width gives it, and the channel's info area under it
/// only while that leaves the area [minInfoHeight]. Otherwise the video
/// takes the whole column, as before the info area existed: the player
/// letterboxes its picture inside (never stretched), and narrowing the chat
/// makes the video grow again.
///
/// The video is always the first child of the same [Column]: the info area
/// coming and going while the divider is dragged never rebuilds the player.
class TabletVideoColumn extends StatelessWidget {
  const TabletVideoColumn({
    super.key,
    required this.video,
    required this.info,
    this.fill = false,
  });

  /// Below the video, the channel's info area needs at least this much room.
  static const minInfoHeight = 120.0;

  /// The player, with its gestures.
  final Widget video;

  /// The channel's info area.
  final Widget info;

  /// Whether the picture fills its box (the player's fill-screen toggle):
  /// the video then takes the whole column.
  final bool fill;

  /// Whether a column of [size] shows the info area under the video.
  static bool showsInfo(Size size, {bool fill = false}) =>
      !fill && size.height - size.width * 9 / 16 >= minInfoHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final infoShown = showsInfo(size, fill: fill);
        return Column(
          children: [
            SizedBox(
              height: infoShown ? size.width * 9 / 16 : size.height,
              width: double.infinity,
              child: TabletInfoBelow(shown: infoShown, child: video),
            ),
            if (infoShown) Expanded(child: info),
          ],
        );
      },
    );
  }
}

/// Tells the player's controls whether the channel's info area stands
/// under the video beside a tablet's chat (it then has the title).
class TabletInfoBelow extends InheritedWidget {
  const TabletInfoBelow({super.key, required this.shown, required super.child});

  final bool shown;

  /// Null outside a tablet's video column.
  static bool? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TabletInfoBelow>()?.shown;

  @override
  bool updateShouldNotify(TabletInfoBelow oldWidget) =>
      shown != oldWidget.shown;
}
