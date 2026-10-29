import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/models/onset_release.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/release_notes.dart';
import 'package:onset/services/onset_updater.dart';
import 'package:onset/theme.dart';
import 'package:onset/widgets/onset_update_prompt.dart';
import 'package:provider/provider.dart';

class _MockUpdater extends Mock implements OnsetUpdater {}

const _mb = 1024 * 1024;

const _release = OnsetRelease(
  build: 72,
  tag: 'build-72',
  notes: '- Chat waits as long as the video is behind live.',
  apkAssetId: 1,
  shaAssetId: 2,
  apkSize: 38 * _mb,
);

void main() {
  late _MockUpdater updater;

  setUpAll(() => registerFallbackValue(_release));

  setUp(() {
    updater = _MockUpdater();
    when(() => updater.postpone(any())).thenAnswer((_) async {});
  });

  Future<void> pumpOffer(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final themes = OnsetThemes(colorSchemeSeed: OnsetTokens.accent);
    await tester.pumpWidget(
      MaterialApp(
        theme: themes.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => offerUpdate(
                context,
                updater,
                const UpdateAvailable(_release, 68),
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

  for (final size in const [Size(390, 844), Size(1280, 854)]) {
    testWidgets('${size.width.toInt()} wide: the build, what is installed, '
        'the notes, Update and Later', (tester) async {
      await pumpOffer(tester, size);

      expect(find.text('NEW BUILD'), findsOneWidget);
      expect(find.text('Update available'), findsOneWidget);
      expect(find.text('ONSET build 72 is ready.'), findsOneWidget);
      expect(
        find.text(
          'Installed: build 68 · 38.0 MB · SHA-256 checked before install',
        ),
        findsOneWidget,
      );
      expect(find.text(_release.notes), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      verify(() => updater.postpone(_release)).called(1);
      expect(find.text('Update available'), findsNothing);
    });
  }

  testWidgets('on a phone, back answers "Later" too', (tester) async {
    await pumpOffer(tester, const Size(390, 844));
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    verify(() => updater.postpone(_release)).called(1);
    expect(find.text('Update available'), findsNothing);
  });

  testWidgets('the release notes page: versions, dates, points', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    ReleaseNotes.debugSource = () async => '''
## v5.0.5

January 9, 2026

### Bug Fixes

- Fixed lag.
- [iOS] Fixed user agent breaking login.
''';
    addTearDown(() => ReleaseNotes.debugSource = null);
    await tester.pumpWidget(
      Provider<SettingsStore>.value(
        value: SettingsStore.fromJson({}),
        child: const MaterialApp(home: ReleaseNotes()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Release notes'), findsOneWidget);
    expect(find.text("WHAT'S NEW"), findsOneWidget);
    expect(find.text('v5.0.5'), findsOneWidget);
    expect(find.text('January 9, 2026'), findsOneWidget);
    expect(find.text('BUG FIXES'), findsWidgets);
    expect(find.text('iOS'), findsWidgets);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the release notes page when the notes cannot be read', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    ReleaseNotes.debugSource = () async => throw FlutterError('no asset');
    addTearDown(() => ReleaseNotes.debugSource = null);
    await tester.pumpWidget(
      Provider<SettingsStore>.value(
        value: SettingsStore.fromJson({}),
        child: const MaterialApp(home: ReleaseNotes()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Release notes'), findsOneWidget);
    expect(find.text("WHAT'S NEW"), findsOneWidget);
  });

  testWidgets('the release notes page with no entries yet', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Provider<SettingsStore>.value(
        value: SettingsStore.fromJson({}),
        child: const MaterialApp(home: ReleaseNotes()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Release notes'), findsOneWidget);
    expect(find.text("WHAT'S NEW"), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
