import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:onset/apis/twitch_community_service.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/unban_request.dart';
import 'package:onset/screens/channel/chat/stores/chat_store.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:provider/provider.dart';

Future<void> showUnbanRequest(BuildContext context, ChatStore chatStore) {
  final community = context.read<TwitchCommunityService?>();
  final actions = context.read<TwitchViewerActionsService?>();
  final channelId = chatStore.channelId;
  final auth = context.authStore;
  String token() => auth.twitchWebToken ?? '';
  return showOnsetSheet<void>(
    context: context,
    builder: (_) => UnbanRequestSheet(
      load: () async =>
          community?.getUnbanRequest(channelId: channelId, authToken: token()),
      send: (message) async =>
          await actions?.createUnbanRequest(
            channelId: channelId,
            message: message,
            authToken: token(),
          ) ??
          const UnbanRequestOutcome(UnbanRequestResult.failed),
    ),
  );
}

class UnbanRequestSheet extends StatefulWidget {
  const UnbanRequestSheet({super.key, required this.load, required this.send});

  static const fieldKey = ValueKey('unban-request-field');
  static const sendKey = ValueKey('unban-request-send');
  static const noteKey = ValueKey('unban-request-note');

  final Future<UnbanRequestState?> Function() load;
  final Future<UnbanRequestOutcome> Function(String message) send;

  @override
  State<UnbanRequestSheet> createState() => _UnbanRequestSheetState();
}

class _UnbanRequestSheetState extends State<UnbanRequestSheet> {
  final _controller = TextEditingController();
  UnbanRequestState? _state;
  var _loading = true;
  var _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    unawaited(_reload());
  }

  Future<void> _reload() async {
    final state = await widget.load();
    if (!mounted) return;
    setState(() {
      _state = state;
      _loading = false;
    });
  }

  Future<void> _send() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() {
      _sending = true;
      _error = null;
    });
    final outcome = await widget.send(_controller.text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (outcome.result == UnbanRequestResult.sent) {
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.unbanRequestSent)));
      _controller.clear();
      await _reload();
      return;
    }
    setState(
      () => _error = l.unbanRequestFailed(
        code: outcome.result == UnbanRequestResult.signedOut
            ? 'signedOut'
            : outcome.code ?? 'other',
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = SheetColors.of(context);
    final state = _state;
    final detail = SheetText.rowDetail.copyWith(color: colors.secondary);
    final body = SheetText.row.copyWith(color: colors.text);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: ListView(
        shrinkWrap: true,
        primary: false,
        padding: EdgeInsets.fromLTRB(
          16,
          6,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        children: [
          Semantics(
            header: true,
            child: Text(
              l.unbanRequestTitle,
              style: SheetText.subtitle.copyWith(color: colors.text),
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (state == null)
            Text(l.unbanRequestUnavailable(reason: 'failed'), style: detail)
          else ...[
            if (state.hasRequest) ...[
              Text(
                l.unbanRequestStatus(
                  status: state.status!,
                  date: DateFormat.yMMMd(
                    l.localeName,
                  ).format(state.createdAt!.toLocal()),
                ),
                style: body,
              ),
              if (state.moderatorNote case final note?)
                Padding(
                  key: UnbanRequestSheet.noteKey,
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Text(l.unbanRequestNote, style: detail),
                      Text(note, style: body),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
            ],
            if (!state.enabled)
              Text(l.unbanRequestUnavailable(reason: 'disabled'), style: detail)
            else if (!state.canSend)
              state.status == 'PENDING'
                  ? const SizedBox.shrink()
                  : Text(
                      l.unbanRequestUnavailable(reason: 'wait'),
                      style: detail,
                    )
            else ...[
              SheetTextField(
                key: UnbanRequestSheet.fieldKey,
                controller: _controller,
                hint: l.unbanRequestHint,
                maxLength: TwitchViewerActionsService.maxUnbanMessageLength,
                counter: true,
              ),
              const SizedBox(height: 6),
              Text(l.unbanRequestOnce, style: detail),
              if (_error case final error?)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    error,
                    style: detail.copyWith(color: colors.danger),
                  ),
                ),
              const SizedBox(height: 14),
              SheetButton(
                key: UnbanRequestSheet.sendKey,
                label: l.unbanRequestSend,
                large: true,
                expand: true,
                onPressed: _sending || _controller.text.trim().isEmpty
                    ? null
                    : _send,
              ),
            ],
          ],
        ],
      ),
    );
  }
}
