import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/whisper_history.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';
import 'package:onset/screens/settings/widgets/settings_list_switch.dart';

class WhisperPrivacyGroup extends StatefulWidget {
  const WhisperPrivacyGroup({
    super.key,
    required this.load,
    required this.save,
  });

  static const blockStrangersKey = ValueKey('whisper-block-strangers');

  final Future<WhisperPrivacy?> Function() load;
  final Future<ViewerActionOutcome> Function(bool blockStrangers) save;

  @override
  State<WhisperPrivacyGroup> createState() => _WhisperPrivacyGroupState();
}

class _WhisperPrivacyGroupState extends State<WhisperPrivacyGroup> {
  WhisperPrivacy? _privacy;
  var _loading = true;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    final privacy = await widget.load();
    if (!mounted) return;
    setState(() {
      _privacy = privacy;
      _loading = false;
    });
  }

  Future<void> _change(bool block) async {
    final previous = _privacy;
    if (previous == null || _busy || previous.blockStrangers == block) return;
    final l = context.l10n;
    final confirmed = await confirmSettingsAction(
      context,
      title: l.giftSettingsConfirmTitle,
      message: l.giftSettingsConfirmBody,
      confirm: l.giftSettingsChange,
      danger: false,
    );
    if (!confirmed || !mounted) return;
    await _apply(block, undo: previous.blockStrangers);
  }

  Future<void> _apply(bool block, {bool? undo}) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l = context.l10n;
    setState(() => _busy = true);
    final outcome = await widget.save(block);
    if (!mounted) return;
    final done = outcome == ViewerActionOutcome.done;
    setState(() {
      _busy = false;
      final current = _privacy;
      if (done && current != null) {
        _privacy = WhisperPrivacy(
          blockStrangers: block,
          banned: current.banned,
          disabledByParent: current.disabledByParent,
        );
      }
    });
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l.viewerActionResult(status: outcome.name)),
          action: done && undo != null
              ? SnackBarAction(
                  label: l.commonUndo,
                  onPressed: () => unawaited(_apply(undo)),
                )
              : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final privacy = _privacy;
    return SettingsGroup(
      title: l.whisperPrivacyTitle,
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
        else if (privacy == null)
          SettingsNote(l.whisperPrivacyUnavailable)
        else ...[
          if (privacy.banned) SettingsNote(l.whisperPrivacyBanned),
          if (privacy.disabledByParent) SettingsNote(l.whisperPrivacyParent),
          SettingsListSwitch(
            key: WhisperPrivacyGroup.blockStrangersKey,
            title: l.whisperBlockStrangers,
            subtitle: Text(l.whisperBlockStrangersDetail),
            value: privacy.blockStrangers,
            onChanged: _busy || privacy.disabledByParent
                ? null
                : (value) => unawaited(_change(value)),
          ),
        ],
      ],
    );
  }
}
