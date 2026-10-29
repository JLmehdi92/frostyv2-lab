import 'package:flutter/material.dart';

/// The colour square of the accent pickers (onboarding's Setup, Settings ›
/// General): saturation across, brightness down, for the hue.
class AccentSaturationValue extends StatelessWidget {
  const AccentSaturationValue({
    super.key,
    required this.hsv,
    required this.onChanged,
    this.height = 168,
    this.radius = 8,
  });

  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = this.height;
        void pick(Offset position) => onChanged(
          hsv
              .withSaturation((position.dx / width).clamp(0.0, 1.0))
              .withValue(1 - (position.dy / height).clamp(0.0, 1.0)),
        );
        return Semantics(
          label: 'Saturation and brightness',
          value:
              '${(hsv.saturation * 100).round()} %, '
              '${(hsv.value * 100).round()} %',
          // Picks on touch, then follows the finger: drags along either axis
          // win over a scrolling sheet around it (the square is hit first),
          // and each one reads both coordinates.
          child: Listener(
            onPointerDown: (event) => pick(event.localPosition),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: (details) => pick(details.localPosition),
              onHorizontalDragUpdate: (details) => pick(details.localPosition),
              child: SizedBox(
                height: height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(radius),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white,
                              HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor(),
                            ],
                          ),
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(radius),
                            gradient: const LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Colors.black, Color(0x00000000)],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: hsv.saturation * width - 10,
                      top: (1 - hsv.value) * height - 10,
                      child: AccentPickerThumb(color: hsv.toColor()),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The hue slider of the accent pickers: a rainbow track in a 44 dp target,
/// with eight named hues for a screen reader.
class AccentHueSlider extends StatelessWidget {
  const AccentHueSlider({
    super.key,
    required this.hue,
    required this.onChanged,
    this.trackHeight = 12,
  });

  /// The hues the slider's eight segments name for a screen reader.
  static const namedHues = [22, 67, 112, 157, 202, 247, 292, 337];

  final double hue;
  final ValueChanged<double> onChanged;
  final double trackHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        void pick(Offset position) =>
            onChanged((position.dx / width).clamp(0.0, 1.0) * 360);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => pick(details.localPosition),
          onHorizontalDragStart: (details) => pick(details.localPosition),
          onHorizontalDragUpdate: (details) => pick(details.localPosition),
          child: SizedBox(
            height: 44,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: (44 - trackHeight) / 2,
                  height: trackHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(trackHeight / 2),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFF0000),
                          Color(0xFFFFFF00),
                          Color(0xFF00FF00),
                          Color(0xFF00FFFF),
                          Color(0xFF0000FF),
                          Color(0xFFFF00FF),
                          Color(0xFFFF0000),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: hue / 360 * width - 10,
                  top: 12,
                  child: AccentPickerThumb(
                    color: HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
                  ),
                ),
                // Eight named hues for a screen reader (a tap lands on the
                // same hue through the slider itself).
                Positioned.fill(
                  child: Row(
                    children: [
                      for (final named in namedHues)
                        Expanded(
                          child: Semantics(
                            button: true,
                            label: 'Hue $named degrees',
                            onTap: () => onChanged(named.toDouble()),
                            child: const SizedBox.expand(),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The white-ringed thumb of the colour square and the hue slider.
class AccentPickerThumb extends StatelessWidget {
  const AccentPickerThumb({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x80000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}
