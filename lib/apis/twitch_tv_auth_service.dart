import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/constants.dart';
import 'package:onset/models/twitch_tv_session.dart';

class TwitchTvAuthService extends BaseApiClient {
  TwitchTvAuthService(Dio dio, {DateTime Function()? now})
    : _now = now ?? DateTime.now,
      super(dio, 'https://id.twitch.tv/oauth2');

  final DateTime Function() _now;

  static const deviceUrl = 'https://id.twitch.tv/oauth2/device';
  static const tokenUrl = 'https://id.twitch.tv/oauth2/token';
  static const validateUrl = 'https://id.twitch.tv/oauth2/validate';

  static const scopes = [
    'channel_read',
    'chat:read',
    'user_blocks_edit',
    'user_blocks_read',
    'user_follows_edit',
    'user_read',
  ];

  static const deviceGrantType = 'urn:ietf:params:oauth:grant-type:device_code';

  Future<TwitchTvDeviceCode?> requestDeviceCode() async {
    try {
      final response = await _form(deviceUrl, {
        'client_id': kTwitchTvClientId,
        'scopes': scopes.join(' '),
      });
      if (response.statusCode != 200) return null;
      return TwitchTvDeviceCode.fromJson(response.data, now: _now());
    } catch (e) {
      debugPrint('Twitch device code unavailable: ${e.runtimeType}');
      return null;
    }
  }

  Future<TwitchTvPoll> pollToken(TwitchTvDeviceCode code) async {
    if (code.isExpiredAt(_now())) return const TwitchTvPollExpired();
    try {
      final response = await _form(tokenUrl, {
        'client_id': kTwitchTvClientId,
        'device_code': code.deviceCode,
        'grant_type': deviceGrantType,
      });
      if (response.statusCode == 200) {
        final grant = TwitchTvGrant.fromJson(response.data);
        return grant == null
            ? const TwitchTvPollFailed()
            : TwitchTvPollGranted(grant);
      }
      return pollOf(response.data);
    } catch (e) {
      debugPrint('Twitch device token poll failed: ${e.runtimeType}');
      return const TwitchTvPollFailed();
    }
  }

  static TwitchTvPoll pollOf(Object? body) {
    final message = body is Map ? '${body['message']}'.toLowerCase() : '';
    if (message.contains('authorization_pending')) {
      return const TwitchTvPollPending();
    }
    if (message.contains('slow_down')) return const TwitchTvPollSlowDown();
    if (message.contains('denied')) return const TwitchTvPollDenied();
    if (message.contains('expired') || message.contains('invalid device')) {
      return const TwitchTvPollExpired();
    }
    return const TwitchTvPollFailed();
  }

  Future<TwitchTvGrant?> refresh(String refreshToken) async {
    try {
      final response = await _form(tokenUrl, {
        'client_id': kTwitchTvClientId,
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
      });
      if (response.statusCode != 200) return null;
      return TwitchTvGrant.fromJson(response.data);
    } catch (e) {
      debugPrint('Twitch session refresh failed: ${e.runtimeType}');
      return null;
    }
  }

  Future<TwitchTvValidation> validate(String accessToken) async {
    try {
      final response = await dio.get<Object?>(
        validateUrl,
        options: Options(
          headers: {'Authorization': 'OAuth $accessToken'},
          validateStatus: (_) => true,
        ),
      );
      if (response.statusCode == 401) return const TwitchTvValidation.invalid();
      if (response.statusCode != 200) {
        return const TwitchTvValidation.unknown();
      }
      final identity = TwitchTvIdentity.fromJson(response.data);
      if (identity == null || identity.clientId != kTwitchTvClientId) {
        return const TwitchTvValidation.invalid();
      }
      return TwitchTvValidation.valid(identity.userId);
    } catch (e) {
      debugPrint('Twitch session check failed: ${e.runtimeType}');
      return const TwitchTvValidation.unknown();
    }
  }

  Future<Response<Object?>> _form(String url, Map<String, String> fields) =>
      dio.post<Object?>(
        url,
        data: fields,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          validateStatus: (_) => true,
        ),
      );
}

enum TwitchTvValidity { valid, invalid, unknown }

class TwitchTvValidation {
  const TwitchTvValidation.valid(String this.userId)
    : validity = TwitchTvValidity.valid;

  const TwitchTvValidation.invalid()
    : validity = TwitchTvValidity.invalid,
      userId = null;

  const TwitchTvValidation.unknown()
    : validity = TwitchTvValidity.unknown,
      userId = null;

  final TwitchTvValidity validity;
  final String? userId;
}
