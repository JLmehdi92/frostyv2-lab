import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/constants.dart';
import 'package:onset/l10n/l10n.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/services/go_live/go_live.dart';
import 'package:onset/services/notifications/activity_log.dart';
import 'package:onset/services/telemetry.dart';
import 'package:onset/services/telemetry_consent.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

const _task = 'onset.goLive';

/// The headers of the background check's Helix calls: [token] with its own
/// app's client id ([tokenClientId], kept with a token of another app),
/// else this app's.
Map<String, String> goLiveHeaders(String token, {String? tokenClientId}) => {
  'Client-Id': tokenClientId ?? clientId,
  'Authorization': 'Bearer $token',
};

/// Android runs it at most every 15 minutes, when the phone allows it.
const kGoLiveInterval = Duration(minutes: 15);

final _login = RegExp(r'^[a-zA-Z0-9_]{1,25}$');

/// The "Share crash logs and analytics" setting in [saved], the settings
/// JSON the app keeps (`main.dart`): the default (off) without one, when it
/// does not read, or when it was saved below [kTelemetryConsentVersion]
/// (the check can run after an update before the app has opened and saved
/// its migrated settings; see `SettingsStore.telemetryConsentVersion`).
bool sharesCrashLogsIn(String? saved) {
  // The setting's default: off until the viewer opts in.
  const fallback = false;
  if (saved == null) return fallback;
  try {
    final settings = jsonDecode(saved);
    if (settings is! Map) return fallback;
    final version = settings['telemetryConsentVersion'];
    if (version is! int || version < kTelemetryConsentVersion) {
      return fallback;
    }
    final value = settings['shareCrashLogsAndAnalytics'];
    return value is bool ? value : fallback;
  } on FormatException {
    return fallback;
  }
}

/// Starts Firebase for the background check only when the viewer shares
/// crash logs and analytics ([sharesCrashLogsIn] on what [readSettings]
/// returns): a viewer who does not share never has Firebase started in the
/// background. Once [startFirebase] succeeds, the settings are read again
/// right before [setCollection], so an opt-out made in the app meanwhile
/// turns collection off instead of on. Settings that do not read count as
/// off.
@visibleForTesting
Future<void> initGoLiveTelemetry({
  required Future<String?> Function() readSettings,
  required Future<bool> Function() startFirebase,
  required void Function(bool shared) setCollection,
}) async {
  Future<bool> shares() async {
    try {
      return sharesCrashLogsIn(await readSettings());
    } catch (e) {
      debugPrint('Go-live check: settings unreadable: $e');
      return false;
    }
  }

  if (!await shares()) return;
  if (!await startFirebase()) return;
  setCollection(await shares());
}

/// The settings the app saved, as it last wrote them (another isolate: the
/// cached copy may be stale).
Future<String?> _readSavedSettings() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  return prefs.getString('settings');
}

/// Firebase for the background check (never collecting in a debug build,
/// as `main.dart`).
Future<void> _initTelemetry() => initGoLiveTelemetry(
  readSettings: _readSavedSettings,
  startFirebase: () => Telemetry.initialize(reportUncaught: false),
  setCollection: setFirebaseCollection,
);

/// Shows, in this isolate, the language the app shows: [L10n] and `Intl`
/// set to [uiLanguageIn] what [prefs] keep (read afresh: the app is another
/// isolate) and the device prefers ([device]), dates loaded for it (there
/// is no MaterialApp here to load them). Returns its texts.
///
/// Preferences that cannot be read (damaged, or a failed reload) give
/// English: the failure goes to [report] (else the log), and the check
/// goes on.
Future<AppLocalizations> useBackgroundLanguage(
  SharedPreferences prefs,
  List<Locale> device, {
  void Function(Object error, StackTrace stack)? report,
}) async {
  try {
    await prefs.reload();
    final language = uiLanguageIn(
      saved: prefs.getString(kUiLanguagePrefsKey),
      settingsJson: prefs.getString('settings'),
      device: device,
    );
    await initializeDateFormatting(language);
    L10n.use(Locale(language));
  } catch (error, stack) {
    if (report != null) {
      report(error, stack);
    } else {
      debugPrint('Background language not read: $error');
    }
    await initializeDateFormatting('en');
    L10n.use(const Locale('en'));
  }
  return L10n.current;
}

/// The background entry point (its own isolate).
@pragma('vm:entry-point')
void goLiveCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != _task) return true;
    // Reporting is a bonus: the check runs without it (and without Firebase
    // in a build that has no config, or without the viewer's consent, in
    // which case Firebase is not even started).
    await _initTelemetry();
    void report(Object error, StackTrace stack) {
      debugPrint('Go-live check failed: $error');
      Telemetry.recordError(error, stack, reason: 'go-live background check');
    }

    try {
      // The notices in the app's language, not the isolate's English.
      final l = await useBackgroundLanguage(
        await SharedPreferences.getInstance(),
        PlatformDispatcher.instance.locales,
        report: report,
      );
      await GoLiveNotifications.init();
      // The app a token of another app was issued to (kept with it): Helix
      // takes the token only with that app's client id.
      String? tokenClientId;
      try {
        tokenClientId = await const FlutterSecureStorage().read(
          key: AuthBase.userTokenClientIdKey,
        );
      } catch (error, stack) {
        report(error, stack);
      }
      return await runGoLiveTask(
        readToken: () =>
            const FlutterSecureStorage().read(key: AuthBase.userTokenKey),
        buildApi: (token) => TwitchApi(
          Dio(
            BaseOptions(
              headers: goLiveHeaders(token, tokenClientId: tokenClientId),
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
            ),
          ),
        ),
        prefs: await GoLivePrefs.load(),
        notify: (notices, more) async {
          await GoLiveNotifications.show(notices, more, l);
          // Listed in Activity too; a failure there must not announce
          // them again.
          try {
            final now = DateTime.now();
            await (await ActivityLog.load()).addAll([
              for (final notice in notices) goLiveEntry(notice, now),
            ]);
          } catch (error, stack) {
            report(error, stack);
          }
        },
        notifyProblem: (_) => GoLiveNotifications.showProblem(l),
        report: report,
      );
    } catch (error, stack) {
      report(error, stack);
      return false;
    }
  });
}

/// Starts or stops the periodic background check (Android only: iOS gives
/// apps no dependable periodic background time).
abstract final class GoLiveScheduler {
  static var _initialized = false;

  static bool get supported => Platform.isAndroid;

  static Future<void> _init() async {
    if (_initialized) return;
    await Workmanager().initialize(goLiveCallbackDispatcher);
    _initialized = true;
  }

  static Future<void> start() async {
    if (!supported) return;
    await _init();
    await Workmanager().registerPeriodicTask(
      _task,
      _task,
      frequency: kGoLiveInterval,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  }

  static Future<void> stop() async {
    if (!supported) return;
    await _init();
    await Workmanager().cancelByUniqueName(_task);
  }
}

/// The go-live notifications: one per channel (tapping opens it), and one
/// summing up a burst.
abstract final class GoLiveNotifications {
  static final _plugin = FlutterLocalNotificationsPlugin();

  /// How they show, in [l]'s language: Android names the channel in the
  /// system's settings each time one is posted, so it follows the language.
  @visibleForTesting
  static NotificationDetails detailsFor(AppLocalizations l) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          'go_live',
          l.notifChannelGoLive,
          channelDescription: l.notifChannelGoLiveDescription,
          groupKey: 'onset.goLive',
          // Renames the existing channel when the language changed (the
          // default only creates a missing one). Android keeps the viewer's
          // settings of the channel: only its name and description change.
          channelAction: AndroidNotificationChannelAction.update,
          // A channel announced twice (the app and the background task at
          // the same moment) replaces its notice without a second alert.
          onlyAlertOnce: true,
        ),
        iOS: const DarwinNotificationDetails(threadIdentifier: 'go_live'),
      );

  @visibleForTesting
  static NotificationDetails detailsForNotice(
    AppLocalizations l, {
    Uint8List? avatar,
    Uint8List? categoryArt,
  }) {
    final base = detailsFor(l);
    final android = base.android!;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        android.channelId,
        android.channelName,
        channelDescription: android.channelDescription,
        groupKey: android.groupKey,
        channelAction: android.channelAction,
        onlyAlertOnce: true,
        largeIcon: avatar == null ? null : ByteArrayAndroidBitmap(avatar),
        styleInformation: categoryArt == null
            ? null
            : BigPictureStyleInformation(
                ByteArrayAndroidBitmap(categoryArt),
                largeIcon: avatar == null
                    ? null
                    : ByteArrayAndroidBitmap(avatar),
              ),
      ),
      iOS: base.iOS,
    );
  }

  @visibleForTesting
  static NotificationDetails summaryDetails(AppLocalizations l) {
    final android = detailsFor(l).android!;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        android.channelId,
        android.channelName,
        channelDescription: android.channelDescription,
        groupKey: android.groupKey,
        channelAction: android.channelAction,
        onlyAlertOnce: true,
        setAsGroupSummary: true,
      ),
    );
  }

  static const maxImageBytes = 2 * 1024 * 1024;
  static const imageTimeout = Duration(seconds: 8);

  @visibleForTesting
  static Future<Uint8List?> downloadImage(String? url, {Dio? dio}) async {
    if (url == null || !isTwitchImageUrl(url)) return null;
    final cancel = CancelToken();
    try {
      final client =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 5),
            ),
          );
      return await _read(client, url, cancel).timeout(
        imageTimeout,
        onTimeout: () {
          cancel.cancel('Go-live image too slow');
          return null;
        },
      );
    } catch (e) {
      debugPrint('Go-live image unavailable: ${e.runtimeType}');
      return null;
    }
  }

  static Future<Uint8List?> _read(
    Dio client,
    String url,
    CancelToken cancel,
  ) async {
    final response = await client.get<ResponseBody>(
      url,
      cancelToken: cancel,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: false,
        validateStatus: (status) => status == 200,
      ),
    );
    final body = response.data;
    if (body == null) return null;
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in body.stream) {
      bytes.add(chunk);
      if (bytes.length > maxImageBytes) {
        cancel.cancel('Go-live image too large');
        return null;
      }
    }
    return bytes.isEmpty ? null : bytes.takeBytes();
  }

  static final _ready = Completer<void>();

  /// Done once [init] has set the plugin up: nothing shows before.
  static Future<void> get ready => _ready.future;

  /// [onOpen] gets the login of a tapped go-live notice while the app runs,
  /// [onMention] the channel's login of a tapped mention notice.
  static Future<void> init({
    void Function(String login)? onOpen,
    void Function(String login)? onMention,
  }) async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_go_live'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final login = loginOf(response.payload);
        if (login != null) onOpen?.call(login);
        final mention = mentionLoginOf(response.payload);
        if (mention != null) onMention?.call(mention);
      },
    );
    if (!_ready.isCompleted) _ready.complete();
  }

  /// The login a notice carries, or null when it is not one.
  @visibleForTesting
  static String? loginOf(String? payload) =>
      payload != null && _login.hasMatch(payload) ? payload : null;

  /// The channel login a mention notice carries (`mention:<login>`), or
  /// null when it is not one.
  @visibleForTesting
  static String? mentionLoginOf(String? payload) {
    const prefix = 'mention:';
    if (payload == null || !payload.startsWith(prefix)) return null;
    return loginOf(payload.substring(prefix.length));
  }

  /// The notice the app was opened from, if any: its channel's login, and
  /// whether it is a mention.
  static Future<({String login, bool mention})?> launchNotice() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    final payload = details?.notificationResponse?.payload;
    final login = loginOf(payload);
    if (login != null) return (login: login, mention: false);
    final mention = mentionLoginOf(payload);
    if (mention != null) return (login: mention, mention: true);
    return null;
  }

  /// Asks for the right to notify (Android 13+, iOS); true when granted.
  static Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, sound: true) ??
        false;
  }

  /// Whether notices can show (the user may have blocked them since).
  static Future<bool> allowed() async {
    if (!Platform.isAndroid) return true;
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.areNotificationsEnabled() ??
        true;
  }

  /// Says once, in [l]'s language, that the notices are paused because
  /// Twitch refused the login ([kGoLiveLoggedOut], the only problem kept).
  static Future<void> showProblem(AppLocalizations l) => _plugin.show(
    id: kGoLiveProblemId,
    title: l.notifGoLivePaused,
    body: l.goLiveLogInAgain,
    notificationDetails: detailsFor(l),
  );

  /// Posts [notices] (worded already) and, in [l]'s language, the one
  /// summing up [more] channels beyond them.
  static Future<void> show(
    List<GoLiveNotice> notices,
    int more,
    AppLocalizations l,
  ) async {
    for (final notice in notices) {
      final (avatar, art) = await (
        downloadImage(notice.avatarUrl),
        downloadImage(goLiveCategoryArtUrl(notice)),
      ).wait;
      await _plugin.show(
        id: goLiveNoticeId(notice),
        title: notice.title,
        body: notice.body.isEmpty ? null : notice.body,
        notificationDetails: detailsForNotice(
          l,
          avatar: avatar,
          categoryArt: art,
        ),
        payload: notice.login,
      );
    }
    if (notices.length + (more > 0 ? 1 : 0) > 1) {
      await _plugin.show(
        id: kGoLiveSummaryId,
        title: l.notifChannelGoLive,
        notificationDetails: summaryDetails(l),
      );
    }
    final details = detailsFor(l);
    if (more > 0) {
      await _plugin.show(
        id: kGoLiveMoreId,
        title: l.notifGoLiveMore(count: more),
        notificationDetails: details,
      );
    }
  }
}
