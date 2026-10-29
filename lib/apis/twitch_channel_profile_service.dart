import 'package:dio/dio.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/constants.dart';
import 'package:onset/models/channel_profile.dart';
import 'package:onset/models/community_highlights.dart';

/// A GQL error answered for a channel profile request.
class ChannelProfileApiException extends ApiException {
  const ChannelProfileApiException(super.message);

  @override
  String toString() => 'ChannelProfileApiException: $message';
}

/// A channel's profile and schedule, from anonymous GQL (the public web
/// Client-ID, full documents, no user token).
class TwitchChannelProfileService extends BaseApiClient {
  TwitchChannelProfileService(Dio dio) : super(dio, '');

  static const _gqlUrl = 'https://gql.twitch.tv/gql';
  static final _login = RegExp(r'^[a-zA-Z0-9_]{1,25}$');

  // Verified anonymously on 2026-10-13 (the stream's `createdAt` and `game`
  // on 2026-10-29).
  static const _profileQuery =
      'query ChannelProfile(\$login: String!) { user(login: \$login) { id '
      'login displayName description createdAt profileImageURL(width: 300) '
      'bannerImageURL offlineImageURL primaryColorHex '
      'roles { isPartner isAffiliate } followers { totalCount } '
      'channel { id socialMedias { name title url } } '
      'panels { id type ... on DefaultPanel { title imageURL linkURL '
      'description altText } } '
      'lastBroadcast { id title startedAt game { id displayName } } '
      'stream { id type viewersCount createdAt game { displayName } } } }';

  // `segments` takes no `first`: it answers this week and the next.
  static const _scheduleQuery =
      'query ChannelSchedule(\$login: String!) { user(login: \$login) { id '
      'channel { id schedule { id segments { id startAt endAt title '
      'isCancelled categories { id name } } nextSegment { id startAt } } } } }';

  /// The profile of [login], or null when there is no such channel.
  ///
  /// A `user` nulled by an error, or one that cannot be read (a schema
  /// change), throws: "no such channel" would hide a channel that exists.
  Future<ChannelProfile?> getProfile(String login) async {
    final (:data, :errors) = await _gql('ChannelProfile', _profileQuery, login);
    final user = data['user'];
    if (user == null) {
      if (errors.isNotEmpty) throw ChannelProfileApiException(errors);
      return null;
    }
    return ChannelProfile.fromGql(user) ??
        (throw const ChannelProfileApiException('Unreadable profile'));
  }

  /// The schedule of [login]; [ChannelSchedule.empty] without one. A
  /// schedule nulled by an error throws instead of reading as empty.
  Future<ChannelSchedule> getSchedule(String login) async {
    final (:data, :errors) = await _gql(
      'ChannelSchedule',
      _scheduleQuery,
      login,
    );
    final channel = chMap(chMap(data['user'])?['channel']);
    final schedule = channel?['schedule'];
    if (schedule == null && errors.isNotEmpty) {
      throw ChannelProfileApiException(errors);
    }
    return ChannelSchedule.fromGql(schedule);
  }

  /// The answer's data, and its error messages ('' when none).
  Future<({Map<dynamic, dynamic> data, String errors})> _gql(
    String operationName,
    String query,
    String rawLogin,
  ) async {
    final login = rawLogin.trim().toLowerCase();
    if (!_login.hasMatch(login)) {
      throw ArgumentError.value(rawLogin, 'login', 'Not a Twitch login');
    }
    final Object? body = await post<dynamic>(
      _gqlUrl,
      headers: {'Client-ID': kTwitchWebClientId},
      data: {
        'operationName': operationName,
        'query': query,
        'variables': {'login': login},
      },
    );
    final data = body is Map ? body['data'] : null;
    final rawErrors = body is Map ? body['errors'] : null;
    final errors = rawErrors is List
        ? rawErrors.map((e) => e is Map ? '${e['message']}' : '$e').join('; ')
        : '';
    if (data is! Map) {
      throw ChannelProfileApiException(
        errors.isNotEmpty ? errors : 'Malformed GQL response',
      );
    }
    // Nested resolver errors leave the rest usable: every block is optional.
    return (data: data, errors: errors);
  }
}
