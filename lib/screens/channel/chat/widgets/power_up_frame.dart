import 'package:flutter/material.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';

List<Color> powerUpColors(String? animationId) => switch (animationId) {
  'simmer' => const [Color(0xFFFF6B3D), Color(0xFFFFC23D), Color(0xFFFF3D7F)],
  'rainbow-eclipse' => const [
    Color(0xFFFF4D4D),
    Color(0xFFFFD84D),
    Color(0xFF4DFF88),
    Color(0xFF4DB8FF),
    Color(0xFFB04DFF),
  ],
  'cosmic-abyss' => const [
    Color(0xFF3D5BFF),
    Color(0xFF9B3DFF),
    Color(0xFF3DE0FF),
  ],
  _ => const [OnsetTokens.accent, Color(0xFF3DE0FF)],
};

class PowerUpMessageFrame extends StatefulWidget {
  const PowerUpMessageFrame({
    super.key,
    required this.animationId,
    required this.child,
  });

  final String? animationId;
  final Widget child;

  static const period = Duration(seconds: 3);

  static const loops = 4;

  @override
  State<PowerUpMessageFrame> createState() => _PowerUpMessageFrameState();
}

class _PowerUpMessageFrameState extends State<PowerUpMessageFrame>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: PowerUpMessageFrame.period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotionOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.repeat(count: PowerUpMessageFrame.loops);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = powerUpColors(widget.animationId);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final shift = _controller.value * 2;
        final gradient = LinearGradient(
          begin: Alignment(-1 - shift, -1),
          end: Alignment(1 - shift, 1),
          colors: [...colors, colors.first],
          tileMode: TileMode.repeated,
        );
        return CustomPaint(
          painter: _FramePainter(gradient: gradient),
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.only(left: 8, right: 12),
        margin: const EdgeInsets.only(left: 4),
        color: colors.first.withValues(alpha: 0.1),
        child: widget.child,
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  const _FramePainter({required this.gradient});

  final Gradient gradient;

  @override
  void paint(Canvas canvas, Size size) {
    final bar = Rect.fromLTWH(0, 0, 4, size.height);
    canvas.drawRect(
      bar,
      Paint()..shader = gradient.createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.gradient != gradient;
}
