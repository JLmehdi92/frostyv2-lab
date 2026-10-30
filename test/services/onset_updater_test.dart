import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/onset_update_service.dart';
import 'package:onset/models/onset_release.dart';
import 'package:onset/services/onset_installer.dart';
import 'package:onset/services/onset_updater.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockService extends Mock implements OnsetUpdateService {}

OnsetRelease _release(int build) => OnsetRelease(
  build: build,
  tag: 'build-$build',
  notes: 'notes',
  apkAssetId: 1,
  shaAssetId: 2,
  apkSize: 6,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockService service;
  late DateTime now;
  late List<MethodCall> calls;
  late bool canInstall;

  setUpAll(() => registerFallbackValue(_release(1)));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = _MockService();
    now = DateTime(2026, 10, 15, 12);
    calls = [];
    canInstall = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(OnsetInstaller.channel, (call) async {
          calls.add(call);
          return call.method == 'canInstall' ? canInstall : null;
        });
  });

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(OnsetInstaller.channel, null),
  );

  OnsetUpdater updater({
    String token = 'token',
    String repo = 'owner/app',
    bool isAndroid = true,
    int currentBuild = 1020,
  }) => OnsetUpdater(
    token: token,
    repo: repo,
    isAndroid: isAndroid,
    service: service,
    currentBuild: () async => currentBuild,
    now: () => now,
  );

  void latestIs(OnsetRelease? release) =>
      when(() => service.latest()).thenAnswer((_) async => release);

  group('enabled', () {
    test('needs Android and a repository', () {
      expect(updater().enabled, isTrue);
      expect(updater(repo: '').enabled, isFalse);
      expect(updater(token: '', repo: '').enabled, isFalse);
      expect(updater(isAndroid: false).enabled, isFalse);
    });

    test('a build made while the repository was public has no token and '
        'still looks for updates', () async {
      latestIs(_release(1023));
      final subject = updater(token: '');

      expect(subject.enabled, isTrue);
      expect(await subject.check(), isA<UpdateAvailable>());
    });

    test('a disabled updater never asks GitHub', () async {
      latestIs(_release(1023));

      expect(
        await updater(repo: '').check(force: true),
        isA<UpdateCheckSkipped>(),
      );
      expect(
        await updater(isAndroid: false).check(),
        isA<UpdateCheckSkipped>(),
      );
      verifyNever(() => service.latest());
    });

    test('the default build has no token and stays disabled', () {
      expect(OnsetUpdater().enabled, isFalse);
    });
  });

  group('check', () {
    test('offers a newer build', () async {
      latestIs(_release(1023));

      final result = await updater().check();

      expect((result as UpdateAvailable).release.build, 1023);
      expect(result.currentBuild, 1020);
    });

    test('the same or an older build is up to date', () async {
      latestIs(_release(1020));
      expect(await updater().check(), isA<UpToDate>());

      latestIs(_release(1001));
      expect(await updater().check(force: true), isA<UpToDate>());
    });

    test('no readable release is a failed check', () async {
      latestIs(null);

      expect(await updater().check(), isA<UpdateCheckFailed>());
    });

    test('asks at most every six hours', () async {
      latestIs(_release(1020));
      final subject = updater();

      await subject.check();
      now = now.add(const Duration(hours: 5, minutes: 59));
      expect(await subject.check(), isA<UpdateCheckSkipped>());
      verify(() => service.latest()).called(1);

      now = now.add(const Duration(minutes: 1));
      expect(await subject.check(), isA<UpToDate>());
      verify(() => service.latest()).called(1);
    });

    test('the six hours survive a restart', () async {
      latestIs(_release(1020));
      await updater().check();

      now = now.add(const Duration(hours: 1));
      expect(await updater().check(), isA<UpdateCheckSkipped>());
    });

    test('a newer build is offered again at the next start', () async {
      // The process can die while "install unknown apps" is being granted.
      latestIs(_release(1023));
      await updater().check();

      now = now.add(const Duration(minutes: 1));
      expect(await updater().check(), isA<UpdateAvailable>());
      verify(() => service.latest()).called(2);
    });

    test('a release hidden from a tokenless build is quietly no update, '
        'asked at most every six hours', () async {
      // A private repository answers 404 to a build that has no token.
      when(() => service.latest()).thenThrow(const UpdateNotVisibleException());
      final subject = updater(token: '');

      expect(await subject.check(), isA<UpToDate>());
      expect(await subject.check(force: true), isA<UpToDate>());
      now = now.add(const Duration(hours: 1));
      expect(await subject.check(), isA<UpdateCheckSkipped>());
      verify(() => service.latest()).called(2);
    });

    test('a failed check is retried at the next chance', () async {
      latestIs(null);
      await updater().check();

      latestIs(_release(1023));
      expect(await updater().check(), isA<UpdateAvailable>());
    });

    test('a clock set back does not silence checks', () async {
      latestIs(_release(1020));
      final subject = updater();

      await subject.check();
      now = now.subtract(const Duration(days: 3));
      expect(await subject.check(), isA<UpToDate>());
    });

    test('a forced check ignores the six hours', () async {
      latestIs(_release(1023));
      final subject = updater();

      await subject.check();
      expect(await subject.check(force: true), isA<UpdateAvailable>());
      verify(() => service.latest()).called(2);
    });
  });

  group('later', () {
    test('keeps the same build quiet for 24 hours', () async {
      latestIs(_release(1023));
      final subject = updater();

      await subject.postpone(_release(1023));
      now = now.add(const Duration(hours: 7));
      expect(await subject.check(), isA<UpdateCheckSkipped>());

      now = now.add(const Duration(hours: 17));
      expect(await subject.check(), isA<UpdateAvailable>());
    });

    test('a newer build prompts again', () async {
      final subject = updater();
      await subject.postpone(_release(1023));

      latestIs(_release(1024));
      now = now.add(const Duration(hours: 7));
      expect(await subject.check(), isA<UpdateAvailable>());
    });

    test('a forced check still shows the postponed build', () async {
      latestIs(_release(1023));
      final subject = updater();

      await subject.postpone(_release(1023));
      expect(await subject.check(force: true), isA<UpdateAvailable>());
    });
  });

  group('removeInstalledDownloads', () {
    test('removes the downloads up to the installed build', () async {
      when(() => service.removeDownloadsUpTo(any())).thenAnswer((_) async {});

      await updater(currentBuild: 1023).removeInstalledDownloads();

      verify(() => service.removeDownloadsUpTo(1023)).called(1);
    });

    test('also in builds that do not look for updates', () async {
      when(() => service.removeDownloadsUpTo(any())).thenAnswer((_) async {});

      await updater(repo: '').removeInstalledDownloads();

      verify(() => service.removeDownloadsUpTo(1020)).called(1);
    });

    test('a failure is ignored', () async {
      when(
        () => service.removeDownloadsUpTo(any()),
      ).thenThrow(const FileSystemException('busy'));

      await updater().removeInstalledDownloads();
    });
  });

  group('install', () {
    test('installs the downloaded file from the app cache', () async {
      final file = File('${Directory.systemTemp.path}/updates/onset-1023.apk');
      when(
        () => service.download(
          any(),
          onProgress: any(named: 'onProgress'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => file);

      await updater().downloadAndInstall(_release(1023));

      expect(calls.single.method, 'install');
      expect(calls.single.arguments, {'path': file.path});
    });

    test('tells when the system installer takes over', () async {
      final order = <String>[];
      when(
        () => service.download(
          any(),
          onProgress: any(named: 'onProgress'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async {
        order.add('download');
        return File('/tmp/updates/onset-1023.apk');
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(OnsetInstaller.channel, (call) async {
            order.add(call.method);
            return null;
          });

      await updater().downloadAndInstall(
        _release(1023),
        onInstall: () => order.add('onInstall'),
      );

      expect(order, ['download', 'onInstall', 'install']);
    });

    test('a dismissed installer reads as cancelled', () async {
      when(
        () => service.download(
          any(),
          onProgress: any(named: 'onProgress'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => File('/tmp/updates/onset-1023.apk'));
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            OnsetInstaller.channel,
            (call) async => throw PlatformException(code: 'install_aborted'),
          );

      await expectLater(
        updater().downloadAndInstall(_release(1023)),
        throwsA(isA<UpdateCancelledException>()),
      );
    });

    test('a refused install is an install error', () async {
      when(
        () => service.download(
          any(),
          onProgress: any(named: 'onProgress'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => File('/tmp/updates/onset-1023.apk'));
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            OnsetInstaller.channel,
            (call) async => throw PlatformException(code: 'outside_updates'),
          );

      await expectLater(
        updater().downloadAndInstall(_release(1023)),
        throwsA(isA<UpdateInstallException>()),
      );
    });

    test('download errors reach the caller and nothing is installed', () async {
      when(
        () => service.download(
          any(),
          onProgress: any(named: 'onProgress'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenThrow(const UpdateIntegrityException());

      await expectLater(
        updater().downloadAndInstall(
          _release(1023),
          cancelToken: CancelToken(),
        ),
        throwsA(isA<UpdateIntegrityException>()),
      );
      expect(calls, isEmpty);
    });

    test('reports whether installs are allowed', () async {
      expect(await updater().canInstall(), isTrue);
      canInstall = false;
      expect(await updater().canInstall(), isFalse);
      expect(calls.map((c) => c.method), ['canInstall', 'canInstall']);
    });

    test('opens the system page that allows installs', () async {
      await updater().openInstallSettings();

      expect(calls.single.method, 'openInstallSettings');
    });

    test('a build without the native side cannot install', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(OnsetInstaller.channel, null);

      expect(await const OnsetInstaller().canInstall(), isFalse);
    });
  });
}
