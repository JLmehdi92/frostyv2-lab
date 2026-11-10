import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/integrity_retry_interceptor.dart';
import 'package:onset/constants.dart';
import 'package:onset/models/clip.dart';
import 'package:onset/models/clip_comment.dart';
import 'package:onset/models/profile_edit.dart';

class TwitchAccountGqlService extends BaseApiClient {
  TwitchAccountGqlService(Dio dio) : super(dio, '');

  static const _gqlUrl = 'https://gql.twitch.tv/gql';
  static final _numericId = RegExp(r'^[0-9]{1,20}$');
  static final _opaqueId = RegExp(r'^[A-Za-z0-9_:\-]{1,128}$');
  static final loginPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_]{2,24}$');
  static const maxCommentLength = 500;

  static const _userModelFragments =
      '  fragment UserModelFragment on User { id login displayName '
      'primaryColorHex chatColor description profileImageURL(width: 300) '
      'bannerImageURL roles { isStaff } createdAt turboStatus { '
      'hasActiveTurbo } }  fragment CurrentUserModelFragment on User { '
      '__typename ...UserModelFragment accountHealth { isVerifiedEmail } '
      'turboStatus { hasActiveTurbo } }';

  static const _updateDisplayNameDocument =
      'mutation UpdateUserDisplayNameMutation(\$userID: ID!, \$newDisplayName: '
      'String!) { updateUser(input: { userID: \$userID displayName: '
      '\$newDisplayName } ) { error { code } user { __typename '
      '...CurrentUserModelFragment settings { preferredLanguageTag } } } }'
      '$_userModelFragments';

  static const _updateDescriptionDocument =
      'mutation UpdateUserDescriptionMutation(\$userID: ID!, \$newDescription: '
      'String!) { updateUser(input: { userID: \$userID description: '
      '\$newDescription } ) { error { code } user { __typename '
      '...CurrentUserModelFragment } } }$_userModelFragments';

  static const _changeUsernameDocument =
      'mutation ChangeUsernameMutation(\$userID: ID!, \$newLogin: String!) { '
      'changeUsername(input: { userID: \$userID login: \$newLogin } ) { error '
      '{ code } user { __typename ...CurrentUserModelFragment } } }'
      '$_userModelFragments';

  static const _usernameAvailableDocument =
      'query IsUsernameAvailableQuery(\$login: String!) { '
      'isUsernameAvailable(username: \$login) }';

  static const _renameStatusDocument =
      'query UserLoginRenameStatusQuery { currentUser { loginRenameStatus { '
      'isEligible eligibleAt } } }';

  static const _profileDocument =
      'query EditableProfile { currentUser { id login displayName description '
      'profileImageURL(width: 300) bannerImageURL } }';

  static const _socialLinksDocument =
      'query SocialLinks { currentUser { id channel { socialMedias { id name '
      'title url } } } }';

  static const _socialMediasFragment =
      '  fragment SocialMediasFragment on Channel { socialMedias { id name '
      'title url } }';

  static const _createSocialLinkDocument =
      'mutation CreateSocialLink(\$input: CreateSocialMediaInput!) { '
      'createSocialMedia(input: \$input) { channel { __typename '
      '...SocialMediasFragment } error } }$_socialMediasFragment';

  static const _updateSocialLinkDocument =
      'mutation UpdateSocialLink(\$input: UpdateSocialMediaInput!) { '
      'updateSocialMedia(input: \$input) { channel { __typename '
      '...SocialMediasFragment } error } }$_socialMediasFragment';

  static const _deleteSocialLinkDocument =
      'mutation DeleteSocialLink(\$input: DeleteSocialMediaInput!) { '
      'deleteSocialMedia(input: \$input) { channel { __typename '
      '...SocialMediasFragment } } }$_socialMediasFragment';

  static const _commentEligibilityDocument =
      'query ClipCommentEligibilityQuery(\$slug: ID!) { clip(slug: \$slug) { '
      'self { commentCreationEligibility { isAllowed errorCodes '
      'requiredFollowingLengthMinutes } } broadcaster { self { follower { '
      'followedAt } } } } }';

  static const _clipCommentFragments =
      '  fragment UserBadgeFragment on Badge { setID imageUrlNormal: '
      'imageURL(size: NORMAL) imageUrlDouble: imageURL(size: DOUBLE) '
      'imageUrlQuadruple: imageURL(size: QUADRUPLE) version title }  fragment '
      'ClipCommentFragment on ClipComment { id body likeCount replyCount '
      'isHeartedByCreator isLikedByViewer isDownvotedByViewer '
      'isCollapsedByCommunity createdAt editedAt author { id login displayName '
      'profileImageURL(width: 70) } authorBadges { __typename '
      '...UserBadgeFragment } emotes { emoteID from to } parentComment { id } }';

  static const _createCommentDocument =
      'mutation CreateClipComment(\$input: CreateClipCommentInput!) { '
      'createClipComment(input: \$input) { comment { __typename '
      '...ClipCommentFragment } error } }$_clipCommentFragments';

  static const _likeCommentDocument =
      'mutation LikeClipComment(\$input: LikeClipCommentInput!) { '
      'likeClipComment(input: \$input) { error } }';

  static const _unlikeCommentDocument =
      'mutation UnlikeClipComment(\$input: UnlikeClipCommentInput!) { '
      'unlikeClipComment(input: \$input) { error } }';

  static bool isValidLogin(String login) =>
      loginPattern.hasMatch(login) && login.length <= 25;

  Future<EditableProfile?> profile({required String authToken}) async {
    final data = await _query('EditableProfile', _profileDocument, authToken);
    return EditableProfile.tryParse(data is Map ? data['currentUser'] : null);
  }

  Future<LoginRenameStatus?> renameStatus({required String authToken}) async =>
      LoginRenameStatus.tryParse(
        await _query(
          'UserLoginRenameStatusQuery',
          _renameStatusDocument,
          authToken,
        ),
      );

  Future<List<SocialLink>?> socialLinks({required String authToken}) async {
    final data = await _query('SocialLinks', _socialLinksDocument, authToken);
    final user = data is Map ? data['currentUser'] : null;
    return SocialLink.listFrom(user is Map ? user['channel'] : null);
  }

  Future<UsernameAvailability> usernameAvailability({
    required String login,
    required String authToken,
  }) async {
    if (!isValidLogin(login)) return UsernameAvailability.taken;
    final data = await _query(
      'IsUsernameAvailableQuery',
      _usernameAvailableDocument,
      authToken,
      variables: {'login': login.toLowerCase()},
    );
    final available = data is Map ? data['isUsernameAvailable'] : null;
    if (available is! bool) return UsernameAvailability.unknown;
    return available
        ? UsernameAvailability.available
        : UsernameAvailability.taken;
  }

  Future<AccountEditResult<EditableProfile>> updateDisplayName({
    required String userId,
    required String displayName,
    required String authToken,
  }) {
    final name = displayName.trim();
    if (!_numericId.hasMatch(userId) || name.isEmpty || name.length > 25) {
      return _failedAtOnce(authToken);
    }
    return _updateUser(
      operation: 'UpdateUserDisplayNameMutation',
      document: _updateDisplayNameDocument,
      field: 'updateUser',
      authToken: authToken,
      variables: {'userID': userId, 'newDisplayName': name},
    );
  }

  Future<AccountEditResult<EditableProfile>> updateDescription({
    required String userId,
    required String description,
    required String authToken,
  }) {
    final text = description.trim();
    if (!_numericId.hasMatch(userId) ||
        text.length > EditableProfile.maxDescriptionLength) {
      return _failedAtOnce(authToken);
    }
    return _updateUser(
      operation: 'UpdateUserDescriptionMutation',
      document: _updateDescriptionDocument,
      field: 'updateUser',
      authToken: authToken,
      variables: {'userID': userId, 'newDescription': text},
    );
  }

  Future<AccountEditResult<EditableProfile>> changeUsername({
    required String userId,
    required String login,
    required String authToken,
  }) {
    if (!_numericId.hasMatch(userId) || !isValidLogin(login)) {
      return _failedAtOnce(authToken);
    }
    return _updateUser(
      operation: 'ChangeUsernameMutation',
      document: _changeUsernameDocument,
      field: 'changeUsername',
      authToken: authToken,
      variables: {'userID': userId, 'newLogin': login.toLowerCase()},
    );
  }

  Future<AccountEditResult<List<SocialLink>>> addSocialLink({
    required String channelId,
    required String title,
    required String url,
    required String authToken,
  }) {
    if (!_numericId.hasMatch(channelId) || !_validLink(title, url)) {
      return _failedAtOnce(authToken);
    }
    return _socialLinkEdit(
      operation: 'CreateSocialLink',
      document: _createSocialLinkDocument,
      field: 'createSocialMedia',
      authToken: authToken,
      input: {'channelID': channelId, 'title': title.trim(), 'url': url.trim()},
    );
  }

  Future<AccountEditResult<List<SocialLink>>> updateSocialLink({
    required String channelId,
    required String linkId,
    required String title,
    required String url,
    required String authToken,
  }) {
    if (!_numericId.hasMatch(channelId) ||
        !_opaqueId.hasMatch(linkId) ||
        !_validLink(title, url)) {
      return _failedAtOnce(authToken);
    }
    return _socialLinkEdit(
      operation: 'UpdateSocialLink',
      document: _updateSocialLinkDocument,
      field: 'updateSocialMedia',
      authToken: authToken,
      input: {
        'channelID': channelId,
        'id': linkId,
        'title': title.trim(),
        'url': url.trim(),
      },
    );
  }

  Future<AccountEditResult<List<SocialLink>>> deleteSocialLink({
    required String channelId,
    required String linkId,
    required String authToken,
  }) {
    if (!_numericId.hasMatch(channelId) || !_opaqueId.hasMatch(linkId)) {
      return _failedAtOnce(authToken);
    }
    return _socialLinkEdit(
      operation: 'DeleteSocialLink',
      document: _deleteSocialLinkDocument,
      field: 'deleteSocialMedia',
      authToken: authToken,
      input: {'channelID': channelId, 'id': linkId},
    );
  }

  Future<ClipCommentEligibility?> commentEligibility({
    required String slug,
    required String authToken,
  }) async {
    if (!isValidClipSlug(slug)) return null;
    return ClipCommentEligibility.tryParse(
      await _query(
        'ClipCommentEligibilityQuery',
        _commentEligibilityDocument,
        authToken,
        variables: {'slug': slug},
      ),
    );
  }

  Future<AccountEditResult<ClipComment>> postComment({
    required String slug,
    required String body,
    required String authToken,
  }) async {
    final text = body.trim();
    if (!isValidClipSlug(slug) ||
        text.isEmpty ||
        text.length > maxCommentLength) {
      return _failedAtOnce(authToken);
    }
    final result = await _mutate(
      operation: 'CreateClipComment',
      document: _createCommentDocument,
      field: 'createClipComment',
      authToken: authToken,
      variables: {
        'input': {'clipSlug': slug, 'body': text},
      },
    );
    if (result.outcome != AccountEditOutcome.done) {
      return AccountEditResult(result.outcome, code: result.code);
    }
    final comment = ClipComment.tryParse(result.value?['comment']);
    return comment == null
        ? const AccountEditResult.failed()
        : AccountEditResult(AccountEditOutcome.done, value: comment);
  }

  Future<AccountEditOutcome> setCommentLiked({
    required String slug,
    required String commentId,
    required bool liked,
    required String authToken,
  }) async {
    if (!isValidClipSlug(slug) || !_opaqueId.hasMatch(commentId)) {
      return (await _failedAtOnce<void>(authToken)).outcome;
    }
    final result = await _mutate(
      operation: liked ? 'LikeClipComment' : 'UnlikeClipComment',
      document: liked ? _likeCommentDocument : _unlikeCommentDocument,
      field: liked ? 'likeClipComment' : 'unlikeClipComment',
      authToken: authToken,
      variables: {
        'input': {'clipSlug': slug, 'commentID': commentId},
      },
    );
    return result.outcome;
  }

  static const maxClipTitleLength = 100;

  static const _deleteClipsDocument =
      'mutation DeleteClipsMutation(\$input: DeleteClipsInput!) { '
      'deleteClips(input: \$input) { clips { slug } } }';

  static const _updateClipDocument =
      'mutation UpdateClipMutation(\$input: UpdateClipInput!) { '
      'updateClip(input: \$input) { clip { slug title } error { message } } }';

  Future<AccountEditOutcome> deleteClip({
    required String slug,
    required String authToken,
  }) async {
    if (!isValidClipSlug(slug)) {
      return (await _failedAtOnce<void>(authToken)).outcome;
    }
    final result = await _mutate(
      operation: 'DeleteClipsMutation',
      document: _deleteClipsDocument,
      field: 'deleteClips',
      authToken: authToken,
      variables: {
        'input': {
          'slugs': [slug],
        },
      },
    );
    if (result.outcome != AccountEditOutcome.done) return result.outcome;
    final deleted = result.value?['clips'];
    return deleted is List &&
            deleted.any((clip) => clip is Map && clip['slug'] == slug)
        ? AccountEditOutcome.done
        : AccountEditOutcome.refused;
  }

  Future<AccountEditResult<String>> renameClip({
    required String slug,
    required String title,
    required String authToken,
  }) async {
    final text = title.trim();
    if (!isValidClipSlug(slug) ||
        text.isEmpty ||
        text.length > maxClipTitleLength) {
      return _failedAtOnce(authToken);
    }
    final result = await _mutate(
      operation: 'UpdateClipMutation',
      document: _updateClipDocument,
      field: 'updateClip',
      authToken: authToken,
      variables: {
        'input': {'slug': slug, 'title': text},
      },
    );
    if (result.outcome != AccountEditOutcome.done) {
      return AccountEditResult(result.outcome, code: result.code);
    }
    final clip = result.value?['clip'];
    final saved = clip is Map ? clip['title'] : null;
    return saved is String
        ? AccountEditResult(AccountEditOutcome.done, value: saved)
        : const AccountEditResult.failed();
  }

  static bool _validLink(String title, String url) {
    final name = title.trim();
    return name.isNotEmpty &&
        name.length <= SocialLink.maxTitleLength &&
        SocialLink.isValidUrl(url);
  }

  Future<AccountEditResult<EditableProfile>> _updateUser({
    required String operation,
    required String document,
    required String field,
    required String authToken,
    required Map<String, Object?> variables,
  }) async {
    final result = await _mutate(
      operation: operation,
      document: document,
      field: field,
      authToken: authToken,
      variables: variables,
    );
    if (result.outcome != AccountEditOutcome.done) {
      return AccountEditResult(result.outcome, code: result.code);
    }
    final profile = EditableProfile.tryParse(result.value?['user']);
    return profile == null
        ? const AccountEditResult.failed()
        : AccountEditResult(AccountEditOutcome.done, value: profile);
  }

  Future<AccountEditResult<List<SocialLink>>> _socialLinkEdit({
    required String operation,
    required String document,
    required String field,
    required String authToken,
    required Map<String, Object?> input,
  }) async {
    final result = await _mutate(
      operation: operation,
      document: document,
      field: field,
      authToken: authToken,
      variables: {'input': input},
    );
    if (result.outcome != AccountEditOutcome.done) {
      return AccountEditResult(result.outcome, code: result.code);
    }
    final links = SocialLink.listFrom(result.value?['channel']);
    return links == null
        ? const AccountEditResult.failed()
        : AccountEditResult(AccountEditOutcome.done, value: links);
  }

  Future<AccountEditResult<T>> _failedAtOnce<T>(String authToken) =>
      Future.value(
        authToken.isEmpty
            ? AccountEditResult<T>.signedOut()
            : AccountEditResult<T>.failed(),
      );

  Future<Object?> _query(
    String operation,
    String document,
    String authToken, {
    Map<String, Object?> variables = const {},
  }) async {
    if (authToken.isEmpty) return null;
    try {
      final Object? body = await post<dynamic>(
        _gqlUrl,
        headers: _headers(authToken),
        data: {
          'operationName': operation,
          'query': document,
          'variables': variables,
        },
      );
      if (body is! Map) return null;
      final errors = body['errors'];
      if (errors is List && errors.isNotEmpty) return null;
      return body['data'];
    } catch (e) {
      if (kDebugMode) debugPrint('$operation failed: $e');
      return null;
    }
  }

  Future<AccountEditResult<Map<dynamic, dynamic>>> _mutate({
    required String operation,
    required String document,
    required String field,
    required String authToken,
    required Map<String, Object?> variables,
  }) async {
    if (authToken.isEmpty) return const AccountEditResult.signedOut();
    try {
      final Object? body = await post<dynamic>(
        _gqlUrl,
        extra: IntegrityRetryInterceptor.userAction,
        headers: _headers(authToken),
        data: {
          'operationName': operation,
          'query': document,
          'variables': variables,
        },
      );
      return _resultOf(body, field);
    } on UnauthorizedException {
      return const AccountEditResult.signedOut();
    } catch (e) {
      if (kDebugMode) debugPrint('$operation failed: $e');
      return const AccountEditResult.failed();
    }
  }

  static AccountEditResult<Map<dynamic, dynamic>> _resultOf(
    Object? body,
    String field,
  ) {
    if (body is! Map) return const AccountEditResult.failed();
    final errors = body['errors'];
    if (errors is List && errors.isNotEmpty) {
      final text = errors
          .map((e) => e is Map ? '${e['message']}' : '$e')
          .join(' ')
          .toLowerCase();
      return text.contains('integrity')
          ? const AccountEditResult(AccountEditOutcome.integrityRefused)
          : const AccountEditResult.failed();
    }
    final data = body['data'];
    final payload = data is Map ? data[field] : null;
    if (payload is! Map) return const AccountEditResult.failed();
    final error = payload['error'];
    if (error is Map) {
      final code = error['code'];
      return AccountEditResult(
        AccountEditOutcome.refused,
        code: code is String ? code : null,
      );
    }
    if (error is String && error.isNotEmpty) {
      return AccountEditResult(AccountEditOutcome.refused, code: error);
    }
    return AccountEditResult(AccountEditOutcome.done, value: payload);
  }

  static Map<String, String> _headers(String authToken) => {
    'Client-ID': kTwitchWebClientId,
    'Authorization': 'OAuth $authToken',
  };
}
