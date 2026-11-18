# 11 — Services, global stores, localisation plumbing and native platform code

> Cross-spec decisions in [00-index.md](00-index.md) (section "Decisions") override any conflicting PC suggestion in this file.

Scope of this leaf: `lib/services/**` (playback focus, preloader, token cache, background audio, audio focus, floating player, cast bridge, network metering, locale bridge, notification-settings link, launch info, updater and installer, web token service, settings persistence, image cache manager, 7TV cosmetics cache, shared timer, font licences, profile image picker, telemetry and consent, Hermes client, `realtime/` sockets and protocols, `go_live/` poller and worker, `notifications/`), `lib/stores/**` (global stores), the hand-written files of `lib/l10n/` (`l10n.dart`, `api_errors.dart`, `enum_labels.dart`) plus the ARB structure and `docs/L10N.md` rules, every Kotlin file under `android/app/src/main/kotlin/app/onset/`, the manifest/Gradle facts that change behaviour, `ios/Runner/AppDelegate.swift`, and the vendored `packages/simple_pip_mode` plugin (Dart + Android). Everything here is the plumbing under the screens: none of it draws a Flutter screen of its own, but several pieces draw system UI (notifications, an overlay window, the Picture-in-picture window, the splash handover).

## Purpose

These modules connect the Flutter app to the operating system and to Twitch's push channels, and hold the few app-wide states that outlive a screen:

- **Playback plumbing.** `PlaybackFocus` keeps exactly one player audible across stacked screens (live, VOD, clips). `PlaybackPreloader` + `PlaybackTokenCache` fetch the stream's playback access token the instant a stream card is pressed so the native low-latency player starts without a GQL round trip. The Kotlin `IvsTextureManager`/`IvsTexturePlayer`/`IvsPlayerCore`/`IvsTuning` run the Amazon IVS player (Twitch's own video tech) into a Flutter texture with low-latency tuning, and stream latency/buffer/rate/quality/caption/ad/stats events back to Dart once a second (VOD progress 4×/s). `TwitchWebTokenService` + `TwitchCookies.kt` read the twitch.tv `auth-token` cookie from the login WebView so enhanced-broadcast renditions (1440p HEVC/AV1) can be requested.
- **Background and system media.** `BackgroundAudio` + `BackgroundAudioService.kt` keep a live stream audible with the app in the background (foreground `mediaPlayback` service, media session for lock screen/headphones/Bluetooth, MediaStyle notification with Play/Pause and Stop). `AudioFocus` + `AudioFocusBridge.kt` pause the stream on calls/other apps and on headphone unplug, and resume after a transient loss. `FloatingPlayer` + `FloatingPlayerService.kt` show a system-wide always-on-top overlay player outside the app. The vendored `simple_pip_mode` plugin gives Android Picture-in-picture with a play/pause action. `CastBridge`/`CastStore` + `CastBridge.kt` cast the HLS stream to a Chromecast (Default Media Receiver). `NetworkMetering` + `NetworkBridge.kt` say whether the network is metered (Wi-Fi-only autoplay, data saving) and stream changes.
- **App life.** `LaunchInfo` decides whether the launch intro plays and where the Android 12 splash tile was drawn. `LocaleBridge` keeps the in-app language and Android 13's per-app language in sync. `NotificationSettingsLink` opens Settings › Notifications when the system's notification settings page links to the app. `OnsetUpdater`/`OnsetInstaller` + `ApkInstaller.kt` offer and install newer ONSET builds from GitHub Releases. `persistSettings` writes the settings JSON debounced. `CustomCacheManager` is the image disk cache with an orphan sweep. `SharedTimerService` is the single 1 Hz clock for all uptime labels. `registerFontLicenses` adds Inter's OFL. `pickProfileImage` opens the gallery. `Telemetry`/`telemetry_consent` run optional, opt-in Firebase.
- **Realtime.** `TwitchRealtimeClient` (one shared anonymous Hermes socket for public topics such as hype trains and community highlights), `HermesClient` (per-channel Hermes socket for predictions, channel points, goals, celebrations, sub gifts, shared chat, shoutouts, moments, content labels, stream state, broadcast settings, user topics with the web token), `TwitchEventSubClient` (the user's EventSub socket; whispers). Pure protocol codecs in `hermes_protocol.dart` and `eventsub_protocol.dart`.
- **Notifications.** Go-live notices for followed channels (`GoLivePoller` every 90 s while the app is alive; WorkManager task `onset.goLive` every 15 min otherwise; shared dedupe state in SharedPreferences), chat-mention notices while the app is not in front (`MentionAlerts`), local "Remind me" schedule reminders (`ScheduleReminders`), and the `ActivityLog` history shown on the Activity screen.
- **Global stores.** `CastStore`, `MiniPlayerStore` (adopts the live player + chat for the in-app mini player), `GlobalAssetsStore` (global Twitch/7TV/BTTV/FFZ emotes and badges), `WhisperStore` (whispers over EventSub + Helix + optional GQL history).
- **Localisation plumbing.** `L10n`/`LocaleSync`/`uiLanguageIn`/`saveUiLanguage` make the language available outside widgets (notifications, background isolate), `api_errors.dart` words API failures, `enum_labels.dart` names every settings enum.

Design invariants that the rewrite must preserve: every native bridge degrades silently (logged, never thrown) so playback/chat never fail because of it; the WebView engine always remains reachable; one owner at a time for background audio, audio focus and playback focus; anonymous playback tokens; no Twitch cookies other than twitch.tv ones ever leave the cookie jar; nothing is sent to Firebase before explicit opt-in; private messages never touch disk.

## Screens and layouts

No Flutter screen is defined here, but these system surfaces are:

1. **Android 12+ splash handover** (`MainActivity.handOverSplash` + `LaunchInfo`): the system splash shows the launch tile (the central 72 dp of a 288 dp icon canvas, `res/drawable/splash_icon.xml`) on the ONSET ground `#0A0A0A`; native measures the tile centre/size relative to the Flutter view in dp and sends `splashTile {x, y, size}`; Flutter's launch intro draws its own tile at exactly that rect, answers after two frames, and only then is the splash removed (or after 300 ms whatever happens). Below Android 12, `launch_background.xml` shows the tile too (`nativeTile: true`).
2. **Media notification** (channel `playback`, id 7301): small icon `ic_stat_playback`; title = channel display name (login if empty); text = stream title; actions [Pause|Play, Stop] both shown in compact view; MediaStyle bound to the "ONSET" media session (lock-screen controls, Bluetooth/headset buttons); public visibility; ongoing (non-swipeable) while playing; swipe when paused = stop; tap opens the app.
3. **Floating player overlay** (outside the app, Android `SYSTEM_ALERT_WINDOW`): a black rounded window (radius 14 dp, elevation 8 dp), width = 60 % of the screen's shorter side, height = width × 9/16, initially top-right (16 dp from the right edge, 96 dp from the top), video fills it, a 36 dp circular close button (55 % black background, white ✕) in the top-right corner with 6 dp margin. Drag anywhere moves it (8 dp slop); a tap returns to the app; the close button closes it. Its player is a separate IVS instance with default tuning and no event listener (no error/buffering UI, no mute/volume, low-latency mode not applied — see Known Android defects). Accompanied by a low-importance ongoing notification (channel `onset_floating_player` "Floating player", id 4207) with one "Close the floating player" action; tapping the notification opens the app.
4. **Overlay permission flow** (in `pop_out.dart`, using this service): dialog "Float the stream over other apps?" with "Not now" / "Continue", then the system "Display over other apps" page; refused → snackbar "Without the permission, the stream continues in picture-in-picture." and Android PiP is used instead.
5. **Picture-in-picture window** (Android): 16:9; auto-enter when leaving the app (Android 12+ `setAutoEnterEnabled`) only when the setting `autoPictureInPicture` is on, video is shown (`showVideo`), the content gate allows leaving (not a covered/mature-gated stream) and the device supports auto PiP — otherwise `setAutoPipMode(autoEnter: false)`; the PiP button calls `enterPipMode(autoEnter: true)`; starting the floating player disarms auto PiP and pauses the in-app player, its close re-applies it; one remote action play/pause (`mediaOnlyPause`), labels from the plugin's resources (EN "Play"/"Pause", FR "Lire"/"Mettre en pause"). The channel screen swaps to a video-only layout while in PiP (`PipWidget`).
6. **Go-live notifications** (channel `go_live`): per channel: title "{name} is live", text "{title} · {category}" (FR "{category} · {title}"), large icon = channel avatar (Twitch CDN only, ≤ 2 MiB), expanded = big picture of the category box art 144×192; tap opens the channel. A group summary when more than one notification is posted, and a "{count} more channels went live" notification when more than five channels went live in one check. A "Go-live notifications paused" / "Log in again to get go-live notifications." notice when Twitch refuses the token.
7. **Chat-mention notifications** (channel `chat_mentions`, category message): title "{sender} mentioned you in {channel}", text = the message on one line (≤ 200 chars + …); one per channel (replaced), throttled to one per 30 s per channel; tap brings the chat back (see `MentionTap`). Not `onlyAlertOnce`: each post re-alerts.
8. **Schedule reminders** (channel `schedule_reminders`): scheduled at the segment start: title "{name}’s stream is starting", text "{title} · {category}" or "Untitled stream"; tap opens the channel.
9. **Install confirmation**: Android's own package-installer confirmation screen (ONSET only hands it the session); "Install unknown apps" settings page when not yet allowed.
10. **Cast**: no native UI (route selection is ONSET's own sheet); the receiver shows the Default Media Receiver with title, subtitle and image.
11. **Activity screen data**: `ActivityLog` provides newest-first entries (title, body, category label "Live"/"Chat mentions"/"Events", read state, unread count, `viewedAt` for the bell's "new" badge); the screen itself is specified in another leaf.

## Behaviour and state

Ownership and lifetimes (created in `main.dart`, all for the app lifetime unless noted):
- `LaunchInfo.load()` starts at the very first line of `main()` (500 ms timeout). `registerFontLicenses()` first; `CustomCacheManager.scheduleOrphanSweep()` (10 s after first frame); `Telemetry.initialize()` in parallel with SharedPreferences; secure-storage wipe on first run (`first_run` pref, non-blocking); `SettingsStore.fromJson(prefs['settings'] ?? '{}')`; `syncFirebaseCollection(settings)`; `persistSettings(settings, prefs.setString('settings', …))`; `syncSystemLanguage(settings, LocaleBridge.shared)` + reaction pushing language changes + resume listener adopting system changes.
- `TwitchRealtimeClient()` with lifecycle pause/resume; `SharedTimerService` paused/resumed with the app lifecycle; `TwitchEventSubClient(create: Helix createEventSubSubscription(type, version, condition, sessionId), delete: Helix deleteEventSubSubscription)` with lifecycle pause/resume; reaction storing the logged-in user id into `GoLivePrefs.setUserId`; `ActivityStore` refreshed at start and on each resume (the background task writes to the same list); `MentionAlerts.shared` = post via `MentionNotifications.show` + add Activity entry, `inFront: appInFront`; `GoLivePoller` (`check` waits for `GoLiveNotifications.ready` up to 20 s then `checkGoLiveInApp`), wired to `AppLifecycleListener.onStateChange` and started; `WhisperStore` following `authStore` user id and token; providers for `TwitchRealtimeClient`, `MiniPlayerStore`, `OnsetUpdater`, `GlobalAssetsStore`.
- `LocaleSync` in `MaterialApp.builder` calls `L10n.use`, `rememberUiLanguage(onChanged: ScheduleReminders.shared?.reschedule)` and `BackgroundAudio.shared.setLabels(mediaLabelsOf(L10n.current))`.
- `NotificationSettingsLink().listen(openNotificationSettings)` after the first frame.

Single-owner rules: `BackgroundAudio` (last `show` wins; only the owner can hide), `AudioFocus` (last `request` wins; only the owner abandons), `PlaybackFocus` (stack; claim pauses the previous top, release of top resumes the new top), `MiniPlayerStore` (one adopted player; adopting another disposes the previous), `FloatingPlayerService` (one window; a second start reloads it), `ApkInstaller` (one pending install; a new one supersedes).

Failure semantics: Dart wrappers of method channels degrade instead of failing, but their exact behaviour differs per wrapper (wording per file section). Return null/false/unknown and log only the runtime type: `FloatingPlayer` (`Floating player <method> failed: <type>`), `CastBridge` (`Cast <method> failed: <type>`), `NetworkMetering` (`Network metering unknown: <type>`, `Network changes unknown: <type>`), `NotificationSettingsLink` (`Notification settings link unavailable: <type>`). Log the full exception text: `BackgroundAudio <method> failed: <e>`, `AudioFocus <method> failed: <e>`, `LaunchInfo` (`Launch info unavailable: <e>`; returns `none`), `LocaleBridge` (`Per-app language not set: <e>`, `System languages not read: <e>`, `Per-app language not read: <e>`), `TwitchWebTokenService` (`Could not read the twitch.tv cookie jar: <e.message>`, `Could not clear the cookie jar: <e.message>`, `Could not read the page cookies: <type>`). Silent (no log): `MissingPluginException` in `TwitchWebTokenService.readAuthToken`/`clearCookies`, `LaunchInfo.load` on iOS (returns a cold start without tile), and both exceptions in `OnsetInstaller.canInstall`/`openInstallSettings`. Not caught at all: `OnsetInstaller.install` rethrows on purpose (the updater maps the codes), and the `simple_pip_mode` Dart API (`SimplePip`) catches nothing. Never logged anywhere: tokens, cookie values, URLs with secrets. Realtime clients surface failures only to their topic listeners. The go-live background task returns false (retry) only for unexpected errors.

Persistence (SharedPreferences keys owned here): `settings` (whole settings JSON), `first_run`, `ui_language`, `system_app_language`, `go_live_enabled`, `go_live_muted`, `go_live_user_id`, `go_live_seen`, `go_live_problem`, `go_live_checked_at`, `go_live_announced`, `activity_log`, `activity_viewed_at`, `schedule_reminders`, `onset_update_last_check`, `onset_update_postponed_build`, `onset_update_postponed_at`. Secure storage read by the worker: `AuthBase.userTokenKey`, `AuthBase.userTokenClientIdKey`. Image cache DB `libCachedImageData` + files under the temp dir. Update APKs under `<cacheDir>/updates/`. Nothing about whispers is persisted except muted/archived user ids in settings.

Timing constants (all exact): settings save debounce 300 ms; orphan sweep 10 s after first frame, min age 1 h; image cache stale 30 days, max 10 000 objects; token cache safety margin 60 s, capacity 32; preloader Dio connect 5 s / receive 8 s / idle 60 s; launch info timeout 500 ms; splash fallback 300 ms; IVS latency tick 1 s, VOD progress 250 ms; live rate clamp 1.0–1.1, VOD 0.5–2.0; IVS initial buffer 100 ms; 7TV batch window 400 ms, batch 20, capacity 4 000 users / 200 sets, pause 5 min after failure; shared timer 1 s; go-live in-app 90 s, background 15 min, min gap 60 s, 5 notices + summary, 3 pages × 100, announced memory 24 h, image 2 MiB / 8 s; mention throttle 30 s, 200 chars, names 25 chars; updater check interval 6 h, postpone 24 h; Hermes (shared): backoff 1-2-4-8-16-30 s × jitter 0.8–1.2, healthy 60 s, watchdog keepalive + 5 s, fatal retry 5 min, server-reconnect loop guard 30 s, idle close 30 s, background grace 60 s, unsubscribe delay 500 ms, default keepalive 15 s clamped 1–120 s; Hermes (per channel): ping every 0.6 × keepalive, silence 3 × keepalive, backoff 500 ms × 2^n capped 60 s with half jitter, keepalive clamped 5–120 s; EventSub: backoff same as shared Hermes, idle close 5 s, grace 60 s, release 500 ms, keepalive default 10 s clamped 1–600 s, 200 seen message ids; whispers: 200 per thread, 50 threads, 10 000 chars, history refresh gap 30 s.

## Animations and motion

- **Splash → intro handover** (Android 12+): no system exit animation (`setOnExitAnimationListener` takes over); the Flutter launch intro starts on the exact rect of the splash tile (`LaunchInfo.splashTile`), and the splash is removed only after Flutter has rendered two frames with its tile there (fallback 300 ms), so there is no visible jump. `LaunchInfo.playsIntro` = cold start AND opened from the launcher; warm starts, restores, notification or link launches skip the intro. The intro animation itself is specified with the launch widgets.
- **Refresh rate**: `MainActivity.preferSmoothRefreshRate` asks for the highest display mode at the current resolution whose rate is a multiple of 60 Hz (120 over 144), never lowering, so 30/60 fps streams and UI animations keep an even cadence. iOS: `CADisableMinimumFrameDurationOnPhone = true` (ProMotion 120 Hz).
- **Floating overlay window**: moves 1:1 with the finger after an 8 dp slop; no snapping, inertia, edge clamping or open/close animation (the window appears/disappears instantly).
- **Picture-in-picture**: entry/exit animated by the OS; `seamlessResize` false by default.
- **Texture rendering**: the IVS player draws into a Flutter `SurfaceProducer` texture (initially 1280×720, resized to the stream's resolution), specifically so Flutter can move/scale it smoothly for the draggable in-app mini player and transitions.
- **Notifications**: no custom motion; `onlyAlertOnce` avoids a second sound/vibration when a go-live notice is re-posted.
- **Uptime labels**: tick together once per second from `SharedTimerService` (one notification per second for all listeners; immediate tick on resume).
- Realtime, stores and l10n have no motion.

## Settings

Settings (in `SettingsStore`, persisted by `persistSettings`) that drive these modules:
- `backgroundAudio` (default false) and `backgroundAudioHeadphonesOnly` (default false): whether the IVS store shows the media notification / keeps playing in background (headphones-only checks `AudioFocus.headphonesConnected`).
- `playerEngine` (`ivs` default, `nativeLowLatency` media_kit/mpv, `twitchWeb` WebView): `resolvePlayerEngine` maps `ivs` to `twitchWeb` off Android and `forceWeb` after a runtime fallback; the preloader only acts for the resolved `ivs`.
- `autoPictureInPicture` (default true) and `showVideo` (default true): arm Android auto-enter PiP through `SimplePip.setAutoPipMode`.
- `liveCatchUpMode` (`speedUp` default / `jumpToLive`) and `bufferProfile` (`standard` / `ultra` default) → the `IvsTuning` map (`speedUpCatchUp`, `rebufferToLive`, `initialBufferMs`, `llMinBufferSec`, `llMinBufferCeilingSec`) — exact mapping in the `IvsTuning.kt` section (`autoLatency` also changes it).
- `vodAutoplay` (`always` default, `wifiOnly`, `never`) and `dataSaver` (default false) use `NetworkMetering`.
- `mentionNotifications` (default true) gates `alertChatMention`.
- `shareCrashLogsAndAnalytics` (default off) + `telemetryConsentVersion` (current `kTelemetryConsentVersion = 1`; an "on" saved under an older version counts as off) → `syncFirebaseCollection`; written to disk immediately.
- `appLanguage` (`system`/`en`/`fr`) + `languagePromptVersion` → `L10n`, `LocaleBridge`, written immediately.
- `mutedWhisperUserIds`, `archivedWhisperUserIds` → `WhisperStore`.
- `confirmExternalLinks` (default true; link gate, not in this leaf's code but wired in main).
- Go-live settings live outside the settings JSON, in `GoLivePrefs` (`go_live_enabled`, per-channel bells `go_live_muted`) so the background isolate can read them; turning go-live on asks notification permission (Android 13+), starts `GoLiveScheduler` and clears `seen`.
- Update prompts: "Later" stores the postponed build for 24 h; a forced check in Settings ignores both quiet periods.
- Hidden build-time settings: `UPDATE_REPO`, `UPDATE_TOKEN` (updater), `FIREBASE_*` dart-defines (telemetry), `CLIENT_ID`.

## Strings

All visible words come from ARB (`lib/l10n/app_en.arb` / `app_fr.arb`). Keys used directly by this leaf's code, with EN / FR values:

- Media notification: `mediaChannel` "Playback" / "Lecture en cours"; `mediaPlay` "Play" / "Lire"; `mediaPause` "Pause" / "Mettre en pause"; `mediaStop` "Stop" / "Arrêter".
- Floating player (passed from `pop_out.dart` to the native service): `popOutNotificationChannel` "Floating player" / "Lecteur flottant"; `popOutClose` "Close the floating player" / "Fermer le lecteur flottant"; related flow strings `popOutNotReady` "Couldn’t float the player: the stream isn’t ready yet." / "Impossible d’afficher le lecteur flottant : le live n’est pas encore prêt."; `popOutRefused` "Without the permission, the stream continues in picture-in-picture." / "Sans l’autorisation, le live continue en Picture-in-picture."; `popOutPermissionTitle` "Float the stream over other apps?" / "Afficher le live par-dessus les autres applications ?"; `popOutPermissionNotNow` "Not now" / "Plus tard"; `popOutPermissionContinue` "Continue" / "Continuer".
- Notification channels: `notifChannelGoLive` "Go-live notifications" / "Lives des chaînes suivies"; `notifChannelGoLiveDescription` "When channels you follow go live" / "Quand une chaîne que vous suivez lance un live"; `notifChannelMentions` "Chat mentions" / "Mentions dans le chat"; `notifChannelMentionsDescription` "When someone mentions you in a chat you’re watching while ONSET is in the background" / "Quand quelqu’un vous mentionne dans un chat ouvert en arrière-plan"; `notifChannelReminders` "Stream reminders" / "Rappels de lives"; `notifChannelRemindersDescription` "When a scheduled stream you set a reminder for starts" / "Quand commence un live prévu pour lequel vous avez activé un rappel".
- Notification texts: `notifGoLiveTitle` "{name} is live" / "{name} est en direct"; `notifStreamBody` "{title} · {category}" / "{category} · {title}"; `notifGoLiveMore` "{count, plural, one{{count} more channel went live} other{{count} more channels went live}}" / "{count, plural, one{{count} autre chaîne est en direct} other{{count} autres chaînes sont en direct}}"; `notifGoLivePaused` "Go-live notifications paused" / "Notifications de live en pause"; `goLiveLogInAgain` "Log in again to get go-live notifications." / "Reconnectez-vous pour recevoir les notifications de live."; `notifMentionTitle` "{sender} mentioned you in {channel}" / "{sender} vous mentionne dans le chat de la chaîne {channel}"; `notifReminderTitle` "{name}’s stream is starting" / "Le live de la chaîne {name} commence"; `notifReminderUntitled` "Untitled stream" / "Live sans titre"; reminder outcomes `profileReminderRefused` "Allow notifications for this app in the system settings." / "Autorisez les notifications de cette application dans les paramètres du système."; `profileReminderFailed` "Couldn’t set the reminder." / "Impossible de programmer le rappel.".
- Whisper failures: `chatLogInToWhisper` "Log in to whisper." / "Connectez-vous pour chuchoter."; `whisperOtherAccount` "This conversation belongs to another account." / "Cette conversation appartient à un autre compte."; `whisperTooLong` "Whispers can be {max} characters at most." / "Les chuchotements sont limités à {max} caractères."; `whisperLogInAgain` "Log in again to whisper from this app." / "Reconnectez-vous pour chuchoter depuis cette application."; `chatWhisperFailedBecause` "Couldn’t whisper: {reason}" / "Impossible de chuchoter. {reason}"; `whisperFailedUnexpected` "Couldn’t whisper (unexpected error)." / "Impossible de chuchoter (erreur inattendue).".
- API errors (25 keys) and enum labels (122 keys): listed with values in the `lib/l10n/api_errors.dart` and `lib/l10n/enum_labels.dart` sections below.
- Native strings not from ARB: the PiP plugin's Android resources (EN `Play`/"Play media", `Pause`/"Pause media", `Next`/"Skip to next media", `Previous`/"Go back to previous media", `Live`/"Jump to live"; FR `Lire`/"Lancer la lecture", `Mettre en pause`/"Mettre la lecture en pause", `Suivant`/"Passer au contenu suivant", `Précédent`/"Revenir au contenu précédent", `Direct`/"Revenir au direct"); below Android 13 these follow the device language. App label `ONSET`. iOS photo-library usage text "ONSET opens your photos only when you choose a new profile picture or banner.".
- Developer-only English (never shown): log lines (`BackgroundAudio <m> failed`, `Go-live check failed`, …), error messages of native results (`a https twitch.tv url is required`, `only a downloaded update can be installed`, `another install started`, `the update could not be handed to Android`, `no installer to confirm the update`, `the update was dismissed`, `Android refused the update`), legacy stored go-live problem text `Log in again to get go-live notifications.`.
- ARB structure: 2 289 keys per language, same order, English-only metadata with 2 289 descriptions, 603 keys with typed placeholders, 153 plurals, 101 selects (details and the full `docs/L10N.md` rule set in the localisation section below).

## Network and data

Endpoints and protocols touched by this leaf:
- **Hermes (shared)**: `wss://hermes.twitch.tv/v1?clientId=kimne78kx3ncx6brgo4mv6wki5h1ko`, anonymous; frames `subscribe {id, timestamp, subscribe:{id, type:'pubsub', pubsub:{topic}}}`, `unsubscribe {…, unsubscribe:{id}}`; server frames `welcome{keepaliveSec, sessionId, recoveryUrl}`, `keepalive`, `subscribeResponse{result, error, errorCode, subscription.id}`, `unsubscribeResponse`, `notification{subscription.id, pubsub}`, `reconnect{url}`. Topics like `hype-train-events-v2.<channelId>`; auth-only prefixes refused locally. Fatal close codes 4010, 4111, 4112, 4120–4123, 4130, 4131.
- **Hermes (per channel)**: `wss://hermes.twitch.tv/v1?clientId=kd1unb4b3q4t58fwlpcbzcbnm76a8fp` (official Android client id); additionally `authenticate {token}` with the twitch.tv web token before subscribing, `ping` frames; topics built by `HermesTopics` (`predictions-channel-v1.`, `community-points-channel-v1.`, `creator-goals-events-v1.`, `celebration-events-v1.`, `channel-sub-gifts-v1.`, `shared-chat-channel-v1.`, `shoutout.`, `community-moments-channel-v1.`, `content-classification-labels-v1.`, `video-playback-by-id.`, `broadcast-settings-update.`, user topics `predictions-user-v1.`, `community-points-user-v1.`, `user-subscribe-events-v1.`, …).
- **EventSub**: `wss://eventsub.wss.twitch.tv/ws`; subscriptions created over Helix `POST https://api.twitch.tv/helix/eventsub/subscriptions` (`{type, version, condition, transport:{method:'websocket', session_id}}`) and deleted with `DELETE …/eventsub/subscriptions?id=`; topic used: `user.whisper.message` v1 `{user_id}`; close code 4001 fatal; reconnect URLs must be `wss` on `*.eventsub.wss.twitch.tv`.
- **Helix** (go-live): `GET /streams/followed?user_id&first=100&after` (≤ 3 pages), `GET /users?id=…` for avatars; background headers `Client-Id` (token's own client id if stored) + `Authorization: Bearer`; Dio connect 10 s / receive 15 s. Whispers `POST /whispers?from_user_id&to_user_id` `{message}`. Global assets: Twitch `/chat/emotes/global`, `/chat/badges/global`, 7TV/BTTV/FFZ global emote and badge endpoints (in the API clients).
- **GQL playback token** (via `TwitchStreamService.preload`): anonymous `PlaybackAccessToken` with the public client id, optionally the web `auth-token`; tokens cached in memory by lower-cased login.
- **Images**: Twitch CDN only for notification images: `https://static-cdn.jtvnw.net/ttv-boxart/<gameId>-144x192.jpg` and profile image URLs on `static-cdn.jtvnw.net`; no redirects; 200 only; ≤ 2 MiB.
- **GitHub Releases** (updater, through `OnsetUpdateService`): latest release of `UPDATE_REPO`, optional bearer `UPDATE_TOKEN`, download + checksum verification to `<cache>/updates/*.apk`.
- **Chromecast**: Google Cast SDK, Default Media Receiver, `MediaInfo(url, contentType 'application/x-mpegURL', streamType LIVE|BUFFERED, metadata MOVIE{title, subtitle, image})`, autoplay, start position.
- **Firebase** (opt-in only): Crashlytics, Analytics (screen views), Performance HTTP metrics.
- **Cookies**: twitch.tv cookie jar of Android's WebView (`CookieManager`), flushed before reading.
Data never leaving the device: whispers, activity log, reminders, settings.

## Tested behaviour

Every test file covering this leaf (all under `flutter test`):

Services:
- `test/services/audio_focus_test.dart` — asks once and abandons; changes reach the holder; a newer player takes over; no platform/failing platform left alone (play on); headphones connected or unknown.
- `test/services/background_audio_test.dart` — show/update/hide; `playing`; media buttons reach the owner; a replaced owner cannot change or hide; unsupported platform; native failure not thrown; a refused show re-sent on resume; nothing re-sent once shown or hidden; labels follow the language (sent at once while shown, with each show).
- `test/services/cache_manager_test.dart` — the sweep runs once the delay after the first frame ends.
- `test/services/cast_bridge_test.dart` — no-op where unsupported; media sent with stream type and start; native failure reads as unavailable; session state parsing.
- `test/services/font_licenses_test.dart` — Inter's licence is on the Licenses page.
- `test/services/go_live/go_live_poller_test.dart` — checks at once then every interval in front; keeps going in PiP (inactive); stops in background unless a stream plays; no overlapping slow checks; failures don't stop later ones; stops for good when detached/disposed.
- `test/services/go_live/go_live_test.dart` — `newlyLive` rules; notice wording; one Activity entry per broadcast; `checkGoLive` (off/logged out, avatars, failed avatar lookup still announces, first check only remembers, all pages read, burst capped and summed, muted not announced, flicker announced once, announced older than a day forgotten, minGap skip, failed read keeps state, failed notice retried, another viewer starts over); `checkGoLiveInApp`; `runGoLiveTask` (no token, refused token pauses and says so once, skip after app check, app checking during token read wins, offline retried without report, dropped connection retried and reported, other errors reported); rich notices (stable ids, replace vs add, FNV-1a clear of reserved ids, category art only for numeric ids, avatar large icon + art big picture); notification images (small read, > 2 MB dropped while streaming, redirect not followed, other hosts never asked).
- `test/services/go_live/go_live_worker_test.dart` — a notice opens only a well-formed login; background reports only with consent; an "on" saved before the consent version ignored; Firebase not started for non-sharers or unreadable settings, collects for sharers, collection untouched when Firebase does not start.
- `test/services/hermes_client_test.dart` — welcome gating and single subscribe; lifecycle (unsubscribe before answer, revocation re-subscribe, unknown revocation); routing by subscription id, object payloads, unknown ids, refused subscribe, malformed payload, missing data; backoff to 60 s reset by welcome; reconnect frame not charged; ping within keepalive; silence 3× keepalive; pause cancels reconnect; dispose; malformed frames keep the socket; zero keepalive clamped; parse error logs code only; authenticate before subscribe, topics added while authenticating wait, missing/failing token still subscribes, no provider no auth; pause/resume; flat payloads for sub gifts and stream state; untyped payload delivered whole.
- `test/services/launch_info_test.dart` — cold start under the native tile; notification/link launch no intro; warm start; iOS without channel; failing channel; never-answering channel doesn't hold launch; splash handover takes the tile then lets it go; malformed positions ignored.
- `test/services/locale_bridge_test.dart` — tag/language mapping; tells then adopts; change while closed adopted at launch; app pick told; regional pick adopted as its language; nothing without per-app language; failures logged.
- `test/services/network_metering_test.dart` — metered/unmetered/unknown; non-Android unknown without asking; changes stream, errors skipped, nothing elsewhere.
- `test/services/notification_settings_link_test.dart` — opens once for a launch, each time while running, nothing elsewhere.
- `test/services/notifications/activity_log_test.dart` — empty start; newest first across reload; concurrent changes all land; no duplicates; max entries; unread/mark read/all/remove; damaged entry skipped; bad login dropped; labels follow Twitch's categories; viewedAt remembered.
- `test/services/notifications/mention_alerts_test.dart` — posts only when not in front; throttle per channel; failed post not counted; one safe line cut; joiners kept for emoji/scripts; tap outcomes; closable pages incl. every settings sub-page; Activity entry; stable id distinct from go-live ids; `chatMentionOf` rules; `alertChatMention` hook and setting.
- `test/services/notifications/schedule_reminders_test.dart` — set at segment start and persisted; toggle cancels; uncancellable stays set; listeners notified; refused/failed sets nothing; only future non-cancelled; untitled body; due handed to Activity once; moved rescheduled, cancelled dropped, moved into past dropped, gone dropped, went-off kept for Activity; damaged dropped; language change rewording; rewording never undoes concurrent changes (cancelled/moved meanwhile); strict ordering; stable ids avoiding fixed ones.
- `test/services/onset_updater_test.dart` — enabled only on Android with a repo; tokenless public build; disabled never asks; check offers newer, 2000-series builds, same/older up to date, unreadable fails, 6 h interval persisted, newer offered again next start, hidden release quiet, rate limit waits 6 h, failed retried, clock set back, forced ignores 6 h; Later quiet 24 h, newer prompts, forced shows postponed; download cleanup (also when disabled, failure ignored); install from cache, onInstall callback, dismissed → cancelled, refused → install error, download errors propagate, canInstall/openInstallSettings, no native side.
- `test/services/playback_focus_test.dart` — claim pauses previous; release top resumes below; release below calls nobody; double claim no-op; re-claim moves on top; unknown owners ignored; released must re-register.
- `test/services/playback_preloader_test.dart` — preloads only for the resolved IVS engine; uses the token the player will send.
- `test/services/playback_token_cache_test.dart` — validity, safety margin, expiry over time, case-insensitive logins, invalidate, no-expiry never cached, LRU eviction, pending sharing.
- `test/services/realtime/eventsub_protocol_test.dart` — welcome/keepalive default, notification fields, reconnect only to Twitch wss, revocation, keepalive/unknown/malformed, only 4001 fatal.
- `test/services/realtime/hermes_protocol_test.dart` — decoding of every frame, keepalive default and clamp, notification payload string/object, reconnect with/without url, unknown, garbage; encode shapes; close codes; topic validation; UUID v4 ids.
- `test/services/realtime/realtime_socket_test.dart` — a failed connect ends the stream without a zone error.
- `test/services/realtime/twitch_eventsub_client_test.dart` — connect on first listener; moved session keeps subscriptions; lost socket reconnects and re-subscribes; keepalive silence; refused permanent vs server error transient; revocation; last listener deletes and closes; 4001 not retried; background sleep/resume; move whose old socket closes first; subscribe running at session end redone; stale answer not claimed; failed move starts a new session; token refusal flagged unauthorized.
- `test/services/realtime/twitch_realtime_client_test.dart` — lazy connect; single socket and per-topic subscribe; routing; refused topic permanent; throwing listener isolation; watchdog; backoff 1-2-4 and re-subscribe; healthy-minute reset; 4100 reconnects; fatal stops until later subscribe; reconnect frame immediate; ref counting with 500 ms grace and 30 s idle close; short vs long background; hardening cases (pending reconnect after all left, reconnect frames in a row back off, subscriber during fatal pause, late subscriber status replay, fatal in background not undone, dropped session not healthy, later-session topic not a resubscribe, resume cuts backoff, malformed/login-only topics refused, clean dispose).
- `test/services/settings_persistence_test.dart` — a divider drag writes a few times, not per frame; change before leaving written at once; stopping flushes; consent/language keys written at once.
- `test/services/seventv_cosmetics_cache_test.dart` — one request for chatters seen together; batches; pause after failure; LRU capacity; emote set fetched once and retried after failure; rest of flush not sent after a failed batch; set cache capacity.
- `test/services/shared_timer_service_test.dart` — stops in background, resumes with one tick; listener added in background waits for resume.
- `test/services/telemetry_consent_test.dart` — debug never collects; saved opt-in collects from launch; pre-version "on" never collects; switch on/off at once; reset stops; debug switch inert.
- `test/services/telemetry_test.dart` — `firebaseOptionsFrom` cases; without config every call no-op and nothing collected; before opt-in nothing to Crashlytics/Performance, after opt-in reports, none after opt-out; uncaught platform error left to engine; framework error shown not reported; image load failures never fatal; native configs collect nothing by default and never the advertising id; repository carries no Firebase config.
- `test/services/twitch_web_token_service_test.dart` — `parseAuthToken` table; jar read, empty jar, platform error, missing native side; clearCookies and its errors; no channel calls off Android; page fallback incl. JSON-quoted result.

Stores:
- `test/stores/cast_store_test.dart` — availability; device list; load after connect; immediate cast to connected device; refused load reported; ended session drops pending; failed start reported; same-name devices distinct; stop ends session.
- `test/stores/mini_player_store_test.dart` — live progress follows the player; minimized flag set/cleared; close saves position before disposing; another channel replaces and closes the first; no tracker fine.
- `test/stores/whisper_history_test.dart` — Twitch conversations merged into the list; earlier whispers loaded once per conversation; failure keeps session whispers and flags unavailable; hidden stays hidden until newer; 30 s refresh gap; account switch drops fetched history.
- `test/stores/whisper_store_test.dart` — `whisperFromEvent` rules; `whisperPreview` line/invisible/joiner rules; hide; mute/archive restore and report; listens to the viewer; unread until opened; ordering; send adds after Twitch accepts; `thread()` without opening; 50-thread cap; other-account protection; re-login re-listens; non-token refusal not a login problem; stacked open conversations; `/w` keeps conversation only after success; logout forgets; every failure reads in both languages.

Localisation (`test/l10n/`):
- `test/l10n/arb.dart` (ARB/ICU reader helper), `test/l10n/helpers_lot8c.dart` (shared helper for lot 8c).
- `test/l10n/arb_parity_test.dart` — same keys/order, French no metadata, descriptions, non-empty, valid ICU, typed placeholders identical in French, plurals with `other` and French `one`, `_sameInBothLanguages` list, generated code fresh.
- `test/l10n/l10n_test.dart` — `resolveAppLocale`, `L10n.use` switches texts and Intl observably, French `one` covers 0 and 1, `context.l10n` fallback.
- `test/l10n/api_errors_test.dart` — every kind worded in both languages; Twitch's words only on English screens; chat failure lines as sentences with quoted reasons.
- `test/l10n/notifications_l10n_test.dart` — go-live notices in EN and FR (category first), problem code and legacy text, channel names in the language shown for go-live, mentions, reminders, the media notification labels, mention notices.
- `test/l10n/select_coverage_test.dart` — selects with empty/vague `other` listed with all passed values.
- `test/l10n/en_style_test.dart`, `test/l10n/fr_typography_test.dart` — the style guides on every value and the release notes.
- `test/l10n/english_leaks_test.dart` — the leak detector used by French screen tests.
- `test/l10n/inter_font_test.dart` — bundled Inter faces draw every ARB character.
- `test/l10n/numbers_dates_test.dart` — compact viewer counts and schedule day titles per language.
- French screen sweeps (5 windows × 2 text scales, overflow/leak/clipping checks): `test/l10n/fr_channel_player_test.dart`, `test/l10n/fr_chat_test.dart`, `test/l10n/fr_community_highlights_test.dart`, `test/l10n/fr_hype_train_test.dart`, `test/l10n/fr_lot11_test.dart`, `test/l10n/fr_lot2_test.dart`, `test/l10n/fr_lot4c_test.dart`, `test/l10n/fr_lot5_test.dart`, `test/l10n/fr_lot6_test.dart`, `test/l10n/fr_lot6b_test.dart`, `test/l10n/fr_lot7e_test.dart`, `test/l10n/fr_lot7f_test.dart`, `test/l10n/fr_lot8a_test.dart`, `test/l10n/fr_lot8b_test.dart`, `test/l10n/fr_lot8c_test.dart`, `test/l10n/fr_lot8d_test.dart`, `test/l10n/fr_lot9a_test.dart`, `test/l10n/fr_lot9b_test.dart`, `test/l10n/fr_mod_tools_test.dart`, `test/l10n/fr_notification_permission_test.dart`, `test/l10n/fr_settings_test.dart`, `test/l10n/fr_vod_test.dart`.

Related repository guards (outside the required paths but protecting this code): `test/guards/ivs_live_rate_clamp_test.dart` (reads `IvsPlayerCore.kt`: live clamp 1.0–1.1 equal to `LatencyController.maxLiveRate`, VOD 0.5–2, `rate_rejected`, ticks never dropped), `test/guards/android_l10n_test.dart` (no English literal in Kotlin notification channels/actions; PiP plugin has French; `locales_config.xml`/iOS languages match), `test/guards/crash_report_privacy_test.dart` (no crash report identifies the viewer or channel), `test/guards/no_client_secret_test.dart`, `test/guards/l10n_wiring_test.dart`, `test/guards/l10n_language_lookups_test.dart`, `test/guards/no_hardcoded_strings_test.dart`.

## Wide and tablet layout

- Nothing here lays out Flutter widgets, so there is no breakpoint logic, but several values scale with the device: the floating overlay window is 60 % of the screen's **shorter** side computed in physical pixels (a tablet whose shorter side is 1600 px gets a 960×540 px window; a 1080×2400 phone gets 648×364 px), always 16:9,, placed 16 dp from the right and 96 dp from the top regardless of orientation; it can be dragged anywhere, including off the system bar areas (`FLAG_LAYOUT_NO_LIMITS`).
- The activity never restarts on rotation/resize/split-screen (`configChanges` covers orientation, screenSize, smallestScreenSize, screenLayout, density, uiMode, locale, fontScale…), so players, sockets and services survive tablet rotations and multi-window resizing.
- Picture-in-picture uses a 16:9 aspect ratio on every form factor.
- `MiniPlayerStore.shellChrome` carries the shell header/bottom-bar insets, which differ between phone (bottom bar) and tablet (side rail; insets may be zero at the bottom) so the in-app mini window stays inside the visible area.
- Notifications, media session and cast are form-factor independent.
- Settings page descriptions (`SettingsPageIdLabel.description`) exist specifically for the tablet two-pane settings layout (the line under each page title in the side column).
- French screen tests run at 360×640, 390×844, 844×390 and the tablets 1280×854 and 854×1280 at text scales ×1.0 and ×1.3.

## PC equivalent

Concrete Windows mapping (Rust; macOS/Linux noted where the API differs). Nothing is dropped; mobile-only mechanisms get a desktop replacement with the same contract.

| Mobile piece | Windows implementation |
|---|---|
| `onset/ivs-texture-manager`, `onset/ivs-texture/<id>` (IVS SDK, Android only) | A native low-latency HLS engine in Rust: playlist fetch/refresh (LL-HLS aware, Twitch `#EXT-X-TWITCH-PREFETCH` segments), decode via libmpv (`libmpv2` crate, `profile=low-latency`, `cache=no`, `demuxer-readahead-secs` from the tuning) or FFmpeg + D3D11VA, rendered into the app's wgpu/D3D11 texture so the mini player can move it. Keep the exact event contract: `state` (IDLE/READY/BUFFERING/PLAYING/ENDED), `qualities` sorted height→fps→bitrate and `qualitiesChanged`, `quality`, `error {code,msg,errorType,source}`, `rebuffering`, `ad` (from `#EXT-X-DATERANGE` stitched-ad markers), `caption` (CEA-608/708 from the stream), `textTracks`, `latency` every 1 s (`ms` from EXT-X-PROGRAM-DATE-TIME of the playing segment vs wall clock, `bufferMs`, `rate`, `lowLatency`), `stats`, VOD `progress` every 250 ms, `duration`, `seeked`. Same methods and clamps (live rate 1.0–1.1 with `rate_rejected`, VOD 0.5–2, volume 0–1, VOD start seek on first READY, auto-play once per load). `IvsTuning` maps to target buffer / catch-up speed parameters (speed-up catch-up default, initial buffer 100 ms). The WebView2 Twitch embed remains the fallback engine (`twitchWeb`). macOS: VideoToolbox via libmpv; Linux: VA-API via libmpv. |
| `onset/background-audio` + `BackgroundAudioService` | Desktop processes are not frozen, so no service is needed; keep playing when the window is minimised or hidden to the tray. System Media Transport Controls via `windows` crate (`ISystemMediaTransportControlsInterop::GetForWindow`): title = display name, artist = stream title, Play/Pause/Stop enabled, `PlaybackStatus` playing/paused; button presses → `MediaCommand` play/pause/stop. Media keys work through SMTC. Optional taskbar thumbnail toolbar (`ITaskbarList3::ThumbBarAddButtons`) Play/Pause + Stop with the `mediaPlay/mediaPause/mediaStop` labels. macOS: `MPNowPlayingInfoCenter` + `MPRemoteCommandCenter`; Linux: MPRIS over D-Bus (`mpris-server`). |
| `onset/audio-focus` | Windows has no focus API. Map `noisy` to `IMMNotificationClient::OnDefaultDeviceChanged`/`OnDeviceStateChanged` when the active render endpoint (headphones/Bluetooth) disappears → pause; map `lossTransient`/`gain` to Windows communications ducking (`IAudioVolumeDuckNotification::OnVolumeDuckNotification`/`OnVolumeUnduckNotification`, i.e. a call in Teams/Discord) → pause and resume; `loss` not generated. `headphonesConnected` = default render endpoint form factor `Headphones`/`Headset` (`PKEY_AudioEndpoint_FormFactor`) or Bluetooth. |
| `onset/floating-player` + `FloatingPlayerService` (overlay outside the app) | A second borderless always-on-top window (winit `WindowLevel::AlwaysOnTop`, no taskbar entry) sharing the same player texture, default width 60 % of the primary monitor's shorter side capped to a sensible max (e.g. 480 px logical), 16:9, initial position top-right 16 px from the right of the work area and 96 px from the top, rounded corners 14 px (DWM `DWMWA_WINDOW_CORNER_PREFERENCE`), 36 px circular close button top-right with 6 px margin, drag-to-move with 8 px slop, click returns to and restores the main window (`returned: true`), close → `returned: false`. No permission needed (`canDrawOverlays` always true). Instead of a notification, the tray icon menu shows "Close the floating player". |
| `simple_pip_mode` (Android PiP) | Same always-on-top mini window as above, entered automatically when the main window is minimised while a live plays (the `autoEnter` behaviour), with an overlay play/pause button mirroring `mediaOnlyPause` and `setIsPlaying`; `onPipEntered/Exited` become mini-window open/close events. |
| `onset/cast` + `CastBridge.kt` | `rust_cast` crate over TLS port 8009 + mDNS discovery of `_googlecast._tcp.local` (`mdns-sd`), friendly name from the TXT `fn` record, id from `id`. Launch app id `CC1AD845` (Default Media Receiver), `LOAD` with `contentType: application/x-mpegURL`, `streamType: LIVE|BUFFERED`, metadata type MOVIE title/subtitle/images, `autoplay: true`, `currentTime = startMs/1000`; `disconnect` = `STOP` the receiver app (stopReceiverApplicationWhenEndingSession). Same `devices`/`state` events and `CastStore` logic. |
| `onset/network` + `/metered` | WinRT `NetworkInformation::GetInternetConnectionProfile()?.GetConnectionCost()`: `NetworkCostType::Unrestricted` → false, `Fixed`/`Variable` or `Roaming`/`OverDataLimit` → true, no profile → null; `NetworkInformation::NetworkStatusChanged` event re-evaluates and emits only changes. macOS: `NWPathMonitor.isExpensive`; Linux: NetworkManager `Metered` property. |
| `onset/cookies` (`TwitchCookies`) | WebView2 `ICoreWebView2CookieManager::GetCookies("https://www.twitch.tv")` (returns HttpOnly cookies); keep the Android contract: return the raw `name=value; …` string of twitch.tv cookies and extract `auth-token` in the shared Rust token code (`parseAuthToken`); only https twitch.tv hosts accepted (same case-sensitive check); `DeleteAllCookies` on logout. The same navigation guard (`isTwitchPageUrl`) in the hidden WebView2 `NavigationStarting` handler. |
| `onset/updates` + `ApkInstaller` | Updater over the same GitHub Releases with the same 6 h check / 24 h postpone logic and pref keys: download the Windows asset (MSIX or Velopack/`self_update` package) into `%LOCALAPPDATA%\ONSET\updates\`, verify SHA-256, then hand it to the installer (`App Installer` for MSIX or Velopack's `Update.exe apply`) and restart; only files inside that folder are accepted; signature must match (Authenticode publisher check). `canInstall` = true; `openInstallSettings` unnecessary (no-op). Downloads up to the installed version are deleted at start. | (Superseded where it differs by D4: no MSIX, no Authenticode requirement.)
| `onset/locale` | No per-app language API: the in-app setting is the only one; `systemLocales` = `GetUserPreferredUILanguages` (or WinRT `GlobalizationPreferences::Languages`), most preferred first, parsed with the same `localeOfTag`; `push`/`changedInSystem` are no-ops. macOS has per-app languages via `AppleLanguages` user default (implement push/get there). |
| `onset/launch` + splash handover | Single-instance app (named mutex + named pipe forwarding of arguments). `coldStart` = first instance; `fromLauncher` = no protocol/toast arguments. No system splash: the window opens directly on the intro (tile centred), so `nativeTile` false. Deep links: register `twitch://` and `ttv://` URL protocols (HKCU\Software\Classes) and handle https twitch.tv links pasted/dragged in. |
| `onset/notification-settings` | Toast notifications carry a context-menu/button "Notification settings" that launches the app with `--open=settings/notifications`; also `ms-settings:notifications` linked from the in-app page. `consumeLaunch` reads that argument at start; `open` comes through the single-instance pipe. |
| Go-live WorkManager task (`onset.goLive`) | Tray-resident process: the poller runs every 90 s while the main window is visible or a stream/mini window plays, and every 15 min while only the tray icon remains (same `GoLivePrefs` file, same 60 s min gap and dedupe). Optional "Run at sign-in" (HKCU Run key) or a Task Scheduler job `onset.exe --go-live-check` every 15 min when the app is fully closed, executing `runGoLiveTask` headless with the token from Windows Credential Manager. | (Superseded where it differs by D6: 90 s polling, tray + autostart, no 15-minute mode.)
| Notifications (flutter_local_notifications) | Windows toast notifications via the `windows` crate `ToastNotificationManager` with an AppUserModelID (Start-menu shortcut created by the installer). Go-live: `Tag` = stable notice id, `Group` = `go_live` (replacement and `onlyAlertOnce` → `SuppressPopup` on re-post), `appLogoOverride` (circle crop) = avatar, `hero` image = box art, `launch` arg = login; "N more" toast id 0, problem toast id 1, collection summary via `ToastCollection` or a summary toast id 2. Mentions: group `chat_mentions`, tag per channel. Reminders: `ScheduledToastNotification` added with `ToastNotifier::AddToSchedule` at the segment start (survives reboot), removed with `RemoveFromSchedule`, re-added on language change. Android channels → per-category toggles in ONSET's settings (Windows has no channels; the app enforces them) plus the system-level per-app toggle. Permission: `ToastNotifier::Setting()` to detect disabled toasts (`allowed`). macOS: `UNUserNotificationCenter`; Linux: `notify-rust` (D-Bus). |
| `ActivityLog`, `ScheduleReminders`, `GoLivePrefs`, update prefs, `ui_language`, `settings` (SharedPreferences) | A JSON/SQLite store under `%APPDATA%\ONSET\` with the same keys and value formats; cross-process access (tray poller vs headless task) guarded by a file lock, re-read before each mutation like `reload()`. |
| Secure storage (`AuthBase.userTokenKey`, client id) | Windows Credential Manager (`keyring` crate). |
| `persistSettings` | Debounced (300 ms) atomic write (temp file + rename) of `settings.json`; immediate write for consent and language keys; flush on window hide/minimise/close and on exit. |
| `CustomCacheManager` | Disk image cache `%LOCALAPPDATA%\ONSET\cache\libCachedImageData\` with a SQLite index; stale 30 days, max 10 000 objects; orphan sweep 10 s after the first frame, sparing files modified < 1 h ago. Trap: the Dart sweep matches files with `file.path.split('libCachedImageData/').last` (hard-coded `/`); ported literally to Windows `\` paths every file would look orphaned and the whole cache would be wiped after 1 h. Compute the relative path with `std::path::Path::strip_prefix` and compare normalised components. |
| `SharedTimerService` | One 1 Hz UI tick, paused while the window is minimised/occluded and resumed with an immediate tick. |
| `registerFontLicenses` | Bundle Inter and its OFL; list it on the Licenses page (with the Rust crate licences generated by `cargo-about`). |
| `pickProfileImage` | Native file-open dialog (`rfd` crate) filtered to JPEG/PNG/GIF/WebP, same 10 MiB limit and outcomes (cancel → nothing; error/oversize → "can't use this image"). |
| `Telemetry` (Firebase) | Firebase has no desktop SDK: Sentry (`sentry` crate) for crashes behind the same opt-in, versioned consent and "image load failures are never fatal" rule; analytics and HTTP traces optional/off; nothing collected before opt-in, unsent reports deleted on opt-out. |
| Realtime (`web_socket_channel`) | `tokio-tungstenite` with rustls; protocol codecs and state machines ported 1:1 (timings above); websocket pings answered by the library. Lifecycle pause/resume = window minimised to tray for > 60 s / restored (or system suspend/resume via `WM_POWERBROADCAST`). |
| `MainActivity.preferSmoothRefreshRate` | Present at the monitor's native refresh (winit/wgpu `PresentMode::Fifo` or `Mailbox`); per-monitor DPI awareness; no API needed. |
| `PlaybackFocus`, `PlaybackTokenCache`, `PlaybackPreloader` | Ported in memory. Token cache key = login, or login + `#` + a stable hash of the web token (not Dart's `hashCode`); the cache is cleared on logout/account switch. Preloading on stream-card hover/press is **enabled on PC explicitly** (the Dart preloader is gated to Android); HTTP client with 60 s keep-alive. |
| iOS `AppDelegate` | Not applicable on Windows; the macOS build later uses its own app delegate with the same plugin set. |

### Known Android defects (reproduced faithfully in this spec; the PC port fixes them)

| # | Android behaviour today (exact) | PC port behaviour |
|---|---|---|
| 1 | Floating overlay player never calls `IvsTuning.applyTo`: no live low-latency mode, no `rebufferToLive(false)`, no 100 ms initial buffer; only SDK speed-up catch-up. | The always-on-top mini window uses the same tuned engine instance/config as the main player (low-latency, 100 ms initial buffer, user catch-up/buffer profile). |
| 2 | Floating overlay has no player listener: no auto-play on READY, IVS errors leave a black window, no rebuffer/latency, no mute/volume. | The mini window subscribes to the full event contract: shows buffering/error state with retry, auto-plays on READY, honours mute/volume. |
| 3 | `IvsTexturePlayer` attaches the producer surface once; a recreated surface is never re-attached (black video, audio continues). | The renderer re-binds the output texture on every swapchain/device recreation (resize, DPI change, GPU device loss). |
| 4 | Cast: connecting to device B while connected to A emits a `connected` state for A, and `CastStore` loads B's media on A. | `connect` emits `connecting` with the target id; pending media is loaded only when the connected session's device id equals the requested device. |
| 5 | Cast `load` reports success when the request is merely handed over; receiver load failures are never seen. | `load` waits for the receiver's `MEDIA_STATUS`/`LOAD_FAILED` reply (timeout 10 s) and reports failure. |
| 6 | Whisper thread eviction never evicts archived threads; more than 50 threads can exist. | Eviction considers archived threads too (never the new or open ones), enforcing the 50 cap. |
| 7 | Go-live background task: `_initTelemetry()` runs outside the try, so a throw escapes without report or retry signal. | Telemetry start-up is inside the guarded block; any failure is logged and the run returns "retry". |
| 8 | Mention id fallback can be the literal `"null"` (`mention:<channelId>:null`), merging distinct mentions in Activity. | Fallback id = `tmi-sent-ts` if present, else a generated unique id (timestamp + random). |
| 9 | Mentions with an empty message text pass `chatMentionOf` and post an empty-body notice. | Empty (or whitespace-only) texts are rejected like null ones. |
| 10 | `setCaptions(false)` leaves the text track selected and reported as selected. | Turning captions off deselects the track and reports `selected: null`. |
| 11 | VOD `setPlaybackRate` throws on SDK refusal instead of returning `rate_rejected`. | VOD rate changes return `rate_rejected` on refusal, like live. |
| 12 | `seekTo` without `ms` seeks to 0 (and before READY overrides the start position). | A missing `ms` is rejected as a bad argument; no seek. |
| 13 | `DragToMove` ignores ACTION_CANCEL. | Pointer capture loss ends the drag cleanly (no tap). |
| 14 | `GoLiveScheduler.stop()` initialises WorkManager even if never started. | Stopping an unregistered scheduled task is a no-op. |
| 15 | Go-live poller is not restarted when background playback begins while stopped. | The poller re-evaluates on playback start/stop events, not only on window resume. |
| 16 | Go-live notification images are fetched notice by notice (up to 5 × 8 s). | Images for all notices are fetched in parallel before posting, each with the 8 s / 2 MiB limits. |
| 17 | `ApkInstaller` keeps one static pending answer; a second install answers the first `superseded` but the first job keeps running, and its late failure or its session's status answers the second call. | One install per session id; each status is routed only to the call that started that session; starting a new install cancels the previous download/apply. |
| 18 | `simple_pip_mode` registers its PiP action receiver `RECEIVER_EXPORTED` with implicit intents: any app can pause/resume ONSET, and an unknown `EXTRA_ACTION_TYPE` crashes the process (`PipAction.valueOf`). | No inter-process channel: the mini window's buttons call the player directly; unknown actions are impossible by construction. |
| 19 | (Unconfirmed, needs an API 24/25 emulator) `simple_pip_mode` uses API 26 classes (`RemoteAction`, `PictureInPictureParams`) on minSdk 24 without a version gate; `NoClassDefFoundError` is not caught, so Android 7.x likely crashes when a player screen opens. | Not applicable to the PC API surface; the mini window has no OS-version-dependent API. Record: the Android build should gate PiP calls on API ≥ 26. |
| 20 | `SharedTimerService.removeListener` decrements unconditionally; the count can go negative and the uptime tick then never restarts. | The 1 Hz tick tracks a set of real registrations; removal of an unknown listener is a no-op. |
| 21 | `GlobalAssetsStore.refresh` during an in-flight load awaits the old load (old provider flags) and marks loaded; the settings change is lost. | A refresh during a load cancels or chains after it and always fetches with the latest flags. |
| 22 | `GlobalAssetsStore` marks itself loaded after a failed provider fetch; that provider stays empty all session (no retry until a settings change). | Failed providers are retried with backoff (and on network regain). |
| 23 | `GlobalAssetsStore.refresh` with a provider now disabled neither fetches nor clears it; its global emotes/badges stay in `globalEmoteMap` and keep rendering in chat. | A disabled provider's collections are emptied on refresh. |
| 24 | `simple_pip_mode` keeps `lateinit var activity`: any call before `onAttachedToActivity` throws `UninitializedPropertyAccessException` and crashes the call. | PC has no plugin attach phase: the mini-player window is owned by the app and every call is valid from startup; calls before the window exists are queued or ignored, never panic. |

Nothing else differs silently: every other behaviour in this file is to be reproduced as written.

## Per-file reference: lib/services (playback, platform bridges, app plumbing)

### lib/services/playback_focus.dart

`class PlaybackFocus` keeps exactly one player audible across stacked screens. `static final shared = PlaybackFocus()` is the app-wide instance. Only player screens claim (live channel screen, VOD screen, clip screen, clips feed, clip story) — never sheets or dialogs.

Data: `_callbacks: Map<Object, ({VoidCallback onLost, VoidCallback onRegained})>` and `_stack: List<Object>` (owners in claim order).
- `top` → last element of the stack or null.
- `register(owner, {onLost, onRegained})` → stores/overwrites the callbacks; registering does not put the owner on the stack.
- `claim(owner)` → no-op if the owner is unknown or already top; otherwise moves the owner to the top (removed then appended, so re-claiming re-orders) and calls `onLost()` of the previous top (which pauses itself).
- `release(owner)` → no-op if unknown; removes the callbacks and the stack entry; if the released owner was top and there is a new top, that new top's `onRegained()` is called (it resumes). Releasing a non-top owner does not touch the top.
Callers also tie `WakelockPlus.disable()` to "I was top and now no one is". Example: watching a live channel, opening a VOD from its profile pauses the live player (onLost); closing the VOD resumes the live player (onRegained).

### lib/services/playback_preloader.dart

`class PlaybackPreloader(TwitchStreamService service, {bool? isAndroid})` — requests a stream's playback access token as soon as its stream card is pressed (`stream_card_parts.dart` calls `PlaybackPreloader.instance.preload(...)` on press-down), so the native player finds it cached or in flight (`PlaybackTokenCache.pending`) instead of paying a GQL round trip after navigation — like the official app's theatre preload.

- `static PlaybackPreloader instance = PlaybackPreloader(TwitchStreamService(tokenCache: PlaybackTokenCache.shared, http))` (replaceable in tests).
- `static final Dio http` with `connectTimeout 5 s`, `receiveTimeout 8 s` and an `IOHttpClientAdapter` whose `HttpClient` has `idleTimeout = 60 s` (`playbackHttpClient()`), keeping the TLS connection to Twitch warm for the player's following requests.
- `preload({required login, required PlayerEngine engine, String? authToken})`: resolves the engine with `resolvePlayerEngine(setting: engine, isAndroid: _isAndroid, forceWeb: false)`; does nothing unless the resolved engine is `PlayerEngine.ivs` and the login is non-empty (the WebView and other engines, and IVS outside Android, do not use the token); otherwise fires `service.preload(login, authToken: authToken)` unawaited. `authToken` must be exactly the one the player will send (the twitch.tv web `auth-token`) or the player would look up a different cache entry.

PC note: `preload` resolves the engine with `isAndroid: _isAndroid`, so it never preloads off Android. The PC port preloads for its native engine explicitly (gate on "native low-latency engine selected", not on the OS) — a deliberate, listed change.

### lib/services/playback_token_cache.dart

`class PlaybackTokenCache({DateTime Function()? now, Duration safetyMargin = 60 s, int capacity = 32})` (asserts capacity ≥ 0). In-memory only, never persisted or logged. `static final shared` is used by every IVS player and the preloader.

Keying (as actually used by `TwitchStreamService._cacheKey`, `lib/apis/twitch_stream_service.dart`): an anonymous token is cached under the login, an authenticated one (sent with the twitch.tv web `auth-token`) under `'<login>#<authToken.hashCode>'`; the cache lower-cases the whole key. So authenticated and anonymous tokens never mix and one viewer's authenticated token is never replayed for another. There is no `clear()`: on logout authenticated entries stay in memory until they expire (or are LRU-evicted) — harmless only because the key changes with the token. The source comment ("tokens are anonymous, one cache serves every account") predates this keying. PC port: Dart's `String.hashCode` is not stable or portable — use a stable hash of the token (e.g. SHA-256, truncated, never the token itself) and clear the whole cache on logout/account switch.

- Storage: insertion-ordered map `login.toLowerCase() → PlaybackAccessToken`; first key = least recently used.
- `get(login)`: removes the entry; returns null if absent or invalid (an invalid one stays removed); otherwise re-inserts it as most-recently-used and returns it.
- `put(login, token)`: ignored when invalid; inserts as MRU; evicts LRU entries while `length > capacity`.
- `invalidate(login)`: removes the entry (used when usher rejects a token).
- Validity: a token with null `expiresAt` is never cached/returned; valid iff `now + safetyMargin` is before `expiresAt` (no token that would expire mid-request).
- In-flight sharing: `pending(login)` returns the future currently being fetched for that login; `track(login, future)` stores it and removes it on completion or error only if it is still the same future (`identical`).

### lib/services/background_audio.dart

Dart side of `onset/background-audio`.

- `enum MediaCommand { play, pause, stop }`.
- `typedef MediaLabels = ({String channel, String play, String pause, String stop})`; `mediaLabelsOf(AppLocalizations l)` = `(channel: l.mediaChannel, play: l.mediaPlay, pause: l.mediaPause, stop: l.mediaStop)`.
- `class BackgroundAudio({MethodChannel? channel, bool? supported})` — default channel `onset/background-audio`, supported = `Platform.isAndroid`; when supported, installs the handler for `command`. `static final shared`.

Contract: one player shows the notification at a time — the last to call `show` becomes `_owner`; `hide(owner)` from another owner is ignored, so a replaced player cannot hide its successor's notification. Native failures are logged (`BackgroundAudio <method> failed: <e>`), never thrown.

- `setLabels(labels)`: no-op unsupported or unchanged; stores; if a notification is up sends `labels {channel, play, pause, stop}`. Wired from the app's `LocaleSync` so the notification is re-worded immediately on a language change.
- `show({owner, title, subtitle, playing, onCommand})`: stores owner, callback and `_shown`; lazily creates an `AppLifecycleListener(onResume: retryShow)`; `_sendShow()` invokes `show {title, subtitle, playing, labels}` with labels = last `setLabels` or `mediaLabelsOf(L10n.current)`; `_showFailed` = native call failed.
- `retryShow()` (@visibleForTesting): when supported, owned, and the last show failed, re-sends it. Reason: Android 12+ refuses to start a foreground service from the background (a stream that starts playing behind a locked screen); the show is re-sent when the app returns to the foreground.
- `playing` getter: owner set and last shown state playing — used by the go-live poller (`playingInBackground`) because a playing background stream keeps the process alive.
- `hide(owner)`: only by the current owner; clears state, invokes `hide`.
- `_onCall`: `command {action}` with action `play|pause|stop` → `onCommand(MediaCommand)`; anything else ignored.
The IVS store shows it (setting `backgroundAudio` on, not stopped from the notification, status playing or reconnecting) with title = channel display name (login when empty) and subtitle = trimmed stream title; `playing` = not paused; it hides it otherwise. Media commands map to pause/play/stop of that player.

### lib/services/audio_focus.dart

Dart side of `onset/audio-focus`. `enum AudioFocusChange { loss, lossTransient, gain, noisy }` (permanent loss to another app/call; temporary loss; given back; headphones unplugged so audio would go to the speaker).

`class AudioFocus({MethodChannel? channel, bool? supported})`, default channel `onset/audio-focus`, supported = Android; `static final shared`. One player holds it at a time (last to request). Native failures logged (`AudioFocus <method> failed: <e>`), never thrown.
- `request(owner, onChange)`: unsupported → true. If someone already holds a granted focus, just transfers ownership/callback and returns true without a native call. Else invokes `request`; a platform failure (null) counts as granted (`?? true`: play on without focus). Returns `_granted`. False means Android refused for now (a call); `gain` follows (Android 8+).
- `abandon(owner)`: only by the current owner; clears and invokes `abandon`.
- `headphonesConnected()`: unsupported → null; else the native Bool or null on failure.
- Native `change {state}`: `gain` sets `_granted = true`, `loss` sets false, `lossTransient`/`noisy` leave it; then `onChange(change)`. The IVS store reacts: `lossTransient` pauses (marked paused-for-focus) if playing; `loss`/`noisy` pause (or, if already paused, abandon the focus); `gain` resumes only if it was paused for focus and no other player (a VOD on top) holds playback. A refused request pauses an automatic start but not a play the viewer chose; a pause from the notification/headphones during a call abandons focus so the call's end does not restart the stream.

### lib/services/floating_player.dart

Dart side of `onset/floating-player`. `class FloatingPlayer({MethodChannel? channel, bool? supported})`, `static final shared`, `supported` = Android.
- `onClosed` setter: stores the listener and (when supported) installs the handler: `closed {returned}` → `listener(returned == true)` (`returned` = the user tapped the window to come back to the app vs. closed it).
- `canDrawOverlays()` → Bool (`?? false`); `openPermissionSettings()` → Bool (`?? false`); `start({url, title, channelLabel, closeLabel})` → Bool (`?? false`); `stop()`.
- `_ask` returns null when unsupported or on any error (logs `Floating player <method> failed: <runtimeType>`).
Used by `lib/screens/channel/video/pop_out.dart` (`popOutLive`): needs the resolved usher URL (otherwise snackbar `popOutNotReady`); without overlay permission shows an explanation dialog (`popOutPermission*` keys, buttons "Not now"/"Continue") then opens the settings and waits for resume; on start the in-app player is prepared/paused (`prepareFloatingPlayer`) and restored on `closed` (`floatingPlayerClosed(returned:)`); falls back to Android PiP when the overlay is unavailable.

### lib/services/cast_bridge.dart

Dart side of `onset/cast`.
- `CastDevice {id, name}` (value equality on both).
- `enum CastConnection { disconnected, connecting, connected }`.
- `CastMedia {url, title, live, subtitle?, imageUrl?, start = Duration.zero}`; `toArguments()` → `{url, title, subtitle, imageUrl, live, startMs: start.inMilliseconds}`.
- `CastStatus(connection, {deviceName, deviceId})`, `CastStatus.disconnected`; `fromMap(raw)`: non-map → disconnected; `state` `'connected'`/`'connecting'`/else disconnected; `device`, `deviceId` kept only when Strings.
- `class CastBridge({MethodChannel? channel, bool? supported})` (supported = Android): `listen({onDevices, onStatus})` installs the handler for `devices` (list parsed keeping only maps with String `id` and `name`) and `state`; `startDiscovery()` → Bool (`start`, `?? false`); `stopDiscovery()` (`stop`); `status()` → `CastStatus.fromMap(state)`; `connect(device)` → Bool (`connect {id}`); `disconnect()`; `load(media)` → Bool. All calls return null/false when unsupported or failing (log `Cast <method> failed: <runtimeType>`).

### lib/services/network_metering.dart

Dart side of `onset/network` + event channel `onset/network/metered`. `class NetworkMetering({channel, events, supported})`, `static final shared`.
- `isMetered()` → `Future<bool?>`: null when unsupported or on error (log `Network metering unknown`).
- `changes()` → `Stream<bool?>`: empty when unsupported; otherwise `receiveBroadcastStream()` mapped to bool-or-null, errors logged (`Network changes unknown`) and skipped (later values still come), `.distinct()` (the same answer twice in a row arrives once).
Consumers: the IVS store, the clip player store and the VOD screen ask `isMetered` to apply the data-saving/"Wi-Fi only" autoplay and quality caps; the home live feed listens to `changes()` so feed previews stop the moment the device leaves Wi-Fi.

### lib/services/locale_bridge.dart

Keeps the app's own language setting and Android 13+'s per-app language (Settings › Apps › ONSET › Language) the same both ways. Elsewhere (Android < 13, iOS) native answers null and the app setting is the only one.

`class LocaleBridge({MethodChannel? channel, bool? supported, Future<SharedPreferences> Function()? prefs})`, channel `onset/locale`, `static final shared`. Preference key `system_app_language` = the system tag the app last set or adopted ("" = device language); a different system value means the user picked one in system settings.

- `tagOf(AppLanguage)`: system → `''`, en → `'en'`, fr → `'fr'`.
- `languageOf(tag)`: `''` → system; first subtag split on `[-_,]`, lower-cased: `en` → en, `fr` → fr, else null.
- `push(language)`: reads `get`; if the current system tag already means the same language (e.g. `fr-CA` for French) it is kept as the viewer chose it and stored as told; otherwise `set(tagOf(language))` and store the tag. Errors logged `Per-app language not set`.
- `systemLocales()` → `List<Locale>?`: invokes `systemLocales`, splits on `,`, parses each with `localeOfTag`, null when empty/unsupported/error (`System languages not read`); caches into `lastSystemLocales`. Needed because on 13+ Flutter's platform locales become the per-app language once set, so "System" must ask the device's real list.
- `localeOfTag(tag)`: trims, splits on `[-_]`; language must match `^[a-z]{2,8}$` (lower-cased) else null; region = first later part matching `^([a-zA-Z]{2}|[0-9]{3})$`, upper-cased; script parts dropped (`zh-Hant-TW` → `zh_TW`).
- `changedInSystem()` → `AppLanguage?`: reads `get`; null tag → null; if no stored told-tag (never told; the app tells first) or equal → null; otherwise stores the new tag (adopted) and returns `languageOf(tag)` (may be null for a language the app does not speak).
- Top-level `syncSystemLanguage(settings, bridge)`: `adopt()` = if `changedInSystem()` returns a language different from `settings.appLanguage`, `settings.chooseLanguage(picked)`. Runs adopt, then `push(settings.appLanguage)`, returns `adopt` so `main.dart` calls it on every resume; `main.dart` also pushes on each `appLanguage` change (MobX reaction).

### lib/services/notification_settings_link.dart

`class NotificationSettingsLink({channel, supported})`, channel `onset/notification-settings`, Android only. `listen(onOpen)`: installs a handler calling `onOpen()` on `open` (new intent while running), then invokes `consumeLaunch` and calls `onOpen()` if it returns true (the app was cold-started by the system's "app notification settings" link). Errors logged `Notification settings link unavailable`. `main.dart` reacts by pushing the Settings › Notifications page (`SettingsPageId.notifications`) after the next frame.

### lib/services/launch_info.dart

`class LaunchInfo {coldStart, nativeTile, fromLauncher = true}`; `LaunchInfo.none = (coldStart false, nativeTile false)`; `playsIntro = coldStart && fromLauncher`. Channel `onset/launch` (`@visibleForTesting static const channel`). `static final splashTile = ValueNotifier<Rect?>(null)` — where the Android 12+ splash drew its tile in logical pixels of the Flutter view, so the launch intro (`lib/widgets/launch/launch_intro.dart`) puts its tile at exactly that spot and the handover cannot jump.

- `load({timeout = 500 ms})`: installs `_onPlatformCall`, invokes `info` with the timeout. Returns `LaunchInfo(coldStart: info.coldStart == true, nativeTile: info.nativeTile == true, fromLauncher: info.fromLauncher != false)`. `MissingPluginException` (iOS) → `LaunchInfo(coldStart: true, nativeTile: false)` (each process start runs main once behind a plain launch screen). Any other error or timeout → `none` (never holds the launch). Called at the very start of `main()` without awaiting.
- `_onPlatformCall`: only `splashTile`, others throw `MissingPluginException`. Non-map args → false. Reads finite numbers `x`, `y`, `size`; missing or `size <= 0` → false. Sets `splashTile = Rect.fromCenter(center: (x,y), width: size, height: size)`, waits two `endOfFrame`s (the frame with the tile built, then one more so it is on screen), returns true — the native side removes its splash on that answer.

### lib/services/onset_updater.dart

In-app updater over GitHub Releases (`OnsetUpdateService` in `lib/apis/onset_update_service.dart`).

Result types (sealed `UpdateCheck`): `UpdateAvailable(release, currentBuild)`, `UpToDate`, `UpdateCheckSkipped` (off, checked recently, or postponed), `UpdateCheckFailed` (GitHub unreadable or no complete build). `UpdateInstallException` = Android could not install.

`class OnsetUpdater({token = updateToken, repo = updateRepo, isAndroid, service, installer = const OnsetInstaller(), currentBuild, now})`. `enabled = isAndroid && repo.isNotEmpty` — only Android builds produced by the update workflow (which bakes `UPDATE_REPO`, and `UPDATE_TOKEN` while the repo is private) make any request. Constants: `checkInterval = 6 h`, `postponeFor = 24 h`; prefs keys `onset_update_last_check`, `onset_update_postponed_build`, `onset_update_postponed_at` (all epoch ms / ints). `currentBuild()` = `int.tryParse(PackageInfo.buildNumber) ?? 0`.

`check({force = false})`:
1. Disabled → Skipped.
2. Not forced and last check < 6 h ago → Skipped.
3. `service.latest()`: `UpdateNotVisibleException` (tokenless build, private repo) → record last check, UpToDate; `UpdateRateLimitedException` (anonymous GitHub per-IP limit) → record last check, Failed; null release → Failed (no record, retried at next resume).
4. `release.build <= current` → record last check, UpToDate (only an up-to-date answer quiets the next checks; an available but uninstalled build is offered again on the next start, e.g. the process died on the "install unknown apps" page).
5. Not forced, postponed build == release.build and postponed < 24 h ago → Skipped.
6. → `UpdateAvailable(release, current)`.
`_since(millis, now)`: elapsed; a negative elapsed (clock set back) reads as `postponeFor` so a quiet period can never last forever.

`removeInstalledDownloads()`: `service.removeDownloadsUpTo(currentBuild)` — deletes downloaded APKs already installed or older (runs in every build); errors logged `Update cleanup failed`.
`postpone(release)`: stores build and now ("Later").
`canInstall()`, `openInstallSettings()` delegate to the installer.
`downloadAndInstall(release, {onProgress(received, total), cancelToken, onInstall})`: `service.download(...)` (throws its own download/verification errors, e.g. checksum, cancelled), then `onInstall()`, then `installer.install(path)`; `PlatformException` with code `install_aborted` → `UpdateCancelledException`, other codes → `UpdateInstallException`; `MissingPluginException` → `UpdateInstallException`. Provided app-wide via `Provider<OnsetUpdater>`.

### lib/services/onset_installer.dart

`class OnsetInstaller` (const) over channel `onset/updates`; `abortedCode = 'install_aborted'`.
- `canInstall()` → Bool; false on `PlatformException`/`MissingPluginException`.
- `openInstallSettings()` → swallows both exceptions (the update flow explains when nothing opens; not on Android).
- `install(path)` → `invokeMethod('install', {'path': path})`, completing with the installer's final answer (success, or PlatformException `install_aborted` / `install_failed` / `outside_updates` / `superseded`). Native guarantees: APK copied into a PackageInstaller session, only files in the app cache `updates/` directory, only an update of this package.

### lib/services/twitch_web_token_service.dart

`class TwitchWebTokenService({bool? isAndroid})` (const) over channel `onset/cookies`. Reads the twitch.tv web session token (`auth-token` cookie) from the in-app WebView's jar. Why: Twitch only serves enhanced-broadcast renditions (1440p60 HEVC/AV1) when the `PlaybackAccessToken` GQL request is authenticated, and GQL only honours allowlisted client ids; ONSET's OAuth token is for ONSET's client id and is rejected (measured). The real twitch.tv login performed in the login WebView leaves the cookie; reading it replaces a token the user previously pasted manually (the manual field in video settings remains the fallback).

- `twitchUrl = 'https://www.twitch.tv'` (the cookie is set on `.twitch.tv`).
- `isTwitchPageUrl(url)`: true for `about:blank`; else must parse, scheme `https`, host `twitch.tv` or `*.twitch.tv`. Used as the navigation guard of the hidden session WebView (JavaScript on, the viewer's cookies, invisible) — any redirect elsewhere (other sites, `intent:`, `file:`) is refused.
- `readAuthToken()`: non-Android → null; invokes `getCookie {url: twitchUrl}` and parses; PlatformException (logged) or MissingPluginException → null.
- `readAuthTokenFromPage(Future<Object?> pageCookies)`: awaits a JavaScript `document.cookie` result; non-String → null; a JSON-quoted string is `jsonDecode`d first; then parsed; errors logged → null. (Fallback path reading cookies from inside the page.)
- `parseAuthToken(raw)` (@visibleForTesting): splits on `;`, skips pairs without `=`, trims names, returns the trimmed value of the first exact `auth-token` name, empty value → null. Exact match matters: Twitch sets other cookies containing "token" (`twitch.lohp.countryCode`, CSRF pairs).
- `clearCookies()`: Android only; invokes `clearCookies`; errors logged/ignored. Called on logout so the next login does not silently reuse the previous account's session.

### lib/services/settings_persistence.dart

`const kSettingsSaveDelay = Duration(milliseconds: 300)`. `VoidCallback persistSettings(SettingsStore settings, void Function(String json) write, {Duration delay = kSettingsSaveDelay})` — writes the whole settings store as JSON (`jsonEncode(settings)`) to SharedPreferences key `settings` (the writer given by `main.dart`).

- `save()`: encodes; skips when identical to the last written JSON; else writes.
- A MobX `autorun(save, delay: 300 ms)` gathers changes: at most one write per 300 ms with the latest values. Reason: dragging the chat divider or a settings slider changes a setting every frame; writing each change encoded the full settings on the UI thread up to 144 times per second.
- A MobX `reaction` on `(shareCrashLogsAndAnalytics, telemetryConsentVersion, appLanguage, languagePromptVersion)` saves immediately (never gathered): other isolates (the go-live background worker) read these from disk, and they change rarely.
- `AppLifecycleListener(onHide: save, onPause: save)`: flushes at once when the app leaves the screen so nothing is lost to the app being killed.
- Returns a disposer: disposes both reactions and the lifecycle listener, then saves one last time.

Precision: `written` starts null and the delayed `autorun` runs once about 300 ms after start, so the first `save()` always rewrites the `settings` key at every launch, even when nothing changed.

### lib/services/cache_manager.dart

`class CustomCacheManager` — the image disk cache used for emotes, badges, avatars, thumbnails (via cached_network_image).
- `key = 'libCachedImageData'`; repo `CacheObjectProvider(databaseName: key)`; `instance = CacheManager(Config(key, stalePeriod: 30 days, maxNrOfCacheObjects: 10000, repo))`. Files live in `<temporaryDirectory>/libCachedImageData/`.
- `sweepDelay = 10 s`, `sweepMinAge = 1 h`.
- `scheduleOrphanSweep({sweep})`: after the first frame, a 10 s Timer runs `removeOrphanedCacheFiles(minAge: 1 h)` (unawaited), so startup is not slowed. Called from `main()`.
- `removeOrphanedCacheFiles({minAge = 0})`: if the cache dir exists, opens the repo, reads all objects' `relativePath`s and calls `deleteOrphans(cacheDir, known, olderThan: now − minAge)`; any error logged `Cache sweep failed: <runtimeType>`.
- `deleteOrphans(cacheDir, known, {olderThan})` (@visibleForTesting): lists files recursively; for each file whose path after `libCachedImageData/` is not in `known`, deletes it unless modified after `olderThan` (a file just being written by a download is spared). Per-file `FileSystemException` logged `Cache file not swept`. Purpose: files whose database rows were lost (crash mid-write, DB reset) otherwise leak forever.

### lib/services/seventv_cosmetics_cache.dart

`class SevenTvCosmeticsCache(SevenTVApi api, {batchWindow = 400 ms, batchSize = 20, capacity = 4000, setCapacity = 200, pauseAfterFailure = 5 min, now})` — 7TV per-user cosmetics (paint/name colour gradients, badges, personal emote set ids) for chat authors, fetched in batches.

- `_known: Map<twitchId, SevenTvUserCosmetics>` write-ordered (evicts the least recently *written*, not true LRU), capacity 4000. `cached(id)`; `remember(id, cosmetics)` re-inserts as MRU and evicts the oldest beyond capacity.
- `lookup(id)`: known → immediate value; already waiting → the same future; paused (within 5 min after a failure) → `SevenTvUserCosmetics.none`; else a Completer is queued and a single flush timer (`batchWindow` 400 ms) is started if none.
- `_flush()`: snapshots and clears the waiting map; processes ids in chunks of 20: if paused mid-way, completes the rest with `none` and returns; calls `api.getUsersCosmetics(batch)`; on error logs `7TV cosmetics unavailable`, sets `pausedUntil = now + 5 min`, treats as empty; each id found is remembered; every waiter completes with its cosmetics or `none` (a user without cosmetics is not remembered, so a later message may retry).
- `emoteSet(setId)`: memoised future per set id, LRU with `setCapacity` 200 (re-inserted on hit, oldest evicted before adding); fetches `api.getEmoteSet(id, type: EmoteType.sevenTVPersonal)`; on error removes the entry, logs `7TV emote set unavailable`, resolves `[]`.
- `forgetEmoteSet(setId)` removes a set (when 7TV announces a change).
- `dispose()`: cancels the timer and completes all waiters with `none`.

Precisions: the user map is **write-ordered**, not true LRU: `cached(id)` and `lookup(id)` hits do not refresh recency; only `remember` re-inserts (the emote-set map does refresh on hit). Logs print the full error: `7TV emote set unavailable: <error>`, `7TV cosmetics unavailable: <error>`. `dispose()` does not stop a `_flush` already running (it still completes its waiters and calls `remember`), and there is no disposed flag: a `lookup` after `dispose` starts a new flush timer.

### lib/services/shared_timer_service.dart

`SharedTimerService extends ChangeNotifier`, singleton `instance`. One 1-second `Timer.periodic` shared by all uptime displays (stream cards, channel info, profile live card, `widgets/uptime.dart`) so they tick together and only one timer exists.
- `currentTime` = last tick time (initialised at construction).
- `addListener` increments a counter and starts the timer on the first listener; `removeListener` decrements and stops it at zero.
- `pause()` sets paused and stops the timer; `resume()` (only if paused) clears it and, when listeners exist, sets `_lastTick = now`, notifies at once and restarts. `main.dart` wires `onPause`/`onResume` of an `AppLifecycleListener` to these (no ticking in the background).
- `_startTimer` does nothing while paused or already running. `dispose` stops the timer.

Defect (see Known Android defects): `removeListener` decrements the count unconditionally; removing a listener never added, or twice, drives the count below zero, after which `addListener` never sees exactly 1 and the shared tick never starts again for the rest of the process.

### lib/services/font_licenses.dart

`const interLicenseAsset = 'assets/fonts/OFL.txt'` (SIL Open Font License 1.1 of the bundled Inter font). `registerFontLicenses()` → `LicenseRegistry.addLicense` with a stream yielding one `LicenseEntryWithLineBreaks(['Inter'], text)`; called first thing in `main()` so the Licenses page lists Inter (fonts are assets, not packages, and are not listed automatically).

### lib/services/profile_image_picker.dart

`Future<ProfileImagePick?> pickProfileImage()` used by Edit profile (avatar and banner). Opens the gallery with `ImagePicker().pickImage(source: gallery, requestFullMetadata: false)` (no EXIF/location permission). Exception → `ProfileImagePick(null)` (logged `Picking a profile image failed`), which the screen shows as "could not use this image". Cancel → null (nothing happens). If the file length exceeds `ProfileImageFile.maxBytes` (10 × 1024 × 1024 = 10 MiB) → `ProfileImagePick(null)`. Else `ProfileImagePick(ProfileImageFile.fromNamed(name, bytes))` (the type is derived from the file name).

### lib/services/telemetry_consent.dart

- `firebaseCollectionFor(shared, {debug = kDebugMode})` = `shared && !debug` (a debug build never collects).
- `setFirebaseCollection(shared, {debug})` → `Telemetry.setCollectionEnabled(firebaseCollectionFor(...))`.
- `syncFirebaseCollection(settings, {debug})` → MobX `reaction` on `settings.shareCrashLogsAndAnalytics` with `fireImmediately: true`, applying at once and on every change wherever it is made (settings switch "Share crash logs and analytics", onboarding, settings reset). Returns the disposer; `main.dart` keeps it for the app lifetime.

### lib/services/telemetry.dart

Optional Firebase (Crashlytics, Analytics, Performance) behind one switch.

`FirebaseConfig {apiKey, appIdAndroid, appIdIos, messagingSenderId, projectId, storageBucket}`; `none` (all empty); `fromEnvironment` reads `--dart-define`s `FIREBASE_API_KEY`, `FIREBASE_APP_ID_ANDROID`, `FIREBASE_APP_ID_IOS`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_PROJECT_ID`, `FIREBASE_STORAGE_BUCKET`; `isComplete` = apiKey, messagingSenderId and projectId non-empty.

`firebaseOptionsFrom(config, platform)`: null if incomplete; app id per platform (android/iOS, others ''), empty → null; else `FirebaseOptions(apiKey, appId, messagingSenderId, projectId, storageBucket (null if empty), iosBundleId: 'app.onset' on iOS)`.

`abstract final class Telemetry` (static state `_enabled`, `_consented`):
- `enabled` (Firebase up in this isolate), `collecting` (= enabled && consented).
- `debugReset({firebaseUp = false})` for tests.
- `initialize({reportUncaught = true})`: already enabled → true; web → false; no options → false; `Firebase.initializeApp` failure → logs `Firebase unavailable`, false; else enabled, and with reportUncaught installs `FlutterError.onError = recordFlutterFatalError` and `PlatformDispatcher.instance.onError = handlePlatformError` (main isolate; the background worker passes false).
- `_guard` (runs only when enabled) / `_guardCollecting` (only when collecting) / `_call` (sync errors and async future errors are printed `Firebase call failed`, never rethrown — no re-reported uncaught error).
- `recordError(error, stack, {reason, fatal = false})` → Crashlytics, collecting only.
- `recordFlutterFatalError(details)`: not collecting, or `isImageLoadFailure(details)` (library `image resource service` or a `NetworkImageLoadException`: a deleted emote/missing avatar draws a placeholder, never a crash) → `FlutterError.presentError` only; else Crashlytics fatal.
- `handlePlatformError(error, stack)`: not collecting → false (engine logs it); else records fatal, returns true.
- `log(message)`, `setCustomKey(key, value)` — collecting only.
- `setCollectionEnabled(enabled)`: no-op unless enabled; sets consent; toggles Crashlytics, Analytics and Performance collection; when turning off, `deleteUnsentReports()` (reports kept on device are deleted unsent).
- `newHttpMetric(url, method)` → Performance `HttpMetric` only when collecting (method GET/POST/PUT/DELETE/PATCH, default GET), else null; used by the Dio interceptor for request traces.
- `navigatorObservers()` → `[FirebaseAnalyticsObserver]` when enabled (screen views; Analytics itself honours its own collection flag), else empty.
Native manifests start with every collection flag false and ad-id collection disabled.
## Per-file reference: realtime sockets and protocols

ONSET runs three independent realtime connections, all isolated from chat (IRC) and video so their failure never breaks those:
1. `TwitchRealtimeClient` — one shared anonymous Hermes socket for public topics used by the hype-train and community-highlights stores (created in `main.dart`, provided app-wide, wired to lifecycle pause/resume).
2. `HermesClient` — a per-channel Hermes socket owned by `ChannelEventsStore` (predictions, channel points, creator goals, celebrations, sub gifts, shared chat, shoutouts, community moments, content classification labels, video playback, broadcast settings, and user-scoped topics when a twitch.tv web token is available).
3. `TwitchEventSubClient` — one EventSub socket for the logged-in user's events (whispers today), with subscriptions created over Helix.

### lib/services/realtime/realtime_socket.dart

`abstract interface class RealtimeSocket { Stream<String> messages; void send(String); Future<void> close([int? code, String? reason]); int? closeCode; }` — a text websocket abstraction so the clients are testable without network. `typedef RealtimeSocketFactory = RealtimeSocket Function(Uri uri)`.

`WebSocketChannelSocket(Uri)` implements it over `web_socket_channel` (`dart:io`, which answers server websocket pings automatically). The constructor calls `WebSocketChannel.connect(uri)` and `ready.ignore()` (a failed connect also ends `messages`, which the clients handle; otherwise `ready` would report the same failure as an uncaught zone error). `messages` = channel stream filtered to `String` frames (binary frames dropped). `send` → `sink.add`; `close` → `sink.close(code, reason)`; `closeCode` → channel close code.

### lib/services/realtime/hermes_protocol.dart

Pure functions for Twitch's Hermes websocket (the successor of PubSub).

- `hermesEndpoint = wss://hermes.twitch.tv/v1?clientId=kimne78kx3ncx6brgo4mv6wki5h1ko` (`kTwitchWebClientId`, the twitch.tv web client id).
- Frames longer than 256 × 1024 characters are dropped (`HermesMalformed`). Default keepalive 15 s.
- Sealed `HermesFrame`: `HermesWelcome {sessionId?, keepalive, recoveryUrl?}` (recovery URL carries a session token: never log it), `HermesKeepalive`, `HermesSubscribeResult {parentId?, subscriptionId, ok, error?, errorCode?}`, `HermesUnsubscribeResult {parentId?, subscriptionId, ok}`, `HermesNotification {id?, subscriptionId, payload (topic JSON as string), serverTime?}`, `HermesReconnect {url?}`, `HermesUnknown(type)`, `HermesMalformed`.
- `decodeHermesFrame(text)` never throws: JSON must be a map with String `type`; reads `id`, `parentId`, `timestamp` (ISO, parsed leniently).
  - `welcome`: `welcome.keepaliveSec` used when a finite positive number, clamped 1..120 s (fractional seconds kept in ms), else 15 s; `sessionId`, `recoveryUrl`.
  - `keepalive`.
  - `subscribeResponse`: requires `subscribeResponse` map and `subscription.id`; `ok` = `result == 'ok'`; `error`, `errorCode`.
  - `unsubscribeResponse`: same shape, no error fields.
  - `notification`: requires `notification.subscription.id` and `notification.pubsub` either a String (kept) or a Map (re-encoded with jsonEncode); else malformed.
  - `reconnect`: `reconnect.url`.
  - other → `HermesUnknown(type)`.
- `encodeSubscribe({messageId, subscriptionId, topic, now})` → `{"type":"subscribe","id":<messageId>,"timestamp":<UTC ISO-8601>,"subscribe":{"id":<subscriptionId>,"type":"pubsub","pubsub":{"topic":<topic>}}}`.
- `encodeUnsubscribe({messageId, subscriptionId, now})` → `{"type":"unsubscribe","id":…,"timestamp":…,"unsubscribe":{"id":<subscriptionId>}}`.
- `enum HermesCloseKind { normal, reconnect, fatal }`; fatal close codes `{4010, 4111, 4112, 4120, 4121, 4122, 4123, 4130, 4131}`; `classifyHermesClose(code, {initiatedByUs = false})`: our own 1000 → normal; fatal set → fatal; everything else (including null) → reconnect.
- `isValidPubSubTopic(topic)`: regex `^[a-z0-9-]+(?:\.[a-z0-9-]+)*\.[0-9]{1,20}$` (`family.name.<numeric id>`; the id ends up in a frame so it is validated).
- `newHermesId(Random)`: RFC 4122 UUID v4 string (16 random bytes, version nibble 4, variant 10xx), lower-case hex with dashes 8-4-4-4-12.

### lib/services/realtime/twitch_realtime_client.dart

`TwitchRealtimeClient({connect, endpoint, random, idleClose = 30 s, backgroundGrace = 60 s, unsubscribeDelay = 500 ms, authTopicPrefixes = defaultAuthTopicPrefixes})` — one shared anonymous Hermes connection for public topics (`hype-train-events-v2.<channelId>`, community highlights). Default socket factory `WebSocketChannelSocket.new`, endpoint `hermesEndpoint`, random `Random.secure()`.

Public types: sealed `RealtimeTopicEvent` = `RealtimeMessage(payload, {serverTime})`, `RealtimeSubscribed({isResubscribe})` (after a resubscribe, messages in between were missed: consumers refetch their state), `RealtimeUnavailable(reason, {permanent = false})` (permanent: not before next session/app resume). `enum RealtimeConnectionState { idle, connecting, connected, reconnecting, paused, failed }` exposed as `state` and a broadcast `states` stream (only distinct changes emitted). `RealtimeTopicSubscription {topic, events, cancel()}` (idempotent; `forTesting` constructor).

`defaultAuthTopicPrefixes` (refused locally with `StateError('<topic> needs a logged-in session')` because Hermes accepts them anonymously but they need a user): `hype-train-events-v1.rewards.`, `whispers.`, `chatrooms-user-v1.`, `user-moderation-notifications.`, `community-points-user-v1.`, `predictions-user-v1.`, `private-callout.`.

Constants: backoff seconds `[1, 2, 4, 8, 16, 30]` with jitter ×0.8–1.2; healthy session 60 s (a session alive 60 s resets the attempt counter, and a close after a healthy session reconnects immediately); watchdog margin 5 s; fatal retry interval 5 min; server-reconnect loop interval 30 s.

Per-topic `_Topic`: broadcast controller, `refCount`, `subscriptionId`, `unsubscribeTimer`, `firstSession`, `status` (last Subscribed/Unavailable, replayed to each new listener; a replayed Subscribed is always `isResubscribe: false`). `events` is a `Stream.multi` that adds the replay then forwards the controller (pause/resume forwarded, cancel not awaited).

`subscribe(topic)`: throws `StateError` when disposed, `ArgumentError` for a malformed topic, `StateError` for auth topics. Cancels the idle timer, gets or creates the topic, cancels its pending unsubscribe, increments refCount. If state is `failed`: tries `_retryAfterFatal()`; still in the 5-min window → emits `RealtimeUnavailable('failed', permanent: true)`. Else if no socket → `_ensureConnected()`; else if welcomed and not subscribed → sends subscribe. Returns a handle whose cancel calls `_release`.

`_release`: decrement; at zero, after `unsubscribeDelay` (500 ms; a quick switch back to the same channel keeps the subscription) and still zero: if subscribed and welcomed sends unsubscribe; removes the topic; closes its controller; if no topics remain, cancels reconnect and starts the idle timer (30 s) which drops the socket, resets attempts and sets `idle`.

Lifecycle: `onAppPaused()` arms a 60 s grace timer; when it fires (unless state is `failed`) → paused, cancel reconnect, drop socket, state `paused`. `onAppResumed()` cancels grace; `failed` → `_retryAfterFatal()`; not paused but a reconnect timer pending with topics → attempts 0 and reconnect immediately (do not sit out the rest of a backoff); paused → unpause, attempts 0, `idle` if no topics else open.

Connection: `_openSocket()` cancels reconnect, drops any socket, `idle` if no topics; otherwise state `connecting` (first session) or `reconnecting`; factory exceptions → schedule reconnect; arms the watchdog immediately (no welcome within keepalive+5 s counts as dead); listens with `cancelOnError`. `_dropSocket()` cancels watchdog/healthy timers, clears socket, welcome, connectedAt and every topic's subscriptionId, closes with 1000 without reacting. `_onClosed(socket)` (ignores stale sockets): healthy if connected ≥ 60 s; fatal close code → `failedAt = now`, state `failed`, every topic gets `RealtimeUnavailable('closed <code>', permanent: true)`; otherwise `_scheduleReconnect(immediate: wasHealthy)`. `_scheduleReconnect`: nothing when disposed/paused; `idle` without topics; else `reconnecting`, every topic gets `RealtimeUnavailable('reconnecting')`, delay 0 (immediate) or `backoff[min(attempt,5)] s × jitter` then attempt++. `_retryAfterFatal()`: false within 5 min of the failure, else resets and reopens if topics exist. Watchdog = keepalive + 5 s, re-armed on every frame; when it fires: log `keepalive missed`, drop, schedule reconnect.

Frames: Welcome → welcomed, keepalive from server, re-arm watchdog, session count++, connectedAt, healthy timer (60 s → attempts 0), state `connected`, subscribe every topic with refCount > 0 (new random subscription id; `firstSession` set once). SubscribeResult ok → `RealtimeSubscribed(isResubscribe: firstSession < sessionCount)`; not ok → `RealtimeUnavailable(errorCode ?? error ?? 'subscribe failed', permanent: true)`. Notification → routed by subscription id (Hermes notifications do not name their topic) → `RealtimeMessage(payload, serverTime)`. Reconnect → if the previous server reconnect was ≥ 30 s ago (or none): attempts 0 and reopen at once; else drop and backoff (loop protection). Keepalive/Unsubscribe/Unknown/Malformed ignored. Send failures logged. Logging only in debug (`TwitchRealtimeClient <msg>`). `dispose()` cancels all timers, closes all topic controllers, closes the socket with 1000 and the states stream.

Precisions: `subscribe` with no socket calls `_ensureConnected()`, which does nothing while paused or while a reconnect timer is active (the topic waits for the resume or the timer). After a fatal close when no topics remain, a resume calls `_retryAfterFatal()`, which (once 5 min passed) clears `_failedAt` and resets attempts but opens nothing, so `state` stays `failed` until the next `subscribe`.

### lib/services/realtime/eventsub_protocol.dart

Pure functions for Twitch EventSub websocket.

- `eventSubEndpoint = wss://eventsub.wss.twitch.tv/ws`. Frames > 512 × 1024 chars dropped. Default keepalive 10 s.
- Sealed `EventSubFrame`: `EventSubWelcome {sessionId, keepalive}`, `EventSubKeepalive`, `EventSubNotification {messageId, subscriptionId, type, event: Map<String,Object?>, sentAt?}`, `EventSubReconnect(url)`, `EventSubRevocation {subscriptionId, type, status}`, `EventSubUnknown(type)`, `EventSubMalformed`.
- `decodeEventSubFrame(text)` never throws; requires `metadata.message_type`:
  - `session_welcome`: `payload.session.id` non-empty; `keepalive_timeout_seconds` finite > 0 clamped 1..600 s, else 10 s.
  - `session_keepalive`.
  - `notification`: requires `metadata.message_id`, `payload.subscription.id`, `payload.subscription.type`, `payload.event` map (non-String keys dropped); `sentAt` from `metadata.message_timestamp`.
  - `session_reconnect`: `payload.session.reconnect_url` must pass `isEventSubUrl` (the session token rides in the URL: only Twitch's host) else malformed.
  - `revocation`: `payload.subscription.id` required; `type` and `status` default "".
  - other → Unknown.
- `isEventSubUrl(url)`: scheme `wss`, no user info, host `eventsub.wss.twitch.tv` or ending `.eventsub.wss.twitch.tv`.
- `enum EventSubCloseKind { reconnect, fatal }`; `classifyEventSubClose(code)`: `4001` (client sent a frame, our bug: retrying would loop) → fatal; anything else → reconnect.

### lib/services/realtime/twitch_eventsub_client.dart

`EventSubTopic(type, version, condition: Map<String,String>)` with `key = '<type>/<version>/<k1=v1&k2=v2 sorted by key>'`, equality/hash on key. Example: `EventSubTopic('user.whisper.message', '1', {'user_id': id})`.

Events: sealed `EventSubTopicEvent` = `EventSubData(event, {sentAt})`, `EventSubListening({afterGap})` (events sent while not listening were missed), `EventSubUnavailable(reason, {permanent = false, unauthorized = false})` (unauthorized: no scope/expired/revoked — only logging in again helps). `EventSubCreate = Future<String> Function(EventSubTopic, String sessionId)` (Helix `POST /eventsub/subscriptions`, transport websocket with the session id; returns the subscription id), `EventSubDelete = Future<void> Function(String id)` (Helix `DELETE /eventsub/subscriptions?id=`). `EventSubHandle {topic, events, cancel()}` idempotent.

`TwitchEventSubClient({required create, required delete, connect, endpoint, random, idleClose = 5 s, backgroundGrace = 60 s, releaseDelay = 500 ms})`. Constants: backoff `[1, 2, 4, 8, 16, 30]` s with jitter ×0.8–1.2, healthy session 60 s, watchdog margin 5 s, `_seenLimit = 200` message ids for duplicate suppression.

Entry state: controller, refCount, subscriptionId, `creating`, `everListened`, `failed` (refused until listened anew or resume), `releaseTimer`, `status` replay (Listening replayed as `afterGap: false`); `wanted = refCount > 0 && !failed`.

`listen(topic)`: disposed → StateError; cancel idle; get/create entry; cancel release timer; a fresh first listener clears `failed`; refCount++. If `_fatal` → emit `EventSubUnavailable('closed', permanent: true)`; else no socket → open unless paused or a reconnect is pending; else if a session id exists → `_subscribe(entry)`.

`_release`: at zero refs after 500 ms: delete the subscription quietly, remove entry, close controller; if nothing is wanted: cancel reconnect, idle timer 5 s → drop sockets, attempts 0 (Twitch closes a session without subscriptions anyway).

Lifecycle: `onAppPaused` → 60 s grace then paused, cancel reconnect, drop sockets. `onAppResumed` → cancel grace; if it was paused or fatal: clear fatal, attempts 0, clear every `failed`, open if anything wanted; else if a reconnect timer is pending and something wanted → attempts 0, open now.

Connection: `_open()` drops sockets, returns if nothing wanted, connects (exception → schedule reconnect), clears session id, arms watchdog, listens. Session move (`session_reconnect`): `_move(url)` opens a second socket `_next` while keeping the current one; a connect exception drops everything and schedules a reconnect. Frames from `_next` are ignored except its Welcome → `_onMoved`: `_next` becomes current, session id and keepalive updated, watchdog re-armed, old socket closed with 1000 — subscriptions carry over (session counter not bumped). If the old socket closes before the new welcome, `_next` is promoted and `_awaitingMoveWelcome` set; that welcome keeps subscriptions too. If `_next` itself closes, the move just failed and the current socket carries on. `_dropSockets()` cancels timers, closes next and current with 1000, clears session id and move flag, bumps `_session` (answers for the dropped session become stale), clears subscription ids.

`_onClosed` (current socket, no pending move): drop; fatal close (4001) → report to Telemetry `StateError('EventSub closed the socket: <code>')` reason `eventsub close`, `_fatal = true`, every entry gets `EventSubUnavailable('closed <code>', permanent: true)`; else schedule reconnect (every wanted entry gets `EventSubUnavailable('reconnecting')`, delay backoff × jitter, attempt++; no immediate path here). Watchdog keepalive + 5 s; on fire drop and reconnect.

Frames on the current socket (watchdog re-armed): Welcome (not a move) → new session: session id, keepalive, `_session++`, healthy timer 60 s → attempts 0, every entry's id cleared and each wanted entry subscribed. Notification → duplicate `messageId` dropped (set of last 200 ids, oldest evicted) → `EventSubData` to the entry with that subscription id. Reconnect → `_move(url)`. Revocation → entry loses its id, `failed = true`, emits `EventSubUnavailable(status, permanent: true, unauthorized: status == 'authorization_revoked')`.

`_subscribe(entry)`: requires a session id, not already creating or subscribed. Calls `create(topic, sessionId)`; if disposed, the session changed or no longer wanted → deletes the new subscription (only if the same session) and returns; else stores the id and emits `EventSubListening(afterGap: everListened)`. Errors: logged; non-`ApiException` errors reported to Telemetry (reason `eventsub subscribe`); if the session changed, nothing; HTTP 400/401/403/404 → permanent (entry failed); emits `EventSubUnavailable('<error>', permanent, unauthorized: status 401 or 403)`. Finally: if the session changed meanwhile and the entry is still wanted, retries for the new session. Deletes are fire-and-forget; non-API errors reported (reason `eventsub delete`). `dispose()` cancels timers, deletes every subscription, closes controllers, drops sockets.

### lib/services/hermes_client.dart

`HermesClient({WebSocketChannel Function(Uri)? connect, Future<String?> Function()? tokenProvider})` — the per-channel Hermes client used by `ChannelEventsStore`. Uses the official Android client id `kd1unb4b3q4t58fwlpcbzcbnm76a8fp` (GQL and Hermes refuse non-allowlisted ids): endpoint `wss://hermes.twitch.tv/v1?clientId=kd1unb4b3q4t58fwlpcbzcbnm76a8fp`. Two verified facts recorded: notifications never name their topic (routing needs the client's own subscription-id map), and channel-scoped topics need no authentication (only `*-user-v1`).

`HermesEvent {topic, type, data}` (toString `HermesEvent(topic, type)`); `events` broadcast stream of all topics.

Constants: default keepalive 15 s (from `welcome.keepaliveSec`, parsed by `HermesMessage.keepaliveInterval` clamped 5..120 s); silence factor 3 (no frame for 3 × keepalive → reconnect); max backoff 60 s.

State: `_desiredTopics` (source of truth surviving reconnects), `_pendingSubscribes` (request id → topic), `_subscriptionTopics` (server subscription id → topic), `_reconnectAttempts`, `_sessionReady` (welcomed and authenticated), `_paused`, `_disposed`. `isConnected` = channel non-null.

- `pause()`: background — paused, cancel reconnect, tear down socket (keeps desired topics). `resume()`: unpause, attempts 0, connect if topics exist.
- `connect()`: no-op if disposed, paused or connected; `_openSocket(endpoint)`: listen (`onError` logs and reconnects; `onDone` reconnects), arm silence timer; connect exception → reconnect.
- `subscribe(topic)`: adds to desired; before the session is ready just ensures connection (the welcome replays the set; subscribing earlier would duplicate every event); else sends only if new. `subscribeAll(topics)` sequentially.
- `unsubscribe(topic)`: removes from desired; if mapped, removes the mapping and sends unsubscribe.
- Frames: subscribe `{id: requestId, type:'subscribe', timestamp, subscribe:{id: <new id>, type:'pubsub', pubsub:{topic}}}`; unsubscribe `{id, type:'unsubscribe', timestamp, unsubscribe:{id: subscriptionId}}`; authenticate `{id, type:'authenticate', timestamp, authenticate:{token}}`; ping `{id, type:'ping', timestamp}`. Ids `'<microsecondsSinceEpoch>-<random 0..2^32>'`; timestamps UTC ISO-8601.
- `_onFrame`: non-String ignored; re-arms silence timer; handles inside try (a bad frame costs that frame, never the socket). `HermesMessage.tryParse` null → dropped.
  - welcome → attempts 0, keepalive, `_armKeepalive()` (ping every 0.6 × keepalive), clear both maps (ids are per-session), `_startSession()`: authenticate (token provider failure or empty token → skip, channel topics still work anonymously), then if still the same socket → session ready and subscribe every desired topic (strict order: Hermes refuses a `*-user-v1` subscribe that arrives before authenticate).
  - subscribeResponse → matched by `parentId`; not ok → log `Hermes refused <topic>`; ok with id: if the topic is no longer desired → send unsubscribe; else map it.
  - notification → topic by subscription id; payload required; payload `type` required unless the topic sends untyped payloads (`content-classification-labels-v1.`); `data` = whole payload when untyped or the topic sends flat payloads (`video-playback-by-id.`, `broadcast-settings-update.`, `channel-sub-gifts-v1.`), else `payload.data` (or {}); emits `HermesEvent`.
  - reconnect → attempts 0 then schedule reconnect (a clean restart, not charged as an error).
  - revocation → mapping removed and the topic re-subscribed.
  - parseError → logs only the error code (the echoed frame contains the token).
  - keepalive ignored; other types log `responseError` if any.
- `_send(frame)`: no-op without a socket; a sink exception logs `Hermes send failed` and schedules a reconnect.
- `_scheduleReconnect()`: no-op if disposed, paused or a reconnect is pending; tears down; `base = min(60000, 500 × 2^attempts)` ms; delay = `base/2 + random(0..base/2)` (full jitter on the upper half so all viewers do not reconnect in lockstep); attempts++.
- `_teardownSocket()`: session not ready, cancel keepalive and silence timers, cancel the subscription, close the sink, clear both maps.
- `dispose()`: disposed, cancel reconnect, teardown, clear desired topics, close the events stream.

Precisions: the keepalive comes from `HermesMessage.keepaliveInterval` (`lib/models/hermes.dart`) as `Duration(seconds: seconds.toInt().clamp(5, 120))` — whole seconds, truncated (15.9 s → 15 s), unlike the shared protocol which keeps milliseconds and clamps 1..120. `resume()` returns early when not paused and `pause()` when already paused. `_teardownSocket` closes the sink without a close code. Message ids use a non-secure `Random()` (`'<µs>-<random>'`), not UUIDs.

## Per-file reference: go-live checks and notifications

Notification channels used by ONSET (Android; all re-named on every post with `AndroidNotificationChannelAction.update`, which keeps the user's per-channel settings and only changes name/description when the language changes):

| Channel id | Name (EN / FR ARB key) | Description key | Group key | Posted by |
|---|---|---|---|---|
| `go_live` | `notifChannelGoLive` "Go-live notifications" / "Lives des chaînes suivies" | `notifChannelGoLiveDescription` "When channels you follow go live" / "Quand une chaîne que vous suivez lance un live" | `onset.goLive` | `GoLiveNotifications` (app and background isolate) |
| `chat_mentions` | `notifChannelMentions` "Chat mentions" / "Mentions dans le chat" | `notifChannelMentionsDescription` "When someone mentions you in a chat you’re watching while ONSET is in the background" / "Quand quelqu’un vous mentionne dans un chat ouvert en arrière-plan" | `onset.mentions` | `MentionNotifications` |
| `schedule_reminders` | `notifChannelReminders` "Stream reminders" / "Rappels de lives" | `notifChannelRemindersDescription` "When a scheduled stream you set a reminder for starts" / "Quand commence un live prévu pour lequel vous avez activé un rappel" | `onset.reminders` | `LocalReminderPlatform` |
| `playback` | `mediaChannel` "Playback" / "Lecture en cours" | — | — | `BackgroundAudioService` (native, id 7301) |
| `onset_floating_player` | `popOutNotificationChannel` "Floating player" / "Lecteur flottant" | — | — | `FloatingPlayerService` (native, id 4207) |

iOS thread identifiers: `go_live`, `chat_mentions`, `schedule_reminders`. Small icon for plugin notifications: `ic_stat_go_live`.

Notification ids: go-live reserved `0` (= "N more" notice), `1` (problem), `2` (group summary); go-live notice id = FNV-1a 31-bit of `'<userId>|<startedAt>'` over UTF-8 bytes, shifted by +3 when < 3; mention id = `stableNoticeId('mention:<channelId>')` (XOR 1 if it equals the numeric channel id); reminder id = `stableNoticeId('reminder:<segmentId>')`. Payloads: go-live = bare login; mention = `mention:<login>`; reminder = bare login.

### lib/services/go_live/go_live_poller.dart

`const kGoLiveAppInterval = Duration(seconds: 90)`. `class GoLivePoller({required Future<void> Function() check, required bool Function() playingInBackground, interval = 90 s})` runs the go-live check while the app process is alive: in front (resumed), in picture-in-picture (inactive), or in the background while a stream plays with the media notification (`BackgroundAudio.shared.playing`). The 15-minute WorkManager task covers the rest. Nothing runs once the app is gone.

- `running` = a timer exists. `_inFront` = resumed or inactive. `_alive` = not disposed, not detached, and (in front or playing in background).
- `start()`: state resumed, `_resume()` → if no timer: `Timer.periodic(interval, _tick)` and an immediate `_run()`.
- `onLifecycle(state)` (wired to `AppLifecycleListener.onStateChange`): store state; resumed → `_resume()` (immediate check + timer if stopped); otherwise stop if not alive.
- `_tick()`: not alive → stop; else run.
- `_run()`: never overlaps (`_checking` flag); errors logged `Go-live check failed: <e>`.
- `dispose()` stops for good.
`main.dart` builds it with a check that first awaits `GoLiveNotifications.ready` (timeout 20 s; nothing can show before the plugin is initialised), then `checkGoLiveInApp(api, prefs: GoLivePrefs.load(), loggedIn, notify: GoLiveNotifications.show(notices, more, L10n.current) + ActivityStore.addAll(goLiveEntry...))`, and `playingInBackground: () => BackgroundAudio.shared.playing`.

Precisions: `onLifecycle` stores the state even after `dispose()` (then returns). A stream starting to play in the background while the poller is stopped does not restart it: only a transition to `resumed` restarts the timer (the "playing in background" condition only keeps an already running timer alive).

### lib/services/go_live/go_live.dart

`GoLivePrefs(SharedPreferences)` — state shared through plain SharedPreferences between the app and the background isolate (each isolate keeps its own cache, hence `reload()`). Keys:
- `go_live_enabled` (bool, default false). `setEnabled(true)` from false first clears `seen` (who went live while it was off is not announced).
- `go_live_muted` (string list of channel ids whose bell is off; every followed channel notifies unless muted, like Twitch). `setMuted(id, bool)`.
- `go_live_user_id` (viewer whose followed channels are checked). `setUserId(id)`: unchanged → no-op; otherwise clears `seen` (another viewer: start over without a burst) and stores/removes.
- `go_live_seen` (string list: followed channel ids live at the last check; null before the first check).
- `go_live_problem` (string code; `kGoLiveLoggedOut = 'logged_out'`; the legacy English value `kGoLiveLoggedOutLegacy = 'Log in again to get go-live notifications.'` is read back as `logged_out`). `setProblem(null)` removes.
- `go_live_checked_at` (int epoch ms, when the last check of either isolate started). `checkedWithin(gap, now)` = last exists, now not before last (a clock set back does not count), and difference < gap.
- `go_live_announced` (string list of `'<channelId>@<startedAt>'`; parsed only when `@` is at index > 0) — the broadcast last announced per channel: at most one notice per broadcast.

`newlyLive({wasLive, live, muted = {}, announced = {}})`: empty when `wasLive` is null (first check announces nobody); else streams not in `wasLive`, not muted, and (startedAt empty or announced[id] != startedAt).

`typedef GoLiveNotice = ({userId, login, name, streamTitle, category, title, body, startedAt, gameId, avatarUrl?})`. `goLiveNotice(stream, [l, avatarUrl])`: name = display name or login when empty; streamTitle trimmed; title = `notifGoLiveTitle(name)` ("{name} is live" / "{name} est en direct"); body = `streamNoticeBody(l, title, category)` (EN "{title} · {category}", FR "{category} · {title}", or whichever exists alone, or empty).

Ids: `kGoLiveMoreId = 0`, `kGoLiveProblemId = 1`, `kGoLiveSummaryId = 2`, `kGoLiveReservedIds = {0,1,2}`; `goLiveNoticeId(notice) = goLiveNoticeIdOf('<userId>|<startedAt>')`; `goLiveNoticeIdOf(key)` = FNV-1a (offset `0x811c9dc5`, prime `0x01000193`, 32-bit) over UTF-8 bytes, masked to 31 bits; ids < 3 get +3. The same broadcast always gets the same id, so the app and the background task announcing it at the same moment replace one notice.

`goLiveCategoryArtUrl(notice)`: when `gameId` matches `^[0-9]{1,20}$` → `https://static-cdn.jtvnw.net/ttv-boxart/<gameId>-144x192.jpg`, else null. `isTwitchImageUrl(url)`: https and host exactly `static-cdn.jtvnw.net`. `goLiveAvatars(api, streams)`: Helix users by ids → map id → profileImageUrl (only Twitch CDN URLs); errors → {} (logged `Go-live avatars unavailable`).

`goLiveEntry(notice, at)` → `ActivityEntry(id: 'live:<userId>:<startedAt>', kind: live, title, body, login, at, params: {name, title?, category?})`.

Constants: `kMaxGoLiveNotices = 5`; `_maxPages = 3` pages of 100 followed streams (max 300 live followed channels read per check); `kGoLiveMinGap = 60 s`; announced memory 24 h.

`checkGoLive({api, prefs, notify, minGap, now})`:
1. Disabled or no user id → 0.
2. With `minGap` and a check started within it → 0 (skipped).
3. `setCheckedAt(now)` before reading Twitch (claims the slot so a concurrent check skips).
4. Reads Helix `GET /streams/followed?user_id=<id>&first=100&after=<cursor>` up to 3 pages (stops on no cursor or empty page).
5. `fresh = newlyLive(seen, live, muted, announced)`. If non-empty: take the first 5, fetch avatars, build notices (wording in `L10n.current` of this isolate), `notify(shown, fresh.length − shown.length)`.
6. `seen` = ids of all live streams.
7. `announced` = previous entries whose startedAt parses and is within the last 24 h, plus every live stream with a non-empty startedAt (announced or not — live at the first check, muted — so a flicker off/on stays quiet).
8. Returns fresh count. Twitch or notify failures throw (state not updated → nothing lost; a double announce replaces its own notice).

`checkGoLiveInApp({api, prefs, loggedIn, notify, now})`: logged out → 0; `prefs.reload()` (the background task may have run); `checkGoLive(..., minGap: 60 s)`.

`runGoLiveTask({readToken, buildApi, prefs, notify, notifyProblem, report, now})` (one background run; true = done, false = ask the system to retry):
- disabled → true; checked within 60 s → true; token null (logged out) → true; reload prefs and re-test the 60 s gap (the app may have checked meanwhile) → true.
- `checkGoLive(..., minGap 60 s)` then `setProblem(null)` → true.
- `UnauthorizedException` (Twitch refused the token): if the stored problem is not already `logged_out`, store it and `notifyProblem` once → true (notices paused until next login).
- Other errors: `NetworkException`/`TimeoutException` are expected and not reported; anything else → `report(error, stack)`; returns false (retry).

Precisions:
- In `runGoLiveTask`, the unreported transient errors are the app's own classes from `lib/apis/base_api_client.dart`: `NetworkException` and `TimeoutException` (the latter `extends ApiException`, default kind `connectionTimeout`). A `dart:async` `TimeoutException` is not one of them: it is reported and the task returns false (retry).
- `goLiveNotice` trims the stream title (`streamTitle`) but stores `category` untrimmed (`stream.gameName`); `goLiveEntry` adds `category` to the Activity params whenever it is non-empty, so a whitespace-only category is kept (the body itself is built by `streamNoticeBody`, which trims both).

### lib/services/go_live/go_live_worker.dart

Background (WorkManager) side, runs in its own isolate.

- Task name `onset.goLive` (`_task`). `kGoLiveInterval = 15 min` (Android's minimum; runs when the phone allows it).
- `goLiveHeaders(token, {tokenClientId})` → `{'Client-Id': tokenClientId ?? clientId, 'Authorization': 'Bearer <token>'}` (a token issued to another app is only accepted with that app's client id, kept in secure storage under `AuthBase.userTokenClientIdKey`).
- `_login` regex `^[a-zA-Z0-9_]{1,25}$`.
- `sharesCrashLogsIn(savedSettingsJson)`: default false; false when null, not a map, `telemetryConsentVersion` missing/non-int/below `kTelemetryConsentVersion` (the task may run after an update before the app migrated its settings), or non-bool value; else `shareCrashLogsAndAnalytics`. FormatException → false.
- `initGoLiveTelemetry({readSettings, startFirebase, setCollection})`: if the viewer does not share (read failures count as no) → Firebase is never started; else start Firebase and, if it started, read the settings again right before `setCollection(shares)` so an opt-out made meanwhile wins. Production wiring: settings read via `SharedPreferences.reload()` + key `settings`, `Telemetry.initialize(reportUncaught: false)`, `setFirebaseCollection`.
- `useBackgroundLanguage(prefs, deviceLocales, {report})`: reloads prefs, `uiLanguageIn(saved: prefs[kUiLanguagePrefsKey], settingsJson: prefs['settings'], device)`, `initializeDateFormatting(language)`, `L10n.use(Locale(language))`; any failure → report (or log `Background language not read`) and fall back to English. Returns `L10n.current`.
- `goLiveCallbackDispatcher()` (`@pragma('vm:entry-point')`): `Workmanager().executeTask`; other task names → true. Initialises telemetry, defines `report` (log + `Telemetry.recordError(reason: 'go-live background check')`), then: language, `GoLiveNotifications.init()`, reads the token client id (errors reported), and returns `runGoLiveTask(readToken: secure storage AuthBase.userTokenKey, buildApi: TwitchApi(Dio(headers: goLiveHeaders, connectTimeout 10 s, receiveTimeout 15 s)), prefs, notify: show + add Activity entries (Activity failure reported, not re-announced), notifyProblem: showProblem(l), report)`. Any uncaught error → report, false.
- `GoLiveScheduler` (Android only; iOS gives no dependable periodic background time): `_init()` once `Workmanager().initialize(goLiveCallbackDispatcher)`; `start()` registers a periodic task (unique name and task `onset.goLive`, frequency 15 min, constraint network connected, `ExistingPeriodicWorkPolicy.update`); `stop()` cancels by unique name. Started/stopped with the go-live setting.
- `GoLiveNotifications`:
  - `detailsFor(l)`: channel `go_live`, name/description from ARB, group `onset.goLive`, channel action update, `onlyAlertOnce: true` (a re-post replaces silently); iOS thread `go_live`.
  - `detailsForNotice(l, {avatar, categoryArt})`: same plus `largeIcon` = avatar bitmap; when category art exists, `BigPictureStyleInformation(art, largeIcon: avatar)` (expanded notification shows the 144×192 box art).
  - `summaryDetails(l)`: same channel, `setAsGroupSummary: true`.
  - `maxImageBytes = 2 MiB`, `imageTimeout = 8 s`. `downloadImage(url, {dio})`: only Twitch CDN URLs; Dio connect/receive 5 s; streamed GET, no redirects, only status 200, aborts above 2 MiB or after 8 s (cancel token) → null; any error → null (logged `Go-live image unavailable`).
  - `ready` completes after `init`. `init({onOpen, onMention})`: initialises the plugin with Android icon `ic_stat_go_live` and iOS settings that do not request permissions at init; tap handler: payload that is a login → `onOpen(login)`; `mention:<login>` → `onMention(login)`.
  - `loginOf(payload)` (regex login) and `mentionLoginOf(payload)` (prefix `mention:`).
  - `launchNotice()` → `(login, mention: false|true)` when the app was launched by tapping one of these, else null.
  - `requestPermission()`: Android `requestNotificationsPermission()` (13+ runtime prompt) or iOS `requestPermissions(alert, sound)`; false when unavailable.
  - `allowed()`: Android `areNotificationsEnabled()` (default true); other platforms true.
  - `showProblem(l)`: id 1, title `notifGoLivePaused` ("Go-live notifications paused" / "Notifications de live en pause"), body `goLiveLogInAgain` ("Log in again to get go-live notifications." / "Reconnectez-vous pour recevoir les notifications de live.").
  - `show(notices, more, l)`: for each notice, downloads avatar and category art in parallel, posts with its stable id, title, body (null when empty), payload = login. If more than one notification results (notices + "more"), posts the group summary (id 2, title `notifChannelGoLive`). If `more > 0`, posts id 0 with `notifGoLiveMore(count)` ("{count} more channel(s) went live" / "{count} autre(s) chaîne(s) est/sont en direct").

Precisions (verified against the code):
- In `goLiveCallbackDispatcher`, `_initTelemetry()` is awaited **before** the `try`: a throw from Firebase start-up escapes `executeTask` (no report, no `false` returned). Errors of `readSettings` are caught inside `initGoLiveTelemetry`; errors of `startFirebase` (`Telemetry.initialize` catches its own `initializeApp` failure) or `setCollection` are not. (Defect.)
- `summaryDetails` has no iOS `threadIdentifier` (Android details only). The summary (id 2) has a title only (`notifChannelGoLive`), no body, no payload; the "more" notice (id 0) has a title only and no payload, so tapping it just opens the app. Post order: each notice, then the summary, then the "more" notice.
- `show` handles notices **sequentially**: for each notice, its avatar and category art are downloaded in parallel, then it is posted, before the next notice starts (worst case 5 × 8 s of image waits).
- `GoLiveScheduler.stop()` calls `_init()` (`Workmanager().initialize`) before `cancelByUniqueName`, even when the task was never started.

### lib/services/notifications/notice_ids.dart

`int stableNoticeId(String key)`: FNV-1a over UTF-16 code units (offset `0x811c9dc5`, prime `0x01000193`, 32-bit), masked to 31 bits; ids 0 or 1 become +2 (0 and 1 are the go-live "more" and problem notices). Stable across launches so a re-post replaces and a cancel finds the same notification. (Note the go-live notice id uses UTF-8 bytes and reserves 0–2; this one uses code units and reserves 0–1.)

### lib/services/notifications/activity_log.dart

The Activity screen's history of notifications ONSET posted on this device.

- `enum ActivityKind { live, mention, reminder }` (labels in `enum_labels.dart`).
- `storedDate(ms, {isUtc})`: DateTime from epoch ms when an int with |ms| ≤ 8 640 000 000 000 000, else null (damaged storage).
- `streamNoticeBody(l, {title, category, none = ''})`: trims both; no title → category or `none`; no category → title; both → `notifStreamBody(title, category)`.
- `ActivityEntry {id, kind, title, body, at, login?, read = false, params?}`: id unique per event (`live:<userId>:<startedAt>`, `mention:<channelId>:<messageId>`, `reminder:<segmentId>`). `title`/`body` = words as posted (shown for older entries without params). `titleIn(l)`: live → `notifGoLiveTitle(name)`, reminder → `notifReminderTitle(name)`, mention → `notifMentionTitle(sender, channel)` when params allow, else stored title. `bodyIn(l)`: without params or `name` → stored body; live → `streamNoticeBody(title, category)`; reminder → same with `none: notifReminderUntitled`; mention → stored body (the message text as written). So the list re-words itself when the language changes. `copyWith(read)`. JSON: `{id, kind: name, title, body, login?, at: epoch ms, read, params?}`; `fromJson` returns null for anything malformed or an unknown kind; `login` kept only if it matches `^[a-zA-Z0-9_]{1,25}$`; params keep only String→String pairs.
- `ActivityLog(SharedPreferences)`: keys `activity_log` (string list of JSON entries) and `activity_viewed_at` (int epoch ms). `maxEntries = 100` (oldest dropped). `load()`, `reload()`. `entries`: decoded (damaged entries dropped), sorted newest first. `unreadCount`. `viewedAt`/`setViewedAt` (what came after is "new" for the bell badge). `_save` sorts and keeps the 100 newest. All mutations are serialised in-process through a promise chain (`_serial`; failures do not break the chain); across isolates there is no lock (a simultaneous app/background write may drop one entry; accepted). `add(entry)` → bool; `addAll(entries)` reloads, adds ids not already present, saves when anything was added, returns count; `markRead(id)`, `markAllRead()`, `remove(id)`, `clear()` (removes the key).

Precisions: `entries` catches only `FormatException` while decoding; every mutation (`addAll`, `markRead`, `markAllRead`, `remove`) rewrites the list from `entries`, so a damaged entry is permanently deleted from storage at the next change. `addAll` dedupes only against the (at most 100) entries kept, so an id already dropped by the cap can be added again.

### lib/services/notifications/mention_alerts.dart

Chat-mention notifications while the app is not in front (background or PiP).

- `ChatMention = ({messageId, channelId, channelLogin, channelName, fromName, text})`; `MentionNotice = ({messageId, channelId, channelLogin, sender, channelName, title, body})`.
- `kMentionThrottle = 30 s` (one notice per channel per window); `kMentionMaxLength = 200` characters.
- `chatMentionOf(message, {ownLogin, channelId, channelLogin, channelName})` → null unless: logged in, command is PRIVMSG, the message is flagged as a mention (same rule the chat uses to highlight), has text, is not a history message (`tags['historical'] == '1'`), and is not from the viewer (case-insensitive). messageId = `tags['id']` or `'<tmi-sent-ts>'`; fromName = `display-name` or the login.
- `alertChatMention(message, {enabled, ownLogin, channelId, channelLogin, channelName, alerts})` → null when disabled or not a mention, else `alerts.onMention(...)`. Called (unawaited) by `ChatStore` for each displayed incoming message with `enabled: settings.mentionNotifications`, own login, channel id/login/display name.
- `_oneLine(text, max)` = `whisperPreview(text)` (single line, collapsed whitespace) cut to `max` chars plus `…`.
- `enum MentionTap { bringToFront, backToChannel, notice, restoreMini, openChannel }` and `mentionTapFor(login, {open, shown, closable, miniLogin})`: open & shown → bringToFront; open & closable → backToChannel (pop the pages above); open & not closable → notice (in-app message says where the mention is); not open & the mini player shows that login (case-insensitive) → restoreMini; else openChannel.
- `mentionClosablePages = {'Settings', 'ReleaseNotes', 'ChannelProfile', 'ChannelVideos', 'CategoryStreams', 'TagStreams', '/search', '/followed-videos', '/continue-watching'}`, `mentionClosableSettingsPrefix = 'Settings/'`; `mentionMayClose(namesAbove)` = every route name above the channel is closable (players, VODs, clips, whispers, dialogs, sheets, unnamed routes are never closed).
- `mentionEntry(notice, at)` → `ActivityEntry(id: 'mention:<channelId>:<messageId>', kind: mention, login: channelLogin, params: {sender, channel})`.
- `mentionNoticeId(channelId)` = `stableNoticeId('mention:<channelId>')`, XOR 1 if equal to the numeric channel id.
- `MentionAlerts({post, inFront, throttle = 30 s, now, words})`; `static shared` = inert until the app sets it. `onMention(m)`: in front → false; within throttle for that channel → false; records the time; sender and channel cut to 25 chars, title `notifMentionTitle(sender, channel)` ("{sender} mentioned you in {channel}" / "{sender} vous mentionne dans le chat de la chaîne {channel}"), body = message cut to 200; `post(notice)`; failure → logged, throttle slot released (the next mention may try), false.
- `appInFront()` = lifecycle state resumed (PiP is inactive → not in front).
- `MentionNotifications.detailsFor(l)`: channel `chat_mentions`, group `onset.mentions`, update action, category `message`; iOS thread `chat_mentions`. `allowed()` like go-live. `show(notice, [l])`: id `mentionNoticeId`, title, body, payload `mention:<login>`.

Precisions (verified against the code):
- `chatMentionOf` rejects only `text == null`; an empty message text passes.
- When the message has no `id` tag the fallback is the string interpolation `'${message.tags['tmi-sent-ts']}'`, which is the literal `"null"` when that tag is missing too, producing the Activity id `mention:<channelId>:null` (two such mentions in one channel collapse into one entry). (Defect.)
- `MentionNotifications.detailsFor` sets no `onlyAlertOnce`: every post (after the 30 s throttle) alerts again even though it replaces the channel's previous notice; the body is passed even when empty.

### lib/services/notifications/schedule_reminders.dart

"Remind Me" on a channel's schedule, kept on the device as local notifications (Twitch's own reminder is a private mutation pushed from its servers).

- `ScheduleReminder {segmentId, login, channelName, startAt, title?, category?}`; `noticeTitleIn(l)` = `notifReminderTitle(name)` ("{name}’s stream is starting" / "Le live de la chaîne {name} commence"); `noticeBodyIn(l)` = `streamNoticeBody(title, category, none: notifReminderUntitled)` ("Untitled stream" / "Live sans titre"); `movedTo(at)`; `entryIn([l])` → `ActivityEntry(id: 'reminder:<segmentId>', kind: reminder, at: startAt, login, params {name, title?, category?} with blanks dropped)`. JSON `{segmentId, login, channelName, startAt: epoch ms, title?, category?}`; `fromJson` rejects invalid logins/missing fields; startAt read as UTC.
- `reminderNoticeId(segmentId) = stableNoticeId('reminder:<segmentId>')`.
- `enum ReminderResult { set, cleared, refused, failed }` → the schedule tab shows a snackbar only for `refused` (`profileReminderRefused` "Allow notifications for this app in the system settings." / "Autorisez les notifications de cette application dans les paramètres du système.") and `failed` (`profileReminderFailed` "Couldn’t set the reminder." / "Impossible de programmer le rappel."); set/cleared just flip the button.
- `abstract interface class ReminderPlatform { requestPermission(); schedule({id, at, title, body, payload, l}); cancel(id); }`.
- `class ScheduleReminders extends ChangeNotifier({prefs, platform, now, words})`; `static shared`; key `schedule_reminders` (string list of JSON). All mutations are serialised (`_oneAtATime`, queue counter) so one never re-schedules a reminder another cancelled or moved.
  - `isSet(segmentId)`; `canRemind(segment)` = not cancelled and starts after now.
  - `reschedule()` (called when the UI language changes, because the system keeps the scheduled text): for every future reminder still the same object, schedule again with the current wording; if it changed meanwhile, cancel or schedule the current version; failures leave it as it was.
  - `toggle(segment, {login, channelName})`: if set → cancel the alarm first, remove, save, notify → cleared. Else if not remindable or the login is invalid → failed; permission refused → refused; build (startAt in UTC, title, categoryName), schedule first, then store, save, notify → set. Exceptions → failed.
  - `sync(login, segments)` (after reading a schedule): for each reminder of that login: segment missing → drop only if it was in the future and within the range read (beyond the last segment read it may just not have been fetched); cancelled → drop; same start → keep; moved and still future → reschedule at the new time; moved into the past → drop. Saves/notifies when changed; errors logged per reminder.
  - `takeDue()`: reminders whose start ≤ now are removed and returned as Activity entries (worded now).
- `LocalReminderPlatform` (const): `detailsFor(l)` channel `schedule_reminders`, group `onset.reminders`, update action, iOS thread `schedule_reminders`. `requestPermission()` as go-live. `schedule(...)`: exact alarm (`exactAllowWhileIdle`) only when Android already allows exact alarms (`canScheduleExactNotifications`), else `inexactAllowWhileIdle` (a few minutes late is acceptable; ONSET never asks for the exact-alarm permission); `zonedSchedule` at `TZDateTime.from(at.toUtc(), tz.UTC)`. `cancel(id)`. The flutter_local_notifications boot receiver re-arms alarms after reboot/app update.

Precisions: `toJson` stores `title` and `category` untrimmed (only `entryIn` params drop blanks); `_read` drops only entries throwing `FormatException` (and those `fromJson` rejects); `toggle` asks for the notification permission on every set (`platform.requestPermission()` each time, no cached answer); `takeDue` entries carry `at: startAt` (the scheduled start, not the time the app noticed them). The code comment on `noticeBodyIn` says "Stream" without title or category, but the actual text is `notifReminderUntitled` ("Untitled stream" / "Live sans titre").

## Per-file reference: global stores (lib/stores)

### lib/stores/cast_store.dart

MobX store `CastStore = CastStoreBase with _$CastStore` (generated `cast_store.g.dart`), app-wide instance `final sharedCastStore = CastStore()` used by `lib/widgets/cast_button.dart` (the cast button in the player chrome and the device sheet). The constructor takes an optional `CastBridge` (default `CastBridge()`) and immediately registers `listen(onDevices: _setDevices, onStatus: _setStatus)`.

Observable state (`@readonly`): `devices: List<CastDevice>` (default empty), `status: CastStatus` (default disconnected), `available: bool?` (null until discovery answered; false = no Google Play services/Cast unavailable), `loadFailed: bool`, `casting: CastMedia?` (what the receiver is playing). Private `_pending` media and `_onLoaded` callback. `supported` = bridge supported (Android). Computed: `connection` = status.connection; `connected` = connection == connected.

Actions:
- `beginDiscovery()` (sheet opened): `available = await startDiscovery()`; when available, reads `status()` and applies it.
- `endDiscovery()` (sheet closed): stop discovery.
- `castTo(device, media, {onLoaded})`: sets pending, clears loadFailed; if already connected to that device id → load now; else `connect(device)`; a false answer (route gone) clears pending and sets `loadFailed = true`; returns whether the connection was requested. The pending media is loaded when the state turns connected.
- `castHere(media, {onLoaded})`: loads on the current session (e.g. switching channel while casting).
- `stopCasting()`: clears pending/casting and disconnects (ends the session and stops the receiver app).
- `_setStatus(status)`: connected → if pending, load it; disconnected → a pending load becomes `loadFailed = true`, and pending/onLoaded/casting are cleared; connecting → nothing.
- `_loadPending()`: takes the pending media (returns false when none), `bridge.load(media)`, then `loadFailed = !loaded`, `casting = loaded ? media : null`, calls `onLoaded` on success (the cast sheet calls the player's `onCastStarted` and closes itself; errors show `castNotReady`/`castFailed` in the sheet). Returns loaded.

Precisions: when `castTo` targets the device already connected (`connected && status.deviceId == device.id`), it returns the result of `_loadPending()` (true only if the load succeeded) rather than "connection requested", and `onLoaded` is called before `castTo` completes. Because of the native connect behaviour (see `CastBridge.kt`), `castTo` a second device while connected to a first one can load the media on the first device (Known Android defects).

### lib/stores/mini_player_store.dart

MobX store `MiniPlayerStore` (provided via `Provider<MiniPlayerStore>` in `main.dart`): the in-app floating mini player that keeps the same live `IvsVideoStore` playing — and the channel's `ChatTabsStore` connected with its message history — while the user navigates the app. No reload and no chat reset on the way in or out.

Readonly observables: `visible` (bool), `userLogin`, `userId`, `displayName`, `shellChrome: EdgeInsets?` (how much of the top and bottom the navigation shell's header and bottom bar cover while the shell is on screen; the window keeps its corners inside, under the header and above the bar; null otherwise), `player: IvsVideoStore?`, `chatTabsStore: ChatTabsStore?`. Private `LiveProgressTracker? _liveProgress` (keeps recording the viewer's position in the broadcast for "continue watching" while minimised).

- `setShellChrome(insets)` updates only when different.
- `adopt({player, chatTabsStore, userLogin, userId, displayName, liveProgress})`: closes a different previous tracker, disposes a different previous player and chat store (only one mini player at a time), stores the new ones, `player.setMinimized(true)`, `visible = true`.
- `release()` → `(player, chat, liveProgress)` record: hands them back to the channel screen being restored without disposing (player `setMinimized(false)`), clears all fields, `visible = false`.
- `close()`: closes the tracker first (it reads the position before the player goes), disposes player and chat, clears, hides.
The mini window widget lives elsewhere (another spec leaf); this store only owns the adopted objects and the chrome insets it must stay within.

Precision: `release()` and `close()` do not reset `shellChrome`; it keeps the last insets until the shell calls `setShellChrome` again.

### lib/stores/global_assets_store.dart

MobX store `GlobalAssetsStore` (one per app, provided at the root; shared by all chat tabs) caching global emotes and badges. Constructor requires `twitchApi`, `bttvApi`, `ffzApi`, `sevenTVApi`. `ffzBadgeDefinitions` passes through `ffzApi.badgeDefinitions`. `late final sevenTvCosmetics = SevenTvCosmeticsCache(sevenTVApi)` (the per-user 7TV paint/badge cache, see its section).

State (`@readonly`): `isLoaded`, `isLoading`, private `_loadingFuture`; emote lists `twitchGlobalEmotes`, `sevenTVGlobalEmotes`, `bttvGlobalEmotes`, `ffzGlobalEmotes`; badges `twitchGlobalBadges: Map<badgeKey, ChatBadge>`, `bttvBadges: Map<providerId, ChatBadge>`, `ffzBadges: Map<userId, List<ChatBadge>>`.

`@computed globalEmoteMap`: name → Emote, filled in the order Twitch, 7TV, BTTV, FFZ — a later provider overwrites an earlier one with the same name (FFZ wins over BTTV over 7TV over Twitch for global emotes).

`ensureLoaded({showTwitchEmotes, showTwitchBadges, show7TVEmotes, showBTTVEmotes, showBTTVBadges, showFFZEmotes, showFFZBadges})` (all default true; the chat passes the user's emote/badge provider settings): returns at once when loaded; awaits the in-flight load when loading; otherwise starts `_fetchGlobalAssets` and marks loaded after it. `refresh(...)` clears `isLoaded` and calls `ensureLoaded` (settings changed). `_fetchGlobalAssets` runs, in parallel (`Future.wait`), only the enabled fetches: Twitch `getEmotesGlobal` (Helix `/chat/emotes/global`), 7TV `getEmotesGlobal`, BTTV `getEmotesGlobal`, FFZ `getEmotesGlobal`, Twitch `getBadgesGlobal` (Helix `/chat/badges/global`), BTTV `getBadges`, FFZ `getBadges`. Each failure is logged (`GlobalAssetsStore error`), reported to Telemetry with reason `Global asset fetch failed`, and that collection reset to empty — one provider failing never blocks the others.

Precisions and defects:
- (a) `refresh(...)` during an in-flight load sets `isLoaded = false`, then `ensureLoaded` awaits the old `_loadingFuture` (fetched with the old flags) and marks loaded: the new settings are lost until the next refresh. (Defect.)
- (b) A provider that is now disabled is neither fetched nor cleared: its previous emotes/badges stay in the lists and in `globalEmoteMap`. `ChatAssetsStore.emoteToObject` copies `globalEmoteMap` unfiltered, so emotes of a provider turned off in settings keep rendering in chat until restart. (Defect; the PC port clears disabled providers explicitly.)
- (c) After a failed fetch the store still marks itself loaded, so a provider that failed at start (no network) stays empty for the whole session; nothing retries until a settings change calls `refresh`. (Defect.)

### lib/stores/whisper_store.dart

The logged-in viewer's whispers (direct messages): received over EventSub (`user.whisper.message` v1), sent through Helix (`POST /whispers?from_user_id=&to_user_id=` with `{message}`), plus optional history read from Twitch's private GQL (via `TwitchSocialService.whisperThreads/whisperMessages`, authenticated with the twitch.tv web token). Kept in memory only for the session (no public history API for EventSub messages and private messages are never written to disk); mute/archive preferences persist in settings (`mutedWhisperUserIds`, `archivedWhisperUserIds`).

Helpers:
- `whisperPreview(text)`: single-line sanitiser for previews and notifications: removes zero-width invisibles (U+200B, U+2060, U+FEFF), removes "stray" joiners U+200C/U+200D (adjacent to Latin-range chars U+0000–U+024F, at the end, or at the start; kept between emoji and in scripts like Persian/Indic), replaces control chars (U+0000–U+001F, U+007F–U+009F), bidi/direction marks (U+061C, U+200E, U+200F, U+202A–U+202E, U+2066–U+2069) and line/paragraph separators (U+2028, U+2029) with spaces, collapses runs of spaces, trims. Purpose: a whisper cannot fake a second line or reverse text.
- `Whisper {id, text, mine, sentAt}`; `IncomingWhisper = ({fromUserId, fromLogin, fromName, whisper})`.
- `whisperFromEvent(event, {me, sentAt})`: requires `from_user_id` numeric (1–20 digits), `from_user_login` matching `^[a-zA-Z0-9_]{1,25}$`, `to_user_id == me`, `whisper.text` non-empty and ≤ `TwitchApi.maxWhisperLength` (10 000); login lower-cased; name = `from_user_name` when non-empty and ≤ 64 chars else the login; id = `whisper_id` or `in-<microseconds>`; sentAt = event time or now.

`WhisperThread` (MobX; generated): `userId`, `login`, `displayName`; `maxWhispers = 200` (oldest dropped); `whispers: ObservableList<Whisper>` oldest first; observables `unread`, `lastAt`. `_add` appends; `_merge` (history) skips a whisper with the same id or "the same whisper" (same direction, same text, within 2 minutes of each other), inserts in time order, trims to 200, advances `lastAt`.

`enum WhisperStatus { off, connecting, listening, interrupted, refused, unavailable }` — off (logged out), interrupted (reconnecting, retries itself), refused (token lacks the whisper scope or was revoked: log in again), unavailable (another refusal: retried on resume). Consumers: the whispers kit shows an interrupted/refused mark, Home and the chat show a log-in-again hint on `refused`.

`WhisperStore({twitchApi, listen, currentUserId, credentials, mutedUserIds, archivedUserIds, onPreferencesChanged, historyThreads, historyMessages})`:
- A MobX reaction on `(currentUserId(), credentials())` with `fireImmediately` calls `_follow(me)`: the same viewer again (a new token after re-login) re-listens so a refusal gets another try; another account or none → cancel handle and events, clear threads, remote thread ids, hidden-at marks, history state and open list; `me == null` → status off; else `_listenTo(me)` (status connecting; the new handle is created before the old one is cancelled so the topic stays subscribed across the switch).
- `_onEvent`: Listening → listening; Unavailable → interrupted (not permanent) / refused (permanent + unauthorized) / unavailable; Data → parse; unreadable events only log their field names in debug (never the content); find/create the thread; skip duplicate ids; add; `unread++` unless that conversation is on screen; un-archive it; push to `incoming` stream unless muted (used for in-app whisper toasts).
- `maxThreads = 50`: creating a thread evicts the least recent others (never the new one nor any open one).
- Computed: `openUserId` (last of the open stack; a conversation can open over another), `threads` (not archived, most recent first by `lastAt`), `archivedThreads`, `unreadCount` (sum of unread over non-archived, non-muted threads — the Activity tab badge).
- `isMuted`, `isArchived`, `toggleMute`, `archive`, `unarchive` (each saves preferences through `onPreferencesChanged(muted, archived)`, which writes the settings lists).
- History: `historyRefreshGap = 30 s`; `refreshHistory()` (no-op without user or fetcher, or within 30 s of the last ask): fetches thread list; `historyAvailable = threads != null`; stores remote thread ids per peer; merges each thread's last message unless the conversation was hidden after it. `loadConversation(userId)` merges that thread's messages. `remoteThreadId(userId)`.
- `hide(userId)`: remembers the hide time (history older than it does not resurrect it), removes the thread and any open entry, un-archives.
- `thread(...)`, `open(...)` (unread = 0, push on the open stack), `close(userId)` (removes the last occurrence).
- `sendTo({userId, login, displayName, text})` — starts a conversation only once the whisper went (`/w` from chat); `send(thread, text)`. `_send`: logged out → `WhisperLoggedOut`; a thread kept from before an account switch → `WhisperOtherAccount`; trimmed empty → null (nothing); longer than 10 000 → `WhisperTooLong(10000)`; Helix call: `UnauthorizedException` → `WhisperLogInAgain`; other `ApiException` → `WhisperRefused(e)`; anything else → Telemetry (`whisper send`, never the text) and `WhisperUnexpected`. On success (and same account) adds `Whisper(id: 'out-<µs>', mine: true, sentAt: now)`.
- `dispose()` stops the reaction, cancels the handle, closes `incoming`.
- `WhisperFailure.text(l)`: LoggedOut → `chatLogInToWhisper` ("Log in to whisper." / "Connectez-vous pour chuchoter."); OtherAccount → `whisperOtherAccount` ("This conversation belongs to another account." / "Cette conversation appartient à un autre compte."); TooLong → `whisperTooLong(max)` ("Whispers can be {max} characters at most." / "Les chuchotements sont limités à {max} caractères."); LogInAgain → `whisperLogInAgain` ("Log in again to whisper from this app." / "Reconnectez-vous pour chuchoter depuis cette application."); Refused → `chatWhisperFailedBecause(reason: chatErrorText(l, error))` ("Couldn’t whisper: {reason}" / "Impossible de chuchoter. {reason}"); Unexpected → `whisperFailedUnexpected` ("Couldn’t whisper (unexpected error)." / "Impossible de chuchoter (erreur inattendue).").

Precisions (verified against the code):
- Thread eviction (`maxThreads = 50`) picks the least recent thread from `threads`, i.e. **non-archived** threads only, excluding the new one and open ones; archived threads are never evicted, and the loop stops when no candidate is left, so more than 50 threads can exist (archived or open ones). (Defect relative to the stated cap.)
- History merges (`refreshHistory`, `loadConversation`) never increment `unread`, never push to `incoming` and never un-archive; only EventSub whispers do.
- A thread whose `lastAt` is null sorts as `DateTime(0)` (last). `refreshHistory` records `_historyAskedAt` before fetching, so a failed fetch also starts the 30 s gap; exceptions thrown by the `historyThreads`/`historyMessages` fetchers are not caught by the store (they propagate to the caller; the production fetchers return null on failure).

## Per-file reference: localisation (lib/l10n, non-generated)

ARB facts: `lib/l10n/app_en.arb` (template, 13 537 lines) and `lib/l10n/app_fr.arb` (2 292 lines) hold **2 289 keys each, in identical order**; every English key has an `@key` with a `description` (2 289); French carries no metadata; `@@locale` `en`/`fr`. 603 keys declare placeholders (507 `String`, 265 `int`, 4 `double`, 2 `DateTime` with format `yMMMM`; number formats: 37 `decimalPattern`, 5 `compact`, 4 `decimalPatternDigits`). 153 messages use ICU `plural`, 101 use `select`. Largest key families by prefix: chat 323, settings 271, mod 158, clip 92, ht (hype train) 92, live 69, profile 55, stream 51, latency 50, edit 47, onboarding 46, points 45, vod 41, channel 37, whisper 33, highlight 31, player 29, notice 29, notification 25, twitch 25, api 24, emote 24. `l10n.yaml`: arb-dir `lib/l10n`, template `app_en.arb`, output `app_localizations.dart`, class `AppLocalizations`, `nullable-getter: false`, `required-resource-attributes: true`, `use-named-parameters: true`, `format: true`. Generated files (`app_localizations*.dart`) are never edited and keep CRLF line endings.

`docs/L10N.md` rules (summary): every viewer-facing text (UI, screen reader, notifications, media notification, PiP buttons) comes from ARB in both languages, same commit, same key order, English description mentioning placement and length limits; placeholders typed with examples; plurals `{count, plural, one{…} other{…}}` with `one` (French `one` covers 0 and 1), number inside branches; on/off selects use `OnOff`; selects with an empty/vague `other` listed in `select_coverage_test`; never build sentences from pieces (`l10nMark`/`l10nSpans`); extracting English is byte-identical; not translated: brand names, Twitch data, code-like text, logs/exceptions, endonyms, chat commands. French: « vous », « Impossible de … », sentence case, U+202F before ; ! ? %, U+00A0 before : and inside « », curly ’, …, « » (nested “ ”), number+unit with U+00A0, no elision before a dynamic name, no agreement with a dynamic name, `live` masculine, `emote` feminine, glossary (chaîne, live, vidéo, Chuchotements, Picture-in-picture…), notification channel names short plural sentence case with descriptions without final full stop. English: US spelling, "Log in", "Tap", "Couldn’t …", serial comma, sentence case, curly quotes, ellipsis char, compact units in tight places. Background isolate: language via `uiLanguageIn`, `initializeDateFormatting` before `L10n.use`; notification builders take `AppLocalizations`; channel names passed each post with update action; scheduled notification text re-worded on language change; stored data never translated (codes + params). Guards: listed in §Tested behaviour.

### lib/l10n/l10n.dart

Localisation access and language plumbing (re-exports `app_localizations.dart`).

- `extension L10nContext on BuildContext { AppLocalizations get l10n }` — the texts of the language on screen, falling back to `L10n.english` when no `AppLocalizations` is above (bare test apps never fail). Widgets read this and rebuild on language change.
- `abstract final class L10n`: `english` = `lookupAppLocalizations(Locale('en'))`; `_current` is a MobX `Observable<AppLocalizations>` named `L10n.current` initialised to English; `current` getter (observable — MobX reactions re-run on language change). `use(locale)`: `supported = resolveAppLocale(AppLanguage.system, [locale])` (unsupported → English), sets `Intl.defaultLocale = supported.languageCode` (date/number formatting), and in an action sets `_current`. Without a MaterialApp (background isolate) `initializeDateFormatting` must be called first or `DateFormat` throws.
- `resolveAppLocale(language, deviceLocales)`: a picked language → its locale; System → the first device locale whose language code is supported (`fr-CA` → `fr`), in device preference order; none → `en`.
- `resolveAppLanguage(language, device)`: never returns `system` — the explicit language shown (`fr` when resolved French, else `en`); used for which language pill shows selected.
- `LocaleSync` widget (placed in `MaterialApp.builder` under `Localizations`): in `didChangeDependencies`, when `Localizations.localeOf(context)` changed, calls `L10n.use(locale)` then every `onLocale` listener in order; a throwing listener is reported via `FlutterError.reportError` (library `onset l10n`, context "while telling a listener the locale") and does not stop the others. `main.dart` passes `rememberUiLanguage(onChanged: ScheduleReminders.shared?.reschedule)` and a listener that sends `mediaLabelsOf(L10n.current)` to `BackgroundAudio.shared.setLabels`.
- `kUiLanguagePrefsKey = 'ui_language'` (the language last shown, `'en'`/`'fr'`, for the background isolate).
- `saveUiLanguage(locale)` → `Future<bool>`: serialised (a counter plus a chained future so concurrent calls compare with what the previous one saved); reads the stored code; same → false; writes the new code; returns `(before ?? 'en') != new` (a value saved by an English-only version reads as English). Any SharedPreferences error → false (logged `Language not saved for the background`).
- `rememberUiLanguage({onChanged})` → `ValueChanged<Locale>`: saves, and only when the saved language actually changed (now or while the app was closed) runs `onChanged` (re-wording reminders), failures logged `Language change not followed`; not on every launch.
- `uiLanguageIn({saved, settingsJson, device})` (background language, in order): `settingsJson['appLanguage']` when it is a supported code; else the first supported device language (via `resolveAppLocale(system, device)`); else `saved` when supported; else `'en'`. Malformed settings JSON is treated like System.
- `dateLocaleOf(l)`: `'en_US'` for English (always loaded), else `l.localeName` (`fr`).
- `localDecimal("2.3")`: replaces the first `.` with the current Intl locale's decimal separator (`2,3` in French).
- `enum OnOff { on, off }` with `OnOff.of(bool)`: the branch names of on/off ARB selects (`{x, select, on{…} other{…}}`) so typos cannot silently fall into `other`.
- `l10nMark(index)`: a private-use character `U+F0000 + index` for index 0..15 (RangeError otherwise) to pass as a placeholder value; `l10nSpans(message, pieces)`: splits the formatted message on those marks into `TextSpan`s of plain text with `pieces[i]` inserted where mark i is (a piece not placed is omitted; a mark without a piece is dropped). Used for bold names and links whose position differs per language (e.g. "Logged in as **name**").

The doc comment's example `context.l10n.commonNext` refers to `commonNext`: EN "Next" / FR "Suivant".

### lib/l10n/api_errors.dart

Words API failures for the viewer.

- `apiErrorKindText(l, kind, {statusCode})` — exhaustive switch over `ApiErrorKind`: network → `apiErrorNetwork`; connectionTimeout → `apiErrorConnectionTimeout`; sendTimeout → `apiErrorSendTimeout`; receiveTimeout → `apiErrorReceiveTimeout`; cancelled → `apiErrorCancelled`; certificate → `apiErrorCertificate`; unknown → `apiErrorUnexpected`; badRequest → `apiErrorBadRequest`; unauthorized → `apiErrorUnauthorized`; forbidden → `apiErrorForbidden`; notFound → `apiErrorNotFound`; conflict → `apiErrorConflict`; invalid → `apiErrorInvalid`; rateLimited → `apiErrorRateLimited`; server → `apiErrorServer`; unavailable → `apiErrorUnavailable`; maintenance → `apiErrorMaintenance`; serverTimeout → `apiErrorServerTimeout`; http → `apiErrorHttp(status: statusCode ?? 500)`; userNotFound → `apiErrorUserNotFound`; channelNotFound → `apiErrorChannelNotFound`; categoryNotFound → `apiErrorCategoryNotFound`; tokenProxyTimeout → `apiErrorTokenProxyTimeout`.
- `apiErrorText(l, error, {fallback})`: an `ApiException` with a non-blank `twitchMessage` on an English screen → Twitch's own words; any other `ApiException` → its kind worded; `SocketException` → `apiErrorUnableToConnect`; anything else → `fallback` (the screen's "Couldn’t load …") or `apiErrorUnexpected`.
- `chatErrorText(l, error)`: English → `error.message` (Twitch's English, as chat always showed). Other languages → `asSentence(apiErrorText(l, error))`, then if Twitch gave a reason that is non-empty, ≤ `maxQuotedTwitchReason` (120) characters and single-line → append `chatTwitchReason(reason)` ("Twitch’s reason: “{reason}”" / "Raison de Twitch : « {reason} »"), followed by "." unless the reason itself ends a sentence. Example FR: « Impossible de bannir. Requête non valide. Raison de Twitch : « The user is already banned. » ».
- `endsSentence(text)` = matches `[.!?…]$` after trimming right; `asSentence(text)` appends "." unless empty or already ending a sentence.
- `isConnectionProblemText(message)`: true when the message equals `apiErrorUnableToConnect` or `apiErrorNetwork` in any supported language (feeds pass worded messages; the status view picks the offline illustration from them).

Keys and values (EN / FR):
- `apiErrorNetwork`: EN "No internet connection. Check your network." / FR "Pas de connexion Internet. Vérifiez votre réseau."
- `apiErrorConnectionTimeout`: EN "The connection timed out. Try again." / FR "Impossible de joindre Twitch à temps. Réessayez."
- `apiErrorSendTimeout`: EN "Sending took too long. Try again." / FR "L’envoi a pris trop de temps. Réessayez."
- `apiErrorReceiveTimeout`: EN "Twitch took too long to respond. Try again." / FR "Le serveur a mis trop de temps à répondre. Réessayez."
- `apiErrorCancelled`: EN "The request was canceled." / FR "La requête a été annulée"
- `apiErrorCertificate`: EN "Couldn’t verify Twitch’s security certificate." / FR "Erreur de certificat de sécurité"
- `apiErrorUnexpected`: EN "An unexpected error occurred." / FR "Une erreur inattendue est survenue"
- `apiErrorBadRequest`: EN "The request wasn’t valid." / FR "Requête non valide"
- `apiErrorUnauthorized`: EN "Log in to continue." / FR "Connectez-vous pour continuer"
- `apiErrorForbidden`: EN "Access denied: missing permissions." / FR "Accès refusé. Autorisations insuffisantes"
- `apiErrorNotFound`: EN "This content couldn’t be found." / FR "Contenu introuvable"
- `apiErrorConflict`: EN "This changed in the meantime. Refresh and try again." / FR "Le contenu a changé entre-temps. Actualisez"
- `apiErrorInvalid`: EN "The data sent wasn’t valid." / FR "Données non valides"
- `apiErrorRateLimited`: EN "Too many requests. Wait a moment, then try again." / FR "Trop de requêtes. Patientez avant de réessayer"
- `apiErrorServer`: EN "Twitch had a server error. Try again later." / FR "Erreur du serveur. Réessayez plus tard"
- `apiErrorUnavailable`: EN "Twitch is temporarily unavailable." / FR "Service temporairement indisponible"
- `apiErrorMaintenance`: EN "Twitch is under maintenance. Try again later." / FR "Service en maintenance. Réessayez plus tard"
- `apiErrorServerTimeout`: EN "Twitch’s server didn’t respond. Try again." / FR "Le serveur ne répond pas. Réessayez"
- `apiErrorHttp`: EN "HTTP error {status}." / FR "Erreur HTTP {status}"
- `apiErrorUserNotFound`: EN "This user doesn’t exist." / FR "Cet utilisateur n’existe pas"
- `apiErrorChannelNotFound`: EN "This channel doesn’t exist." / FR "Cette chaîne n’existe pas"
- `apiErrorCategoryNotFound`: EN "Category not found." / FR "Catégorie introuvable"
- `apiErrorTokenProxyTimeout`: EN "The ONSET token service didn’t respond in time." / FR "Le serveur d’ONSET n’a pas répondu à temps"
- `apiErrorUnableToConnect`: EN "Couldn’t connect to Twitch." / FR "Impossible de joindre Twitch"
- `chatTwitchReason`: EN "Twitch’s reason: “{reason}”" / FR "Raison de Twitch : « {reason} »"

### lib/l10n/enum_labels.dart

Exhaustive `label(l)` extensions (a new enum value without a name does not compile): `AppLanguageLabel` (`label` = endonym option, `nameInText` = language inside a sentence), `ThemeTypeLabel`, `ShellSectionLabel`, `HomeFeedLabel`, `BrowseTabLabel`, `ActivityTabLabel`, `HomeTabLabel` (Settings › General › "Open the app on"), `ActivityKindLabel` (category under an Activity entry, like Twitch), `ClipPeriodLabel`, `ClipSortLabel`, `StreamSortLabel`, `FollowedSortLabel`, `TimestampTypeLabel`, `LandscapeCutoutTypeLabel`, `LandscapeChatModeLabel`, `PortraitChatHeightLabel`, `LiveCatchUpModeLabel`, `BufferProfileLabel`, `VodAutoplayLabel`, `CelebrationsOnVideoLabel`, `CaptionSizeLabel`, `CaptionBackgroundLabel`, `SettingsPageIdLabel` (`title` and tablet `description`, null for chatFilters, notInterested, editProfile), `TokenNoticeLabel` (snackbars), `TwitchAccountPageLabel` (`title` and `detail`), `ReleaseSectionKindLabel.count(l, n)` (plural counts in the release-notes summary line), `ChatModeLabel` (`label` via `chatModeName(mode: name)` select and `pill` via `chatModePill`), `EmoteTypeLabel` (`emoteTypeName(type: name)` select), `BadgeTypeLabel` (`badgeTypeName(type: name)`), `ClipDiscoveryLabel`. Mapping enum value → key follows the extension source one-to-one; all keys with EN / FR values:
- `appLanguageSystem`: EN "System" / FR "Système"
- `languageNameEnglish`: EN "English" / FR "English"
- `languageNameFrench`: EN "Français" / FR "Français"
- `languageInTextEnglish`: EN "English" / FR "anglais"
- `languageInTextFrench`: EN "French" / FR "français"
- `themeSystem`: EN "System" / FR "Système"
- `themeLight`: EN "Light" / FR "Clair"
- `themeDark`: EN "Dark" / FR "Sombre"
- `shellSectionHome`: EN "Home" / FR "Accueil"
- `shellSectionBrowse`: EN "Browse" / FR "Parcourir"
- `shellSectionActivity`: EN "Activity" / FR "Activité"
- `shellSectionProfile`: EN "Profile" / FR "Profil"
- `shellFeedFollowing`: EN "Following" / FR "Suivis"
- `shellFeedLive`: EN "Live" / FR "En direct"
- `shellFeedClips`: EN "Clips" / FR "Clips"
- `shellBrowseCategories`: EN "Categories" / FR "Catégories"
- `shellBrowseLiveChannels`: EN "Live channels" / FR "Chaînes en direct"
- `shellActivityNotifications`: EN "Notifications" / FR "Notifications"
- `shellWhispers`: EN "Whispers" / FR "Chuchotements"
- `activityKindLive`: EN "Live" / FR "En direct"
- `activityKindMention`: EN "Chat mentions" / FR "Mentions dans le chat"
- `activityKindReminder`: EN "Events" / FR "Événements"
- `clipPeriodLastDay`: EN "24 hours" / FR "24 heures"
- `clipPeriodLastWeek`: EN "7 days" / FR "7 jours"
- `clipPeriodLastMonth`: EN "30 days" / FR "30 jours"
- `clipPeriodAllTime`: EN "All time" / FR "Depuis toujours"
- `clipSortTop`: EN "Top" / FR "Les plus vus"
- `clipSortTrending`: EN "Trending" / FR "Tendances"
- `clipSortNewest`: EN "Newest" / FR "Les plus récents"
- `clipSortOldest`: EN "Oldest" / FR "Les plus anciens"
- `streamSortViewersHigh`: EN "Viewers (high to low)" / FR "Spectateurs (décroissant)"
- `streamSortRecommended`: EN "Recommended" / FR "Recommandés"
- `streamSortViewersLow`: EN "Viewers (low to high)" / FR "Spectateurs (croissant)"
- `streamSortRecent`: EN "Recently started" / FR "Lancés récemment"
- `followedSortViewers`: EN "Viewers (high to low)" / FR "Spectateurs (décroissant)"
- `followedSortRecent`: EN "Recently started" / FR "Lancés récemment"
- `followedSortName`: EN "Name (A–Z)" / FR "Nom (A-Z)"
- `followedSortCategory`: EN "Category" / FR "Catégorie"
- `followedSortRecommended`: EN "Recommended" / FR "Recommandées"
- `timestampDisabled`: EN "Disabled" / FR "Désactivé"
- `timestampTwelve`: EN "12-hour" / FR "12 heures"
- `timestampTwentyFour`: EN "24-hour" / FR "24 heures"
- `notchSideNone`: EN "None" / FR "Aucun"
- `notchSideLeft`: EN "Left" / FR "Gauche"
- `notchSideRight`: EN "Right" / FR "Droite"
- `notchSideBoth`: EN "Both" / FR "Les deux"
- `settingsChatSwitchingOverlay`: EN "Chat over the video" / FR "Chat superposé à la vidéo"
- `settingsChatSwitchingColumn`: EN "Chat beside the video" / FR "Chat à côté de la vidéo"
- `settingsChatSwitchingHidden`: EN "No chat" / FR "Sans chat"
- `portraitChatHeightLow`: EN "Low" / FR "Basse"
- `portraitChatHeightMedium`: EN "Medium" / FR "Moyenne"
- `portraitChatHeightHigh`: EN "High" / FR "Haute"
- `portraitChatHeightCustom`: EN "Custom" / FR "Personnalisée"
- `liveCatchUpSpeedUp`: EN "Speed up" / FR "Accélérer"
- `liveCatchUpJumpToLive`: EN "Jump to live" / FR "Revenir au direct"
- `bufferProfileStandard`: EN "Standard" / FR "Standard"
- `bufferProfileUltra`: EN "Ultra" / FR "Ultra"
- `vodAutoplayAlways`: EN "Wi-Fi and mobile data" / FR "Données mobiles et Wi-Fi"
- `vodAutoplayWifiOnly`: EN "Wi-Fi only" / FR "Wi-Fi uniquement"
- `vodAutoplayNever`: EN "Never" / FR "Jamais"
- `celebrationsFull`: EN "Full" / FR "Complètes"
- `celebrationsSubtle`: EN "Subtle" / FR "Discrètes"
- `captionSizeSmall`: EN "Small" / FR "Petite"
- `captionSizeMedium`: EN "Medium" / FR "Moyenne"
- `captionSizeLarge`: EN "Large" / FR "Grande"
- `captionSizeExtraLarge`: EN "Extra large" / FR "Très grande"
- `captionBackgroundBlack`: EN "Black" / FR "Noir"
- `captionBackgroundTranslucent`: EN "Translucent" / FR "Translucide"
- `captionBackgroundNone`: EN "None" / FR "Aucun"
- `settingsPageGeneral`: EN "General" / FR "Général"
- `settingsPageVideo`: EN "Video" / FR "Vidéo"
- `settingsPageChat`: EN "Chat" / FR "Chat"
- `settingsPageNotifications`: EN "Notifications" / FR "Notifications"
- `settingsPageOther`: EN "Other" / FR "Autres"
- `settingsPageAccount`: EN "Account" / FR "Compte"
- `settingsPageBlocked`: EN "Blocked users" / FR "Utilisateurs bloqués"
- `settingsPageChatFilters`: EN "Edit chat filters" / FR "Modifier les filtres du chat"
- `settingsPageNotInterested`: EN "Not interested" / FR "Chaînes masquées"
- `editProfileTitle`: EN "Edit profile" / FR "Modifier le profil"
- `settingsPageGeneralDescription`: EN "Theme, stream cards, browsing, and links" / FR "Le thème, les cartes de live, la navigation et les liens"
- `settingsPageVideoDescription`: EN "Low-latency player, playback, overlay, videos, and captions" / FR "Le lecteur à faible latence, la lecture, l’interface du lecteur, les vidéos et les sous-titres"
- `settingsPageChatDescription`: EN "Appearance, delay, alerts, and filters" / FR "L’apparence, le délai, les alertes et les filtres du chat"
- `settingsPageNotificationsDescription`: EN "Go-live and chat mention notifications" / FR "Les notifications de live et de mention dans le chat"
- `settingsPageOtherDescription`: EN "Updates, storage, privacy, and about" / FR "Les mises à jour, le stockage, la confidentialité et la rubrique À propos"
- `settingsPageAccountDescription`: EN "Your Twitch account in ONSET" / FR "Votre compte Twitch dans ONSET"
- `settingsPageBlockedDescription`: EN "People you blocked on Twitch" / FR "Les personnes que vous avez bloquées sur Twitch"
- `authForeignTokenNotice`: EN "This token was created for another app — some features may not work." / FR "Ce jeton a été créé pour une autre application – certaines fonctionnalités risquent d’être indisponibles."
- `authSessionEndedNotice`: EN "Your Twitch session has ended. Log in again from Settings." / FR "Votre session Twitch a pris fin. Reconnectez-vous depuis les paramètres."
- `settingsTwitchProfile`: EN "Edit profile" / FR "Modifier le profil"
- `settingsTwitchSecurity`: EN "Security and privacy" / FR "Sécurité et confidentialité"
- `settingsTwitchNotifications`: EN "Email and notifications" / FR "E-mails et notifications"
- `settingsTwitchConnections`: EN "Connections" / FR "Connexions"
- `settingsTwitchFamilyCenter`: EN "Family Center" / FR "Espace famille"
- `settingsTwitchSubscriptions`: EN "My subscriptions" / FR "Mes abonnements"
- `settingsTwitchDrops`: EN "Drops inventory" / FR "Inventaire des drops"
- `settingsTwitchTurbo`: EN "Twitch Turbo" / FR "Twitch Turbo"
- `settingsTwitchPrime`: EN "Prime Gaming" / FR "Prime Gaming"
- `settingsTwitchRecap`: EN "Year recap" / FR "Bilan de l’année"
- `settingsTwitchSignup`: EN "Create another account" / FR "Créer un autre compte"
- `settingsTwitchDeleteAccount`: EN "Disable or delete account" / FR "Désactiver ou supprimer le compte"
- `settingsTwitchProfileDetail`: EN "Display name, bio, picture — on twitch.tv" / FR "Nom affiché, bio, photo – sur twitch.tv"
- `settingsTwitchSecurityDetail`: EN "Password, email, phone, two-factor authentication — on twitch.tv" / FR "Mot de passe, e-mail, téléphone, double authentification – sur twitch.tv"
- `settingsTwitchNotificationsDetail`: EN "What Twitch emails and notifies you about — on twitch.tv" / FR "Ce que Twitch vous envoie par e-mail ou en notification – sur twitch.tv"
- `settingsTwitchConnectionsDetail`: EN "Linked accounts — on twitch.tv" / FR "Comptes associés – sur twitch.tv"
- `settingsTwitchFamilyCenterDetail`: EN "Parental supervision tools — on twitch.tv" / FR "Outils de supervision parentale – sur twitch.tv"
- `settingsTwitchSubscriptionsDetail`: EN "Manage your subscriptions — on twitch.tv" / FR "Gérer vos abonnements – sur twitch.tv"
- `settingsTwitchDropsDetail`: EN "Rewards earned by watching — on twitch.tv" / FR "Récompenses gagnées en regardant – sur twitch.tv"
- `settingsTwitchTurboDetail`: EN "Ad-free viewing — on twitch.tv" / FR "Visionnage sans publicité – sur twitch.tv"
- `settingsTwitchPrimeDetail`: EN "Your free monthly subscription — on twitch.tv" / FR "Votre abonnement mensuel gratuit – sur twitch.tv"
- `settingsTwitchRecapDetail`: EN "Your year on Twitch — on twitch.tv" / FR "Votre année sur Twitch – sur twitch.tv"
- `settingsTwitchSignupDetail`: EN "A new Twitch account — on twitch.tv" / FR "Un nouveau compte Twitch – sur twitch.tv"
- `settingsTwitchDeleteAccountDetail`: EN "Close your Twitch account — on twitch.tv" / FR "Fermer votre compte Twitch – sur twitch.tv"
- `releaseKindAdded`: EN "{count, plural, one{{count} new} other{{count} new}}" / FR "{count, plural, one{{count} nouveauté} other{{count} nouveautés}}"
- `releaseKindImproved`: EN "{count, plural, one{{count} improvement} other{{count} improvements}}" / FR "{count, plural, one{{count} amélioration} other{{count} améliorations}}"
- `releaseKindFixed`: EN "{count, plural, one{{count} fix} other{{count} fixes}}" / FR "{count, plural, one{{count} correction} other{{count} corrections}}"
- `releaseKindOther`: EN "{count, plural, one{{count} change} other{{count} changes}}" / FR "{count, plural, one{{count} modification} other{{count} modifications}}"
- `chatModeName`: EN "{mode, select, slow{Slow mode} followers{Followers-only mode} subscribers{Subscribers-only mode} emoteOnly{Emote-only mode} uniqueChat{Unique chat mode} other{}}" / FR "{mode, select, slow{Mode lent} followers{Mode followers uniquement} subscribers{Mode abonnés uniquement} emoteOnly{Mode emotes uniquement} uniqueChat{Mode chat unique} other{}}"
- `chatModePill`: EN "{mode, select, emoteOnly{Emote-only} followers{Followers-only} slow{Slow mode} subscribers{Subscribers-only} uniqueChat{Unique chat} other{}}" / FR "{mode, select, emoteOnly{Emotes uniquement} followers{Followers uniquement} slow{Mode lent} subscribers{Abonnés uniquement} uniqueChat{Chat unique} other{}}"
- `emoteTypeName`: EN "{type, select, twitchBits{Twitch Bits emote} twitchFollower{Twitch follower emote} twitchSub{Twitch sub emote} twitchGlobal{Twitch global emote} twitchUnlocked{Twitch unlocked emote} twitchChannel{Twitch channel emote} ffzGlobal{FrankerFaceZ global emote} ffzChannel{FrankerFaceZ channel emote} bttvGlobal{BetterTTV global emote} bttvChannel{BetterTTV channel emote} bttvShared{BetterTTV shared emote} sevenTVGlobal{7TV global emote} sevenTVChannel{7TV channel emote} sevenTVPersonal{7TV personal emote} bttvPersonal{BetterTTV personal emote} other{}}" / FR "{type, select, twitchBits{Emote de Bits Twitch} twitchFollower{Emote de follower Twitch} twitchSub{Emote d’abonné Twitch} twitchGlobal{Emote globale Twitch} twitchUnlocked{Emote Twitch débloquée} twitchChannel{Emote de chaîne Twitch} ffzGlobal{Emote globale FrankerFaceZ} ffzChannel{Emote de chaîne FrankerFaceZ} bttvGlobal{Emote globale BetterTTV} bttvChannel{Emote de chaîne BetterTTV} bttvShared{Emote partagée BetterTTV} sevenTVGlobal{Emote globale 7TV} sevenTVChannel{Emote de chaîne 7TV} sevenTVPersonal{Emote personnelle 7TV} bttvPersonal{Emote personnelle BetterTTV} other{}}"
- `badgeTypeName`: EN "{type, select, twitch{Twitch badge} bttv{BetterTTV badge} ffz{FrankerFaceZ badge} sevenTV{7TV badge} other{}}" / FR "{type, select, twitch{Badge Twitch} bttv{Badge BetterTTV} ffz{Badge FrankerFaceZ} sevenTV{Badge 7TV} other{}}"
- `clipDiscoveryAll`: EN "All clips" / FR "Tous les clips"
- `clipDiscoveryFeatured`: EN "Featured only" / FR "Mis en avant uniquement"
## Per-file reference: native Android (Kotlin), iOS (Swift) and the PiP plugin

All app Kotlin lives in package `app.onset` (namespace and applicationId `app.onset`, minSdk `max(flutter.minSdkVersion, 23)`, Java/Kotlin target 17, core-library desugaring on for `flutter_local_notifications`). Native dependencies that carry behaviour: `com.amazonaws:ivs-player:1.57.0` (the Amazon IVS player SDK), `com.google.android.gms:play-services-cast-framework:21.5.0`, `androidx.mediarouter:mediarouter:1.7.0`, `com.android.tools:desugar_jdk_libs:2.1.4`. Firebase Gradle plugins (google-services, firebase-perf, crashlytics) are only applied when `android/app/google-services.json` exists. Release signing reads `android/key.properties`; without it the release build is signed with the debug key and Gradle logs the warning `WARNING: android/key.properties not found; the release build is signed with the DEBUG key.`

Manifest facts relevant to behaviour (`android/app/src/main/AndroidManifest.xml`):
- Permissions: `INTERNET`; `ACCESS_NETWORK_STATE` (metered check for "Wi-Fi Only" autoplay); `POST_NOTIFICATIONS` (go-live notices, Android 13+, requested when the user turns them on); `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_MEDIA_PLAYBACK` (background audio and the floating player); `REQUEST_INSTALL_PACKAGES` (in-app updater); `SYSTEM_ALERT_WINDOW` (floating player overlay); `RECEIVE_BOOT_COMPLETED` (schedule reminders re-armed after reboot). Explicitly removed (`tools:node="remove"`): `com.google.android.gms.permission.AD_ID`, `ACCESS_ADSERVICES_AD_ID`, `ACCESS_ADSERVICES_ATTRIBUTION`.
- `<queries>`: VIEW intents with scheme `https`; PROCESS_TEXT with `text/plain`.
- Application: label `ONSET`, `allowBackup="false"`, `dataExtractionRules` excludes everything (`root` / `.`) from both cloud backup and device transfer, `localeConfig=@xml/locales_config` listing exactly `en` and `fr` (offered in the system per-app language settings on Android 13+).
- MainActivity: `exported`, `launchMode="singleTop"`, `taskAffinity=""`, theme `@style/LaunchTheme` then `NormalTheme`, `supportsPictureInPicture="true"`, `configChanges` = orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode (the activity is never recreated on rotation/resize/locale), hardware accelerated, `windowSoftInputMode="adjustResize"`.
- Intent filters: (1) MAIN + LAUNCHER; (2) MAIN + `android.intent.category.NOTIFICATION_PREFERENCES` (the system "Additional settings in the app" link on the notification settings page opens the app's notification settings); (3) `autoVerify` VIEW/BROWSABLE `https` on hosts `twitch.tv`, `www.twitch.tv`, `m.twitch.tv`, `clips.twitch.tv`, `go.twitch.tv`; (4) VIEW/BROWSABLE schemes `twitch` and `ttv` with hosts `stream`, `channel`, `profile`, `open`, `following`, `directory`, `game`, `search`, `video`, `activity`.
- Meta-data: `com.google.android.gms.cast.framework.OPTIONS_PROVIDER_CLASS_NAME = app.onset.CastOptionsProvider`; Firebase `firebase_crashlytics_collection_enabled`, `firebase_analytics_collection_enabled`, `firebase_performance_collection_enabled` all `false` (Dart turns them on only after consent); `google_analytics_adid_collection_enabled=false`, `google_analytics_default_allow_ad_personalization_signals=false`.
- Services: `.BackgroundAudioService` and `.FloatingPlayerService`, both non-exported, `foregroundServiceType="mediaPlayback"`. Receivers: `.InstallResultReceiver` (non-exported), `ScheduledNotificationReceiver` and `ScheduledNotificationBootReceiver` from flutter_local_notifications (boot receiver listens to `BOOT_COMPLETED`, `MY_PACKAGE_REPLACED`, `QUICKBOOT_POWERON`, `com.htc.intent.action.QUICKBOOT_POWERON`).
- Resources: `ic_stat_go_live.xml` and `ic_stat_playback.xml` are the monochrome status-bar icons (go-live notices; playback/floating notifications); `splash_icon.xml` is a 288 dp canvas whose launch tile is the central 72 dp; colours `ic_launcher_background #D0F020`, `launch_background #0A0A0A` (the ONSET ground, OnsetTokens.backgroundDark).

### android/app/src/main/kotlin/app/onset/MainActivity.kt

`class MainActivity : PipCallbackHelperActivityWrapper()` (the simple_pip_mode activity wrapper, so PiP enter/exit callbacks reach Dart). It owns one instance of each bridge: `IvsTextureManager`, `BackgroundAudioBridge`, `AudioFocusBridge`, `TwitchCookies`, `ApkInstaller`, `NetworkBridge`, `CastBridge`, `FloatingPlayerBridge`, plus three inline MethodChannels.

Launch bookkeeping:
- `coldStart = !processStarted && savedInstanceState == null`, then the companion `processStarted = true` (lives as long as the process, so a second activity in a kept process is a warm start and a restored state never replays the launch intro).
- `fromLauncher = intent.action == ACTION_MAIN && intent.hasCategory(CATEGORY_LAUNCHER)`.
- `openNotificationSettingsOnLaunch = asksForNotificationSettings(intent)`, true when action is MAIN and category `Notification.INTENT_CATEGORY_NOTIFICATION_PREFERENCES`.
- On Android 12+ (`S`), `splashScreen.setOnExitAnimationListener { handOverSplash(it) }` is installed before `super.onCreate`, so there is no system exit fade and the splash stays until Flutter has drawn its own tile. After `super.onCreate`, `preferSmoothRefreshRate()` runs inside `runCatching`.
- `onNewIntent`: if the new intent asks for notification settings, invokes `open` (no args) on `onset/notification-settings`.

`configureFlutterEngine` creates, in order: `TwitchCookies(messenger)`, `IvsTextureManager(this, flutterEngine.renderer, messenger)`, `BackgroundAudioBridge(applicationContext, …)`, `AudioFocusBridge(applicationContext, …)`, `ApkInstaller(applicationContext, …)`, `NetworkBridge(applicationContext, …)`, `CastBridge(applicationContext, …)`, `FloatingPlayerBridge(this, …)`, then:
- Channel `onset/locale`: `set(tag: String)` → `setAppLocale(tag)` ("" means follow the device), returns null; `get()` → `appLocale()`; `systemLocales()` → `systemLocales()`; anything else notImplemented.
- Channel `onset/notification-settings`: `consumeLaunch()` → returns `openNotificationSettingsOnLaunch` and resets it to false (one-shot); other methods notImplemented.
- Channel `onset/launch`: `info()` → `{coldStart: Bool, nativeTile: true, fromLauncher: Bool}`; Kotlin → Dart call `splashTile {x, y, size}` (doubles, dp, relative to the Flutter view).

`handOverSplash(splash)` (API 31): `remove` is idempotent. If the splash icon view, the Flutter view (`FLUTTER_VIEW_ID`), the launch channel are missing or `icon.width == 0`, the splash is removed at once. Otherwise it reads screen positions of the icon and Flutter view, `density`, computes `tile = icon.width * 72 / 288` and invokes `splashTile` with `x = (iconX − viewX + icon.width/2)/density`, `y = (iconY − viewY + icon.height/2)/density`, `size = tile/density`. The splash is removed when Dart answers (success, error or notImplemented) or after 300 ms (`postDelayed`), whichever comes first. Rationale recorded in code: the splash is centred on the whole window, which a Flutter view stopping above a navigation bar does not cover, and the system chooses the icon size, so it is measured, not assumed.

Locale helpers: `setAppLocale(tag)` is a no-op below Android 13 (TIRAMISU); otherwise via `LocaleManager` sets `applicationLocales` to the empty list (tag "") or `LocaleList.forLanguageTags(tag)`, only if different. `appLocale()` returns null below 13, else `applicationLocales.toLanguageTags()` ("" = device). `systemLocales()` returns comma-separated tags most-preferred first (e.g. `fr-FR,en-US`): on 13+ from `LocaleManager.systemLocales`, otherwise `Resources.getSystem().configuration.locales` (from 13 the activity configuration holds the per-app language, hence the system list must be read separately).

`cleanUpFlutterEngine` clears the locale handler then disposes background audio, audio focus, network, cast, floating player and texture manager, then super.

`preferSmoothRefreshRate()`: gets the display (`display` on API 30+, `windowManager.defaultDisplay` before), keeps the supported modes with the same physical width/height as the current mode, filters the ones whose refresh rate is within 1 Hz of a multiple of 60 (multiple ≥ 1), picks the highest of those (or of all same-size modes when none), and if it is more than 1 Hz above the current rate sets `window.attributes.preferredDisplayModeId`. 120 Hz therefore wins over 144 Hz so 30/60 fps streams keep an even cadence; the rate is never lowered. Reason: some OEM skins (HyperOS) keep unlisted apps at 60 Hz.

Precisions: `cleanUpFlutterEngine` does not dispose `ApkInstaller` (which has no `dispose` and whose single-thread executor is never shut down) nor `TwitchCookies`, and does not clear the `onset/notification-settings` and `onset/launch` handlers. `set` on `onset/locale` with a non-String argument is treated as `""` (`call.arguments as? String ?: ""`), i.e. follow the device language.

### android/app/src/main/kotlin/app/onset/IvsTuning.kt

`data class IvsTuning` — the low-latency tuning Dart sends as the `config` map of `onset/ivs-texture-manager.create` (Dart `IvsPlayerConfig`). Log tag `OnsetIVS`. Fields and defaults:
- `speedUpCatchUp: Boolean = true` — live catch-up by speeding playback up rather than jumping to live (`SessionConfig.setLiveCatchUpSpeedUpEnabled`).
- `rebufferToLive: Boolean = false` — `player.setRebufferToLive`.
- `initialBufferMs: Long = 100` — `player.setInitialBufferDuration`.
- `llMinBufferSec: Double? = null` — `SessionConfig.setLowLatencyMinBufferSeconds` when set.
- `llMinBufferCeilingSec: Double? = null` — `SessionConfig.setLowLatencyMinBufferCeilingSeconds` when set.
- `vod: Boolean = false` — past broadcast/highlight: no live low-latency or catch-up tuning.

`buildPlayer(context)`: VOD → `MediaPlayer.Builder(context).build()`, falling back to `Player.Factory.create(context)` if the builder throws; logs `vod player sdk=<version>`. Live → builds a `SessionConfig` with speed-up flag; each buffer override is applied in its own `runCatching` (an out-of-range value only drops that value and logs `min buffer <v> rejected` / `buffer ceiling <v> rejected`, never the speed-up); then `MediaPlayer.Builder(context).sessionConfig(session).build()`; on any failure logs `session config rejected, using defaults` and uses `Player.Factory.create`. Logs `tuning=<this> sdk=<version>`. Playback never fails because of tuning.

`applyTo(player)` must run before the first `load()` (changing the initial buffer swaps the native buffer strategy; latency/catch-up modes are applied when a stream loads). VOD: `setLiveLowLatencyEnabled(false)`, `setRebufferToLive(false)` (SDK default buffering for smooth seeking). Live: `setLiveLowLatencyEnabled(true)`, `setRebufferToLive(rebufferToLive)`, `setInitialBufferDuration(initialBufferMs)`. Throwables are logged (`vod config failed`, `low-latency config failed`), never rethrown.

`fromArgs(map?)`: null map → defaults. Keys `speedUpCatchUp` (Boolean), `rebufferToLive` (Boolean), `initialBufferMs` (Number→Long), `llMinBufferSec`, `llMinBufferCeilingSec` (Number→Double, else null), `vod` (Boolean, default false). Missing or mistyped keys fall back to defaults.

What Dart actually sends (`lib/screens/channel/video/ivs_player_config.dart`, `IvsPlayerConfig.toCreateArgs`): catch-up `speedUp` → `{speedUpCatchUp: !autoLatency, rebufferToLive: false}` (with the app's auto latency on, the SDK speed-up is left off because it resets the rate on every buffer update and would undo Dart's catch-up); `jumpToLive` → `{speedUpCatchUp: false, rebufferToLive: true}`; always `initialBufferMs: 100`; buffer profile `ultra` adds `{llMinBufferSec: 0.5, llMinBufferCeilingSec: 3.0}`, `standard` adds nothing. With auto latency on, a chosen Ultra falls back to Standard while `BufferFallback.shared` is active (Ultra stalled repeatedly on a recent stream). VODs send `{vod: true}` only.

Log lines (tag `OnsetIVS`): `vod builder failed, using defaults: <throwable>`, `vod player sdk=<version>`, `min buffer <v> rejected: <throwable>`, `buffer ceiling <v> rejected: <throwable>`, `session config rejected, using defaults: <throwable>`, `tuning=<IvsTuning(...)> sdk=<version>`, `vod config failed: <throwable>`, `low-latency config failed: <throwable>`.

### android/app/src/main/kotlin/app/onset/IvsPlayerCore.kt

`class IvsPlayerCore(player: Player, channel: MethodChannel, onVideoSize: ((Int, Int) -> Unit)?)` — bridges one IVS player to one per-instance channel (`onset/ivs-texture/<textureId>`). All events go Dart-ward as `invokeMethod("onEvent", map)` posted on the main looper (exceptions swallowed).

State: `latencyTicker`, `progressTicker`, `tuning`, `pendingStartMs` (VOD: position to seek on the first READY after a load, 0 included, because a still-recording VOD would otherwise start at its live edge), `autoPlayPending` (VOD: auto-play once per load so later READYs keep a pause), `qualitiesSent`, `sentQualityNames` (the ladder is watched because Twitch adds enhanced-broadcast 1440p HEVC/AV1 renditions after playback starts), `statsEnabled`, `captionsEnabled` (off by default), `preferredTrackId`, `sentTracks`.

Dart → native methods (`start(url, tuning)` installs the handler):
- `play`, `pause` → player.play/pause, return null.
- `setAutoQuality` → `setAutoQualityMode(true)`.
- `setQuality {name}` → finds the quality with that name, `setQuality(q, true)` (second argument `adaptive = true`: the switch happens seamlessly at a segment boundary instead of flushing the buffer; this also leaves auto-quality mode); unknown name ignored.
- `setMuted {muted}` → `isMuted = muted == true`.
- `setVolume {volume}` → float, default 1, clamped 0..1.
- `setCaptions {enabled}` → stores flag, `applyCaptions()`, `sendTextTracks()` (so the menu ticks the newly selected track).
- `setTextTrack {id}` → stores `preferredTrackId`, selects the track with that id if present (errors logged `text track:`), `sendTextTracks()`.
- `setStatsEnabled {enabled}`.
- `load {url, startMs?}` → resets `qualitiesSent`, `sentQualityNames`, `sentTracks`; for VOD sets `pendingStartMs = startMs` and `autoPlayPending = true`; loads `Uri.parse(url)` when url non-null.
- `seekTo {ms}` (VOD only, live → notImplemented): if `autoPlayPending` (not READY yet) the value becomes `pendingStartMs` (the READY start seek would otherwise undo it); else `seekTo(max(ms,0))`.
- `setPlaybackRate {rate}` → NaN → 1. VOD: clamp 0.5..2. Live: clamp 1.0..1.1 (only Dart's auto-latency controller sets it; the player is then created without the SDK speed-up; a live stream can never play slower than real time nor visibly fast); if the SDK throws returns error code `rate_rejected` so Dart stops trying. Logs `setPlaybackRate <rate> state=<state>`.
- `getPosition` (VOD only) → `player.position` or null.
- else notImplemented.

Player listener → events:
- `onStateChanged` → `{type:'state', state: <IDLE|READY|BUFFERING|PLAYING|ENDED>}`. On READY: live → `play()`; VOD with `autoPlayPending` → clear it, seek to `pendingStartMs` (≥0) if any, clear, `play()`. On PLAYING: `applyCaptions()`, `sendTextTracks()`, and the first time per load sends `{type:'qualities', list:[names sorted]}`.
- `onError` → `{type:'error', code, msg: errorMessage, errorType: errorType.name, source}`; logged at error level.
- `onRebuffering` → `{type:'rebuffering'}`.
- `onQualityChanged` → `{type:'quality', name}`.
- `onVideoSizeChanged(w,h)` → `onVideoSize(w,h)` callback (texture buffer resize), no event.
- `onCue`: an `AdCue` → `{type:'ad', durationMs, startMs, endMs}` (Dart's auto latency never speeds up an ad); a `TextCue` when captions are on → `{type:'caption', text, startMs, endMs}`.
- `onTextTracksChanged` → `applyCaptions()` + `sendTextTracks()` (tracks can be announced after start).
- `onDurationChanged` (VOD) → `{type:'duration', ms}`; `onSeekCompleted` (VOD) → `{type:'seeked', ms}`.

After installing the listener: `tuning.applyTo(player)`; if `url` non-empty (the player may be created before the usher URL is known; Dart sends it with `load` later) VOD sets `autoPlayPending = true` and loads. Then VOD → progress ticker, live → latency ticker.

`applyCaptions()`: only when captions on; selects Dart's preferred track if present and not already selected, else the first track if none selected; never throws (`captions:` log). `sendTextTracks()`: list of `{id, label, language: languageTag}`, selected id; compares list+selected with the last sent and sends `{type:'textTracks', list, selected}` only when changed.

Progress ticker (VOD): every 250 ms (rescheduled first) sends `{type:'progress', positionMs, bufferedMs, durationMs}` (each getter guarded → null).

Quality ordering `sortedQualityNames()`: descending height, then framerate, then bitrate (so 1440p HEVC/AV1 is first even with a lower bitrate than 1080p H.264). `sendQualitiesIfChanged()`: once a first ladder was sent, a non-empty different list is sent as `{type:'qualitiesChanged', list}`.

Latency ticker (live): every 1000 ms, reschedules first (a failing getter can never stop it), sends `latencyTick()`, then `sendQualitiesIfChanged()`, then when `statsEnabled` `collectStats()`; each step wrapped separately (`latency tick failed`, `qualities failed`, `stats failed`). `latencyTick()` = `{type:'latency', ms: liveLatency|null, bufferMs: max(buffered−position,0)|null, rate: playbackRate (double)|null, lowLatency: isLiveLowLatency|null}`; a tick is never dropped silently because Dart's auto-latency ends a catch-up on a tick without latency or on missing ticks.

`collectStats()` = `{type:'stats', bitrate: statistics.videoBitRate, fps: frameRate, dropped: droppedFrames, decoded: decodedFrames, rendered: renderedFrames, bufferedMs, lowLatency, playbackRate, bandwidth: bandwidthEstimate, quality: {name, width, height, codecs, framerate (double), bitrate}|null}` — every getter guarded.

`dispose()`: removes both tickers, clears the handler, `player.release()`.

Precisions (verified against the code):
- `setCaptions {enabled: false}` only clears the flag: no further `caption` events are sent, but the selected text track is not deselected, and the next `textTracks` event still reports it as `selected`.
- VOD `setPlaybackRate` sets `player.playbackRate = rate.coerceIn(0.5f, 2f)` without a try/catch: an SDK refusal throws on the platform thread instead of returning `rate_rejected` (only the live branch reports `rate_rejected`).
- `seekTo` without an `ms` argument seeks to 0 (`?: 0L`); before READY (autoPlayPending) that 0 replaces `pendingStartMs`, so the VOD starts at the beginning.
- Log lines (tag `OnsetIVS`): `onError type=<errorType> code=<code> source=<source> msg=<message>` (error level), `setPlaybackRate <rate> state=<state>` (debug), `live rate <rate> rejected: <throwable>`, `text track: <message>`, `captions: <message>`, `text tracks: <message>`, `progress failed: <throwable>`, `latency tick failed: <throwable>`, `qualities failed: <throwable>`, `stats failed: <throwable>`.

### android/app/src/main/kotlin/app/onset/IvsTexturePlayer.kt

`IvsTexturePlayer(context, textureRegistry, messenger, url, tuning)` renders IVS into a Flutter texture (`textureRegistry.createSurfaceProducer()`) instead of a SurfaceView, because a texture can be moved/animated by Flutter's compositor (the draggable in-app mini player, PiP). `textureId = surfaceProducer.id()`. Player = `tuning.buildPlayer(context)`. Per-player channel `onset/ivs-texture/<textureId>`. The core's `onVideoSize` resizes the producer when `w > 0 && h > 0`. Init: `surfaceProducer.setSize(1280, 720)`, `player.setSurface(surfaceProducer.surface)`, `core.start(url, tuning)`. `dispose()` → core.dispose + `surfaceProducer.release()`.

`IvsTextureManager(context, textureRegistry, messenger)` on channel `onset/ivs-texture-manager`: `create {config: Map?, url: String?}` → builds the tuning with `IvsTuning.fromArgs(config)`, creates an `IvsTexturePlayer` with url or "" and returns its `textureId` (Long); `dispose {textureId}` removes and disposes that player, returns null; other methods notImplemented. `dispose()` clears the handler and disposes every tracked player (a HashMap<Long, IvsTexturePlayer>).

Precision: `player.setSurface(surfaceProducer.surface)` is called once in `init`; no `SurfaceProducer` lifecycle callback is registered, so if the engine recreates the producer's surface (e.g. after the app was backgrounded on some devices), the new surface is never re-attached and video stays black while audio continues. (Defect, see Known Android defects.)

### android/app/src/main/kotlin/app/onset/FloatingPlayerService.kt

System-wide floating player (outside the app), a non-exported foreground service (`mediaPlayback`) drawing an overlay window. Log tag `OnsetFloating`. Constants: notification channel `onset_floating_player`, notification id `4207`, stop action `app.onset.floating.STOP`, extras `url`, `title`, `channelLabel`, `closeLabel`. Companion: `onClosed: ((Boolean) -> Unit)?`, `@Volatile running`, `stop(context)` (only when running; sends ACTION_STOP via startService, logs `could not stop`).

`onStartCommand`: null intent, ACTION_STOP or missing url → `close(returned=false)`, `START_NOT_STICKY`. Otherwise `running = true`, `closing = false`, `promote(intent)` (startForeground first, required for a foreground-started service), then if `Settings.canDrawOverlays` is false → close; else `show(url, closeLabel)`. Always `START_NOT_STICKY`.

`promote`: notification channel `onset_floating_player` named by the `channelLabel` extra (fallback the title), importance LOW; notification with small icon `ic_stat_playback`, title = `title` extra, content intent = launch intent (`PendingIntent.getActivity` request 0, IMMUTABLE), ongoing, one action (system icon `ic_menu_close_clear_cancel`, label = closeLabel) firing `PendingIntent.getService(request 1, ACTION_STOP, IMMUTABLE)`. `startForeground(4207, …, FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)` on Q+.

`show`: if a player already exists → `load(url)` + `play()` (re-use the window). Else: window width = `round(min(screenWidthPx, screenHeightPx) × 0.6)`, height = `width × 9 / 16`; type `TYPE_APPLICATION_OVERLAY` (O+, `TYPE_PHONE` before); flags `FLAG_NOT_FOCUSABLE | FLAG_LAYOUT_NO_LIMITS`; `PixelFormat.TRANSLUCENT`; gravity TOP|START; initial x = `screenWidth − width − 16dp`, y = `96dp` (top-right corner, 16 dp from the right edge, 96 dp from the top). Root `FrameLayout`: black `GradientDrawable` with corner radius 14 dp, `clipToOutline`, elevation 8 dp. A full-size `SurfaceView` whose holder callbacks attach/detach the player surface. A close `ImageButton` 36×36 dp, top|end, margins 6 dp, system close icon tinted white, oval background `#8C000000` (55 % black), contentDescription = closeLabel, click → `close(returned=false)`. The root's touch listener is `DragToMove(layout, manager, root, slop = 8dp, onTap = returnToApp)`. `addView` failure → log `overlay refused` and close. Then `IvsTuning()` (default live tuning) player, surface if already created, `load(url)`, `play()`.

`DragToMove`: DOWN records layout x/y and raw pointer; MOVE marks `moved` once |dx| or |dy| exceeds slop, then sets layout x/y = start + delta and `updateViewLayout` (errors ignored); UP without movement → `performClick()` + tap callback. Always consumes. No snapping, no edge clamping, no fling, no resize gesture, no animation.

`returnToApp()`: launch intent with `FLAG_ACTIVITY_NEW_TASK | FLAG_ACTIVITY_REORDER_TO_FRONT`, start it (log `could not return to the app` on failure), then `close(returned=true)`.

`close(returned)`: idempotent via `closing`; `running = false`; removes the window; releases the player; `stopForeground(STOP_FOREGROUND_REMOVE)`; `stopSelf()`; posts `onClosed(returned)` on the main looper. `onDestroy` → `close(false)`.

`FloatingPlayerBridge(activity, messenger)` on channel `onset/floating-player`: sets `FloatingPlayerService.onClosed` to invoke Dart method `closed {returned: Bool}`. Methods: `canDrawOverlays` → Bool; `openPermissionSettings` → starts `ACTION_MANAGE_OVERLAY_PERMISSION` for `package:<pkg>`, returns true, or false (log `no overlay settings`); `start {url, title, channelLabel, closeLabel}` → false when url missing or no overlay permission; otherwise starts the service (foreground on O+) with the extras, then `activity.moveTaskToBack(true)` (the app goes to the background, the floating window stays), returns true, or false on exception (`could not start`); `stop` → `FloatingPlayerService.stop(activity)`. `dispose()` clears `onClosed` and the handler.

Precisions (verified against the code):
- The overlay's player is built with `IvsTuning().buildPlayer(this)` then `load(url)` and `play()`, but `IvsTuning.applyTo(player)` is **never called**: no `setLiveLowLatencyEnabled(true)`, no `setRebufferToLive(false)`, no 100 ms initial buffer — only the SessionConfig speed-up catch-up (default true) applies. (Defect, see Known Android defects.)
- No `Player.Listener` is attached: no auto-play on READY (only the explicit `play()` after `load`), no error handling (an IVS error leaves a black window until the user closes it), no rebuffering/latency reporting, no mute or volume control; the overlay plays at full volume, unmuted. (Defect.)
- The channel-name fallback to the title (`EXTRA_CHANNEL_LABEL ?: title`) never happens in practice: the bridge always puts the `channelLabel` extra (`""` when Dart sends none) and Dart always sends `popOutNotificationChannel`, so an empty label would yield an empty channel name rather than the title.
- `DragToMove` handles only ACTION_DOWN, ACTION_MOVE and ACTION_UP; ACTION_CANCEL is ignored (a cancelled gesture leaves the window where it was dragged; no tap fires). The slop is a float in pixels, `8 * density`, not rounded; movement is applied with `roundToInt()` of the delta.

### android/app/src/main/kotlin/app/onset/BackgroundAudioService.kt

Keeps a live stream's sound playing with the app in the background: a `mediaPlayback` foreground service (so Android does not freeze the process), a `MediaSession` tagged `"ONSET"` (lock screen, headphone and Bluetooth buttons) and a MediaStyle notification. The IVS player stays in the Flutter-side texture; the service only keeps the process alive and forwards buttons. Log tag `OnsetAudio`.

Constants: actions `app.onset.audio.SHOW`, `app.onset.audio.PLAY`, `app.onset.audio.PAUSE`, `app.onset.audio.STOP`; extras `title`, `subtitle`, `playing`; notification channel id `playback`; notification id `7301`. Companion: `instance` (running service, privately set), `onCommand: ((String) -> Unit)?` (`"play"`, `"pause"`, `"stop"`), `labels: MediaLabels` (notification words in the app's language, sent by Dart with each show and on language change; ARB keys `mediaChannel`, `mediaPlay`, `mediaPause`, `mediaStop`; empty only until the first show, so the notification is never posted without them), `startPending`, `hideRequested` (stopping a foreground-started service before it called startForeground crashes, so a hide during a pending start makes the service stop itself right after promoting).

`onCreate`: `instance = this`, session with callbacks onPlay/onPause/onStop → `onCommand("play"|"pause"|"stop")`, `isActive = true`.

`onStartCommand`: SHOW → `startPending = false`, `update(title, subtitle, playing (default true), promote = true)`, then if `hideRequested` → reset and `stopSelf()`. PLAY/PAUSE/STOP (from notification buttons) → `onCommand`. Returns `START_NOT_STICKY` (without the app there is nothing to play).

`update(title, subtitle, playing, promote=false)`: sets session metadata (`METADATA_KEY_TITLE` = title, `METADATA_KEY_ARTIST` = subtitle) and playback state (actions PLAY|PAUSE|PLAY_PAUSE|STOP, state PLAYING or PAUSED, position UNKNOWN, speed 1). Without `promote` it just `notify(7301, …)` (Android 12+ refuses `startForeground` from the background, so later changes repost); with promote → `startForeground(7301, …, MEDIA_PLAYBACK)` on Q+.

`buildNotification()`: channel `playback` named `labels.channel`, importance LOW; toggle action = pause (system `ic_media_pause`, `labels.pause`, ACTION_PAUSE) when playing, else play (`ic_media_play`, `labels.play`, ACTION_PLAY); small icon `ic_stat_playback`; title, text = subtitle; content intent = launch intent (request 0, IMMUTABLE); delete intent = ACTION_STOP (swiping the paused notification stops playback); visibility PUBLIC (shown on lock screen); `setOngoing(playing)` (not dismissible while playing); actions [toggle, stop (`ic_menu_close_clear_cancel`, `labels.stop`)]; `MediaStyle` with the session token and compact view actions 0 and 1. Pending intents: `PendingIntent.getService(requestCode = action.hashCode(), IMMUTABLE | UPDATE_CURRENT)`.

`refreshLabels()` reposts with the current state. `dismiss()` clears `instance` if it is this and `stopSelf()` (later shows start a new service). `onDestroy` clears instance, deactivates and releases the session, `stopForeground(REMOVE)`.

`data class MediaLabels(channel, play, pause, stop)` default "", `from(map)` → null for a null map, else each key as String or "".

`BackgroundAudioBridge(context, messenger)` on channel `onset/background-audio`: `onCommand` → main-thread `invokeMethod("command", {action})`. Methods: `labels {channel, play, pause, stop}` → store and `instance?.refreshLabels()`, return null. `show {title, subtitle, playing, labels}` → store labels if present; if a service instance runs → `hideRequested = false`, `update(...)` (no promote), return null; else build a SHOW intent, `hideRequested = false`, `startPending = true`, `startForegroundService` (O+) / `startService`; on exception (e.g. Android 12+ background-start refusal) `startPending = false`, log, return error `start_failed`. `hide` → if `startPending` set `hideRequested = true`; else `instance.dismiss()` or `stopService`. `dispose()` clears `onCommand`, the handler, and hides.

### android/app/src/main/kotlin/app/onset/AudioFocusBridge.kt

Channel `onset/audio-focus`. Methods: `request` → Bool granted; `abandon` → null; `headphonesConnected` → Bool. Native → Dart: `change {state}` with `loss`, `lossTransient`, `gain` or `noisy`, always posted on the main looper.

Focus listener: `AUDIOFOCUS_LOSS` → `loss`; `AUDIOFOCUS_LOSS_TRANSIENT` → `lossTransient`; `AUDIOFOCUS_GAIN` → `gain`; `LOSS_TRANSIENT_CAN_DUCK` is ignored (Android 8+ ducks by itself).

`request()`: O+ builds once and reuses an `AudioFocusRequest(AUDIOFOCUS_GAIN)` with attributes usage MEDIA, content type MOVIE, `setWillPauseWhenDucked(false)`, `setAcceptsDelayedFocusGain(true)` (refused during a call; GAIN arrives when it ends), listener on the main handler. Pre-O uses the deprecated `requestAudioFocus(listener, STREAM_MUSIC, AUDIOFOCUS_GAIN)`. `granted = REQUEST_GRANTED`; `held = granted || REQUEST_DELAYED` (a delayed request must be abandoned too). When held and not yet registered, registers a receiver for `ACTION_AUDIO_BECOMING_NOISY` (headphones unplugged / BT disconnect) → `noisy`; on 13+ with `RECEIVER_NOT_EXPORTED`. Returns `granted` (false for refused or delayed).

`abandon()`: if held → `abandonAudioFocusRequest` (O+) / `abandonAudioFocus(listener)`, `held = false`; unregisters the noisy receiver if registered.

`headphonesConnected()`: true if any output device type is in {WIRED_HEADSET, WIRED_HEADPHONES, BLUETOOTH_A2DP, BLUETOOTH_SCO, USB_HEADSET (O+), BLE_HEADSET (S+)}.

`dispose()` clears the handler and abandons.

### android/app/src/main/kotlin/app/onset/CastBridge.kt

Google Cast (Chromecast) to the Default Media Receiver. Log tag `OnsetCast`.

`CastOptionsProvider : OptionsProvider` (registered in the manifest): receiver application id `CastMediaControlIntent.DEFAULT_MEDIA_RECEIVER_APPLICATION_ID` (the stock "CC1AD845" receiver), `setStopReceiverApplicationWhenEndingSession(true)`, no additional session providers.

`CastBridge(context, messenger)` on channel `onset/cast`. MediaRouteSelector with control category `categoryForCast(DEFAULT_MEDIA_RECEIVER_APPLICATION_ID)`. A single-thread executor for `CastContext.getSharedInstance(context, executor)`. Flags `unavailable`, `discovering`, `connecting`.

Methods:
- `start` → `withCastContext`: cached context → true; previously failed → false; otherwise asynchronously obtains the shared CastContext, registers the session listener and answers true, or on failure/throw logs `cast unavailable`, sets `unavailable = true` and answers false (Play Services missing). When available, `startDiscovery()`: adds the router callback with `CALLBACK_FLAG_PERFORM_ACTIVE_SCAN` once, then sends devices and state.
- `stop` → removes the router callback (stops discovery).
- `state` → `stateMap()`.
- `connect {id}` → finds a route with that id that is a cast route; none → false; else `setConnecting(true)`, `route.select()`, true.
- `disconnect` → `sessionManager.endCurrentSession(true)` (stops the receiver), `connecting = false`, sends state, null.
- `load {url, live?, title?, subtitle?, imageUrl?, startMs?}` → false without url or without a current session's `remoteMediaClient`; builds `MediaMetadata(MEDIA_TYPE_MOVIE)` with KEY_TITLE, KEY_SUBTITLE and one `WebImage(imageUrl)`; `MediaInfo(url)` with content type `application/x-mpegURL`, stream type LIVE (default, `live` true) or BUFFERED; `MediaLoadRequestData` autoplay true, current time `startMs` (default 0); `client.load` → true, exception → false (`load failed`).

Native → Dart: `devices` with a list of `{id, name}` (routes that are not default, are enabled and match the selector), sent on route added/removed/changed and on start; `state` with `{state: 'connected'|'connecting'|'disconnected', device: friendlyName|null, deviceId: selected cast route id|null}`. State rules: session connected → connected; `connecting` flag or session connecting → connecting; else disconnected. Session listener: starting/resuming → connecting true; started/resumed/start failed/resume failed/ended → connecting false; ending/suspended → send state.

`dispose()` stops discovery, removes the session listener, clears the handler, shuts down the executor.

Precisions (verified against the code):
- `load` returns true as soon as `remoteMediaClient.load(request)` is handed over without throwing; the returned `PendingResult` is never observed, so a receiver-side load failure (unsupported stream, expired URL) is not reported to Dart — `CastStore` shows it as casting.
- `KEY_TITLE`, `KEY_SUBTITLE` and the `WebImage` are added only when the corresponding argument is a non-null String; `CastMedia.toArguments()` always sends the keys, possibly with null values, which are skipped.
- `connect` to device B while a session with device A is connected: `setConnecting(true)` immediately emits `stateMap()`, which still reads A's connected session and reports `connected` with A's details; `CastStore._setStatus(connected)` therefore loads B's pending media on A's session before the route switch happens. (Defect, see Known Android defects.)

### android/app/src/main/kotlin/app/onset/NetworkBridge.kt

Channel `onset/network`: `isMetered` → true on mobile data or metered Wi-Fi, false on unmetered, null when no active network, no ConnectivityManager or a SecurityException. Event channel `onset/network/metered`: while listened, streams the same Bool? each time the default network changes, so "Wi-Fi Only" previews stop at once when leaving Wi-Fi.

`listen(sink)`: stops a previous registration, resets `sentOnce`/`lastSent`, registers a `NetworkCallback` (`registerDefaultNetworkCallback` on N+, else `registerNetworkCallback(NetworkRequest.Builder().build())`) whose `onCapabilitiesChanged` and `onLost` post `send` to the main thread. A RuntimeException at registration (SecurityException, too many callbacks) is swallowed: previews keep the value read when they started. `send(from, sink)` ignores posts from a stale callback, recomputes `isMetered()`, and only emits when it differs from the last emitted value (Wi-Fi capabilities change every few seconds with signal strength). `onCancel` → `stopListening()` (unregister, IllegalArgumentException ignored). `dispose()` stops listening and clears both handlers.

Precision: nothing is sent explicitly when listening starts: the first value is whatever the system's initial `onCapabilitiesChanged` for the current default network yields (Android normally calls it immediately after registration). Without a ConnectivityManager, `listen` returns with no events and no error.

### android/app/src/main/kotlin/app/onset/TwitchCookies.kt

Channel `onset/cookies` (`TwitchCookies.CHANNEL`). Reads the twitch.tv session cookie (`auth-token`) left by the in-app login WebView, the only credential Twitch GQL accepts for enhanced-broadcast renditions (1440p HEVC/AV1), because GQL only honours allowlisted client ids and ONSET's OAuth token belongs to ONSET's client id. Dart cannot read it itself (webview_flutter's cookie manager only writes/clears, and the cookie may be HttpOnly).

Methods:
- `getCookie {url}` → if url missing or not `https` with host `twitch.tv` or ending in `.twitch.tv` (parsed with `java.net.URI`; a URISyntaxException counts as not Twitch) → error `bad_args` "a https twitch.tv url is required". Else flushes `CookieManager` first (cookies written by the WebView live in memory until Chromium persists them; a login followed immediately by a read would race) and returns the raw `name=value; name=value` string, or null when blank/absent. Only Twitch cookies may leave the jar, since the channel is reachable from any Dart code and the jar holds every site the WebViews visited.
- `clearCookies` → `removeAllCookies {}` + `flush()`, returns null (used on logout).
- else notImplemented. `dispose()` clears the handler.

Precisions: `getCookie` returns the **whole** twitch.tv cookie string (`name=value; …`); `auth-token` is extracted on the Dart side (`TwitchWebTokenService.parseAuthToken`). The host check is case-sensitive (`uri.scheme == "https"`, `host == "twitch.tv"` or `endsWith(".twitch.tv")`), the same in Dart's `isTwitchPageUrl`.

### android/app/src/main/kotlin/app/onset/ApkInstaller.kt

Channel `onset/updates` (`ApkInstaller.CHANNEL`); error codes `install_aborted` (ABORTED), `install_failed` (FAILED), plus `outside_updates` and `superseded`; directory `updates` under the app cache.

Methods:
- `canInstall` → O+ `packageManager.canRequestPackageInstalls()`, else true.
- `openInstallSettings` → O+ only: `ACTION_MANAGE_UNKNOWN_APP_SOURCES` for `package:<pkg>` with NEW_TASK; an ActivityNotFoundException is ignored (the Dart side explains what to do). Returns null.
- `install {path}` → `updateFile(path)`: canonical file must have parent == canonical `<cacheDir>/updates`, be a file and end in `.apk`; otherwise error `outside_updates` "only a downloaded update can be installed". Else `install(file, result)`.

`install`: finishes any previous pending call with error `superseded` "another install started", stores the new `pending` result, and on a single-thread IO executor commits a session (any exception there → main-thread error `install_failed` "the update could not be handed to Android"; exceptions are never left uncaught on that thread).

`commitSession`: `PackageInstaller.SessionParams(MODE_FULL_INSTALL)` with `setAppPackageName(own package)` (the session only accepts an update of this app; Android refuses a different signing key), create + open session, `openWrite("onset.apk", 0, length)`, copy, `fsync`, then commit with a broadcast PendingIntent to the explicit non-exported `InstallResultReceiver` (request code = session id, `FLAG_UPDATE_CURRENT` plus `FLAG_MUTABLE` on API 31+ because the installer fills the status extras). On failure the session is abandoned (SecurityException ignored) and the exception rethrown. The APK is copied into a session rather than shared via content URI so no other app can read it (it embeds build-time secrets).

`InstallResultReceiver.onReceive` reads `EXTRA_STATUS` (default FAILURE): `STATUS_PENDING_USER_ACTION` → starts the system confirmation intent (`EXTRA_INTENT`, typed getter on 13+) with NEW_TASK; if missing or ActivityNotFound → `install_failed` "no installer to confirm the update"; `STATUS_SUCCESS` → success(null) (usually the process is killed by the update before); `STATUS_FAILURE_ABORTED` → `install_aborted` "the update was dismissed"; else → `install_failed` "Android refused the update". `finish` answers the pending call at most once.

Defect (see Known Android defects): `pending` is a single static slot. A second `install` answers the first call `superseded` but does not cancel the first job; the first job's late `install_failed`, or its session's broadcast (success / `install_aborted` / `install_failed` via `InstallResultReceiver`), then answers the **second** call. The receiver does not check which session the status belongs to.

### ios/Runner/AppDelegate.swift

`@main @objc class AppDelegate: FlutterAppDelegate`; `application(_:didFinishLaunchingWithOptions:)` only calls `GeneratedPluginRegistrant.register(with: self)` and super. There is no iOS implementation of any of ONSET's custom channels (`onset/ivs-texture-manager`, `onset/background-audio`, `onset/audio-focus`, `onset/cast`, `onset/network`, `onset/cookies`, `onset/updates`, `onset/floating-player`, `onset/locale`, `onset/launch`, `onset/notification-settings`); every Dart wrapper catches `MissingPluginException`/`PlatformException` and degrades (WebView engine, no background-audio notification, no cast, metered unknown, etc.). Info.plist facts: display name `ONSET`, `CFBundleLocalizations` en/fr, URL schemes `twitch` and `ttv` (`twitch-links`), `LSApplicationQueriesSchemes` https/http, `NSPhotoLibraryUsageDescription` "ONSET opens your photos only when you choose a new profile picture or banner.", `ITSAppUsesNonExemptEncryption` false, Firebase collection keys all false (`FirebaseCrashlyticsCollectionEnabled`, `FIREBASE_ANALYTICS_COLLECTION_ENABLED`, `firebase_performance_collection_enabled`), `CADisableMinimumFrameDurationOnPhone` true (ProMotion 120 Hz), `UIApplicationSupportsIndirectInputEvents` true, status bar visible, LaunchScreen storyboard, PrivacyInfo.xcprivacy present.

### packages/simple_pip_mode/lib/simple_pip.dart

Vendored fork of `simple_pip_mode` 1.0.0 (Android-only PiP). `class SimplePip` with static channel `puntito.simple_pip_mode`.
- Static getters: `isPipAvailable` (`isPipAvailable` → `?? false`), `isAutoPipAvailable` (Android S+), `isPipActivated`.
- Callbacks `onPipEntered`, `onPipExited` (VoidCallback?), `onPipAction(PipAction)`. The constructor installs the channel handler only when at least one callback is given (so a bare `SimplePip()` used for commands does not steal the handler): `onPipEntered`, `onPipExited`, `onPipAction` (argument = lowercase action name mapped with `PipAction.values.firstWhere(name == arg)`).
- `enterPipMode({aspectRatio = (16, 9), autoEnter = false, seamlessResize = false})` → `{aspectRatio: [w,h], autoEnter, seamlessResize}` → Bool.
- `setAutoPipMode({aspectRatio = (16, 9), seamlessResize = false, autoEnter = true})` → Bool (Android 12+; native error `NotImplemented` below).
- `setPipActionsLayout(layout)` → `setPipLayout {layout: name}` → Bool.
- `setIsPlaying(bool)` → `setIsPlaying {isPlaying}` → Bool: flips the play/pause remote action when playback was changed by something other than the PiP button (player button, media notification). Tapping the PiP button flips it natively.
ONSET uses: `PipWidget(pipLayout: PipActionsLayout.mediaOnlyPause)` on the channel screen; the IVS store calls `setAutoPipMode()` / `setAutoPipMode(autoEnter: false)`, `enterPipMode(autoEnter: true)` and `setIsPlaying(!paused)`, all guarded by `Platform.isAndroid`.

Precision: `onPipAction` maps the name with `PipAction.values.firstWhere(...)` without `orElse`, so an unknown action name throws `StateError` in the handler.

### packages/simple_pip_mode/lib/pip_widget.dart

`PipWidget` (StatefulWidget): `onPipEntered`, `onPipExited`, `onPipAction(PipAction)`, `builder`/`child` (normal), `pipBuilder`/`pipChild` (while in PiP), `pipLayout` (default `PipActionsLayout.none`). Asserts at least one of child/builder and one of pipChild/pipBuilder. State creates a `SimplePip` wired to its own handlers and calls `setPipActionsLayout(widget.pipLayout)` in `initState`; `_pipMode` flips with setState on enter/exit and forwards to the widget callbacks; build returns `pipBuilder(context) ?? pipChild` in PiP else `builder(context) ?? child`. ONSET's `lib/utils/pip_callbacks.dart` re-creates the SimplePip and re-applies the layout when the PiP owner changes. No animation of its own (the OS animates the window).

### packages/simple_pip_mode/lib/aspect_ratio.dart

`typedef AspectRatio = (int, int)` (a Dart record) with extension `AspectRatioExtension`: `width` = `$1`, `height` = `$2`, `name` = `'$width:$height'`, `asList` = `[width, height]` (sent over the channel). Default everywhere `(16, 9)`. This is a tiny helper, but the PC rewrite must keep the 16:9 default for the mini window's aspect ratio.

### packages/simple_pip_mode/lib/actions/pip_action.dart

`enum PipAction { play, pause, previous, next, live }` — documented as: play (triangle icon), pause (double bars), previous, next, live (forces the player to the latest content, "surround" icon). Native defines each action's drawable, title, description and the "after action" (play↔pause). Names travel lowercase over the channel.

### packages/simple_pip_mode/lib/actions/pip_actions_layout.dart

`enum PipActionsLayout { none, media, mediaOnlyPause, mediaLive }`: none = no actions; media = previous, play/pause, next (in that order); mediaOnlyPause = only play/pause (what ONSET uses); mediaLive = live then play/pause. Sent by `name`; native upper-cases and strips underscores (`MEDIAONLYPAUSE`).

### packages/simple_pip_mode/android/src/main/kotlin/cl/puntito/simple_pip_mode/SimplePipModePlugin.kt

`SimplePipModePlugin: FlutterPlugin, MethodCallHandler, ActivityAware` on channel `puntito.simple_pip_mode`. On attach: creates the channel, gives it to a `PipCallbackHelper`, registers a broadcast receiver (`ContextCompat.registerReceiver(..., IntentFilter("SIMPLE_PIP_ACTION"), RECEIVER_EXPORTED)`) that reads `EXTRA_ACTION_TYPE`, maps it with `PipAction.valueOf`, toggles the action if it has an after-action (re-rendering the remote actions) and calls `onPipAction` → Dart `onPipAction(<lowercase name>)`. Detach clears the handler and unregisters the receiver.

Methods (API 26+): `getPlatformVersion` → `"Android <release>"`; `isPipAvailable` → `hasSystemFeature(FEATURE_PICTURE_IN_PICTURE)`; `isPipActivated` → `activity.isInPictureInPictureMode`; `isAutoPipAvailable` → SDK ≥ S; `enterPipMode {aspectRatio, autoEnter, seamlessResize}` → `PictureInPictureParams.Builder().setAspectRatio(Rational(w,h)).setActions(actions)` plus on S+ `setAutoEnterEnabled`/`setSeamlessResizeEnabled`, stores the builder, returns `activity.enterPictureInPictureMode(params)`; `setPipLayout {layout}` → `PipActionsLayout.valueOf(upper, no underscores)`, rebuilds `actions`, true or false on bad name; `setIsPlaying {isPlaying}` → when the layout contains PLAY or PAUSE replaces that slot with PAUSE (playing) or PLAY and re-renders, returns true, else false; `setAutoPipMode {...}` → S+ sets params on the activity (`setPictureInPictureParams`) and returns true, else error `NotImplemented` "System Version less than Android S found" / "Expected Android S or newer."; other → notImplemented. `renderPipActions()` rebuilds the remote actions and, if params exist, re-applies them to the activity.

Defects (see Known Android defects):
- The PiP action receiver is registered with `RECEIVER_EXPORTED`, and the remote actions use an implicit `Intent("SIMPLE_PIP_ACTION")` with no package. Any installed app can broadcast it with `EXTRA_ACTION_TYPE` `PLAY`/`PAUSE`/`LIVE` to pause or resume ONSET and flip the persistent `PipActionsLayout.actions` state; any other value makes `PipAction.valueOf` throw `IllegalArgumentException` inside `onReceive`, killing the process. (Contrast `AudioFocusBridge`, which uses `RECEIVER_NOT_EXPORTED`.)
- Below API 26 (the app's minSdk is 24 with Flutter 3.38): `setPipLayout` builds `RemoteAction`s and `enterPipMode` uses `PictureInPictureParams`, both API 26 classes. `catch (e: Exception)` does not catch `NoClassDefFoundError`/`NoSuchMethodError`, and Dart callers gate only on `Platform.isAndroid` (`PipWidget.initState`, `lib/utils/pip_callbacks.dart`), so Android 7.x likely crashes when a player screen opens. **Unconfirmed** (needs an API 24/25 emulator run).
- `lateinit var activity`: a call before `onAttachedToActivity` throws `UninitializedPropertyAccessException`.

### packages/simple_pip_mode/android/src/main/kotlin/cl/puntito/simple_pip_mode/PipCallbackHelper.kt

`open class PipCallbackHelper`: channel `puntito.simple_pip_mode` (created from the engine in `configureFlutterEngine` or injected with `setChannel`). `onPictureInPictureModeChanged(active)` → invokes `onPipEntered` or `onPipExited` (no args). `onPipAction(action)` → invokes `onPipAction` with `action.name.lowercase()`.

### packages/simple_pip_mode/android/src/main/kotlin/cl/puntito/simple_pip_mode/PipCallbackHelperActivityWrapper.kt

`open class PipCallbackHelperActivityWrapper: FlutterActivity()` holding a `PipCallbackHelper`; `configureFlutterEngine` wires the helper's channel; `onPictureInPictureModeChanged(active, newConfig)` calls super and forwards to the helper. ONSET's `MainActivity` extends it, so PiP entry/exit reaches the Dart `PipWidget` (the channel screen swaps to its video-only PiP layout).

### packages/simple_pip_mode/android/src/main/kotlin/cl/puntito/simple_pip_mode/Constants.kt

`object Constants { SIMPLE_PIP_ACTION = "SIMPLE_PIP_ACTION"; EXTRA_ACTION_TYPE = "EXTRA_ACTION_TYPE" }` — the broadcast action and extra key used by PiP remote-action PendingIntents and the plugin's receiver.

### packages/simple_pip_mode/android/src/main/kotlin/cl/puntito/simple_pip_mode/actions/PipAction.kt

`enum class PipAction(icon, title, description, afterAction: String?)`:
- `PLAY` — `ic_baseline_play_arrow_24`, `pip_action_play`, `pip_action_play_description`, after `PAUSE`.
- `PAUSE` — `ic_baseline_pause_24`, `pip_action_pause`, `pip_action_pause_description`, after `PLAY`.
- `NEXT` — `ic_baseline_skip_next_24`, `pip_action_next`, `pip_action_next_description`.
- `PREVIOUS` — `ic_baseline_skip_previous_24`, `pip_action_previous`, `pip_action_previous_description`.
- `LIVE` — `ic_surround_sound_24`, `pip_action_live`, `pip_action_live_description`.
`toRemoteAction(context)` → `RemoteAction(icon, title, description, PendingIntent.getBroadcast(request = ordinal, Intent("SIMPLE_PIP_ACTION").putExtra("EXTRA_ACTION_TYPE", name), UPDATE_CURRENT|IMMUTABLE))`. `afterAction()` → `valueOf(afterAction)` or null.
Plugin strings: EN `Play`/"Play media", `Pause`/"Pause media", `Next`/"Skip to next media", `Previous`/"Go back to previous media", `Live`/"Jump to live"; FR (`values-fr`) `Lire`/"Lancer la lecture", `Mettre en pause`/"Mettre la lecture en pause", `Suivant`/"Passer au contenu suivant", `Précédent`/"Revenir au contenu précédent", `Direct`/"Revenir au direct".

### packages/simple_pip_mode/android/src/main/kotlin/cl/puntito/simple_pip_mode/actions/PipActionsLayout.kt

`enum class PipActionsLayout(actions: MutableList<PipAction>)`: `NONE []`, `MEDIA [PREVIOUS, PAUSE, NEXT]`, `MEDIAONLYPAUSE [PAUSE]`, `MEDIALIVE [LIVE, PAUSE]` (initial slot is PAUSE: entering PiP assumes playback). `remoteActions(context)` maps them to RemoteActions. `toggleToAfterAction(action)` replaces the slot holding that action with its after-action (PAUSE→PLAY after a tap and vice versa). Note: the lists are mutable enum state, so the toggled state persists for the process lifetime.
