import 'package:flutter/material.dart';
import 'package:onset/models/hype_train.dart';
import 'package:onset/screens/channel/hype_train/widgets/hype_train_tokens.dart';
import 'package:onset/widgets/onset_cached_network_image.dart';

/// Twitch's scrolling announcement: one line of text and emotes starting
/// just past the trailing edge and travelling linearly over [duration]
/// until it is [HtDims.marqueeGap] past the leading edge (mirrored right to
/// left). Centred and still with [reduceMotion].
class HypeTrainMarquee extends StatefulWidget {
  const HypeTrainMarquee({
    super.key,
    required this.text,
    required this.duration,
    this.emotes = const [],
    this.style,
    this.emoteSize = HtDims.icon,
    this.reduceMotion = false,
  });

  final String text;
  final List<HtReward> emotes;
  final Duration duration;
  final TextStyle? style;

  /// 24 dp, 20 dp in the compact banner.
  final double emoteSize;
  final bool reduceMotion;

  /// Space before each emote.
  static const _emoteGap = 4.0;

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

  List<HtReward> get _emotes => [
    for (final emote in widget.emotes.take(6))
      if (emote.emoteUrl != null) emote,
  ];

  /// Unconstrained: the line may be wider than the banner.
  Widget _content() => Row(
    key: const ValueKey('ht-marquee-content'),
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(widget.text, maxLines: 1, softWrap: false, style: widget.style),
      for (final emote in _emotes)
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: HypeTrainMarquee._emoteGap,
          ),
          child: OnsetCachedNetworkImage(
            imageUrl: emote.emoteUrl.toString(),
            width: widget.emoteSize,
            height: widget.emoteSize,
            useFade: false,
          ),
        ),
    ],
  );

  /// The width [_content] lays out to.
  double _contentWidth(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(
        text: widget.text,
        style: DefaultTextStyle.of(context).style.merge(widget.style),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width +
        _emotes.length * (HypeTrainMarquee._emoteGap + widget.emoteSize);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reduceMotion) {
      return ClipRect(
        child: Center(
          child: FittedBox(fit: BoxFit.scaleDown, child: _content()),
        ),
      );
    }
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final travel = width + _contentWidth(context) + HtDims.marqueeGap;
        return ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final x = width - travel * _controller.value;
              return Transform.translate(
                key: const ValueKey('ht-marquee'),
                offset: Offset(rtl ? -x : x, 0),
                child: child,
              );
            },
            child: OverflowBox(
              alignment: AlignmentDirectional.centerStart,
              minWidth: 0,
              maxWidth: double.infinity,
              child: _content(),
            ),
          ),
        );
      },
    );
  }
}
