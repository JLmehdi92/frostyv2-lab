# Implementation Plan: E1 "VOD" (in-app past broadcasts with chat replay, ONSET design)

Planner: ECC `planner` (read-only). Base: `ef1a80c` ("add roadmap for full twitch parity"). Repo: `/home/user/frostyv2-lab`.
**Complexity: Large** (about 10 tightly scoped commits, Kotlin + Dart + UI).
**WAITING FOR CONFIRMATION**: no code is written until the user approves (see "Decisions to confirm" at the end).

---

## Overview

Past broadcasts, highlights and uploads play in a new in-app VOD theatre. The player is the native IVS texture player, extended with seek, playback rate and progress events. If IVS is unavailable, the in-app Twitch embed WebView takes over. The browser is never used.

Chat replay is fetched anonymously from GQL `video.comments(contentOffsetSeconds)`. Each comment is converted into a normal `IRCMessage`, so the existing span renderer and `ChatAssetsStore` draw Twitch, 7TV, BTTV and FFZ emotes, badges and name colours unchanged.

Entry points:
- a channel Videos list (Past broadcasts / Highlights / Uploads)
- the live overlay, the offline overlay, the chat-only app bar, the chat user card and the stream-card long-press menu
- deep links and chat links for `/videos/<id>`, `/v/<id>`, `/<channel>/v/<id>` and `?t=`

Resume positions are stored locally.

The live path is kept byte-for-byte where possible:
- No change to `TwitchStreamService`, live usher parameters, the live `IvsTuning` defaults, the latency ticker, `ChatStore` or `IRCMessage`.
- Live code is touched only for: a mechanical overlay-helper extraction, a playback-focus hook, new entry-point buttons and in-app routing of VOD links.

## Requirements (restated)

1. VODs play **inside the app** (native IVS, or the in-app embed WebView as fallback), never in an external browser. This applies to list taps, deep links and links tapped in chat.
2. Player controls:
   - seek bar with elapsed and duration
   - −10 s / +30 s buttons and double-tap seek
   - speed 0.5–2.0× in 0.25 steps
   - quality (restored with the existing `quality_selection.dart` rules)
   - mute and volume
   - play/pause, replay at the end
   - fullscreen/landscape with the chat column or overlay, as on live
   - system PiP (the existing `simple_pip_mode` pattern)
3. Chat replay synced to the playback position:
   - shows 7TV, BTTV and FFZ emotes (channel + global), Twitch badges (global + channel, FFZ mod/VIP overrides) and user colours
   - read-only, never sends
   - hides gracefully on failure; uploads show a "no chat replay" state
4. Channel Videos list with three tabs, infinite scroll, thumbnails, duration, date, views, category and a resume progress bar.
5. Local resume:
   - saved every 20 s, on pause, on app background and on exit
   - reopening starts 30 s before the saved position
   - `?t=` overrides the saved position
6. ONSET design only: `lib/theme.dart`, `FrostyColors`, `kOverlayShadow`, `kCardBorderRadius`, and the `lib/widgets/` kit (`SectionHeader`, `AlertMessage`, `FrostyPageView`, `SkeletonLoader*`, `BlurredContainer`, `DraggableDivider`, `FrostyCachedNetworkImage`, `ProfilePicture`, `ScrollToTopButton`). No Twitch assets or text are copied.
7. No regressions in: live latency, stats panel, chat, 7TV live updates, moderation rendering, mini player, PiP, WebView fallback, iOS (web engine).

## Verified facts used by this plan (live, 2026-10-13, public web Client-ID, full query text, no user token, no integrity header)

- `user(login){videos(first,type,after){edges{cursor node{…}} pageInfo{hasNextPage}}}` works.
- `video(id){comments(contentOffsetSeconds){edges{cursor node{contentOffsetSeconds commenter{id login displayName} message{fragments{text emote{emoteID}} userBadges{setID version} userColor}}} pageInfo{hasNextPage}}}` works anonymously and returns about 50 comments.
  - This contradicts GAP.md PRF-12 ("requires Client-Integrity"). Update GAP.md in the final docs commit.
- `videoPlaybackAccessToken(id, params:{platform:"web",playerBackend:"mediaplayer",playerType:"site"}){value signature}` works.
  - The token JSON carries `expires`, `chansub.restricted_bitrates` and `authorization.forbidden`.
- usher `https://usher.ttvnw.net/vod/<id>.m3u8?allow_source=true&allow_audio_only=true&supported_codecs=av1,h265,h264&playlist_include_framerate=true&p=<rand>&sig=..&token=..` returns HTTP 200 with a 1080p60…360p master playlist.

Fields marked **(TBC)** below must be confirmed by a captured fixture before the commit lands. In GraphQL one unknown field fails the whole query, so every unconfirmed field goes into a separate optional query or is removed.

---

## Patterns to Mirror

| Category | Source | Pattern |
|---|---|---|
| API service | `lib/apis/twitch_stream_service.dart:16-49,122-160` | Extends `BaseApiClient`. Public web Client-ID header. Full GQL document, no persisted hash. Keeps `_http` for raw needs. `@visibleForTesting static` parameter builder (`usherQueryParameters`, l.101). Throws `ApiException` when the token is missing. |
| Token cache | `lib/services/playback_token_cache.dart` + `lib/models/playback_access_token.dart` | `PlaybackAccessToken.fromValue` parses `expires`. LRU cache with a 60 s safety margin, never persisted or logged. |
| Native player store | `lib/screens/channel/video/stores/ivs_video_store.dart` (l.293 `_createTexture`, l.346 `_onEvent`, l.417 `_applyRecovery`, l.591 `_restoreQuality`, l.746 `dispose`, l.242 auto-PiP autorun) | Store-owned texture via `frosty/ivs-texture-manager`, per-texture channel `frosty/ivs-texture/<id>`, `_recoveryEpoch` staleness guard, `_textureReady` gate, quality restore generation counter, sound re-send after each load. |
| Recovery | `lib/screens/channel/video/ivs_recovery.dart` | `classifyIvsError` → `IvsRecoveryPolicy.onError` → `IvsRetry` / `IvsOffline` / `IvsFallback`. |
| Native config | `lib/screens/channel/video/ivs_player_config.dart` + `IvsTuning.kt:70 fromArgs` | Dart config map → tolerant Kotlin parsing with defaults. |
| Kotlin bridge | `IvsPlayerCore.kt:59 "load"`, `:108 onDurationChanged` (empty today), `:120 startLatencyTicker` | `when(call.method)`, `send(mapOf("type" to …))` posted on the main looper, every getter wrapped in `runCatching`. |
| Feature store | `lib/screens/settings/stores/auth_store.dart` (canonical), `ivs_video_store.dart` | `Foo = FooBase with _$Foo`, `@readonly` private observables, `@action`, `part '*.g.dart'`. |
| Store tests | `test/screens/channel/video/stores/ivs_video_store_test.dart` + `test/helpers/fake_ivs_native.dart` | mocktail mocks, real `SettingsStore.fromJson({})`, `SharedPreferences.setMockInitialValues`, `FakeIvsNative.install/emit/callsNamed`, `settle()` loops, `dispose` in `tearDown`. |
| API tests | `test/apis/twitch_stream_service_test.dart` | `DioAdapter` with full URLs, `data: Matchers.any`, `throwsA(isA<ApiException>())`. |
| IRC rendering | `lib/models/irc.dart:950 fromString`, `:651 generateSpan`, `:249 _addUserBadges`, `:407 _addUsername` | Badges keyed `setID/version`. Emote ranges are UTF-16 `substring(start, end+1)`. `display-name`, `color`, `user-id`, `tmi-sent-ts` tags. |
| Chat assets | `chat_store.dart:748-760` + `chat_assets_store.dart:131,156` | `assetsStore.init()` then `assetsFuture(channelId, headers: auth.headersTwitch, show* flags from settings)`. **`dispose()` needs `init()` first** (late `_disposeReaction`). |
| Chat filters | `chat_store.dart:531-555` | Blocked users (`auth.user.blockedUsers`), muted words (`settings.mutedWords`, `matchWholeWord`). |
| Paged list | `lib/screens/home/stream_list/stream_list_store.dart:46-60,142` + `streams_list.dart:338` | `hasMore`, `isLoading`, `_error`, cursor, load more near the end. |
| Card UI | `lib/screens/home/stream_list/stream_card.dart:52-120` | 16:9 `FrostyCachedNetworkImage`, `SkeletonLoader(borderRadius: kCardBorderRadius)`, black 55% chip with a 0.5 px white 8% border, `ProfilePicture(radius: 10)`, subtitle size 14. |
| Overlay UI | `lib/screens/channel/video/video_overlay.dart:35-82,140-235` | Gradient overlay, `kOverlayShadow` icons in `overlayOnSurface`, settings bottom sheet built from `SectionHeader` + `ListTile` + check icon, volume `Slider.adaptive(divisions: 20)`. |
| Layout / PiP | `lib/screens/channel/channel.dart:165,287,871` | Close the mini player when a player opens. `PipWidget(pipLayout: mediaOnlyPause)`. Landscape column with `DraggableDivider` and `chatWidth` / `landscapeChatLeftSide` / `fullScreen*` settings. Dispose restores `SystemChrome`. |
| Deep links | `lib/main.dart:220-298` | `app_links`, `handleDeepLink(Uri)`, `navigatorKey`, failure `SnackBar(AlertMessage)`. |

Logging: `debugPrint('<Class> <op> failed: $e')`. Never print tokens, signatures or usher URLs. Usher calls never go through the shared Dio, because `FirebasePerformanceInterceptor` records URLs and `BaseApiClient._handleError` sends the request URI to Crashlytics.

---

## Architecture Changes (summary)

New feature folder `lib/screens/vod/`:
- `vod_screen.dart`, `vod_layout.dart`, `vod_overlay.dart`, `channel_videos.dart`
- `widgets/`: `vod_seek_bar.dart`, `vod_card.dart`, `vod_chat_replay.dart`, `vod_chat_message.dart`, `vod_speed_sheet.dart`, `vod_error_view.dart`
- `stores/`: `ivs_vod_store.dart`, `web_vod_store.dart`, `vod_chat_replay_store.dart`, `channel_videos_store.dart`
- pure files: `vod_player_controller.dart`, `vod_time.dart`, `vod_comment_cache.dart`, `vod_comment_to_irc.dart`, `vod_resume.dart`

Data layer:
- `lib/apis/twitch_vod_service.dart` (extends `BaseApiClient`)
- `lib/models/vod.dart`, `lib/models/vod_comment.dart`, `lib/models/vod_access.dart` (hand-written `fromJson`, the same approach as `hls_variant.dart`, so no codegen is needed; codegen is optional)

App-level services:
- `lib/services/playback_focus.dart`: one active player at a time
- `lib/utils/twitch_links.dart`: pure link parser
- `lib/utils/link_router.dart`: in-app routing hook used by `irc.dart`

Native:
- `IvsTuning.kt` gains a `vod` mode
- `IvsPlayerCore.kt` gains `seekTo`, `setPlaybackRate`, a `startMs` argument on load, and `duration` / `seeked` / `progress` events. The live ticker is unchanged.

Live code touched (small, additive):
- `video_overlay.dart`: Videos button, offline "Past broadcasts" pill, helper extraction
- `channel.dart`: PlaybackFocus registration and resume, chat-only app-bar action
- `chat_user_modal.dart`: Videos button
- `user_actions_modal.dart`: Videos tile
- `irc.dart`: one `onTap` line goes through `LinkRouter`
- `main.dart`: provider, `RouteObserver` not needed, link router registration, `handleDeepLink` VOD branch

---

## Commit sequence and dependencies

```
V1 data layer ──┬─> V2a native vod mode ─> V2b IvsVodStore ─┐
                └─> V3 chat replay store ───────────────────┤
V4a extract overlay helpers (independent, live-safe) ───────┤
V4b playback focus (one player at a time) ──────────────────┤
                                                            v
                                  V4c VOD screen (IVS) ─> V4d WebView VOD fallback
                                                            v
                         V5a channel Videos list + entry points ─> V5b in-app VOD links
                                                            v
                                                   V6 local resume ─> V7 docs (GAP/ARCHITECTURE)
```

Each commit must be independently green (`flutter analyze`, `flutter test`) and must leave the app working. Commits are lowercase, with no prefix.

---

### V1 — `add twitch vod gql service and models`

**Goal:** an anonymous, fully tested data layer for lists, a single VOD, comments, the token and the usher URL. No UI.

**Step 0 (manual, before any test):** capture real responses with `curl` (public Client-ID, full query text) for:
- a channel's ARCHIVE, HIGHLIGHT and UPLOAD pages (first 2)
- `video(id)` for a recorded VOD and, if possible, a still-recording VOD
- a comments page at offset 0 and at offset 3600
- an empty comments page past the end
- a GQL `errors` response (bad id)
- a 403 usher body for a sub-only VOD

Trim and anonymise the captures into `test/fixtures/vod_responses.dart`. Every field marked (TBC) is kept only if it appears in a 200 fixture.

**Files**
- CREATE `lib/models/vod.dart`
  - `enum VodType { archive, highlight, upload }` with `gqlName` (`ARCHIVE`/`HIGHLIGHT`/`UPLOAD`)
  - `class Vod { id, title, lengthSeconds, createdAt, viewCount, previewThumbnailUrl, gameName?, gameId?, ownerId, ownerLogin, ownerDisplayName, type?, isRecording (TBC status), isRestricted (TBC resourceRestriction) }`
  - `factory Vod.fromGql(JsonMap node, {JsonMap? owner})`: tolerant (missing optional fields → null) and strict on `id`, `lengthSeconds` and `createdAt`
  - `class VodPage { List<Vod> items; String? cursor; bool hasNextPage; }`
  - `class MutedSegment { int offset; int duration; }` (filled only by the optional query)
- CREATE `lib/models/vod_comment.dart`: `VodComment { id?, offsetSeconds, commenterId?, commenterLogin?, commenterDisplayName?, fragments: List<VodFragment{text, emoteId?}>, badges: List<(setId, version)>, color? }` and `VodCommentPage { comments, lastCursor?, hasNextPage }`. `id` is TBC; without it the dedupe key is `offset|commenterId|text`.
- CREATE `lib/models/vod_access.dart`: `VodAccessInfo.fromTokenValue(String value)` reads `authorization.forbidden`, `authorization.reason` (TBC), `chansub.restricted_bitrates` and `expires` (via `PlaybackAccessToken.parseExpiry`). Tolerant: malformed JSON → `forbidden=false`.
- CREATE `lib/apis/twitch_vod_service.dart` `class TwitchVodService extends BaseApiClient`:
  - `getChannelVideos({required String login, required VodType type, String? cursor, int first = 20})`. Query `user(login:$login){id login displayName videos(first:$first, after:$after, type:$type){…}}` (`sort:TIME` TBC; it is not needed because newest-first is the default).
  - `getVideo(String vodId)` returns `Vod?`, null when the VOD does not exist.
  - `getMutedSegments(String vodId)` → `List<MutedSegment>`. **Separate optional query** (`muteInfo{mutedSegmentConnection{nodes{duration offset}}}`, TBC). Never throws: returns `[]`.
  - `getComments({required String vodId, required int offsetSeconds})` → `VodCommentPage`.
  - `getCommentsAfter({required String vodId, required String cursor})`: TBC, because cursor paging may be integrity-gated. Separate document, since `after` and `contentOffsetSeconds` must not be sent together.
  - `getVodUsherUrl({required String vodId, bool forceFreshToken = false})` → `String`. Its own `videoPlaybackAccessToken` document (`playerType:"site"`, verified), so the live `PlaybackAccessToken_Template` is not touched.
  - `diagnoseVodPlaylist(String url)` → `VodPlaybackProblem?`. Raw `_http.get` with `validateStatus: (_) => true`. Maps the usher JSON `error_code` as follows:
    - `vod_manifest_restricted` → `subscriberOnly`
    - `content_geoblocked` → `geoBlocked`
    - `nauth_*` → `tokenRejected`
    - 404 → `notFound`
    - anything else → `unknown`
    - 200 → null
    It never throws and never logs the URL.
  - `@visibleForTesting static Map<String,String> vodUsherQueryParameters({signature, token, p})` = exactly `allow_source=true`, `allow_audio_only=true`, `supported_codecs=av1,h265,h264`, `playlist_include_framerate=true`, `p`, `sig`, `token`. **No `fast_bread`, no `type=any`.**
  - `@visibleForTesting static String normalizeVodId(String raw)` strips a leading `v` and requires `^\d{1,20}$`, otherwise it throws `ArgumentError`. This is a security check, because the id goes into a URL path.
  - Shared GQL helper `_gql(String op, String query, JsonMap vars)`: throws `VodApiException(message, isIntegrity: …)` when `errors` is non-empty, or when the data root is null. `isIntegrity` is true when an error message contains "integrity" (case-insensitive).
  - Token cache: the service owns a private `PlaybackTokenCache()` instance (keyed by numeric id; tokens are anonymous, so keying per user is not needed). It is never persisted or logged.
  - Own `Dio` with timeouts (connect 5 s, receive 8 s), like `IvsVideoStore` l.~190.
- UPDATE `lib/main.dart`: one `Provider<TwitchVodService>.value(...)` in `MultiProvider`. UPDATE `lib/utils/context_extensions.dart`: a `twitchVodService` getter.

**Behaviour:** pure data. Every failure is a typed exception or a null/empty result. Nothing in the app calls it yet.

**Tests first**
- `test/models/vod_test.dart`:
  - parses an archive node
  - parses a highlight with a null game
  - a recording node (`status` TBC)
  - a restricted node
  - a missing thumbnail → null
  - a malformed node (no id) throws `FormatException`
- `test/models/vod_comment_test.dart`:
  - text plus emote fragments
  - badges list
  - null `userColor`
  - null commenter (deleted user)
  - empty fragments
- `test/models/vod_access_test.dart`:
  - forbidden true/false
  - restricted_bitrates list
  - expiry
  - malformed value
- `test/apis/twitch_vod_service_test.dart` (`DioAdapter`):
  - list: sends `Client-ID` and the right variables (`type`, `after`, `first`); parses edges, cursor and hasNextPage; empty `edges`; `user: null` → `NotFoundException`/`VodApiException`; GQL `errors` → `VodApiException`; an integrity message sets `isIntegrity`
  - `getVideo` returns null for `video: null`
  - comments:
    - offset variable sent
    - page parsed in order
    - `hasNextPage` false
    - integrity error flagged
  - `getMutedSegments` returns `[]` on a GQL error (never throws)
  - usher:
    - token requested with `playerType: site` and the vod id
    - URL path `https://usher.ttvnw.net/vod/<id>.m3u8`
    - exact parameter set, with `supported_codecs=av1%2Ch265%2Ch264`
    - absence of `fast_bread` and `type`
    - the cached token is reused, and `forceFreshToken` bypasses the cache
    - `forbidden=true` throws `VodForbiddenException`
    - a missing token throws `ApiException`
  - `normalizeVodId`: `v123` → `123`; `123` → `123`; `12a`, `../1`, `''` and a 21-digit id throw
  - `diagnoseVodPlaylist`: 200 → null; 403 with `vod_manifest_restricted` → `subscriberOnly`; `content_geoblocked` → `geoBlocked`; 404 → `notFound`; a network error → `unknown`

**Risks**
- Unconfirmed field names (Medium). Mitigation: Step 0 fixtures, and optional fields in separate queries.
- Twitch changes the GQL schema (Medium). Mitigation: typed exceptions; the UI degrades to an error state, and live is unaffected.
- Tokens leaking through logs or Crashlytics (High impact). Mitigation: own Dio, raw diagnose call, no `debugPrint` of URLs, and a review checklist item.

**Acceptance:** all new tests green. `flutter analyze` clean. No change to `twitch_stream_service.dart` or its tests.

---

### V2a — `add a vod mode with seek and rate to the native ivs player`

**Goal:** native support for VOD playback without changing live behaviour.

**Files**
- UPDATE `android/app/src/main/kotlin/com/tommychow/frosty/IvsTuning.kt`:
  - New field `val vod: Boolean = false`, parsed in `fromArgs` (`args["vod"] as? Boolean ?: false`).
  - `buildPlayer`: when `vod`, build `MediaPlayer.Builder(context).build()` (no `SessionConfig` live catch-up), falling back to `Player.Factory.create`.
  - `applyTo`: when `vod`, call `setLiveLowLatencyEnabled(false)` and `setRebufferToLive(false)`, and do **not** set the 100 ms initial buffer (keep the SDK default for VOD smoothness). The live branch is byte-identical.
- UPDATE `IvsPlayerCore.kt`:
  - `start(url, tuning)` keeps `tuning` and `pendingStartMs: Long`.
  - New methods:
    - `"seekTo" {ms}` → `player.seekTo(ms.coerceAtLeast(0))`
    - `"setPlaybackRate" {rate}` → `player.playbackRate = rate.coerceIn(0.5f, 2f)`
    - `"getPosition"` → `result.success(player.position)`, for the final resume save
  - `"load"` reads the optional `startMs`. On the first `READY` after a load: if `pendingStartMs > 0` call `seekTo(pendingStartMs)`, then `play()` (live keeps calling `play()` directly).
  - `onDurationChanged(d)` → `send({"type":"duration","ms":d})`. `onSeekCompleted(p)` → `send({"type":"seeked","ms":p})`.
  - Ticker: if `tuning.vod`, a separate 250 ms `progressTicker` sends `{"type":"progress","positionMs","bufferedMs","durationMs"}` (each getter in `runCatching`) and **no** latency event. Otherwise the existing `startLatencyTicker()` runs unchanged. `dispose()` removes both.
- UPDATE `lib/screens/channel/video/ivs_player_config.dart`: add `static const Map<String, Object> vodCreateArgs = {'vod': true};`. The live `toCreateArgs()` is unchanged.

**Tests first**
- `test/screens/channel/video/ivs_player_config_test.dart`: `vodCreateArgs == {'vod': true}`; the live args for every enum combination are unchanged (existing tests stay green).
- Contract tests are written in V2b with `FakeIvsNative` (no Kotlin test infrastructure exists).
- Optional and cheap: add `testImplementation("junit:junit:4.13.2")` and `android/app/src/test/kotlin/.../IvsTuningTest.kt` for `fromArgs` (missing `vod` → false, `vod=true`, mistyped → default). Skip if Gradle test wiring is unwanted.

**Risks**
- `getDuration()` semantics for a still-recording VOD (playlist without ENDLIST is treated as live: duration may be −1 or `Long.MAX_VALUE`). Mitigation: Dart treats `<=0` or `>= 2^53` as unknown and falls back to `Vod.lengthSeconds` (V2b). Verify on a device (manual protocol §M4).
- `seekTo` before `READY` being ignored. Mitigation: deferred to the first READY.
- Accidental live change (High impact). Mitigation: every new path is gated on `tuning.vod`, and the live regression checklist runs after this commit.

**Acceptance:** builds (`flutter build apk --debug`). Live stream on device: latency badge, stats panel and catch-up identical (checklist R1–R3).

---

### V2b — `add the ivs vod player store`

**Goal:** a MobX store driving a VOD on the native player, with no UI yet.

**Files**
- CREATE `lib/screens/vod/vod_player_controller.dart`: `abstract class VodPlayerController`, the surface the VOD UI depends on, so the IVS and WebView engines are interchangeable:
  - `status` (`VodPlaybackStatus { loading, playing, paused, buffering, ended, failed, problem }`), `problem` (`VodPlaybackProblem?`)
  - `position`, `duration`, `buffered`, `positionSeconds` (computed int, so reactions fire at most once per second), `paused`, `ended`
  - `playbackRate`, `qualities`, `quality`, `muted`, `volume`, `overlayVisible`, `isInPipMode`
  - `play()`, `pause()`, `togglePlay()`, `seekTo(Duration)`, `seekBy(Duration)`, `setPlaybackRate(double)`, `setQuality(String)`, `toggleMute()`, `setVolume(double)`, `handleVideoTap()`, `showOverlay()`, `requestPictureInPicture()`, `onPipEntered()`, `onPipExited()`
  - `Future<void> ready`, `void Function()? onFatalError`, `Future<Duration?> currentPositionForSave()`, `dispose()`
- CREATE `lib/screens/vod/stores/ivs_vod_store.dart` `IvsVodStore = IvsVodStoreBase with _$IvsVodStore implements VodPlayerController`:
  - Constructor: `vodId`, `TwitchVodService`, `SettingsStore`, `Duration startAt`, `Duration? knownLength`, `@visibleForTesting IvsRecoveryPolicy?`.
  - Texture lifecycle: `create {config: IvsPlayerConfig.vodCreateArgs}` in parallel with `getVodUsherUrl`, then `load {url, startMs}`. Mirrors `IvsVideoStore._createTexture/_textureReady/_loadSource` including the dispose-during-create release.
  - Events:
    - `progress` → `_position`, `_buffered`, `_duration` (unknown → `knownLength`)
    - `duration`
    - `seeked` → clears `_seeking`
    - `state` → `PLAYING` → playing; `BUFFERING` → buffering; `READY`/`IDLE` → paused; `ENDED` → `_ended = true`, paused
    - `qualities` → `['Auto', ...list]`, restore via `pickInitialQuality` with the `last_stream_quality` prefs and `settingsStore.defaultToHighestQuality` (copy of the `_restoreQuality` generation logic), then re-send sound and rate
    - `quality`
    - `error`
  - Seek: `seekTo(target)` clamps to `[0, duration − 1 s]`, sets `_position` optimistically, sets `_seeking`, then invokes `seekTo {ms}`. `seekBy(±)` uses the current position. When `ended`, `play()` first seeks to 0.
  - Rate: allowed values `kVodPlaybackRates = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]`; others are ignored. Re-sent after every load.
  - Recovery: `classifyIvsError` then the reused `IvsRecoveryPolicy`.
    - `refreshToken` / `recoverable` → reload with a fresh URL at the **current position** (`load {url, startMs: position}`).
    - `offline` (`NOT_AVAILABLE`) → `diagnoseVodPlaylist(url)` → `status = problem` with `problem` set (subscriberOnly / geoBlocked / notFound / unknown). No WebView fallback, because the embed would fail too.
    - `fatal` or an exhausted budget → `onFatalError` (the screen swaps to the WebView engine in V4d).
    - The `_recoveryEpoch` guard is copied.
  - Overlay auto-hide timer (5 s, as live). It stays visible while paused or ended.
  - Auto-PiP autorun as in `ivs_video_store.dart:242`, but only while playing (`pip.setIsPlaying`). Disabled in `dispose`.
  - `currentPositionForSave()` → `invokeMethod<int>('getPosition')` with a fallback to `_position`.
- UPDATE `test/helpers/fake_ivs_native.dart` (additive only): `Future<void> emitProgress(int positionMs, {int? durationMs, int? bufferedMs})` and a configurable `getPosition` return value.

**Tests first** (`test/screens/vod/stores/ivs_vod_store_test.dart`, `MockTwitchVodService`, `FakeIvsNative`, the same `createStore`/`settle` helpers as the live test)
- Creates the player with `{'vod': true}` and loads the usher URL with `startMs` = startAt (0 and 1 234 000).
- `progress` events update the position, duration and buffered values; `positionSeconds` changes only on whole seconds.
- Unknown duration (−1, or a huge value) falls back to `knownLength`.
- Seeking:
  - `seekTo` clamps below 0 and past the end, sends `seekTo {ms}` and updates the position optimistically
  - `seekBy(+30 s)` near the end clamps
  - `seekBy(−10 s)` at 5 s → 0
- `setPlaybackRate(1.25)` sends `setPlaybackRate {rate: 1.25}`; `3.0` is ignored; the rate is re-sent after a reload.
- `ENDED` → `ended`; `play()` after the end seeks to 0 and then plays.
- Quality: restores the saved `last_stream_quality`, the highest when that setting is on, Auto by default; a user pick during the restore is not overridden.
- Mute and volume are re-sent after a load.
- A recoverable error reloads with a fresh token at the current position (`load.startMs` equals the last progress position).
- An authorization error forces a fresh token.
- `NOT_AVAILABLE` + diagnose `subscriberOnly` → `status == problem`, `problem == subscriberOnly`, no `onFatalError`.
- A fatal error → `onFatalError` called once.
- A burst of errors uses a single retry (epoch guard).
- Dispose:
  - dispose before create completes releases the texture
  - dispose before the URL resolves never loads
  - no reload after dispose
- `currentPositionForSave` returns the native position.

**Risks**
- Code duplication with `IvsVideoStore` (Medium maintainability). Mitigation: deliberate, to keep the heavily tested live store untouched. A follow-up ticket can extract a shared `IvsNativeSession` once E1 is stable.
- Event flood from 250 ms progress events. Mitigation: `positionSeconds` is a computed property, and only the seek bar observes the raw position.

**Acceptance:** tests green. The store is not reachable from the UI yet.

---

### V3 — `add vod chat replay store`

**Goal:** replay chat driven purely by playback position, rendered through the existing `IRCMessage` pipeline.

**Files**
- CREATE `lib/screens/vod/vod_comment_cache.dart` (pure Dart):
  - `bySecond: Map<int, List<VodComment>>`, `_covered: List<(int start, int end)>` (kept merged), `_seenKeys: Set<String>`.
  - `addPage({required int requestedSecond, required VodCommentPage page, required int videoLengthSeconds})`. Covered range = `[min(requested, minOffset), hasNext ? maxOffset − 1 : videoLength]`, because the last second may be cut mid-page. Edge cases:
    - empty page → `[requested, videoLength]`
    - all comments in one second with `hasNext` → `[requested, requested]` and `needsCursor = true`
  - `isCovered(int s)`, `firstUncoveredFrom(int s)`, `commentsIn(int fromExclusive, int toInclusive)`, `lastN(int second, int n)`.
  - `evictFarFrom(int s, {int keepSeconds = 1800, int maxComments = 20000})` for memory.
- CREATE `lib/screens/vod/vod_comment_to_irc.dart` (pure): `IRCMessage vodCommentToIrcMessage(VodComment c, {required String channelId, required String channelLogin, required DateTime vodCreatedAt, String? viewerLogin})`.
  - Builds a raw IRC line and calls the **unchanged** `IRCMessage.fromString` (zero edits to `irc.dart`, identical emoji, word, mention and `/me` handling).
  - Tags:
    - `badges=<setID/version,…>`
    - `color=<#RRGGBB>`: omitted when null, so live's grey default applies
    - `display-name`, `user-id`, `room-id=<channelId>`, `id=<comment id or key>`
    - `tmi-sent-ts=<vodCreatedAt + offset in ms>`
    - `emotes=<id:start-end,…/…>`
  - Message text: fragments concatenated, with `\r`/`\n` → space.
  - Emote ranges are computed in **UTF-16 code units** over the concatenated text, to match `fromString`'s `substring` (l.~1035).
  - Tag values are escaped: space → `\s`; `;`, `=` and backslash removed (display names never legitimately contain them).
  - Prefix `:<login>!<login>@<login>.tmi.twitch.tv PRIVMSG #<channelLogin> :`.
  - A null commenter renders as display name `Deleted user`, login `deleted_user`, no `user-id`; the replay widget disables the name tap.
- CREATE `lib/screens/vod/vod_replay_filters.dart` (pure): `bool isReplayCommentHidden(IRCMessage m, {required List<String> blockedLogins, required List<String> mutedWords, required bool matchWholeWord})`. Mirrors the live rule at `chat_store.dart:531-555`, without the live `return` bug that drops the whole batch. `ChatStore` is not touched.
- CREATE `lib/screens/vod/stores/vod_chat_replay_store.dart` `VodChatReplayStore`:
  - Inputs: `vodId`, `Vod meta` (owner id/login, createdAt, length, type), `TwitchVodService`, `ChatAssetsStore` (created and owned here: `init()` then `assetsFuture(channelId: ownerId, headers: auth.headersTwitch, show* from settings)`), `AuthStore`, `SettingsStore`.
  - Observables:
    - `status` (`ReplayStatus { loading, active, empty, unavailable, notApplicable }`)
    - `messages` (`ObservableList<IRCMessage>`, capped at 300 with 20% purges as on live)
    - `autoScroll` and `scrollController` (same semantics as `chat_store.dart:409-416` and `resumeScroll()`)
  - `@action void onPositionSecond(int s)`:
    - **Forward tick** (`0 < s − last ≤ 3`): append `commentsIn(last, s)` through the filter and the converter (memoised by key).
    - **Seek** (backwards, or a jump over 3 s): clear `messages`, then fill with `lastN(s, 50)` when covered; otherwise show the loading state and fetch.
    - **Prefetch:** when `firstUncoveredFrom(s) − s < lead` with `lead = 15 s × playbackRate` and no fetch is in flight, fetch at that second.
    - **Backfill:** when a fetch for second F lands and the current second ≥ F, append the comments in `[F, current]` not yet shown (tracked by key).
    - A generation counter drops stale results during rapid seeks; the results are still cached.
  - Fetching:
    - `getComments(offset)`; if `needsCursor`, try `getCommentsAfter(cursor)` once; on failure mark the second covered (accepting the loss).
    - Transient errors: backoff 1/2/4 s, then wait for the next seek.
    - `VodApiException.isIntegrity`, or 3 consecutive failures → `status = unavailable` (sticky for the session).
    - `Vod.type == upload` → `notApplicable`, no network.
  - No IRC connection, no 7TV EventAPI, no sending.
  - `dispose()` disposes `assetsStore` (after `init()`) and the scroll controller.

**Tests first**
- `test/screens/vod/vod_comment_cache_test.dart`:
  - range merge and overlap
  - `hasNext` cut-second rule
  - empty page covers to the end
  - single-second page sets `needsCursor`
  - dedupe by key across overlapping pages
  - `commentsIn` boundaries (exclusive/inclusive)
  - `lastN`
  - `evictFarFrom` keeps the window
- `test/screens/vod/vod_comment_to_irc_test.dart` (round-trip through `IRCMessage.fromString`):
  - plain text → `message`, `user`, `display-name`, `color`
  - badges map to `subscriber/12,moderator/1` and render keys that exist in `twitchBadgesToObject`
  - a Twitch emote fragment → `localEmotes['Kappa']` with the `static-cdn …/<id>/default/dark/3.0` URL
  - **an emoji before an emote** → the correct word (UTF-16 ranges)
  - repeated emote → both ranges
  - a 7TV word (no emote fragment) stays a plain word in `split`, so `generateSpan` resolves it from `assetsStore.emoteToObject`
  - null colour → no `color` tag
  - newline stripped
  - a display name with a space is escaped
  - deleted user
  - `tmi-sent-ts` = createdAt + offset
  - a mention of `viewerLogin` sets `mention`
- `test/screens/vod/vod_replay_filters_test.dart`: blocked login hidden; muted word, whole-word on and off; case-insensitive.
- `test/screens/vod/stores/vod_chat_replay_store_test.dart` (mocktail `MockTwitchVodService`, a mock or fake `ChatAssetsStore` that stubs `init`/`assetsFuture`):
  - the first tick fetches at 0
  - ticks 1..10 append only that second's comments, in order
  - no duplicate fetch while one is in flight
  - prefetch fires before the covered end, and the lead scales with rate
  - a seek forward into an uncovered range clears, shows loading, fetches at the target, then shows `lastN`
  - a seek back into a covered range serves from cache without network
  - a late fetch backfills comments up to the current second
  - a stale fetch after a newer seek does not reorder messages
  - an integrity error → `unavailable` and no further fetches
  - 3 transient failures → `unavailable`; retry resets it
  - upload → `notApplicable`, zero calls
  - the cap keeps at most 300 messages
  - blocked users are filtered
  - dispose stops timers

**Risks**
- Anonymous comments get integrity-gated later (Medium). Mitigation: sticky `unavailable` state; the pane collapses and video is unaffected.
- 7TV, BTTV and FFZ emotes are the channel's **current** sets, not the sets at broadcast time. This is a known limitation shared by every third-party client (no history API); document it in the UI tooltip and the docs.
- Busy seconds with more than 50 comments (Low). Mitigation: the cursor attempt, then accept the loss.
- `ChatAssetsStore.dispose()` without `init()` throws (Low). Mitigation: always call `init()` in the constructor; there is a test for it.

**Acceptance:** tests green. `irc.dart`, `chat_store.dart` and `chat_assets_store.dart` are unchanged (`git diff --stat` shows no lines for them).

---

### V4a — `extract shared video overlay helpers`

**Goal:** let the VOD overlay reuse the live overlay's visuals and orientation logic without duplication. This is a mechanical, behaviour-preserving move.

**Files**
- CREATE `lib/screens/channel/video/overlay_common.dart`:
  - `BoxDecoration overlayGradient({required bool fromTop})` (moved from `VideoOverlay._overlayGradient`)
  - `Future<void> enterLandscape()` and `void exitToPortrait()` (moved from `video_overlay.dart:52-82`)
  - `Widget overlayIconButton({...})` (icon with `kOverlayShadow` in `overlayOnSurface`, used by both overlays)
  - `Widget buildVolumeSection(...)`: the volume row from the settings sheet, parameterised by `muted`, `volume`, `toggleMute` and `setVolume` instead of `IvsVideoStore`
- UPDATE `lib/screens/channel/video/video_overlay.dart`: call the extracted functions. No visual change.

**Tests first:** `test/screens/channel/video/overlay_common_test.dart` (widget test): `overlayGradient` stops and colours equal the previous constants; the volume section shows the mute icon state and calls back. Existing tests stay green.

**Risks:** live overlay regression (Low). Mitigation: pure move; manual check of R5 (landscape, fullscreen, rotate).

**Acceptance:** live overlay pixel-identical (manual), analyze and test green.

---

### V4b — `pause the other player while a vod or stream takes over`

**Goal:** exactly one audible player. Opening a VOD from a live channel (overlay, user card, chat link) pauses the live stream beneath, and coming back resumes it. Opening a live channel from a VOD pauses the VOD.

**Files**
- CREATE `lib/services/playback_focus.dart`: `class PlaybackFocus { static final shared = PlaybackFocus(); Object? register(Object owner, {required VoidCallback onLost, required VoidCallback onRegained}); void claim(Object owner); void release(Object owner); }`. The owners form a stack; claiming calls `onLost` on the previous top, and releasing calls `onRegained` on the new top. It is pure Dart.
- UPDATE `lib/screens/channel/channel.dart` (CRLF file, edit carefully):
  - `initState`: `PlaybackFocus.shared.register(this, onLost: _pauseForOtherPlayer, onRegained: _resumeAfterOtherPlayer)` and `claim(this)`.
  - `dispose`: `release(this)`, unless the player was handed off to the mini window; in that case also release.
  - `_pauseForOtherPlayer` remembers `wasPlaying = !_videoStore.paused` and calls `handlePausePlay()` if playing.
  - `_resumeAfterOtherPlayer` resumes when it was playing, and re-asserts auto-PiP and the wakelock (`if (settingsStore.keepScreenAwake) WakelockPlus.enable()`), because the VOD screen's dispose may have turned them off.
- UPDATE `lib/screens/channel/video/stores/ivs_video_store.dart`: add a public `void reassertAutoPip()` that re-runs the auto-PiP decision. Additive.

**Tests first:** `test/services/playback_focus_test.dart`:
- claim pauses the previous owner
- release resumes the new top
- release of a non-top owner does not call callbacks
- double claim is idempotent
- unknown owner is a no-op

**Risks**
- Pausing live on unrelated routes (Medium). Mitigation: only explicit `claim` calls from player screens; bottom sheets and dialogs never claim.
- Live chat delay sync after the pause (Low): IVS latency grows during the pause, then speed-up catch-up handles it.

**Acceptance:** live → open VOD (in V4c) → live silent → back → live resumes. Mini player behaviour unchanged (R3).

---

### V4c — `add the vod player screen`

**Goal:** the in-app VOD theatre (IVS engine) with replay chat, in ONSET style.

**Files**
- CREATE `lib/screens/vod/vod_time.dart` (pure):
  - `String formatVodTime(Duration d)` → `M:SS` under 1 h, otherwise `H:MM:SS`
  - `String formatVodTimeForShare(Duration)` → `1h2m3s`
  - `Duration? parseTwitchTimestamp(String raw)`: accepts `1h2m3s`, `01h02m03s`, `2m3s`, `3s`, `90`, `1h`, and leniently `5m`; invalid → null
- CREATE `lib/screens/vod/vod_screen.dart` `VodScreen({required String vodId, Vod? vod, Duration? startAt})`, `routeName = 'VodScreen'`, plus a static `Future<void> open(BuildContext, …)` helper:
  - `initState`:
    - `context.miniPlayerStore.close()`, the same rule as `channel.dart:165`
    - `PlaybackFocus.shared.register/claim`
    - wakelock on (`keepScreenAwake`)
    - resolve metadata: use `vod`, or `getVideo(id)` → not found → `VodErrorView(notFound)`
    - build the engine: `resolvePlayerEngine(setting, isAndroid, forceWeb)` → IVS → `IvsVodStore`, else `WebVodStore` (V4d; until then, a "VOD playback needs the native player" `AlertMessage`)
    - create `VodChatReplayStore`
    - `reaction((_) => player.positionSeconds, replay.onPositionSecond)`
    - `reaction((_) => player.playbackRate, replay.setRate)`
  - Fallback wiring: `onFatalError` or a `ready` failure → rebuild with `forceWeb: true`, the same pattern as `channel.dart:165-177`.
  - Lifecycle: `didChangeAppLifecycleState(paused)` hooks the resume save (V6).
  - `dispose`: reactions, stores, `release`, `SystemChrome` restore, orientations reset, wakelock off only if no other focus owner remains.
  - `PipWidget(pipLayout: PipActionsLayout.mediaOnlyPause, onPipAction: togglePlay, pipChild: playerWidget)` on Android.
- CREATE `lib/screens/vod/vod_layout.dart`:
  - Portrait: `SafeArea` → 16:9 player on top, then a `Column` with an info strip and the replay pane, mirroring `channel.dart`'s structure.
  - Landscape (`!landscapeForceVerticalChat`): immersive system UI. A `Row` with a side chat column sized `settingsStore.chatWidth`, on the side given by `landscapeChatLeftSide`, with `DraggableDivider` (maxWidth 0.6). When `settingsStore.fullScreen`, the chat is an overlay with `fullScreenChatOverlayOpacity`, toggled with the chat button.
  - Reuses the same `SettingsStore` fields as live, so preferences are shared.
  - The replay pane is hidden in landscape when the status is `unavailable` or `notApplicable`, and the video then expands.
  - Swipe-down on the player enters system PiP (no in-app VOD mini player in E1).
- CREATE `lib/screens/vod/vod_overlay.dart` (ONSET):
  - Top row: back, title, and owner `ProfilePicture` + name (tap opens the live `VideoChat` for the owner, which claims focus), settings button, chat overlay button in landscape fullscreen.
  - Centre: `replay_10_rounded` / big play-pause / `forward_30_rounded`, with `kOverlayShadow` icons in `overlayOnSurface`. Ended → replay icon.
  - Bottom: `VodSeekBar`, then `elapsed / duration` in tabular figures, speed chip (`1.25×`, the same chip style as the StreamCard uptime chip), mute, PiP, rotate/fullscreen (via V4a helpers).
  - Double-tap gestures: left third = −10 s, right third = +10 s, each with a ripple badge "−10 s"/"+10 s"; centre in landscape = cycle chat mode, as live.
  - Gradients from `overlayGradient`. Auto-hide follows `overlayVisible`, but stays shown while paused or ended.
  - The settings sheet reuses the live sheet structure: `SectionHeader('Quality')` with check tiles (writes `last_stream_quality` like live), `SectionHeader('Volume')` via `buildVolumeSection`, `SectionHeader('Playback speed')` with 7 tiles, and a "Copy link at current time" tile (`twitch.tv/videos/<id>?t=…`, clipboard only).
- CREATE `lib/screens/vod/widgets/vod_seek_bar.dart`:
  - Custom painter or `SliderTheme`: track 3 dp, buffered segment at 40% alpha, played in `colorScheme.primary`, muted segments drawn as `frostyColors.followersOnly` ticks above the track (from `getMutedSegments`, loaded lazily, empty on error).
  - Thumb grows from 6 to 8 on drag.
  - While dragging, local state only; a time bubble shows the target. `seekTo` is called once on release.
  - Semantics labels "Elapsed time", "Seek".
- CREATE `lib/screens/vod/widgets/vod_chat_replay.dart`:
  - `SectionHeader('Chat replay')`-style slim header with a tooltip ("Third-party emotes reflect the channel's current sets").
  - A `ListView.builder(reverse: true)` of `VodChatMessage`, wrapped like `chat.dart`: `MediaQuery` textScaler `settings.messageScale`, `DefaultTextStyle` `fontSize`, `FrostyScrollbar`.
  - A "Resume auto-scroll" pill with the same look as live `_buildResumeScrollButton`.
  - States:
    - loading → `LoadingIndicator(subtitle: 'Loading chat replay')`
    - empty → `AlertMessage('No messages yet')`
    - unavailable → `AlertMessage('Chat replay is unavailable for this video', trailingIcon: refresh)`
    - notApplicable → `AlertMessage('Uploads have no chat replay')`
- CREATE `lib/screens/vod/widgets/vod_chat_message.dart`:
  - `Padding(vertical: settings.messageSpacing / 2)` + divider when `showChatMessageDividers`.
  - `Text.rich(TextSpan(children: ircMessage.generateSpan(context, style, assetsStore, emoteScale, badgeScale, launchExternal, timestamp: settings.timestampType)))`.
  - Emote and badge taps use the existing detail sheets built into `generateSpan`. Long-press copies the text, with an `ScaffoldMessenger` notice in ONSET style.
  - Name tap opens a small sheet: `ProfilePicture`, name, "Videos" (V5a), "Open channel".
- CREATE `lib/screens/vod/widgets/vod_error_view.dart`: one `AlertMessage` per `VodPlaybackProblem`:
  - subscriberOnly → "This video is for subscribers only"
  - geoBlocked → "Not available in your region"
  - notFound → "This video is no longer available"
  - unknown → "Couldn't play this video" with a Retry action
  
  Never a browser fallback.
- CREATE `lib/screens/vod/widgets/vod_info_strip.dart` (portrait, under the player): title (2 lines), "3 days ago · 12,345 views · Category" (category tap opens `CategoryStreams` as `StreamInfoBar` does), and a "Recording" chip when `isRecording`.

**Tests first**
- `test/screens/vod/vod_time_test.dart`:
  - format 0, 59 s, 1:00, 59:59, 1:00:00, 10:00:00
  - share format
  - parse all accepted forms, zero padding, whitespace, `5m` → 300 s, invalid strings (`abc`, `1x`, `-5`, empty) → null, huge values clamp or reject
- `test/screens/vod/widgets/vod_seek_bar_test.dart` (widget):
  - dragging does not call `onSeek` until release; release calls it once with the dragged value
  - labels render `formatVodTime`
  - muted segments painted count
  - a duration of 0 shows a disabled bar
- `test/screens/vod/widgets/vod_chat_message_test.dart` (widget, a fake `ChatAssetsStore` with one 7TV emote): a converted comment renders a `WidgetSpan` for the 7TV word and the Twitch emote, coloured name text, badge spans.
- `test/screens/vod/widgets/vod_chat_replay_test.dart`: each status renders the matching `AlertMessage` or `LoadingIndicator`; tapping the pill calls `resumeScroll`.

**Risks**
- Layout duplication with `channel.dart` (Medium maintainability). Mitigation: a deliberately smaller `VodLayout`; a later ticket can unify it into a shared `PlayerChatLayout`. Live `channel.dart` stays untouched apart from V4b.
- Shared `SettingsStore.fullScreen*` flags (Low): intended, so preferences carry over.
- PiP `PipWidget` instances in the stack (Low): only the top opaque route paints. The `onPipEntered` of a paused live screen beneath is harmless.
- Wakelock or auto-PiP turned off for the live screen beneath (Low). Mitigation: re-asserted in V4b `onRegained`.

**Acceptance (device)**
- A VOD opened from a temporary debug entry plays with chat replay; emotes from all providers render.
- Seek, ±10/30 s and speed work, and the chat follows a seek within 2 s.
- Landscape side chat and the fullscreen overlay work; PiP works.
- Pressing back returns, and live resumes when it came from live.

---

### V4d — `play vods in the twitch web player when ivs is unavailable`

**Goal:** honour CLAUDE.md "degrade gracefully". iOS, a forced web engine, or an IVS fatal error still play **in-app**.

**Files**
- CREATE `lib/screens/vod/stores/web_vod_store.dart` `WebVodStore implements VodPlayerController`:
  - `WebViewController` loading `https://player.twitch.tv/?video=v<id>&time=<1h2m3s>&autoplay=true&muted=false&parent=frosty`, with the same platform params as `video_store.dart:220-238` (iOS inline playback, Android `setMediaPlaybackRequiresUserGesture(false)`).
  - A 1 s JS poll: `document.querySelector('video')` → `currentTime`, `duration`, `paused`, `playbackRate` → `JavaScriptChannel('VodState')` → observables.
  - `seekTo`, `play`, `pause` and `setPlaybackRate` via `runJavaScript` on the `<video>` element.
  - Qualities: `['Auto']` only (the Twitch embed controls remain usable).
  - Overlay: the custom VOD overlay sits on top. A long-press toggles to the Twitch controls, as live.
- CREATE `lib/screens/vod/web_vod.dart`: `WebViewWidget` host.
- UPDATE `lib/screens/vod/vod_screen.dart`: build `WebVodStore` when the engine resolves to web.

**Tests first:** `test/screens/vod/stores/web_vod_store_test.dart`:
- URL builder: id normalised; `time` formatted; no `time` when the start is 0
- `onStateMessage(json)` parsing: position, duration, paused; NaN/Infinity duration → unknown
- seek/rate JS strings are built from clamped numbers only (no string interpolation of untrusted data)

`WebViewController` is mocked via `mocktail`.

**Risks:** embed DOM changes (Medium). Mitigation: only the standard `<video>` element is used, and replay simply stops following if polling fails.

**Acceptance:** with the setting on "Twitch web", or on iOS, a VOD plays in-app and the replay follows within about 1–2 s.

---

### V5a — `add the channel videos list and entry points`

**Goal:** browse a channel's past broadcasts, highlights and uploads from everywhere a channel appears.

**Files**
- CREATE `lib/screens/vod/stores/channel_videos_store.dart` `ChannelVideosStore`:
  - per `VodType`: `ObservableList<Vod> videos`, `_cursor`, `_hasNextPage`, `isLoading`, `_error`, `hasMore` computed
  - `fetchMore()` guarded against concurrent calls, `refresh()`, `ScrollController` with load-more at 80% (the `stream_list_store` pattern)
  - page size 20
- CREATE `lib/screens/vod/channel_videos.dart` `ChannelVideosScreen({userId, userLogin, displayName, VodType initialTab = archive})`:
  - `FrostyAppBar(title: '<name> · Videos')`
  - `FrostyPageView(headers: ['Past broadcasts', 'Highlights', 'Uploads'])`, one store per tab, created lazily
  - `RefreshIndicator`, `ScrollToTopButton`
  - skeleton `StreamCardSkeletonLoader` ×6 while loading
  - `AlertMessage('No past broadcasts')` etc. when empty
  - error → `AlertMessage(message, trailingIcon: Icons.refresh_rounded)`
- CREATE `lib/screens/vod/widgets/vod_card.dart` (mirrors `StreamCard` sizes):
  - thumbnail with `%{width}x%{height}` / `-320x180` replacement as needed and a `SkeletonLoader` placeholder
  - processing or missing thumbnail → `ColoredBox(surfaceContainer)` + `Icons.video_library_outlined`
  - duration chip at the bottom right (chip style copied from the uptime chip)
  - "Recording" chip at the top left in `colorScheme.error`
  - lock icon chip + "Subscribers only" subtitle when `isRestricted`
  - title, `relative date · views · category`
  - resume progress bar slot (filled in V6)
  - tap → `VodScreen.open(context, vodId: v.id, vod: v)`; long-press → photo-view of the thumbnail (as StreamCard)
- Entry points (additive UI):
  - `video_overlay.dart`: a `Videos` `IconButton(Icons.video_library_outlined)` in both the live and offline top rows, plus an offline pill "Past broadcasts" (FilledButton.tonal, rounded pill as ONSET fields) under the offline `StreamInfoBar` → `ChannelVideosScreen(initialTab: archive)`. Navigation from the overlay of a live stream: the pushed list does not claim focus (the live stream keeps playing until a VOD is opened).
  - `channel.dart` chat-only `AppBar`: an `actions: [Videos button]`.
  - `chat_user_modal.dart`: a trailing `IconButton(tooltip: 'Videos', icon: Icons.video_library_outlined)` → `ChannelVideosScreen(userId, userLogin: username, displayName)`.
  - `widgets/user_actions_modal.dart`: a `ListTile(leading: Icons.video_library_outlined, title: 'Videos')`. This covers the long-press on live and offline followed cards and search results.

**Tests first**
- `test/screens/vod/stores/channel_videos_store_test.dart`:
  - the first page loads, and `hasMore` follows `hasNextPage`
  - `fetchMore` appends with the cursor
  - concurrent `fetchMore` → one request
  - error sets `error` and keeps the items
  - `refresh` clears and refetches
  - empty list
  - `NotFound` → error message
- `test/screens/vod/widgets/vod_card_test.dart`: duration chip text; Recording chip; restricted lock; tap calls the open callback (injectable `onTap` for the test).

**Risks**
- UI clutter in the live overlay (Low). Mitigation: a single icon; the offline pill shows only offline.
- Double audio when a live stream plays under the list and the user opens a VOD (Medium). Mitigation: V4b focus pauses live.

**Acceptance:** each entry point opens the list; the tabs paginate to the end; tapping a card plays in-app.

---

### V5b — `open twitch vod links in the app`

**Goal:** `twitch.tv/videos/<id>`, `/v/<id>`, `/<channel>/v/<id>` and `/<channel>/video/<id>` (legacy), with `?t=`, plus `/<channel>/videos[?filter=archives|highlights|uploads]` open in-app from Android App Links and from chat (live and replay).

**Files**
- CREATE `lib/utils/twitch_links.dart` (pure): `sealed class TwitchLink` with `VodLink(String vodId, Duration? startAt)`, `ChannelVideosLink(String login, VodType? type)`, `ChannelLink(String login)` and `OtherLink`. `static TwitchLink parse(Uri uri)`:
  - Hosts `twitch.tv`, `www.twitch.tv`, `m.twitch.tv`. A scheme-less text (`twitch.tv/videos/1`) is normalised by prefixing `https://`.
  - Ids are validated with `^\d{1,20}$` (else `OtherLink`). `t` goes through `parseTwitchTimestamp`.
  - Reserved first segments (`videos`, `v`, `directory`, `settings`, `search`, `p`, `downloads`, `jobs`, `turbo`, `subscriptions`, `wallet`, `inventory`, `drops`, `friends`, `messages`, `following`) never become a `ChannelLink`.
- CREATE `lib/utils/link_router.dart`: `class LinkRouter { static Future<bool> Function(TwitchLink link)? inAppHandler; static Future<void> open(Uri uri, {required bool launchExternal}) }`.
  - It routes `VodLink` and `ChannelVideosLink` in-app when a handler is set; everything else goes to `launchUrl` exactly as before.
  - VOD links ignore `launchUrlExternal` (requirement: never the browser for VODs).
  - Channel links keep the current behaviour (decision to confirm).
- UPDATE `lib/models/irc.dart:843`: `..onTap = () => LinkRouter.open(Uri.parse(text), launchExternal: launchExternal)`. This is the only line changed in `irc.dart`.
- UPDATE `lib/main.dart`:
  - `initState`: `LinkRouter.inAppHandler = _openTwitchLinkInApp`.
  - `handleDeepLink`: `switch (TwitchLink.parse(uri))`:
    - `VodLink` → `navigatorKey.currentState?.push(VodScreen route(vodId, startAt))`
    - `ChannelVideosLink` → `getUser(login)` → `ChannelVideosScreen`
    - otherwise → the **existing code unchanged** (channel → `VideoChat`, failure snackbar)
  - The snackbar fallback for VOD failures offers Retry only, no browser action.
- No manifest change: the existing `twitch.tv` / `www.` / `m.` App Link filter already covers these paths. A `twitch://video/<id>` custom scheme is optional (needs a manifest edit) and deferred.

**Tests first**
- `test/utils/twitch_links_test.dart`:
  - `https://www.twitch.tv/videos/123456789` → `VodLink('123456789', null)`
  - `?t=1h2m3s` → 3723 s; `?t=01h02m03s`; `?t=90` → 90 s; `?t=5m` → 300 s; invalid `t` → null start
  - `m.twitch.tv/videos/1`, `twitch.tv/v/1`, `twitch.tv/somechannel/v/1`, `twitch.tv/somechannel/video/1`
  - scheme-less `twitch.tv/videos/1`
  - `twitch.tv/videos/abc` → `OtherLink`
  - `twitch.tv/videos/../../x` → `OtherLink`
  - `twitch.tv/somechannel/videos?filter=highlights` → `ChannelVideosLink(type: highlight)`; `/videos/archive` → archive
  - `twitch.tv/somechannel` → `ChannelLink`
  - `twitch.tv/directory/game/x` → `OtherLink`
  - `evil.com/videos/1` → `OtherLink`
  - trailing slash and uppercase host
- `test/utils/link_router_test.dart`:
  - a VOD link with a handler → the handler is called and `launchUrl` is not (inject a launcher function for the test)
  - a VOD link without a handler → launcher (pre-init edge)
  - a non-Twitch link → launcher with the right mode for `launchExternal` true and false

**Risks**
- Deep-link regression for channels (Medium). Mitigation: the channel branch is untouched; parser tests cover reserved words; manual R8.
- `regexLink` matches with trailing punctuation (Low). Mitigation: the parser trims `.,!?)`.

**Acceptance:**
- `adb shell am start -a android.intent.action.VIEW -d "https://www.twitch.tv/videos/<id>?t=1h2m3s"` opens the VOD at 1:02:03 in-app.
- A VOD link tapped in live chat and in replay chat opens in-app.
- Channel links behave as before.

---

### V6 — `remember vod watch position locally`

**Goal:** resume where the user stopped, and show "continue watching" progress on lists.

**Files**
- CREATE `lib/screens/vod/vod_resume.dart`: `class VodResumeRepository`, built over `SharedPreferences`, with one JSON key `vod_resume_v1` holding `{vodId: {p: positionSec, l: lengthSec, u: updatedAtMs}}`. LRU cap of 300 entries; corrupted JSON resets.
  - `Future<int?> position(String id)` and `Future<Map<String,(int,int)>> snapshot()`, read once per list screen.
  - `Future<void> save(String id, {required int positionSec, required int lengthSec})`: positions under 30 s are not saved; a position at or past `length − 30 s` removes the entry (finished).
  - Pure `Duration startPositionFor({int? saved, Duration? deepLink, required int length})`: the deep link wins; otherwise `max(0, saved − 30)`; finished → 0.
  - Pure `bool isWatched(int position, int length)` (heuristic from RE notes §2.6, used for the "Watched" label).
- UPDATE `lib/screens/vod/vod_screen.dart`:
  - The start position comes from `startPositionFor`.
  - A periodic 20 s timer runs while `status == playing`.
  - Saves on pause (reaction on `paused`), on `AppLifecycleState.paused`, and in `dispose` (fire-and-forget with `currentPositionForSave()`, falling back to the last known position synchronously).
- UPDATE `lib/screens/vod/widgets/vod_card.dart`: a 3 dp `LinearProgressIndicator`-style bar at the bottom of the thumbnail (`primary` on `overlayOnSurface` at 30% alpha) when a saved position exists, plus a "Watched" chip when finished. `ChannelVideosScreen` loads `snapshot()` once and refreshes it on return (`await Navigator.push` → `setState`).
- Server-side resume (`viewingHistory` / `UpdateUserViewedVideo`) needs a user GQL session and is **out of E1** (roadmap E9 decision).

**Tests first**
- `test/screens/vod/vod_resume_test.dart`:
  - save then read
  - under 30 s not saved
  - near the end removes the entry
  - LRU evicts the oldest past 300
  - corrupted prefs → empty
  - `startPositionFor`: deep link wins, minus 30 s, clamp at 0, finished → 0
  - `isWatched` thresholds (under 300 s length, under 3000 s length, 10% rule)
- `test/screens/vod/vod_screen_resume_test.dart` (unit-level via an extracted `VodResumeController` taking a fake clock and a `VodPlayerController` fake):
  - saves every 20 s only while playing
  - saves on pause
  - saves on lifecycle paused
  - the dispose save uses the native position

**Risks:** SharedPreferences writes every 20 s (Low): one small JSON write each time.

**Acceptance:** watch to 10:00, back out, reopen → starts at 9:30. A deep link with `?t=` overrides the saved position. The card shows the progress bar.

---

### V7 — `update gap and architecture docs for vods`

- `docs/GAP.md`:
  - PRF-07/08/09/10/11 ✅
  - PRF-12 ✅ (anonymous comments verified; the integrity note is obsolete)
  - PRF-14 ⚠️ (overlay drawn when the optional query works)
  - PRF-15 ⚠️ (paywall state only)
  - MSC-01 ⚠️ (VOD links done; clips in E2)
  - PRF-16 ❌ (see decisions)
- `docs/ARCHITECTURE.md`: a VOD section (service, stores, native VOD mode, replay pipeline, PlaybackFocus).
- `docs/plans/roadmap.md`: mark E1 done.

---

## Testing Strategy

- **Pure units:**
  - `vod_time`, `twitch_links`, `vod_comment_cache`, `vod_comment_to_irc` (round trip through the real `IRCMessage.fromString`)
  - `vod_replay_filters`, `vod_resume`, `playback_focus`
  - models, `vodUsherQueryParameters`, `normalizeVodId`, `IvsPlayerConfig.vodCreateArgs`
- **Service tests:** `DioAdapter` with full URLs and captured fixtures in `test/fixtures/vod_responses.dart`.
- **Store tests:**
  - `IvsVodStore` (`FakeIvsNative` + `MockTwitchVodService`)
  - `VodChatReplayStore` (`MockTwitchVodService` + stubbed `ChatAssetsStore`)
  - `ChannelVideosStore`, `WebVodStore` (mocked `WebViewController`)
- **Widget tests:** seek bar, chat replay states, replay message rendering, VOD card, overlay helpers.
- **Unchanged suites must stay green:** `ivs_video_store_test.dart` (~70 tests), `irc_test.dart`, `twitch_stream_service_test.dart`, `settings_store_test.dart`, etc.
- **Validation per commit:**
  ```bash
  flutter pub get
  dart run build_runner build --delete-conflicting-outputs   # V2b, V3, V5a stores
  flutter analyze
  flutter test
  flutter build apk --debug --dart-define=CLIENT_ID=<id> --dart-define=SECRET=<secret>
  ```
- **Reviews before each commit is considered done:** `flutter-reviewer` + `kotlin-reviewer` (V2a), plus a `security-review` focused on tokens, URL building and link routing (V1, V2b, V5b).

## Regression checklist (device, after every commit from V2a on; live items from `low-latency-player.plan.md` extended)

1. **R1** Live on IVS: chat connected; 7TV, BTTV and FFZ emotes; a 7TV live emote add/remove notice appears.
2. **R2** Latency badge to 0.1 s; stats panel (latency median, buffer, bitrate, `lowLatency: true`); auto chat delay "(Ns delay)" is whole seconds near the latency.
3. **R3** Mini player: swipe down → mini, no reload; restore → same player, chat history kept; opening another channel closes the mini.
4. **R4** PiP: auto-PiP on Home, the PiP button, the pause action in PiP; live and VOD each separately.
5. **R5** Landscape: fit/fill (tablet button), chat column and overlay cycle (double-tap centre), fullscreen, rotate, divider drag.
6. **R6** WebView engine selectable; forced fallback (airplane mode for 20 s on IVS) still launches; on iOS the web engine plays live and VODs.
7. **R7** Offline channel: offline bar, no infinite spinner, new "Past broadcasts" pill works.
8. **R8** Deep link `twitch.tv/<channel>` still opens `VideoChat`; an unknown link shows the snackbar.
9. **R9** Moderation rendering (deleted message reveal, timeout/ban headers) unchanged in live chat.
10. **R10** Chat links: non-Twitch links follow the "open links externally" setting exactly as before.
11. **R11** Live → open VOD → live paused (no double audio) → back → live resumes, latency recovers by speed-up within about 10 s.
12. **R12** 2K check: an enhanced-broadcasting channel still lists 1440p on live, and VOD qualities include the source rendition (AV1/HEVC when present).

## Manual test protocol (VOD-specific, real Android phone, release build)

- **M1 Lists:** three channels (A big partner, B mid, C with uploads and highlights).
  - Each tab paginates to the end and the empty states show.
  - Recording VOD chip on a currently live channel.
  - Sub-only VOD shows the lock.
- **M2 Playback start:** open five VODs from the list; measure time to first frame (stopwatch or `adb logcat -s FrostyIVS flutter`); default quality restore matches the saved quality.
- **M3 Transport:**
  - −10 s and +30 s at the start and end edges
  - scrub to 75%
  - double-tap seek on both sides
  - speed 0.5×…2.0× (audio pitch preserved, replay follows)
  - pause/resume
  - end of video → replay
- **M4 Recording VOD (channel live now):** plays from the start, the seek bar uses `lengthSeconds`, seeking near the live edge does not crash, duration grows or stays sane.
- **M5 Chat replay:**
  - messages appear in time with on-screen events (compare against twitch.tv at the same timestamp)
  - 7TV, BTTV and FFZ emotes, sub/mod/VIP badges, FFZ custom mod badge, name colours
  - seek forward 1 h → chat repopulates within 2 s
  - seek back → instant from cache
  - scroll up → auto-scroll pauses and the pill resumes it
  - an upload → "no chat replay"
  - airplane mode mid-replay → unavailable state, video continues from buffer, retry after reconnect
- **M6 Errors:** sub-only VOD (anonymous) → paywall message, no browser; a deleted VOD id via deep link → not-found view; force IVS failure (Settings → web engine) → in-app embed plays with replay.
- **M7 Layout:** portrait/landscape rotation mid-playback keeps the position; side chat left/right; fullscreen overlay chat opacity; PiP from VOD; system back from PiP.
- **M8 Links:**
  - `adb` App Link for `/videos/<id>?t=1h2m3s`, `/v/<id>`, `/<channel>/v/<id>?t=90`, `/<channel>/videos?filter=highlights`
  - the same URLs pasted in a live chat message and tapped; a VOD link inside replay chat
- **M9 Resume:** watch to 10:00, back, reopen → 9:30; kill the app at 15:00 (background first) → reopen at about 14:30; watch the last 20 s → card shows "Watched" and reopening starts at 0; a `?t=` link overrides.
- **M10 Focus and audio:** live → VOD (live silent) → owner avatar → live of the same channel (VOD paused) → back twice → each player resumes correctly; the mini player is closed when a VOD opens.

## Risks & Mitigations (cross-cutting)

- **Twitch GQL or usher change, or integrity gating** (Medium). Typed exceptions, a sticky "unavailable" replay state, the in-app WebView fallback for playback, and no impact on live (separate service and token cache).
- **Token leakage** (High impact, Low likelihood):
  - usher URLs only go to the native player, a dedicated Dio and the raw diagnose call
  - never `debugPrint`ed, never in Crashlytics (the BaseApiClient error path is avoided for usher), never through the shared Dio's Firebase Performance interceptor
  - tokens are never persisted
- **Live regression** (High impact). Native changes are gated by `vod`, `TwitchStreamService` is untouched, the `IRCMessage` parser is untouched (a single `onTap` line changes), `ChatStore` is untouched, and the R1–R12 checklist runs per commit.
- **Memory on long VODs with heavy chat.** Cache eviction (window of 30 min, at most 20k comments) and a visible cap of 300.
- **iOS.** No native VOD; `resolvePlayerEngine` selects `WebVodStore`. Every Android-only call sits behind `Platform.isAndroid`, as on live.
- **CRLF files** (`channel.dart`, `AndroidManifest.xml`, `pubspec.yaml`, `auth_store.dart`). Preserve line endings to avoid whole-file diffs; the `dart format` hook runs on each edit.

## Decisions to confirm (defaults the plan applies unless told otherwise)

1. **Replay timestamps** show the broadcast wall-clock time (`createdAt + offset`, reusing `_addTimestamp`), not the VOD-relative "1:02:03". Changing this needs an `irc.dart` tweak.
2. **Opening a VOD while a live stream plays:** the live stream is **paused** (and resumed on return). It is not closed. Opening a VOD **closes** the in-app mini player, the same rule as opening a channel.
3. **No in-app mini player for VODs in E1.** Swipe-down enters system PiP. A follow-up (V8) can generalise `MiniPlayerStore` to `VodPlayerController`.
4. **PRF-16 "videos of followed channels"** (listed under E1 in the roadmap) is **deferred**: it needs either a user GQL session (`followedVideos`) or N calls per followed channel. Proposal: an E1.1 "Following → Videos" shelf using N anonymous `user(login).videos(first:3)` calls, cached for 10 min.
5. **Sub-only VODs:** a paywall message only (anonymous token). Sending the user OAuth on `videoPlaybackAccessToken` waits for the E9 decision.
6. **Chat links to channels** (`twitch.tv/<channel>`) keep their current behaviour. Only VOD and videos links are forced in-app. Routing channel links in-app could be a small follow-up.
7. **Not in E1:** chapters, seek-preview thumbnails, "Up next" autoplay, `?comment=` highlighting, collections, the custom `twitch://` scheme, server watch history. All are candidates for E1.x or E2+.

## Success Criteria

- [ ] VODs, highlights and uploads play inside the app from lists, deep links, live chat and replay chat; there is no code path to an external browser for a VOD.
- [ ] Seek bar, ±10/30 s, double-tap seek, 0.5–2.0× speed, quality restore, mute/volume, PiP, landscape side and overlay chat all work.
- [ ] Chat replay stays in sync (within about 1 s while playing, within 2 s after a seek) with 7TV/BTTV/FFZ emotes, badges and colours; it degrades to a clear ONSET state on failure, and uploads show "no chat replay".
- [ ] Local resume works (−30 s); progress bars appear on cards.
- [ ] All new units and store tests pass; the existing suite is unchanged and green; `flutter analyze` is clean.
- [ ] Regression checklist R1–R12 passes on a device after each commit; latency medians are unchanged against the C6 baseline.
- [ ] GAP.md and ARCHITECTURE.md are updated.

### Critical Files for Implementation
- /home/user/frostyv2-lab/android/app/src/main/kotlin/com/tommychow/frosty/IvsPlayerCore.kt
- /home/user/frostyv2-lab/android/app/src/main/kotlin/com/tommychow/frosty/IvsTuning.kt
- /home/user/frostyv2-lab/lib/screens/channel/video/stores/ivs_video_store.dart (template for the new `lib/screens/vod/stores/ivs_vod_store.dart`)
- /home/user/frostyv2-lab/lib/apis/twitch_stream_service.dart (template for the new `lib/apis/twitch_vod_service.dart`)
- /home/user/frostyv2-lab/lib/models/irc.dart (`fromString` l.950 and `generateSpan` l.651 are reused unchanged; `onTap` l.843 goes through `LinkRouter`)
- /home/user/frostyv2-lab/lib/main.dart (provider, `handleDeepLink` l.241, link router registration)
- /home/user/frostyv2-lab/lib/screens/channel/channel.dart (PlaybackFocus hook; layout reference for `vod_layout.dart`)
- /home/user/frostyv2-lab/test/helpers/fake_ivs_native.dart (MethodChannel fake extended additively)
- /home/user/frostyv2-lab/lib/screens/channel/chat/stores/chat_assets_store.dart (reused for replay emotes and badges; call `init()` before `dispose()`)