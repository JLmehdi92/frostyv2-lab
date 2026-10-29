import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/settings/widgets/go_live_setting.dart';
import 'package:onset/screens/settings/widgets/settings_list_switch.dart';
import 'package:onset/services/go_live/go_live.dart';
import 'package:onset/widgets/sheet/onset_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakePlatform extends GoLivePlatform {
  FakePlatform({
    this.granted = true,
    this.supported = true,
    this.isAllowed = true,
    this.startFails = false,
  });

  final bool granted;
  final bool isAllowed;
  final bool startFails;
  @override
  final bool supported;
  final calls = <String>[];

  @override
  Future<bool> requestPermission() async {
    calls.add('permission');
    return granted;
  }

  @override
  Future<bool> allowed() async => isAllowed;

  @override
  Future<void> start() async {
    calls.add('start');
    if (startFails) throw StateError('no scheduler');
  }

  @override
  Future<void> stop() async => calls.add('stop');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
    await tester.pumpAndSettle();
  }

  bool switchValue(WidgetTester tester) =>
      tester.widget<SettingsListSwitch>(find.byType(SettingsListSwitch)).value;

  testWidgets('says how often channels are checked', (tester) async {
    final prefs = await GoLivePrefs.load();
    await prefs.setEnabled(true);
    await pump(tester, GoLiveSetting(userId: '7', platform: FakePlatform()));
    expect(
      find.textContaining('every 90 seconds while ONSET is open'),
      findsOneWidget,
    );
    expect(find.textContaining('about every 15 minutes'), findsOneWidget);
  });

  testWidgets('turning it on asks for the right, then starts', (tester) async {
    final platform = FakePlatform();
    await pump(tester, GoLiveSetting(userId: '7', platform: platform));
    expect(switchValue(tester), isFalse);

    await tester.tap(find.byType(SettingsListSwitch));
    await tester.pumpAndSettle();

    expect(platform.calls, ['permission', 'start']);
    expect(switchValue(tester), isTrue);
    final prefs = await GoLivePrefs.load();
    expect(prefs.enabled, isTrue);
    expect(prefs.userId, '7');

    await tester.tap(find.byType(SettingsListSwitch));
    await tester.pumpAndSettle();
    expect(platform.calls.last, 'stop');
    expect((await GoLivePrefs.load()).enabled, isFalse);
  });

  testWidgets('a refused right says where to allow it', (tester) async {
    final platform = FakePlatform(granted: false);
    await pump(tester, GoLiveSetting(userId: '7', platform: platform));

    await tester.tap(find.byType(SettingsListSwitch));
    await tester.pumpAndSettle();

    expect(platform.calls, ['permission']);
    expect(switchValue(tester), isFalse);
    expect(find.textContaining('system settings'), findsOneWidget);
  });

  testWidgets('a failed schedule leaves it off', (tester) async {
    final platform = FakePlatform(startFails: true);
    await pump(tester, GoLiveSetting(userId: '7', platform: platform));

    await tester.tap(find.byType(SettingsListSwitch));
    await tester.pumpAndSettle();

    expect(switchValue(tester), isFalse);
    expect(find.textContaining("Couldn't turn on"), findsOneWidget);
    expect((await GoLivePrefs.load()).enabled, isFalse);
  });

  testWidgets('blocked notices and a paused check are shown', (tester) async {
    final prefs = await GoLivePrefs.load();
    await prefs.setEnabled(true);
    await pump(
      tester,
      GoLiveSetting(userId: '7', platform: FakePlatform(isAllowed: false)),
    );
    expect(find.textContaining('blocked'), findsOneWidget);

    await prefs.setProblem(kGoLiveLoggedOut);
    await pump(tester, const SizedBox());
    await pump(tester, GoLiveSetting(userId: '7', platform: FakePlatform()));
    expect(find.text(kGoLiveLoggedOut), findsOneWidget);
  });

  testWidgets('logged out or not Android: cannot be turned on', (tester) async {
    await pump(tester, GoLiveSetting(userId: null, platform: FakePlatform()));
    expect(
      tester
          .widget<SettingsListSwitch>(find.byType(SettingsListSwitch))
          .onChanged,
      isNull,
    );
    expect(find.textContaining('Log in'), findsOneWidget);

    await pump(
      tester,
      GoLiveSetting(userId: '7', platform: FakePlatform(supported: false)),
    );
    expect(find.text('Android only.'), findsOneWidget);
  });

  testWidgets("a channel's bell shows only while notices are on", (
    tester,
  ) async {
    await pump(tester, const GoLiveBellTile(channelId: '42', name: 'Streamer'));
    expect(find.byType(OnsetSwitch), findsNothing);

    final prefs = await GoLivePrefs.load();
    await prefs.setEnabled(true);
    await pump(tester, const SizedBox());
    await pump(tester, const GoLiveBellTile(channelId: '42', name: 'Streamer'));
    bool bell() => tester.widget<OnsetSwitch>(find.byType(OnsetSwitch)).value;
    expect(find.text('Notify when Streamer goes live'), findsOneWidget);
    expect(bell(), isTrue);

    // The whole row toggles it (board ChaineCarteUtilisateur).
    await tester.tap(find.text('Notify when Streamer goes live'));
    await tester.pumpAndSettle();
    expect(bell(), isFalse);
    expect((await GoLivePrefs.load()).muted, {'42'});

    await tester.tap(find.byType(OnsetSwitch));
    await tester.pumpAndSettle();
    expect(bell(), isTrue);
    expect((await GoLivePrefs.load()).muted, isEmpty);
  });
}
