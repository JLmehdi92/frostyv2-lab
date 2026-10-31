import 'package:flutter_test/flutter_test.dart';
import 'package:onset/constants.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/services/go_live/go_live_worker.dart';

void main() {
  test('a notice opens only a well-formed login', () {
    expect(GoLiveNotifications.loginOf('some_streamer'), 'some_streamer');
    expect(GoLiveNotifications.loginOf(null), isNull);
    expect(GoLiveNotifications.loginOf(''), isNull);
    expect(GoLiveNotifications.loginOf('../evil'), isNull);
    expect(GoLiveNotifications.loginOf('a' * 26), isNull);
    // A mention notice is not a go-live one.
    expect(GoLiveNotifications.loginOf('mention:some_streamer'), isNull);
  });

  test("a mention notice opens its channel's login, well-formed only", () {
    expect(
      GoLiveNotifications.mentionLoginOf('mention:some_streamer'),
      'some_streamer',
    );
    expect(GoLiveNotifications.mentionLoginOf('some_streamer'), isNull);
    expect(GoLiveNotifications.mentionLoginOf('mention:'), isNull);
    expect(GoLiveNotifications.mentionLoginOf('mention:../evil'), isNull);
    expect(GoLiveNotifications.mentionLoginOf('mention:${'a' * 26}'), isNull);
    expect(GoLiveNotifications.mentionLoginOf(null), isNull);
  });

  test("the background check sends the token with its own app's client id", () {
    expect(goLiveHeaders('tok', tokenClientId: 'other_app'), {
      'Client-Id': 'other_app',
      'Authorization': 'Bearer tok',
    });
    // This app's token (nothing stored): this app's client id.
    expect(goLiveHeaders('tok')['Client-Id'], clientId);
  });

  test('the background check reports only what the app was allowed to', () {
    // Its own isolate: it reads the "Share crash logs and analytics"
    // setting the app saved, off when there is none or it does not read.
    expect(sharesCrashLogsIn(null), isFalse);
    expect(sharesCrashLogsIn('{}'), isFalse);
    expect(sharesCrashLogsIn('not json'), isFalse);
    expect(sharesCrashLogsIn('[]'), isFalse);
    expect(sharesCrashLogsIn('{"shareCrashLogsAndAnalytics":"yes"}'), isFalse);
    expect(sharesCrashLogsIn('{"shareCrashLogsAndAnalytics":false}'), isFalse);
    expect(
      sharesCrashLogsIn(
        '{"shareCrashLogsAndAnalytics":true,'
        '"telemetryConsentVersion":$kTelemetryConsentVersion}',
      ),
      isTrue,
    );
  });

  test('the background check ignores an "on" saved before the consent '
      'version', () {
    // It can run after an update before the app has opened (and saved the
    // migrated settings): an old "on" was ticked for the viewer.
    expect(sharesCrashLogsIn('{"shareCrashLogsAndAnalytics":true}'), isFalse);
    expect(
      sharesCrashLogsIn(
        '{"shareCrashLogsAndAnalytics":true,"telemetryConsentVersion":0}',
      ),
      isFalse,
    );
    expect(
      sharesCrashLogsIn(
        '{"shareCrashLogsAndAnalytics":true,"telemetryConsentVersion":"1"}',
      ),
      isFalse,
    );
  });

  group('the background check starts Firebase', () {
    const on =
        '{"shareCrashLogsAndAnalytics":true,'
        '"telemetryConsentVersion":$kTelemetryConsentVersion}';
    const off =
        '{"shareCrashLogsAndAnalytics":false,'
        '"telemetryConsentVersion":$kTelemetryConsentVersion}';

    Future<({int starts, List<bool> collection})> run(
      List<String?> reads, {
      bool firebaseStarts = true,
    }) async {
      var starts = 0;
      final collection = <bool>[];
      final queue = [...reads];
      await initGoLiveTelemetry(
        readSettings: () async => queue.removeAt(0),
        startFirebase: () async {
          starts++;
          return firebaseStarts;
        },
        setCollection: collection.add,
      );
      return (starts: starts, collection: collection);
    }

    test('not at all for a viewer who does not share', () async {
      for (final saved in [
        null,
        '{}',
        off,
        '{"shareCrashLogsAndAnalytics":true}',
      ]) {
        final result = await run([saved]);
        expect(result.starts, 0, reason: '$saved');
        expect(result.collection, isEmpty, reason: '$saved');
      }
    });

    test('not when the settings do not read', () async {
      var starts = 0;
      await initGoLiveTelemetry(
        readSettings: () async => throw StateError('no prefs'),
        startFirebase: () async {
          starts++;
          return true;
        },
        setCollection: (_) => fail('collection set'),
      );
      expect(starts, 0);
    });

    test('and collects for a viewer who shares', () async {
      final result = await run([on, on]);
      expect(result.starts, 1);
      expect(result.collection, [true]);
    });

    test(
      'and turns collection off when the viewer opted out meanwhile',
      () async {
        // Read on, then the viewer turns the switch off in the app while
        // Firebase starts: the second read wins.
        final result = await run([on, off]);
        expect(result.starts, 1);
        expect(result.collection, [false]);
      },
    );

    test('and leaves collection alone when Firebase does not start', () async {
      final result = await run([on], firebaseStarts: false);
      expect(result.starts, 1);
      expect(result.collection, isEmpty);
    });
  });
}
