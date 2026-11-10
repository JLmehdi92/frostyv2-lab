import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/follow_result.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/screens/onboarding/login_webview.dart';
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
    return actions != null && actions.isSignedIn ? actions : null;
  }

  static final pending = ValueNotifier<Set<String>>(const {});

  static bool isPending(String id) => pending.value.contains(id);

  static Future<void> Function(BuildContext context) openLogin =
      defaultOpenLogin;

  static Future<void> defaultOpenLogin(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => const LoginWebView()),
  );

  static FollowActions? _providedActions(BuildContext context) {
    try {
      return context.read<FollowActions?>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  static Future<bool?> toggle(
    BuildContext context, {
    required FollowTarget target,
    required String id,
    required String name,
    required bool? following,
    ValueChanged<bool>? onChanged,
  }) async {
    if (isPending(id)) return null;
    final root = Navigator.maybeOf(context, rootNavigator: true);
    final actions = _providedActions(context);
    if (actions == null || !actions.isSignedIn) {
      _showSignInNeeded(context);
      return null;
    }
    final unfollow = following == true;
    if (unfollow && !await _confirmUnfollow(context, name)) return null;
    if (isPending(id)) return null;
    pending.value = {...pending.value, id};
    final FollowResult result;
    try {
      result = await _send(actions, target, id, following, unfollow);
    } finally {
      pending.value = {...pending.value}..remove(id);
    }
    final shownFrom = context.mounted ? context : root?.context;
    if (shownFrom == null || !shownFrom.mounted) return null;
    showResult(
      shownFrom,
      result,
      name: name,
      followed: !unfollow,
      retry: () {
        final again = root?.context;
        if (again == null || !again.mounted) return;
        unawaited(
          toggle(
            again,
            target: target,
            id: id,
            name: name,
            following: unfollow,
            onChanged: onChanged,
          ),
        );
      },
    );
    if (!result.succeeded) return null;
    unawaited(HapticFeedback.lightImpact());
    onChanged?.call(!unfollow);
    return !unfollow;
  }

  static Future<FollowResult> _send(
    FollowActions actions,
    FollowTarget target,
    String id,
    bool? following,
    bool unfollow,
  ) async {
    final hadSession = actions.canFollowInApp;
    if (!await actions.connectWebSession()) return FollowResult.noWebSession;
    if (!hadSession || following == null) {
      final current = await switch (target) {
        FollowTarget.channel => actions.followsChannel(id),
        FollowTarget.category => actions.followsCategory(id),
      };
      if (current == !unfollow) return FollowResult.done;
    }
    return switch ((target, unfollow)) {
      (FollowTarget.channel, false) => actions.followChannel(id),
      (FollowTarget.channel, true) => actions.unfollowChannel(id),
      (FollowTarget.category, false) => actions.followCategory(id),
      (FollowTarget.category, true) => actions.unfollowCategory(id),
    };
  }

  static Future<bool?> followFromPrompt(
    BuildContext context, {
    required String id,
    required String name,
    required bool? following,
    required bool confirm,
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
      onChanged: onChanged,
    );
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

  static void _showSignInNeeded(BuildContext context) {
    _showSnackBar(
      context,
      context.l10n.followSignInNeeded,
      _logInAction(context),
    );
  }

  static SnackBarAction _logInAction(BuildContext context) {
    final navigator = Navigator.maybeOf(context, rootNavigator: true);
    return SnackBarAction(
      label: context.l10n.followLogInAction,
      onPressed: () {
        if (navigator != null && navigator.mounted) {
          unawaited(openLogin(navigator.context));
        }
      },
    );
  }

  static void _showSnackBar(
    BuildContext context,
    String text, [
    SnackBarAction? action,
  ]) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), action: action));
  }

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
    VoidCallback? retry,
  }) {
    final l = context.l10n;
    if (result.succeeded) {
      _showSnackBar(
        context,
        followed ? l.followDone(name: name) : l.unfollowDone(name: name),
      );
      return;
    }
    _showSnackBar(
      context,
      l.followError(status: result.name),
      _failureAction(context, result, retry),
    );
  }

  static SnackBarAction? _failureAction(
    BuildContext context,
    FollowResult result,
    VoidCallback? retry,
  ) {
    if (result.needsWebSession) return _logInAction(context);
    if (retry == null || !result.canRetry) return null;
    return SnackBarAction(label: context.l10n.commonRetry, onPressed: retry);
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
