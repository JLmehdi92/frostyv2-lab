import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/models/onset_release.dart';
import 'package:frosty/screens/settings/other_settings.dart';
import 'package:frosty/screens/settings/stores/settings_store.dart';
import 'package:frosty/screens/settings/widgets/update_check_tile.dart';
import 'package:frosty/services/onset_updater.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class _MockUpdater extends Mock implements OnsetUpdater {}

const _release = OnsetRelease(
  build: 1023,
  tag: 'build-1023',
  notes: '',
  apkAssetId: 1,
  shaAssetId: 2,
  apkSize: 10,
);

void main() {
  late _MockUpdater updater;

  setUp(() {
    updater = _MockUpdater();
    when(() => updater.enabled).thenReturn(true);
    when(() => updater.currentBuild()).thenAnswer((_) async => 1020);
  });

  Future<void> pumpSettings(WidgetTester tester, {OnsetUpdater? provided}) {
    final settings = OtherSettings(settingsStore: SettingsStore.fromJson({}));
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: provided == null
                ? settings
                : Provider<OnsetUpdater>.value(
                    value: provided,
                    child: settings,
                  ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows the installed build', (tester) async {
    await pumpSettings(tester, provided: updater);
    await tester.pumpAndSettle();

    expect(find.byType(UpdateCheckTile), findsOneWidget);
    expect(find.text('Check for updates'), findsOneWidget);
    expect(find.text('Build 1020'), findsOneWidget);
  });

  testWidgets('is hidden when updates are off', (tester) async {
    when(() => updater.enabled).thenReturn(false);
    await pumpSettings(tester, provided: updater);
    await tester.pumpAndSettle();

    expect(find.text('Check for updates'), findsNothing);
  });

  testWidgets('is hidden without an updater', (tester) async {
    await pumpSettings(tester);
    await tester.pumpAndSettle();

    expect(find.text('Check for updates'), findsNothing);
    expect(find.text('Reset settings'), findsOneWidget);
  });

  testWidgets('says when the build is the latest', (tester) async {
    when(
      () => updater.check(force: true),
    ).thenAnswer((_) async => const UpToDate());
    await pumpSettings(tester, provided: updater);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();

    verify(() => updater.check(force: true)).called(1);
    expect(find.text("You're up to date"), findsOneWidget);
  });

  testWidgets('says when GitHub cannot be read', (tester) async {
    when(
      () => updater.check(force: true),
    ).thenAnswer((_) async => const UpdateCheckFailed());
    await pumpSettings(tester, provided: updater);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't check for updates"), findsOneWidget);
  });

  testWidgets('a check that throws says so and can be retried', (tester) async {
    when(() => updater.check(force: true)).thenThrow(StateError('prefs'));
    await pumpSettings(tester, provided: updater);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't check for updates"), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final tile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('Check for updates'),
        matching: find.byType(ListTile),
      ),
    );
    expect(tile.onTap, isNotNull);
  });

  testWidgets('offers a newer build', (tester) async {
    when(
      () => updater.check(force: true),
    ).thenAnswer((_) async => const UpdateAvailable(_release, 1020));
    await pumpSettings(tester, provided: updater);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();

    expect(find.text('Update available'), findsOneWidget);
    expect(find.text('ONSET build 1023 is ready.'), findsOneWidget);
  });
}
