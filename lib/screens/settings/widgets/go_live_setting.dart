import 'package:flutter/material.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/settings/widgets/settings_list_switch.dart';
import 'package:onset/services/go_live/go_live.dart';
import 'package:onset/services/go_live/go_live_worker.dart';
import 'package:onset/services/telemetry.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:onset/widgets/sheet/sheet_glyph.dart';

/// The platform side of go-live notices, swappable in tests.
class GoLivePlatform {
  const GoLivePlatform();

  bool get supported => GoLiveScheduler.supported;
  Future<bool> requestPermission() => GoLiveNotifications.requestPermission();
  Future<bool> allowed() => GoLiveNotifications.allowed();
  Future<void> start() => GoLiveScheduler.start();
  Future<void> stop() => GoLiveScheduler.stop();
}

/// Turns go-live notices on or off for the logged-in viewer ([userId]).
class GoLiveSetting extends StatefulWidget {
  const GoLiveSetting({
    super.key,
    required this.userId,
    this.platform = const GoLivePlatform(),
  });

  /// Null when logged out.
  final String? userId;
  final GoLivePlatform platform;

  @override
  State<GoLiveSetting> createState() => _GoLiveSettingState();
}

/// What went wrong the last time the setting was read or changed.
enum _GoLiveProblem { readFailed, refused, turnOnFailed, turnOffFailed }

class _GoLiveSettingState extends State<GoLiveSetting> {
  GoLivePrefs? _prefs;
  var _busy = false;
  _GoLiveProblem? _problem;

  /// Notices blocked in the system settings since they were turned on.
  var _blocked = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await GoLivePrefs.load();
      final blocked =
          prefs.enabled &&
          widget.platform.supported &&
          !await widget.platform.allowed();
      if (!mounted) return;
      setState(() {
        _prefs = prefs;
        _blocked = blocked;
      });
    } catch (e, stack) {
      _report(e, stack);
      if (mounted) {
        setState(() => _problem = _GoLiveProblem.readFailed);
      }
    }
  }

  static void _report(Object error, StackTrace stack) {
    debugPrint('Go-live setting failed: $error');
    Telemetry.recordError(error, stack, reason: 'go-live setting');
  }

  Future<void> _set(bool on) async {
    final prefs = _prefs;
    if (prefs == null) return;
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      if (on) {
        if (!await widget.platform.requestPermission()) {
          _problem = _GoLiveProblem.refused;
          return;
        }
        // Scheduled first: the switch only says on once it is.
        await widget.platform.start();
        await prefs.setUserId(widget.userId);
        await prefs.setEnabled(true);
        await prefs.setProblem(null);
        _blocked = false;
      } else {
        await prefs.setEnabled(false);
        await widget.platform.stop();
      }
    } catch (e, stack) {
      _report(e, stack);
      if (on) await prefs.setEnabled(false).catchError((_) {});
      _problem = on
          ? _GoLiveProblem.turnOnFailed
          : _GoLiveProblem.turnOffFailed;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = _prefs;
    final loggedIn = widget.userId != null;
    final supported = widget.platform.supported;
    final on = (prefs?.enabled ?? false) && loggedIn;
    final l = context.l10n;
    final problem = _problem;
    final String subtitle;
    if (!supported) {
      subtitle = l.goLiveAndroidOnly;
    } else if (!loggedIn) {
      subtitle = l.goLiveLoggedOut;
    } else if (problem != null) {
      subtitle = switch (problem) {
        _GoLiveProblem.readFailed => l.goLiveReadFailed,
        _GoLiveProblem.refused => l.notificationsAllowInSystem,
        _GoLiveProblem.turnOnFailed => l.goLiveTurnOnFailed,
        _GoLiveProblem.turnOffFailed => l.goLiveTurnOffFailed,
      };
    } else if (on && _blocked) {
      subtitle = l.goLiveBlocked;
    } else if (on && prefs?.problem != null) {
      // The only problem the background check keeps: Twitch refused its
      // login.
      subtitle = l.goLiveLogInAgain;
    } else if (on) {
      subtitle = l.goLiveOnDetail;
    } else {
      subtitle = l.goLiveOffDetail;
    }
    return SettingsListSwitch(
      title: l.goLiveTitle,
      subtitle: Text(
        subtitle,
        style: _problem != null || (on && (_blocked || prefs?.problem != null))
            ? TextStyle(color: Theme.of(context).colorScheme.error)
            : null,
      ),
      value: on,
      onChanged: supported && loggedIn && prefs != null && !_busy ? _set : null,
    );
  }
}

/// A channel's bell: whether its go-live is notified. Shown only while
/// go-live notices are on.
class GoLiveBellTile extends StatefulWidget {
  const GoLiveBellTile({
    super.key,
    required this.channelId,
    required this.name,
  });

  final String channelId;
  final String name;

  @override
  State<GoLiveBellTile> createState() => _GoLiveBellTileState();
}

class _GoLiveBellTileState extends State<GoLiveBellTile> {
  GoLivePrefs? _prefs;

  @override
  void initState() {
    super.initState();
    GoLivePrefs.load().then((prefs) {
      if (mounted) setState(() => _prefs = prefs);
    });
  }

  @override
  Widget build(BuildContext context) {
    final prefs = _prefs;
    if (prefs == null || !prefs.enabled) return const SizedBox.shrink();
    final on = !prefs.muted.contains(widget.channelId);
    Future<void> change(bool value) async {
      try {
        await prefs.setMuted(widget.channelId, !value);
      } catch (e, stack) {
        _GoLiveSettingState._report(e, stack);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.goLiveBellFailed)),
          );
        }
      }
      if (mounted) setState(() {});
    }

    // The row with a switch (as in the user card's "More").
    return MergeSemantics(
      child: SheetRow(
        glyph: SheetGlyphKind.bell,
        label: context.l10n.goLiveBell(name: widget.name),
        onTap: () => change(!on),
        trailing: OnsetSwitch(value: on, onChanged: change),
      ),
    );
  }
}
