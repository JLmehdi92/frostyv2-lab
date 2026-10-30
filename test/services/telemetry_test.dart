import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:onset/apis/firebase_performance_interceptor.dart';
import 'package:onset/screens/onboarding/onboarding_flow.dart';
import 'package:onset/services/telemetry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('firebaseOptionsFrom', () {
    FirebaseConfig config({
      String apiKey = 'key',
      String appIdAndroid = '1:1:android:a',
      String appIdIos = '1:1:ios:b',
      String messagingSenderId = '1',
      String projectId = 'project',
      String storageBucket = 'bucket',
    }) => FirebaseConfig(
      apiKey: apiKey,
      appIdAndroid: appIdAndroid,
      appIdIos: appIdIos,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      storageBucket: storageBucket,
    );

    test('is null for a build without a Firebase config', () {
      expect(
        firebaseOptionsFrom(FirebaseConfig.none, TargetPlatform.android),
        isNull,
      );
      expect(
        firebaseOptionsFrom(FirebaseConfig.none, TargetPlatform.iOS),
        isNull,
      );
    });

    test('is null when a required value is missing', () {
      for (final missing in [
        config(apiKey: ''),
        config(messagingSenderId: ''),
        config(projectId: ''),
        config(appIdAndroid: ''),
      ]) {
        expect(firebaseOptionsFrom(missing, TargetPlatform.android), isNull);
      }
      expect(
        firebaseOptionsFrom(config(appIdIos: ''), TargetPlatform.iOS),
        isNull,
      );
    });

    test('takes the app id of the platform', () {
      final android = firebaseOptionsFrom(config(), TargetPlatform.android)!;
      expect(android.appId, '1:1:android:a');
      expect(android.apiKey, 'key');
      expect(android.messagingSenderId, '1');
      expect(android.projectId, 'project');
      expect(android.storageBucket, 'bucket');

      final ios = firebaseOptionsFrom(config(), TargetPlatform.iOS)!;
      expect(ios.appId, '1:1:ios:b');
      expect(ios.iosBundleId, 'app.onset');
    });

    test('leaves the storage bucket out when it is not given', () {
      final options = firebaseOptionsFrom(
        config(storageBucket: ''),
        TargetPlatform.android,
      )!;
      expect(options.storageBucket, isNull);
    });

    test('is null on a platform ONSET does not ship on', () {
      expect(firebaseOptionsFrom(config(), TargetPlatform.linux), isNull);
      expect(firebaseOptionsFrom(config(), TargetPlatform.windows), isNull);
    });
  });

  group('without a Firebase config', () {
    test('the test build carries none', () {
      expect(FirebaseConfig.fromEnvironment.isComplete, isFalse);
    });

    test(
      'initialize leaves Firebase off and the error handlers alone',
      () async {
        final flutterHandler = FlutterError.onError;
        final platformHandler = PlatformDispatcher.instance.onError;

        expect(await Telemetry.initialize(), isFalse);
        expect(Telemetry.enabled, isFalse);
        expect(FlutterError.onError, same(flutterHandler));
        expect(PlatformDispatcher.instance.onError, same(platformHandler));
      },
    );

    test('every call is a no-op that does not throw', () {
      expect(Telemetry.enabled, isFalse);
      expect(
        () => Telemetry.recordError(StateError('x'), StackTrace.current),
        returnsNormally,
      );
      expect(
        () => Telemetry.recordError(
          StateError('x'),
          null,
          reason: 'why',
          fatal: true,
        ),
        returnsNormally,
      );
      expect(
        () => Telemetry.recordFlutterFatalError(
          FlutterErrorDetails(exception: StateError('x')),
        ),
        returnsNormally,
      );
      expect(() => Telemetry.log('message'), returnsNormally);
      expect(() => Telemetry.setCustomKey('key', true), returnsNormally);
      expect(() => Telemetry.setUserIdentifier('id'), returnsNormally);
      expect(() => Telemetry.setCollectionEnabled(true), returnsNormally);
      expect(() => Telemetry.setCollectionEnabled(false), returnsNormally);
      expect(Telemetry.newHttpMetric('https://example.com/a', 'GET'), isNull);
      expect(Telemetry.navigatorObservers(), isEmpty);
    });

    test('nothing is collected by default, nor after an opt-in', () {
      expect(Telemetry.collecting, isFalse);
      Telemetry.setCollectionEnabled(true);
      expect(Telemetry.collecting, isFalse);
      Telemetry.setCollectionEnabled(false);
      expect(Telemetry.collecting, isFalse);
    });

    test('the onboarding privacy choice does not throw', () {
      expect(() => setFirebaseCollection(true), returnsNormally);
      expect(() => setFirebaseCollection(false), returnsNormally);
    });

    test('requests still go through the performance interceptor', () async {
      final dio = Dio()..interceptors.add(FirebasePerformanceInterceptor());
      final adapter = DioAdapter(dio: dio);
      adapter.onGet(
        'https://example.com/ok',
        (server) => server.reply(200, {'ok': true}),
      );
      adapter.onGet(
        'https://example.com/fail',
        (server) => server.reply(500, {'ok': false}),
      );

      final response = await dio.get('https://example.com/ok');
      expect(response.statusCode, 200);
      expect(response.data, {'ok': true});

      await expectLater(
        dio.get('https://example.com/fail'),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            500,
          ),
        ),
      );
    });
  });

  group('before the viewer opts in', () {
    // Firebase "up" without a real app behind it: any call that reaches it
    // fails and is printed, so a print means the call went through.
    late List<String> printed;
    late DebugPrintCallback savedPrint;

    setUp(() {
      printed = [];
      savedPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
      Telemetry.debugReset(firebaseUp: true);
    });

    tearDown(() {
      debugPrint = savedPrint;
      Telemetry.debugReset();
    });

    void report() {
      Telemetry.recordError(StateError('x'), StackTrace.current);
      Telemetry.log('message');
      Telemetry.setCustomKey('key', true);
      expect(Telemetry.newHttpMetric('https://example.com/a', 'GET'), isNull);
    }

    test('Crashlytics and Performance get nothing', () {
      expect(Telemetry.enabled, isTrue);
      expect(Telemetry.collecting, isFalse);
      report();
      expect(printed, isEmpty);
    });

    test('they get reports once the viewer opts in, and none after', () {
      Telemetry.setCollectionEnabled(true);
      expect(Telemetry.collecting, isTrue);
      printed.clear();
      report();
      // Each of the four calls reached Firebase.
      expect(printed, hasLength(4));

      Telemetry.setCollectionEnabled(false);
      expect(Telemetry.collecting, isFalse);
      printed.clear();
      report();
      expect(printed, isEmpty);
    });

    test('an uncaught framework error is still shown, not reported', () {
      final shown = <FlutterErrorDetails>[];
      final savedPresent = FlutterError.presentError;
      FlutterError.presentError = shown.add;
      addTearDown(() => FlutterError.presentError = savedPresent);

      final details = FlutterErrorDetails(exception: StateError('x'));
      Telemetry.recordFlutterFatalError(details);

      expect(shown, [same(details)]);
      expect(printed, isEmpty);
    });
  });

  group('with a bundled native Firebase config', () {
    // A google-services.json / GoogleService-Info.plist starts Firebase
    // natively even without the dart-defines: nothing may be collected until
    // the app applies the "Share crash logs and analytics" setting.
    test('Android collects nothing by default', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');
      for (final key in [
        'firebase_crashlytics_collection_enabled',
        'firebase_analytics_collection_enabled',
        'firebase_performance_collection_enabled',
      ]) {
        expect(
          manifest,
          contains('android:name="$key" android:value="false"'),
          reason: key,
        );
      }
    });

    test('iOS collects nothing by default', () {
      final plist = File(
        'ios/Runner/Info.plist',
      ).readAsStringSync().replaceAll(RegExp(r'\s+'), '');
      for (final key in [
        'FirebaseCrashlyticsCollectionEnabled',
        'FIREBASE_ANALYTICS_COLLECTION_ENABLED',
        'firebase_performance_collection_enabled',
      ]) {
        expect(plist, contains('<key>$key</key><false/>'), reason: key);
      }
    });

    test('the repository carries no Firebase project config', () {
      for (final path in [
        'android/app/google-services.json',
        'ios/Runner/GoogleService-Info.plist',
        'ios/firebase_app_id_file.json',
        'lib/firebase_options.dart',
      ]) {
        expect(File(path).existsSync(), isFalse, reason: path);
      }
    });
  });
}
