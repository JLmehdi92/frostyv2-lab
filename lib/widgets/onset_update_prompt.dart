import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:frosty/apis/onset_update_service.dart';
import 'package:frosty/models/onset_release.dart';
import 'package:frosty/services/onset_updater.dart';
import 'package:frosty/widgets/alert_message.dart';
import 'package:frosty/widgets/frosty_dialog.dart';
import 'package:provider/provider.dart';

/// Offers [update]: the "Update available" popup, then the install permission
/// when Android asks for it, the download and the system installer.
///
/// [waitForResume] completes when the viewer is back from the system settings
/// (the next app resume by default).
Future<void> offerUpdate(
  BuildContext context,
  OnsetUpdater updater,
  UpdateAvailable update, {
  Future<void> Function()? waitForResume,
}) async {
  final release = update.release;
  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => UpdateAvailableDialog(release: release),
  );
  if (accepted != true) {
    await updater.postpone(release);
    return;
  }
  if (!context.mounted) return;

  if (!await updater.canInstall()) {
    if (!context.mounted) return;
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (context) => FrostyDialog(
        title: 'Allow updates',
        message:
            'Android asks you to let ONSET install apps. Turn on "Allow from '
            'this source" on the next screen, then come back.',
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
    if (openSettings != true) return;

    final back = (waitForResume ?? _nextResume)();
    await updater.openInstallSettings();
    await back;
    if (!await updater.canInstall()) {
      if (context.mounted) {
        _tell(context, 'ONSET is not allowed to install updates');
      }
      return;
    }
  }
  if (!context.mounted) return;

  final error = await showDialog<Object?>(
    context: context,
    barrierDismissible: false,
    builder: (context) =>
        UpdateProgressDialog(updater: updater, release: release),
  );
  if (!context.mounted) return;
  switch (error) {
    case UpdateIntegrityException():
      _tell(context, 'The download was corrupted — try again');
    case UpdateInstallException():
      _tell(context, "Couldn't open the installer");
    case null || UpdateCancelledException():
      break;
    default:
      _tell(context, 'Download failed');
  }
}

/// Completes at the next time the app comes back to the foreground.
Future<void> _nextResume() {
  final resumed = Completer<void>();
  late final AppLifecycleListener listener;
  listener = AppLifecycleListener(
    onResume: () {
      listener.dispose();
      resumed.complete();
    },
  );
  return resumed.future;
}

void _tell(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: AlertMessage(message: message, centered: false)),
  );
}

/// "Update available": the build, the start of its release notes, and the
/// choice between "Later" (pops false) and "Update" (pops true).
class UpdateAvailableDialog extends StatelessWidget {
  final OnsetRelease release;

  const UpdateAvailableDialog({super.key, required this.release});

  @override
  Widget build(BuildContext context) {
    final notes = release.notes.trim();

    return FrostyDialog(
      title: 'Update available',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ONSET build ${release.build} is ready.'),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              notes,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Later'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Update'),
        ),
      ],
    );
  }
}

/// Downloads and installs [release] while showing its progress. Pops with
/// null once the system installer is open, or with the error.
class UpdateProgressDialog extends StatefulWidget {
  final OnsetUpdater updater;
  final OnsetRelease release;

  const UpdateProgressDialog({
    super.key,
    required this.updater,
    required this.release,
  });

  @override
  State<UpdateProgressDialog> createState() => _UpdateProgressDialogState();
}

class _UpdateProgressDialogState extends State<UpdateProgressDialog> {
  final _cancelToken = CancelToken();
  var _received = 0;
  late var _total = widget.release.apkSize;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    Object? error;
    try {
      await widget.updater.downloadAndInstall(
        widget.release,
        cancelToken: _cancelToken,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _received = received;
            _total = total;
          });
        },
      );
    } catch (e) {
      error = e;
    }
    if (mounted) Navigator.pop(context, error);
  }

  @override
  void dispose() {
    if (!_cancelToken.isCancelled) _cancelToken.cancel();
    super.dispose();
  }

  static String _megabytes(int bytes) =>
      (bytes / (1024 * 1024)).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final progress = _total > 0 ? (_received / _total).clamp(0.0, 1.0) : null;

    return PopScope(
      canPop: false,
      child: FrostyDialog(
        title: 'Downloading update',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 8),
            Text(
              _total > 0
                  ? '${_megabytes(_received)} / ${_megabytes(_total)} MB'
                  : '${_megabytes(_received)} MB',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _cancelToken.isCancelled
                ? null
                : () => setState(() => _cancelToken.cancel()),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

/// Looks for an update once the screen has started and each time the app
/// comes back to the foreground, and offers it. Does nothing without an
/// enabled [OnsetUpdater] provided above the screen.
mixin OnsetUpdateChecks<T extends StatefulWidget> on State<T> {
  OnsetUpdater? _updater;
  AppLifecycleListener? _updateLifecycle;
  var _updateBusy = false;

  @override
  void initState() {
    super.initState();
    final updater = context.read<OnsetUpdater?>();
    if (updater == null || !updater.enabled) return;
    _updater = updater;
    _updateLifecycle = AppLifecycleListener(onResume: _checkForUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  Future<void> _checkForUpdate() async {
    final updater = _updater;
    if (updater == null || _updateBusy || !mounted) return;
    _updateBusy = true;
    try {
      final result = await updater.check();
      if (result is UpdateAvailable && mounted) {
        await offerUpdate(context, updater, result);
      }
    } catch (e) {
      // An update is never worth an error screen: the next resume retries.
      debugPrint('Update check failed: ${e.runtimeType}');
    } finally {
      _updateBusy = false;
    }
  }

  @override
  void dispose() {
    _updateLifecycle?.dispose();
    super.dispose();
  }
}
