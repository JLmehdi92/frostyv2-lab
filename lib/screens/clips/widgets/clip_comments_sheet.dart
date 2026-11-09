import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onset/apis/twitch_account_gql_service.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/clip_comment.dart';
import 'package:onset/models/profile_edit.dart';
import 'package:onset/screens/vod/vod_time.dart';
import 'package:onset/screens/vod/widgets/video_glyph.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/onset_cached_network_image.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';

class ClipCommentActions {
  const ClipCommentActions({
    required this.eligibility,
    required this.post,
    required this.setLiked,
  });

  final Future<ClipCommentEligibility?> Function() eligibility;
  final Future<AccountEditResult<ClipComment>> Function(String body) post;
  final Future<AccountEditOutcome> Function(String commentId, bool liked)
  setLiked;
}

class ClipCommentsSheet extends StatefulWidget {
  const ClipCommentsSheet({super.key, required this.load, this.actions});

  static const composerKey = ValueKey('clip-comment-composer');
  static const sendKey = ValueKey('clip-comment-send');
  static const moreKey = ValueKey('clip-comments-more');
  static ValueKey<String> likeKey(String id) =>
      ValueKey('clip-comment-like-$id');
  static ValueKey<String> showKey(String id) =>
      ValueKey('clip-comment-show-$id');

  final Future<ClipCommentPage> Function(String? cursor) load;
  final ClipCommentActions? actions;

  @override
  State<ClipCommentsSheet> createState() => _ClipCommentsSheetState();
}

class _ClipCommentsSheetState extends State<ClipCommentsSheet> {
  final _comments = <ClipComment>[];
  final _revealed = <String>{};
  final _liking = <String>{};
  final _controller = TextEditingController();
  String? _cursor;
  var _loading = true;
  var _failed = false;
  var _posting = false;
  String? _postError;
  ClipCommentEligibility? _eligibility;
  var _eligibilityKnown = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPage(null));
    unawaited(_loadEligibility());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadEligibility() async {
    final actions = widget.actions;
    if (actions == null) return;
    final eligibility = await actions.eligibility();
    if (!mounted) return;
    setState(() {
      _eligibility = eligibility;
      _eligibilityKnown = true;
    });
  }

  Future<void> _loadPage(String? cursor) async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final page = await widget.load(cursor);
      if (!mounted) return;
      setState(() {
        _comments.addAll(
          page.items.where((c) => _comments.every((old) => old.id != c.id)),
        );
        _cursor = page.cursor;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _toggleLike(ClipComment comment) async {
    final actions = widget.actions;
    if (actions == null || _liking.contains(comment.id)) return;
    final liked = !comment.likedByViewer;
    setState(() => _liking.add(comment.id));
    final outcome = await actions.setLiked(comment.id, liked);
    if (!mounted) return;
    setState(() {
      _liking.remove(comment.id);
      if (outcome == AccountEditOutcome.done) {
        final index = _comments.indexWhere((c) => c.id == comment.id);
        if (index >= 0) {
          _comments[index] = _comments[index].withLike(liked: liked);
        }
      }
    });
    if (outcome != AccountEditOutcome.done) {
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.l10n.clipCommentLikeFailed)),
        );
    }
  }

  Future<void> _post() async {
    final actions = widget.actions;
    final text = _controller.text.trim();
    if (actions == null || text.isEmpty || _posting) return;
    setState(() {
      _posting = true;
      _postError = null;
    });
    final result = await actions.post(text);
    if (!mounted) return;
    final l = context.l10n;
    setState(() {
      _posting = false;
      final comment = result.value;
      if (result.succeeded && comment != null) {
        _comments.insert(0, comment);
        _controller.clear();
      } else {
        _postError = switch (result.outcome) {
          AccountEditOutcome.integrityRefused => l.clipCommentIntegrity,
          AccountEditOutcome.signedOut => l.clipCommentSignedOut,
          AccountEditOutcome.refused => l.clipCommentRefused(
            code: result.code ?? 'UNKNOWN',
          ),
          _ => l.clipCommentPostFailed,
        };
      }
    });
  }

  String? _blockedMessage(AppLocalizations l) {
    final eligibility = _eligibility;
    if (widget.actions == null) return l.clipCommentSignInToPost;
    if (!_eligibilityKnown) return null;
    if (eligibility == null) return l.clipCommentEligibilityUnknown;
    if (eligibility.allowed) return null;
    return switch (eligibility.block) {
      ClipCommentBlock.commentsDisabled => l.clipCommentsDisabled,
      ClipCommentBlock.notFollowing => l.clipCommentFollowFirst,
      ClipCommentBlock.followTooRecent => l.clipCommentFollowLonger(
        minutes: eligibility.requiredFollowMinutes ?? 0,
      ),
      ClipCommentBlock.notSubscribed => l.clipCommentSubscribersOnly,
      ClipCommentBlock.unverified => l.clipCommentVerifyAccount,
      ClipCommentBlock.other || null => l.clipCommentNotAllowed,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = SheetColors.of(context);
    final blocked = _blockedMessage(l);
    final canPost =
        widget.actions != null &&
        _eligibilityKnown &&
        (_eligibility?.allowed ?? false);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Semantics(
              header: true,
              child: Text(
                l.clipComments,
                style: SheetText.subtitle.copyWith(color: colors.text),
              ),
            ),
          ),
          Flexible(child: _list(l, colors)),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              8 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: canPost
                ? _composer(l, colors)
                : blocked == null
                ? const SizedBox(height: 4)
                : Text(
                    blocked,
                    style: SheetText.rowDetail.copyWith(
                      color: colors.secondary,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _composer(AppLocalizations l, SheetColors colors) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 6,
    children: [
      SheetTextField(
        key: ClipCommentsSheet.composerKey,
        controller: _controller,
        hint: l.clipCommentHint,
        maxLength: TwitchAccountGqlService.maxCommentLength,
      ),
      Align(
        alignment: AlignmentDirectional.centerEnd,
        child: SheetButton(
          key: ClipCommentsSheet.sendKey,
          label: l.clipCommentSend,
          onPressed: _posting ? null : () => unawaited(_post()),
        ),
      ),
      if (_postError case final error?)
        Text(error, style: SheetText.rowDetail.copyWith(color: colors.danger)),
    ],
  );

  Widget _list(AppLocalizations l, SheetColors colors) {
    if (_comments.isEmpty) {
      final message = _failed
          ? l.clipCommentsFailed
          : _loading
          ? null
          : l.clipCommentsEmpty;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: message == null
            ? const Center(
                child: SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 10,
                children: [
                  Text(
                    message,
                    style: SheetText.body.copyWith(color: colors.secondary),
                  ),
                  if (_failed)
                    SheetButton(
                      label: l.commonRetry,
                      tone: SheetButtonTone.text,
                      onPressed: () => unawaited(_loadPage(null)),
                    ),
                ],
              ),
      );
    }
    return ListView(
      shrinkWrap: true,
      primary: false,
      padding: EdgeInsets.zero,
      children: [
        for (final comment in _comments) _row(comment, l, colors),
        if (_cursor != null || _failed)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: _loading
                ? const Center(
                    child: SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : SheetButton(
                    key: ClipCommentsSheet.moreKey,
                    label: _failed ? l.commonRetry : l.clipCommentsMore,
                    tone: SheetButtonTone.text,
                    onPressed: () => unawaited(_loadPage(_cursor)),
                  ),
          ),
      ],
    );
  }

  Widget _row(ClipComment comment, AppLocalizations l, SheetColors colors) {
    final hidden = comment.collapsed && !_revealed.contains(comment.id);
    final details = [
      formatTimeAgo(comment.createdAt, l),
      if (comment.replyCount > 0)
        l.clipCommentReplies(count: comment.replyCount),
      if (comment.heartedByCreator) l.clipCommentHearted,
    ].join(' · ');
    final avatarUrl = comment.authorImageUrl;
    final avatar = InitialAvatar(name: comment.authorDisplayName, size: 32);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          ClipOval(
            child: avatarUrl == null
                ? avatar
                : OnsetCachedNetworkImage(
                    imageUrl: avatarUrl,
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => avatar,
                    errorWidget: (_, _, _) => avatar,
                  ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 3,
              children: [
                Text(
                  comment.authorDisplayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SheetText.row.copyWith(
                    color: colors.text,
                    fontSize: 14,
                  ),
                ),
                if (hidden)
                  Row(
                    spacing: 8,
                    children: [
                      Flexible(
                        child: Text(
                          l.clipCommentCollapsed,
                          style: SheetText.rowDetail.copyWith(
                            color: colors.tertiary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      TextButton(
                        key: ClipCommentsSheet.showKey(comment.id),
                        onPressed: () =>
                            setState(() => _revealed.add(comment.id)),
                        child: Text(l.clipCommentShow),
                      ),
                    ],
                  )
                else
                  Text(
                    comment.body,
                    style: SheetText.body.copyWith(
                      color: colors.body,
                      height: 1.35,
                    ),
                  ),
                Text(
                  details,
                  style: OnsetType.tabular(
                    SheetText.rowDetail.copyWith(color: colors.secondary),
                  ),
                ),
              ],
            ),
          ),
          _likeButton(comment, l, colors),
        ],
      ),
    );
  }

  Widget _likeButton(
    ClipComment comment,
    AppLocalizations l,
    SheetColors colors,
  ) {
    final liked = comment.likedByViewer;
    final color = liked ? SheetColors.accentOf(context) : colors.secondary;
    final enabled = widget.actions != null && !_liking.contains(comment.id);
    return Semantics(
      button: true,
      toggled: liked,
      label: l.clipCommentLikes(count: comment.likeCount),
      onTap: enabled ? () => unawaited(_toggleLike(comment)) : null,
      excludeSemantics: true,
      child: InkResponse(
        key: ClipCommentsSheet.likeKey(comment.id),
        onTap: enabled ? () => unawaited(_toggleLike(comment)) : null,
        radius: 24,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 2,
            children: [
              VideoGlyph(VideoGlyphKind.heart, color: color, size: 18),
              Text(
                '${comment.likeCount}',
                style: OnsetType.tabular(
                  SheetText.rowDetail.copyWith(color: color, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
