import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// A [BackdropFilter] that only blurs while its page is in place.
///
/// While the page's route is pushed or popped, the page below shows through
/// (the Live feed's muted preview, a channel's video): nothing may blur over
/// a video Texture, so the filter is off until the push has finished and
/// from the moment the pop starts. [child] is drawn either way.
class SettledBlur extends StatefulWidget {
  const SettledBlur({
    super.key,
    required this.filter,
    required this.child,
    this.enabled = true,
  });

  final ui.ImageFilter filter;
  final Widget child;

  /// Off: never blurs (a layout without glass).
  final bool enabled;

  @override
  State<SettledBlur> createState() => _SettledBlurState();
}

class _SettledBlurState extends State<SettledBlur> {
  Animation<double>? _animation;
  var _settled = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (animation == _animation) return;
    _animation?.removeStatusListener(_onStatus);
    _animation = animation?..addStatusListener(_onStatus);
    _settled = _isSettled(animation?.status);
  }

  static bool _isSettled(AnimationStatus? status) =>
      status == null || status == AnimationStatus.completed;

  void _onStatus(AnimationStatus status) {
    final settled = _isSettled(status);
    if (settled != _settled && mounted) setState(() => _settled = settled);
  }

  @override
  void dispose() {
    _animation?.removeStatusListener(_onStatus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BackdropFilter(
    enabled: widget.enabled && _settled,
    filter: widget.filter,
    child: widget.child,
  );
}
