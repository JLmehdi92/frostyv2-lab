import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/go_live_setting.dart';
import 'package:onset/screens/settings/widgets/mention_notification_setting.dart';
import 'package:onset/screens/settings/widgets/settings_list_switch.dart';

class FakePlatform extends GoLivePlatform {
  FakePlatform({this.granted = true, this.isAllowed = true});

  final bool granted;
  final bool isAllowed;
  var asked = 0;

  @override
  Future<bool> requestPermission() async {
    asked++;
    return granted;
  }

  @override
  Future<bool> allowed() async => isAllowed;
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    SettingsStore store, {
    required GoLivePlatform platform,
    bool loggedIn = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MentionNotificationSetting(
            settingsStore: store,
            loggedIn: loggedIn,
            platform: platform,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool switchValue(WidgetTester tester) =>
      tester.widget<SettingsListSwitch>(find.byType(SettingsListSwitch)).value;

  testWidgets('on by default, says when it notifies', (tester) async {
    final store = SettingsStore.fromJson({});
    await pump(tester, store, platform: FakePlatform());
    expect(find.text('Chat mention notifications'), findsOneWidget);
    expect(switchValue(tester), isTrue);
    expect(find.textContaining('in the background'), findsOneWidget);
  });

  testWidgets('turning it off and on again asks for the right', (tester) async {
    final store = SettingsStore.fromJson({});
    final platform = FakePlatform();
    await pump(tester, store, platform: platform);
    await tester.tap(find.byType(SettingsListSwitch));
    await tester.pumpAndSettle();
    expect(store.mentionNotifications, isFalse);
    expect(platform.asked, 0);

    await tester.tap(find.byType(SettingsListSwitch));
    await tester.pumpAndSettle();
    expect(store.mentionNotifications, isTrue);
    expect(platform.asked, 1);
  });

  testWidgets('a refused right says where to allow it', (tester) async {
    final store = SettingsStore.fromJson({})..mentionNotifications = false;
    await pump(tester, store, platform: FakePlatform(granted: false));
    await tester.tap(find.byType(SettingsListSwitch));
    await tester.pumpAndSettle();
    expect(store.mentionNotifications, isFalse);
    expect(find.textContaining('system settings'), findsOneWidget);
  });

  testWidgets('blocked notifications are said, with a way to allow them', (
    tester,
  ) async {
    final store = SettingsStore.fromJson({});
    final platform = FakePlatform(isAllowed: false);
    await pump(tester, store, platform: platform);
    expect(find.textContaining('blocked'), findsOneWidget);
    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();
    expect(platform.asked, 1);
  });

  testWidgets('logged out: off, with why', (tester) async {
    final store = SettingsStore.fromJson({});
    await pump(tester, store, platform: FakePlatform(), loggedIn: false);
    expect(switchValue(tester), isFalse);
    expect(find.textContaining('Log in'), findsOneWidget);
    expect(
      tester
          .widget<SettingsListSwitch>(find.byType(SettingsListSwitch))
          .onChanged,
      isNull,
    );
  });
}
