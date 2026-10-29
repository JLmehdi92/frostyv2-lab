# ONSET Low-Latency Native Player — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the app's high-latency Twitch WebView player with a native low-latency HLS player (`media_kit`), kept behind a settings toggle with the WebView as fallback, without removing any existing feature.

**Architecture:** A new `TwitchStreamService` fetches the raw HLS playlist (Twitch GQL token → usher.ttvnw.net) and a `NativeVideoStore` plays it via `media_kit` (libmpv) tuned for low latency. Both the existing `VideoStore` (WebView) and the new `NativeVideoStore` implement a shared `PlayerController` interface so the existing `VideoOverlay` and `channel.dart` drive either engine. A `PlayerEngine` setting selects the engine; default is native, WebView remains as a fallback.

**Tech Stack:** Flutter, Dart, MobX (codegen), `media_kit` + `media_kit_video`, `dio` (existing `BaseApiClient`), `http_mock_adapter` + `mocktail` for tests.

---

## Why this structure

- The existing `lib/screens/channel/video/video_store.dart` is ~1100 lines and tightly bound to the WebView. We do **not** rewrite it. We add a parallel store and abstract only the members the overlay/channel actually consume into `PlayerController`.
- The HLS token + playlist logic is pure/networked and **unit-testable** → TDD.
- The `media_kit` playback itself is **device-verified** (cannot be unit-tested headlessly on Windows). Those tasks have explicit manual verification steps instead of unit tests.

## File structure (created / modified)

| File | Responsibility |
|------|----------------|
| `lib/screens/channel/video/player_controller.dart` *(create)* | Abstract interface the overlay + channel depend on |
| `lib/apis/twitch_stream_service.dart` *(create)* | GQL `PlaybackAccessToken` + usher `.m3u8` URL + variant parsing |
| `lib/models/hls_variant.dart` *(create)* | Data model for a quality variant (name + url) |
| `lib/screens/channel/video/stores/native_video_store.dart` *(create)* | MobX store wrapping `media_kit` Player, implements `PlayerController` |
| `lib/screens/channel/video/native_video.dart` *(create)* | Widget rendering the `media_kit` `Video` |
| `lib/screens/channel/video/video_store.dart` *(modify)* | Add `implements PlayerController` (no behavior change) |
| `lib/screens/channel/video/video_overlay.dart` *(modify)* | Change field type `VideoStore` → `PlayerController` |
| `lib/screens/channel/channel.dart` *(modify)* | Pick store/widget by `settingsStore.playerEngine` |
| `lib/screens/settings/stores/settings_store.dart` *(modify)* | Add `playerEngine` setting |
| `lib/screens/settings/video_settings.dart` *(modify)* | Add engine picker UI |
| `lib/main.dart` *(modify)* | `MediaKit.ensureInitialized()` |
| `test/apis/twitch_stream_service_test.dart` *(create)* | Tests for token + parsing |
| `test/models/hls_variant_test.dart` *(create)* | Tests for playlist parsing |

---

## Phase 0 — Toolchain (do this on the Windows dev machine first)

No code. Goal: run the **unmodified** clone on a real Android device to prove the build chain and Twitch credentials work before changing anything.

- [ ] **Step 1: Install Flutter SDK (Windows)**

Download the Flutter SDK zip from https://docs.flutter.dev/get-started/install/windows, extract to `C:\src\flutter`, add `C:\src\flutter\bin` to PATH. Then:

Run: `flutter --version`
Expected: prints Flutter + Dart versions (no "command not found").

- [ ] **Step 2: Install Android toolchain**

Install Android Studio (includes Android SDK + platform-tools). Then accept licenses:

Run: `flutter doctor --android-licenses` (accept all), then `flutter doctor`
Expected: "Flutter" and "Android toolchain" show `[✓]`. Ignore the iOS/Xcode `[✗]` lines (Windows — expected).

- [ ] **Step 3: Connect a device**

Enable USB debugging on the Android phone (or start an emulator from Android Studio). Then:

Run: `flutter devices`
Expected: the phone/emulator is listed.

- [ ] **Step 4: Get Twitch dev credentials**

Create an app at https://dev.twitch.tv/console/apps (OAuth redirect `http://localhost`), copy the **Client ID** and generate a **Client Secret**.

- [ ] **Step 5: Install deps and run the unmodified app**

Run:
```bash
flutter pub get
flutter run --dart-define=clientId=YOUR_ID --dart-define=secret=YOUR_SECRET
```
Expected: the app launches on the device, you can open a live channel, and video plays (with the current high latency). **This is the baseline.** Note the latency shown in the overlay for later A/B comparison.

- [ ] **Step 6: Commit the project baseline (branch first)**

Run:
```bash
git checkout -b low-latency-player
git add CLAUDE.md docs/
git commit -m "add claude.md and low-latency player design + plan"
```

---

## Phase 1 — Native player behind a toggle (WebView stays default)

### Task 1: Add media_kit dependencies

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/main.dart`

- [ ] **Step 1: Add packages**

Run:
```bash
flutter pub add media_kit media_kit_video media_kit_libs_video
```
Expected: `pubspec.yaml` gains the three packages; `flutter pub get` succeeds.

- [ ] **Step 2: Initialize MediaKit at startup**

In `lib/main.dart`, find the `main()` function (it already calls `WidgetsFlutterBinding.ensureInitialized()`). Add the import and the init call right after the binding init:

```dart
import 'package:media_kit/media_kit.dart';
```
```dart
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
```

- [ ] **Step 3: Verify it still builds**

Run: `flutter analyze`
Expected: no new errors.

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/main.dart
git commit -m "add media_kit dependencies and init"
```

---

### Task 2: HLS variant model + master-playlist parser (TDD)

**Files:**
- Create: `lib/models/hls_variant.dart`
- Test: `test/models/hls_variant_test.dart`

- [ ] **Step 1: Write the failing test**

`test/models/hls_variant_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/models/hls_variant.dart';

void main() {
  // A trimmed Twitch master playlist (two qualities).
  const masterPlaylist = '''
#EXTM3U
#EXT-X-MEDIA:TYPE=VIDEO,GROUP-ID="chunked",NAME="1080p60 (source)",AUTOSELECT=YES,DEFAULT=YES
#EXT-X-STREAM-INF:BANDWIDTH=6000000,RESOLUTION=1920x1080,VIDEO="chunked"
https://video-edge-1.ttvnw.net/chunked/index-live.m3u8
#EXT-X-MEDIA:TYPE=VIDEO,GROUP-ID="720p60",NAME="720p60",AUTOSELECT=YES,DEFAULT=NO
#EXT-X-STREAM-INF:BANDWIDTH=3000000,RESOLUTION=1280x720,VIDEO="720p60"
https://video-edge-1.ttvnw.net/720p60/index-live.m3u8
''';

  test('parses each quality name and its media url', () {
    final variants = HlsVariant.parseMasterPlaylist(masterPlaylist);

    expect(variants.length, 2);
    expect(variants[0].name, '1080p60 (source)');
    expect(variants[0].url, 'https://video-edge-1.ttvnw.net/chunked/index-live.m3u8');
    expect(variants[1].name, '720p60');
    expect(variants[1].url, 'https://video-edge-1.ttvnw.net/720p60/index-live.m3u8');
  });

  test('returns empty list for an empty or invalid playlist', () {
    expect(HlsVariant.parseMasterPlaylist(''), isEmpty);
    expect(HlsVariant.parseMasterPlaylist('not a playlist'), isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/hls_variant_test.dart`
Expected: FAIL — `HlsVariant` is undefined.

- [ ] **Step 3: Write minimal implementation**

`lib/models/hls_variant.dart`:
```dart
/// A single selectable quality from a Twitch HLS master playlist.
class HlsVariant {
  /// Human-readable name, e.g. '1080p60 (source)' or '720p60'.
  final String name;

  /// URL of this variant's media playlist.
  final String url;

  const HlsVariant({required this.name, required this.url});

  /// Parses a Twitch HLS master playlist into an ordered list of variants.
  ///
  /// Pairs each `#EXT-X-MEDIA:...,NAME="..."` with the URL line that follows
  /// its matching `#EXT-X-STREAM-INF`. Returns an empty list when the input is
  /// not a valid master playlist.
  static List<HlsVariant> parseMasterPlaylist(String playlist) {
    final lines = const LineSplitter()
        .convert(playlist)
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.isEmpty || lines.first != '#EXTM3U') return const [];

    final variants = <HlsVariant>[];
    String? pendingName;

    for (final line in lines) {
      if (line.startsWith('#EXT-X-MEDIA:')) {
        final match = RegExp(r'NAME="([^"]*)"').firstMatch(line);
        pendingName = match?.group(1);
      } else if (!line.startsWith('#') && pendingName != null) {
        variants.add(HlsVariant(name: pendingName, url: line));
        pendingName = null;
      }
    }

    return variants;
  }
}
```
Add the required import at the top of the file:
```dart
import 'dart:convert';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/models/hls_variant_test.dart`
Expected: PASS (both tests).

- [ ] **Step 5: Commit**

```bash
git add lib/models/hls_variant.dart test/models/hls_variant_test.dart
git commit -m "add hls variant model and master playlist parser"
```

---

### Task 3: TwitchStreamService — token + usher URL (TDD)

**Files:**
- Create: `lib/apis/twitch_stream_service.dart`
- Test: `test/apis/twitch_stream_service_test.dart`

Reference: it must extend `BaseApiClient` like the other services in `lib/apis/`. Inspect `lib/apis/base_api_client.dart` and `lib/apis/twitch_api.dart` for the exact constructor/`dio` access pattern before writing, and mirror it.

- [ ] **Step 1: Write the failing test**

`test/apis/twitch_stream_service_test.dart`:
```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onset/apis/twitch_stream_service.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late TwitchStreamService service;

  const login = 'somestreamer';

  setUp(() {
    dio = Dio(BaseOptions());
    adapter = DioAdapter(dio: dio);
    service = TwitchStreamService(dio: dio);
  });

  test('requests a playback access token then resolves usher variants', () async {
    adapter.onPost(
      'https://gql.twitch.tv/gql',
      (server) => server.reply(200, {
        'data': {
          'streamPlaybackAccessToken': {
            'value': '{"token":"abc"}',
            'signature': 'deadbeef',
          },
        },
      }),
    );

    adapter.onGet(
      'https://usher.ttvnw.net/api/channel/hls/$login.m3u8',
      (server) => server.reply(200, '''
#EXTM3U
#EXT-X-MEDIA:TYPE=VIDEO,GROUP-ID="chunked",NAME="1080p60 (source)",DEFAULT=YES
#EXT-X-STREAM-INF:BANDWIDTH=6000000,VIDEO="chunked"
https://video-edge-1.ttvnw.net/chunked/index-live.m3u8
'''),
      queryParameters: {
        'allow_source': 'true',
        'fast_bread': 'true',
        'low_latency': 'true',
        'p': anything,
        'sig': 'deadbeef',
        'token': '{"token":"abc"}',
        'player': 'twitchweb',
        'type': 'any',
      },
    );

    final variants = await service.getStreamVariants(userLogin: login);

    expect(variants, hasLength(1));
    expect(variants.first.name, '1080p60 (source)');
    expect(variants.first.url,
        'https://video-edge-1.ttvnw.net/chunked/index-live.m3u8');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/apis/twitch_stream_service_test.dart`
Expected: FAIL — `TwitchStreamService` is undefined.

- [ ] **Step 3: Write minimal implementation**

`lib/apis/twitch_stream_service.dart`:
```dart
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:onset/models/hls_variant.dart';

/// Fetches the raw Twitch HLS playlist for a channel so it can be played by a
/// native low-latency player instead of the Twitch web embed.
///
/// Flow: POST a `PlaybackAccessToken` to Twitch GQL using the public web
/// client-id, then GET the usher `.m3u8` master playlist with low-latency flags.
///
/// This bypasses the official embed and is used for personal builds only; the
/// caller is expected to fall back to the WebView engine if this throws.
class TwitchStreamService {
  final Dio _dio;

  /// Public web client-id used by twitch.tv itself (not a secret).
  static const _gqlClientId = 'kimne78kx3ncx6brgo4mv6wki5h1ko';

  TwitchStreamService({required Dio dio}) : _dio = dio;

  Future<List<HlsVariant>> getStreamVariants({required String userLogin}) async {
    final token = await _getAccessToken(userLogin);

    final response = await _dio.get<String>(
      'https://usher.ttvnw.net/api/channel/hls/$userLogin.m3u8',
      queryParameters: {
        'allow_source': 'true',
        'fast_bread': 'true', // enables Twitch low-latency segments
        'low_latency': 'true',
        'p': _randomP(),
        'sig': token.signature,
        'token': token.value,
        'player': 'twitchweb',
        'type': 'any',
      },
      options: Options(responseType: ResponseType.plain),
    );

    return HlsVariant.parseMasterPlaylist(response.data ?? '');
  }

  Future<_AccessToken> _getAccessToken(String login) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'https://gql.twitch.tv/gql',
      options: Options(headers: {'Client-ID': _gqlClientId}),
      data: {
        'operationName': 'PlaybackAccessToken',
        'extensions': {
          'persistedQuery': {
            'version': 1,
            'sha256Hash':
                '0828119ded1c13477966434e15800ff57ddacf13ba1911c129dc2200705b0712',
          },
        },
        'variables': {
          'isLive': true,
          'login': login,
          'isVod': false,
          'vodID': '',
          'playerType': 'embed',
        },
      },
    );

    final data = response.data?['data']?['streamPlaybackAccessToken']
        as Map<String, dynamic>?;
    if (data == null) {
      throw StateError('No playback access token for $login');
    }
    return _AccessToken(
      value: data['value'] as String,
      signature: data['signature'] as String,
    );
  }

  /// Twitch's usher endpoint expects a random integer in `p`.
  int _randomP() => DateTime.now().microsecondsSinceEpoch % 10000000;
}

class _AccessToken {
  final String value;
  final String signature;
  const _AccessToken({required this.value, required this.signature});
}
```

> NOTE for the implementer: the `sha256Hash` above is the long-lived hash Twitch's
> web client uses for `PlaybackAccessToken`. If the token POST returns 401/`PersistedQueryNotFound`
> during device testing, switch the `data` payload to send a raw `query` string
> instead of the persisted-query hash (see streamlink's Twitch plugin for the
> current GQL document). Keep the rest of the method identical.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/apis/twitch_stream_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Run full analysis**

Run: `flutter analyze`
Expected: clean.

- [ ] **Step 6: Commit**

```bash
git add lib/apis/twitch_stream_service.dart test/apis/twitch_stream_service_test.dart
git commit -m "add twitch stream service for raw hls playlist"
```

---

### Task 4: PlayerController interface

**Files:**
- Create: `lib/screens/channel/video/player_controller.dart`
- Modify: `lib/screens/channel/video/video_store.dart`

Determine the exact member set by reading every `videoStore.` usage in `video_overlay.dart` and every `_videoStore.` usage in `channel.dart`. The interface below covers the members those two files call. If reading reveals an additional member, add it to the interface and ensure both stores expose it.

- [ ] **Step 1: Create the interface**

`lib/screens/channel/video/player_controller.dart`:
```dart
import 'package:onset/models/channel.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';

/// The contract the video overlay and channel screen depend on, so they can
/// drive either the WebView engine ([VideoStore]) or the native engine
/// ([NativeVideoStore]) interchangeably.
abstract class PlayerController {
  SettingsStore get settingsStore;

  // Playback state
  bool get paused;
  bool get overlayVisible;
  bool get isInPipMode;

  // Stream info
  StreamTwitch? get streamInfo;
  Channel? get offlineChannelInfo;

  // Quality
  List<String> get availableStreamQualities;
  String get streamQuality;
  void setStreamQuality(String quality);
  Future<void> updateStreamQualities();

  // Latency (null when unknown)
  String? get latency;

  // Actions
  void handleVideoTap();
  void handleToggleOverlay();
  void handlePausePlay();
  Future<void> handleRefresh();
  void requestPictureInPicture();
  void togglePictureInPicture();
  void handleAppResume();
  void dispose();
}
```

- [ ] **Step 2: Make VideoStore implement it (no behavior change)**

In `lib/screens/channel/video/video_store.dart`, add the import and `implements PlayerController` on the public class typedef line:
```dart
import 'package:onset/screens/channel/video/player_controller.dart';
```
```dart
class VideoStore = VideoStoreBase with _$VideoStore implements PlayerController;
```

- [ ] **Step 3: Verify VideoStore already satisfies the interface**

Run: `flutter analyze`
Expected: clean. If the analyzer reports a missing member, that member is consumed by the overlay/channel but absent here — reconcile by adjusting the interface to match the real `VideoStore` API (the interface must reflect what `VideoStore` actually exposes).

- [ ] **Step 4: Commit**

```bash
git add lib/screens/channel/video/player_controller.dart lib/screens/channel/video/video_store.dart
git commit -m "extract player controller interface from video store"
```

---

### Task 5: Add the PlayerEngine setting

**Files:**
- Modify: `lib/screens/settings/stores/settings_store.dart`
- Then regenerate: `settings_store.g.dart`

Read the top of `settings_store.dart` first to copy the existing `default*` + `@observable` + reset-method pattern exactly (see `showLatency` / `useTextureRendering`).

- [ ] **Step 1: Add the enum and setting**

At the top of `lib/screens/settings/stores/settings_store.dart` (after imports, outside the class):
```dart
/// Which engine plays the live video.
enum PlayerEngine {
  /// Native low-latency HLS player (media_kit). Default.
  nativeLowLatency,

  /// Original Twitch web embed in a WebView. Fallback.
  twitchWeb,
}
```
Near the other `default*` constants, add:
```dart
static const defaultPlayerEngine = PlayerEngine.nativeLowLatency;
```
Near the other `@observable` fields (next to `useTextureRendering`), add:
```dart
  @observable
  PlayerEngine playerEngine = defaultPlayerEngine;
```
In the settings reset method (where `useTextureRendering = defaultUseTextureRendering;` etc. are listed), add:
```dart
    playerEngine = defaultPlayerEngine;
```

- [ ] **Step 2: Regenerate codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `settings_store.g.dart` updates with the new observable; JSON (de)serialization includes `playerEngine`. (The `@JsonSerializable` enum is serialized by name by default.)

- [ ] **Step 3: Verify**

Run: `flutter analyze`
Expected: clean.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/settings/stores/settings_store.dart lib/screens/settings/stores/settings_store.g.dart
git commit -m "add player engine setting (native low-latency default)"
```

---

### Task 6: NativeVideoStore (media_kit) — device-verified

**Files:**
- Create: `lib/screens/channel/video/stores/native_video_store.dart`

No unit test (playback can't run headlessly); verified on device in Task 8. It must implement `PlayerController`. Reuse `TwitchApi` for stream info exactly as `VideoStore._updateStreamInfoInternal` does (read that method and copy its API calls).

- [ ] **Step 1: Implement the store**

`lib/screens/channel/video/stores/native_video_store.dart`:
```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:onset/apis/twitch_api.dart';
import 'package:onset/apis/twitch_stream_service.dart';
import 'package:onset/models/channel.dart';
import 'package:onset/models/hls_variant.dart';
import 'package:onset/models/stream.dart';
import 'package:onset/screens/channel/video/player_controller.dart';
import 'package:onset/screens/settings/stores/auth_store.dart';
import 'package:onset/screens/settings/stores/settings_store.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mobx/mobx.dart';

part 'native_video_store.g.dart';

class NativeVideoStore = NativeVideoStoreBase with _$NativeVideoStore;

abstract class NativeVideoStoreBase with Store implements PlayerController {
  final String userLogin;
  final String userId;
  final TwitchApi twitchApi;
  @override
  final AuthStore authStore;
  @override
  final SettingsStore settingsStore;

  final TwitchStreamService _streamService;

  /// The media_kit player. `Player` exposes `platform` as `NativePlayer` for
  /// libmpv property tuning.
  final Player player = Player(
    configuration: const PlayerConfiguration(
      // Keep the demuxer buffer tiny so we stay near the live edge.
      bufferSize: 4 * 1024 * 1024,
    ),
  );

  late final VideoController videoController = VideoController(player);

  List<HlsVariant> _variants = [];

  @readonly
  List<String> _availableStreamQualities = [];

  @readonly
  int _streamQualityIndex = 0;

  @readonly
  var _paused = false;

  @readonly
  var _overlayVisible = true;

  @readonly
  StreamTwitch? _streamInfo;

  @readonly
  Channel? _offlineChannelInfo;

  @readonly
  String? _latency;

  Timer? _overlayTimer;

  @override
  bool get isInPipMode => false; // Native PiP handled by OS; no tracked state.

  @override
  String get streamQuality =>
      _availableStreamQualities.elementAtOrNull(_streamQualityIndex) ?? 'Auto';

  NativeVideoStoreBase({
    required this.userLogin,
    required this.userId,
    required this.twitchApi,
    required this.authStore,
    required this.settingsStore,
    TwitchStreamService? streamService,
  }) : _streamService = streamService ?? TwitchStreamService(dio: twitchApi.dio) {
    _configureLowLatency();
    player.stream.playing.listen((playing) => runInAction(() => _paused = !playing));
    _load();
    updateStreamInfo();
    _scheduleOverlayHide();
  }

  Future<void> _configureLowLatency() async {
    final native = player.platform;
    if (native is NativePlayer) {
      // libmpv low-latency live tuning (see media_kit + mpv docs).
      await native.setProperty('cache', 'no');
      await native.setProperty('cache-secs', '0');
      await native.setProperty('demuxer-lavf-o', 'live=1');
      await native.setProperty('demuxer-readahead-secs', '0');
      await native.setProperty('video-sync', 'display-resample');
      if (Platform.isAndroid) {
        await native.setProperty('hwdec', 'mediacodec-copy');
      }
    }
  }

  @action
  Future<void> _load() async {
    try {
      _variants = await _streamService.getStreamVariants(userLogin: userLogin);
      _availableStreamQualities = _variants.map((v) => v.name).toList();
      _streamQualityIndex = 0;
      if (_variants.isNotEmpty) {
        await player.open(Media(_variants.first.url));
        await player.play();
      }
    } catch (e) {
      debugPrint('NativeVideoStore load failed: $e');
      rethrow; // Caller (channel) may fall back to the WebView engine.
    }
  }

  @override
  @action
  void setStreamQuality(String quality) {
    final index = _availableStreamQualities.indexOf(quality);
    if (index == -1) return;
    _streamQualityIndex = index;
    player.open(Media(_variants[index].url));
    player.play();
  }

  @override
  Future<void> updateStreamQualities() async {
    // Variants are fetched once at load; nothing to refresh on demand.
  }

  @override
  void handlePausePlay() => player.playOrPause();

  @override
  @action
  Future<void> handleRefresh() async {
    _latency = null;
    await _load();
    await updateStreamInfo(forceUpdate: true);
  }

  @override
  @action
  void handleVideoTap() {
    _overlayTimer?.cancel();
    if (_overlayVisible) {
      _overlayVisible = false;
    } else {
      _overlayVisible = true;
      updateStreamInfo(forceUpdate: true);
      _scheduleOverlayHide();
    }
  }

  @override
  void handleToggleOverlay() {
    // Native engine always uses the custom overlay; nothing to toggle.
  }

  @override
  void handleAppResume() {
    if (!settingsStore.showVideo) updateStreamInfo(forceUpdate: true);
  }

  @override
  void requestPictureInPicture() {
    // OS-level PiP for the native surface is added in a later iteration.
  }

  @override
  void togglePictureInPicture() => requestPictureInPicture();

  void _scheduleOverlayHide([Duration delay = const Duration(seconds: 5)]) {
    _overlayTimer?.cancel();
    _overlayTimer = Timer(delay, () => runInAction(() => _overlayVisible = false));
  }

  @action
  Future<void> updateStreamInfo({bool forceUpdate = false}) async {
    try {
      _streamInfo = await twitchApi.getStream(userLogin: userLogin);
      _offlineChannelInfo = null;
    } catch (e) {
      _streamInfo = null;
      try {
        _offlineChannelInfo = await twitchApi.getChannel(userId: userId);
      } catch (_) {
        _offlineChannelInfo = null;
      }
    }
  }

  @override
  @action
  void dispose() {
    _overlayTimer?.cancel();
    player.dispose();
  }
}
```

> NOTE: confirm `twitchApi.dio` exposes the Dio instance (check `lib/apis/twitch_api.dart` / `BaseApiClient`). If the field is named differently, pass that instead when constructing `TwitchStreamService`.

- [ ] **Step 2: Generate the MobX mixin**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: creates `native_video_store.g.dart`.

- [ ] **Step 3: Verify**

Run: `flutter analyze`
Expected: clean. Fix any interface-mismatch errors so `NativeVideoStore` fully satisfies `PlayerController`.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/channel/video/stores/native_video_store.dart lib/screens/channel/video/stores/native_video_store.g.dart
git commit -m "add native video store using media_kit low-latency player"
```

---

### Task 7: NativeVideo widget

**Files:**
- Create: `lib/screens/channel/video/native_video.dart`

- [ ] **Step 1: Implement the widget**

`lib/screens/channel/video/native_video.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:onset/screens/channel/video/stores/native_video_store.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Renders the native low-latency video surface for [NativeVideoStore].
class NativeVideo extends StatelessWidget {
  final NativeVideoStore videoStore;

  const NativeVideo({super.key, required this.videoStore});

  @override
  Widget build(BuildContext context) {
    return Video(
      controller: videoStore.videoController,
      controls: NoVideoControls, // ONSET draws its own overlay.
      fit: BoxFit.contain,
    );
  }
}
```

- [ ] **Step 2: Verify**

Run: `flutter analyze`
Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/channel/video/native_video.dart
git commit -m "add native video widget"
```

---

### Task 8: Wire the engine switch into channel.dart + overlay

**Files:**
- Modify: `lib/screens/channel/video/video_overlay.dart`
- Modify: `lib/screens/channel/channel.dart`

- [ ] **Step 1: Re-type the overlay to the interface**

In `lib/screens/channel/video/video_overlay.dart`, change the field type and import:
```dart
import 'package:onset/screens/channel/video/player_controller.dart';
```
```dart
  final PlayerController videoStore;
```
(Remove the now-unused `import '.../video_store.dart';` if present.)

- [ ] **Step 2: Verify the overlay still compiles against the interface**

Run: `flutter analyze`
Expected: clean. Any error here names a member used by the overlay but missing from `PlayerController` — add it to the interface (Task 4) and to both stores, then re-run.

- [ ] **Step 3: Select the store + widget by engine in channel.dart**

In `lib/screens/channel/channel.dart`:

Add imports:
```dart
import 'package:onset/screens/channel/video/native_video.dart';
import 'package:onset/screens/channel/video/stores/native_video_store.dart';
import 'package:onset/screens/channel/video/player_controller.dart';
```

Replace the `late final VideoStore _videoStore = VideoStore(...)` initializer (around line 78) with an engine-typed controller built once from the setting:
```dart
  late final PlayerController _videoStore = _buildPlayerController();

  PlayerController _buildPlayerController() {
    final settingsStore = context.read<SettingsStore>();
    if (settingsStore.playerEngine == PlayerEngine.nativeLowLatency) {
      return NativeVideoStore(
        userLogin: widget.userLogin,
        userId: widget.userId,
        twitchApi: context.read<TwitchApi>(),
        authStore: context.read<AuthStore>(),
        settingsStore: settingsStore,
      );
    }
    return VideoStore(
      userLogin: widget.userLogin,
      userId: widget.userId,
      twitchApi: context.read<TwitchApi>(),
      authStore: context.read<AuthStore>(),
      settingsStore: settingsStore,
    );
  }
```
> Match the exact constructor argument names/values used by the original `VideoStore(...)` call you are replacing — copy them verbatim from the existing initializer (the `context.read` sources above are illustrative; use whatever the original code passes).

Replace the player widget construction (original `Video(key: _videoKey, videoStore: _videoStore)` near line 300) with an engine-aware build:
```dart
            final store = _videoStore;
            final player = store is NativeVideoStore
                ? NativeVideo(key: _videoKey, videoStore: store)
                : Video(key: _videoKey, videoStore: store as VideoStore);
```
and use `player` where `Video(...)` was previously placed in the tree.

> For any remaining direct `VideoStore`-typed usages the analyzer flags in
> `channel.dart` (e.g. `_videoStore.isInPipMode`), they already exist on
> `PlayerController`, so they compile unchanged. Only the two construction sites
> above need editing.

- [ ] **Step 4: Verify build**

Run: `flutter analyze`
Expected: clean.

- [ ] **Step 5: Device verification (the real test)**

Run:
```bash
flutter run --dart-define=clientId=YOUR_ID --dart-define=secret=YOUR_SECRET
```
Then on the device:
1. Open a live channel → native player loads and plays.
2. Compare latency against the Phase 0 baseline (the official Twitch app / old WebView) — expect a large reduction (~2–4s).
3. Quality menu lists qualities and switching works.
4. Chat still shows 7TV/BTTV/FFZ emotes, deleted messages, and timeout/ban notices (these are unchanged but confirm).
5. In Settings → change engine to "Twitch web" (added in Task 9) → the old WebView still works.

Expected: low-latency playback, all features intact, fallback works.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/channel/channel.dart lib/screens/channel/video/video_overlay.dart
git commit -m "select player engine in channel and overlay by setting"
```

---

### Task 9: Settings UI — engine picker

**Files:**
- Modify: `lib/screens/settings/video_settings.dart`

Read `video_settings.dart` to copy the existing settings-row pattern (it already renders toggles like `useTextureRendering`). Add a list/segmented control bound to `settingsStore.playerEngine`.

- [ ] **Step 1: Add the picker**

Add a setting row (mirroring the existing rows in this file) that sets `settingsStore.playerEngine`:
```dart
        SettingsListSwitch(
          title: 'Low-latency native player',
          subtitle:
              'Plays the stream with a native player for much lower latency. '
              'Turn off to use the original Twitch web player.',
          value: settingsStore.playerEngine == PlayerEngine.nativeLowLatency,
          onChanged: (enabled) => settingsStore.playerEngine = enabled
              ? PlayerEngine.nativeLowLatency
              : PlayerEngine.twitchWeb,
        ),
```
> Use the actual settings-row widget/class this file already uses (e.g. the
> existing switch component). Match its required parameters; the snippet above
> is the intent, not necessarily the exact widget name.

- [ ] **Step 2: Verify**

Run: `flutter analyze`
Expected: clean.

- [ ] **Step 3: Device check**

Toggle the setting, reopen a channel, confirm the engine changes.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/settings/video_settings.dart
git commit -m "add player engine toggle to video settings"
```

---

## Phase 2 — Native default polish + latency → chat sync

### Task 10: Compute and display native latency, feed chat auto-sync

**Files:**
- Modify: `lib/screens/channel/video/stores/native_video_store.dart`

media_kit doesn't expose Twitch's "latency to broadcaster" directly. Approximate live-edge delay from the player position vs buffer end, and reuse the existing `settingsStore.syncedChatDelay` / `autoSyncChatDelay` plumbing (same fields `VideoStore` writes).

- [ ] **Step 1: Track latency from the player stream**

In `NativeVideoStoreBase` constructor, after the `playing` listener, add a periodic estimate:
```dart
    player.stream.buffer.listen((buffered) {
      final positionMs = player.state.position.inMilliseconds;
      final bufferedMs = buffered.inMilliseconds;
      final behindSeconds = ((bufferedMs - positionMs) / 1000).clamp(0, 60);
      runInAction(() {
        _latency = '${behindSeconds.round()}s';
        if (settingsStore.autoSyncChatDelay) {
          settingsStore.syncedChatDelay = behindSeconds.toDouble();
        }
      });
    });
```
> This is an approximation of distance-from-live, not Twitch's exact metric, but
> it is enough to drive the chat-delay sync and show a latency number. If it
> reads as 0 on device, switch the source to the gap between
> `player.state.duration` (live edge) and `player.state.position`.

- [ ] **Step 2: Verify**

Run: `flutter analyze` then device check: latency badge updates; enabling auto-sync shifts chat timing to match video.
Expected: latency visible; chat sync responds.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/channel/video/stores/native_video_store.dart lib/screens/channel/video/stores/native_video_store.g.dart
git commit -m "estimate native latency and feed chat delay sync"
```

---

### Task 11: Automatic fallback to WebView on native failure

**Files:**
- Modify: `lib/screens/channel/channel.dart`

If `NativeVideoStore` fails to load the playlist (Twitch API change, geo-block, etc.), fall back to the WebView engine for this session so the app never shows a dead player.

- [ ] **Step 1: Catch load failure and rebuild with WebView**

Wrap the native store's first load so a failure flips a local `_engineOverride` to `PlayerEngine.twitchWeb` and rebuilds `_videoStore`. Concretely, expose a `Future<void> get ready` on `NativeVideoStore` that completes/throws based on `_load()`, and in `channel.dart`:
```dart
  @override
  void initState() {
    super.initState();
    final store = _videoStore;
    if (store is NativeVideoStore) {
      store.ready.catchError((_) {
        if (!mounted) return;
        setState(() {
          _videoStore.dispose();
          _videoStore = _buildPlayerController(forceWeb: true);
        });
      });
    }
    // ...keep existing initState body...
  }
```
Add `bool forceWeb = false` to `_buildPlayerController` that forces the `VideoStore` branch, and make `_videoStore` non-`late`/reassignable (`PlayerController _videoStore;` set in `initState`).

In `NativeVideoStore`, store the load future:
```dart
  late final Future<void> ready = _load();
```
and remove the bare `_load();` call from the constructor (replace with nothing — `ready` triggers it).

- [ ] **Step 2: Verify**

Run: `flutter analyze`. Device check: temporarily break the token (e.g. wrong login) → app falls back to WebView instead of a black screen.
Expected: graceful fallback.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/channel/channel.dart lib/screens/channel/video/stores/native_video_store.dart lib/screens/channel/video/stores/native_video_store.g.dart
git commit -m "fall back to webview engine when native playback fails"
```

---

## Phase 3 — Feature-preservation + review pass

### Task 12: Full regression checklist on device

**Files:** none (verification only)

- [ ] **Step 1: Run the feature matrix on a real device**

Confirm each still works with the **native** engine selected:
- [ ] 7TV / BTTV / FFZ emotes render in chat
- [ ] Deleted messages: `showDeletedMessages` on shows them; off + tap reveals (`<message deleted>`)
- [ ] Timeout / ban notices ("Timed out for N seconds", "Permanently banned")
- [ ] Badges, mentions, autocomplete, send message
- [ ] Followed streams list, search, theme switching
- [ ] Theater / fullscreen, landscape
- [ ] PiP (WebView engine), backgrounding
- [ ] Quality switch, refresh, pause/play
- [ ] Latency badge + auto chat-delay sync
- [ ] Engine toggle switches native ↔ webview

Expected: every item passes. Any failure → fix before proceeding.

- [ ] **Step 2: Run the test suite**

Run: `flutter test`
Expected: all green.

### Task 13: Code review + security review

- [ ] **Step 1: Static review**

Run: `flutter analyze`
Expected: zero issues.

- [ ] **Step 2: Invoke review skills**

Use the `code-review` skill on the diff (`git diff main...low-latency-player`), the `security-review` skill on `twitch_stream_service.dart` (handling of tokens/signatures, no secret logging), and `pr-review-toolkit` for a broader pass. Address findings.

- [ ] **Step 3: Final commit**

```bash
git add -A
git commit -m "address review findings for low-latency player"
```

---

## Self-Review notes (author)

- **Spec coverage:** native player (Tasks 4,6,7,8), token/usher service (Task 3), parser (Task 2), engine toggle + fallback (Tasks 5,9,11), latency→chat sync (Task 10), feature preservation (Task 12), reviews (Task 13). All spec sections mapped.
- **Risk acknowledged in-plan:** GQL persisted-query hash and the latency estimate are the two most likely device-time adjustments; each has an inline fallback note.
- **Unverifiable-on-Windows parts** (media_kit playback, real latency) are explicitly device-verified, not faked as unit tests.
