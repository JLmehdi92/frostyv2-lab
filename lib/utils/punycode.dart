const _base = 36;
const _tMin = 1;
const _tMax = 26;
const _skew = 38;
const _damp = 700;
const _initialBias = 72;
const _initialN = 128;

String asciiHost(String host) => _decoded(host)
    .split('.')
    .map(
      (label) => label.runes.every((rune) => rune < 0x80)
          ? label
          : 'xn--${punycodeEncode(label.toLowerCase())}',
    )
    .join('.');

String _decoded(String host) {
  try {
    return Uri.decodeComponent(host);
  } on ArgumentError {
    return host;
  } on FormatException {
    return host;
  }
}

String punycodeEncode(String input) {
  final codePoints = input.runes.toList();
  final output = StringBuffer();
  for (final point in codePoints) {
    if (point < 0x80) output.writeCharCode(point);
  }
  final basicLength = output.length;
  var handled = basicLength;
  if (basicLength > 0) output.write('-');
  var n = _initialN;
  var delta = 0;
  var bias = _initialBias;
  while (handled < codePoints.length) {
    final next = codePoints
        .where((point) => point >= n)
        .reduce((a, b) => a < b ? a : b);
    delta += (next - n) * (handled + 1);
    n = next;
    for (final point in codePoints) {
      if (point < n) delta++;
      if (point != n) continue;
      var q = delta;
      for (var k = _base; ; k += _base) {
        final t = k <= bias
            ? _tMin
            : k >= bias + _tMax
            ? _tMax
            : k - bias;
        if (q < t) break;
        output.writeCharCode(_digit(t + (q - t) % (_base - t)));
        q = (q - t) ~/ (_base - t);
      }
      output.writeCharCode(_digit(q));
      bias = _adapt(delta, handled + 1, first: handled == basicLength);
      delta = 0;
      handled++;
    }
    delta++;
    n++;
  }
  return output.toString();
}

int _digit(int value) => value < 26 ? value + 97 : value + 22;

int _adapt(int delta, int points, {required bool first}) {
  var scaled = first ? delta ~/ _damp : delta ~/ 2;
  scaled += scaled ~/ points;
  var k = 0;
  while (scaled > ((_base - _tMin) * _tMax) ~/ 2) {
    scaled ~/= _base - _tMin;
    k += _base;
  }
  return k + (_base - _tMin + 1) * scaled ~/ (scaled + _skew);
}
