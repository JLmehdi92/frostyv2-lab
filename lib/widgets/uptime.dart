import 'package:flutter/material.dart';
import 'package:onset/services/shared_timer_service.dart';
import 'package:onset/utils/context_extensions.dart';

/// A widget that displays a timer representing the time since the given start time.
/// Uses a shared timer service to keep all uptime displays synchronized.
class Uptime extends StatefulWidget {
  final String startTime;
  final TextStyle? style;

  /// How to handle text that does not fit (null = default clipping).
  final TextOverflow? overflow;

  const Uptime({super.key, required this.startTime, this.style, this.overflow});

  @override
  State<Uptime> createState() => _UptimeState();
}

class _UptimeState extends State<Uptime> {
  late final SharedTimerService _timerService;

  @override
  void initState() {
    super.initState();
    _timerService = SharedTimerService.instance;
    _timerService.addListener(_onTick);
  }

  void _onTick() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = DateTime.tryParse(widget.startTime);
    if (start == null) return const SizedBox.shrink();
    return Text(
      _timerService.currentTime.difference(start).toString().split('.')[0],
      // The duration ticks every second: without fixed-width figures the
      // digits dance, so tabular figures are the default for every caller.
      style: context.onsetText.metadata.merge(widget.style).copyWith(
        fontFeatures: [const FontFeature.tabularFigures()],
      ),
      maxLines: widget.overflow == null ? null : 1,
      overflow: widget.overflow,
    );
  }

  @override
  void dispose() {
    _timerService.removeListener(_onTick);
    super.dispose();
  }
}
