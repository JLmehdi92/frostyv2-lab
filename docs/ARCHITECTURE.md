# ONSET architecture

ONSET is a Flutter Twitch client for Android (the Dart code stays
iOS-compatible). Its default live player is the native Amazon IVS player,
which keeps the stream close to the live edge; the Twitch web player in a
WebView stays available as a fallback. Every path below is relative to the
repository root.

## 1. Stack

- **Flutter 3.38.4 / Dart 3.10.3**, pinned in the CI workflows (newer releases
  break `extended_text_field` and `simple_icons`, older ones `app_links`).
- **State**: MobX (`mobx`, `flutter_mobx`, `mobx_codegen` with
  `build_runner`); dependency injection with `provider`.
- **Network**: `dio` (one shared client from `lib/apis/dio_client.dart`) and
  `web_socket_channel` (IRC chat, 7TV EventAPI, Twitch real-time sockets).
- **Video**: the Amazon IVS Android SDK (Gradle dependency in
  `android/app/build.gradle.kts`), `media_kit` (libmpv) and `webview_flutter`.
  Picture-in-picture comes from the vendored plugin `packages/simple_pip_mode`.
- **Storage**: `flutter_secure_storage` for tokens, `shared_preferences` for
  settings, `flutter_cache_manager` / `cached_network_image` for images.
- **Firebase** (Crashlytics, Analytics, Performance) is optional: it only
  starts when the build carries the `FIREBASE_*` dart-defines
  (`lib/services/telemetry.dart`), and collects only once the viewer turns
  on "Share crash logs and analytics" (`lib/services/telemetry_consent.dart`).
  No Firebase config is committed; the release repository's `FIREBASE_*`
  secrets give the published builds one, so the privacy policy must be
  updated before Firebase is turned on or off there.
- **Tests**: `flutter_test`, `mocktail`, `http_mock_adapter`.

## 2. Repository layout

```
.github/workflows/   ci.yml (analyze + test on push and pull request)
                     onset-update.yml (signed APK published as a release)
.github/assets/      README media (animated logo, screenshots)
android/             Android host app and the native Kotlin bridges
ios/                 iOS host app (plugins only, no native player)
packages/            simple_pip_mode (vendored plugin)
assets/              fonts, celebration art, launcher icons, the ONSET mark, release notes
docs/                this file and the in-app update setup (MISES_A_JOUR.md)
tool/                developer scripts outside the app (onset_logo_assets.py,
                     readme_logo.py, readme_shots/) and token_proxy/, the
                     Cloudflare Worker that hands out logged-out app tokens
lib/
  main.dart          entry point: services, global stores, providers, routes
  theme.dart         design tokens and the light and dark themes
  constants.dart     build-time constants (dart-defines) and shared regexes
  apis/              HTTP services, all extending BaseApiClient, and Dio interceptors
  models/            data models (@JsonSerializable, generated .g.dart committed)
  services/          app-level services: playback, realtime sockets, updates,
                     notifications, go-live polling, image cache, telemetry
  stores/            global MobX stores only (assets, mini player, whispers)
  utils/             helpers (common_utils.dart, context extensions, links)
  widgets/           widgets shared by several features (sheets, motion,
                     launch intro, mini player window, update prompt)
  screens/           one folder per feature, each with its own stores/ and
                     widgets/ where it has them:
    activity/          notifications and whispers inbox
    channel/           live channel screen
      video/           player engines, overlay, latency, quality, captions
      chat/            IRC chat, emotes, moderation, chat details
      celebrations/    raid and gift celebrations (particles/ engine)
      community_highlights/  pinned highlights, raids, gift bombs
      hype_train/      hype train banner, sheet and effects
    channel_profile/   channel page (home, about, schedule, videos)
    clips/             clips feed and clip player
    home/              navigation shell, Following / Live / Clips feeds,
                       Browse (top/), search, stream lists
    onboarding/        first-launch flow
    settings/          settings pages, auth, settings and user stores
    vod/               past broadcasts with chat replay
    whispers/          whisper threads
test/                mirrors lib/, plus guards/ (repo-wide checks),
                     helpers/ and fixtures/ (shared test code)
```

## 3. Layers

- **APIs** (`lib/apis/`). `BaseApiClient` (`lib/apis/base_api_client.dart`)
  gives typed `get` / `post` / `put` / `delete` calls and maps `DioException`
  to `ApiException` subclasses. Every service extends it: `TwitchApi`
  (Helix and OAuth), the GQL-based services (stream, VOD, clips, directory,
  hype train, points, channel profile, community highlights, chat rules,
  followed categories, watch streaks), `BTTVApi`, `FFZApi`, `SevenTVApi` and
  `OnsetUpdateService`. `TwitchAuthInterceptor` adds the Helix credentials;
  `UnauthorizedInterceptor` turns a 401 into a reconnect prompt.
- **Models** (`lib/models/`). JSON models with committed `.g.dart` files, plus
  hand-written parsers such as `lib/models/irc.dart` (IRC messages) and
  `lib/models/hls_variant.dart` (HLS master playlists).
- **Services** (`lib/services/`). Plain Dart services created in
  `lib/main.dart`: playback focus, preloading and token cache, background
  audio, audio focus, network metering, the Twitch real-time sockets
  (`lib/services/realtime/`), go-live polling (`lib/services/go_live/`),
  local notifications (`lib/services/notifications/`), the web session token,
  the in-app updater and installer, the image cache and telemetry.
- **Stores** (MobX, see §5). Screens observe them with `Observer`.
- **Screens and widgets**. Each feature under `lib/screens/` owns its
  widgets; `lib/widgets/` only holds what several features share.

Navigation is imperative (`Navigator` and `MaterialPageRoute`). `lib/main.dart`
builds the services and global stores, exposes them with `MultiProvider`
(shortcuts in `lib/utils/context_extensions.dart`) and opens either the
onboarding flow (`lib/screens/onboarding/`) or `Home`, the navigation shell
(`lib/screens/home/home.dart`, `lib/screens/home/shell/`). `MaterialApp.builder`
lays the global mini player (`lib/widgets/global_mini_player.dart`) over every
route. Deep links (`app_links`) open channels, VODs and clips.

## 4. Player engines

The live player is chosen per channel by `resolvePlayerEngine`
(`lib/screens/channel/video/player_engine_resolver.dart`) from the
`playerEngine` setting (`PlayerEngine` in
`lib/screens/settings/stores/settings_store.dart`). All engines implement
`PlayerController` (`lib/screens/channel/video/player_controller.dart`), which
is all the overlay (`lib/screens/channel/video/video_overlay.dart`) and the
channel screen (`lib/screens/channel/channel.dart`) depend on.

| Engine | Store | View | Notes |
|---|---|---|---|
| `ivs` (default) | `IvsVideoStore` (`lib/screens/channel/video/stores/ivs_video_store.dart`) | `IvsTextureVideo` (`lib/screens/channel/video/ivs_video.dart`) | Android only. The IVS SDK renders into a Flutter texture (`android/app/src/main/kotlin/app/onset/IvsTexturePlayer.kt`, `android/app/src/main/kotlin/app/onset/IvsPlayerCore.kt`, `android/app/src/main/kotlin/app/onset/IvsTuning.kt`) over the `onset/ivs-texture-manager` channel. |
| `nativeLowLatency` | `NativeVideoStore` (`lib/screens/channel/video/stores/native_video_store.dart`) | `NativeVideo` (`lib/screens/channel/video/native_video.dart`) | media_kit (libmpv) with low-latency demuxer settings. Not offered in the settings UI. |
| `twitchWeb` | `VideoStore` (`lib/screens/channel/video/stores/video_store.dart`) | `Video` (`lib/screens/channel/video/video.dart`) | The Twitch web player in a WebView. Fallback engine, and the engine on iOS. |

- **Stream URL.** The native engines get a playback access token and the HLS
  master playlist from `TwitchStreamService`
  (`lib/apis/twitch_stream_service.dart`). Tokens are cached per channel
  (`lib/services/playback_token_cache.dart`) and requested as soon as a
  stream card is pressed (`lib/services/playback_preloader.dart`).
- **Fallback.** IVS is only used on Android. If a native engine fails to
  resolve its stream or reports a fatal error, the channel screen rebuilds
  the player with the WebView engine for the session, so the app keeps
  playing when the token or playlist flow changes.
- **Latency.** The overlay shows the measured latency (`showLatency`, on by
  default; `lib/screens/channel/video/latency_pill.dart`) and a stats panel
  (`lib/screens/channel/video/ivs_stats_panel.dart`). With Auto latency on
  (default), `LatencyController`
  (`lib/screens/channel/video/latency_controller.dart`) plays a drifted IVS
  stream at 1.05x until it is back near its target, without a reload (in
  picture-in-picture and the mini player too); the player is then created
  without the SDK speed-up, which would reset the rate. Where the catch-up
  does not run (stopped after stalls, a stream without low latency), a
  1.03x drain of a clearly excessive buffer takes the SDK's place. With
  Ultra buffering, repeated network stalls make the next streams use
  Standard for a while (`lib/screens/channel/video/buffer_fallback.dart`).
  `LiveEdgeGuard` (`lib/screens/channel/video/live_edge_guard.dart`) stays
  the last resort: it reloads the IVS stream when it drifts too far behind
  live. The measured latency can drive the chat
  delay, so messages line up with the picture
  (`lib/screens/channel/chat/chat_delay_queue.dart`).
- **Mini player and PiP.** Dragging the video down hands the live
  `IvsVideoStore` and the channel's `ChatTabsStore` to `MiniPlayerStore`
  (`lib/stores/mini_player_store.dart`), so playback and chat continue in a
  floating window without a reload. Android picture-in-picture goes through
  `simple_pip_mode`; background audio uses a media notification
  (`lib/services/background_audio.dart`).
- **VODs and clips.** VODs use `VodPlayerController`
  (`lib/screens/vod/vod_player_controller.dart`) with `IvsVodStore` (native)
  or `WebVodStore` (WebView) in `lib/screens/vod/stores/`. Clips play on their
  own media_kit player (`lib/screens/clips/clip_media_backend.dart`, driven by
  `lib/screens/clips/stores/clip_player_store.dart`).
- **One audible player.** `PlaybackFocus` (`lib/services/playback_focus.dart`)
  pauses the player underneath when a live or VOD screen opens on top.

## 5. Stores

MobX stores use the generated mixin pattern (`class Foo = FooBase with
_$Foo`); the canonical example is
`lib/screens/settings/stores/auth_store.dart`. Run `build_runner` after
changing one and commit the generated `.g.dart` next to its source.

- **Global** (`lib/stores/`, provided in `lib/main.dart`): `GlobalAssetsStore`
  (global emotes and badges), `MiniPlayerStore`, `WhisperStore`.
- **Settings and session** (`lib/screens/settings/stores/`): `AuthStore`
  (OAuth login, tokens in secure storage), `SettingsStore` (every setting,
  persisted as JSON in shared preferences), `UserStore`.
- **Channel**: `lib/screens/channel/stores/` (channel events, clip creation),
  `lib/screens/channel/video/stores/` (the three live engines, captions),
  `lib/screens/channel/chat/stores/` (chat tabs, chat connection, chat assets,
  chat rules), `lib/screens/channel/chat/details/stores/` (chatters and chat
  details), `lib/screens/channel/hype_train/stores/` and
  `lib/screens/channel/community_highlights/stores/`.
- **Home**: `lib/screens/home/stores/` (shell section and tabs),
  `lib/screens/home/stream_list/stores/`, `lib/screens/home/live_feed/stores/`,
  `lib/screens/home/search/stores/`, `lib/screens/home/top/categories/stores/`,
  `lib/screens/home/continue_watching/stores/` and
  `lib/screens/home/followed_videos/stores/`.
- **Other features**: `lib/screens/activity/stores/`,
  `lib/screens/channel_profile/stores/`, `lib/screens/clips/stores/` and
  `lib/screens/vod/stores/`.

## 6. Chat

The chat layer is independent of the player. `ChatStore`
(`lib/screens/channel/chat/stores/chat_store.dart`) connects to Twitch IRC
over a WebSocket, parses messages with `lib/models/irc.dart` and applies the
chat delay. `ChatAssetsStore` loads Twitch, 7TV, BTTV and FFZ emotes and
badges; 7TV emote set changes arrive live through the 7TV EventAPI.
Moderation actions go through Helix (`lib/screens/channel/chat/moderation.dart`).
Real-time Twitch events (hype trains, highlights, channel points) come from
the shared socket in `lib/services/realtime/`.

## 7. In-app updates

- **Build.** Each push to `main` runs `.github/workflows/onset-update.yml`,
  which builds a signed arm64 APK with Flutter 3.38.4 and publishes it as a
  `build-N` GitHub release with its SHA-256, N being the APK's build number,
  2000 + the workflow's run number (so build numbers start at 2001 and only
  grow). The app offers a release only when N is
  higher than its own build number. The one-time setup (keystore, secrets,
  public or private repository) is in `docs/MISES_A_JOUR.md`.
- **App.** `OnsetUpdater` (`lib/services/onset_updater.dart`) is only enabled
  on Android builds that carry `UPDATE_REPO` (and `UPDATE_TOKEN` while the
  repository is private); see `lib/constants.dart`. It checks the latest
  release through `OnsetUpdateService` (`lib/apis/onset_update_service.dart`),
  downloads the APK, verifies its SHA-256 and hands it to the Android
  installer (`lib/services/onset_installer.dart`,
  `android/app/src/main/kotlin/app/onset/ApkInstaller.kt`). The prompt lives
  in `lib/widgets/onset_update_prompt.dart`.
- **Release notes.** `assets/release-notes.md` is bundled and shown by
  `lib/screens/settings/widgets/release_notes.dart`.
- Local builds have no `UPDATE_REPO`, so they never check for updates.

## 8. Build and verify

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # after store or model changes
flutter analyze                                            # must be clean
flutter test                                               # must be green
flutter run --dart-define=CLIENT_ID=<id> --dart-define=TOKEN_PROXY_URL=<https://worker-url>
flutter build apk --release --dart-define=CLIENT_ID=<id> --dart-define=TOKEN_PROXY_URL=<https://worker-url>
```

- `CLIENT_ID` is the login Twitch application's (it is public by design: it
  is in every Helix request). `TOKEN_PROXY_URL` is the token proxy, a
  Cloudflare Worker (`tool/token_proxy/`) that hands logged-out viewers an app
  access token (`TwitchApi.getDefaultToken`) minted for a **second** Twitch
  application nobody logs in to, with that application's client id. The app
  checks the token with Twitch and sends it with that client id
  (`AuthStore`'s foreign-token mechanism, `default_token_client_id` in secure
  storage); logged-in sessions keep the login application's. An app token of
  the login application could subscribe to its users' private EventSub
  events; one of an application nobody authorized cannot. No client secret
  is in the app or the repository (`test/guards/no_client_secret_test.dart`).
  The VS Code launch configurations read both values from `.env` (copy
  `.env.example`). `TOKEN_PROXY_URL` must match
  `TwitchApi.tokenProxyUrlPattern`, which the update workflow checks too.
- Without a usable proxy (no URL, or the Worker down) the app still starts
  and logging in works; logged-out Helix features fail quietly. A logged-out
  viewer never gets the login dialog from a Helix 401
  (`UnauthorizedInterceptor`, `AuthStore.isAnonymous`): `retryAppToken`, at
  most once a minute, asks the proxy again when there is no token, or asks
  Twitch whether the token still works and replaces it if it was revoked or
  expired. A user's session, even reconnecting, keeps the dialog.
- Changing the login application (a new `CLIENT_ID`) needs no migration: a
  stored user token of the old application keeps working as another app's
  token (`TokenCheck.foreign`, with `foreignTokenNotice`) while that
  application exists; once it is deleted Twitch refuses it, and the launch
  logs out cleanly with `sessionEndedNotice` (no reconnect loop). A stored
  app token of the old application is replaced by the proxy's.
- A release build without a release signing key configured in `android/`
  is signed with the debug key.
- CI (`.github/workflows/ci.yml`) runs `flutter analyze` and `flutter test` on
  Linux for every push to `main` and every pull request.
- Several tracked files use CRLF line endings (`pubspec.yaml`,
  `lib/screens/channel/channel.dart`, `AndroidManifest.xml`, among others):
  edit them in place without converting the whole file.
