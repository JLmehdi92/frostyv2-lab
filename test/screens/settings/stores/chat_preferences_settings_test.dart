import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';

SettingsStore _restored(SettingsStore store) => SettingsStore.fromJson(
  jsonDecode(jsonEncode(store.toJson())) as Map<String, dynamic>,
);

void main() {
  group('name colors', () {
    test('readable by default, at 4.5:1', () {
      final store = SettingsStore.fromJson({});
      expect(store.readableNameColors, isTrue);
      expect(store.increaseChatContrast, isFalse);
      expect(store.nameColorContrast, readableNameColorContrast);
    });

    test('off keeps every name color as sent', () {
      final store = SettingsStore.fromJson({})..readableNameColors = false;
      expect(store.nameColorContrast, isNull);
      expect(_restored(store).nameColorContrast, isNull);
    });

    test('increased contrast asks for 7:1, readable or not', () {
      final store = SettingsStore.fromJson({})..increaseChatContrast = true;
      expect(store.nameColorContrast, highNameColorContrast);
      store.readableNameColors = false;
      expect(store.nameColorContrast, highNameColorContrast);
      expect(_restored(store).nameColorContrast, highNameColorContrast);
    });

    test('a chat reset brings both back', () {
      final store = SettingsStore.fromJson({})
        ..readableNameColors = false
        ..increaseChatContrast = true
        ..resetChatSettings();
      expect(store.nameColorContrast, readableNameColorContrast);
    });
  });

  group('landscape chat modes', () {
    test('all three by default, in cycle order', () {
      expect(SettingsStore.fromJson({}).switchableLandscapeChatModes, [
        LandscapeChatMode.overlay,
        LandscapeChatMode.column,
        LandscapeChatMode.hidden,
      ]);
    });

    test('one can go, the last two stay', () {
      final store = SettingsStore.fromJson({})
        ..setLandscapeChatMode(LandscapeChatMode.hidden, on: false);
      expect(store.switchableLandscapeChatModes, [
        LandscapeChatMode.overlay,
        LandscapeChatMode.column,
      ]);
      store.setLandscapeChatMode(LandscapeChatMode.column, on: false);
      expect(store.switchableLandscapeChatModes, [
        LandscapeChatMode.overlay,
        LandscapeChatMode.column,
      ]);
      expect(_restored(store).switchableLandscapeChatModes, [
        LandscapeChatMode.overlay,
        LandscapeChatMode.column,
      ]);
      store.setLandscapeChatMode(LandscapeChatMode.hidden, on: true);
      expect(store.switchableLandscapeChatModes, hasLength(3));
    });

    test('an unknown or too short saved list reads as all three', () {
      expect(
        SettingsStore.fromJson({
          'landscapeChatModes': ['overlay', 'pip'],
        }).switchableLandscapeChatModes,
        hasLength(3),
      );
      expect(
        SettingsStore.fromJson({
          'landscapeChatModes': ['hidden', 'bogus', 'overlay'],
        }).switchableLandscapeChatModes,
        [LandscapeChatMode.overlay, LandscapeChatMode.hidden],
      );
    });
  });

  group('portrait chat height', () {
    test('low for a new install', () {
      expect(
        SettingsStore.fromJson({}).portraitChatHeight,
        PortraitChatHeight.low,
      );
    });

    test('a size dragged before the presets is kept as custom', () {
      expect(
        SettingsStore.fromJson({'portraitVideoScale': 0.6}).portraitChatHeight,
        PortraitChatHeight.custom,
      );
      expect(
        SettingsStore.fromJson({'portraitVideoScale': 1.0}).portraitChatHeight,
        PortraitChatHeight.low,
      );
    });

    test('a preset survives a restart and a video reset', () {
      final store = SettingsStore.fromJson({})
        ..portraitChatHeight = PortraitChatHeight.high;
      expect(_restored(store).portraitChatHeight, PortraitChatHeight.high);
      store.resetVideoSettings();
      expect(store.portraitChatHeight, PortraitChatHeight.low);
    });
  });

  test('tap to close the chat overlay is off by default and saved', () {
    final store = SettingsStore.fromJson({});
    expect(store.tapToCloseOverlayChat, isFalse);
    store.tapToCloseOverlayChat = true;
    expect(_restored(store).tapToCloseOverlayChat, isTrue);
    store.resetChatSettings();
    expect(store.tapToCloseOverlayChat, isFalse);
  });
}
