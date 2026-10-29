import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/constants.dart';
import 'package:onset/firebase_options.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/services/go_live/go_live.dart';
import 'package:onset/services/notifications/activity_log.dart';
import 'package:workmanager/workmanager.dart';

const _task = 'frosty.goLive';

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

/// The background entry point (its own isolate).
@pragma('vm:entry-point')
void goLiveCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != _task) return true;
    var crashlytics = false;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      crashlytics = true;
    } catch (_) {
      // Reporting is a bonus: the check runs without it.
    }
    void report(Object error, StackTrace stack) {
      debugPrint('Go-live check failed: $error');
      if (!crashlytics) return;
      try {
        FirebaseCrashlytics.instance.recordError(
          error,
          stack,
          reason: 'go-live background check',
        );
      } catch (_) {}
    }

    try {
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
          await GoLiveNotifications.show(notices, more);
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
        notifyProblem: GoLiveNotifications.showProblem,
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

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'go_live',
      'Go live',
      channelDescription: 'When channels you follow go live',
      groupKey: 'frosty.goLive',
      // A channel announced twice (the app and the background task at the
      // same moment) replaces its notice without a second alert.
      onlyAlertOnce: true,
    ),
    iOS: DarwinNotificationDetails(threadIdentifier: 'go_live'),
  );

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

  /// Says once that the notices are paused, and why.
  static Future<void> showProblem(String message) => _plugin.show(
    id: 1,
    title: 'Go-live notifications paused',
    body: message,
    notificationDetails: _details,
  );

  static Future<void> show(List<GoLiveNotice> notices, int more) async {
    for (final notice in notices) {
      await _plugin.show(
        // One per channel: a new go-live replaces the last one.
        id: int.parse(notice.userId) % 0x7fffffff,
        title: notice.title,
        body: notice.body.isEmpty ? null : notice.body,
        notificationDetails: _details,
        payload: notice.login,
      );
    }
    if (more > 0) {
      await _plugin.show(
        id: 0,
        title: '$more more channel${more == 1 ? '' : 's'} went live',
        notificationDetails: _details,
      );
    }
  }
}
