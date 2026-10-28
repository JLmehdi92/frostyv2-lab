import 'package:flutter/material.dart';
import 'package:frosty/theme.dart';
import 'package:frosty/widgets/motion/motion.dart';
import 'package:frosty/widgets/motion/reduce_motion.dart';

/// A number that rolls to its new value instead of jumping (viewer counts,
/// channel points, a hype train level): the "Compteurs" card of the
/// micro-animation board.
///
/// [text] is the formatted number ("12 418", "1,000", "12.4K"). The two
/// values are lined up from the right, and only the places that changed
/// roll — up when the number grows, down when it falls — clipped to the line.
/// Figures are tabular, so the width does not dance while it rolls.
///
/// Screen readers get the whole number once. Reduce motion: the new value at
/// once.
class RollingNumber extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration duration;

  const RollingNumber(
    this.text, {
    super.key,
    this.style,
    this.duration = const Duration(milliseconds: 450),
  });

  @override
  State<RollingNumber> createState() => _RollingNumberState();
}

class _RollingNumberState extends State<RollingNumber>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
  );
  late final _roll = CurvedAnimation(
    parent: _controller,
    curve: FrostyMotion.standard,
  );

  String _from = '';
  bool _up = true;

  @override
  void didUpdateWidget(RollingNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    if (oldWidget.text == widget.text) return;
    _from = oldWidget.text;
    _up = _grows(oldWidget.text, widget.text);
    if (reduceMotionOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  /// Whether going from [from] to [to] is an increase. Separators and units
  /// are ignored; anything unreadable rolls up.
  static bool _grows(String from, String to) {
    num? read(String s) => num.tryParse(s.replaceAll(RegExp(r'[^0-9.\-]'), ''));
    final a = read(from);
    final b = read(to);
    if (a == null || b == null) return true;
    return b >= a;
  }

  @override
  void dispose() {
    _roll.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = FrostyType.tabular(
      DefaultTextStyle.of(context).style.merge(widget.style),
    );

    return Semantics(
      label: widget.text,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final now = widget.text.split('');
          final rolling = _controller.isAnimating;
          final before = rolling ? _from.split('') : now;
          final length = now.length > before.length
              ? now.length
              : before.length;
          String at(List<String> chars, int i) {
            final j = i - (length - chars.length);
            return j < 0 ? '' : chars[j];
          }

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < length; i++)
                if (at(now, i).isNotEmpty)
                  if (rolling && at(before, i) != at(now, i))
                    _RollingPlace(
                      from: at(before, i),
                      to: at(now, i),
                      up: _up,
                      progress: _roll.value,
                      style: style,
                    )
                  else
                    Text(at(now, i), style: style, softWrap: false),
            ],
          );
        },
      ),
    );
  }
}

/// One place of the number while it rolls: the old character leaves, the
/// new one arrives, both clipped to the line. The new character sizes it.
class _RollingPlace extends StatelessWidget {
  final String from;
  final String to;
  final bool up;
  final double progress;
  final TextStyle style;

  const _RollingPlace({
    required this.from,
    required this.to,
    required this.up,
    required this.progress,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final direction = up ? 1.0 : -1.0;
    return ClipRect(
      child: Stack(
        alignment: Alignment.center,
        children: [
          FractionalTranslation(
            translation: Offset(0, direction * (1 - progress)),
            child: Text(to, style: style, softWrap: false),
          ),
          if (from.isNotEmpty)
            Positioned.fill(
              child: OverflowBox(
                maxWidth: double.infinity,
                child: FractionalTranslation(
                  translation: Offset(0, -direction * progress),
                  child: Text(from, style: style, softWrap: false),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
