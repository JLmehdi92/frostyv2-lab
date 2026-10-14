import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frosty/screens/settings/widgets/go_live_setting.dart';
import 'package:frosty/services/go_live/go_live.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakePlatform extends GoLivePlatform {
  FakePlatform({this.granted = true, this.supported = true});

  final bool granted;
  @override
  final bool supported;
  final calls = <String>[];

  @override
  Future<bool> requestPermission() async {
    calls.add('permission');
    return granted;
  }

  @override
  Future<void> start() async => calls.add('start');

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
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value;

  testWidgets('turning it on asks for the right, then starts', (tester) async {
    final platform = FakePlatform();
    await pump(tester, GoLiveSetting(userId: '7', platform: platform));
    expect(switchValue(tester), isFalse);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(platform.calls, ['permission', 'start']);
    expect(switchValue(tester), isTrue);
    final prefs = await GoLivePrefs.load();
    expect(prefs.enabled, isTrue);
    expect(prefs.userId, '7');

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(platform.calls.last, 'stop');
    expect((await GoLivePrefs.load()).enabled, isFalse);
  });

  testWidgets('a refused right says where to allow it', (tester) async {
    final platform = FakePlatform(granted: false);
    await pump(tester, GoLiveSetting(userId: '7', platform: platform));

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(platform.calls, ['permission']);
    expect(switchValue(tester), isFalse);
    expect(find.textContaining('system settings'), findsOneWidget);
  });

  testWidgets('logged out or not Android: cannot be turned on', (tester) async {
    await pump(tester, GoLiveSetting(userId: null, platform: FakePlatform()));
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
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
    expect(find.byType(SwitchListTile), findsNothing);

    final prefs = await GoLivePrefs.load();
    await prefs.setEnabled(true);
    await pump(tester, const SizedBox());
    await pump(tester, const GoLiveBellTile(channelId: '42', name: 'Streamer'));
    expect(switchValue(tester), isTrue);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(switchValue(tester), isFalse);
    expect((await GoLivePrefs.load()).muted, {'42'});
  });
}
