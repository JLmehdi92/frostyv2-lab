import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/channel_profile/channel_preferences_screen.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/settings_kit.dart';
import 'package:onset/services/go_live/go_live.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/l10n.dart';

void main() {
  late SettingsStore settings;

  setUp(() => settings = SettingsStore.fromJson({}));

  Future<GoLivePrefs> prefs({required bool enabled}) async {
    SharedPreferences.setMockInitialValues({'go_live_enabled': enabled});
    return GoLivePrefs.load();
  }

  Future<void> pump(
    WidgetTester tester, {
    bool loggedIn = true,
    bool goLive = true,
  }) async {
    final goLivePrefs = await tester.runAsync(() => prefs(enabled: goLive));
    await pumpLocalized(
      tester,
      Scaffold(
        body: ChannelPreferencesScreen(
          channelId: '42',
          name: 'xQc',
          settingsStore: settings,
          loggedIn: loggedIn,
          goLivePrefs: () async => goLivePrefs!,
        ),
      ),
      locale: en,
      size: const Size(400, 1200),
    );
    await tester.pump();
  }

  bool switchOn(WidgetTester tester, String key) => tester
      .widget<SettingsSwitch>(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(SettingsSwitch),
        ),
      )
      .value;

  testWidgets('the bell mutes and unmutes this channel only', (tester) async {
    await pump(tester);
    expect(find.text('Get a notification when xQc goes live.'), findsOneWidget);
    expect(switchOn(tester, 'channel-prefs-bell'), isTrue);

    await tester.tap(find.byKey(const ValueKey('channel-prefs-bell')));
    await tester.pump();
    final stored = await tester.runAsync(GoLivePrefs.load);
    expect(stored!.muted, {'42'});
    expect(switchOn(tester, 'channel-prefs-bell'), isFalse);
  });

  testWidgets('without live notifications the bell says how to get them', (
    tester,
  ) async {
    await pump(tester, goLive: false);
    expect(
      find.text('Turn on live notifications in Settings to use the bell.'),
      findsOneWidget,
    );
    await pump(tester, loggedIn: false);
    expect(find.text('Log in to get live notifications.'), findsOneWidget);
  });

  testWidgets('notices, pin and hide change this channel only', (tester) async {
    settings.pinnedChannelIds = ['7'];
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('channel-prefs-notices')));
    await tester.pump();
    expect(settings.noticesHiddenChannelIds, ['42']);
    expect(settings.showsNoticesIn('42'), isFalse);
    expect(settings.showsNoticesIn('7'), isTrue);

    await tester.tap(find.byKey(const ValueKey('channel-prefs-pin')));
    await tester.pump();
    expect(settings.pinnedChannelIds, ['7', '42']);

    await tester.tap(find.byKey(const ValueKey('channel-prefs-hide')));
    await tester.pump();
    expect(settings.hiddenChannelIds, ['42']);
    await tester.tap(find.byKey(const ValueKey('channel-prefs-hide')));
    await tester.pump();
    expect(settings.hiddenChannelIds, isEmpty);

    settings.showUserNotices = false;
    await tester.pump();
    expect(
      find.text('Notices are turned off for every chat in Settings › Chat.'),
      findsOneWidget,
    );
  });
}
