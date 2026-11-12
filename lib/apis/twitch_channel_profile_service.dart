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

  static const _trailerQuery =
      'query ChannelTrailer(\$login: String!) { user(login: \$login) { id '
      'channel { id trailer { video { id title lengthSeconds '
      'previewThumbnailURL(width: 640, height: 360) } } } } }';

  static const _restrictionQuery =
      'query ChannelProfileRestriction(\$channelID: ID!) { user(id: '
      '\$channelID) { id channelSafetyStatus } }';

  static final _channelId = RegExp(r'^[0-9]{1,20}$');
  static const _restrictedStatuses = {
    'RESTRICTED',
    'SUSPENDED',
    'TEMPORARILY_RESTRICTED',
  };

  static const _djRoleQuery =
      'query ChannelDjRole(\$login: String!) { user(login: \$login) { id '
      'roles { isParticipatingDJ } } }';

  Future<bool> isParticipatingDj(String login) async {
    if (!_login.hasMatch(login)) return false;
    try {
      final Object? body = await post<dynamic>(
        kTwitchGqlUrl,
        headers: {'Client-ID': kTwitchWebClientId},
        data: {
          'operationName': 'ChannelDjRole',
          'query': _djRoleQuery,
          'variables': {'login': login},
        },
      );
      final data = body is Map ? body['data'] : null;
      final user = data is Map ? data['user'] : null;
      final roles = user is Map ? user['roles'] : null;
      return roles is Map && roles['isParticipatingDJ'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isRestricted(String channelId) async {
    if (!_channelId.hasMatch(channelId)) return false;
    try {
      final Object? body = await post<dynamic>(
        kTwitchGqlUrl,
        headers: {'Client-ID': kTwitchWebClientId},
        data: {
          'operationName': 'ChannelProfileRestriction',
          'query': _restrictionQuery,
          'variables': {'channelID': channelId},
        },
      );
      final data = body is Map ? body['data'] : null;
      final user = data is Map ? data['user'] : null;
      final statuses = user is Map ? user['channelSafetyStatus'] : null;
      if (statuses is! List) return false;
      return statuses.any(
        (status) =>
            status is String &&
            _restrictedStatuses.contains(status.trim().toUpperCase()),
      );
    } catch (_) {
      return false;
    }
  }

  Future<ChannelTrailer?> getTrailer(String login) async {
    final (:data, :errors) = await _gql('ChannelTrailer', _trailerQuery, login);
    final channel = chMap(chMap(data['user'])?['channel']);
    if (channel == null && errors.isNotEmpty) {
      throw ChannelProfileApiException(errors);
    }
    return ChannelTrailer.fromGql(chMap(channel?['trailer'])?['video']);
  }

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
      kTwitchGqlUrl,
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

class ChannelTrailer {
  const ChannelTrailer({
    required this.videoId,
    required this.title,
    this.length,
    this.thumbnailUrl,
  });

  final String videoId;
  final String title;
  final Duration? length;
  final String? thumbnailUrl;

  static final _videoId = RegExp(r'^[0-9]{1,20}$');

  static ChannelTrailer? fromGql(Object? video) {
    final map = chMap(video);
    final id = map?['id'];
    if (map == null || id is! String || !_videoId.hasMatch(id)) return null;
    final seconds = chInt(map['lengthSeconds']);
    final thumbnail = chString(map['previewThumbnailURL']);
    return ChannelTrailer(
      videoId: id,
      title: chString(map['title'], max: 300) ?? '',
      length: seconds != null && seconds > 0
          ? Duration(seconds: seconds)
          : null,
      thumbnailUrl: thumbnail != null && thumbnail.startsWith('https://')
          ? thumbnail
          : null,
    );
  }
}
