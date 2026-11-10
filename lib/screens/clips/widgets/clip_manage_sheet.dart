import 'dart:async';

import 'package:flutter/material.dart' hide Clip;
import 'package:flutter/services.dart';
import 'package:onset/apis/twitch_account_gql_service.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/clip.dart';
import 'package:onset/models/profile_edit.dart';
import 'package:onset/screens/vod/widgets/video_glyph.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';

class ClipManageActions {
  const ClipManageActions({required this.rename, required this.delete});

  factory ClipManageActions.of(
    TwitchAccountGqlService service, {
    required String Function() token,
  }) => ClipManageActions(
    rename: (slug, title) =>
        service.renameClip(slug: slug, title: title, authToken: token()),
    delete: (slug) => service.deleteClip(slug: slug, authToken: token()),
  );

  final Future<AccountEditResult<String>> Function(String slug, String title)
  rename;
  final Future<AccountEditOutcome> Function(String slug) delete;
}

enum ClipChange { renamed, deleted }

Future<ClipChange?> showClipManageSheet(
  BuildContext context, {
  required String slug,
  required String title,
  required ClipManageActions actions,
}) async {
  final choice = await showOnsetSheet<ClipChange>(
    context: context,
    builder: (sheetContext) => _ClipManageSheet(title: title),
  );
  if (choice == null || !context.mounted) return null;
  return switch (choice) {
    ClipChange.renamed => renameClip(
      context,
      slug: slug,
      title: title,
      rename: actions.rename,
    ),
    ClipChange.deleted => _deleteClip(context, slug: slug, actions: actions),
  };
}

Future<ClipChange?> renameClip(
  BuildContext context, {
  required String slug,
  required String title,
  required Future<AccountEditResult<String>> Function(String, String) rename,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l = context.l10n;
  final result = await showDialog<AccountEditResult<String>>(
    context: context,
    barrierColor: kSheetScrim,
    builder: (_) =>
        ClipRenameDialog(initial: title, save: (text) => rename(slug, text)),
  );
  if (result == null) return null;
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          result.succeeded
              ? l.clipRenamed
              : l.clipActionFailed(status: result.outcome.name),
        ),
      ),
    );
  return result.succeeded ? ClipChange.renamed : null;
}

Future<ClipChange?> _deleteClip(
  BuildContext context, {
  required String slug,
  required ClipManageActions actions,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l = context.l10n;
  final outcome = await showDialog<AccountEditOutcome>(
    context: context,
    barrierColor: kSheetScrim,
    builder: (_) => _ClipDeleteDialog(delete: () => actions.delete(slug)),
  );
  if (outcome == null) return null;
  final deleted = outcome == AccountEditOutcome.done;
  if (deleted) unawaited(HapticFeedback.mediumImpact());
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          deleted ? l.clipDeleted : l.clipActionFailed(status: outcome.name),
        ),
      ),
    );
  return deleted ? ClipChange.deleted : null;
}

class _ClipManageSheet extends StatelessWidget {
  const _ClipManageSheet({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = SheetColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            title.isEmpty ? l.clipUntitled : title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: SheetText.title.copyWith(color: colors.text),
          ),
        ),
        SheetRow(
          key: ClipManageKeys.rename,
          leading: VideoGlyph(VideoGlyphKind.pencil, color: colors.text),
          label: l.clipRename,
          end: SheetRowEnd.chevron,
          onTap: () => Navigator.pop(context, ClipChange.renamed),
        ),
        SheetRow(
          key: ClipManageKeys.delete,
          glyph: SheetGlyphKind.trash,
          label: l.clipDelete,
          danger: true,
          onTap: () => Navigator.pop(context, ClipChange.deleted),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

abstract final class ClipManageKeys {
  static const rename = ValueKey('clip-manage-rename');
  static const delete = ValueKey('clip-manage-delete');
  static const save = ValueKey('clip-rename-save');
  static const confirmDelete = ValueKey('clip-delete-confirm');
}

class ClipRenameDialog extends StatefulWidget {
  const ClipRenameDialog({
    super.key,
    required this.initial,
    required this.save,
  });

  final String initial;
  final Future<AccountEditResult<String>> Function(String title) save;

  @override
  State<ClipRenameDialog> createState() => _ClipRenameDialogState();
}

class _ClipRenameDialogState extends State<ClipRenameDialog> {
  late final _title = TextEditingController(text: widget.initial);
  var _saving = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  bool get _valid {
    final text = _title.text.trim();
    return text.isNotEmpty &&
        text.length <= TwitchAccountGqlService.maxClipTitleLength;
  }

  Future<void> _save() async {
    if (_saving || !_valid) return;
    setState(() => _saving = true);
    final result = await widget.save(_title.text);
    if (mounted) Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return OnsetDialog(
      title: l.clipRenameTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetTextField(
            controller: _title,
            label: l.clipRenameField,
            autofocus: true,
            maxLength: TwitchAccountGqlService.maxClipTitleLength,
            counter: true,
            onChanged: (_) => setState(() {}),
          ),
          SheetStatusLine(busy: _saving, padding: EdgeInsets.zero),
        ],
      ),
      actions: [
        SheetButton(
          label: l.commonCancel,
          tone: SheetButtonTone.text,
          onPressed: _saving ? null : () => Navigator.pop(context),
        ),
        SheetButton(
          key: ClipManageKeys.save,
          label: l.clipRenameSave,
          onPressed: _saving || !_valid ? null : _save,
        ),
      ],
    );
  }
}

class _ClipDeleteDialog extends StatefulWidget {
  const _ClipDeleteDialog({required this.delete});

  final Future<AccountEditOutcome> Function() delete;

  @override
  State<_ClipDeleteDialog> createState() => _ClipDeleteDialogState();
}

class _ClipDeleteDialogState extends State<_ClipDeleteDialog> {
  var _deleting = false;

  Future<void> _delete() async {
    if (_deleting) return;
    setState(() => _deleting = true);
    final outcome = await widget.delete();
    if (mounted) Navigator.pop(context, outcome);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return OnsetDialog(
      title: l.clipDeleteTitle,
      message: l.clipDeleteBody,
      content: SheetStatusLine(busy: _deleting, padding: EdgeInsets.zero),
      actions: [
        SheetButton(
          label: l.commonCancel,
          tone: SheetButtonTone.text,
          onPressed: _deleting ? null : () => Navigator.pop(context),
        ),
        SheetButton(
          key: ClipManageKeys.confirmDelete,
          label: l.clipDelete,
          onPressed: _deleting ? null : _delete,
        ),
      ],
    );
  }
}

extension ClipManageable on Clip {
  bool get isManageable => isValidClipSlug(slug);
}
