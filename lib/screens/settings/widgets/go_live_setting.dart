import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:frosty/screens/settings/widgets/settings_list_switch.dart';
import 'package:frosty/services/go_live/go_live.dart';
import 'package:frosty/services/go_live/go_live_worker.dart';

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

class _GoLiveSettingState extends State<GoLiveSetting> {
  GoLivePrefs? _prefs;
  var _busy = false;
  String? _problem;

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
        setState(() => _problem = "Couldn't read the go-live setting.");
      }
    }
  }

  static void _report(Object error, StackTrace stack) {
    debugPrint('Go-live setting failed: $error');
    try {
      FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: 'go-live setting',
      );
    } catch (_) {
      // Firebase may not be initialized (e.g., in tests).
    }
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
          _problem = 'Allow notifications for this app in the system settings.';
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
      _problem =
          "Couldn't ${on ? 'turn on' : 'turn off'} go-live notifications.";
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
    final String subtitle;
    if (!supported) {
      subtitle = 'Android only.';
    } else if (!loggedIn) {
      subtitle = 'Log in to be told when channels you follow go live.';
    } else if (_problem != null) {
      subtitle = _problem!;
    } else if (on && _blocked) {
      subtitle =
          'Notifications are blocked for this app. Allow them in the system '
          'settings.';
    } else if (on && prefs?.problem != null) {
      subtitle = prefs!.problem!;
    } else if (on) {
      subtitle =
          'Checked every 90 seconds while ONSET is open or playing, and '
          'about every 15 minutes otherwise, when the system allows. Turn a '
          "channel's bell off from its menu.";
    } else {
      subtitle = 'Be told when channels you follow go live.';
    }
    return SettingsListSwitch(
      title: 'Go-live notifications',
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
    return SwitchListTile.adaptive(
      secondary: Icon(
        on
            ? Icons.notifications_active_outlined
            : Icons.notifications_off_outlined,
      ),
      title: Text('Notify when ${widget.name} goes live'),
      value: on,
      onChanged: (value) async {
        try {
          await prefs.setMuted(widget.channelId, !value);
        } catch (e, stack) {
          _GoLiveSettingState._report(e, stack);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Couldn't change the bell.")),
            );
          }
        }
        if (mounted) setState(() {});
      },
    );
  }
}
