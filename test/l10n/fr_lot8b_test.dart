import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/giphy_service.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/models/chat_ui_settings.dart';
import 'package:onset/models/gif_picker.dart';
import 'package:onset/models/playback_access_token.dart';
import 'package:onset/screens/channel/chat/emote_menu/gif_picker_panel.dart';
import 'package:onset/screens/channel/video/free_preview.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/widgets/chat_account_sync.dart';
import 'package:onset/screens/settings/widgets/settings_page.dart';

import '../fixtures/gif_payloads.dart';
import '../helpers/l10n.dart';

class _MockGiphy extends Mock implements GiphyService {}

const _config = GifPickerConfig(
  enabled: true,
  allowlisted: true,
  apiKey: 'abcDEF123456',
  rating: 'pg',
);

ChatUiSettings _account() => const ChatUiSettings({
  ChatUiSetting.emoteAnimations: false,
  ChatUiSetting.gifs: true,
  ChatUiSetting.gifAnimations: false,
  ChatUiSetting.readableColors: true,
});

Widget _player(Widget child) => Scaffold(
  backgroundColor: Colors.black,
  body: Center(
    child: AspectRatio(aspectRatio: 16 / 9, child: child),
  ),
);

const lot8bScreenNames = [
  'free preview banner',
  'free preview tier 2',
  'free preview ended',
  'chat account sync',
  'chat account sync unavailable',
  'gif picker empty',
  'gif picker subscribers',
];

FreePreviewController _preview(String name) {
  final now = DateTime(2026, 11, 9, 12);
  final controller = FreePreviewController(
    endsAt: DateTime(2026, 11, 9, 12, 2, 31),
    clock: () => now,
  );
  if (name.contains('tier 2')) controller.tier = SubscriberTier.tier2;
  if (name.contains('ended')) controller.expire();
  return controller;
}

(Widget, VoidCallback) lot8bScreen(String name) {
  if (name.startsWith('free preview')) {
    final controller = _preview(name);
    return (
      _player(
        FreePreviewLayer(
          controller: controller,
          name: 'Streamer',
          login: 'streamer',
          onUseWebPlayer: () {},
        ),
      ),
      controller.dispose,
    );
  }
  final screen = _otherScreens()[name]!;
  return (screen, () {});
}

Map<String, Widget> _otherScreens() {
  final giphy = _MockGiphy();
  when(
    () => giphy.search(
      config: _config,
      query: any(named: 'query'),
    ),
  ).thenAnswer((_) async => const []);
  return {
    'chat account sync': Scaffold(
      body: SettingsGroupsView(
        children: [
          ChatAccountSyncGroup(
            settingsStore: SettingsStore.fromJson({}),
            load: () async => _account(),
            save: (_, _) async => ViewerActionOutcome.done,
          ),
        ],
      ),
    ),
    'chat account sync unavailable': Scaffold(
      body: SettingsGroupsView(
        children: [
          ChatAccountSyncGroup(
            settingsStore: SettingsStore.fromJson({}),
            load: () async => null,
            save: (_, _) async => ViewerActionOutcome.done,
          ),
        ],
      ),
    ),
    'gif picker empty': Scaffold(
      body: SizedBox(
        height: 360,
        child: GifPickerPanel(
          channelLogin: 'streamer',
          channelName: 'Streamer',
          loadConfig: () async => _config,
          giphy: giphy,
          send: (_, _) async => const GifSendResult(GifSendStatus.sent),
          onSent: () {},
        ),
      ),
    ),
    'gif picker subscribers': Scaffold(
      body: SizedBox(
        height: 360,
        child: GifPickerPanel(
          channelLogin: 'streamer',
          channelName: 'Streamer',
          loadConfig: () async => const GifPickerConfig(
            enabled: true,
            allowlisted: false,
            apiKey: 'abcDEF123456',
            rating: 'pg',
          ),
          giphy: giphy,
          send: (_, _) async => const GifSendResult(GifSendStatus.sent),
          onSent: () {},
        ),
      ),
    ),
  };
}

void main() {
  setUpAll(() => registerFallbackValue(_config));

  for (final (sizeName, size) in frenchScreenSizes) {
    for (final scale in frenchTextScales) {
      final at = '$sizeName, text ×$scale';
      for (final name in lot8bScreenNames) {
        testWidgets('$name, $at', (tester) async {
          final (screen, dispose) = lot8bScreen(name);
          await pumpLocalized(tester, screen, size: size, textScale: scale);
          await tester.pump();
          await tester.pump();
          await expectFrenchThroughout(
            tester,
            '$name, $at',
            content: const ['Streamer', 'GIPHY'],
          );
          dispose();
        });
      }
    }
  }

  testWidgets('the GIF send dialog and cooldown are French', (tester) async {
    final giphy = _MockGiphy();
    when(
      () => giphy.search(
        config: _config,
        query: any(named: 'query'),
      ),
    ).thenAnswer((_) async => [GiphyGif.fromJson(giphyGif('a1'))!]);
    await pumpLocalized(
      tester,
      Scaffold(
        body: SizedBox(
          height: 360,
          child: GifPickerPanel(
            channelLogin: 'streamer',
            channelName: 'Streamer',
            loadConfig: () async => _config,
            giphy: giphy,
            send: (_, _) async => const GifSendResult(
              GifSendStatus.cooldown,
              secondsUntilCanSend: 5,
            ),
            onSent: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(GifPickerPanel.tileKey('a1')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await expectFrenchThroughout(tester, 'gif send dialog');
    await tester.tap(find.byKey(GifPickerPanel.sendKey));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.text('Vous pourrez envoyer un autre GIF dans 5 secondes.'),
      findsOneWidget,
    );
  });
}
