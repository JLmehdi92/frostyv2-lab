import 'package:flutter/material.dart';
import 'package:frosty/models/hype_train.dart';
import 'package:frosty/widgets/frosty_cached_network_image.dart';

/// One line of text and emotes sliding from the trailing edge out past the
/// leading edge over [duration] (mirrored right to left). Centred and still
/// with [reduceMotion].
class HypeTrainMarquee extends StatefulWidget {
  const HypeTrainMarquee({
    super.key,
    required this.text,
    required this.duration,
    this.emotes = const [],
    this.style,
    this.reduceMotion = false,
  });

  final String text;
  final List<HtReward> emotes;
  final Duration duration;
  final TextStyle? style;
  final bool reduceMotion;

  @override
  State<HypeTrainMarquee> createState() => _HypeTrainMarqueeState();
}

class _HypeTrainMarqueeState extends State<HypeTrainMarquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (!widget.reduceMotion && widget.duration > Duration.zero) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Unconstrained: the line may be wider than the banner.
  Widget _content() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(widget.text, maxLines: 1, softWrap: false, style: widget.style),
      for (final emote in widget.emotes.take(6))
        if (emote.emoteUrl case final url?)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4),
            child: FrostyCachedNetworkImage(
              imageUrl: url.toString(),
              width: 20,
              height: 20,
              useFade: false,
            ),
          ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    // A fixed line height: the sliding content is laid out unconstrained.
    final height = MediaQuery.textScalerOf(context).scale(14) * 1.6 + 4;
    return SizedBox(height: height < 24 ? 24 : height, child: _line(context));
  }

  Widget _line(BuildContext context) {
    if (widget.reduceMotion) {
      return ClipRect(
        child: FittedBox(fit: BoxFit.scaleDown, child: _content()),
      );
    }
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              // From the trailing edge to past the leading edge.
              final x = width * (1 - 2 * _controller.value);
              return Transform.translate(
                key: const ValueKey('ht-marquee'),
                offset: Offset(rtl ? -x : x, 0),
                child: child,
              );
            },
            child: OverflowBox(
              alignment: AlignmentDirectional.centerStart,
              maxWidth: double.infinity,
              child: _content(),
            ),
          ),
        );
      },
    );
  }
}
