import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/onset_update_service.dart';
import 'package:onset/models/onset_release.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';
import 'package:onset/services/onset_updater.dart';
import 'package:onset/widgets/onset_update_prompt.dart';
import 'package:provider/provider.dart';

class _MockUpdater extends Mock implements OnsetUpdater {}

class _Screen extends StatefulWidget {
  const _Screen();

  @override
  State<_Screen> createState() => _ScreenState();
}

class _ScreenState extends State<_Screen> with OnsetUpdateChecks {
  @override
  Widget build(BuildContext context) => const Text('home');
}

const _mb = 1024 * 1024;

const _release = OnsetRelease(
  build: 2023,
  tag: 'build-2023',
  notes: 'Faster chat\nFix PiP',
  apkAssetId: 1,
  shaAssetId: 2,
  apkSize: 10 * _mb,
);

void main() {
  late _MockUpdater updater;
  late Completer<void> resumed;

  setUpAll(() => registerFallbackValue(_release));

  setUp(() {
    updater = _MockUpdater();
    when(() => updater.enabled).thenReturn(true);
    when(() => updater.canInstall()).thenAnswer((_) async => true);
    when(() => updater.postpone(any())).thenAnswer((_) async {});
    when(() => updater.openInstallSettings()).thenAnswer((_) async {});
    when(() => updater.removeInstalledDownloads()).thenAnswer((_) async {});
  });

  void downloadDoes(
    Future<void> Function(
      void Function(int, int)? onProgress,
      CancelToken? cancelToken,
      void Function()? onInstall,
    )
    body,
  ) {
    when(
      () => updater.downloadAndInstall(
        any(),
        onProgress: any(named: 'onProgress'),
        cancelToken: any(named: 'cancelToken'),
        onInstall: any(named: 'onInstall'),
      ),
    ).thenAnswer(
      (invocation) => body(
        invocation.namedArguments[#onProgress] as void Function(int, int)?,
        invocation.namedArguments[#cancelToken] as CancelToken?,
        invocation.namedArguments[#onInstall] as void Function()?,
      ),
    );
  }

  Future<void> pumpOffer(WidgetTester tester) async {
    // Made inside the test: a future from setUp completes outside fake async.
    resumed = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => offerUpdate(
                context,
                updater,
                const UpdateAvailable(_release, 2020),
                waitForResume: () => resumed.future,
              ),
              child: const Text('offer'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('offer'));
    await tester.pumpAndSettle();
  }

  testWidgets('the popup names the build and its notes', (tester) async {
    await pumpOffer(tester);

    expect(find.text('Update available'), findsOneWidget);
    expect(find.text('ONSET build 2023 is ready.'), findsOneWidget);
    expect(find.text('Faster chat\nFix PiP'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
    expect(find.text('Update'), findsOneWidget);
  });

  testWidgets('"Later" postpones the build', (tester) async {
    await pumpOffer(tester);

    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();

    verify(() => updater.postpone(_release)).called(1);
    expect(find.text('Update available'), findsNothing);
  });

  testWidgets('"Update" shows the progress, then installs', (tester) async {
    final finish = Completer<void>();
    downloadDoes((onProgress, _, _) {
      onProgress!(5 * _mb, 10 * _mb);
      return finish.future;
    });
    await pumpOffer(tester);

    await tester.tap(find.text('Update'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Downloading update…'), findsOneWidget);
    expect(find.text('5.0 / 10.0 MB'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 0.5);
    expect(find.text('Cancel'), findsOneWidget);

    finish.complete();
    await tester.pumpAndSettle();
    expect(find.text('Downloading update…'), findsNothing);
    verifyNever(() => updater.postpone(any()));
  });

  testWidgets('waits on the system installer once downloaded', (tester) async {
    final finish = Completer<void>();
    downloadDoes((onProgress, _, onInstall) {
      onProgress!(10 * _mb, 10 * _mb);
      onInstall!();
      return finish.future;
    });
    await pumpOffer(tester);

    await tester.tap(find.text('Update'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Installing update…'), findsOneWidget);
    expect(find.text('Downloading update…'), findsNothing);
    final cancel = tester.widget<SettingsButton>(
      find.ancestor(
        of: find.text('Cancel'),
        matching: find.byType(SettingsButton),
      ),
    );
    expect(cancel.onPressed, isNull);

    finish.complete();
    await tester.pumpAndSettle();
    expect(find.text('Installing update…'), findsNothing);
  });

  testWidgets('"Cancel" stops the download quietly', (tester) async {
    downloadDoes((_, cancelToken, _) async {
      await cancelToken!.whenCancel;
      throw const UpdateCancelledException();
    });
    await pumpOffer(tester);
    await tester.tap(find.text('Update'));
    await tester.pump();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Downloading update…'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  for (final (error, message) in [
    (
      const UpdateIntegrityException(),
      'The download was corrupted. Try again.',
    ),
    (const UpdateDownloadException(), 'Couldn’t download the update.'),
    (const UpdateInstallException(), 'Android couldn’t install the update.'),
  ]) {
    testWidgets('${error.runtimeType} says "$message"', (tester) async {
      downloadDoes((_, _, _) async => throw error);
      await pumpOffer(tester);

      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();

      expect(find.text('Downloading update…'), findsNothing);
      expect(find.text(message), findsOneWidget);
    });
  }

  testWidgets('an unexpected error closes the progress too', (tester) async {
    downloadDoes((_, _, _) async => throw StateError('boom'));
    await pumpOffer(tester);

    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();

    expect(find.text('Downloading update…'), findsNothing);
    expect(find.text('Couldn’t download the update.'), findsOneWidget);
  });

  group('without the install permission', () {
    setUp(() {
      var allowed = false;
      when(() => updater.canInstall()).thenAnswer((_) async => allowed);
      when(() => updater.openInstallSettings()).thenAnswer((_) async {
        allowed = true;
      });
      downloadDoes((_, _, _) async {});
    });

    testWidgets('explains, opens the settings, then goes on', (tester) async {
      await pumpOffer(tester);
      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();

      expect(find.text('Allow updates'), findsOneWidget);
      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      verify(() => updater.openInstallSettings()).called(1);
      verifyNever(
        () => updater.downloadAndInstall(
          any(),
          onProgress: any(named: 'onProgress'),
          cancelToken: any(named: 'cancelToken'),
          onInstall: any(named: 'onInstall'),
        ),
      );

      resumed.complete();
      await tester.pumpAndSettle();
      verify(
        () => updater.downloadAndInstall(
          any(),
          onProgress: any(named: 'onProgress'),
          cancelToken: any(named: 'cancelToken'),
          onInstall: any(named: 'onInstall'),
        ),
      ).called(1);
    });

    testWidgets('still refused when back: says so', (tester) async {
      when(() => updater.openInstallSettings()).thenAnswer((_) async {});
      await pumpOffer(tester);
      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();

      resumed.complete();
      await tester.pumpAndSettle();

      expect(
        find.text('ONSET isn’t allowed to install updates.'),
        findsOneWidget,
      );
    });
  });

  group('OnsetUpdateChecks', () {
    Future<void> pumpWatcher(WidgetTester tester, {OnsetUpdater? provided}) =>
        tester.pumpWidget(
          MaterialApp(
            home: provided == null
                ? const _Screen()
                : Provider<OnsetUpdater>.value(
                    value: provided,
                    child: const _Screen(),
                  ),
          ),
        );

    testWidgets('checks after the first frame and offers the update', (
      tester,
    ) async {
      when(
        () => updater.check(),
      ).thenAnswer((_) async => const UpdateAvailable(_release, 2020));

      await pumpWatcher(tester, provided: updater);
      await tester.pumpAndSettle();

      verify(() => updater.check()).called(1);
      verify(() => updater.removeInstalledDownloads()).called(1);
      expect(find.text('Update available'), findsOneWidget);
    });

    testWidgets('checks again when the app comes back', (tester) async {
      when(() => updater.check()).thenAnswer((_) async => const UpToDate());
      await pumpWatcher(tester, provided: updater);
      await tester.pumpAndSettle();

      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();

      verify(() => updater.check()).called(2);
      expect(find.text('Update available'), findsNothing);
    });

    testWidgets('a check that throws does not stop the next one', (
      tester,
    ) async {
      when(() => updater.check()).thenThrow(StateError('prefs'));
      await pumpWatcher(tester, provided: updater);
      await tester.pumpAndSettle();

      when(
        () => updater.check(),
      ).thenAnswer((_) async => const UpdateAvailable(_release, 2020));
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Update available'), findsOneWidget);
    });

    testWidgets('does nothing when updates are off or missing', (tester) async {
      when(() => updater.enabled).thenReturn(false);
      await pumpWatcher(tester, provided: updater);
      await tester.pumpAndSettle();
      verifyNever(() => updater.check(force: any(named: 'force')));
      // Leftover APKs go even in builds that no longer look for updates.
      verify(() => updater.removeInstalledDownloads()).called(1);

      await pumpWatcher(tester);
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });
  });
}
