/// A snapshot of the native IVS player statistics, sent once per second by
/// `IvsPlayerCore` while the stats panel is open.
///
/// Parsing is deliberately tolerant: every field is optional and a value of
/// the wrong type is treated as unknown rather than throwing, so an older or
/// newer native build can never crash the overlay.
class IvsStats {
  const IvsStats({
    this.bitrate,
    this.fps,
    this.droppedFrames,
    this.decodedFrames,
    this.renderedFrames,
    this.bufferedMs,
    this.lowLatency,
    this.playbackRate,
    this.bandwidth,
    this.qualityName,
    this.width,
    this.height,
    this.codecs,
    this.framerate,
  });

  factory IvsStats.fromEvent(Map<dynamic, dynamic> event) {
    final quality = event['quality'];
    final q = quality is Map ? quality : const {};
    return IvsStats(
      bitrate: _int(event['bitrate']),
      fps: _int(event['fps']),
      droppedFrames: _int(event['dropped']),
      decodedFrames: _int(event['decoded']),
      renderedFrames: _int(event['rendered']),
      bufferedMs: _int(event['bufferedMs']),
      lowLatency: _bool(event['lowLatency']),
      playbackRate: _double(event['playbackRate']),
      bandwidth: _int(event['bandwidth']),
      qualityName: _string(q['name']),
      width: _int(q['width']),
      height: _int(q['height']),
      codecs: _string(q['codecs']),
      framerate: _double(q['framerate']),
    );
  }

  /// Current video bitrate in bits per second.
  final int? bitrate;
  final int? fps;
  final int? droppedFrames;
  final int? decodedFrames;
  final int? renderedFrames;

  /// How far the buffered position is ahead of the playhead.
  final int? bufferedMs;

  /// Whether IVS is actually using the low-latency segment path.
  final bool? lowLatency;
  final double? playbackRate;

  /// Estimated network bandwidth in bits per second.
  final int? bandwidth;
  final String? qualityName;
  final int? width;
  final int? height;
  final String? codecs;
  final double? framerate;

  String? get resolution =>
      width != null && height != null ? '$width×$height' : null;

  static int? _int(Object? v) => v is num ? v.round() : null;

  static double? _double(Object? v) => v is num ? v.toDouble() : null;

  static bool? _bool(Object? v) => v is bool ? v : null;

  static String? _string(Object? v) => v is String ? v : null;
}
