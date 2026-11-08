import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/vod.dart';
import 'package:onset/models/vod_chapter.dart';
import 'package:onset/screens/vod/vod_time.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';

/// Seek bar of the VOD player: played and buffered parts, copyright-muted
/// parts as ticks above the track, a time bubble while scrubbing. Seeks
/// once, when the finger lifts (or on a tap).
class VodSeekBar extends StatefulWidget {
  const VodSeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.buffered,
    required this.onSeek,
    this.mutedSegments = const [],
    this.chapters = const [],
    this.onScrubbing,
  });

  final List<VodChapter> chapters;

  final Duration position;
  final Duration duration;
  final Duration buffered;
  final List<MutedSegment> mutedSegments;
  final ValueChanged<Duration> onSeek;

  /// True when a drag starts, false when it ends (keeps controls visible).
  final ValueChanged<bool>? onScrubbing;

  @override
  State<VodSeekBar> createState() => _VodSeekBarState();
}

class _VodSeekBarState extends State<VodSeekBar> {
  /// Fraction under the finger while dragging.
  double? _drag;

  bool get _enabled => widget.duration > Duration.zero;

  double _fractionOf(Duration d) {
    if (!_enabled) return 0;
    return (d.inMilliseconds / widget.duration.inMilliseconds).clamp(0.0, 1.0);
  }

  Duration _timeAt(double fraction) => Duration(
    milliseconds: (widget.duration.inMilliseconds * fraction.clamp(0.0, 1.0))
        .round(),
  );

  double _fractionAtX(double x, double width) =>
      width <= 0 ? 0 : (x / width).clamp(0.0, 1.0);

  static const _semanticStep = Duration(seconds: 10);

  double get _bubbleWidth => widget.chapters.isEmpty ? 64 : 160;

  Duration _stepped(Duration delta) {
    final target = widget.position + delta;
    if (target < Duration.zero) return Duration.zero;
    if (target > widget.duration) return widget.duration;
    return target;
  }

  String _valueAt(Duration at) {
    final value = context.l10n.vodSeekValue(
      position: formatVodTime(at),
      duration: formatVodTime(widget.duration),
    );
    final chapter = chapterAt(widget.chapters, at);
    if (chapter == null) return value;
    return context.l10n.vodSeekValueChapter(
      value: value,
      chapter: chapter.title,
    );
  }

  @override
  Widget build(BuildContext context) {
    final drag = _drag;
    final played = drag ?? _fractionOf(widget.position);
    final muted = [
      if (_enabled)
        for (final segment in widget.mutedSegments)
          (
            _fractionOf(Duration(seconds: segment.offset)),
            _fractionOf(Duration(seconds: segment.offset + segment.duration)),
          ),
    ];

    return Semantics(
      label: context.l10n.vodSeek,
      value: _valueAt(widget.position),
      increasedValue: _valueAt(_stepped(_semanticStep)),
      decreasedValue: _valueAt(_stepped(-_semanticStep)),
      slider: true,
      onIncrease: _enabled
          ? () => widget.onSeek(_stepped(_semanticStep))
          : null,
      onDecrease: _enabled
          ? () => widget.onSeek(_stepped(-_semanticStep))
          : null,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: _enabled
                ? (d) => widget.onSeek(
                    _timeAt(_fractionAtX(d.localPosition.dx, width)),
                  )
                : null,
            onHorizontalDragStart: _enabled
                ? (d) {
                    setState(
                      () => _drag = _fractionAtX(d.localPosition.dx, width),
                    );
                    widget.onScrubbing?.call(true);
                  }
                : null,
            onHorizontalDragUpdate: _enabled
                ? (d) => setState(
                    () => _drag = _fractionAtX(d.localPosition.dx, width),
                  )
                : null,
            onHorizontalDragEnd: _enabled
                ? (_) {
                    final fraction = _drag;
                    setState(() => _drag = null);
                    widget.onScrubbing?.call(false);
                    if (fraction != null) widget.onSeek(_timeAt(fraction));
                  }
                : null,
            onHorizontalDragCancel: _enabled
                ? () {
                    setState(() => _drag = null);
                    widget.onScrubbing?.call(false);
                  }
                : null,
            child: SizedBox(
              height: 40,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: VodSeekBarPainter(
                        played: played,
                        buffered: _fractionOf(widget.buffered),
                        mutedRanges: muted,
                        chapterStarts: [
                          if (_enabled)
                            for (final chapter in widget.chapters)
                              if (chapter.start > Duration.zero)
                                _fractionOf(chapter.start),
                        ],
                        enabled: _enabled,
                        dragging: drag != null,
                        // The signal for what was played,
                        // white 22 % / 38 % for the track and the buffer,
                        // the muted parts as light ticks above.
                        playedColor: context.onsetColors.live,
                        trackColor: Colors.white.withValues(alpha: 0.22),
                        bufferedColor: Colors.white.withValues(alpha: 0.38),
                        mutedColor: OnsetTokens.textBodyDark,
                      ),
                    ),
                  ),
                  if (drag != null)
                    Positioned(
                      bottom: 30,
                      left: (drag * width - _bubbleWidth / 2).clamp(
                        0.0,
                        (width - _bubbleWidth).clamp(0.0, double.infinity),
                      ),
                      width: _bubbleWidth,
                      child: _TimeBubble(
                        text: formatVodTime(_timeAt(drag)),
                        chapter: chapterAt(
                          widget.chapters,
                          _timeAt(drag),
                        )?.title,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TimeBubble extends StatelessWidget {
  const _TimeBubble({required this.text, this.chapter});

  final String text;
  final String? chapter;

  @override
  Widget build(BuildContext context) => Center(
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (chapter case final chapter?)
              Text(
                chapter,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: OnsetTokens.textBodyDark,
                  fontSize: 12,
                ),
              ),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Paints the seek bar track. Fractions are of the video length.
class VodSeekBarPainter extends CustomPainter {
  const VodSeekBarPainter({
    required this.played,
    required this.buffered,
    required this.mutedRanges,
    this.chapterStarts = const [],
    required this.enabled,
    required this.dragging,
    required this.playedColor,
    required this.trackColor,
    required this.bufferedColor,
    required this.mutedColor,
  });

  final double played;
  final double buffered;

  /// Copyright-muted parts as (start, end) fractions.
  final List<(double, double)> mutedRanges;
  final List<double> chapterStarts;
  final bool enabled;
  final bool dragging;
  final Color playedColor;
  final Color trackColor;
  final Color bufferedColor;
  final Color mutedColor;

  static const _trackHeight = 3.0;

  static const chapterGapColor = Color(0xCC000000);

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final width = size.width;
    RRect bar(double from, double to, [double height = _trackHeight]) =>
        RRect.fromLTRBR(
          from * width,
          y - height / 2,
          to * width,
          y + height / 2,
          Radius.circular(height / 2),
        );

    canvas.drawRRect(bar(0, 1), Paint()..color = trackColor);
    if (!enabled) return;
    canvas.drawRRect(bar(0, buffered), Paint()..color = bufferedColor);
    canvas.drawRRect(bar(0, played), Paint()..color = playedColor);
    final gap = Paint()..color = chapterGapColor;
    for (final start in chapterStarts) {
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(start * width, y),
          width: 2,
          height: _trackHeight + 2,
        ),
        gap,
      );
    }
    final mutedPaint = Paint()..color = mutedColor;
    for (final (start, end) in mutedRanges) {
      // 2 px tall, 3 px above the track.
      canvas.drawRRect(
        RRect.fromLTRBR(
          start * width,
          y - _trackHeight / 2 - 5,
          (end * width).clamp(start * width + 2, width),
          y - _trackHeight / 2 - 3,
          const Radius.circular(1),
        ),
        mutedPaint,
      );
    }
    final knob = Offset(played * width, y);
    final radius = dragging ? 8.0 : 6.0;
    // The knob's 3 px dark ring, so it reads over a bright picture.
    canvas
      ..drawCircle(knob, radius + 3, Paint()..color = const Color(0x40000000))
      ..drawCircle(knob, radius, Paint()..color = playedColor);
  }

  @override
  bool shouldRepaint(VodSeekBarPainter old) =>
      old.played != played ||
      old.buffered != buffered ||
      old.enabled != enabled ||
      old.dragging != dragging ||
      old.playedColor != playedColor ||
      old.trackColor != trackColor ||
      old.bufferedColor != bufferedColor ||
      old.mutedColor != mutedColor ||
      !listEquals(old.mutedRanges, mutedRanges) ||
      !listEquals(old.chapterStarts, chapterStarts);
}
