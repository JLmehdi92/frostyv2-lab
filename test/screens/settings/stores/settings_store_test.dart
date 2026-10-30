import 'package:flutter_test/flutter_test.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';

void main() {
  group('SettingsStore JSON serialization', () {
    test('settings saved before ONSET keep the new defaults', () {
      // An older save knows neither key; it must not switch either off.
      final store = SettingsStore.fromJson({
        'showVideo': true,
        'chatWidth': 0.3,
      });

      expect(store.showCelebrations, isTrue);
      expect(store.collapseGiftBombs, isTrue);
    });

    test('celebrations and gift bomb collapsing round-trip', () {
      final store = SettingsStore.fromJson({})
        ..showCelebrations = false
        ..collapseGiftBombs = false;

      final restored = SettingsStore.fromJson(store.toJson());

      expect(restored.showCelebrations, isFalse);
      expect(restored.collapseGiftBombs, isFalse);
    });

    test('live catch-up and buffer profile defaults', () {
      final store = SettingsStore.fromJson({});

      expect(store.liveCatchUpMode, LiveCatchUpMode.speedUp);
      expect(store.bufferProfile, BufferProfile.ultra);
      expect(store.autoLatency, isTrue);
    });

    test('a buffer profile saved before Ultra became the default is kept', () {
      // Every launch saves the whole store, so a saved value is the one the
      // viewer had (picked, or the Standard default they kept): only an
      // install that never saved one gets Ultra.
      final standard = SettingsStore.fromJson({'bufferProfile': 'standard'});
      final ultra = SettingsStore.fromJson({'bufferProfile': 'ultra'});

      expect(standard.bufferProfile, BufferProfile.standard);
      expect(ultra.bufferProfile, BufferProfile.ultra);
      expect(
        SettingsStore.fromJson(standard.toJson()).bufferProfile,
        BufferProfile.standard,
      );
    });

    test('crash logs and analytics are off until the viewer opts in', () {
      expect(SettingsStore().shareCrashLogsAndAnalytics, isFalse);
      expect(SettingsStore.fromJson({}).shareCrashLogsAndAnalytics, isFalse);
    });

    test('a saved crash logs and analytics choice is kept', () {
      // Every launch saves the whole store, so an install that already ran
      // has the value it saved (picked, or the old default it kept): only an
      // install that never saved one, and a reset, get the new default.
      final shared = SettingsStore.fromJson({
        'shareCrashLogsAndAnalytics': true,
      });
      final notShared = SettingsStore.fromJson({
        'shareCrashLogsAndAnalytics': false,
      });

      expect(shared.shareCrashLogsAndAnalytics, isTrue);
      expect(notShared.shareCrashLogsAndAnalytics, isFalse);
      expect(
        SettingsStore.fromJson(shared.toJson()).shareCrashLogsAndAnalytics,
        isTrue,
      );
    });

    test('auto latency is on for settings saved before it existed', () {
      final store = SettingsStore.fromJson({
        'bufferProfile': 'standard',
        'liveCatchUpMode': 'speedUp',
      });

      expect(store.autoLatency, isTrue);
    });

    test('auto latency round-trips through JSON', () {
      final store = SettingsStore.fromJson({})..autoLatency = false;

      expect(SettingsStore.fromJson(store.toJson()).autoLatency, isFalse);
    });

    test('live catch-up and buffer profile round-trip through JSON', () {
      final store = SettingsStore.fromJson({})
        ..liveCatchUpMode = LiveCatchUpMode.jumpToLive
        ..bufferProfile = BufferProfile.standard;

      final restored = SettingsStore.fromJson(store.toJson());

      expect(restored.liveCatchUpMode, LiveCatchUpMode.jumpToLive);
      expect(restored.bufferProfile, BufferProfile.standard);
    });

    test('unknown catch-up and buffer values fall back to the safe ones', () {
      final store = SettingsStore.fromJson({
        'liveCatchUpMode': 'warp',
        'bufferProfile': 'ludicrous',
      });

      expect(store.liveCatchUpMode, LiveCatchUpMode.speedUp);
      expect(store.bufferProfile, BufferProfile.standard);
    });

    test('resetVideoSettings restores catch-up and buffer defaults', () {
      final store = SettingsStore.fromJson({})
        ..liveCatchUpMode = LiveCatchUpMode.jumpToLive
        ..bufferProfile = BufferProfile.standard
        ..autoLatency = false
        ..resetVideoSettings();

      expect(store.liveCatchUpMode, LiveCatchUpMode.speedUp);
      expect(store.bufferProfile, BufferProfile.ultra);
      expect(store.autoLatency, isTrue);
    });

    test('catch-up and buffer names match their enums', () {
      expect(liveCatchUpModeNames, ['Speed up', 'Jump to live']);
      expect(bufferProfileNames, ['Standard', 'Ultra']);
    });

    test('keeps a saved showLatency value over the new default', () {
      final store = SettingsStore.fromJson({'showLatency': false});

      expect(store.showLatency, isFalse);
    });

    test('fromJson with empty map returns all defaults', () {
      final store = SettingsStore.fromJson({});

      expect(store.themeType, ThemeType.system);
      // ONSET's lime accent.
      expect(store.accentColor, 0xffc8ff3d);
      expect(store.showThumbnails, isTrue);
      expect(store.largeStreamCard, isFalse);
      expect(store.launchUrlExternal, isFalse);
      expect(store.showVideo, isTrue);
      expect(store.defaultToHighestQuality, isFalse);
      expect(store.useTextureRendering, isTrue);
      expect(store.showOverlay, isTrue);
      expect(store.toggleableOverlay, isFalse);
      expect(store.showLatency, isTrue);
      expect(store.badgeScale, 1.0);
      expect(store.emoteScale, 1.0);
      expect(store.messageScale, 1.0);
      expect(store.messageSpacing, 8.0);
      expect(store.fontSize, 12.0);
      expect(store.showDeletedMessages, isTrue);
      expect(store.showChatMessageDividers, isFalse);
      expect(store.timestampType, TimestampType.disabled);
      expect(store.autoSyncChatDelay, isTrue);
      expect(store.chatDelay, 0.0);
      expect(store.syncedChatDelay, 0.0);
      expect(store.effectiveChatDelay, 0.0);
      expect(store.highlightFirstTimeChatter, isTrue);
      expect(store.showUserNotices, isTrue);
      expect(store.emoteMenuButtonOnLeft, isFalse);
      expect(store.landscapeChatLeftSide, isFalse);
      expect(store.landscapeForceVerticalChat, isFalse);
      expect(store.landscapeCutout, LandscapeCutoutType.none);
      expect(store.chatWidth, 0.2);
      expect(store.fullScreenChatOverlayOpacity, 0.5);
      expect(store.autocomplete, isTrue);
      expect(store.showTwitchEmotes, isTrue);
      expect(store.showTwitchBadges, isTrue);
      expect(store.show7TVEmotes, isTrue);
      expect(store.showBTTVEmotes, isTrue);
      expect(store.showBTTVBadges, isTrue);
      expect(store.showFFZEmotes, isTrue);
      expect(store.showFFZBadges, isTrue);
      expect(store.showRecentMessages, isFalse);
      expect(store.persistChatTabs, isTrue);
      expect(store.secondaryTabs, isEmpty);
      expect(store.mutedWords, isEmpty);
      expect(store.matchWholeWord, isTrue);
      expect(store.shareCrashLogsAndAnalytics, isFalse);
      expect(store.fullScreen, isFalse);
      expect(store.fullScreenChatOverlay, isFalse);
      expect(store.pinnedChannelIds, isEmpty);
    });

    test('roundtrip serialization preserves non-default values', () {
      final store = SettingsStore.fromJson({});

      // Set non-default values
      store.themeType = ThemeType.dark;
      store.accentColor = 0xFF00FF00;
      store.showThumbnails = false;
      store.fontSize = 16.0;
      store.chatDelay = 5.0;
      store.syncedChatDelay = 8.0;
      store.showVideo = false;
      store.timestampType = TimestampType.twelve;
      store.landscapeCutout = LandscapeCutoutType.both;
      store.mutedWords = ['spam', 'bad'];
      store.pinnedChannelIds = ['ch1', 'ch2'];

      final json = store.toJson();
      final restored = SettingsStore.fromJson(json);

      expect(restored.themeType, ThemeType.dark);
      expect(restored.accentColor, 0xFF00FF00);
      expect(restored.showThumbnails, isFalse);
      expect(restored.fontSize, 16.0);
      expect(restored.chatDelay, 5.0);
      expect(restored.syncedChatDelay, 0.0);
      expect(json.containsKey('syncedChatDelay'), isFalse);
      expect(restored.showVideo, isFalse);
      expect(restored.timestampType, TimestampType.twelve);
      expect(restored.landscapeCutout, LandscapeCutoutType.both);
      expect(restored.mutedWords, ['spam', 'bad']);
      expect(restored.pinnedChannelIds, ['ch1', 'ch2']);
    });

    test('unknown ThemeType enum value falls back to system', () {
      final store = SettingsStore.fromJson({'themeType': 'nonexistent_theme'});
      expect(store.themeType, ThemeType.system);
    });

    test('unknown TimestampType enum value falls back to disabled', () {
      final store = SettingsStore.fromJson({
        'timestampType': 'nonexistent_timestamp',
      });
      expect(store.timestampType, TimestampType.disabled);
    });
  });

  group('mentionNotifications', () {
    test('is on by default, also for settings saved before it existed', () {
      expect(SettingsStore.fromJson({}).mentionNotifications, isTrue);
      expect(
        SettingsStore.fromJson({'showVideo': true}).mentionNotifications,
        isTrue,
      );
    });

    test('round-trips through JSON', () {
      final store = SettingsStore.fromJson({})..mentionNotifications = false;
      expect(
        SettingsStore.fromJson(store.toJson()).mentionNotifications,
        isFalse,
      );
    });

    test('resetGeneralSettings turns it back on', () {
      final store = SettingsStore.fromJson({})
        ..mentionNotifications = false
        ..resetGeneralSettings();
      expect(store.mentionNotifications, isTrue);
    });
  });

  group('showHypeTrain', () {
    test('is on by default, also for settings saved before it existed', () {
      expect(SettingsStore.fromJson({}).showHypeTrain, isTrue);
      expect(
        SettingsStore.fromJson({'showUserNotices': false}).showHypeTrain,
        isTrue,
      );
    });

    test('round-trips through JSON', () {
      final store = SettingsStore.fromJson({})..showHypeTrain = false;

      expect(SettingsStore.fromJson(store.toJson()).showHypeTrain, isFalse);
    });

    test('resetChatSettings turns it back on', () {
      final store = SettingsStore.fromJson({})
        ..showHypeTrain = false
        ..resetChatSettings();

      expect(store.showHypeTrain, isTrue);
    });
  });

  group('showCommunityHighlights', () {
    test('is on by default, also for settings saved before it existed', () {
      expect(SettingsStore.fromJson({}).showCommunityHighlights, isTrue);
      expect(
        SettingsStore.fromJson({
          'showHypeTrain': false,
        }).showCommunityHighlights,
        isTrue,
      );
    });

    test('round-trips through JSON', () {
      final store = SettingsStore.fromJson({})..showCommunityHighlights = false;

      expect(
        SettingsStore.fromJson(store.toJson()).showCommunityHighlights,
        isFalse,
      );
    });

    test('resetChatSettings turns it back on', () {
      final store = SettingsStore.fromJson({})
        ..showCommunityHighlights = false
        ..resetChatSettings();

      expect(store.showCommunityHighlights, isTrue);
    });
  });

  group('collapseGiftBombs', () {
    test('is on for a new install (no settings saved yet)', () {
      expect(SettingsStore.fromJson({}).collapseGiftBombs, isTrue);
    });

    test('a value an install already saved is kept, off included', () {
      // Every launch saves the whole store, so an existing install has the
      // key: the new default never overrides it.
      expect(
        SettingsStore.fromJson({'collapseGiftBombs': false}).collapseGiftBombs,
        isFalse,
      );
      expect(
        SettingsStore.fromJson({'collapseGiftBombs': true}).collapseGiftBombs,
        isTrue,
      );
      expect(
        SettingsStore.fromJson(
          (SettingsStore.fromJson({})..collapseGiftBombs = false).toJson(),
        ).collapseGiftBombs,
        isFalse,
      );
    });

    test('resetChatSettings turns it back to the default', () {
      final store = SettingsStore.fromJson({})
        ..collapseGiftBombs = false
        ..resetChatSettings();

      expect(store.collapseGiftBombs, isTrue);
    });
  });

  group('showDeletedMessages', () {
    test('is on by default', () {
      expect(SettingsStore.fromJson({}).showDeletedMessages, isTrue);
    });

    test('ignores the false saved under the old key', () {
      // Older installs saved the old default, false, without anyone choosing it.
      expect(
        SettingsStore.fromJson({
          'showDeletedMessages': false,
        }).showDeletedMessages,
        isTrue,
      );
    });

    test('keeps a false chosen under the new key', () {
      final store = SettingsStore.fromJson({})..showDeletedMessages = false;

      expect(store.toJson()['revealDeletedMessages'], isFalse);
      expect(store.toJson().containsKey('showDeletedMessages'), isFalse);
      expect(
        SettingsStore.fromJson(store.toJson()).showDeletedMessages,
        isFalse,
      );
    });

    test('resetChatSettings turns it back on', () {
      final store = SettingsStore.fromJson({})
        ..showDeletedMessages = false
        ..resetChatSettings();

      expect(store.showDeletedMessages, isTrue);
    });
  });

  group('showModerationNotices', () {
    test('is on by default, also for older settings', () {
      expect(SettingsStore.fromJson({}).showModerationNotices, isTrue);
    });

    test('resetChatSettings turns it back on', () {
      final store = SettingsStore.fromJson({})
        ..showModerationNotices = false
        ..resetChatSettings();
      expect(store.showModerationNotices, isTrue);
    });

    test('clip and video previews are on unless turned off', () {
      expect(SettingsStore.fromJson({}).showLinkPreviews, isTrue);
      final store = SettingsStore.fromJson({'showLinkPreviews': false});
      expect(store.showLinkPreviews, isFalse);
      store.resetChatSettings();
      expect(store.showLinkPreviews, isTrue);
    });

    test('emotes animate unless turned off', () {
      expect(SettingsStore.fromJson({}).animateEmotes, isTrue);
      final store = SettingsStore.fromJson({'animateEmotes': false});
      expect(store.animateEmotes, isFalse);
      store.resetChatSettings();
      expect(store.animateEmotes, isTrue);
    });

    test('GIFs show and animate unless turned off', () {
      final fresh = SettingsStore.fromJson({});
      expect(fresh.showGifs, isTrue);
      expect(fresh.animateGifs, isTrue);

      final store = SettingsStore.fromJson({
        'showGifs': false,
        'animateGifs': false,
      });
      expect(store.showGifs, isFalse);
      expect(store.animateGifs, isFalse);
      expect(store.toJson()['showGifs'], isFalse);
      expect(store.toJson()['animateGifs'], isFalse);

      store.resetChatSettings();
      expect(store.showGifs, isTrue);
      expect(store.animateGifs, isTrue);
    });
  });

  group('warnMatureContent', () {
    test('on by default, kept, and reset with the video settings', () {
      expect(SettingsStore.fromJson({}).warnMatureContent, isTrue);
      final store = SettingsStore.fromJson({'warnMatureContent': false});
      expect(store.warnMatureContent, isFalse);
      store.resetVideoSettings();
      expect(store.warnMatureContent, isTrue);
    });
  });

  group('hiddenContentLabels', () {
    test('none by default, kept, and reset with the general settings', () {
      expect(SettingsStore.fromJson({}).hiddenContentLabels, isEmpty);
      final store = SettingsStore.fromJson({
        'hiddenContentLabels': ['Gambling'],
      });
      expect(store.hiddenContentLabels, ['Gambling']);
      expect(store.toJson()['hiddenContentLabels'], ['Gambling']);
      store.resetGeneralSettings();
      expect(store.hiddenContentLabels, isEmpty);
    });
  });

  group('backgroundAudio', () {
    test('off by default, kept, and reset with the video settings', () {
      expect(SettingsStore.fromJson({}).backgroundAudio, isFalse);
      final store = SettingsStore.fromJson({'backgroundAudio': true});
      expect(store.backgroundAudio, isTrue);
      expect(store.toJson()['backgroundAudio'], isTrue);
      store.resetVideoSettings();
      expect(store.backgroundAudio, isFalse);
    });
  });

  group('showCaptions', () {
    test('off by default, kept, and reset with the video settings', () {
      expect(SettingsStore.fromJson({}).showCaptions, isFalse);
      final store = SettingsStore.fromJson({'showCaptions': true});
      expect(store.showCaptions, isTrue);
      store.resetVideoSettings();
      expect(store.showCaptions, isFalse);
    });
  });

  group('streamLanguage', () {
    test('is every language by default, also for older settings', () {
      expect(SettingsStore.fromJson({}).streamLanguage, '');
    });

    test('round-trips through JSON', () {
      final store = SettingsStore.fromJson({})..streamLanguage = 'fr';
      expect(SettingsStore.fromJson(store.toJson()).streamLanguage, 'fr');
    });

    test('resetGeneralSettings goes back to every language', () {
      final store = SettingsStore.fromJson({})
        ..streamLanguage = 'de'
        ..resetGeneralSettings();
      expect(store.streamLanguage, '');
    });
  });

  group('SettingsStore reset actions', () {
    test('resetGeneralSettings restores general defaults', () {
      final store = SettingsStore.fromJson({});

      store.themeType = ThemeType.dark;
      store.accentColor = 0xFF00FF00;
      store.showThumbnails = false;
      store.largeStreamCard = true;
      store.launchUrlExternal = true;

      store.resetGeneralSettings();

      expect(store.themeType, ThemeType.system);
      // ONSET's lime accent.
      expect(store.accentColor, 0xffc8ff3d);
      expect(store.showThumbnails, isTrue);
      expect(store.largeStreamCard, isFalse);
      expect(store.launchUrlExternal, isFalse);
    });

    test('resetVideoSettings restores video defaults', () {
      final store = SettingsStore.fromJson({});

      store.showVideo = false;
      store.defaultToHighestQuality = true;
      store.useTextureRendering = false;
      store.showOverlay = false;
      store.toggleableOverlay = true;
      store.showLatency = false;

      store.resetVideoSettings();

      expect(store.showVideo, isTrue);
      expect(store.defaultToHighestQuality, isFalse);
      expect(store.useTextureRendering, isTrue);
      expect(store.showOverlay, isTrue);
      expect(store.toggleableOverlay, isFalse);
      expect(store.showLatency, isTrue);
    });

    test('resetChatSettings restores chat defaults', () {
      final store = SettingsStore.fromJson({});

      store.badgeScale = 2.0;
      store.emoteScale = 2.0;
      store.fontSize = 20.0;
      store.showDeletedMessages = false;
      store.timestampType = TimestampType.twentyFour;
      store.chatDelay = 10.0;
      store.syncedChatDelay = 7.0;
      store.emoteMenuButtonOnLeft = true;
      store.landscapeCutout = LandscapeCutoutType.right;
      store.chatWidth = 0.5;
      store.mutedWords = ['word1'];
      store.showBTTVEmotes = false;
      store.showFFZBadges = false;

      store.resetChatSettings();

      expect(store.badgeScale, 1.0);
      expect(store.emoteScale, 1.0);
      expect(store.fontSize, 12.0);
      expect(store.showDeletedMessages, isTrue);
      expect(store.timestampType, TimestampType.disabled);
      expect(store.chatDelay, 0.0);
      expect(store.syncedChatDelay, 0.0);
      expect(store.emoteMenuButtonOnLeft, isFalse);
      expect(store.landscapeCutout, LandscapeCutoutType.none);
      expect(store.chatWidth, 0.2);
      expect(store.mutedWords, isEmpty);
      expect(store.showBTTVEmotes, isTrue);
      expect(store.showFFZBadges, isTrue);
    });

    test('resetOtherSettings restores other defaults', () {
      final store = SettingsStore.fromJson({});

      store.shareCrashLogsAndAnalytics = true;

      store.resetOtherSettings();

      expect(store.shareCrashLogsAndAnalytics, isFalse);
    });

    test('resetGlobalConfigs restores global config defaults', () {
      final store = SettingsStore.fromJson({});

      store.fullScreen = true;
      store.fullScreenChatOverlay = true;
      store.pinnedChannelIds = ['ch1'];

      store.resetGlobalConfigs();

      expect(store.fullScreen, isFalse);
      expect(store.fullScreenChatOverlay, isFalse);
      expect(store.pinnedChannelIds, isEmpty);
    });

    test('resetAllSettings restores everything to defaults', () {
      final store = SettingsStore.fromJson({});

      // Modify settings across all categories
      store.themeType = ThemeType.light;
      store.showVideo = false;
      store.fontSize = 20.0;
      store.shareCrashLogsAndAnalytics = true;
      store.fullScreen = true;

      store.resetAllSettings();

      expect(store.themeType, ThemeType.system);
      expect(store.showVideo, isTrue);
      expect(store.fontSize, 12.0);
      expect(store.shareCrashLogsAndAnalytics, isFalse);
      expect(store.fullScreen, isFalse);
    });

    test('resetGeneralSettings does not affect video settings', () {
      final store = SettingsStore.fromJson({});

      store.showVideo = false;
      store.themeType = ThemeType.dark;

      store.resetGeneralSettings();

      expect(store.themeType, ThemeType.system);
      expect(store.showVideo, isFalse); // Should remain changed
    });

    test('resetVideoSettings does not affect chat settings', () {
      final store = SettingsStore.fromJson({});

      store.fontSize = 20.0;
      store.showLatency = false;

      store.resetVideoSettings();

      expect(store.showLatency, isTrue);
      expect(store.fontSize, 20.0); // Should remain changed
    });

    group('chat sync default', () {
      test('a new install syncs chat with the stream latency', () {
        final store = SettingsStore.fromJson({});

        expect(store.autoSyncChatDelay, isTrue);
        expect(store.toJson()['chatSyncDefaultApplied'], isTrue);
      });

      test('turns sync on once for settings that never chose a delay', () {
        final store = SettingsStore.fromJson({
          'autoSyncChatDelay': false,
          'chatDelay': 0.0,
        });

        expect(store.autoSyncChatDelay, isTrue);
        expect(store.toJson()['chatSyncDefaultApplied'], isTrue);
      });

      test('keeps a manual delay the viewer chose', () {
        final store = SettingsStore.fromJson({
          'autoSyncChatDelay': false,
          'chatDelay': 5.0,
        });

        expect(store.autoSyncChatDelay, isFalse);
        expect(store.effectiveChatDelay, 5.0);
      });

      test('sync turned off after the change stays off', () {
        final store = SettingsStore.fromJson({
          'autoSyncChatDelay': false,
          'chatDelay': 0.0,
          'chatSyncDefaultApplied': true,
        });

        expect(store.autoSyncChatDelay, isFalse);
      });
    });

    test('effectiveChatDelay uses synced value only during auto sync', () {
      final store = SettingsStore.fromJson({})..autoSyncChatDelay = false;

      store.chatDelay = 4.0;
      store.syncedChatDelay = 9.0;

      expect(store.effectiveChatDelay, 4.0);

      store.autoSyncChatDelay = true;

      expect(store.effectiveChatDelay, 9.0);
    });
  });

  group('Enums', () {
    test('ThemeType has expected values', () {
      expect(ThemeType.values.length, 3);
      expect(ThemeType.values, contains(ThemeType.system));
      expect(ThemeType.values, contains(ThemeType.light));
      expect(ThemeType.values, contains(ThemeType.dark));
    });

    test('TimestampType has expected values', () {
      expect(TimestampType.values.length, 3);
      expect(TimestampType.values, contains(TimestampType.disabled));
      expect(TimestampType.values, contains(TimestampType.twelve));
      expect(TimestampType.values, contains(TimestampType.twentyFour));
    });

    test('LandscapeCutoutType has expected values', () {
      expect(LandscapeCutoutType.values.length, 4);
      expect(LandscapeCutoutType.values, contains(LandscapeCutoutType.none));
      expect(LandscapeCutoutType.values, contains(LandscapeCutoutType.left));
      expect(LandscapeCutoutType.values, contains(LandscapeCutoutType.right));
      expect(LandscapeCutoutType.values, contains(LandscapeCutoutType.both));
    });

    test('themeNames matches ThemeType order', () {
      expect(themeNames.length, ThemeType.values.length);
      expect(themeNames[0], 'System');
      expect(themeNames[1], 'Light');
      expect(themeNames[2], 'Dark');
    });

    test('timestampNames matches TimestampType order', () {
      expect(timestampNames.length, TimestampType.values.length);
      expect(timestampNames[0], 'Disabled');
      expect(timestampNames[1], '12-hour');
      expect(timestampNames[2], '24-hour');
    });
  });
}
