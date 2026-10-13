import 'dart:math' as math;

/// Pixels to request for an image drawn [logicalWidth] dp wide at
/// [pixelRatio]: rounded up to a multiple of [step] so small layout changes
/// keep hitting the cache, and capped at [max] (Twitch's largest preview).
int imagePixelWidth(
  double logicalWidth,
  double pixelRatio, {
  int step = 160,
  int max = 1920,
}) {
  if (!logicalWidth.isFinite || logicalWidth <= 0) return step;
  final pixels = (logicalWidth * pixelRatio / step).ceil() * step;
  return math.min(math.max(pixels, step), max);
}
