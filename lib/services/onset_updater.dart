import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onset/apis/onset_update_service.dart';
import 'package:onset/constants.dart';
import 'package:onset/models/onset_release.dart';
import 'package:onset/services/onset_installer.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What an update check found.
sealed class UpdateCheck {
  const UpdateCheck();
}

/// A newer build than the installed one.
final class UpdateAvailable extends UpdateCheck {
  final OnsetRelease release;
  final int currentBuild;

  const UpdateAvailable(this.release, this.currentBuild);
}

/// The installed build is the latest one.
final class UpToDate extends UpdateCheck {
  const UpToDate();
}

/// Nothing was asked: updates are off, checked recently, or postponed.
final class UpdateCheckSkipped extends UpdateCheck {
  const UpdateCheckSkipped();
}

/// GitHub could not be read, or holds no complete ONSET build.
final class UpdateCheckFailed extends UpdateCheck {
  const UpdateCheckFailed();
}

/// Android could not install the update.
class UpdateInstallException implements Exception {
  const UpdateInstallException();
}

/// Finds newer ONSET builds and installs them.
///
/// Only Android builds made by the update workflow (which bakes in
/// `UPDATE_TOKEN` and `UPDATE_REPO`) are enabled: anywhere else no request is
/// ever made.
class OnsetUpdater {
  static const checkInterval = Duration(hours: 6);
  static const postponeFor = Duration(hours: 24);

  static const _lastCheckKey = 'onset_update_last_check';
  static const _postponedBuildKey = 'onset_update_postponed_build';
  static const _postponedAtKey = 'onset_update_postponed_at';

  final bool enabled;
  final OnsetUpdateService _service;
  final OnsetInstaller _installer;
  final Future<int> Function() _currentBuild;
  final DateTime Function() _now;

  OnsetUpdater({
    String token = updateToken,
    String repo = updateRepo,
    bool? isAndroid,
    OnsetUpdateService? service,
    OnsetInstaller installer = const OnsetInstaller(),
    Future<int> Function()? currentBuild,
    DateTime Function()? now,
  }) : enabled =
           (isAndroid ?? Platform.isAndroid) &&
           token.isNotEmpty &&
           repo.isNotEmpty,
       _service = service ?? OnsetUpdateService(token: token, repo: repo),
       _installer = installer,
       _currentBuild = currentBuild ?? _installedBuild,
       _now = now ?? DateTime.now;

  static Future<int> _installedBuild() async =>
      int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ?? 0;

  /// The build number of the installed app.
  Future<int> currentBuild() => _currentBuild();

  /// Looks for a newer build. Unless [force]d, asks GitHub at most every
  /// [checkInterval] after finding the installed build up to date, and keeps
  /// a build the viewer postponed quiet for [postponeFor].
  Future<UpdateCheck> check({bool force = false}) async {
    if (!enabled) return const UpdateCheckSkipped();
    final prefs = await SharedPreferences.getInstance();
    final now = _now();

    if (!force) {
      final last = prefs.getInt(_lastCheckKey);
      if (last != null && _since(last, now) < checkInterval) {
        return const UpdateCheckSkipped();
      }
    }

    final release = await _service.latest();
    if (release == null) return const UpdateCheckFailed();

    final current = await _currentBuild();
    if (release.build <= current) {
      // Only an up-to-date answer quiets the next checks: a newer build that
      // was not installed (the process can die while Android's "install
      // unknown apps" page is open) is offered again at the next start.
      await prefs.setInt(_lastCheckKey, now.millisecondsSinceEpoch);
      return const UpToDate();
    }

    if (!force && prefs.getInt(_postponedBuildKey) == release.build) {
      final postponedAt = prefs.getInt(_postponedAtKey);
      if (postponedAt != null && _since(postponedAt, now) < postponeFor) {
        return const UpdateCheckSkipped();
      }
    }
    return UpdateAvailable(release, current);
  }

  /// Deletes downloaded APKs that are already installed (or older), so an
  /// applied update does not keep its tens of megabytes in the cache. Runs in
  /// every build: one installed by hand over a downloaded update has it too.
  Future<void> removeInstalledDownloads() async {
    try {
      await _service.removeDownloadsUpTo(await _currentBuild());
    } catch (e) {
      debugPrint('Update cleanup failed: ${e.runtimeType}');
    }
  }

  /// The viewer chose "Later" for [release].
  Future<void> postpone(OnsetRelease release) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_postponedBuildKey, release.build);
    await prefs.setInt(_postponedAtKey, _now().millisecondsSinceEpoch);
  }

  /// Whether ONSET may install apps ("Install unknown apps").
  Future<bool> canInstall() => _installer.canInstall();

  /// Opens the system page that lets ONSET install apps.
  Future<void> openInstallSettings() => _installer.openInstallSettings();

  /// Downloads and verifies [release], calls [onInstall], then hands it to
  /// the system installer and waits for its answer (when the update succeeds
  /// Android replaces the app, which usually stops before that).
  ///
  /// Throws the download errors of [OnsetUpdateService.download],
  /// [UpdateCancelledException] when the viewer dismisses the installer, or
  /// [UpdateInstallException].
  Future<void> downloadAndInstall(
    OnsetRelease release, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
    void Function()? onInstall,
  }) async {
    final file = await _service.download(
      release,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    onInstall?.call();
    try {
      await _installer.install(file.path);
    } on PlatformException catch (e) {
      if (e.code == OnsetInstaller.abortedCode) {
        throw const UpdateCancelledException();
      }
      throw const UpdateInstallException();
    } on MissingPluginException {
      throw const UpdateInstallException();
    }
  }

  /// The time since [millis]. A clock set back reads as long ago, so a check
  /// or a postponement can never stay quiet for good.
  static Duration _since(int millis, DateTime now) {
    final elapsed = now.difference(DateTime.fromMillisecondsSinceEpoch(millis));
    return elapsed.isNegative ? postponeFor : elapsed;
  }
}
