import 'dart:convert';

class IntegrityToken {
  const IntegrityToken({
    required this.value,
    required this.deviceId,
    required this.expiresAt,
  });

  final String value;
  final String deviceId;
  final DateTime expiresAt;

  static const maxLifetime = Duration(hours: 1);

  static final _tokenShape = RegExp(r'^[A-Za-z0-9._~+/=-]{20,8192}$');
  static final _deviceIdShape = RegExp(r'^[A-Za-z0-9]{8,64}$');

  bool isUsableAt(DateTime moment) => moment.isBefore(expiresAt);

  IntegrityToken cappedAt(DateTime latest) => expiresAt.isAfter(latest)
      ? IntegrityToken(value: value, deviceId: deviceId, expiresAt: latest)
      : this;

  static IntegrityToken? fromCapture(
    String message, {
    required String nonce,
    required DateTime now,
  }) {
    final Object? decoded;
    try {
      decoded = jsonDecode(message);
    } on FormatException {
      return null;
    }
    if (decoded is! Map || nonce.isEmpty || decoded['nonce'] != nonce) {
      return null;
    }
    final value = decoded['token'];
    final deviceId = decoded['deviceId'];
    final expiration = decoded['expiration'];
    if (value is! String || !_tokenShape.hasMatch(value)) return null;
    if (deviceId is! String || !_deviceIdShape.hasMatch(deviceId)) return null;
    if (expiration is! num || !expiration.isFinite || expiration <= 0) {
      return null;
    }
    return IntegrityToken(
      value: value,
      deviceId: deviceId,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        expiration.toInt(),
        isUtc: true,
      ),
    ).cappedAt(now.toUtc().add(maxLifetime));
  }

  @override
  String toString() => 'IntegrityToken(expiresAt: $expiresAt)';
}
