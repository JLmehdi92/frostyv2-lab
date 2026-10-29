import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The Firebase project a build reports to, from `--dart-define`s. The
/// repository carries none: a build without them simply has no Firebase.
@immutable
class FirebaseConfig {
  const FirebaseConfig({
    required this.apiKey,
    required this.appIdAndroid,
    required this.appIdIos,
    required this.messagingSenderId,
    required this.projectId,
    required this.storageBucket,
  });

  final String apiKey;
  final String appIdAndroid;
  final String appIdIos;
  final String messagingSenderId;
  final String projectId;

  /// Optional: Crashlytics, Analytics and Performance do not need it.
  final String storageBucket;

  /// No Firebase at all.
  static const none = FirebaseConfig(
    apiKey: '',
    appIdAndroid: '',
    appIdIos: '',
    messagingSenderId: '',
    projectId: '',
    storageBucket: '',
  );

  /// The values this build was given.
  static const fromEnvironment = FirebaseConfig(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
    appIdAndroid: String.fromEnvironment('FIREBASE_APP_ID_ANDROID'),
    appIdIos: String.fromEnvironment('FIREBASE_APP_ID_IOS'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
    storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
  );

  /// Whether every value both platforms share is there (the app id is
  /// checked per platform by [firebaseOptionsFrom]).
  bool get isComplete =>
      apiKey.isNotEmpty && messagingSenderId.isNotEmpty && projectId.isNotEmpty;
}

/// The options to start Firebase with on [platform], or null when [config]
/// lacks a value it needs there (or ONSET does not ship on [platform]).
FirebaseOptions? firebaseOptionsFrom(
  FirebaseConfig config,
  TargetPlatform platform,
) {
  if (!config.isComplete) return null;
  final appId = switch (platform) {
    TargetPlatform.android => config.appIdAndroid,
    TargetPlatform.iOS => config.appIdIos,
    _ => '',
  };
  if (appId.isEmpty) return null;
  return FirebaseOptions(
    apiKey: config.apiKey,
    appId: appId,
    messagingSenderId: config.messagingSenderId,
    projectId: config.projectId,
    storageBucket: config.storageBucket.isEmpty ? null : config.storageBucket,
    iosBundleId: platform == TargetPlatform.iOS ? 'app.onset' : null,
  );
}

/// Crashlytics, Analytics and Performance, behind one switch.
///
/// Firebase is optional: it starts only when the build carries a
/// [FirebaseConfig]. Until [initialize] succeeds (a build without the
/// config, the tests, a background isolate that never asked) every call
/// here does nothing, so callers never guard or catch around it.
abstract final class Telemetry {
  static bool _enabled = false;

  /// Whether Firebase is up in this isolate.
  static bool get enabled => _enabled;

  /// Starts Firebase when this build has a config. With [reportUncaught],
  /// uncaught framework and platform errors go to Crashlytics as fatal (the
  /// app's main isolate; a background isolate passes false).
  static Future<bool> initialize({bool reportUncaught = true}) async {
    if (_enabled) return true;
    if (kIsWeb) return false;
    final options = firebaseOptionsFrom(
      FirebaseConfig.fromEnvironment,
      defaultTargetPlatform,
    );
    if (options == null) return false;
    try {
      await Firebase.initializeApp(options: options);
    } catch (e) {
      debugPrint('Firebase unavailable: $e');
      return false;
    }
    _enabled = true;
    if (reportUncaught) {
      FlutterError.onError = recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        recordError(error, stack, fatal: true);
        return true;
      };
    }
    return true;
  }

  /// Runs [use] when Firebase is up; a Firebase failure, sync or async, is
  /// only printed (never an uncaught error that would be reported again).
  static void _guard(Object? Function() use) {
    if (!_enabled) return;
    try {
      final result = use();
      if (result is Future<Object?>) {
        unawaited(
          result.then<void>(
            (_) {},
            onError: (Object e) => debugPrint('Firebase call failed: $e'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Firebase call failed: $e');
    }
  }

  static void recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) => _guard(
    () => FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      reason: reason,
      fatal: fatal,
    ),
  );

  static void recordFlutterFatalError(FlutterErrorDetails details) => _guard(
    () => FirebaseCrashlytics.instance.recordFlutterFatalError(details),
  );

  static void log(String message) =>
      _guard(() => FirebaseCrashlytics.instance.log(message));

  static void setCustomKey(String key, Object value) =>
      _guard(() => FirebaseCrashlytics.instance.setCustomKey(key, value));

  static void setUserIdentifier(String identifier) =>
      _guard(() => FirebaseCrashlytics.instance.setUserIdentifier(identifier));

  /// Turns crash reports, analytics and performance traces on or off.
  static void setCollectionEnabled(bool enabled) {
    _guard(
      () =>
          FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(enabled),
    );
    _guard(
      () => FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(enabled),
    );
    _guard(
      () =>
          FirebasePerformance.instance.setPerformanceCollectionEnabled(enabled),
    );
  }

  /// A started-to-be trace of a request to [url], or null without Firebase.
  static HttpMetric? newHttpMetric(String url, String method) {
    if (!_enabled) return null;
    try {
      return FirebasePerformance.instance.newHttpMetric(
        url,
        _httpMethod(method),
      );
    } catch (e) {
      debugPrint('Firebase call failed: $e');
      return null;
    }
  }

  /// The screen-view observer, when Firebase is up.
  static List<NavigatorObserver> navigatorObservers() {
    if (!_enabled) return const [];
    try {
      return [FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance)];
    } catch (e) {
      debugPrint('Firebase call failed: $e');
      return const [];
    }
  }

  static HttpMethod _httpMethod(String method) =>
      switch (method.toUpperCase()) {
        'GET' => HttpMethod.Get,
        'POST' => HttpMethod.Post,
        'PUT' => HttpMethod.Put,
        'DELETE' => HttpMethod.Delete,
        'PATCH' => HttpMethod.Patch,
        _ => HttpMethod.Get,
      };
}
