import 'dart:convert';

class TwitchTvDeviceCode {
  const TwitchTvDeviceCode({
    required this.deviceCode,
    required this.userCode,
    required this.interval,
    required this.expiresAt,
  });

  final String deviceCode;
  final String userCode;
  final Duration interval;
  final DateTime expiresAt;

  static const minimumInterval = Duration(seconds: 1);
  static final _userCodeShape = RegExp(r'^[A-Za-z0-9-]{4,16}$');

  Uri get activationUri =>
      Uri.https('www.twitch.tv', '/activate', {'device-code': userCode});

  bool isExpiredAt(DateTime moment) => !moment.isBefore(expiresAt);

  static TwitchTvDeviceCode? fromJson(Object? json, {required DateTime now}) {
    if (json is! Map) return null;
    final deviceCode = json['device_code'];
    final userCode = json['user_code'];
    final expiresIn = json['expires_in'];
    final interval = json['interval'];
    if (deviceCode is! String || deviceCode.isEmpty) return null;
    if (userCode is! String || !_userCodeShape.hasMatch(userCode)) return null;
    if (expiresIn is! num || expiresIn <= 0) return null;
    final seconds = interval is num && interval > 0 ? interval.toInt() : 5;
    final pollEvery = Duration(seconds: seconds);
    return TwitchTvDeviceCode(
      deviceCode: deviceCode,
      userCode: userCode,
      interval: pollEvery < minimumInterval ? minimumInterval : pollEvery,
      expiresAt: now.add(Duration(seconds: expiresIn.toInt())),
    );
  }
}

class TwitchTvGrant {
  const TwitchTvGrant({required this.accessToken, this.refreshToken});

  final String accessToken;
  final String? refreshToken;

  static TwitchTvGrant? fromJson(Object? json) {
    if (json is! Map) return null;
    final access = json['access_token'];
    final refresh = json['refresh_token'];
    if (access is! String || access.isEmpty) return null;
    return TwitchTvGrant(
      accessToken: access,
      refreshToken: refresh is String && refresh.isNotEmpty ? refresh : null,
    );
  }

  @override
  String toString() => 'TwitchTvGrant(refreshable: ${refreshToken != null})';
}

sealed class TwitchTvPoll {
  const TwitchTvPoll();
}

class TwitchTvPollPending extends TwitchTvPoll {
  const TwitchTvPollPending();
}

class TwitchTvPollSlowDown extends TwitchTvPoll {
  const TwitchTvPollSlowDown();
}

class TwitchTvPollExpired extends TwitchTvPoll {
  const TwitchTvPollExpired();
}

class TwitchTvPollDenied extends TwitchTvPoll {
  const TwitchTvPollDenied();
}

class TwitchTvPollFailed extends TwitchTvPoll {
  const TwitchTvPollFailed();
}

class TwitchTvPollGranted extends TwitchTvPoll {
  const TwitchTvPollGranted(this.grant);

  final TwitchTvGrant grant;
}

class TwitchTvIdentity {
  const TwitchTvIdentity({required this.clientId, required this.userId});

  final String clientId;
  final String userId;

  static TwitchTvIdentity? fromJson(Object? json) {
    if (json is! Map) return null;
    final clientId = json['client_id'];
    final userId = json['user_id'];
    if (clientId is! String || userId is! String || userId.isEmpty) {
      return null;
    }
    return TwitchTvIdentity(clientId: clientId, userId: userId);
  }
}

class TwitchTvSession {
  const TwitchTvSession({
    required this.accessToken,
    required this.userId,
    required this.deviceId,
    this.refreshToken,
  });

  final String accessToken;
  final String? refreshToken;
  final String userId;
  final String deviceId;

  TwitchTvSession withGrant(TwitchTvGrant grant) => TwitchTvSession(
    accessToken: grant.accessToken,
    refreshToken: grant.refreshToken ?? refreshToken,
    userId: userId,
    deviceId: deviceId,
  );

  String encode() => jsonEncode({
    'access': accessToken,
    'refresh': ?refreshToken,
    'user': userId,
    'device': deviceId,
  });

  static TwitchTvSession? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (json is! Map) return null;
    final access = json['access'];
    final refresh = json['refresh'];
    final user = json['user'];
    final device = json['device'];
    if (access is! String || access.isEmpty) return null;
    if (user is! String || user.isEmpty) return null;
    if (device is! String || device.isEmpty) return null;
    return TwitchTvSession(
      accessToken: access,
      refreshToken: refresh is String && refresh.isNotEmpty ? refresh : null,
      userId: user,
      deviceId: device,
    );
  }

  @override
  String toString() => 'TwitchTvSession(user: $userId)';
}
