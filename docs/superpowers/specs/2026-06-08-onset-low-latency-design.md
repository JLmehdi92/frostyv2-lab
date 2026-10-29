# ONSET Low-Latency Player — Design

**Date:** 2026-06-08
**Status:** Approved (pending spec review)
**Author:** brainstormed with user

## Problem

ONSET (mobile Twitch client, Flutter) shows 7TV/BTTV/FFZ emotes and full mod
visibility, but its video runs ~8–15s behind live because it plays the **Twitch
web player inside a `webview_flutter` WebView** (`player.twitch.tv` embed):

```
https://player.twitch.tv/?channel=$userLogin&muted=false&parent=onset
```

The official Twitch app uses a **native low-latency HLS player** (~2–4s). The
user wants that low latency **without losing any feature**, for personal Android
use (developer is on Windows).

## Goal & non-goals

- **Goal:** Native low-latency HLS playback, target ~2–4s (matching the official
  app is the practical floor; we cannot beat Twitch's delivery latency).
- **Goal:** Preserve 100% of existing features.
- **Non-goal (now):** iOS build/publish (no Mac), store publishing, ad system.
- **Non-goal:** Redesigning chat or any non-player subsystem.

## Key insight — features are independent of the player

The 7TV-extension-like features the user cares about are **not** in the player:

- Emotes (7TV/BTTV/FFZ), badges, autocomplete → chat layer.
- **Deleted messages** (`CLEARMSG`) → already in `lib/models/irc.dart:105` +
  `chat_message.dart:380`, via `showDeletedMessages` setting and tap-to-reveal
  (`revealedMessageIds`).
- **Timeouts / bans** (`CLEARCHAT` + `ban-duration`) → already rendered in
  `chat_message.dart:344` ("Timed out for N seconds", "Permanently banned").
- Chat-delay sync with stream latency → `video_store.dart`.

Therefore the latency work touches **only the video subsystem**; the chat layer
is left untouched, guaranteeing feature preservation.

## Approach

Replace the WebView with a **native HLS player** as the default engine, keeping
the WebView as a **selectable fallback**.

### Components

1. **`TwitchStreamService`** (`lib/apis/`, extends `BaseApiClient`)
   - Fetches `PlaybackAccessToken` via Twitch GQL.
   - Builds the `usher.ttvnw.net` master `.m3u8` URL with low-latency flags.
   - Parses variant playlists → quality list.
   - Defensive: on any failure, surfaces an error the UI can use to fall back to
     the WebView engine.

2. **Native player store** (`lib/screens/channel/video/stores/`, MobX)
   - Wraps a `media_kit` (libmpv) `Player`.
   - libmpv tuned for low latency: minimal demuxer cache, start at live edge,
     resync-to-live on stall.
   - Exposes: quality list + selection, play/pause, current latency estimate,
     buffering state.
   - Latency estimate feeds the existing overlay badge and chat-delay auto-sync.

3. **Player engine switch** (settings)
   - `PlayerEngine { nativeLowLatency, twitchWeb }` in `settings_store`.
   - Default `nativeLowLatency`; `twitchWeb` keeps current behavior verbatim.
   - `video.dart` chooses the widget tree based on the engine.

4. **Overlay parity** — reuse `video_overlay.dart` controls (play/pause,
   fullscreen, PiP, quality menu, latency badge) wired to whichever store is
   active, so the UX feels identical.

### Data flow

```
channel screen
  └─ video.dart  ──(engine == native)──> NativeVideoStore ─> media_kit Player
       │                                      ↑   uses
       │                                 TwitchStreamService (GQL token + m3u8)
       └─(engine == twitchWeb)─────────> existing VideoStore ─> WebView (unchanged)
  overlay (video_overlay.dart) binds to the active store
  chat subsystem: UNCHANGED
```

## Error handling & risks

- **Twitch API changes (GQL/usher):** native engine fails → user can switch to
  `twitchWeb` engine; consider an automatic one-time fallback on first failure.
- **Ads:** raw HLS may contain/skip ad segments; player must not crash on
  discontinuities (libmpv handles HLS discontinuities).
- **iOS compatibility:** `media_kit` supports iOS; keep code platform-neutral so
  a later Mac build works.
- **Verification gap:** latency can only be confirmed on a real Android device
  with Twitch credentials; the overlay must show a live latency number for A/B
  comparison against the WebView engine.

## Testing

- Unit-test `TwitchStreamService` m3u8/variant parsing with `http_mock_adapter`
  fixtures (mirror existing `test/fixtures/` style).
- Unit-test the native store's quality/latency state transitions with `mocktail`.
- Keep all existing tests green (`flutter test`).
- Manual device matrix: native engine plays, quality switch works, PiP/theater
  work, latency badge updates, chat mod-actions/emotes intact, fallback engine
  launches.

## Phasing

- **Phase 0:** Install Flutter + Android SDK on Windows; run the *unmodified* app
  on the device (proves toolchain + Twitch credentials).
- **Phase 1:** Add `TwitchStreamService` + native store + `media_kit`, behind the
  engine toggle (WebView stays default). Measure latency.
- **Phase 2:** Make native the default; overlay parity; wire latency → chat sync.
- **Phase 3:** Full feature-preservation pass + security-review + code-review.
