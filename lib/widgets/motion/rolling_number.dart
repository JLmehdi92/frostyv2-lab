import 'package:flutter/material.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/motion/motion.dart';
import 'package:onset/widgets/motion/reduce_motion.dart';

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
    _up = rollsUp(oldWidget.text, widget.text);
    if (reduceMotionOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
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

/// Whether a count going from [from] to [to] grows, so its digits roll up.
/// Reads compact units (1.2K, 3M) and both grouping styles ("1,000",
/// "1.000", "12 418", "12,4 k"); anything unreadable rolls up.
@visibleForTesting
bool rollsUp(String from, String to) {
  final a = readCount(from);
  final b = readCount(to);
  if (a == null || b == null) return true;
  return b >= a;
}

/// [text] as a count: compact units and both grouping styles read; null
/// when no number is found.
@visibleForTesting
double? readCount(String text) {
  // A unit ends the number ("1.2K", "12,4 k"); a letter after it makes it
  // the start of a word ("5 bits", "3 months"), not a unit.
  final match = RegExp(
    "(-?\\d[\\d.,\\s\u00a0\u202f']*)\\s*((?:[kKmMbB](?![A-Za-z]))?)",
  ).firstMatch(text);
  if (match == null) return null;
  var number = match.group(1)!.replaceAll(RegExp("[\\s\u00a0\u202f']"), '');
  final unit = match.group(2)!.toLowerCase();

  // With both separators, the last one is the decimal point. With one kind,
  // it is a decimal point only if it appears once and is not followed by
  // exactly three digits ("1.000" is a thousand; "1.2K" is not).
  final lastDot = number.lastIndexOf('.');
  final lastComma = number.lastIndexOf(',');
  String? decimal;
  if (lastDot >= 0 && lastComma >= 0) {
    decimal = lastDot > lastComma ? '.' : ',';
  } else if (lastDot >= 0 || lastComma >= 0) {
    final separator = lastDot >= 0 ? '.' : ',';
    final count = separator.allMatches(number).length;
    final after = number.length - number.lastIndexOf(separator) - 1;
    if (count == 1 && (after != 3 || unit.isNotEmpty)) decimal = separator;
  }
  for (final separator in const ['.', ',']) {
    if (separator != decimal) number = number.replaceAll(separator, '');
  }
  if (decimal == ',') number = number.replaceAll(',', '.');

  final value = double.tryParse(number);
  if (value == null) return null;
  return value *
      switch (unit) {
        'k' => 1e3,
        'm' => 1e6,
        'b' => 1e9,
        _ => 1,
      };
}
