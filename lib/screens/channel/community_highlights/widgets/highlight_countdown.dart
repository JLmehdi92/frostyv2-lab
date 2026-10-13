import 'dart:async';

import 'package:flutter/widgets.dart';

/// "1:05" style time left.
String formatTimeLeft(Duration left) {
  final seconds = left.isNegative ? 0 : left.inSeconds;
  final minutes = seconds ~/ 60;
  final rest = (seconds % 60).toString().padLeft(2, '0');
  if (minutes < 60) return '$minutes:$rest';
  final hours = minutes ~/ 60;
  return '$hours:${(minutes % 60).toString().padLeft(2, '0')}:$rest';
}

/// Rebuilds [builder] every second with the time left until [deadline]
/// (Twitch time, from [now]); the ticking stays inside this widget.
class HighlightCountdown extends StatefulWidget {
  const HighlightCountdown({
    super.key,
    required this.deadline,
    required this.now,
    required this.builder,
  });

  final DateTime deadline;
  final DateTime Function() now;
  final Widget Function(BuildContext context, Duration left) builder;

  @override
  State<HighlightCountdown> createState() => _HighlightCountdownState();
}

class _HighlightCountdownState extends State<HighlightCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
      if (!widget.deadline.isAfter(widget.now())) _timer?.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.deadline.difference(widget.now());
    // Not announced every second; the card's label reads the time left.
    return ExcludeSemantics(
      child: widget.builder(context, left.isNegative ? Duration.zero : left),
    );
  }
}
