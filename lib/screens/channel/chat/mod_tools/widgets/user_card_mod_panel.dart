import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/apis/twitch_mod_api.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/channel/chat/chat_commands.dart';
import 'package:onset/screens/channel/chat/mod_tools/mod_features.dart';
import 'package:onset/screens/channel/chat/mod_tools/stores/mod_tools_store.dart';
import 'package:onset/screens/channel/chat/mod_tools/widgets/mod_sheet_parts.dart';
import 'package:onset/screens/channel/chat/stores/chat_store.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';

enum UserModPill { banned, timedOut, warned, monitored, restricted }

List<UserModPill> userModPills(UserModStatus status, DateTime now) => [
  if (status.banned) UserModPill.banned,
  if (status.timedOutAt(now)) UserModPill.timedOut,
  if (status.warned) UserModPill.warned,
  if (status.suspicion == SuspiciousStatus.monitored) UserModPill.monitored,
  if (status.suspicion == SuspiciousStatus.restricted) UserModPill.restricted,
];

class UserCardModPills extends StatefulWidget {
  const UserCardModPills({
    super.key,
    required this.tools,
    required this.userId,
    this.dense = false,
  });

  final ModToolsStore tools;
  final String userId;
  final bool dense;

  @override
  State<UserCardModPills> createState() => _UserCardModPillsState();
}

class _UserCardModPillsState extends State<UserCardModPills> {
  @override
  void initState() {
    super.initState();
    widget.tools.loadBan(widget.userId);
  }

  @override
  Widget build(BuildContext context) => Observer(
    builder: (context) {
      final pills = userModPills(
        widget.tools.statusOf(widget.userId),
        DateTime.now(),
      );
      if (pills.isEmpty) return const SizedBox.shrink();
      final colors = SheetColors.of(context);
      final l = context.l10n;
      return Padding(
        padding: EdgeInsets.fromLTRB(16, widget.dense ? 8 : 10, 16, 0),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final pill in pills)
              Container(
                height: widget.dense ? 24 : 26,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: ShapeDecoration(
                  color: colors.dangerTint,
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: colors.danger.withValues(alpha: 0.45),
                      width: OnsetTokens.hairlineWidth,
                    ),
                  ),
                ),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    l.modToolsUserPill(pill: pill.name),
                    style: SheetText.pill.copyWith(
                      fontSize: widget.dense ? 11.5 : 12,
                      color: colors.danger,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class UserCardModActions extends StatefulWidget {
  const UserCardModActions({
    super.key,
    required this.chatStore,
    required this.login,
    required this.userId,
    required this.name,
    required this.isModerator,
    required this.isVip,
  });

  final ChatStore chatStore;
  final String login;
  final String userId;
  final String name;
  final bool isModerator;
  final bool isVip;

  @override
  State<UserCardModActions> createState() => _UserCardModActionsState();
}

class _UserCardModActionsState extends State<UserCardModActions>
    with ModActionState<UserCardModActions> {
  ChatStore get _chat => widget.chatStore;
  ModToolsStore get _tools => _chat.modTools;

  Future<void> _run(
    ModerationCommand command, {
    String? confirmTitle,
    String? confirmMessage,
    String? confirmLabel,
  }) async {
    if (confirmTitle != null) {
      final confirmed = await confirmModAction(
        context,
        title: confirmTitle,
        message: confirmMessage!,
        confirmLabel: confirmLabel!,
        danger: true,
      );
      if (!confirmed || !mounted) return;
    }
    setState(() {
      busy = true;
      statusMessage = null;
    });
    final outcome = await _chat.moderate(command, userId: widget.userId);
    if (!mounted) return;
    setState(() {
      busy = false;
      statusOk = outcome?.ok ?? true;
      statusMessage = outcome?.message;
    });
  }

  Widget _row(
    ModFeature feature, {
    required SheetGlyphKind glyph,
    required String label,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    if (!_tools.shows(feature)) return const SizedBox.shrink();
    if (_tools.needsLogin(feature)) {
      return SheetRow(
        glyph: glyph,
        label: label,
        detail: context.l10n.modToolsLogInToEnable,
        end: SheetRowEnd.chevron,
        onTap: () => openModLogin(context, _chat.auth, feature.scopes),
      );
    }
    return SheetRow(
      glyph: glyph,
      label: label,
      danger: danger,
      onTap: _tools.canUse(feature) && !busy ? onTap : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final login = widget.login.toLowerCase();
    final name = widget.name;
    return Observer(
      builder: (context) {
        final status = _tools.statusOf(widget.userId);
        final monitored = status.suspicion == SuspiciousStatus.monitored;
        final restricted = status.suspicion == SuspiciousStatus.restricted;
        return ModSheetBody(
          children: [
            ModSheetTitle(l.modToolsUserActionsTitle, caption: name),
            _row(
              ModFeature.shoutouts,
              glyph: SheetGlyphKind.heart,
              label: l.modToolsShoutoutUser,
              onTap: () => _run(ShoutoutCommand(login)),
            ),
            _row(
              ModFeature.suspiciousUsers,
              glyph: SheetGlyphKind.monitor,
              label: monitored ? l.modToolsUnmonitor : l.modToolsMonitor,
              onTap: () => _run(
                SuspicionCommand(
                  login,
                  SuspiciousStatus.monitored,
                  on: !monitored,
                ),
              ),
            ),
            _row(
              ModFeature.suspiciousUsers,
              glyph: SheetGlyphKind.lock,
              label: restricted ? l.modToolsUnrestrict : l.modToolsRestrict,
              danger: !restricted,
              onTap: () => _run(
                SuspicionCommand(
                  login,
                  SuspiciousStatus.restricted,
                  on: !restricted,
                ),
                confirmTitle: restricted ? null : l.modToolsRestrictTitle,
                confirmMessage: l.modToolsRestrictMessage(name: name),
                confirmLabel: l.modToolsRestrict,
              ),
            ),
            _row(
              ModFeature.moderators,
              glyph: SheetGlyphKind.shield,
              label: widget.isModerator
                  ? l.modToolsRemoveModerator
                  : l.modToolsMakeModerator,
              danger: widget.isModerator,
              onTap: () => _run(
                RoleCommand(
                  login,
                  ChannelRole.moderator,
                  granted: !widget.isModerator,
                ),
                confirmTitle: l.modToolsRoleConfirmTitle(
                  change: widget.isModerator
                      ? 'removeModerator'
                      : 'addModerator',
                ),
                confirmMessage: l.modToolsRoleConfirmMessage(
                  change: widget.isModerator
                      ? 'removeModerator'
                      : 'addModerator',
                  name: name,
                ),
                confirmLabel: widget.isModerator
                    ? l.modToolsRemove
                    : l.modToolsConfirm,
              ),
            ),
            _row(
              ModFeature.vips,
              glyph: SheetGlyphKind.diamond,
              label: widget.isVip ? l.modToolsRemoveVip : l.modToolsMakeVip,
              danger: widget.isVip,
              onTap: () => _run(
                RoleCommand(login, ChannelRole.vip, granted: !widget.isVip),
                confirmTitle: l.modToolsRoleConfirmTitle(
                  change: widget.isVip ? 'removeVip' : 'addVip',
                ),
                confirmMessage: l.modToolsRoleConfirmMessage(
                  change: widget.isVip ? 'removeVip' : 'addVip',
                  name: name,
                ),
                confirmLabel: widget.isVip
                    ? l.modToolsRemove
                    : l.modToolsConfirm,
              ),
            ),
            statusLine(),
          ],
        );
      },
    );
  }
}
