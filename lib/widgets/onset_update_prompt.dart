import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:onset/apis/onset_update_service.dart';
import 'package:onset/models/onset_release.dart';
import 'package:onset/screens/settings/widgets/settings_glyph.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';
import 'package:onset/services/onset_updater.dart';
import 'package:onset/theme.dart';
import 'package:onset/utils/context_extensions.dart';
import 'package:onset/widgets/alert_message.dart';
import 'package:onset/widgets/launch/onset_mark.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:provider/provider.dart';

/// Offers [update]: the "Update available" sheet (a dialog on a tablet),
/// then the install permission when Android asks for it, the download and
/// the system installer.
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
  final accepted = await _askUpdate(context, update);
  if (accepted != true) {
    await updater.postpone(release);
    return;
  }
  if (!context.mounted) return;

  if (!await updater.canInstall()) {
    if (!context.mounted) return;
    final openSettings = await confirmSettingsAction(
      context,
      title: 'Allow updates',
      message:
          'Android asks you to let ONSET install apps. Turn on "Allow from '
          'this source" on the next screen, then come back.',
      confirm: 'Open settings',
      danger: false,
    );
    if (!openSettings) return;

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
    barrierColor: kSheetScrim,
    builder: (context) =>
        UpdateProgressDialog(updater: updater, release: release),
  );
  if (!context.mounted) return;
  switch (error) {
    case UpdateIntegrityException():
      _tell(context, 'The download was corrupted — try again');
    case UpdateInstallException():
      _tell(context, 'Android could not install the update');
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

/// Offers [update]: a sheet on a phone, a dialog on a
/// tablet; it is answered with "Update" (true) or "Later" (false), never
/// dismissed in passing.
Future<bool?> _askUpdate(BuildContext context, UpdateAvailable update) {
  final colors = SettingsColors.of(context);
  final content = UpdateAvailableDialog(
    release: update.release,
    currentBuild: update.currentBuild,
  );
  if (context.isLargeScreen) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: kSheetScrim,
      builder: (context) => Dialog(
        backgroundColor: colors.dialog,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OnsetTokens.radiusLarge),
          side: BorderSide(
            color: colors.cardRing,
            width: OnsetTokens.hairlineWidth,
          ),
        ),
        child: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: content,
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<bool>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: colors.sheet,
    barrierColor: kSheetScrim,
    elevation: 0,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(OnsetTokens.radiusLarge),
      ),
    ),
    builder: (context) => PopScope(
      // Back answers "Later", as the button does.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, false);
      },
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colors.handle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              content,
            ],
          ),
        ),
      ),
    ),
  );
}

/// "Update available": the ONSET tile, the build, what is
/// installed and the download's size, the start of its release notes, and
/// the choice between "Update" (pops true) and "Later" (pops false).
class UpdateAvailableDialog extends StatelessWidget {
  final OnsetRelease release;

  /// The installed build; unknown when null.
  final int? currentBuild;

  const UpdateAvailableDialog({
    super.key,
    required this.release,
    this.currentBuild,
  });

  static String _megabytes(int bytes) =>
      (bytes / (1024 * 1024)).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final colors = SettingsColors.of(context);
    final accent = SettingsColors.accentOf(context);
    final notes = release.notes.trim();
    final installed = [
      if (currentBuild case final build?) 'Installed: build $build',
      if (release.apkSize > 0) '${_megabytes(release.apkSize)} MB',
      'SHA-256 checked before install',
    ].join(' · ');

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: 'Update available',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          Row(
            spacing: 14,
            children: [
              SizedBox.square(
                dimension: 52,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const ExcludeSemantics(
                      child: OnsetMarkTile(size: 52, radius: 15),
                    ),
                    Positioned(
                      right: -5,
                      bottom: -5,
                      child: Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: OnsetTokens.backgroundDark,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.sheet, width: 2),
                        ),
                        child: SettingsGlyph(
                          SettingsGlyphKind.update,
                          size: 14,
                          strokeWidth: 2.6,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 3,
                  children: [
                    Text(
                      'NEW BUILD',
                      style: TextStyle(
                        fontFamily: OnsetTokens.bodyFamily,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.26,
                        color: accent,
                      ),
                    ),
                    Semantics(
                      header: true,
                      child: Text(
                        'Update available',
                        style: TextStyle(
                          fontFamily: OnsetTokens.bodyFamily,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.55,
                          height: 1.15,
                          color: colors.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              Text(
                'ONSET build ${release.build} is ready.',
                style: TextStyle(
                  fontFamily: OnsetTokens.bodyFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
              Text(
                installed,
                style: OnsetType.tabular(
                  TextStyle(
                    fontFamily: OnsetTokens.bodyFamily,
                    fontSize: 12.5,
                    color: colors.secondary,
                  ),
                ),
              ),
            ],
          ),
          if (notes.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 123),
              decoration: BoxDecoration(
                color: colors.well,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colors.cardRing,
                  width: OnsetTokens.hairlineWidth,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      notes,
                      maxLines: 6,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        fontFamily: OnsetTokens.bodyFamily,
                        fontSize: 13,
                        height: 1.6,
                        color: colors.body,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 34,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              colors.well.withValues(alpha: 0),
                              colors.well,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              SettingsButton(
                label: 'Update',
                tone: SettingsButtonTone.primary,
                large: true,
                expand: true,
                onPressed: () => Navigator.pop(context, true),
              ),
              SettingsButton(
                label: 'Later',
                large: true,
                expand: true,
                onPressed: () => Navigator.pop(context, false),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Downloads and installs [release] while showing its progress, then waits on
/// the system installer. Pops with null once installed, or with the error.
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
  var _installing = false;
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
        onInstall: () {
          if (mounted) setState(() => _installing = true);
        },
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
    final progress = _installing || _total <= 0
        ? null
        : (_received / _total).clamp(0.0, 1.0);

    final colors = SettingsColors.of(context);
    return PopScope(
      canPop: false,
      child: SettingsDialog(
        title: _installing ? 'Installing update' : 'Downloading update',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 14,
          children: [
            LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
              color: SettingsColors.accentOf(context),
              backgroundColor: colors.switchOff,
            ),
            Text(
              _total > 0
                  ? '${_megabytes(_received)} / ${_megabytes(_total)} MB'
                  : '${_megabytes(_received)} MB',
              style: OnsetType.tabular(
                TextStyle(
                  fontFamily: OnsetTokens.bodyFamily,
                  fontSize: 13,
                  color: colors.secondary,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Opacity(
            opacity: _installing ? 0.4 : 1,
            child: SettingsButton(
              label: 'Cancel',
              onPressed: _installing || _cancelToken.isCancelled
                  ? null
                  : () => setState(() => _cancelToken.cancel()),
            ),
          ),
        ],
      ),
    );
  }
}

/// Removes already installed downloads when the screen starts, then looks
/// for an update and offers it, again each time the app comes back to the
/// foreground. Does nothing without an [OnsetUpdater] provided above the
/// screen, and only cleans up when it is not enabled.
mixin OnsetUpdateChecks<T extends StatefulWidget> on State<T> {
  OnsetUpdater? _updater;
  AppLifecycleListener? _updateLifecycle;
  var _updateBusy = false;

  @override
  void initState() {
    super.initState();
    final updater = context.read<OnsetUpdater?>();
    if (updater == null) return;
    unawaited(updater.removeInstalledDownloads());
    if (!updater.enabled) return;
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
        await beforeUpdateOffer();
        if (!mounted) return;
        await offerUpdate(context, updater, result);
      }
    } catch (e) {
      // An update is never worth an error screen: the next resume retries.
      debugPrint('Update check failed: ${e.runtimeType}');
    } finally {
      _updateBusy = false;
    }
  }

  /// Waited for before the offer opens: a screen with a sheet of its own to
  /// show first (Home's one-time language question) completes it once
  /// that sheet is closed, so the two never stack.
  Future<void> beforeUpdateOffer() async {}

  @override
  void dispose() {
    _updateLifecycle?.dispose();
    super.dispose();
  }
}
