import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:frosty/apis/onset_update_service.dart';
import 'package:frosty/constants.dart';
import 'package:frosty/models/onset_release.dart';
import 'package:frosty/services/onset_installer.dart';
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

/// The system installer could not be opened.
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
  /// [checkInterval] and keeps a build the viewer postponed quiet for
  /// [postponeFor].
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
    await prefs.setInt(_lastCheckKey, now.millisecondsSinceEpoch);

    final current = await _currentBuild();
    if (release.build <= current) return const UpToDate();

    if (!force && prefs.getInt(_postponedBuildKey) == release.build) {
      final postponedAt = prefs.getInt(_postponedAtKey);
      if (postponedAt != null && _since(postponedAt, now) < postponeFor) {
        return const UpdateCheckSkipped();
      }
    }
    return UpdateAvailable(release, current);
  }

  /// The viewer chose "Later" for [release].
  Future<void> postpone(OnsetRelease release) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_postponedBuildKey, release.build);
    await prefs.setInt(_postponedAtKey, _now().millisecondsSinceEpoch);
  }

  /// Whether ONSET may install apps. When it may not, opens the system page
  /// that allows it and returns false.
  Future<bool> ensureCanInstall() async {
    if (await _installer.canInstall()) return true;
    await _installer.openInstallSettings();
    return false;
  }

  /// Whether ONSET may install apps, without opening anything.
  Future<bool> canInstall() => _installer.canInstall();

  /// Downloads and verifies [release], then opens the system installer.
  ///
  /// Throws the download errors of [OnsetUpdateService.download], or
  /// [UpdateInstallException].
  Future<void> downloadAndInstall(
    OnsetRelease release, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final file = await _service.download(
      release,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    try {
      await _installer.install(file.path);
    } on PlatformException {
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
