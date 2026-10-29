import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/screens/channel/video/player_controller.dart';
import 'package:onset/screens/channel/video/stores/ivs_video_store.dart';
import 'package:onset/theme.dart';

/// The latency text of the pill, or the reconnect progress while the IVS
/// engine is recovering from an error ("↻ 2/5").
String playerLatencyLabel(PlayerController store) => switch (store) {
  IvsVideoStore(status: IvsPlaybackStatus.reconnecting) =>
    '↻ ${store.retryAttempt}/${store.maxRetryAttempts}',
  _ => store.latency ?? '—',
};

/// The latency to the broadcaster, in a pill over the top-right corner of
/// the video (boards Chaine, ChaineLecteur, Tablette, TablettePortrait).
///
/// It stays where it is whether the player's controls show or not, so the
/// latency can always be read on a real device (a project rule); a tap
/// opens the IVS video stats, a long press says what it measures.
class LatencyPill extends StatelessWidget {
  const LatencyPill({super.key, required this.store, this.large = false});

  final PlayerController store;

  /// The tablet size (28 high instead of 26).
  final bool large;

  static const tooltipIvs = 'Latency to broadcaster · tap for video stats';
  static const tooltipOther = 'Latency to broadcaster';

  static final _label = FrostyType.tabular(
    const TextStyle(
      fontFamily: FrostyTokens.bodyFamily,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1,
      color: FrostyTokens.textPrimaryDark,
    ),
  );

  /// The widest the pill gets ("188.8s", "↻ 9/9"), so the controls' top row
  /// can keep its place without drawing a second pill.
  static double slotWidth(BuildContext context, {bool large = false}) {
    final scaler = MediaQuery.textScalerOf(context);
    double measure(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: _label),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final text = math.max(measure('188.8s'), measure('↻ 9/9'));
    // Padding, the dot and its gap, the hairline.
    return (large ? 10 : 9) * 2 + 6 + 6 + text + 1;
  }

  @override
  Widget build(BuildContext context) {
    final store = this.store;
    final ivs = store is IvsVideoStore ? store : null;
    final height = large ? 28.0 : 26.0;
    // Its own layer: it changes every second, the video under it must not
    // repaint for that.
    return RepaintBoundary(
      child: Tooltip(
        message: ivs != null ? tooltipIvs : tooltipOther,
        preferBelow: true,
        triggerMode: ivs != null
            ? TooltipTriggerMode.longPress
            : TooltipTriggerMode.tap,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: ivs?.toggleStats,
          child: Observer(
            builder: (context) {
              final label = playerLatencyLabel(store);
              return Semantics(
                button: ivs != null,
                label: 'Latency $label',
                excludeSemantics: true,
                child: Container(
                  height: height,
                  padding: EdgeInsets.symmetric(horizontal: large ? 10 : 9),
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(0, 0, 0, large ? 0.55 : 0.5),
                    borderRadius: BorderRadius.circular(height / 2),
                    border: Border.all(
                      color: Color.fromRGBO(255, 255, 255, large ? 0.16 : 0.14),
                      width: FrostyTokens.hairlineWidth,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 6,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: FrostyTokens.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(label, maxLines: 1, style: _label),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
