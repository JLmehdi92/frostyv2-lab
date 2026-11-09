import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/chat_identity.dart';
import 'package:onset/widgets/onset_cached_network_image.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';

typedef SelectChatBadge =
    Future<ViewerActionOutcome> Function(
      ChatBadgeScope scope,
      ChatBadgeChoice? badge,
    );

class ChatBadgeSheet extends StatefulWidget {
  const ChatBadgeSheet({
    super.key,
    required this.load,
    required this.select,
    required this.setFlairHidden,
  });

  static ValueKey<String> choiceKey(ChatBadgeScope scope, String key) =>
      ValueKey('chat-badge-${scope.name}-$key');
  static const flairKey = ValueKey('chat-badge-flair');
  static const confirmKey = ValueKey('chat-badge-confirm');

  final Future<ChatIdentity?> Function() load;
  final SelectChatBadge select;
  final Future<ViewerActionOutcome> Function(bool hidden) setFlairHidden;

  @override
  State<ChatBadgeSheet> createState() => _ChatBadgeSheetState();
}

class _ChatBadgeSheetState extends State<ChatBadgeSheet> {
  ChatIdentity? _identity;
  var _loading = true;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    final identity = await widget.load();
    if (!mounted) return;
    setState(() {
      _identity = identity;
      _loading = false;
    });
  }

  Future<bool> _confirm(String title, String body) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => OnsetDialog(
        title: title,
        message: body,
        actions: [
          SheetButton(
            label: l.commonCancel,
            tone: SheetButtonTone.text,
            onPressed: () => Navigator.pop(context, false),
          ),
          SheetButton(
            key: ChatBadgeSheet.confirmKey,
            label: l.chatBadgeChange,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _apply(
    Future<ViewerActionOutcome> Function() change,
    Future<ViewerActionOutcome> Function() undo,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l = context.l10n;
    setState(() => _busy = true);
    final outcome = await change();
    if (!mounted) return;
    setState(() => _busy = false);
    final done = outcome == ViewerActionOutcome.done;
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            done
                ? l.chatBadgeChanged
                : outcome == ViewerActionOutcome.signedOut
                ? l.chatBadgeLogIn
                : l.chatBadgeFailed,
          ),
          action: done
              ? SnackBarAction(
                  label: l.commonUndo,
                  onPressed: () => unawaited(_undo(undo)),
                )
              : null,
        ),
      );
    if (done) await _reload();
  }

  Future<void> _undo(Future<ViewerActionOutcome> Function() undo) async {
    final outcome = await undo();
    if (mounted && outcome == ViewerActionOutcome.done) await _reload();
  }

  Future<void> _pick(ChatBadgeScope scope, ChatBadgeChoice? badge) async {
    final identity = _identity;
    if (identity == null || _busy) return;
    final previous = identity.selectedFor(scope);
    if (previous?.key == badge?.key) return;
    final l = context.l10n;
    final ok = await _confirm(
      l.chatBadgeConfirm(
        none: badge == null ? 'yes' : 'no',
        badge: badge?.title ?? '',
      ),
      l.chatBadgeConfirmBody(scope: scope.name),
    );
    if (!ok || !mounted) return;
    await _apply(
      () => widget.select(scope, badge),
      () => widget.select(scope, previous),
    );
  }

  Future<void> _toggleFlair(bool hide) async {
    if (_busy) return;
    final l = context.l10n;
    final ok = await _confirm(
      l.chatBadgeFlairConfirm(hide: hide ? 'yes' : 'no'),
      l.chatBadgeFlairBody,
    );
    if (!ok || !mounted) return;
    await _apply(
      () => widget.setFlairHidden(hide),
      () => widget.setFlairHidden(!hide),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = SheetColors.of(context);
    final identity = _identity;
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
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
            child: Semantics(
              header: true,
              child: Text(
                l.chatBadgeTitle,
                style: SheetText.subtitle.copyWith(color: colors.text),
              ),
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (identity == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Text(
                l.chatBadgeLoadFailed,
                style: SheetText.rowDetail.copyWith(color: colors.secondary),
              ),
            )
          else ...[
            for (final scope in ChatBadgeScope.values)
              if (identity.badgesFor(scope).isNotEmpty) ...[
                SheetSectionLabel(
                  scope == ChatBadgeScope.channel
                      ? l.chatBadgeChannel
                      : l.chatBadgeGlobal,
                ),
                _choice(scope, null, identity),
                for (final badge in identity.badgesFor(scope))
                  _choice(scope, badge, identity),
              ],
            if (identity.flairHidden case final hidden?)
              MergeSemantics(
                child: SheetRow(
                  key: ChatBadgeSheet.flairKey,
                  glyph: SheetGlyphKind.star,
                  label: l.chatBadgeHideFlair,
                  detail: l.chatBadgeHideFlairDetail,
                  trailing: OnsetSwitch(
                    value: hidden,
                    onChanged: _busy ? null : _toggleFlair,
                  ),
                  onTap: _busy ? null : () => _toggleFlair(!hidden),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _choice(
    ChatBadgeScope scope,
    ChatBadgeChoice? badge,
    ChatIdentity identity,
  ) {
    final selected = identity.selectedFor(scope)?.key == badge?.key;
    final image = badge?.imageUrl;
    return SheetRow(
      key: ChatBadgeSheet.choiceKey(scope, badge?.key ?? 'none'),
      leading: SizedBox.square(
        dimension: 22,
        child: image == null
            ? null
            : OnsetCachedNetworkImage(imageUrl: image, width: 22, height: 22),
      ),
      label: badge?.title ?? context.l10n.chatBadgeNone,
      trailing: selected
          ? SheetGlyph(
              SheetGlyphKind.check,
              color: SheetColors.accentOf(context),
            )
          : null,
      onTap: _busy ? null : () => unawaited(_pick(scope, badge)),
    );
  }
}
