import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/apis/twitch_mod_api.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/channel/chat/chat_commands.dart';
import 'package:onset/screens/channel/chat/details/chat_details.dart';
import 'package:onset/screens/channel/chat/details/chat_mode_controls.dart';
import 'package:onset/screens/channel/chat/mod_tools/mod_features.dart';
import 'package:onset/screens/channel/chat/mod_tools/stores/mod_tools_store.dart';
import 'package:onset/screens/channel/chat/mod_tools/widgets/mod_compose_sheets.dart';
import 'package:onset/screens/channel/chat/mod_tools/widgets/mod_list_sheets.dart';
import 'package:onset/screens/channel/chat/mod_tools/widgets/mod_queue_sheets.dart';
import 'package:onset/screens/channel/chat/mod_tools/widgets/mod_sheet_parts.dart';
import 'package:onset/screens/channel/chat/moderation.dart';
import 'package:onset/screens/channel/chat/stores/chat_store.dart';
import 'package:onset/utils/twitch_report.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';
import 'package:onset/widgets/twitch_web_page.dart';

Future<void> showModTools(
  BuildContext context,
  ChatStore chatStore, {
  ModToolsView view = ModToolsView.hub,
}) {
  final tools = chatStore.modTools;
  final Widget Function(BuildContext context) builder = switch (view) {
    ModToolsView.hub => (_) => ModToolsSheet(chatStore: chatStore),
    ModToolsView.autoMod => (_) => AutoModQueueSheet(tools: tools),
    ModToolsView.moderators => (_) => RoleListSheet(
      chatStore: chatStore,
      role: ChannelRole.moderator,
    ),
    ModToolsView.vips => (_) => RoleListSheet(
      chatStore: chatStore,
      role: ChannelRole.vip,
    ),
  };
  return showOnsetSheet<void>(
    context: context,
    panel: view != ModToolsView.hub,
    builder: builder,
  );
}

Future<void> _open(BuildContext context, WidgetBuilder builder) =>
    showOnsetSheet<void>(context: context, panel: true, builder: builder);

class ModToolsSheet extends StatefulWidget {
  const ModToolsSheet({super.key, required this.chatStore});

  final ChatStore chatStore;

  @override
  State<ModToolsSheet> createState() => _ModToolsSheetState();
}

class _ModToolsSheetState extends State<ModToolsSheet>
    with ModActionState<ModToolsSheet> {
  ChatStore get _chat => widget.chatStore;
  ModToolsStore get _tools => _chat.modTools;

  Future<void> _run(ModerationCommand command) async {
    setState(() {
      busy = true;
      statusMessage = null;
    });
    ModerationOutcome? outcome;
    try {
      outcome = await _chat.moderate(command);
    } catch (error) {
      debugPrint('Mod tools command failed: $error');
      outcome = moderationFailed;
    }
    if (!mounted) return;
    setState(() {
      busy = false;
      statusOk = outcome?.ok ?? true;
      statusMessage = outcome?.message;
    });
  }

  Future<void> _toggleShield(bool active) async {
    setState(() {
      busy = true;
      statusMessage = null;
    });
    final failure = await _tools.setShieldMode(active);
    if (!mounted) return;
    final l = context.l10n;
    setState(() {
      busy = false;
      statusOk = failure == null;
      statusMessage = failure ?? l.chatModShield(state: OnOff.of(active).name);
    });
  }

  Future<void> _shoutout() async {
    final l = context.l10n;
    final login = await showModTextDialog(
      context,
      title: l.modToolsShoutoutTitle,
      label: l.modToolsChannelLabel,
      confirmLabel: l.modToolsShoutoutSend,
      loginOnly: true,
    );
    if (login == null || !mounted) return;
    await _run(ShoutoutCommand(login.toLowerCase()));
  }

  Future<void> _addMarker() async {
    final l = context.l10n;
    final description = await showModTextDialog(
      context,
      title: l.modToolsMarkerTitle,
      label: l.modToolsMarkerLabel,
      confirmLabel: l.modToolsMarkerAdd,
      maxLength: ModTextLimits.marker,
      optional: true,
    );
    if (description == null || !mounted) return;
    await _run(MarkerCommand(description));
  }

  Future<void> _runCommercial() async {
    final seconds = await showCommercialDialog(context);
    if (seconds == null || !mounted) return;
    await _run(CommercialCommand(seconds));
  }

  Future<void> _raid() async {
    final l = context.l10n;
    final login = await showModTextDialog(
      context,
      title: l.modToolsRaidTitle,
      label: l.modToolsChannelLabel,
      confirmLabel: l.modToolsRaidStart,
      loginOnly: true,
      message: l.modToolsRaidMessage,
    );
    if (login == null || !mounted) return;
    await _run(RaidCommand(login.toLowerCase()));
  }

  Future<void> _cancelRaid() async {
    final l = context.l10n;
    final confirmed = await confirmModAction(
      context,
      title: l.modToolsRaidCancelTitle,
      message: l.modToolsRaidCancelMessage,
      confirmLabel: l.modToolsRaidCancel,
      danger: true,
    );
    if (confirmed && mounted) await _run(const UnraidCommand());
  }

  Widget _row(
    ModFeature feature, {
    required SheetGlyphKind glyph,
    required String label,
    String? detail,
    VoidCallback? onTap,
    SheetRowEnd end = SheetRowEnd.chevron,
    Widget? trailing,
  }) {
    final l = context.l10n;
    if (!_tools.shows(feature)) return const SizedBox.shrink();
    if (_tools.needsLogin(feature)) {
      return SheetRow(
        glyph: glyph,
        label: label,
        detail: l.modToolsLogInToEnable,
        end: SheetRowEnd.chevron,
        onTap: () => openModLogin(context, _chat.auth, feature.scopes),
      );
    }
    final ready = _tools.canUse(feature);
    return SheetRow(
      glyph: glyph,
      label: label,
      detail: detail,
      end: trailing == null ? end : SheetRowEnd.none,
      trailing: trailing,
      onTap: ready && !busy ? onTap : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Observer(
      builder: (context) {
        final tools = _tools;
        final broadcaster = tools.isBroadcaster;
        final pending = tools.pendingHeldCount;
        return ModSheetBody(
          children: [
            ModSheetTitle(
              l.modToolsTitle,
              caption: broadcaster
                  ? l.modToolsCaptionBroadcaster
                  : l.modToolsCaptionModerator,
            ),
            if (tools.scopes == null)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            SheetSectionLabel(l.modToolsSectionLive),
            _row(
              ModFeature.shieldMode,
              glyph: SheetGlyphKind.shield,
              label: l.modToolsShieldMode,
              detail: l.modToolsShieldModeDetail,
              trailing: OnsetSwitch(
                value: tools.shieldActive,
                semanticsLabel: l.modToolsShieldMode,
                onChanged: tools.canUse(ModFeature.shieldMode) && !busy
                    ? _toggleShield
                    : null,
              ),
              onTap: () => _toggleShield(!tools.shieldActive),
            ),
            _row(
              ModFeature.autoMod,
              glyph: SheetGlyphKind.filter,
              label: l.modToolsAutoModQueue,
              detail: pending > 0
                  ? l.modToolsAutoModPending(count: pending)
                  : l.modToolsAutoModEmptyDetail,
              onTap: () =>
                  _open(context, (_) => AutoModQueueSheet(tools: tools)),
            ),
            _row(
              ModFeature.actionFeed,
              glyph: SheetGlyphKind.rules,
              label: l.modToolsActionLog,
              detail: l.modToolsActionLogDetail,
              onTap: () =>
                  _open(context, (_) => ModActionLogSheet(tools: tools)),
            ),
            if (tools.canUse(ModFeature.actionFeed))
              ChatPreferenceSwitch(
                glyph: SheetGlyphKind.whisper,
                label: l.modToolsShowActionsInChat,
                read: () => _chat.settings.showModActionsInChat,
                write: (value) => _chat.settings.showModActionsInChat = value,
              ),
            SheetSectionLabel(l.modToolsSectionChat),
            SheetRow(
              glyph: SheetGlyphKind.unique,
              label: l.chatDetailsModes,
              detail: l.chatDetailsModesDetail,
              end: SheetRowEnd.chevron,
              onTap: () => _open(
                context,
                (context) => Observer(
                  builder: (context) => ChatModeControls(
                    roomState: _chat.chatDetailsStore.roomState,
                    onModerate: _chat.moderate,
                  ),
                ),
              ),
            ),
            _row(
              ModFeature.announcements,
              glyph: SheetGlyphKind.bell,
              label: l.modToolsAnnounce,
              onTap: () =>
                  _open(context, (_) => AnnounceSheet(chatStore: _chat)),
            ),
            _row(
              ModFeature.shoutouts,
              glyph: SheetGlyphKind.heart,
              label: l.modToolsShoutout,
              detail: l.modToolsShoutoutDetail,
              end: SheetRowEnd.none,
              onTap: _shoutout,
            ),
            _row(
              ModFeature.blockedTerms,
              glyph: SheetGlyphKind.block,
              label: l.modToolsBlockedTerms,
              onTap: () =>
                  _open(context, (_) => BlockedTermsSheet(chatStore: _chat)),
            ),
            if (broadcaster)
              SheetRow(
                glyph: SheetGlyphKind.check,
                label: l.modToolsPermittedTerms,
                detail: l.chatDetailsOpensTwitch,
                end: SheetRowEnd.external,
                onTap: () => TwitchWebPage.open(
                  context,
                  title: l.modToolsPermittedTerms,
                  url: Uri.https(
                    'dashboard.twitch.tv',
                    '/u/${_chat.channelName}/settings/moderation/blocked-terms',
                  ),
                ),
              ),
            _row(
              ModFeature.unbanRequests,
              glyph: SheetGlyphKind.unban,
              label: l.modToolsUnbanRequests,
              onTap: () =>
                  _open(context, (_) => UnbanRequestsSheet(chatStore: _chat)),
            ),
            if (broadcaster) ...[
              SheetSectionLabel(l.modToolsSectionChannel),
              _row(
                ModFeature.streamInfo,
                glyph: SheetGlyphKind.settings,
                label: l.modToolsStreamInfo,
                onTap: () =>
                    _open(context, (_) => StreamInfoSheet(chatStore: _chat)),
              ),
              _row(
                ModFeature.polls,
                glyph: SheetGlyphKind.poll,
                label: l.modToolsPolls,
                onTap: () => _open(context, (_) => PollSheet(chatStore: _chat)),
              ),
              _row(
                ModFeature.predictions,
                glyph: SheetGlyphKind.trophy,
                label: l.modToolsPredictions,
                onTap: () =>
                    _open(context, (_) => PredictionSheet(chatStore: _chat)),
              ),
              _row(
                ModFeature.redemptions,
                glyph: SheetGlyphKind.coin,
                label: l.modToolsRewardRequests,
                onTap: () =>
                    _open(context, (_) => RedemptionsSheet(chatStore: _chat)),
              ),
              _row(
                ModFeature.moderators,
                glyph: SheetGlyphKind.shield,
                label: l.modToolsModerators,
                onTap: () => _open(
                  context,
                  (_) => RoleListSheet(
                    chatStore: _chat,
                    role: ChannelRole.moderator,
                  ),
                ),
              ),
              _row(
                ModFeature.vips,
                glyph: SheetGlyphKind.diamond,
                label: l.modToolsVips,
                onTap: () => _open(
                  context,
                  (_) => RoleListSheet(chatStore: _chat, role: ChannelRole.vip),
                ),
              ),
              _row(
                ModFeature.raid,
                glyph: SheetGlyphKind.flame,
                label: l.modToolsRaid,
                end: SheetRowEnd.none,
                onTap: _raid,
              ),
              _row(
                ModFeature.raid,
                glyph: SheetGlyphKind.close,
                label: l.modToolsRaidCancel,
                end: SheetRowEnd.none,
                onTap: _cancelRaid,
              ),
              _row(
                ModFeature.marker,
                glyph: SheetGlyphKind.pin,
                label: l.modToolsMarker,
                end: SheetRowEnd.none,
                onTap: _addMarker,
              ),
              _row(
                ModFeature.commercial,
                glyph: SheetGlyphKind.monitor,
                label: l.modToolsCommercial,
                end: SheetRowEnd.none,
                onTap: _runCommercial,
              ),
            ],
            if (twitchModViewUri(_chat.channelName) case final url?)
              SheetRow(
                key: const ValueKey('mod-view'),
                glyph: SheetGlyphKind.monitor,
                label: l.modToolsModView,
                detail: l.chatDetailsOpensTwitch,
                end: SheetRowEnd.external,
                onTap: () => TwitchWebPage.open(
                  context,
                  title: l.modToolsModView,
                  url: url,
                ),
              ),
            statusLine(),
          ],
        );
      },
    );
  }
}

final _dialogLogin = RegExp(r'^@?[a-zA-Z0-9_]{1,25}$');

Future<String?> showModTextDialog(
  BuildContext context, {
  required String title,
  required String label,
  required String confirmLabel,
  String? message,
  int? maxLength,
  bool loginOnly = false,
  bool optional = false,
}) => showDialog<String>(
  context: context,
  builder: (context) => _ModTextDialog(
    title: title,
    label: label,
    confirmLabel: confirmLabel,
    message: message,
    maxLength: maxLength ?? (loginOnly ? 26 : null),
    loginOnly: loginOnly,
    optional: optional,
  ),
);

class _ModTextDialog extends StatefulWidget {
  const _ModTextDialog({
    required this.title,
    required this.label,
    required this.confirmLabel,
    required this.message,
    required this.maxLength,
    required this.loginOnly,
    required this.optional,
  });

  final String title;
  final String label;
  final String confirmLabel;
  final String? message;
  final int? maxLength;
  final bool loginOnly;
  final bool optional;

  @override
  State<_ModTextDialog> createState() => _ModTextDialogState();
}

class _ModTextDialogState extends State<_ModTextDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _valid {
    final text = _controller.text.trim();
    if (widget.loginOnly) return _dialogLogin.hasMatch(text);
    return widget.optional || text.isNotEmpty;
  }

  String get _value {
    final text = singleLine(_controller.text);
    return widget.loginOnly ? text.replaceFirst('@', '') : text;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) => OnsetDialog(
      title: widget.title,
      message: widget.message,
      content: SheetTextField(
        controller: _controller,
        label: widget.label,
        autofocus: true,
        maxLength: widget.maxLength,
        counter: !widget.loginOnly && widget.maxLength != null,
      ),
      actions: [
        SheetButton(
          label: context.l10n.commonCancel,
          tone: SheetButtonTone.text,
          onPressed: () => Navigator.pop(context),
        ),
        SheetButton(
          label: widget.confirmLabel,
          onPressed: _valid ? () => Navigator.pop(context, _value) : null,
        ),
      ],
    ),
  );
}

Future<int?> showCommercialDialog(BuildContext context) => showDialog<int>(
  context: context,
  builder: (context) => const _CommercialDialog(),
);

class _CommercialDialog extends StatefulWidget {
  const _CommercialDialog();

  @override
  State<_CommercialDialog> createState() => _CommercialDialogState();
}

class _CommercialDialogState extends State<_CommercialDialog> {
  var _seconds = kCommercialLengths.first;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return OnsetDialog(
      title: l.modToolsCommercialTitle,
      message: l.modToolsCommercialMessage,
      content: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final seconds in kCommercialLengths)
            SheetChoicePill(
              label: l.modToolsSeconds(count: seconds),
              selected: seconds == _seconds,
              large: true,
              onSelected: () => setState(() => _seconds = seconds),
            ),
        ],
      ),
      actions: [
        SheetButton(
          label: l.commonCancel,
          tone: SheetButtonTone.text,
          onPressed: () => Navigator.pop(context),
        ),
        SheetButton(
          label: l.modToolsCommercialStart,
          tone: SheetButtonTone.danger,
          onPressed: () => Navigator.pop(context, _seconds),
        ),
      ],
    );
  }
}
