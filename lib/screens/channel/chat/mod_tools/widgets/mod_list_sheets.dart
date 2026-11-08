import 'package:flutter/material.dart';
import 'package:onset/apis/twitch_mod_api.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/moderation.dart';
import 'package:onset/screens/channel/chat/chat_commands.dart';
import 'package:onset/screens/channel/chat/mod_tools/stores/mod_tools_store.dart';
import 'package:onset/screens/channel/chat/mod_tools/widgets/mod_sheet_parts.dart';
import 'package:onset/screens/channel/chat/stores/chat_store.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';
import 'package:onset/widgets/twitch_web_page.dart';

abstract class _ModListState<W extends StatefulWidget, T> extends State<W>
    with ModActionState<W> {
  List<T>? items;
  String? loadFailure;

  ChatStore get chat;

  String get moderatorId => chat.auth.user.details?.id ?? '';

  Future<List<T>> load();

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() => loadFailure = null);
    try {
      final loaded = await load();
      if (mounted) setState(() => items = loaded);
    } catch (error) {
      debugPrint('Mod tools list failed: $error');
      if (mounted) {
        setState(() => loadFailure = modToolsFailure(error, 'load'));
      }
    }
  }

  List<Widget> listState({
    required String empty,
    required Widget Function(T item) tile,
  }) {
    final l = context.l10n;
    final items = this.items;
    if (loadFailure case final failure?) {
      return [
        ModNote(failure),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: SheetButton(
              label: l.commonRetry,
              tone: SheetButtonTone.text,
              onPressed: reload,
            ),
          ),
        ),
      ];
    }
    if (items == null) {
      return const [
        Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (items.isEmpty) return [ModNote(empty)];
    return [for (final item in items) tile(item)];
  }
}

class RoleListSheet extends StatefulWidget {
  const RoleListSheet({super.key, required this.chatStore, required this.role});

  final ChatStore chatStore;
  final ChannelRole role;

  @override
  State<RoleListSheet> createState() => _RoleListSheetState();
}

class _RoleListSheetState
    extends _ModListState<RoleListSheet, ChannelRoleUser> {
  @override
  ChatStore get chat => widget.chatStore;

  bool get _mods => widget.role == ChannelRole.moderator;

  @override
  Future<List<ChannelRoleUser>> load() => chat.twitchApi.moderation
      .getRoleUsers(broadcasterId: chat.channelId, role: widget.role);

  Future<bool> _add(String login) async {
    final ok = await _change(login.replaceFirst('@', ''), granted: true);
    if (ok) await reload();
    return ok;
  }

  Future<bool> _change(String login, {required bool granted}) async {
    final outcome = await chat.moderate(
      RoleCommand(login.toLowerCase(), widget.role, granted: granted),
    );
    if (!mounted) return false;
    setState(() {
      statusOk = outcome?.ok ?? false;
      statusMessage = outcome?.message;
    });
    return outcome?.ok ?? false;
  }

  Future<void> _remove(ChannelRoleUser user) async {
    final l = context.l10n;
    final change = _mods ? 'removeModerator' : 'removeVip';
    final confirmed = await confirmModAction(
      context,
      title: l.modToolsRoleConfirmTitle(change: change),
      message: l.modToolsRoleConfirmMessage(
        change: change,
        name: user.displayName,
      ),
      confirmLabel: l.modToolsRemove,
      danger: true,
    );
    if (!confirmed || !mounted) return;
    if (await _change(user.userLogin, granted: false)) await reload();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ModSheetBody(
      children: [
        ModSheetTitle(
          _mods ? l.modToolsModerators : l.modToolsVips,
          caption: switch (items?.length) {
            null => null,
            final count when _mods => l.modToolsModeratorCount(count: count),
            final count => l.modToolsVipCount(count: count),
          },
        ),
        ModAddField(
          label: l.modToolsUserLabel,
          actionLabel: l.modToolsAdd,
          maxLength: 26,
          onSubmit: _add,
        ),
        statusLine(),
        ...listState(
          empty: l.chatModRoleListEmpty(role: widget.role.name),
          tile: (user) => ModItemTile(
            title: user.displayName,
            subtitle: user.displayName.toLowerCase() == user.userLogin
                ? null
                : user.userLogin,
            actions: [
              ModCompactButton(
                label: l.modToolsRemove,
                danger: true,
                onPressed: () => _remove(user),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class BlockedTermsSheet extends StatefulWidget {
  const BlockedTermsSheet({super.key, required this.chatStore});

  final ChatStore chatStore;

  @override
  State<BlockedTermsSheet> createState() => _BlockedTermsSheetState();
}

class _BlockedTermsSheetState
    extends _ModListState<BlockedTermsSheet, BlockedTerm> {
  @override
  ChatStore get chat => widget.chatStore;

  @override
  Future<List<BlockedTerm>> load() => chat.twitchApi.moderation.getBlockedTerms(
    broadcasterId: chat.channelId,
    moderatorId: moderatorId,
  );

  Future<bool> _add(String text) async {
    final l = context.l10n;
    if (singleLine(text).runes.length < ModTextLimits.blockedTermMin) {
      setState(() {
        statusOk = false;
        statusMessage = l.modToolsBlockedTermTooShort;
      });
      return false;
    }
    BlockedTerm? added;
    final ok = await runModAction(
      () async => added = await chat.twitchApi.moderation.addBlockedTerm(
        broadcasterId: chat.channelId,
        moderatorId: moderatorId,
        text: text,
      ),
      command: 'blockTerm',
      success: l.modToolsBlockedTermAdded,
    );
    if (ok && added != null && mounted) {
      setState(
        () => items = [added!, ...?items?.where((t) => t.id != added!.id)],
      );
    }
    return ok;
  }

  Future<void> _remove(BlockedTerm term) async {
    final l = context.l10n;
    final ok = await runModAction(
      () => chat.twitchApi.moderation.removeBlockedTerm(
        broadcasterId: chat.channelId,
        moderatorId: moderatorId,
        termId: term.id,
      ),
      command: 'unblockTerm',
      success: l.modToolsBlockedTermRemoved,
    );
    if (ok && mounted) {
      setState(() => items = items?.where((t) => t.id != term.id).toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ModSheetBody(
      children: [
        ModSheetTitle(
          l.modToolsBlockedTerms,
          caption: l.modToolsBlockedTermsCaption,
        ),
        ModAddField(
          label: l.modToolsTermLabel,
          actionLabel: l.modToolsAdd,
          maxLength: ModTextLimits.blockedTerm,
          enabled: !busy,
          onSubmit: _add,
        ),
        statusLine(),
        ...listState(
          empty: l.modToolsBlockedTermsEmpty,
          tile: (term) => ModItemTile(
            leading: SheetGlyph(
              SheetGlyphKind.block,
              color: SheetColors.of(context).secondary,
            ),
            title: term.text,
            subtitle: term.expiresAt == null ? null : l.modToolsTermTemporary,
            actions: [
              ModCompactButton(
                label: l.modToolsRemove,
                danger: true,
                onPressed: busy ? null : () => _remove(term),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class UnbanRequestsSheet extends StatefulWidget {
  const UnbanRequestsSheet({super.key, required this.chatStore});

  final ChatStore chatStore;

  @override
  State<UnbanRequestsSheet> createState() => _UnbanRequestsSheetState();
}

class _UnbanRequestsSheetState
    extends _ModListState<UnbanRequestsSheet, UnbanRequest> {
  @override
  ChatStore get chat => widget.chatStore;

  @override
  Future<List<UnbanRequest>> load() =>
      chat.twitchApi.moderation.getPendingUnbanRequests(
        broadcasterId: chat.channelId,
        moderatorId: moderatorId,
      );

  Future<void> _resolve(UnbanRequest request, {required bool approve}) async {
    final l = context.l10n;
    final note = await _askResolution(request, approve: approve);
    if (note == null || !mounted) return;
    final ok = await runModAction(
      () => chat.twitchApi.moderation.resolveUnbanRequest(
        broadcasterId: chat.channelId,
        moderatorId: moderatorId,
        requestId: request.id,
        approve: approve,
        resolution: note,
      ),
      command: approve ? 'approveUnban' : 'denyUnban',
      success: l.modToolsUnbanResolved(
        decision: approve ? 'approved' : 'denied',
        name: request.displayName,
      ),
    );
    if (ok && mounted) {
      setState(() => items = items?.where((r) => r.id != request.id).toList());
    }
  }

  Future<String?> _askResolution(
    UnbanRequest request, {
    required bool approve,
  }) => showDialog<String>(
    context: context,
    builder: (context) =>
        _ResolutionDialog(name: request.displayName, approve: approve),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ModSheetBody(
      children: [
        ModSheetTitle(l.modToolsUnbanRequests, caption: l.modToolsUnbanCaption),
        statusLine(),
        ...listState(
          empty: l.modToolsUnbanEmpty,
          tile: (request) => ModItemTile(
            title: request.displayName,
            subtitle: request.createdAt.isEmpty
                ? null
                : l.modToolsRequestedOn(
                    date: _date(context, request.createdAt),
                  ),
            body: request.text,
            actions: [
              ModCompactButton(
                label: l.modToolsApprove,
                primary: true,
                onPressed: busy ? null : () => _resolve(request, approve: true),
              ),
              ModCompactButton(
                label: l.modToolsDeny,
                danger: true,
                onPressed: busy
                    ? null
                    : () => _resolve(request, approve: false),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _date(BuildContext context, String iso) {
  final date = DateTime.tryParse(iso);
  if (date == null) return iso;
  return MaterialLocalizations.of(context).formatMediumDate(date.toLocal());
}

class _ResolutionDialog extends StatefulWidget {
  const _ResolutionDialog({required this.name, required this.approve});

  final String name;
  final bool approve;

  @override
  State<_ResolutionDialog> createState() => _ResolutionDialogState();
}

class _ResolutionDialogState extends State<_ResolutionDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final decision = widget.approve ? 'approved' : 'denied';
    return OnsetDialog(
      title: l.modToolsUnbanDialogTitle(decision: decision),
      message: l.modToolsUnbanDialogMessage(
        decision: decision,
        name: widget.name,
      ),
      content: SheetTextField(
        controller: _controller,
        label: l.modToolsUnbanNoteLabel,
        maxLength: ModTextLimits.resolution,
        counter: true,
      ),
      actions: [
        SheetButton(
          label: l.commonCancel,
          tone: SheetButtonTone.text,
          onPressed: () => Navigator.pop(context),
        ),
        SheetButton(
          label: widget.approve ? l.modToolsApprove : l.modToolsDeny,
          tone: widget.approve
              ? SheetButtonTone.primary
              : SheetButtonTone.danger,
          onPressed: () => Navigator.pop(context, singleLine(_controller.text)),
        ),
      ],
    );
  }
}

class RedemptionsSheet extends StatefulWidget {
  const RedemptionsSheet({super.key, required this.chatStore});

  final ChatStore chatStore;

  @override
  State<RedemptionsSheet> createState() => _RedemptionsSheetState();
}

class _RedemptionsSheetState
    extends _ModListState<RedemptionsSheet, RewardRedemption> {
  @override
  ChatStore get chat => widget.chatStore;

  @override
  Future<List<RewardRedemption>> load() => chat.twitchApi.moderation
      .getPendingRedemptions(broadcasterId: chat.channelId);

  Future<void> _resolve(
    RewardRedemption redemption,
    RedemptionDecision decision,
  ) async {
    final l = context.l10n;
    final refund = decision == RedemptionDecision.canceled;
    if (refund) {
      final confirmed = await confirmModAction(
        context,
        title: l.modToolsRefundTitle,
        message: l.modToolsRefundMessage(
          name: redemption.displayName,
          reward: redemption.reward.title,
        ),
        confirmLabel: l.modToolsRefund,
        danger: true,
      );
      if (!confirmed || !mounted) return;
    }
    final ok = await runModAction(
      () => chat.twitchApi.moderation.resolveRedemption(
        broadcasterId: chat.channelId,
        rewardId: redemption.reward.id,
        redemptionId: redemption.id,
        decision: decision,
      ),
      command: refund ? 'refund' : 'fulfil',
      success: refund ? l.modToolsRefunded : l.modToolsFulfilled,
    );
    if (ok && mounted) {
      setState(
        () => items = items?.where((r) => r.id != redemption.id).toList(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ModSheetBody(
      children: [
        ModSheetTitle(
          l.modToolsRewardRequests,
          caption: l.modToolsRewardRequestsCaption,
        ),
        statusLine(),
        ...listState(
          empty: l.modToolsRewardRequestsEmpty,
          tile: (redemption) => ModItemTile(
            title: redemption.displayName,
            subtitle: l.modToolsRedemptionReward(
              reward: redemption.reward.title,
              cost: redemption.reward.cost,
            ),
            body: redemption.userInput.isEmpty ? null : redemption.userInput,
            actions: [
              ModCompactButton(
                label: l.modToolsFulfil,
                primary: true,
                onPressed: busy
                    ? null
                    : () => _resolve(redemption, RedemptionDecision.fulfilled),
              ),
              ModCompactButton(
                label: l.modToolsRefund,
                danger: true,
                onPressed: busy
                    ? null
                    : () => _resolve(redemption, RedemptionDecision.canceled),
              ),
            ],
          ),
        ),
        const ModHairline(),
        SheetRow(
          glyph: SheetGlyphKind.coin,
          label: l.modToolsRewardQueueWeb,
          detail: l.chatDetailsOpensTwitch,
          end: SheetRowEnd.external,
          onTap: () => TwitchWebPage.open(
            context,
            title: l.modToolsRewardRequests,
            url: Uri.https(
              'www.twitch.tv',
              '/popout/${chat.channelName}/reward-queue',
            ),
          ),
        ),
      ],
    );
  }
}
