import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/chat_ui_settings.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/settings_glyph.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';

extension ChatUiSettingsLocal on SettingsStore {
  ChatUiSettings get chatUiSettings => ChatUiSettings({
    ChatUiSetting.emoteAnimations: animateEmotes,
    ChatUiSetting.gifs: showGifs,
    ChatUiSetting.gifAnimations: animateGifs,
    ChatUiSetting.readableColors: readableNameColors,
  });

  void applyChatUiSettings(ChatUiSettings settings) {
    animateEmotes = settings[ChatUiSetting.emoteAnimations];
    showGifs = settings[ChatUiSetting.gifs];
    animateGifs = settings[ChatUiSetting.gifAnimations];
    readableNameColors = settings[ChatUiSetting.readableColors];
  }
}

class ChatAccountSyncGroup extends StatefulWidget {
  const ChatAccountSyncGroup({
    super.key,
    required this.settingsStore,
    required this.load,
    required this.save,
  });

  static const useAccountKey = ValueKey('chat-sync-use-account');
  static const saveKey = ValueKey('chat-sync-save');

  final SettingsStore settingsStore;
  final Future<ChatUiSettings?> Function() load;
  final Future<ViewerActionOutcome> Function(
    ChatUiSetting setting,
    bool enabled,
  )
  save;

  @override
  State<ChatAccountSyncGroup> createState() => _ChatAccountSyncGroupState();
}

class _ChatAccountSyncGroupState extends State<ChatAccountSyncGroup> {
  ChatUiSettings? _account;
  var _loading = true;
  var _busy = false;

  SettingsStore get _store => widget.settingsStore;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    final account = await widget.load();
    if (!mounted) return;
    setState(() {
      _account = account;
      _loading = false;
    });
  }

  void _showSnack(String text, {SnackBarAction? action}) =>
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text), action: action));

  void _useAccount(ChatUiSettings account) {
    final previous = _store.chatUiSettings;
    _store.applyChatUiSettings(account);
    _showSnack(
      context.l10n.chatSyncApplied,
      action: SnackBarAction(
        label: context.l10n.commonUndo,
        onPressed: () => _store.applyChatUiSettings(previous),
      ),
    );
  }

  Future<void> _saveToAccount(ChatUiSettings account) async {
    final local = _store.chatUiSettings;
    final changes = local.differencesFrom(account);
    if (changes.isEmpty || _busy) return;
    final l = context.l10n;
    final confirmed = await confirmSettingsAction(
      context,
      title: l.chatSyncSaveConfirmTitle,
      message: l.chatSyncSaveConfirmBody(count: changes.length),
      confirm: l.chatSyncSaveAction,
      danger: false,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    var outcome = ViewerActionOutcome.done;
    for (final setting in changes) {
      outcome = await widget.save(setting, local[setting]);
      if (outcome != ViewerActionOutcome.done) break;
    }
    final refreshed = await widget.load();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _account = refreshed ?? _account;
    });
    _showSnack(l.viewerActionResult(status: outcome.name));
  }

  @override
  Widget build(BuildContext context) => Observer(
    builder: (context) {
      final l = context.l10n;
      final account = _account;
      return SettingsGroup(
        title: l.chatSyncTitle,
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (account == null)
            SettingsNote(l.chatSyncUnavailable)
          else
            ..._rows(context, account),
        ],
      );
    },
  );

  List<Widget> _rows(BuildContext context, ChatUiSettings account) {
    final l = context.l10n;
    final differences = _store.chatUiSettings.differencesFrom(account).length;
    final inSync = differences == 0;
    final idle = !inSync && !_busy;
    return [
      SettingsNote(
        inSync ? l.chatSyncInSync : l.chatSyncDiffers(count: differences),
      ),
      SettingsRow(
        key: ChatAccountSyncGroup.useAccountKey,
        glyph: SettingsGlyphKind.reconnect,
        title: l.chatSyncUseAccount,
        subtitle: Text(l.chatSyncUseAccountDetail),
        enabled: idle,
        onTap: idle ? () => _useAccount(account) : null,
      ),
      SettingsRow(
        key: ChatAccountSyncGroup.saveKey,
        glyph: SettingsGlyphKind.user,
        title: l.chatSyncSave,
        subtitle: Text(l.chatSyncSaveDetail),
        enabled: idle,
        onTap: idle ? () => unawaited(_saveToAccount(account)) : null,
      ),
    ];
  }
}
