import 'package:flutter/material.dart';
import 'package:frosty/widgets/motion/signal_ping.dart';

/// The live dot shown next to a live channel: the design system's
/// [SignalPing] in the theme's live colour (the one place the accent is
/// allowed to appear).
class LiveIndicator extends StatelessWidget {
  /// The size of the indicator dot.
  final double size;

  /// The color of the indicator. Defaults to the theme's live colour.
  final Color? color;

  const LiveIndicator({super.key, this.size = 8, this.color});

  @override
  Widget build(BuildContext context) => SignalPing(size: size, color: color);
}
