import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onset/apis/twitch_clip_service.dart';
import 'package:onset/models/clip.dart';
import 'package:onset/screens/channel/video/quality_selection.dart';
import 'package:onset/screens/clips/stores/channel_clips_store.dart';
import 'package:onset/screens/home/stream_list/stream_card_parts.dart';
import 'package:onset/screens/settings/general_settings.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:onset/screens/settings/video_settings.dart';
import 'package:provider/provider.dart';

import '../../helpers/l10n.dart';
import 'settings_harness.dart';

class MockClipService extends Mock implements TwitchClipService {}

Clip _clip(String id, {bool featured = false}) => Clip(
  id: id,
  slug: 'Slug$id',
  title: id,
  viewCount: 1,
  createdAt: DateTime.utc(2026),
  durationSeconds: 30,
  broadcasterId: '1',
  broadcasterLogin: 'b',
  broadcasterDisplayName: 'B',
  isFeatured: featured,
);

void main() {
  setUpAll(() {
    registerFallbackValue(ClipPeriod.lastWeek);
    registerFallbackValue(ClipSort.top);
  });

  test('the new settings default, survive a restart and reset', () {
    final settings = SettingsStore();
    expect(settings.clipDiscovery, ClipDiscovery.all);
    expect(settings.streamPreviews, isTrue);
    expect(settings.mutePreviews, isTrue);
    expect(settings.alertsOverLandscapeVideo, isTrue);
    settings
      ..clipDiscovery = ClipDiscovery.featured
      ..dataSaver = true
      ..hideViewerCount = true
      ..streamPreviews = false
      ..mutePreviews = false
      ..alertsOverLandscapeVideo = false;
    final restored = SettingsStore.fromJson(settings.toJson());
    expect(restored.clipDiscovery, ClipDiscovery.featured);
    expect(restored.dataSaver, isTrue);
    expect(restored.hideViewerCount, isTrue);
    expect(restored.streamPreviews, isFalse);
    expect(restored.mutePreviews, isFalse);
    expect(restored.alertsOverLandscapeVideo, isFalse);
    restored
      ..resetGeneralSettings()
      ..resetVideoSettings();
    expect(restored.clipDiscovery, ClipDiscovery.all);
    expect(restored.hideViewerCount, isFalse);
    expect(restored.dataSaver, isFalse);
    expect(restored.streamPreviews, isTrue);
  });

  test('landscape alerts off makes celebrations subtle in landscape only', () {
    final settings = SettingsStore()..alertsOverLandscapeVideo = false;
    expect(settings.celebrationsSubtle(landscape: true), isTrue);
    expect(settings.celebrationsSubtle(landscape: false), isFalse);
    settings.celebrationsOnVideo = CelebrationsOnVideo.subtle;
    expect(settings.celebrationsSubtle(landscape: false), isTrue);
  });

  test('data saver picks the best quality at 480p or less', () {
    expect(
      dataSaverQuality(['1080p60', '720p60', '480p30', '360p30', 'audio_only']),
      '480p30',
    );
    expect(dataSaverQuality(['1080p60', '720p60']), isNull);
    expect(dataSaverQuality(['audio_only']), isNull);
  });

  test('featured only keeps the featured clips of a channel', () async {
    final service = MockClipService();
    when(
      () => service.getChannelClips(
        login: any(named: 'login'),
        period: any(named: 'period'),
        sort: any(named: 'sort'),
      ),
    ).thenAnswer(
      (_) async => ClipPage(
        items: [_clip('1'), _clip('2', featured: true)],
        hasMore: false,
      ),
    );
    var featured = true;
    final store = ChannelClipsStore(
      login: 'b',
      clipService: service,
      featuredOnly: () => featured,
    );
    await store.load();
    expect(store.clips.map((c) => c.id), ['2']);
    featured = false;
    await store.refresh();
    expect(store.clips.map((c) => c.id), ['1', '2']);
  });

  test('featured only shows every clip when Twitch could not say', () async {
    final service = MockClipService();
    when(
      () => service.getChannelClips(
        login: any(named: 'login'),
        period: any(named: 'period'),
        sort: any(named: 'sort'),
      ),
    ).thenAnswer(
      (_) async => ClipPage(
        items: [_clip('1'), _clip('2')],
        hasMore: false,
        featuredKnown: false,
      ),
    );
    final store = ChannelClipsStore(
      login: 'b',
      clipService: service,
      featuredOnly: () => true,
    );
    await store.load();
    expect(store.clips.map((c) => c.id), ['1', '2']);
  });

  testWidgets('a hidden viewer count hides the viewer pill', (tester) async {
    final settings = SettingsStore();
    Widget pill() => Provider<SettingsStore>.value(
      value: settings,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: ViewerPill(
            key: ValueKey(settings.hideViewerCount),
            viewers: 1234,
          ),
        ),
      ),
    );
    await pumpLocalized(tester, locale: en, pill());
    expect(find.byType(Row), findsWidgets);
    settings.hideViewerCount = true;
    await pumpLocalized(tester, locale: en, pill());
    expect(
      find.descendant(of: find.byType(ViewerPill), matching: find.byType(Row)),
      findsNothing,
    );
  });

  testWidgets('the new switches write their settings', (tester) async {
    final settings = SettingsStore();
    await pumpSettings(
      tester,
      Scaffold(body: GeneralSettings(settingsStore: settings)),
      settings: settings,
      auth: FakeAuthStore(),
    );
    await tapVisible(tester, find.text('Hide viewer counts'));
    expect(settings.hideViewerCount, isTrue);

    await pumpSettings(
      tester,
      Scaffold(body: VideoSettings(settingsStore: settings)),
      settings: settings,
      auth: FakeAuthStore(),
    );
    await tapVisible(tester, find.text('Data saver'));
    expect(settings.dataSaver, isTrue);
    await tapVisible(tester, find.text('Start previews muted'));
    expect(settings.mutePreviews, isFalse);
    await tapVisible(tester, find.text('Stream previews'));
    expect(settings.streamPreviews, isFalse);
    expect(find.text('Start previews muted'), findsNothing);
  });
}
