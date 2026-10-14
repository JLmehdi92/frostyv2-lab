import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frosty/apis/base_api_client.dart';
import 'package:frosty/apis/twitch_api.dart';
import 'package:frosty/constants.dart';
import 'package:frosty/screens/settings/stores/auth_store.dart';
import 'package:frosty/services/go_live/go_live.dart';
import 'package:workmanager/workmanager.dart';

const _task = 'frosty.goLive';

/// Android runs it at most every 15 minutes, when the phone allows it.
const kGoLiveInterval = Duration(minutes: 15);

final _login = RegExp(r'^[a-zA-Z0-9_]{1,25}$');

/// The background entry point (its own isolate).
@pragma('vm:entry-point')
void goLiveCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != _task) return true;
    try {
      final token = await const FlutterSecureStorage().read(
        key: AuthBase.userTokenKey,
      );
      if (token == null) return true;
      final api = TwitchApi(
        Dio(
          BaseOptions(
            headers: {'Client-Id': clientId, 'Authorization': 'Bearer $token'},
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 15),
          ),
        ),
      );
      await GoLiveNotifications.init();
      await checkGoLive(
        api: api,
        prefs: await GoLivePrefs.load(),
        notify: GoLiveNotifications.show,
      );
      return true;
    } on UnauthorizedException {
      // Logged out elsewhere or expired: the app asks to log in again.
      return true;
    } catch (e) {
      debugPrint('Go-live check failed: $e');
      // Asks Android to try again later.
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
    ),
    iOS: DarwinNotificationDetails(threadIdentifier: 'go_live'),
  );

  /// [onOpen] gets the login of a tapped notice while the app runs.
  static Future<void> init({void Function(String login)? onOpen}) async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final login = loginOf(response.payload);
        if (login != null) onOpen?.call(login);
      },
    );
  }

  /// The login a notice carries, or null when it is not one.
  @visibleForTesting
  static String? loginOf(String? payload) =>
      payload != null && _login.hasMatch(payload) ? payload : null;

  /// The login of the notice the app was opened from, if any.
  static Future<String?> launchLogin() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    return loginOf(details?.notificationResponse?.payload);
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
