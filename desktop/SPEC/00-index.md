# ONSET PC memoir: index

The complete specification of ONSET Android (Flutter) used to rebuild it natively in Rust for Windows, with nothing lost. Every source and test file of the Android app is covered; each area spec passed coverage, section and string checks and two independent ECC reviews. Where specs proposed different PC approaches, the decisions below are binding.

| Spec | Area |
|---|---|
| [01-home.md](01-home.md) | Shell, Following, Live feed, Browse, categories, tags, search, Continue watching, followed videos |
| [02-channel-player.md](02-channel-player.md) | Live channel screen, all layouts, IVS/media_kit/WebView engines, latency controller, overlay, clips creation, pop-out |
| [03-chat-core.md](03-chat-core.md) | Chat logic: IRC, emote providers, 7TV EventAPI, delay sync, commands, filters, history, mod tools, emote menu |
| [04-chat-widgets.md](04-chat-widgets.md) | Chat rendering and every chat sheet, dialog, points and predictions UI |
| [05-live-events.md](05-live-events.md) | Community highlights, hype train and its effects, celebrations and particles |
| [06-vod-clips.md](06-vod-clips.md) | VOD screen, chat replay, up next, resume; clips feed, clip screens, recaps |
| [07-social.md](07-social.md) | Channel profile, activity, Twitch notifications inbox, whispers |
| [08-settings.md](08-settings.md) | Settings, every setting key and default, account pages, auth flows, updates UI |
| [09-foundation-ui.md](09-foundation-ui.md) | Design system, theme tokens, motion, launch intro, shared widgets, onboarding, startup, repo guards |
| [10-apis-models.md](10-apis-models.md) | Every API call (Helix, GQL, usher, 7TV, BTTV, FFZ, Giphy, GitHub) and every model |
| [11-services-native.md](11-services-native.md) | Services, global stores, realtime sockets, go-live, notifications, l10n, all native Android code |
| [12-tests-index.md](12-tests-index.md) | Every test group and test call of the Android suite: the behavioural oracle to port |

The parity matrix ([../PARITY.md](../PARITY.md)) maps each Android file to its Rust crate and the proof that closes it, and collects every Android defect the PC port fixes.

Tools: `desktop/tools/spec-coverage.mjs`, `spec-sections.mjs`, `spec-strings.mjs`, `tests-index.mjs`, `parity.mjs`.

## Crates and dependency rule

| Crate | Owns | May depend on |
|---|---|---|
| `onset-core` | Models, every API service, auth and token logic, settings, stores' state machines, chat protocol and logic, realtime sockets, i18n, and every trait the platform implements: `Telemetry`, `ActivityLog`, `Notifier`, `Installer`, `SecureStore`, `MediaKeys`, `Tray`, `WebView`, `WebCookies`, `PowerRequest`, `AudioInterruptions`, `Share`, `CastBackend`, `NetworkCost`, `FilePicker`, `UrlLauncher`, `DeepLinks`, `SingleInstance`, `Autostart`, `Haptics`, `AppLanguage` | nothing else in the workspace |
| `onset-player` | LL-HLS fetcher with Twitch prefetch, libmpv glue, latency controller, live-edge guard, buffer fallback, recovery, VOD and clip playback, previews, the WebView player engine adapter | `onset-core` |
| `onset-platform` | Windows implementations of the core traits (later macOS/Linux modules): toasts, tray, SMTC, keyring, WebView2, cookies, metering, updater, deep links, single instance, autostart, power requests | `onset-core` |
| `onset-ui` | Slint design system, every screen, sheet and animation | `onset-core` (including its traits) and `onset-player`; never `onset-platform` |
| `onset-app` | Binary: wiring, windows (main and always-on-top mini player), lifecycle | everything |

Rust modules follow the specs, not Dart file boundaries: a Dart file that mixes logic and widgets is split (logic in `onset-core`, drawing in `onset-ui`). In PARITY, a file importing Flutter widgets is owned by `onset-ui`; a widget-free file by `onset-core` (or player/platform by role); rows marked "split" import from a higher layer and are split along the spec when ported. Cargo enforces the dependency rule at build time.

## Decisions

| # | Topic | Decision |
|---|---|---|
| D1 | Player engines | Exactly as on Android: native engine (libmpv + Rust LL-HLS replacing IVS) and the Twitch web engine through `wry` behind the `WebView` trait (WebView2 on Windows; WKWebView / WebKitGTK later) for live, VOD and clips, with the same automatic fallback rules and the same engine setting. The WebView fallback always works. |
| D2 | Video backend | libmpv (render API, `d3d11va` hwdec on Windows). No FFmpeg/GStreamer alternative. |
| D3 | UI toolkit | Slint with the Skia renderer; iced is the only fallback, chosen solely if the phase 1 prototype fails a gate. |
| D4 | Install and update | Velopack (installer, delta updates, Rust SDK) behind the `Installer` trait, fed by a custom update source that downloads with ONSET's own HTTP client (redirects off, every hop re-checked against the host allowlist) and verifies the release asset's SHA-256 before applying. No Authenticode requirement (personal unsigned build), no MSIX, no `self_update`. |
| D5 | Mini player | Both, as on Android: the in-app mini player (GlobalMiniPlayer) stays inside the main window, and the floating player / PiP become a separate always-on-top OS window. |
| D6 | Go-live polling | 90 s while ONSET runs. While go-live notifications are on, ONSET starts at sign-in minimised to the tray (`Autostart`), keeps running in the tray when the window closes, and stops polling only on an explicit Quit — so notices survive a reboot like Android's WorkManager. No 15-minute mode. |
| D7 | Toast notifications | WinRT `ToastNotificationManager` through the `windows` crate, behind the `Notifier` trait; scheduled reminders use `ScheduledToastNotification` so they fire even when ONSET is closed. |
| D8 | Audio interruptions | Behind `AudioInterruptions`: pause when the output device is removed (never auto-resume, like headphone unplug); pause on Windows communications ducking and resume when it ends, like Android's transient audio-focus loss. |
| D9 | Keep screen awake | Behind `PowerRequest` (`SetThreadExecutionState(ES_CONTINUOUS \| ES_DISPLAY_REQUIRED)` on Windows): taken and released exactly where Android calls `WakelockPlus.enable/disable` — channel screen, chat tabs, VOD, clip and clips feed screens, regardless of play/pause — behind the `keepScreenAwake` setting (default on); the clip story screen takes it unconditionally, as on Android. |
| D10 | Cast | Kept: `rust_cast` + `mdns-sd`; the button behaves as on Android when a device is found. |
| D11 | Share | Behind `Share`: Windows Share UI (`DataTransferManager`) is the primary share action, with copy-link always available. |
| D12 | Haptics | Behind `Haptics`: no haptic hardware on PC, so calls are no-ops; every visual feedback is kept. |
| D13 | Media keys | SMTC through the `windows` crate (`ISystemMediaTransportControlsInterop`) behind `MediaKeys`; souvlaki is not used. |
