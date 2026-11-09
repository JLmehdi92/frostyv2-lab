import 'package:onset/apis/base_api_client.dart';

class ClipComment {
  const ClipComment({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.authorLogin,
    required this.authorDisplayName,
    this.authorImageUrl,
    this.likeCount = 0,
    this.replyCount = 0,
    this.heartedByCreator = false,
    this.likedByViewer = false,
    this.collapsed = false,
  });

  static ClipComment? tryParse(Object? node) {
    if (node is! Map) return null;
    final id = node['id'];
    final body = node['body'];
    final createdAt = DateTime.tryParse('${node['createdAt']}');
    final author = node['author'];
    if (id is! String || id.isEmpty || body is! String || createdAt == null) {
      return null;
    }
    final login = author is Map && author['login'] is String
        ? author['login'] as String
        : '';
    final displayName = author is Map && author['displayName'] is String
        ? author['displayName'] as String
        : login;
    final image = author is Map ? author['profileImageURL'] : null;
    return ClipComment(
      id: id,
      body: body,
      createdAt: createdAt,
      authorLogin: login,
      authorDisplayName: displayName.isEmpty ? login : displayName,
      authorImageUrl: image is String && image.startsWith('https://')
          ? image
          : null,
      likeCount: _count(node['likeCount']),
      replyCount: _count(node['replyCount']),
      heartedByCreator: node['isHeartedByCreator'] == true,
      likedByViewer: node['isLikedByViewer'] == true,
      collapsed: node['isCollapsedByCommunity'] == true,
    );
  }

  static int _count(Object? value) =>
      value is num && value.isFinite && value > 0 ? value.toInt() : 0;

  final String id;
  final String body;
  final DateTime createdAt;
  final String authorLogin;
  final String authorDisplayName;
  final String? authorImageUrl;
  final int likeCount;
  final int replyCount;
  final bool heartedByCreator;
  final bool likedByViewer;
  final bool collapsed;

  ClipComment withLike({required bool liked}) => ClipComment(
    id: id,
    body: body,
    createdAt: createdAt,
    authorLogin: authorLogin,
    authorDisplayName: authorDisplayName,
    authorImageUrl: authorImageUrl,
    likeCount: liked == likedByViewer
        ? likeCount
        : (liked ? likeCount + 1 : (likeCount - 1).clamp(0, likeCount)),
    replyCount: replyCount,
    heartedByCreator: heartedByCreator,
    likedByViewer: liked,
    collapsed: collapsed,
  );
}

class ClipCommentPage {
  const ClipCommentPage({required this.items, this.cursor});

  static ClipCommentPage? tryParse(JsonMap data) {
    final clip = data['clip'];
    if (clip is! Map) return null;
    final comments = clip['comments'];
    if (comments is! Map || comments['edges'] is! List) return null;
    final items = <ClipComment>[];
    for (final edge in comments['edges'] as List) {
      final comment = ClipComment.tryParse(edge is Map ? edge['node'] : null);
      if (comment != null) items.add(comment);
    }
    final pageInfo = comments['pageInfo'];
    final next = pageInfo is Map ? pageInfo['endCursor'] : null;
    final hasMore =
        pageInfo is Map &&
        pageInfo['hasNextPage'] == true &&
        next is String &&
        next.isNotEmpty;
    return ClipCommentPage(items: items, cursor: hasMore ? next : null);
  }

  final List<ClipComment> items;
  final String? cursor;
}

enum ClipCommentBlock {
  commentsDisabled,
  notFollowing,
  followTooRecent,
  notSubscribed,
  unverified,
  other;

  static ClipCommentBlock of(List<String> codes) {
    if (codes.contains('COMMENTS_DISABLED')) return commentsDisabled;
    if (codes.contains('USER_NOT_FOLLOWING')) return notFollowing;
    if (codes.contains('FOLLOWING_LENGTH_REQUIREMENT_NOT_MET')) {
      return followTooRecent;
    }
    if (codes.contains('USER_NOT_SUBSCRIBED')) return notSubscribed;
    if (codes.contains('EMAIL_NOT_VERIFIED') ||
        codes.contains('PHONE_NOT_VERIFIED')) {
      return unverified;
    }
    return other;
  }
}

class ClipCommentEligibility {
  const ClipCommentEligibility({
    required this.allowed,
    this.block,
    this.requiredFollowMinutes,
  });

  static ClipCommentEligibility? tryParse(Object? data) {
    final clip = data is Map ? data['clip'] : null;
    final self = clip is Map ? clip['self'] : null;
    final eligibility = self is Map ? self['commentCreationEligibility'] : null;
    if (eligibility is! Map || eligibility['isAllowed'] is! bool) return null;
    if (eligibility['isAllowed'] == true) {
      return const ClipCommentEligibility(allowed: true);
    }
    final codes = eligibility['errorCodes'] is List
        ? [for (final code in eligibility['errorCodes'] as List) '$code']
        : const <String>[];
    final minutes = eligibility['requiredFollowingLengthMinutes'];
    return ClipCommentEligibility(
      allowed: false,
      block: ClipCommentBlock.of(codes),
      requiredFollowMinutes: minutes is num && minutes > 0
          ? minutes.toInt()
          : null,
    );
  }

  final bool allowed;
  final ClipCommentBlock? block;
  final int? requiredFollowMinutes;
}
