import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_social_service.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/channel.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/whispers/whispers_screen.dart';
import 'package:onset/stores/whisper_store.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';
import 'package:provider/provider.dart';

Future<void> showWhisperThreadActions(
  BuildContext context, {
  required WhisperStore store,
  required WhisperThread thread,
  VoidCallback? onHidden,
}) {
  final l = context.l10n;
  return showOnsetSheet<void>(
    context: context,
    builder: (sheetContext) {
      final muted = store.isMuted(thread.userId);
      final archived = store.isArchived(thread.userId);
      return ListView(
        shrinkWrap: true,
        children: [
          SheetSectionLabel(thread.displayName),
          SheetRow(
            key: const ValueKey('whisper-action-mute'),
            label: muted ? l.whisperUnmute : l.whisperMute,
            glyph: SheetGlyphKind.bell,
            onTap: () {
              store.toggleMute(thread.userId);
              Navigator.pop(sheetContext);
            },
          ),
          SheetRow(
            key: const ValueKey('whisper-action-archive'),
            label: archived ? l.whisperUnarchive : l.whisperArchive,
            leading: const Icon(Icons.archive_outlined, size: 20),
            onTap: () {
              archived
                  ? store.unarchive(thread.userId)
                  : store.archive(thread.userId);
              Navigator.pop(sheetContext);
            },
          ),
          if (whisperAllowanceRemover(context, store, thread)
              case final remove?)
            SheetRow(
              key: const ValueKey('whisper-action-stop-replies'),
              label: l.whisperStopReplies(name: thread.displayName),
              glyph: SheetGlyphKind.block,
              onTap: () async {
                Navigator.pop(sheetContext);
                await stopWhisperReplies(
                  context,
                  name: thread.displayName,
                  remove: remove,
                );
              },
            ),
          SheetRow(
            key: const ValueKey('whisper-action-hide'),
            label: l.whisperHide,
            glyph: SheetGlyphKind.trash,
            danger: true,
            onTap: () async {
              Navigator.pop(sheetContext);
              final confirmed = await confirmHideWhisperThread(
                context,
                name: thread.displayName,
              );
              if (!confirmed) return;
              store.hide(thread.userId);
              onHidden?.call();
            },
          ),
        ],
      );
    },
  );
}

Future<ViewerActionOutcome> Function()? whisperAllowanceRemover(
  BuildContext context,
  WhisperStore store,
  WhisperThread thread,
) {
  final threadId = store.remoteThreadId(thread.userId);
  final social = context.read<TwitchSocialService?>();
  final token = context.read<AuthStore?>()?.twitchWebToken;
  if (threadId == null || social == null || token == null || token.isEmpty) {
    return null;
  }
  return () =>
      social.removeWhisperAllowance(threadId: threadId, authToken: token);
}

Future<void> stopWhisperReplies(
  BuildContext context, {
  required String name,
  required Future<ViewerActionOutcome> Function() remove,
}) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => OnsetDialog(
      title: l.whisperStopRepliesTitle(name: name),
      message: l.whisperStopRepliesBody(name: name),
      actions: [
        SheetButton(
          label: l.commonCancel,
          tone: SheetButtonTone.text,
          onPressed: () => Navigator.pop(dialogContext, false),
        ),
        SheetButton(
          key: const ValueKey('whisper-stop-replies-confirm'),
          label: l.whisperStopRepliesConfirm,
          tone: SheetButtonTone.danger,
          onPressed: () => Navigator.pop(dialogContext, true),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  final outcome = await remove();
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(l.viewerActionResult(status: outcome.name))),
    );
}

Future<bool> confirmHideWhisperThread(
  BuildContext context, {
  required String name,
}) async {
  final l = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => OnsetDialog(
      title: l.whisperHideConfirmTitle,
      message: l.whisperHideConfirmMessage(name: name),
      actions: [
        SheetButton(
          label: l.commonCancel,
          tone: SheetButtonTone.text,
          onPressed: () => Navigator.pop(dialogContext, false),
        ),
        SheetButton(
          key: const ValueKey('whisper-hide-confirm'),
          label: l.whisperHideConfirm,
          tone: SheetButtonTone.danger,
          onPressed: () => Navigator.pop(dialogContext, true),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

Future<WhisperTarget?> pickWhisperTarget(
  BuildContext context, {
  required String? me,
}) => showOnsetSheet<WhisperTarget>(
  context: context,
  builder: (_) =>
      NewWhisperSheet(search: context.read<TwitchApi>().searchChannels, me: me),
);

class NewWhisperSheet extends StatefulWidget {
  const NewWhisperSheet({super.key, required this.search, this.me});

  final Future<List<ChannelQuery>> Function({required String query}) search;
  final String? me;

  static const debounce = Duration(milliseconds: 300);

  @override
  State<NewWhisperSheet> createState() => _NewWhisperSheetState();
}

class _NewWhisperSheetState extends State<NewWhisperSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  var _query = '';
  List<ChannelQuery> _results = const [];
  var _failed = false;
  var _searching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _changed(String text) {
    _debounce?.cancel();
    final query = text.trim();
    if (query.isEmpty) {
      setState(() {
        _query = '';
        _results = const [];
        _failed = false;
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(NewWhisperSheet.debounce, () => _run(query));
  }

  Future<void> _run(String query) async {
    try {
      final results = await widget.search(query: query);
      if (!mounted || _controller.text.trim() != query) return;
      setState(() {
        _query = query;
        _results = results.where((c) => c.id != widget.me).toList();
        _failed = false;
        _searching = false;
      });
    } catch (e) {
      debugPrint('Whisper search failed: $e');
      if (!mounted || _controller.text.trim() != query) return;
      setState(() {
        _query = query;
        _results = const [];
        _failed = true;
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = SheetColors.of(context);
    final status = _failed
        ? l.whispersNewFailed
        : !_searching && _query.isNotEmpty && _results.isEmpty
        ? l.whispersNewNoMatch(query: _query)
        : null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetSectionLabel(l.whispersNew),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SheetTextField(
              key: const ValueKey('new-whisper-search'),
              controller: _controller,
              autofocus: true,
              hint: l.whispersNewSearch,
              onChanged: _changed,
            ),
          ),
          if (status != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text(
                status,
                style: SheetText.body.copyWith(color: colors.secondary),
              ),
            ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final channel in _results)
                  SheetRow(
                    key: ValueKey('new-whisper-${channel.id}'),
                    label: channel.displayName,
                    detail:
                        channel.broadcasterLogin ==
                            channel.displayName.toLowerCase()
                        ? null
                        : channel.broadcasterLogin,
                    leading: InitialAvatar(name: channel.displayName),
                    onTap: () => Navigator.pop(
                      context,
                      WhisperTarget(
                        userId: channel.id,
                        login: channel.broadcasterLogin,
                        displayName: channel.displayName,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
