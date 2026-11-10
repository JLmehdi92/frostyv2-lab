import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/follow_result.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/utils/common_utils.dart';
import 'package:onset/widgets/follow/follow_actions.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:provider/provider.dart';

enum FollowTarget { channel, category }

class FollowFlow {
  const FollowFlow._();

  static const confirmKey = ValueKey('follow-confirm');

  static FollowActions? actionsOf(BuildContext context) {
    final FollowActions? actions;
    try {
      actions = context.read<FollowActions?>();
    } on ProviderNotFoundException {
      return null;
    }
    return actions != null && actions.canFollowInApp ? actions : null;
  }

  static final pending = ValueNotifier<Set<String>>(const {});

  static bool isPending(String id) => pending.value.contains(id);

  static Future<bool?> toggle(
    BuildContext context, {
    required FollowTarget target,
    required String id,
    required String name,
    required bool following,
    required Future<void> Function() openOnTwitch,
  }) async {
    if (isPending(id)) return null;
    final actions = actionsOf(context);
    if (actions == null) {
      if (await _confirmWebFallback(context, target, following)) {
        await openOnTwitch();
      }
      return null;
    }
    if (following && !await _confirmUnfollow(context, name)) return null;
    if (isPending(id)) return null;
    pending.value = {...pending.value, id};
    final FollowResult result;
    try {
      result = await switch ((target, following)) {
        (FollowTarget.channel, false) => actions.followChannel(id),
        (FollowTarget.channel, true) => actions.unfollowChannel(id),
        (FollowTarget.category, false) => actions.followCategory(id),
        (FollowTarget.category, true) => actions.unfollowCategory(id),
      };
    } finally {
      pending.value = {...pending.value}..remove(id);
    }
    if (!context.mounted) return null;
    showResult(context, result, name: name, followed: !following);
    if (result.opensTwitch) {
      await openOnTwitch();
      return null;
    }
    if (!result.succeeded) return null;
    unawaited(HapticFeedback.lightImpact());
    return !following;
  }

  static Future<bool?> followFromPrompt(
    BuildContext context, {
    required String id,
    required String name,
    required bool? following,
    required bool confirm,
    required Future<void> Function() openOnTwitch,
    void Function(bool following)? onChanged,
  }) async {
    if (following == true) return null;
    if (confirm && !await confirmFollow(context, name)) return null;
    if (!context.mounted) return null;
    final now = await toggle(
      context,
      target: FollowTarget.channel,
      id: id,
      name: name,
      following: false,
      openOnTwitch: openOnTwitch,
    );
    if (now != null) onChanged?.call(now);
    if (now == true && context.mounted) {
      await suggestAfterFollowing(context, channelId: id, name: name);
    }
    return now;
  }

  static Future<bool> confirmFollow(BuildContext context, String name) =>
      _confirm(
        context,
        title: context.l10n.followConfirmTitle(name: name),
        message: context.l10n.followDeepLinkBody,
        action: context.l10n.channelFollow,
      );

  static Future<bool> _confirmWebFallback(
    BuildContext context,
    FollowTarget target,
    bool following,
  ) => _confirm(
    context,
    title: context.l10n.followWebFallbackTitle,
    message: context.l10n.followWebFallbackBody(
      choice: '${target.name}${following ? 'Unfollow' : 'Follow'}',
    ),
    action: context.l10n.followWebFallbackAction,
  );

  static Future<bool> _confirmUnfollow(BuildContext context, String name) =>
      _confirm(
        context,
        title: context.l10n.unfollowConfirmTitle(name: name),
        message: context.l10n.unfollowConfirmBody,
        action: context.l10n.unfollowAction,
      );

  static Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String action,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => OnsetDialog(
        title: title,
        message: message,
        actions: [
          SheetButton(
            label: context.l10n.commonCancel,
            tone: SheetButtonTone.text,
            onPressed: () => Navigator.pop(context, false),
          ),
          SheetButton(
            key: confirmKey,
            label: action,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  static void showResult(
    BuildContext context,
    FollowResult result, {
    required String name,
    required bool followed,
  }) {
    final l = context.l10n;
    final text = result.succeeded
        ? followed
              ? l.followDone(name: name)
              : l.unfollowDone(name: name)
        : l.followError(status: result.name);
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  static Future<void> suggestAfterFollowing(
    BuildContext context, {
    required String channelId,
    required String name,
  }) async {
    final actions = actionsOf(context);
    if (actions == null) return;
    final suggestions = await actions.suggestionsAfterFollowing(channelId);
    if (suggestions.isEmpty || !context.mounted) return;
    await showOnsetSheet<void>(
      context: context,
      builder: (_) => FollowSuggestionsSheet(
        name: name,
        suggestions: suggestions,
        actions: actions,
      ),
    );
  }
}

class FollowSuggestionsSheet extends StatefulWidget {
  const FollowSuggestionsSheet({
    super.key,
    required this.name,
    required this.suggestions,
    required this.actions,
  });

  static const followAllKey = ValueKey('follow-all');
  static ValueKey<String> rowKey(String id) =>
      ValueKey('follow-suggestion-$id');

  final String name;
  final List<StreamTwitch> suggestions;
  final FollowActions actions;

  @override
  State<FollowSuggestionsSheet> createState() => _FollowSuggestionsSheetState();
}

class _FollowSuggestionsSheetState extends State<FollowSuggestionsSheet> {
  final _followed = <String>{};
  final _busy = <String>{};

  List<StreamTwitch> get _remaining => [
    for (final stream in widget.suggestions)
      if (!_followed.contains(stream.userId)) stream,
  ];

  Future<FollowResult> _followOne(StreamTwitch stream) async {
    setState(() => _busy.add(stream.userId));
    final result = await widget.actions.followChannel(stream.userId);
    if (mounted) {
      setState(() {
        _busy.remove(stream.userId);
        if (result.succeeded) _followed.add(stream.userId);
      });
    }
    return result;
  }

  Future<void> _follow(StreamTwitch stream) async {
    final result = await _followOne(stream);
    if (!mounted) return;
    FollowFlow.showResult(
      context,
      result,
      name: getReadableName(stream.userName, stream.userLogin),
      followed: true,
    );
  }

  Future<void> _followAll() async {
    final remaining = _remaining;
    if (remaining.isEmpty || _busy.isNotEmpty) return;
    final l = context.l10n;
    final confirmed = await FollowFlow._confirm(
      context,
      title: l.followAllConfirmTitle(count: remaining.length),
      message: l.followAllConfirmBody,
      action: l.followAll,
    );
    if (!confirmed || !mounted) return;
    var done = 0;
    FollowResult? failure;
    StreamTwitch? failed;
    for (final stream in remaining) {
      final result = await _followOne(stream);
      if (!mounted) return;
      if (result.succeeded) {
        done++;
      } else {
        failure = result;
        failed = stream;
        break;
      }
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            failure == null || failed == null
                ? l.followAllDone(count: done)
                : l.followAllStopped(
                    done: done,
                    name: getReadableName(failed.userName, failed.userLogin),
                    reason: l.followError(status: failure.name),
                  ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = SheetColors.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: ListView(
        shrinkWrap: true,
        primary: false,
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
            child: Semantics(
              header: true,
              child: Text(
                l.followSuggestionsTitle(name: widget.name),
                style: SheetText.subtitle.copyWith(color: colors.text),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              l.followSuggestionsSubtitle,
              style: SheetText.rowDetail.copyWith(color: colors.secondary),
            ),
          ),
          for (final stream in widget.suggestions) _row(stream),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SheetButton(
              key: FollowSuggestionsSheet.followAllKey,
              label: l.followAll,
              large: true,
              expand: true,
              onPressed: _remaining.isEmpty || _busy.isNotEmpty
                  ? null
                  : _followAll,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(StreamTwitch stream) {
    final l = context.l10n;
    final name = getReadableName(stream.userName, stream.userLogin);
    final followed = _followed.contains(stream.userId);
    final busy = _busy.contains(stream.userId);
    final detail = [
      if (stream.gameName.isNotEmpty) stream.gameName,
      l.streamViewers(count: stream.viewerCount),
    ].join(' · ');
    final colors = SheetColors.of(context);
    return Padding(
      key: FollowSuggestionsSheet.rowKey(stream.userId),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        spacing: 14,
        children: [
          InitialAvatar(name: name),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SheetText.row.copyWith(color: colors.text),
                ),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SheetText.rowDetail.copyWith(color: colors.secondary),
                ),
              ],
            ),
          ),
          if (busy)
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            SheetButton(
              label: followed ? l.channelFollowing : l.channelFollow,
              tone: followed ? SheetButtonTone.text : SheetButtonTone.primary,
              onPressed: followed ? null : () => unawaited(_follow(stream)),
            ),
        ],
      ),
    );
  }
}

class FollowPendingGate extends StatelessWidget {
  const FollowPendingGate({super.key, required this.id, required this.child});

  final String id;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Set<String>>(
    valueListenable: FollowFlow.pending,
    builder: (context, pending, child) {
      final busy = pending.contains(id);
      return Semantics(
        enabled: !busy,
        child: AbsorbPointer(
          absorbing: busy,
          child: AnimatedOpacity(
            opacity: busy ? 0.5 : 1,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            child: child,
          ),
        ),
      );
    },
    child: child,
  );
}
