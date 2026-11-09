import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/models/follow_result.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';
import 'package:onset/screens/settings/widgets/settings_list_switch.dart';

class GiftSettingsGroup extends StatefulWidget {
  const GiftSettingsGroup({super.key, required this.load, required this.save});

  static const followedOnlyKey = ValueKey('gift-followed-only');
  static const hideCountKey = ValueKey('gift-hide-count');

  final Future<GiftSettings?> Function() load;
  final Future<ViewerActionOutcome> Function(GiftSettings settings) save;

  @override
  State<GiftSettingsGroup> createState() => _GiftSettingsGroupState();
}

class _GiftSettingsGroupState extends State<GiftSettingsGroup> {
  GiftSettings? _settings;
  var _loading = true;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    final settings = await widget.load();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _loading = false;
    });
  }

  Future<void> _change(GiftSettings wanted) async {
    final previous = _settings;
    if (previous == null || _busy || wanted == previous) return;
    final l = context.l10n;
    final confirmed = await confirmSettingsAction(
      context,
      title: l.giftSettingsConfirmTitle,
      message: l.giftSettingsConfirmBody,
      confirm: l.giftSettingsChange,
      danger: false,
    );
    if (!confirmed || !mounted) return;
    await _apply(wanted, undo: previous);
  }

  Future<void> _apply(GiftSettings wanted, {GiftSettings? undo}) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l = context.l10n;
    setState(() => _busy = true);
    final outcome = await widget.save(wanted);
    if (!mounted) return;
    final done = outcome == ViewerActionOutcome.done;
    setState(() {
      _busy = false;
      if (done) _settings = wanted;
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
    final settings = _settings;
    return SettingsGroup(
      title: l.giftSettingsTitle,
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
        else if (settings == null)
          SettingsNote(l.giftSettingsUnavailable)
        else ...[
          SettingsListSwitch(
            key: GiftSettingsGroup.followedOnlyKey,
            title: l.giftFollowedOnly,
            subtitle: Text(l.giftFollowedOnlyDetail),
            value: settings.followedChannelsOnly,
            onChanged: _busy
                ? null
                : (value) => unawaited(
                    _change(settings.copyWith(followedChannelsOnly: value)),
                  ),
          ),
          SettingsListSwitch(
            key: GiftSettingsGroup.hideCountKey,
            title: l.giftHideCount,
            subtitle: Text(l.giftHideCountDetail),
            value: settings.countHidden,
            onChanged: _busy
                ? null
                : (value) =>
                      unawaited(_change(settings.copyWith(countHidden: value))),
          ),
        ],
      ],
    );
  }
}
