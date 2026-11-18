# 09 — Foundation UI: design system, startup, shared widgets, onboarding, test infrastructure

> Cross-spec decisions in [00-index.md](00-index.md) (section "Decisions") override any conflicting PC suggestion in this file.

Source of truth: the ONSET Flutter app at `/home/user/frostyv2-lab` (Flutter 3.38.4 / Dart 3.10.3). This leaf specifies, for a native Rust rewrite (Slint UI on Skia, Windows first, macOS/Linux later), everything in `lib/main.dart`, `lib/theme.dart`, `lib/constants.dart`, `lib/utils/**`, `lib/widgets/**`, `lib/screens/onboarding/**`, the bundled `assets/`, and the test infrastructure that encodes the repo's rules (`test/guards`, `test/helpers`, `test/fixtures`, `test/semantics`, `test/widgets`, `test/utils`, `test/theme`, `test/theme_test.dart`, `test/constants_test.dart`, `test/workflows`, `test/screens/onboarding`, `test/screens/lot5_links_and_prompts_test.dart`). All numeric values are logical pixels (dp) unless said otherwise; colours are ARGB hex (`0xAARRGGBB`) or `#RRGGBB` (opaque). Durations are milliseconds. Curves `Cubic(a, b, c, d)` are CSS `cubic-bezier(a, b, c, d)`.

## Purpose

This leaf is the foundation every other leaf builds on:

1. **The design system "Noir & Signal" (1.0 + 2.0)** — colour tokens for dark and light themes, the electric-lime accent (`#C8FF3D`) whose only meaning is "live / active selection", the 0.5 dp hairline depth model (no elevation, no drop shadows as a depth device; the full list of shadows that do exist: the floating mini player (two shadows), the tablet anchored panel (two shadows), the coach-mark bubble (Material elevation 6), the launch-intro tile glow and the landing tile glow (accent α 0.25 [× (1 − flight)], blur 40/48), the onboarding brand tile glow (same values), the OnboardingSwitch knob (0x59000000 blur 2 offset (0,1)), the AccentPickerThumb (0x80000000 blur 4 offset (0,1)), the Setup accent swatch ring (spread shadows #141414 2 / 0xE6F5F5F5 3.5), the Cast icon shadow (0x66000000 blur 6) and the text shadow `kOverlayShadow` (rgba(0,0,0,0.3) blur 4 offset (0,1)) for text over video), radii 8 / 12 / 16 / 24 / pill(100) plus badge 6 and panel 20, the 4-pt spacing grid, the Inter-only type scale with tabular figures for every changing number, the Material component themes, and the two ThemeExtensions (`OnsetColors`, `OnsetTextStyles`).
2. **Motion** — spring and curve tokens, reduce-motion handling, haptics, press scale, rolling numbers, the live "signal ping", staggered entrances, and the 1.4 s cold-start launch intro with its exact storyboard and the onboarding "landing" replay.
3. **The app shell plumbing** — `main()` startup order, dependency graph (providers), `MaterialApp` configuration, navigator observers, the builder stack (locale sync → launch intro → global mini player overlay), deep links (`https://twitch.tv/...`, `twitch://`, `ttv://`), notification taps (go-live, mentions, notification-settings intent), in-app review prompt, external-link confirmation gate.
4. **Shared widgets** used by every feature: sheet kit (`showOnsetSheet`, rows, switch, buttons, pills, dialog, text field), tablet anchored panels, the three glyph sets (sheet, state, onboarding) drawn from verbatim SVG path data, state views (empty / error / logged out / inline), skeleton loaders with a screen-wide sheen, blur containers that never blur video, the floating mini player, follow flow, recommendations, report / share / user actions, photo viewer, coach marks, chips, scrollbar, in-flow notifications, Cast button, update prompt, profile picture, uptime, Twitch web page, accent picker controls, adaptive grid list, draggable splitter.
5. **Utilities** — link parsing (`TwitchLink`), link routing, contrast-correcting chat name colours, punycode, IRC PRIVMSG synthesis, sheets that start under the video, share with clipboard fallback, stream language filter, content labels, image sizing, large-screen detection (`kLargeScreenShortestSide = 600`).
6. **The first-launch onboarding** — Intro (live mosaic, language pill), Log in (permission list mapped to OAuth scopes), the Twitch login WebView, Setup (account pill, live preview, theme, accent picker, chat history, crash reports), Welcome (three tips), and the hand-over to Home.
7. **The test rules** — every guard in `test/guards` is a permanent repository rule that the Rust project must re-implement as its own guard (listed with a Rust equivalent in "Tested behaviour").

Non-negotiable for the rewrite: no feature removed; WebView fallback engine and chat untouched by this layer; Twitch token / GQL failures degrade quietly; no Twitch client secret in the binary; every user-facing string is localised in English and French.

## Screens and layouts

**App root.** `MaterialApp(title 'ONSET')` with `home` = `OnboardingFlow` on first run (`first_run` pref absent/true) else `Home`. The builder wraps every route in, outermost first: `LocaleSync` → `LaunchIntro` (full-screen overlay on cold start) → `Stack[route, Positioned.fill(GlobalMiniPlayer)]`. So the floating mini player sits above all pages, and the intro above everything including the mini player.

**Launch intro overlay** (cold start only): black `#0A0A0A` ground, a 72 dp tile (lime `#D6F427` ground + ONSET icon bitmap, 20 dp corners, lime glow blur 40 phone / 48 tablet), two expanding lime rings, the "ONSET" wordmark (Inter 800, 34 sp phone / 40 sp tablet, 5 letters rising over a 120 / 140 × 2 dp lime underline 12 dp below the letters, 30 / 31 dp below the tile), then the tile flies to the header mark slot (phone fallback rect (16, top+14, 28, 28); tablet (28, top+21, 30, 30)). Full geometry and timeline in "Animations and motion".

**Onboarding** (always black, dark theme seeded with the current accent):
- *Phone portrait*: full-window brand layer (mosaic at top, height min(0.52 h, 440), tilted −8°, fading to black), the tile centred where the intro left it (raised on short windows, possibly scaled down to 60 %), the wordmark under it; top bar 56 dp under the status bar (back chevron 44 dp hidden on Intro, 4-segment progress centred, 44 dp spacer); step content padded LTRB(24, top + 68, 24, bottom + 20); footer buttons stacked full width (primary 52 dp pill, secondary text button 44 dp). On a phone the brand (mosaic/tile/name) only shows on Intro and leaves with it.
- *Phone landscape* (split screen, freeform window): tile + name centred in a left part of width min(max(0.42 usable, nameWidth + 48), 0.5 usable); description / language pill / version / Next in a right column.
- *Tablet landscape*: left brand pane width clamp(0.4375 w, 360, 560) with mosaic, tile centred, version bottom-left; 0.5 dp divider; right step pane with a 72 dp bar and padding 80 (pane ≥ 600) or 48 dp sides, top + 104, bottom + 40; footer buttons in a row at the bottom right (primary 220 dp, 250 on Log in).
- *Tablet portrait*: top brand pane height clamp(0.36 h, 320, 480); steps below with padding LTRB(64, 104, 64, bottom + 40).
- Steps: **Intro** (description under the name, "English | Français" pill 232 dp wide at text scale 1, version "vX.Y.Z (build)", Next with arrow); tablet Intro shows an uppercase eyebrow "First launch" and the description as a 40 / 32 sp headline. **Log in** (title, lead, "What you’ll authorize" card listing 7 permission rows with 32 dp icon tiles on phone / a 2-column grid of cards with 36 dp tiles on tablet, disclaimer, "Log in with Twitch" primary with login glyph, "Skip" secondary). **Twitch page** (bar: back, centred "Log in with Twitch" title, "?" help; a 30 dp host strip with lock; the WebView panel `#111111`, centred max 560 dp on tablet; overlays "Signing you in…", "page failed + Try again", and a red-tinted failure line). **Setup** (title, lead, account pill, a card containing: live preview row, Theme segmented pill System / Light / Dark with a right-aligned note, Accent colour row with hex + swatch + chevron, Chat history switch with a robotty.de link, Crash reports switch; Next). **Welcome** (title, lead, three numbered tip cards, "Let's go!").
- Accent picker: bottom sheet (phone) or 420 dp dialog (tablet) with title + hex + swatch, 168 dp saturation/brightness square, 44 dp hue slider, "Random" pill, Cancel / Done.
- Login help dialog: 24 dp corners, `#1E1E1E`, 40 dp icon tile, title, body, Close; 440 dp wide on tablet.

**Standalone login page** (`LoginWebView`): same bar and panel as the onboarding's web step, in the black theme, used from Profile, session-expired prompts, clip creation and the follow flow.

**Sheets** (`showOnsetSheet`): `#141414` (`#181818` for a sheet over a sheet) in dark, white in light; 24 dp top corners; 0.5 dp light top edge; 36 × 4 handle (8 above, 4 below); scrim black 62 %; rows 52 dp (60 with a second line), 16 dp side padding, 14 dp icon gap; section labels 11 / 600 uppercase tracked 1.54. On the phone channel screen sheets start 12 dp under the video and never dim it.

**Tablet anchored panels** (`showSheetOrPanel`): `#181818`, 20 dp corners, 0.5 ring, two black shadows, a 12 dp rotated-square nub pointing at the anchor, 12 dp gap / margin, never overlapping the video; fall back to sheets on phones or when nothing fits.

**Dialogs**: `OnsetDialog` 326 dp max width card, 24 dp corners, `#1E1E1E`, title 18 / 700, 20 dp padding, actions wrapped to the end with 8 dp gaps. `OnsetAlertDialog` (Material AlertDialog with full-width 50/50 action row). External link dialog, update available (sheet on phone / 420 dp dialog on tablet), update progress dialog, follow/unfollow confirmations, report web fallback, Twitch TV session offer.

**State views**: centred mark (72 dp disc phone / 88 tablet / 64 quiet; or the "signal off" ring 88 / 104), message (max 260 / 360 dp wide), optional detail (max 280), one action pill (44 / 48 dp raised outline pill, or the 48 dp lime primary pill for "Log in with Twitch"). Inline status: 18 dp glyph + message + compact 36 dp "Try again".

**Floating mini player**: 42 % of window width, 16:9, 16 dp corners, black, inner 0.5 hairline, two shadows, close disc 26 dp in a 44 dp target at top-right, rests in one of four corners 12 dp from the edges, under the header / above the bottom bar (or under a 56 dp app bar on other pages); dashed landing-corner targets while dragging.

**Other surfaces**: photo viewer (full screen, blurred or 40 % black scrim, close at top, "Original / Thumbnail" tonal button at 80 % height), coach mark bubble (240 dp lime card, radius 14, elevation 6), recommendations shelf (horizontal list of 112 / 132 dp tiles with 62 % width round avatars), similar-channels sheet, follow suggestions sheet, report sheet (reasons → confirmation with text field), share sheet (chat / whisper / system), user actions "More" sheet, Cast sheet, Twitch web page (transparent app bar with fading blur header, WebView below).

**Bundled assets used by this leaf** (`pubspec.yaml` `flutter.assets` / `fonts`; the PC build ships the same files):
| asset | size / pixels | use |
|---|---|---|
| `assets/fonts/Inter-Light.ttf` (w300), `Inter-Regular.ttf` (w400), `Inter-Italic.ttf` (w400 italic), `Inter-Medium.ttf` (w500), `Inter-SemiBold.ttf` (w600), `Inter-Bold.ttf` (w700), `Inter-BoldItalic.ttf` (w700 italic), `Inter-ExtraBold.ttf` (w800), `Inter-Black.ttf` (w900) | ~412–425 KB each | the only typeface (family "Inter"); weights declared so bold is never synthesised; no 100/200 faces (they resolve to Light 300) |
| `assets/fonts/OFL.txt` | 4 379 B | Inter licence, registered by `registerFontLicenses()` at startup (shown in About › licences) |
| `assets/icons/onset_logo_30.png`, `onset_logo_52.png`, `onset_logo_72.png` | 30², 52², 72² px | ONSET mark families at 1.0x (header 28/30, release notes & update 52, launch 72) |
| `assets/icons/1.5x/onset_logo_{30,52,72}.png` | 45², 78², 108² | 1.5x variants |
| `assets/icons/2.0x/onset_logo_{30,52,72}.png` | 60², 104², 144² | 2.0x |
| `assets/icons/3.0x/onset_logo_{30,52,72}.png` | 90², 156², 216² | 3.0x |
| `assets/icons/4.0x/onset_logo_{30,52,72}.png` | 120², 208², 288² | 4.0x (written by `tool/onset_logo_assets.py` from the 1024 icon) |
| `assets/icons/icon_onset.png` | 1024² | launcher icon source ("ON" with rays and dot on a lime halftone; ground mean #D6F427) |
| `assets/icons/icon_onset_foreground.png` | 1024² | Android adaptive-icon foreground |
| `assets/celebrations/rocket.svg`, `gift_closed.png` (512²), `gift_open.png` (512²), `spark_lime.png`, `spark_mint.png`, `spark_white.png`, `spark_dot.png` (128² each) | — | ONSET's own celebration particles (channel leaf); listed here because `test/guards/no_twitch_animations_test.dart` forbids replacing them with Lottie/third-party animations |
| `assets/release-notes.md`, `assets/release-notes.fr.md` | 1.7 KB / 2.2 KB | in-app release notes (update sheet / "What's new" page, tested by `test/widgets/onset_update_sheet_test.dart`) |
PC: Windows icon `.ico` generated from `icon_onset.png` (16, 24, 32, 48, 64, 256 px), the mark families mapped to display scale 100/150/200/300/400 %, Inter registered with Skia's font manager at startup (no system fallback for UI text).

## Behaviour and state

**Startup (`main`)** — exact order (details in `### lib/main.dart`): binding + font licences → start `LaunchInfo.load()` (cold start? native splash tile?) → precache the ONSET mark (72 and 30 dp families, ≤ 300 ms, never blocks) → `MediaKit.ensureInitialized()` → schedule image-cache orphan sweep → in parallel Telemetry init, SharedPreferences, `initUtils` (iPad detection) → `first_run` read; on first run wipe secure storage in the background (uninstall leftover workaround, must be kept) → settings JSON (`settings` pref, `{}` default) → Firebase collection follows `shareCrashLogsAndAnalytics` (never in debug) → debounced settings persistence (immediate on background) → Android 13 per-app language two-way sync (and on every resume) → shared Dio + Twitch/BTTV/FFZ/7TV clients → separate anonymous GQL Dio (connect 5 s, receive 8 s, never carries the Helix token) and its ~16 GQL services → anonymous realtime (Hermes) client and the shared 1 s timer, both paused in background → global assets store → AuthStore + auth/401 interceptors → Twitch TV device session store + interceptor + points service → VOD service web-token hooks → `authStore.init()` → Twitch TV login offer reacting to account changes → EventSub client (whispers) → go-live prefs follow the logged-in user → activity log + schedule reminders (refreshed now and on each resume) → mention alerts → in-app go-live poller → whisper store → crash key `is_logged_in` (bool only) → await mark precache → `runApp(MultiProvider(...))`.

**Routing and links**:
- `TwitchLink.parse` classifies URLs (VOD, clip, channel clips, channel videos, profile About/Schedule, channel, channel chat, category by slug or name, category videos, collection, search, browse, following, activity, other). App schemes `twitch://` / `ttv://` are converted to web URLs first.
- `handleDeepLink` (initial link with 3 s timeout + stream): skip the intro; in-app links (videos, clips, profiles) open their screen; categories open the category page (Helix search by slug/name) or twitch.tv inside the app; browse / following / activity / search switch the home shell; collections open their first video; channels look the user up via Helix then push the channel screen (chat-only for `/chat`, follow offer for `?followChannel=true`); anything else (or lookup failure) shows a snackbar "Couldn't open “uri”." with an "Open in browser" icon.
- `LinkRouter.open` (chat links): in-app handler first; scheme-less links become https; only http/https are launched (external app or in-app browser view per `launchUrlExternal`); non-Twitch hosts first pass the external-link confirmation (setting `confirmExternalLinks`, default true, with a "Don't ask again" switch); Twitch hosts never ask.
- Go-live notification tap: opens the channel; if it went offline meanwhile and a latest VOD exists, the channel route is replaced by that VOD. Mention notification tap: brings the chat back (bring to front / pop back to the channel / snackbar "You were mentioned in X's chat." when under a player or conversation / restore the mini player / open the channel). Android "notification settings" intent opens ONSET's notification settings page.
- In-app review: `advanced_in_app_review` monitor with min 7 days between reminders, 1 day after install, 5 launches, 3 s delay.

**Themes**: rebuilt reactively (`Observer`) from `settingsStore.accentColor` (seed) and `themeType` (system / light / dark); themes cached per seed.

**Launch intro states**: not playing (warm start, reduce motion, screen reader) → overlay absent and entrance gate open; playing → overlay, gate closed until 0.70; ended by completion, tap, deep link, any route push, or app inactive/hidden/paused. First run: holds on the name at 0.56 and publishes the resting tile rect for the onboarding; the onboarding's "Let's go!" plays the landing (cover → swap route → flight → reveal).

**Onboarding state machine**: steps intro → login → (web) → setup → welcome, with `back` mapping; reaching Welcome writes `first_run = false`; "Let's go!" writes it again and replaces the onboarding route by Home in place (or pushAndRemoveUntil). The Intro's language pill writes `appLanguage` immediately; "Next" on Intro stores the language shown even without a tap. Login outcome tracked as none / pending / failed (latest attempt only). Phone portrait lock while the onboarding is current.

**Login WebView state**: page host shown, signing-in overlay with a 20 s limit, token captured → login future; Twitch redirect to twitch.tv → web-cookie harvest (5 s cap) → close / move on; user declined → failure line; main-frame load error → failure overlay; retry renews the OAuth state; closing invalidates the state.

**Follow**: optimistic toggle with pending set (rows dimmed 50 % and non-interactive), confirm before unfollow, state read before sending when unknown, web session auto-connect with a 1-minute cooldown, TV-session offer once on Twitch's integrity refusal, result snackbars with Retry / Log in / Connect actions, follow suggestions after a follow from a prompt (max 5 live channels of the same category not yet followed).

**Recommendations / Not interested**: hidden channels stored in settings (`notInterestedChannels` map id → name) and filtered everywhere; signed-in viewers also tell Twitch; Undo restores.

**Mini player**: visible when `MiniPlayerStore.visible && player != null`; corner state, drag/snap, glide on chrome changes, restore pushes the channel which adopts the running player, close stops it; PiP shows only the video.

**Update checks** (Home): remove installed downloads, check after first frame and on each resume (single flight), offer sheet/dialog, postpone on Later, install-permission round-trip, download with progress and cancel, error snackbars.

**Coach marks**: one per `NewFeature`, shown 600 ms after first build if unseen and its predecessor is seen; tracks its target every frame, hides when the control is hidden; "Got it" marks it seen (persisted list `seenNewFeatures`).

**Profile pictures**: per-login URL cache and in-flight de-duplication, retry after 2 s, 10 s, 30 s, then on next resume.

## Animations and motion

**Motion tokens (`OnsetMotion`)**:
| token | value |
|---|---|
| springStandard | withDurationAndBounce(350 ms, bounce 0): mass 1, stiffness 322.27, damping 35.90 (ratio 1.0) |
| springMomentum | withDurationAndBounce(400 ms, bounce 0.2): mass 1, stiffness 246.74, damping 25.13 (ratio 0.8) |
| emphasizedDecelerate | Cubic(0.05, 0.7, 0.1, 1) — entering |
| emphasizedAccelerate | Cubic(0.3, 0, 0.8, 0.15) — leaving |
| standard | Cubic(0.2, 0, 0, 1) — indicators, rings, rolls, everything non-spring |
| overshoot | Cubic(0.3, 1.5, 0.5, 1) — launch tile settling / landing pop |
| pressScale / pressDuration | 0.97 / 100 ms |
| enter / exit | 350 ms / 250 ms |
| reducedFade | 150 ms |
| staggerStep / launchStaggerStep | 40 ms / 60 ms |
| staggerCap | 8 |
Spring formula (Flutter 3.38.4): stiffness = 4π²·m / d², dampingRatio = bounce > 0 ? 1 − bounce : 1/(1 + bounce), damping = ratio · 2√(k·m).
Other curves used: Flutter `Curves.ease` = Cubic(0.25, 0.1, 0.25, 1); `easeInOut` = Cubic(0.42, 0, 0.58, 1); `easeOut` = Cubic(0, 0, 0.58, 1); `easeIn` = Cubic(0.42, 0, 1, 1); `easeOutCubic` = Cubic(0.215, 0.61, 0.355, 1); `easeInCubic` = Cubic(0.55, 0.055, 0.675, 0.19); onboarding leave = Cubic(0.4, 0, 1, 1).

**Reduce motion**: Android "Remove animations" (`disableAnimations`) or iOS "Reduce Motion" → every animation becomes a 150 ms cross-fade; no travel, no overshoot, no stagger, no shimmer, no ping, no launch intro, no landing, no mosaic drift, no mini-player glide/lift, PressScale inert, RollingNumber instant, panels fade only.

**Haptics**: selection click (tabs, chips, segmented choices, language/theme pills, switches, link dialog toggle, sheet pills, onboarding step change, text button), light impact (follow success, chat send, emote picker, onboarding primary button, accent Random, report sent, not-interested, splitter end stops), medium impact (subscribe, gift, hype level).

**Controllers inventory** (all must exist in the Rust UI with these values):
| where | animation | duration / curve |
|---|---|---|
| PressScale | press to 0.97 / release spring | 100 ms standard / springMomentum from current value & velocity; cancelled after 18 px move |
| RollingNumber | changed digits roll, new from below (growing) | 450 ms standard; per place translate ±1 line, clipped |
| SignalPing | ripple radius r → 2.6 r, alpha 0.7 → 0 | 1200 ms ×2 per burst, then 5 s rest without ticker; eased by standard |
| StaggeredEntrance | rise 16 px + fade | delay step × min(i, 8) then 350 ms emphasizedDecelerate (40 / 60 ms steps) |
| SkeletonSheen | gradient band sweep, 300 px repeat at 100° | 1600 ms period, Curves.easeInOut phase, stops [0.3, 0.5, 0.7] |
| LaunchIntro | storyboard (below) | 1400 ms; landing 1400 / 1250 ms |
| GlobalMiniPlayer | snap to corner / glide / drag lift | 240 ms easeOutCubic / 320 ms standard / 90 ms scale 1.04 standard |
| OnsetSwitch | track colour / knob slide / knob colour | 200 ms / 260 ms standard / 260 ms (150 ms reduced; slide 0) |
| SheetStatusLine | AnimatedSwitcher between busy bar and message | 260 ms |
| Tablet panel route | fade + scale 0.97 → 1 + rise 6 dp from nub | 220 ms in (standard), 160 ms out (emphasizedAccelerate) |
| ReportSheet | step switch fade + slide 6 % from right | 260 ms easeOutCubic in / easeInCubic out |
| Photo viewer | drag reset / dismiss exit (25 % screen + fade) / button fade | 200 ms linear / 220 ms easeOut / 100 ms |
| CoachMark bubble | fade + scale 0.94 → 1 | 260 ms easeOutCubic |
| OnsetChip | fill/border/text | 200 ms standard |
| FollowPendingGate | opacity 1 ↔ 0.5 | 160 ms easeOut |
| DraggableDivider | line width/colour, handle size | 150 ms easeOut, 200 ms easeOut |
| OnsetCachedNetworkImage | fade in / out | 500 ms easeOut / easeIn |
| ScrollToTopButton | scroll to 0 | 500 ms easeOut |
| Onboarding step switch | in: fade + slide 32 dp; out: fade + slide 32 dp opposite | 730 ms total; in 0–360 standard; out 0–240 Cubic(0.4,0,1,1) |
| Onboarding parts (StepRise) | rise 12 dp + fade | 460 ms emphasizedDecelerate at delays [0, 30, 70, 110, 150, 190, 230, 270] |
| Onboarding hand-over | tile slide, mosaic, bar, Intro parts | 1460 ms (see table in `onboarding_flow.dart`) |
| Onboarding mosaic drift | translate y 0 → −44 px, reverse | 28 s each way, easeInOut |
| Onboarding progress | segment width 14 ↔ 28 | 360 ms standard |
| Language / theme pills | indicator slide / text colour | 320 ms standard / 200 ms |
| Setup preview / swatch | colours (theme/accent) | 260 ms standard |
| OnboardingSwitch | track / knob slide / knob colour | 200 ms / 260 ms standard / 200 ms |
| Login panel overlays | signing-in / failed switch | 220 ms, switchIn standard |
| Onboarding top bar back | opacity | 200 ms |
| Onboarding finish fallback | fade to Home | 280 ms |

**Launch intro storyboard** (`LaunchIntro`, 1400 ms; fractions × 1400):
| t | ms | event |
|---|---|---|
| 0 → 0.08 | 0–112 | lime dot grows from 0 to 20 % of the 72 dp tile (standard) |
| 0.08 → 0.26 | 112–364 | tile grows 20 % → 100 % with overshoot Cubic(0.3,1.5,0.5,1); corner radius 36 → 20 (standard) |
| 0.18 → 0.30 | 252–420 | ONSET icon fades in, scale 0.6 → 1 (Curves.ease) |
| 0.26 → 0.46 | 364–644 | ring 1: 2 dp lime border α 0.8 → 0, scale 1 → 2.8 (3.2 tablet), radius 20 |
| 0.32 → 0.54 | 448–756 | ring 2: 1.5 dp α 0.55 → 0, scale 1 → 3.6 (4.4 tablet) |
| 0.30 + i·0.01842 → 0.42 + i·0.01842 | O 420–588, N 446–614, S 472–640, E 497–665, T 523–691 | letters rise 20 dp (22 tablet) and fade in (emphasizedDecelerate) |
| 0.40 → 0.54 | 560–756 | underline scaleX 0 → 1 from the left (standard) |
| 0.56 | 784 | first run only: hold here (onboarding takes over) |
| 0.58 → 0.78 | 812–1092 | tile flies to the header slot: centre lerp, scale → slot width / 72, radius → the slot mark's corners (standard); glow stays |
| 0.60 → 0.70 | 840–980 | wordmark fades out (ease) |
| 0.68 → 0.80 | 952–1120 | black ground fades out (ease); status icons light while ground > 0.5 |
| 0.70 | 980 | reveal: entrance gate opens (home cards cascade 60 ms apart), overlay stops taking taps |
| 0.74 → 0.86 | 1036–1204 | tile fades out only if no real header slot exists |
| 1.0 | 1400 | finish, overlay removed |
Android native-splash hand-over (`fromTile`): starts at 0.26 (364 ms) with the tile already full size at the splash's rect; glow fades in 364–504 ms.
**Landing** (onboarding → Home): phone (appear) 1400 ms — ground fades in 0–280 ms (emphasizedAccelerate) over the onboarding, tile pops 0.6 → 1 (overshoot) 0–252 ms, page swap at 280 ms, one ring 252–560 ms (2 dp, α 0.7 → 0, scale × (1 + 1.6·standard)), flight 560–1092 ms, ground out 896–1120 ms, reveal 924 ms, tile fade (no slot) 1036–1204 ms. Tablet (tile already on screen) 1250 ms — swap at 250 ms, flight 300–800 ms, ground out 600–850 ms, reveal 625 ms, tile fade 750–900 ms, no pop, no ring.

## Settings

Settings live in `SettingsStore` (MobX, JSON-serialised under the SharedPreferences key `settings`, saved debounced and immediately when the app leaves the screen). Those read or written by this leaf:
| setting (JSON field) | type / default | where in this leaf |
|---|---|---|
| `accentColor` | int ARGB, default `0xFFC8FF3D` | theme seed in `MyApp.build`; onboarding Setup accent row + picker (`settings.accentColor = color.toARGB32()`, throttled 100 ms); LoginWebView seed; accent picker controls (also Settings › General) |
| `themeType` | `ThemeType { system, light, dark }`, default system (unknown → system) | `MaterialApp.themeMode`; onboarding Setup theme pill and preview |
| `appLanguage` | `AppLanguage { system, en, fr }`, default system | `MaterialApp.locale`; Android per-app language sync; onboarding language pill (`chooseLanguage`) and "Next" on Intro (stores the shown language explicitly) |
| `confirmExternalLinks` | bool, default true | external-link dialog gate; "Don't ask again" sets false |
| `launchUrlExternal` | bool, default false | chat links: external browser vs in-app browser view; robotty link in Setup |
| `showThumbnails` | bool, default true | onboarding mosaic only loads live pictures when on |
| `showRecentMessages` | bool, default false | Setup "Chat history" switch (recent-messages.robotty.de) |
| `shareCrashLogsAndAnalytics` | bool, default false | Setup "Crash reports" switch; `syncFirebaseCollection` |
| `seenNewFeatures` | List<String>, default [] | coach marks (`isNewFeature`, `markFeatureSeen`) with ids of `NewFeature` |
| `notInterestedChannels` | Map<String id, String name>, default {} | recommendations filtering, `markNotInterested` / `clearNotInterested` |
| `pinnedChannelIds` | List<String>, default [] | user actions Pin / Unpin |
| `mutedWhisperUserIds`, `archivedWhisperUserIds` | List<String> | seeded into WhisperStore at startup, written back on change |
| `hideViewerCount` | bool, default false | `viewerCountsHidden(context)` helper |
| `clipDiscovery` | `ClipDiscovery { all, featured }`, default all | `featuredClipsOnly(context)` helper |
Other persisted keys: SharedPreferences `first_run` (bool, absent = true; set false on reaching Welcome and on "Let's go!"); `GoLivePrefs` user id (set by the auth reaction); secure storage wiped on first run. Build-time constants (not user settings): `CLIENT_ID`, `TOKEN_PROXY_URL`, `UPDATE_TOKEN`, `UPDATE_REPO` (`--dart-define`). The PC build reads the same settings JSON schema (so a settings export/import between Android and PC stays possible) and keeps the same defaults.

## Strings

All user-facing text comes from `lib/l10n/app_en.arb` / `app_fr.arb` via `context.l10n` / `L10n.current` (rule enforced by `test/guards/no_hardcoded_strings_test.dart`). Literal exceptions in this leaf: the brand "ONSET" (wordmark, semantics label of the mark, app title), language endonyms (`English`, `Français`, the stream language endonyms), `'recent-messages.robotty.de'` (a host), `kDeletedUserLogin`/`kDeletedUserDisplayName` data values. Enum labels (`AppLanguage.label`, `ThemeType.label`) come from `lib/l10n/enum_labels.dart`. Styled placeholders use `l10nMark(i)` + `l10nSpans` (private-use code points U+F0000…U+F000F) so bold names / links sit wherever each language puts them. Every key used by this leaf's source, with its exact English and French values (ICU plural/select syntax kept verbatim):

| key | EN | FR | used in (under lib/) |
|---|---|---|---|
| `accentColorRandom` | Random | Aléatoire | screens/onboarding/onboarding_accent_picker.dart |
| `accentColorSemantics` | Accent color, {hex} | Couleur d’accent, {hex} | screens/onboarding/onboarding_setup.dart |
| `accentColorTitle` | Accent color | Couleur d’accent | screens/onboarding/onboarding_accent_picker.dart, screens/onboarding/onboarding_setup.dart |
| `accentHue` | {degrees, plural, one{Hue {degrees} degree} other{Hue {degrees} degrees}} | {degrees, plural, one{Teinte {degrees} degré} other{Teinte {degrees} degrés}} | widgets/accent_picker_controls.dart |
| `accentSaturationBrightness` | Saturation and brightness | Saturation et luminosité | widgets/accent_picker_controls.dart |
| `accentSaturationBrightnessValue` | {saturation}%, {brightness}% | {saturation} %, {brightness} % | widgets/accent_picker_controls.dart |
| `castButton` | Cast to a device | Caster sur un appareil | widgets/cast_button.dart |
| `castConnectedTo` | Casting to {device} | Diffusion sur {device} | widgets/cast_button.dart |
| `castConnecting` | Connecting… | Connexion… | widgets/cast_button.dart |
| `castFailed` | Couldn’t start casting. Try again. | Impossible de lancer la diffusion. Réessayez. | widgets/cast_button.dart |
| `castNoDevices` | No Cast devices found. Check that your TV or speaker is on the same Wi-Fi network. | Aucun appareil Cast trouvé. Vérifiez que votre téléviseur ou votre enceinte est sur le même réseau Wi-Fi. | widgets/cast_button.dart |
| `castNotReady` | Couldn’t cast: the video isn’t ready yet. | Impossible de caster : la vidéo n’est pas encore prête. | widgets/cast_button.dart |
| `castSearching` | Looking for Cast devices on this network… | Recherche d’appareils Cast sur ce réseau… | widgets/cast_button.dart |
| `castSheetTitle` | Cast | Caster | widgets/cast_button.dart |
| `castStop` | Stop casting | Arrêter la diffusion | widgets/cast_button.dart |
| `castThisVideo` | Cast this video | Caster cette vidéo | widgets/cast_button.dart |
| `castUnavailable` | Casting isn’t available on this device. | La diffusion Cast n’est pas disponible sur cet appareil. | widgets/cast_button.dart |
| `channelFollow` | Follow | Suivre | widgets/follow/follow_flow.dart |
| `channelFollowing` | Following | Suivie | widgets/follow/follow_flow.dart |
| `coachMarkCast` | Watch on your TV: cast to a Google Cast device. | Regardez sur votre téléviseur : diffusez sur un appareil Google Cast. | widgets/cast_button.dart |
| `coachMarkGotIt` | Got it | J’ai compris | widgets/coach_mark.dart |
| `commonBack` | Back | Retour | screens/onboarding/login_webview.dart, screens/onboarding/onboarding_flow.dart, widgets/sheet/onset_sheet.dart, widgets/twitch_web_page.dart |
| `commonCancel` | Cancel | Annuler | screens/onboarding/onboarding_accent_picker.dart, widgets/external_link_dialog.dart, widgets/follow/follow_flow.dart, widgets/onset_update_prompt.dart, widgets/report/report_sheet.dart |
| `commonClose` | Close | Fermer | screens/onboarding/login_webview.dart, widgets/onset_photo_view_dialog.dart |
| `commonConnectWithTwitch` | Log in with Twitch | Se connecter avec Twitch | screens/onboarding/login_webview.dart, screens/onboarding/onboarding_login.dart, widgets/state_views.dart |
| `commonDismiss` | Dismiss | Masquer | widgets/onset_notification.dart |
| `commonDone` | Done | Terminé | screens/onboarding/onboarding_accent_picker.dart |
| `commonLiveBadge` | LIVE | LIVE | screens/onboarding/onboarding_intro.dart, screens/onboarding/onboarding_setup.dart |
| `commonNext` | Next | Suivant | screens/onboarding/onboarding_intro.dart, screens/onboarding/onboarding_setup.dart |
| `commonRetry` | Retry | Réessayer | widgets/alert_message.dart, widgets/follow/follow_flow.dart |
| `commonTryAgain` | Try again | Réessayer | screens/onboarding/login_webview.dart, widgets/state_views.dart |
| `commonUndo` | Undo | Annuler | widgets/recommendations/recommended_channels.dart |
| `contentLabelDrugs` | Drugs, intoxication, or excessive tobacco use | Drogues, intoxication ou consommation excessive de tabac | utils/content_labels.dart |
| `contentLabelGambling` | Gambling | Jeux d’argent | utils/content_labels.dart |
| `contentLabelMatureGame` | Mature-rated game | Jeu classé pour adultes | utils/content_labels.dart |
| `contentLabelPolitics` | Politics and sensitive social issues | Politique et questions sociales sensibles | utils/content_labels.dart |
| `contentLabelProfanity` | Significant profanity or vulgarity | Grossièretés ou vulgarité marquées | utils/content_labels.dart |
| `contentLabelSexualThemes` | Sexual themes | Thèmes sexuels | utils/content_labels.dart |
| `contentLabelViolentGraphic` | Violent and graphic depictions | Représentations violentes et explicites | utils/content_labels.dart |
| `deepLinkCategoryFallback` | Category | Catégorie | main.dart |
| `deepLinkFailed` | Couldn’t open “{uri}”. | Impossible d’ouvrir « {uri} » | main.dart |
| `deepLinkOpenInBrowser` | Open in browser | Ouvrir dans le navigateur | main.dart |
| `draggableDividerChatWidth` | Chat width | Largeur du chat | widgets/draggable_divider.dart |
| `draggableDividerValue` | {percent}% | {percent} % | widgets/draggable_divider.dart |
| `followAll` | Follow all | Tout suivre | widgets/follow/follow_flow.dart |
| `followAllConfirmBody` | Each channel is added to the channels your Twitch account follows. | Chacune est ajoutée aux chaînes suivies de votre compte Twitch. | widgets/follow/follow_flow.dart |
| `followAllConfirmTitle` | {count, plural, one{Follow this channel?} other{Follow these {count} channels?}} | {count, plural, one{Suivre cette chaîne ?} other{Suivre ces {count} chaînes ?}} | widgets/follow/follow_flow.dart |
| `followAllDone` | {count, plural, one{You now follow {count} more channel.} other{You now follow {count} more channels.}} | {count, plural, one{Vous suivez désormais {count} chaîne de plus.} other{Vous suivez désormais {count} chaînes de plus.}} | widgets/follow/follow_flow.dart |
| `followAllStopped` | {done, plural, =0{Couldn’t follow {name}.} =1{You followed 1 channel, then couldn’t follow {name}.} other{You followed {done} channels, then couldn’t follow {name}.}} {reason} | {done, plural, =0{Le suivi de {name} a échoué.} one{Vous avez suivi {done} chaîne, mais le suivi de {name} a échoué.} other{Vous avez suivi {done} chaînes, mais le suivi de {name} a échoué.}} {reason} | widgets/follow/follow_flow.dart |
| `followConfirmTitle` | Follow {name}? | Suivre {name} ? | widgets/follow/follow_flow.dart |
| `followDeepLinkBody` | A link asked ONSET to follow this channel with your Twitch account. | Un lien demande à ONSET de suivre cette chaîne avec votre compte Twitch. | widgets/follow/follow_flow.dart |
| `followDone` | You now follow {name}. | Vous suivez désormais {name}. | widgets/follow/follow_flow.dart |
| `followError` | {status, select, tooManyFollows{You follow too many channels. Unfollow one, then try again.} unverifiedEmail{Verify your email address on Twitch to follow.} unverifiedPhone{Verify your phone number on Twitch to follow.} unverifiedPhoneAndEmail{Verify your email address and phone number on Twitch to follow.} forbidden{Twitch doesn’t allow this follow.} refused{Twitch declined this follow.} noWebSession{ONSET isn’t connected to your Twitch web session. Log in to connect it.} signedOut{Twitch rejected ONSET’s web session. Log in again to restore it.} needsTvSession{Twitch’s anti-bot check refused this follow. Connect a Twitch session to follow from ONSET.} tvSessionExpired{Your Twitch session expired. Reconnect it, then try again.} integrityRefused{Twitch refused this follow with the error “failed integrity check”. Try again in a few minutes.} gqlError{Twitch answered with an error. Try again.} other{Couldn’t reach Twitch. Try again.}} | {status, select, tooManyFollows{Vous suivez trop de chaînes. Ne suivez plus l’une d’elles, puis réessayez.} unverifiedEmail{Vérifiez votre adresse e-mail sur Twitch pour suivre.} unverifiedPhone{Vérifiez votre numéro de téléphone sur Twitch pour suivre.} unverifiedPhoneAndEmail{Vérifiez votre adresse e-mail et votre numéro de téléphone sur Twitch pour suivre.} forbidden{Twitch n’autorise pas ce suivi.} refused{Twitch a refusé ce suivi.} noWebSession{ONSET n’est pas connecté à votre session web Twitch. Connectez-vous pour la relier.} signedOut{Twitch a refusé la session web d’ONSET. Reconnectez-vous pour la rétablir.} needsTvSession{Le contrôle anti-robot de Twitch a refusé ce suivi. Connectez une session Twitch pour suivre depuis ONSET.} tvSessionExpired{Votre session Twitch a expiré. Reconnectez-la, puis réessayez.} integrityRefused{Twitch a refusé ce suivi avec l’erreur « failed integrity check ». Réessayez dans quelques minutes.} gqlError{Twitch a répondu par une erreur. Réessayez.} other{Impossible de joindre Twitch. Réessayez.}} | widgets/follow/follow_flow.dart |
| `followLogInAction` | Log in | Se connecter | widgets/follow/follow_flow.dart |
| `followSignInNeeded` | Log in to ONSET to follow channels and categories. | Connectez-vous à ONSET pour suivre des chaînes et des catégories. | widgets/follow/follow_flow.dart |
| `followSuggestionsSubtitle` | Also live in the same category | Aussi en direct dans la même catégorie | widgets/follow/follow_flow.dart |
| `followSuggestionsTitle` | You follow {name} | Vous suivez {name} | widgets/follow/follow_flow.dart |
| `languageChoiceSemantics` | Language · Langue | Language · Langue | screens/onboarding/onboarding_language_choice.dart |
| `linkConfirmBody` | This link leads to {host}, outside ONSET. | Ce lien mène à {host}, en dehors d’ONSET. | widgets/external_link_dialog.dart |
| `linkConfirmDontAsk` | Don’t ask again | Ne plus demander | widgets/external_link_dialog.dart |
| `linkConfirmOpen` | Open | Ouvrir | widgets/external_link_dialog.dart |
| `linkConfirmTitle` | Open this link? | Ouvrir ce lien ? | widgets/external_link_dialog.dart |
| `liveFeedNotInterested` | Not interested | Ça ne m’intéresse pas | widgets/recommendations/recommended_channels.dart |
| `loginFailedLine` | Twitch didn’t log you in. Try again. | Twitch n’a pas pu vous connecter. Réessayez. | screens/onboarding/login_webview.dart |
| `loginHelpBodyElsewhere` | If the Twitch cookie banner still blocks the login, tap one of the links in the cookie policy text and keep going until you reach the Twitch home page. From there, log in with the profile icon in the top-right corner. Once you’re logged in, go back and open the login page again. | Si le bandeau de cookies de Twitch bloque encore la connexion, appuyez sur l’un des liens de son texte sur la politique de cookies et naviguez jusqu’à la page d’accueil de Twitch. De là, essayez de vous connecter depuis l’icône de profil en haut à droite. Une fois la connexion effectuée, revenez en arrière, puis rouvrez la page de connexion. | screens/onboarding/login_webview.dart |
| `loginHelpBodyOnboarding` | If the Twitch cookie banner still blocks the login, tap one of the links in the cookie policy text and keep going until you reach the Twitch home page. From there, log in with the profile icon in the top-right corner. Once you’re logged in, go back to the first step of setup and try again. | Si le bandeau de cookies de Twitch bloque encore la connexion, appuyez sur l’un des liens de son texte sur la politique de cookies et naviguez jusqu’à la page d’accueil de Twitch. De là, essayez de vous connecter depuis l’icône de profil en haut à droite. Une fois la connexion effectuée, revenez à la première étape de la prise en main, puis réessayez. | screens/onboarding/login_webview.dart |
| `loginHelpTitle` | Workaround for the Twitch cookie banner | Contourner le bandeau de cookies de Twitch | screens/onboarding/login_webview.dart |
| `loginHelpTooltip` | Login help | Aide à la connexion | screens/onboarding/login_webview.dart |
| `loginHostPage` | Page: {host} | Page : {host} | screens/onboarding/login_webview.dart |
| `loginHostSecure` | Secure page: {host} | Page sécurisée : {host} | screens/onboarding/login_webview.dart |
| `loginLoadFailedDetail` | Check your connection, then try again. | Vérifiez votre connexion Internet, puis réessayez. | screens/onboarding/login_webview.dart |
| `loginLoadFailedTitle` | Couldn’t reach Twitch. | Impossible de joindre Twitch | screens/onboarding/login_webview.dart |
| `loginSigningIn` | Logging you in… | Connexion en cours… | screens/onboarding/login_webview.dart, screens/onboarding/onboarding_setup.dart |
| `mentionNotice` | You were mentioned in {login}’s chat. | Nouvelle mention dans le chat de la chaîne {login} | main.dart |
| `miniPlayerClose` | Close miniplayer | Fermer le mini-lecteur | widgets/global_mini_player.dart |
| `miniPlayerReturn` | Return to stream | Revenir au live | widgets/global_mini_player.dart |
| `newFeaturePill` | New | Nouveau | widgets/coach_mark.dart, widgets/new_feature_pill.dart |
| `notInterestedDone` | You won’t see {name} in suggestions. Undo restores it in ONSET only. | Vous ne verrez plus {name} dans les suggestions. Annuler ne rétablit cette chaîne que dans ONSET. | widgets/recommendations/recommended_channels.dart |
| `notInterestedHiddenHere` | You won’t see {name} in suggestions in ONSET. | Vous ne verrez plus {name} dans les suggestions d’ONSET. | widgets/recommendations/recommended_channels.dart |
| `notInterestedOnlyHere` | {name} is hidden in ONSET only. Twitch didn’t record your reason. | La chaîne {name} est masquée dans ONSET uniquement. Twitch n’a pas enregistré votre raison. | widgets/recommendations/recommended_channels.dart |
| `notInterestedReasonNotInterested` | I’m not interested | Ça ne m’intéresse pas | widgets/recommendations/recommended_channels.dart |
| `notInterestedReasonOffensive` | Offensive content | Contenu offensant | widgets/recommendations/recommended_channels.dart |
| `notInterestedReasonOther` | Something else | Autre raison | widgets/recommendations/recommended_channels.dart |
| `notInterestedSentToTwitch` | Twitch receives your reason. | Votre raison est envoyée à Twitch. | widgets/recommendations/recommended_channels.dart |
| `notInterestedTitle` | Not interested in {name}? | {name} ne vous intéresse pas ? | widgets/recommendations/recommended_channels.dart |
| `notificationPermissionContinue` | Continue | Continuer | widgets/notification_permission_prompt.dart |
| `notificationPermissionMessage` | ONSET can tell you when a channel you follow goes live, when someone mentions you in chat, and when a stream you set a reminder for starts. Your device asks for permission next. | ONSET peut vous prévenir quand une chaîne que vous suivez lance un live, quand quelqu’un vous mentionne dans le chat et quand commence un live pour lequel vous avez activé un rappel. Votre appareil vous demandera ensuite l’autorisation. | widgets/notification_permission_prompt.dart |
| `notificationPermissionNotNow` | Not now | Plus tard | widgets/notification_permission_prompt.dart |
| `notificationPermissionTitle` | Allow notifications? | Autoriser les notifications ? | widgets/notification_permission_prompt.dart |
| `onboardingIntroDescription` | A mobile Twitch client with 7TV, BetterTTV (BTTV), and FrankerFaceZ (FFZ) support. | Un client mobile pour Twitch, compatible avec 7TV, BetterTTV (BTTV) et FrankerFaceZ (FFZ). | screens/onboarding/onboarding_intro.dart |
| `onboardingIntroEyebrow` | First launch | Premier lancement | screens/onboarding/onboarding_intro.dart |
| `onboardingLoginAuthorizeHeader` | What you’ll authorize | Ce que vous autorisez | screens/onboarding/onboarding_login.dart |
| `onboardingLoginDisclaimer` | ONSET asks only for the permissions it needs, through the official Twitch API. You’ll be able to review them before authorizing. | ONSET ne demande que les autorisations nécessaires, via l’API officielle de Twitch. Vous pourrez les consulter avant de les accorder. | screens/onboarding/onboarding_login.dart |
| `onboardingLoginLead` | ONSET needs your permission to let you chat, see followed streams, and more. | ONSET a besoin de votre autorisation pour vous permettre de discuter dans le chat, de voir les lives des chaînes que vous suivez, et plus encore. | screens/onboarding/onboarding_login.dart |
| `onboardingLoginSkip` | Skip | Passer | screens/onboarding/onboarding_login.dart |
| `onboardingLoginTitle` | Log in | Connexion | screens/onboarding/onboarding_login.dart |
| `onboardingPermissionBlocksDetail` | Manage blocks and change your name color | Gérer les blocages, changer votre couleur dans le chat | screens/onboarding/onboarding_login.dart |
| `onboardingPermissionBlocksTitle` | Blocks and name color | Blocages et couleur du pseudo | screens/onboarding/onboarding_login.dart |
| `onboardingPermissionChatDetail` | Read and send messages | Lire et envoyer des messages | screens/onboarding/onboarding_login.dart |
| `onboardingPermissionChatTitle` | Chat | Chat | screens/onboarding/onboarding_login.dart |
| `onboardingPermissionClipsDetail` | Create clips from a stream | Créer des clips à partir d’un live | screens/onboarding/onboarding_login.dart |
| `onboardingPermissionClipsTitle` | Clips | Clips | screens/onboarding/onboarding_login.dart |
| `onboardingPermissionEmotesDetail` | Use your sub and follower emotes | Utiliser vos emotes d’abonné et de follower | screens/onboarding/onboarding_login.dart |
| `onboardingPermissionEmotesTitle` | Your emotes | Vos emotes | screens/onboarding/onboarding_login.dart |
| `onboardingPermissionFollowsDetail` | See who’s live right now | Voir qui est en direct | screens/onboarding/onboarding_login.dart |
| `onboardingPermissionFollowsTitle` | Followed channels | Chaînes suivies | screens/onboarding/onboarding_login.dart |
| `onboardingPermissionModerationDetail` | Bans, AutoMod, terms, shield mode, chat modes | Bannissements, AutoMod, termes, mode bouclier, modes du chat | screens/onboarding/onboarding_login.dart |
| `onboardingPermissionModerationTitle` | Moderation | Modération | screens/onboarding/onboarding_login.dart |
| `onboardingPermissionWhispersDetail` | Read and send whispers | Lire et envoyer des chuchotements | screens/onboarding/onboarding_login.dart |
| `onboardingPermissionWhispersTitle` | Whispers | Chuchotements | screens/onboarding/onboarding_login.dart |
| `onboardingProgressLabel` | Onboarding progress | Progression de la prise en main | screens/onboarding/onboarding_flow.dart |
| `onboardingProgressValue` | Step {step} of {count} | Étape {step} sur {count} | screens/onboarding/onboarding_flow.dart |
| `onboardingSetupCrashDetail` | Help improve ONSET by sending crash logs and analytics through Firebase. Neither your Twitch account nor your channels are sent. | Aidez-nous à améliorer ONSET en envoyant les rapports de plantage et les statistiques d’utilisation via Firebase. Ni votre compte Twitch ni vos chaînes ne sont transmis. | screens/onboarding/onboarding_setup.dart |
| `onboardingSetupCrashTitle` | Share crash logs and analytics | Partager les rapports de plantage et statistiques | screens/onboarding/onboarding_setup.dart |
| `onboardingSetupHistoryDetail` | When Twitch’s own chat history is unavailable, fails, or is empty, ONSET loads recent messages from {link}, which then receives the channel name. | Si l’historique du chat de Twitch est indisponible, ne se charge pas ou est vide, ONSET récupère les messages récents depuis {link}, qui reçoit alors le nom de la chaîne. | screens/onboarding/onboarding_setup.dart |
| `onboardingSetupHistoryTitle` | Fallback chat history (third-party) | Historique de secours du chat (tiers) | screens/onboarding/onboarding_setup.dart |
| `onboardingSetupLead` | Let’s tweak some settings before you get started. You can always change these and more later. | Ajustons quelques réglages avant de commencer. Ceux-ci et bien d’autres restent modifiables à tout moment. | screens/onboarding/onboarding_setup.dart |
| `onboardingSetupLoggedInAs` | Logged in as {name} | Compte connecté : {name} | screens/onboarding/onboarding_setup.dart |
| `onboardingSetupLoginFailed` | Couldn’t log in · go back to try again, or log in later from Profile | Échec de la connexion · réessayez en revenant en arrière, ou plus tard depuis l’onglet Profil | screens/onboarding/onboarding_setup.dart |
| `onboardingSetupNotLoggedIn` | Not logged in · you can log in later from Profile | Aucun compte connecté · vous pourrez vous connecter plus tard depuis l’onglet Profil | screens/onboarding/onboarding_setup.dart |
| `onboardingSetupPreviewBadge` | PREVIEW | APERÇU | screens/onboarding/onboarding_setup.dart |
| `onboardingSetupPreviewChannel` | A live channel | Chaîne en direct | screens/onboarding/onboarding_setup.dart |
| `onboardingSetupPreviewDetail` | Category · viewers | Catégorie · spectateurs | screens/onboarding/onboarding_setup.dart |
| `onboardingSetupPreviewSemantics` | Preview: {name}, {detail} | Aperçu : {name}, {detail} | screens/onboarding/onboarding_setup.dart |
| `onboardingSetupThemeDarkNote` | The ONSET default | Le thème par défaut d’ONSET | screens/onboarding/onboarding_setup.dart |
| `onboardingSetupThemeLightNote` | Light surfaces everywhere | Surfaces claires partout | screens/onboarding/onboarding_setup.dart |
| `onboardingSetupThemeSystemNote` | Follows your device | Suit votre appareil | screens/onboarding/onboarding_setup.dart |
| `onboardingSetupThemeTitle` | Theme | Thème | screens/onboarding/onboarding_setup.dart |
| `onboardingSetupTitle` | Setup | Configuration | screens/onboarding/onboarding_setup.dart |
| `onboardingWelcomeGo` | Let’s go! | C’est parti ! | screens/onboarding/onboarding_welcome.dart |
| `onboardingWelcomeLead` | Just a few more things… | Encore quelques petites choses… | screens/onboarding/onboarding_welcome.dart |
| `onboardingWelcomeTipChangelog` | Links to the full changelog and the FAQ are in Settings › Other. | Les liens vers le journal complet des modifications et la FAQ se trouvent dans les paramètres, rubrique « Autres ». | screens/onboarding/onboarding_welcome.dart |
| `onboardingWelcomeTipGitHub` | Check out the GitHub repo (top-right corner of Settings) to explore ONSET’s source code, report bugs, request features, and more. | Le bouton GitHub, en haut à droite des paramètres, ouvre le dépôt d’ONSET : explorez le code source, signalez des bugs, proposez des fonctionnalités, et plus encore. | screens/onboarding/onboarding_welcome.dart |
| `onboardingWelcomeTipRating` | ONSET checks for new builds by itself, and the release notes open after each update. | ONSET recherche lui-même les nouveaux builds, et les notes de version s’ouvrent après chaque mise à jour. | screens/onboarding/onboarding_welcome.dart |
| `onboardingWelcomeTitle` | Welcome! | Bienvenue ! | screens/onboarding/onboarding_welcome.dart |
| `photoViewOriginal` | View original | Voir l’original | widgets/onset_photo_view_dialog.dart |
| `photoViewThumbnail` | View thumbnail | Voir la miniature | widgets/onset_photo_view_dialog.dart |
| `recommendationsEmpty` | No suggestions right now. | Aucune suggestion pour le moment. | widgets/recommendations/recommended_channels.dart |
| `recommendationsSimilarTitle` | Channels like {name} | Chaînes similaires à {name} | widgets/recommendations/recommended_channels.dart |
| `recommendationsTitle` | Channels for you | Chaînes pour vous | widgets/recommendations/recommended_channels.dart |
| `reportConfirmBody` | Twitch reviews every report and never tells the person you report who sent it. | Twitch examine chaque signalement et ne dit jamais à la personne signalée qui l’a envoyé. | widgets/report/report_sheet.dart |
| `reportConfirmTitle` | Confirm your report | Confirmer le signalement | widgets/report/report_sheet.dart |
| `reportDetailsHint` | What happened? | Que s’est-il passé ? | widgets/report/report_sheet.dart |
| `reportDetailsLabel` | Details (optional) | Précisions (facultatif) | widgets/report/report_sheet.dart |
| `reportOpenOnTwitchAction` | Open twitch.tv | Ouvrir twitch.tv | widgets/report/report_sheet.dart |
| `reportReason` | {reason, select, harassment{Bullying or harassment} hatefulConduct{Hateful conduct} spam{Spam, scams, or bots} sexualContent{Nudity or sexual content} gore{Violence or gore} harm{Dangerous or harmful acts} selfHarm{Self-harm} terrorism{Terrorism or mass violence} impersonation{Impersonation} misinformation{Misinformation} ipViolation{Copyright or trademark} underaged{Underage user} banEvasion{Ban evasion} chatBanEvasion{Chat ban evasion} cheating{Cheating in a game} bitsViolation{Misuse of Bits} other{Something else}} | {reason, select, harassment{Harcèlement ou intimidation} hatefulConduct{Conduite haineuse} spam{Spam, arnaque ou robot} sexualContent{Nudité ou contenu sexuel} gore{Violence ou contenu choquant} harm{Actes dangereux ou nuisibles} selfHarm{Automutilation} terrorism{Terrorisme ou violence de masse} impersonation{Usurpation d’identité} misinformation{Désinformation} ipViolation{Droit d’auteur ou marque} underaged{Personne mineure} banEvasion{Contournement de bannissement} chatBanEvasion{Contournement de bannissement du chat} cheating{Triche dans un jeu} bitsViolation{Utilisation abusive des Bits} other{Autre chose}} | widgets/report/report_sheet.dart |
| `reportSend` | Send report | Envoyer le signalement | widgets/report/report_sheet.dart |
| `reportSent` | Report sent. Thank you. | Signalement envoyé. Merci. | widgets/report/report_sheet.dart |
| `reportTitle` | {kind, select, channel{Report {name}’s channel} emote{Report the {name} emote} message{Report {name}’s message} clip{Report this clip} other{Report {name}}} | {kind, select, channel{Signaler la chaîne {name}} emote{Signaler l’emote {name}} message{Signaler le message de {name}} clip{Signaler ce clip} other{Signaler {name}}} | widgets/report/report_sheet.dart |
| `reportWebFallbackBody` | ONSET sends reports through your Twitch session, which isn’t connected. Log in to ONSET again to connect it, or report on twitch.tv now. | ONSET envoie les signalements par votre session Twitch, qui n’est pas connectée. Reconnectez-vous à ONSET pour l’activer, ou signalez sur twitch.tv dès maintenant. | widgets/report/report_sheet.dart |
| `reportWebFallbackTitle` | Report on twitch.tv? | Signaler sur twitch.tv ? | widgets/report/report_sheet.dart |
| `reportWhy` | Why are you reporting this? | Pourquoi signalez-vous ce contenu ? | widgets/report/report_sheet.dart |
| `scrollToTop` | Scroll to top | Revenir en haut | widgets/scroll_to_top_button.dart |
| `shareChatFailed` | Couldn’t send the link in chat. | Impossible d’envoyer le lien dans le chat. | widgets/share_sheet.dart |
| `shareChatLogInAgain` | Log in again to send links in chat from here. | Reconnectez-vous pour envoyer des liens dans le chat depuis ici. | widgets/share_sheet.dart |
| `shareOther` | More options… | Plus d’options… | widgets/share_sheet.dart |
| `shareSendAsWhisper` | Send as a whisper | Envoyer en chuchotement | widgets/share_sheet.dart |
| `shareSendToChannelChat` | Send in {name}’s chat | Envoyer dans le chat de {name} | widgets/share_sheet.dart |
| `shareSendToChat` | Send in chat | Envoyer dans le chat | widgets/share_sheet.dart |
| `shareSentToChat` | Link sent in {name}’s chat. | Lien envoyé dans le chat de {name}. | widgets/share_sheet.dart |
| `shareTitle` | Share | Partager | widgets/share_sheet.dart |
| `shareWhisperSent` | Link whispered to {name}. | Lien chuchoté à {name}. | widgets/share_sheet.dart |
| `streamLanguageAll` | All languages | Toutes les langues | utils/stream_languages.dart |
| `streamLanguageOther` | Other | Autre | utils/stream_languages.dart |
| `streamViewers` | {count, plural, one{{count} viewer} other{{count} viewers}} | {count, plural, one{{count} spectateur} other{{count} spectateurs}} | widgets/follow/follow_flow.dart, widgets/recommendations/recommended_channels.dart |
| `twitchTvConnectAction` | Connect | Connecter | widgets/follow/follow_flow.dart |
| `twitchTvPromptBody` | Twitch’s anti-bot check refused this action. With a Twitch session, ONSET can follow, claim points, and make predictions without going through that check. | Le contrôle anti-robot de Twitch a refusé cette action. Avec une session Twitch, ONSET peut suivre, récupérer des points et faire des prédictions sans passer par ce contrôle. | widgets/follow/follow_flow.dart |
| `twitchTvPromptLater` | Not now | Plus tard | widgets/follow/follow_flow.dart |
| `twitchTvPromptTitle` | Connect a Twitch session? | Connecter une session Twitch ? | widgets/follow/follow_flow.dart |
| `unfollowAction` | Unfollow | Ne plus suivre | widgets/follow/follow_flow.dart |
| `unfollowConfirmBody` | This changes what your Twitch account follows. | Cela modifie ce que suit votre compte Twitch. | widgets/follow/follow_flow.dart |
| `unfollowConfirmTitle` | Unfollow {name}? | Ne plus suivre {name} ? | widgets/follow/follow_flow.dart |
| `unfollowDone` | You no longer follow {name}. | Vous ne suivez plus {name}. | widgets/follow/follow_flow.dart |
| `updateAllowMessage` | Android asks you to let ONSET install apps. Turn on “Allow from this source” on the next screen, then come back. | Android vous demande d’autoriser ONSET à installer des applications. Activez « Autoriser cette source » sur l’écran suivant, puis revenez. | widgets/onset_update_prompt.dart |
| `updateAllowTitle` | Allow updates | Autoriser les mises à jour | widgets/onset_update_prompt.dart |
| `updateAvailable` | Update available | Mise à jour disponible | widgets/onset_update_prompt.dart |
| `updateChecked` | Verified with SHA-256 before installing | Empreinte SHA-256 vérifiée avant l’installation | widgets/onset_update_prompt.dart |
| `updateCorrupted` | The download was corrupted. Try again. | Le fichier téléchargé est corrompu – réessayez | widgets/onset_update_prompt.dart |
| `updateDownloadFailed` | Couldn’t download the update. | Échec du téléchargement | widgets/onset_update_prompt.dart |
| `updateDownloading` | Downloading update… | Téléchargement de la mise à jour | widgets/onset_update_prompt.dart |
| `updateInstallFailed` | Android couldn’t install the update. | Android n’a pas pu installer la mise à jour | widgets/onset_update_prompt.dart |
| `updateInstalledBuild` | Installed: build {build} | Installé : build {build} | widgets/onset_update_prompt.dart |
| `updateInstalling` | Installing update… | Installation de la mise à jour | widgets/onset_update_prompt.dart |
| `updateLater` | Later | Plus tard | widgets/onset_update_prompt.dart |
| `updateNewBuild` | NEW BUILD | NOUVEAU BUILD | widgets/onset_update_prompt.dart |
| `updateNotAllowed` | ONSET isn’t allowed to install updates. | ONSET n’est pas autorisé à installer des mises à jour | widgets/onset_update_prompt.dart |
| `updateNow` | Update | Mettre à jour | widgets/onset_update_prompt.dart |
| `updateOpenSettings` | Open settings | Ouvrir les paramètres | widgets/onset_update_prompt.dart |
| `updateProgress` | {received} / {total} MB | {received} / {total} Mo | widgets/onset_update_prompt.dart |
| `updateReady` | ONSET build {build} is ready. | Le build {build} d’ONSET est prêt. | widgets/onset_update_prompt.dart |
| `updateSize` | {megabytes} MB | {megabytes} Mo | widgets/onset_update_prompt.dart |
| `userActionsBlock` | Block {name} | Bloquer {name} | widgets/user_actions_modal.dart |
| `userActionsChannelPrefs` | Channel preferences | Préférences de la chaîne | widgets/user_actions_modal.dart |
| `userActionsCopyLink` | Copy link | Copier le lien | widgets/user_actions_modal.dart |
| `userActionsFollow` | Follow {name} | Suivre {name} | widgets/user_actions_modal.dart |
| `userActionsLinkCopied` | Link copied | Lien copié | widgets/user_actions_modal.dart |
| `userActionsPin` | Pin {name} | Épingler {name} | widgets/user_actions_modal.dart |
| `userActionsProfile` | Profile | Profil | widgets/user_actions_modal.dart |
| `userActionsReport` | Report {name} | Signaler {name} | widgets/user_actions_modal.dart |
| `userActionsShare` | Share {name} | Partager {name} | widgets/user_actions_modal.dart |
| `userActionsUnfollow` | Unfollow {name} | Ne plus suivre {name} | widgets/user_actions_modal.dart |
| `userActionsUnpin` | Unpin {name} | Désépingler {name} | widgets/user_actions_modal.dart |
| `userActionsVideos` | Videos | Vidéos | widgets/user_actions_modal.dart |
| `viewerActionResult` | {status, select, done{Done.} refused{Twitch declined this.} integrityRefused{Twitch’s anti-bot check refused this. Connect a Twitch session in Settings › Account, then try again.} signedOut{Log in again to do this from ONSET.} other{Couldn’t reach Twitch. Try again.}} | {status, select, done{C’est fait.} refused{Twitch a refusé.} integrityRefused{Le contrôle anti-robot de Twitch a refusé cette action. Connectez une session Twitch dans Paramètres › Compte, puis réessayez.} signedOut{Reconnectez-vous pour le faire depuis ONSET.} other{Impossible de joindre Twitch. Réessayez.}} | widgets/report/report_sheet.dart |
| `vodLinkCopied` | Link copied | Lien copié | utils/share_link.dart |


## Network and data

This leaf mostly wires networking; endpoints are specified in the API leaves. What happens here:
- **Clients**: one shared Dio (`DioClient.createClient()`) for Helix (`api.twitch.tv/helix`), BTTV, FFZ, 7TV, carrying `TwitchAuthInterceptor` (user token or app token from `TOKEN_PROXY_URL`, `Client-Id: CLIENT_ID`) and `UnauthorizedInterceptor` (401 → auth handling). One anonymous Dio for Twitch GQL `https://gql.twitch.tv/gql` with `Client-Id: kimne78kx3ncx6brgo4mv6wki5h1ko`, connect timeout 5 s, receive timeout 8 s, NO Helix token; the viewer's twitch.tv web token (`auth-token` cookie, harvested in the login WebView) is added per request only by the services that need it; the Twitch TV device session interceptor (`ue6666qo983tsx6so1t0vnawi233wa`) adds its credentials where integrity-checked mutations need them (follows, points).
- **Realtime**: anonymous Hermes websocket (`TwitchRealtimeClient`), connects on first subscription and sleeps after 1 min in background; EventSub websocket for whispers, subscriptions created/deleted through Helix (`createEventSubSubscription(type, version, condition, sessionId)`), paused/resumed with the app lifecycle.
- **Requests made directly by this leaf's code**: Helix `getUser(userLogin)` (deep link channel lookup, profile pictures, display names, follow state), `isFollowing`, `getStreamsByIds`, `getStreamsUnderCategory`, `getFollowedStreams(first 100, quiet)` (follow suggestions), `getTopStreams(quiet)` (onboarding mosaic + Setup preview, up to 24 kept), `sendChatMessage(broadcasterId, senderId, message)` (share to chat); GQL via services: follow/unfollow channel and category, followed categories, recommendations (recommended / similar), not-interested, report, whisper send, first video of a collection; category id lookup (`CategoryStreams.idOf`); `StreamEndLookup.latestBroadcastIfOffline` (go-live tap).
- **Images**: `CachedNetworkImage` with `CustomCacheManager` (disk cache, orphan sweep at startup); Twitch thumbnails sized by replacing `-{width}x{height}` (mosaic 440×247 / 320×180, Setup preview 320×180), memory decode widths (`memCacheWidth`), `imagePixelWidth` rounding to 160 px steps capped at 1920; raid pictures only from `https://static-cdn.jtvnw.net`.
- **Mark assets**: precached locally (no network).
- **Login**: WebView to Twitch OAuth (implicit flow handled by `AuthStore.createAuthWebViewController`: `id.twitch.tv/oauth2/authorize` with the scopes of `onboardingPermissions`, token read from the redirect), then redirect to `www.twitch.tv` where the `auth-token` cookie is harvested (JS `document.cookie`, 5 s cap).
- **Updates**: GitHub releases API of `UPDATE_REPO` (token `UPDATE_TOKEN` while private) via `OnsetUpdater` / `OnsetUpdateService`; APK download with Dio `CancelToken`, progress callback, integrity check, system installer.
- **Recent messages** link: `https://recent-messages.robotty.de/` (only opened in a browser from Setup; the chat history fetch itself is in the chat leaf).
- **Data written**: SharedPreferences `settings`, `first_run`; activity log; schedule reminders; go-live prefs. Telemetry custom key `is_logged_in` only (never ids — guarded).

## Tested behaviour

### Guards — repository rules (each must get a Rust equivalent guard, run in `cargo test` / CI)

Every guard below also asserts it actually scanned something (file-count floors, non-empty match sets); the Rust guards must keep those floors (a guard that inspects nothing passes everything) and their planted-sample self-tests.

**`test/guards/no_client_secret_test.dart`** — the client secret lives only in the token proxy (`tool/token_proxy/`).
- Rule 1: no Dart file under `lib/`, `test/` and `integration_test/` (if present) matches `fromEnvironment\(\s*['"]SECRET['"]` (pattern spelled in pieces so the guard file does not match itself; the guard file itself is skipped). Floors: > 200 files scanned, and `constants.dart` must be among them. Self-test: `String.fromEnvironment('SECRET')` is caught.
- Rule 2: no file in `lib/` contains the literal `client_secret`. Floor: `lib/` > 100 Dart files.
- Rust: `tests/guards/no_client_secret.rs` scanning `src/`, `tests/`, `build.rs` for `env!("SECRET")` / `option_env!("SECRET")` / `std::env::var("SECRET")` and the literal `client_secret` in `src/`, with equivalent floors.

**`test/guards/no_hardcoded_strings_test.dart`** (scanner `test/guards/hardcoded_strings.dart`, allow-list `test/guards/l10n_allowlist.dart`, ratchet `test/guards/l10n_baseline.dart`) — every viewer-read text comes from the ARB files.
- Scope: every `lib/**/*.dart` except `.g.dart` and `lib/l10n/app_localizations*`; floors: > 300 files, must include `lib/main.dart` and `lib/l10n/l10n.dart`.
- Flags a literal with two letters in a row that is in a text-showing place (`Text(`, `label:`, `tooltip:`, default `title`, enum constructor args, project helpers that show text, maps/getters/fields/locals later shown…) or reads like a sentence (≥ 2 words) anywhere, interpolations written `{}`. Ignores code: directives, annotations, logs, asserts, exceptions, `RegExp`, `Uri`, keys, route names, platform channels, preference keys, map keys and indexes, comparisons, `case` patterns, URLs, hosts, asset paths, triple-quoted strings.
- Allow-list `{path: {literal: why}}` (43 files); a stale entry fails. Entries in this leaf's area: `lib/main.dart` {'ONSET' — app name, a brand}; `lib/widgets/launch/onset_mark.dart` {'ONSET' — wordmark screen-reader label, a brand}; `lib/constants.dart` {'blue', 'chocolate', 'coral', 'firebrick', 'green', 'red' — Twitch chat colour ids}; `lib/utils/stream_languages.dart` {the 15 endonyms English, Français, Español, Deutsch, Português, Italiano, Русский, 日本語, 한국어, 中文, العربية, Türkçe, Polski, Nederlands, Svenska}; `lib/utils/irc_privmsg_builder.dart` {'@{} :{}!{}@{}.tmi.twitch.tv PRIVMSG #{} :{}' — an IRC line}.
- Ratchet `l10nBaseline` = `{}` (empty: every text translated); counts must match exactly (more fails, fewer fails until lowered, stale entries fail).
- Rust: `tests/guards/no_hardcoded_strings.rs` over `.slint` + `.rs` with the same place/sentence heuristics, an allow-list file with reasons (same entries), stale-entry failure, exact ratchet (empty).

**`test/guards/l10n_wiring_test.dart`** — `lib/main.dart`'s MaterialApp sets `localizationsDelegates`, `supportedLocales`, a `locale` from the setting, a `localeListResolutionCallback`, and its builder contains `LocaleSync`; self-test catches a missing setting and a missing LocaleSync. Rust: bootstrap test asserting catalogue loaded, supported = {en, fr}, setting-driven locale with system resolution, global current-locale sync.

**`test/guards/l10n_language_lookups_test.dart`** — direct language lookups (`lookupAppLocalizations`, `AppLocalizationsEn/Fr` incl. `.new`, `delegate.load`, `Localizations.override`; regex counts comments too) outside `lib/l10n/` are allowed ONLY as `{'lib/screens/onboarding/onboarding_flow.dart': 1}` (the Intro measures its description in every supported language so switching language never moves the tile). `L10n.english` (formatter-split too) is forbidden outside `lib/l10n/` with no exception. Rust: same allow-list map (the onboarding geometry module, 1 use).

**`test/guards/android_l10n_test.dart`** — Kotlin under `android/app/src/main/kotlin` (non-empty) has no English literal as a `NotificationChannel` name or notification `action` label (words come from Dart); the vendored PiP plugin has a French string for each of its texts (non-empty values); Android per-app language list and iOS `CFBundleLocalizations` equal the app's languages. Rust: native notification/tray/installer strings come from the catalogue; declared languages = {en, fr}.

**`test/guards/crash_report_privacy_test.dart`** — every `Telemetry.(setUserIdentifier|setCustomKey|log|recordError|newHttpMetric)(` call in `lib/` (comments stripped, strings masked) plus any `.setUserId(` and any direct `FirebaseCrashlytics.instance` use: no user identifier; setCustomKey key/value, log text, recordError `reason:`, and HTTP metric URL must not contain an identifier matching `login|channel|user|token|message|email|name|uri|url|path|query|broadcaster|chatter|whisper|target` (case-insensitive), except the vetted helpers `crashReasonFor` and `traceUrlFor`. Planted leaks (10 forms) must be caught; `setCustomKey('is_logged_in', true)` and `reason: 'moderation ${command.runtimeType}'` must pass. Rust: same identifier regex over every telemetry/crash API call, same vetted helpers.

**`test/guards/media_query_scope_test.dart`** — two rules, both requiring non-empty scans:
- Whole `MediaQuery.of(...)` reads allowed only (exact counts): `lib/screens/channel/chat/chat.dart` 1, `lib/screens/home/home.dart` 2, `lib/screens/home/top/browse_page.dart` 1, `lib/screens/channel/chat/widgets/reply_thread.dart` 1, `lib/screens/channel/chat/widgets/chat_user_modal.dart` 1, `lib/screens/vod/widgets/vod_chat_replay.dart` 1, `lib/screens/settings/widgets/settings_page.dart` 2, `lib/widgets/sheet/onset_panel.dart` 1 (each re-provides metrics or needs insets + size together).
- `View.of/maybeOf(...)…viewInsets` reads (they do not rebuild on keyboard changes) allowed only in `lib/screens/channel/channel_top_overlays.dart` (fallback without ChannelKeyboardScope) and `lib/screens/channel/channel_info.dart` (`_HiddenWhileTyping` listens to didChangeMetrics).
- Known limit: a read inside a string interpolation is not seen.
- Rust: `window_metrics_scope.rs` — components bind single window properties; whole-metrics reads and non-reactive IME-inset reads only in the listed modules.

**`test/guards/no_blur_over_video_test.dart`** — widget tests: the photo viewer opened from a chat emote has a plain scrim (no BackdropFilter), elsewhere the photo viewer keeps its soft blur; `OnsetNotification(overVideo: true)` is opaque with no blur, while the default OnsetNotification does blur. (The `onlyWhenSettled` rule for pages sliding over video is tested by `test/widgets/twitch_web_page_test.dart`.) Rust: UI tests on the same three cases.

**`test/guards/no_official_app_claim_test.dart`** — scope: `lib/**/*.dart` (not `.g.dart`), `assets/**/*.{md,txt,json,html,svg}`, `android/**/*.{kt,kts,xml,java}` skipping any `build/` or `.gradle/` segment, `PRIVACY.md`, `PRIVACY.fr.md` (not `site/`). Floors: ≥ 1 `.kt`, ≥ 1 `.md`, > 100 files. After joining split literals and comment lines: `official\s+twitch\s+app` and `application\s+officielle\s+de\s+twitch` (case-insensitive) forbidden anywhere; `official\s+app` forbidden inside single-quoted string literals of non-comment lines. "official Twitch API" is fine. Rust: same patterns over `src/`, `ui/`, `assets/`, installer resources, privacy Markdown.

**`test/guards/no_twitch_animations_test.dart`** — no Lottie files in `assets/animations`; no `lottie` import in `lib/` (floor: lib/ > 100 files); pubspec has no `lottie:` dependency and no `assets/animations`; pubspec DOES declare `assets/celebrations/spark_lime.png`, `spark_mint.png`, `spark_white.png`, `spark_dot.png`. Rust: no Lottie/rlottie crate, no animation JSON, and the four spark PNGs must be bundled.

**`test/guards/site_privacy_sync_test.dart`** — `site/privacy.html` ↔ `PRIVACY.md`, `site/fr/privacy.html` ↔ `PRIVACY.fr.md`: article text word for word (tags dropped, entities decoded, Markdown syntax dropped, whitespace collapsed), same link targets, contents lists = section headings, restricted markup; floors (Markdown > 10 000 chars, > 10 headings, > 4 cited settings paths, > 100 / > 20 labels); cited settings paths and labels must exist in the app. Rust: keep, and check labels against the PC catalogue.

**`test/guards/text_style_font_test.dart`** — every `textStyle:` written in `lib/` (files whose path contains `/l10n` skipped) with an inline `TextStyle(...)` must name a `fontFamily` (styles passed by name are accepted); floor: > 20 `textStyle:` occurrences; a widget test proves a button with such a style draws in Inter. Rust: every Slint text inherits/sets `font-family: "Inter"`.

**`test/guards/ivs_live_rate_clamp_test.dart`** — reads `android/app/src/main/kotlin/app/onset/IvsPlayerCore.kt`: contains `player.playbackRate = rate.coerceIn(1f, 1.1f)` (live), `LatencyController.maxLiveRate == 1.1` and `catchUpRate < 1.1`, `player.playbackRate = rate.coerceIn(0.5f, 2f)` (VOD), refusal `result.error("rate_rejected"`, latency tick `"ms" to runCatching { player.liveLatency }.getOrNull()` with `Log.w(CORE_TAG, "latency tick failed: $t")`, and no `send(latencyTick()) } catch (_: Throwable) {}`. Rust: player clamps live to [1.0, 1.1], catch-up < 1.1, VOD [0.5, 2.0], error code `rate_rejected`, latency failures logged never swallowed.

Self-tests ("the guard finds each planted leak", "the scanner…") prove every guard sees what it looks for; the Rust guards must include the same planted-sample tests (a guard that inspects nothing passes everything).

### Helpers and fixtures (test infrastructure to port)
- `test/helpers/l10n.dart` — `fr`/`en` locales; `loadInter()` loads `assets/fonts/*.ttf` under family Inter so text is measured like on device; `useLocale`; `pumpLocalized(tester, child, locale, size, textScale, wrap)`; `englishLeaks` / `isAppEnglish` (English left on a French screen, with Twitch/viewer content excluded); `shownTexts`, `shownPatterns`, `clippedTexts` (text cut without ellipsis), `ellipsizedTexts` / `ellipsizedAppTexts` (an app label ended by "…" fails); `frenchScreenSizes` = 360×640, 390×844, 1280×854, 854×1280, 844×390; `frenchTextScales` = [1.0, 1.3]; `sweepLocales` = [fr, en]; `expectFrenchThroughout` (no overflow/exception, no English, no clipping, scrolled to the end of each list). Rust: a headless Slint test harness rendering each screen at those 5 window sizes × 2 text scales × 2 languages with the same four checks.
- `test/helpers/semantics_audit.dart` — every on-screen button node must have a tap action and every pressable node a label; fails when no button exists (proves it looked). Rust: accesskit tree audit.
- `test/helpers/live_curves.dart` — counts undisposed `CurvedAnimation`s (leaks per rebuild). Rust: animation handle leak counter.
- `test/helpers/keyboard_animation.dart` — simulates the Android IME inset growing over N frames with nav-bar padding shrinking. Rust: IME/window-resize simulation.
- `test/helpers/fake_twitch_http.dart` — fake Twitch for sign-in (`/oauth2/validate`, Helix answers only a token with its own Client-Id).
- `test/helpers/fake_ivs_native.dart` (fake IVS texture player channels), `test/helpers/fake_player.dart` (live stream/channel fixtures + observable `PlayerController`), `test/helpers/fake_vod_controller.dart`, `test/helpers/fake_realtime_socket.dart` (scripted Hermes socket), `test/helpers/fake_clip_backend.dart`, `test/helpers/fake_cast_bridge.dart` (scripted `CastBridge`), `test/helpers/chat_message_harness.dart`, `test/helpers/chat_store_harness.dart`, `test/helpers/chat_widget_harness.dart`, `test/helpers/community_highlights_harness.dart`, `test/helpers/mod_tools_harness.dart` — fakes/harnesses used by feature tests (ported alongside their features).
- Fixtures (recorded Twitch payloads, reused by API/model tests in other leaves; keep them as JSON test data in Rust): `test/fixtures/api_responses.dart`, `test/fixtures/irc_messages.dart`, `test/fixtures/channel_profile_payloads.dart`, `test/fixtures/chat_identity_payloads.dart`, `test/fixtures/chat_ui_settings_payloads.dart`, `test/fixtures/clip_eligibility_payloads.dart`, `test/fixtures/clip_extras_payloads.dart`, `test/fixtures/clip_responses.dart`, `test/fixtures/community_goal_payloads.dart`, `test/fixtures/community_gql_payloads.dart`, `test/fixtures/community_highlights_payloads.dart`, `test/fixtures/community_points_payloads.dart`, `test/fixtures/directory_payloads.dart`, `test/fixtures/drops_gql_payloads.dart`, `test/fixtures/follow_payloads.dart`, `test/fixtures/free_preview_payloads.dart`, `test/fixtures/gif_payloads.dart`, `test/fixtures/hermes_frames.dart` (double-encoded pubsub JSON), `test/fixtures/hype_train_gql.dart`, `test/fixtures/hype_train_payloads.dart`, `test/fixtures/hype_train_payloads_tbc.dart`, `test/fixtures/legendary_payloads.dart`, `test/fixtures/live_together_payloads.dart`, `test/fixtures/pinata_payloads.dart`, `test/fixtures/prediction_gql_payloads.dart`, `test/fixtures/social_payloads.dart`, `test/fixtures/unban_request_payloads.dart`, `test/fixtures/vod_responses.dart`, `test/fixtures/weekly_rewards_payloads.dart`.

### Theme and constants
- `test/theme_test.dart` — themes built for the same accent are identical (cache), `OnsetTextStyles.resolve` equal for equal colours, copies equal.
- `test/theme/tokens_v2_test.dart` — every 1.0 token unchanged; 2.0 additions (raised, three text tiers, secondary == metadata, stronger hairlines, accent tint, hype, danger, skeleton greys readable on ground and cards with subtle sheen), radii 8/12/16/24/pill, spacing 4-pt grid, the type scale values, metadata tabular figures.
- `test/theme/theme_font_test.dart` — headings, body and numbers use Inter; `displayWeight` rounds to a shipped weight.
- `test/theme/sub_notice_colors_test.dart` — sub notice accent is lime darkened on white, background is the accent tinting each theme, bar stands out from the tint, lime text ≥ 4.5:1 on the tint in both themes, theme carries the colours, copyWith/lerp.
- `test/constants_test.dart` — `regexLink` matches http/https/scheme-less URLs, paths, queries, ports, fragments, many TLDs incl. international, image/video/archive file names, and refuses the negatives (left/right boundaries).

### Utilities
- `test/utils/common_utils_test.dart` — `getReadableName` cases; `adjustChatNameColor` brightens on dark, darkens on light, preserves compliant colours, honours target and custom background.
- `test/utils/content_labels_test.dart` — known names per language, CamelCase spacing, cleanup/dedupe/cap 8.
- `test/utils/context_extensions_test.dart` — `isLargeScreen`/`safePaddingTop` consumers are not rebuilt by keyboard frames.
- `test/utils/large_screen_test.dart` — tablet large in both orientations, phone not, split-screen half < 600 keeps phone layouts.
- `test/utils/https_url_test.dart` — raid pictures only from Twitch's host.
- `test/utils/image_size_test.dart` — rounds up to the step at the DPR, never above the cap, never zero.
- `test/utils/irc_privmsg_builder_test.dart` — emotes/badges/colour, sanitisation, extra-tag allow-list, GIF tag in characters, host allow-list, max GIFs, mod badge → `mod=1`, `/me` safety.
- `test/utils/link_gate_test.dart` — external link asks only for non-Twitch hosts (look-alikes still ask), refused schemes refused before asking, no gate = open.
- `test/utils/link_router_test.dart` — VOD/videos/clip links in-app, channel not handled here, before the app is ready links launch, unhandled launch, only web schemes, browser preference respected.
- `test/utils/modal_bottom_sheet_test.dart` — sheet 12 dp under the video, video undimmed and tap closes, nested sheets too, keyboard room, landscape forgets, edge > 60 % ignored, no video = normal.
- `test/utils/punycode_test.dart` — non-ASCII labels → `xn--`, percent-encoded host decoded first.
- `test/utils/share_link_test.dart` — anchored share sheet, clipboard fallback on unavailable / failure, second tap ignored.
- `test/utils/stream_languages_test.dart` — order ('' first, 'other' last), unknown → '', Helix codes, endonyms vs translated names.
- `test/utils/twitch_links_test.dart` — every VOD / channel videos / clip / channel / reserved / foreign / category / app-scheme form, start times, collections, slug case.
- `test/utils/twitch_subscribe_url_test.dart` — subs URL for logins only.

### Motion, launch and shared widgets
- `test/widgets/motion/motion_test.dart` — spring damping 1.0 / 0.35 s and 0.8 / 0.4 s, curves, press/stagger/reduced values, `reduceMotionOf` (Android and iOS flags), `motionDuration`, haptic mapping.
- `test/widgets/motion/press_scale_test.dart` — sinks to 0.97 while down, springs back from current value, never steals the tap, releases on scroll, inert under reduce motion and when disabled.
- `test/widgets/motion/rolling_number_test.dart` — reads once, only changed digits roll, direction from formatted numbers (k/M/B units only at the end, grouping styles), unreadable rolls up, tabular width, new leading digit grows in, reduce motion instant, clipped.
- `test/widgets/motion/signal_ping_test.dart` — ripple grows/fades in front, bursts then rests with no ticker, scrolled out → no ripple, background stop/resume, TickerMode, reduce motion still, size kept, LiveIndicator = SignalPing in live colour.
- `test/widgets/motion/staggered_entrance_test.dart` — rise/fade, step spacing, cap, no replay, scope first batch only, gate holds, reduce motion fade, no frame scheduled once settled.
- `test/widgets/launch/launch_intro_test.dart` — plays on cold start covering a home that builds underneath; `running` notifier; no intro on warm start, Android/iOS reduce motion, screen reader; 1.4 s then nothing left running; dot → overshoot → settle; rings then letters; flight to fallback slot or the real header mark; home cards enter as uncovered.
- `test/widgets/launch/onset_mark_test.dart` — every family has 5 variants at pixel size, pubspec lists them, tile ground = icon's ground; Android splash is the bitmap (no vector), draws the very pixels of the Flutter 72 dp tile at each density, centred; variant selection never undersized; `precacheFor` sized and pre-metrics paths.
- `test/widgets/sheet/svg_path_test.dart` — lines end where data says, arcs/smooth curves/joined numbers, compact arc flags, broken data refused, every sheet glyph parses inside its 24 box.
- `test/widgets/sheet/onset_sheet_test.dart` — sheet frame both brightnesses, panel tone for sheet over sheet, under video on phone; SheetRow 52/60 dp and danger colour; OnsetSwitch 44 × 26 toggles and announces, disabled inert; status line; dialog card and route naming; counter counts characters.
- `test/widgets/sheet/onset_panel_test.dart` — `placePanel` cases (points above pill in chat column, emote menu above input, user card beside chat under the video, high message card below video, no room → null, narrow column spill); `showSheetOrPanel` tablet panel vs phone sheet, reduce motion fade, keyboard lift and resize close, curves not leaked, panel-tone surface reported.
- `test/widgets/state_views_test.dart` — `onFillColor`, offline vs alert marks, empty variants, sign-in, inline retry, layout at several sizes.
- `test/widgets/skeleton_loader_test.dart` — dark greys with moving sheen, seamless loop, one band across neighbours, light greys, reduce motion still, TickerMode, sizing.
- `test/widgets/global_mini_player_test.dart` — area under shell chrome / app bar, short screen header wins, chrome change keeps corner, glide, drag direct, reduce motion no glide, grab mid-glide, lift + landing targets, no curve pile-up, corner strokes readable.
- `test/widgets/coach_mark_test.dart` — once then never, leaving early keeps it, waits for predecessor, hides with its control, nothing without settings.
- `test/widgets/onset_chip_test.dart` — screen reader can pick, 44 dp target with smaller pill.
- `test/widgets/draggable_divider_test.dart` — screen reader steps, capped at max.
- `test/widgets/external_link_dialog_test.dart` — shows destination, Cancel stays, Open (+ Don't ask again), ASCII host for look-alikes, setting off → no dialog.
- `test/widgets/accent_throttle_test.dart` — immediate then ≤ every 100 ms then trailing; flush / cancel.
- `test/widgets/adaptive_sliver_list_test.dart` — columnsFor (phone 1; 7" tablet 3 row cards landscape / 2 portrait; tiles 4 / 3), layout, empty last-row cells, outer-column insets only.
- `test/widgets/cast_button_test.dart` — hidden when unsupported, no device / cannot cast messages, cast to picked device, failure frees list, media not ready, stop offered, button lit while connected.
- `test/widgets/profile_picture_test.dart` — no re-request on parent rebuild after failure, delayed retry, late success after dispose harmless, bounded retries, cached picture on first frame.
- `test/widgets/recommendations/recommended_channels_test.dart` — shelf hides hidden channels, failed load hides shelf, not-interested reason/hide/undo, refused reason still hides, signed out sends nothing.
- `test/widgets/report/report_sheet_test.dart` — reason → confirmation → report; Back returns; no double send; no session → asks before twitch.tv; both steps fit in fr/en at scales.
- `test/widgets/share_sheet_test.dart` — `sendChatMessage` posts as viewer, dropped message throws with reason; chat send + snackbar; missing chat scope → log in again; whisper flow.
- `test/widgets/user_actions_modal_test.dart` — logged-in follow row, logged out none, follow / unfollow confirm / unknown state read first / unknown still follows, only twitch.tv pages open.
- `test/widgets/follow/follow_actions_test.dart` — web session connect once per tap, TV session follows without web session, category state with web session only, connect failure reported, logged-out never connects, Helix channel state, suggestions rules.
- `test/widgets/follow/follow_flow_test.dart` — optimistic flip and rollback, one-time TV offer, connect sheet, expired TV session wording, native follow snackbar, unfollow confirm, Twitch's reason, TV code, Retry, per-result step names, web-session auto connect, ONSET login asks.
- `test/widgets/follow/follow_failure_fit_test.dart` — every follow failure snackbar (noWebSession, signedOut, needsTvSession, tvSessionExpired, integrityRefused, gqlError, failed) reads whole with its action in fr/en at 320×640, 360×640, 390×844, 844×390, 1024×1366 and scales 1.0/1.3.
- `test/widgets/onset_update_prompt_test.dart` — popup names build and notes, waits on installer, error messages per exception, unexpected error closes progress, install-permission round trip, `OnsetUpdateChecks` first-frame check, resume re-check, throwing check doesn't stop the next, off when disabled.
- `test/widgets/onset_update_sheet_test.dart` — update sheet at several widths, phone back = Later, release notes page (versions, dates, points; unreadable; empty).
- `test/widgets/twitch_web_page_test.dart` — header never blurs while the page slides over a channel.
- `test/widgets/uptime_test.dart` — unreadable start → nothing; readable → a time.
- `test/semantics/app_semantics_test.dart` — accessibility audit of shell, chat bottom bar, VOD overlay, clips feed, channel profile header, live feed, onboarding setup, points button; static check that no `Semantics(button, excludeSemantics)` in `lib/` hides the wrapped tap; inventory self-test.

### Onboarding, workflows and links
- `test/screens/onboarding/onboarding_flow_test.dart` — large text and every step at phone/tablet sizes in both languages at 1.0/1.3; 4-segment progress; back behaviour (none on Intro); permissions listed == login scopes; Twitch page bar + cookie help; signed in → Setup shows who; only the latest login attempt counts; failed login shown on Setup; Twitch page shrinks above the keyboard.
- `test/screens/onboarding/onboarding_language_test.dart` — preselection (English device, French device incl. fr-CA, unsupported → English, prior choice wins); tapping Français switches at once and back; the pill never moves tile/name; sizes; Next stores the shown language; pill semantics; every step fits in both languages; leak check self-test.
- `test/screens/onboarding/intro_phone_fit_test.dart` — roomy keeps design, tighter gaps, tile shrinks only as needed, version line goes (tile grows back), last resort description scrolls.
- `test/screens/onboarding/login_webview_test.dart` — bar/host/help; closes after twitch.tv sign-in; user said no; a successful login waits for Twitch's redirect; 20 s limit; harvest that never answers still closes (5 s); a failing new login over an existing account shows failure; Back during sign-in removes only its route; rebuild never reloads; host strip never shows path/query/fragment; token back → signing-in; page failure + Try again; success keeps the cookie harvest.
- `test/screens/lot5_links_and_prompts_test.dart` — feedback prompt cadence (asks after a dozen opens, later pushes back, done stops, send opens project page, never-stop variant, French), every twitch.tv page named and described in both languages, report and Mod View links only for real logins (`twitchReportUri`/`twitchModViewUri`), offline channel says check back / failure offers retry.
- `test/workflows/onset_update_workflow_test.dart` — the GitHub Actions update workflow: visibility read from event and live repo, token required only when private, passed as dart-define never printed, no client secret required or passed, build numbers > 2000, token proxy URL from a repo variable and validated with the app's own pattern, public log explains missing token, publish guard fails closed and deletes refused artifacts, refuses a token build once public. Rust: the same workflow checks for the Windows release pipeline.

## Wide and tablet layout

- **Threshold**: `kLargeScreenShortestSide = 600.0` dp; `isLargeScreenSize(size) = size.shortestSide >= 600` (both sides ≥ 600). `context.isLargeScreen` = `LargeScreenScope.maybeOf(context) ?? isLargeScreenSize(MediaQuery.sizeOf)`; `LargeScreenScope(large: true)` forces tablet layouts inside a narrower tablet pane. A split-screen half narrower than 600 keeps phone layouts.
- **Gutters**: phone 16, tablet 28 (`OnsetSpacing.gutterPhone/gutterTablet`).
- **Adaptive lists** (`AdaptiveSliverList`): phones 1 column; large screens `ceil(width / maxItemWidth)` columns, row cards 560 dp max, video tiles 320 dp max (4 in a 1280 window) with 18 dp side padding (+ 10 dp card padding = 28 gutter).
- **Sheets vs panels**: large screen + anchor + room → anchored panel (gap 12, margin 12, nub 20 dp from panel ends minimum, avoid the video rect, line up in the chat column); otherwise bottom sheet. Panels close on window resize/rotation.
- **Sheets under video**: only phone portrait with the video edge ≤ 60 % of height; tablets/landscape get normal sheets.
- **Launch intro**: tablet wordmark 40 sp (phone 34), underline 140 dp (120), rise 22 (20), gap below tile 31 (30), ring max scales 3.2 / 4.4 (2.8 / 3.6), glow blur 48 (40), fallback header slot (28, top+21, 30×30) vs (16, top+14, 28×28); landing on tablet starts from the tile already on screen (1250 ms, no pop, no ring).
- **Onboarding**: tablet landscape brand pane clamp(0.4375 w, 360, 560) on the left; portrait pane clamp(0.36 h, 320, 480) on top; 72 dp bar; step padding 80/48 (landscape, by steps width ≥ 600) or 64; footer buttons in a row at the bottom right (primary 220, 250 on Log in); Login permissions as a 2-column card grid (tile 36); Intro as eyebrow + 40/32 headline (≥ 480 content width → 40); accent picker as a 420 dp dialog; login help 440 dp dialog; Twitch login page centred at max 560 dp; titles 40 sp (34 phone), lead 16 (15); mosaic scale width/560, inner width 780 × scale, tile 132 high, gap 12, live tile index 7, radial + edge fades; tablets rotate freely (phones locked portrait during onboarding).
- **State views**: mark 88 (72 phone), signal-off 104 (88), message max 360 (260) at 20 sp w700, action pill 48 (44), spacing 18 (16).
- **Update offer**: 420 dp dialog (inset 40) instead of a bottom sheet.
- **Recommendations shelf**: tile 132 dp (112), gutter 28.
- **Mini player**: same 42 % width rule at any size; area from the shell chrome insets.
- **Phone landscape** (not tablet): onboarding uses a two-part layout (brand left, column right) — `_Geometry._phoneLandscape`.
- **Tested windows**: 360×640, 390×844, 1280×854, 854×1280, 844×390 (+ 320×640, 1024×1366 for follow failures), text scales 1.0 and 1.3.
- **Desktop**: every desktop window whose shortest side is ≥ 600 is "large"; a narrow desktop window (< 600 shortest side) must get the phone layouts exactly, so the Rust UI keeps both layout trees and switches live on resize.

## PC equivalent

Nothing in this leaf is dropped; each element maps to a native Windows (then macOS/Linux) implementation in Rust + Slint (Skia renderer):

- **Startup**: `main.rs` runs the same ordered bootstrap: init logging/telemetry (opt-in, `is_logged_in` bool only), load settings JSON (same schema/defaults, stored in `%APPDATA%\ONSET\settings.json`; `first_run` flag alongside), first-run credential wipe (Windows Credential Manager entries under the ONSET target — the uninstall-leftover rule applies to the credential store too), Fluent/ARB catalogue with system-language resolution (Windows `GetUserPreferredUILanguages`), shared `reqwest` clients (Helix client with auth middleware; anonymous GQL client with 5 s connect / 8 s read timeouts and no Helix token), realtime/EventSub tasks paused when the window is minimised for > 60 s (desktop analogue of "background"), activity/reminders/go-live poller (Windows toast notifications with click-to-open), whisper store, then show the window. The Android-only pieces map to: media_kit → the native low-latency player (libmpv/ffmpeg via the player leaf); `LocaleBridge` per-app language → no-op on Windows (app setting only); `AdvancedInAppReview` → the in-app feedback prompt (no store review API on a sideloaded build; Microsoft Store `StoreContext.RequestRateAndReviewAppAsync` if published there).
- **Deep links**: register the `twitch://` and `ttv://` URL protocols (and an "Open twitch.tv links with ONSET" option) in the registry (`HKCU\Software\Classes`); single-instance app forwards the URI to the running instance (named pipe); same `TwitchLink` parser (pure Rust port, same tests), same 3 s timeout for the initial link, same failure toast with "Open in browser".
- **Notifications**: go-live / mention / reminder toasts via `windows::UI::Notifications` (WinRT) with activation arguments routing to the same `_openGoLiveNotice` / `_openMention` logic; the "notification settings" intent maps to a toast "Settings" button opening ONSET's notification page.
- **Theme system**: a Slint `global Theme` with every token of `theme.rs` (colours dark/light, radii, spacing, type scale with `font-feature-settings: "tnum"`), the accent seed driving derived Material-like roles (port `ColorScheme.fromSeed` HCT algorithm via `material-colors` crate) while selection colours stay pinned to `live`. Follow Windows dark/light (`UISettings` / registry `AppsUseLightTheme`) when `themeType = system`. Inter bundled (`assets/fonts/Inter-*.ttf`, OFL licence shown in About).
- **Motion**: a Rust animation module with the exact springs (critically damped / 0.8 ratio closed-form), cubic-bezier evaluators, and reduce-motion from Windows "Animation effects" (`SPI_GETCLIENTAREAANIMATION`), re-read on `WM_SETTINGCHANGE`. Slint `animate` blocks use the same durations/curves; springs driven from a Rust timer when Slint's built-ins are insufficient.
- **Haptics**: no-op trait on desktop (optional XInput rumble), call sites kept.
- **Launch intro**: Windows has no native splash hand-over; the window opens on the black frame with the 72 dp tile at the centre and the full 1400 ms storyboard plays (the `fromTile` path is used if a native splash window is implemented with the same bitmap and corners). Mark bitmaps chosen by the window's scale factor (100 %, 150 %, 200 %, 300 %, 400 % → 1.0x…4.0x families). Skip on click, on deep link, on window deactivation, on any navigation.
- **Onboarding**: identical steps and layouts (desktop windows normally hit the tablet geometry; a narrow window uses the phone geometry); orientation lock becomes no-op; the Twitch login page uses WebView2 (see `login_webview.dart` section) with cookie harvest via the WebView2 cookie manager.
- **Sheets / panels / dialogs**: bottom sheets on narrow windows; anchored panels (popovers) on wide windows; Escape closes sheets/panels/dialogs; scrims and corner radii unchanged; focus is restored to the previously focused control except the chat input (same "proper focus" rule).
- **Mini player**: in-window floating overlay with the same rules; Android PiP → an optional always-on-top borderless OS window ("pop-out player") keeping the media-only pause action (play/pause button), plus Windows SMTC (System Media Transport Controls) for the media keys.
- **Cast**: Google Cast over mDNS + CASTV2 (`rust_cast`), same sheet and states; hidden if discovery is unavailable.
- **Images**: disk image cache with sweep, decode at target size, 500 ms fades; profile-picture URL cache and retries identical.
- **Share**: Windows Share contract (`DataTransferManager`) anchored to the button when available, else clipboard + "Link copied" toast.
- **External links**: `ShellExecuteW`/`open` crate for the default browser ("external"), an internal WebView window for "in-app browser view"; confirmation dialog for non-Twitch hosts with punycode display.
- **Updates**: GitHub-release self-updater for Windows (installer/MSIX download, checksum/signature check, progress dialog with cancel, postpone), same sheet/dialog copy.
- **Accessibility**: accesskit (Slint built-in) with the same semantics labels, live regions (→ UIA notifications), slider semantics for the splitter (arrow keys ±5 %), toggle states, headers, route names for dialogs.
- **Mouse & keyboard additions** (no behaviour removed): hover states for pressables (PressScale on mouse down), splitter resize cursor, right-click as long-press (recommendation tile "Not interested"), keyboard focus rings using the accent, Tab order matching visual order, scroll wheel on all scroll views, `OnsetScrollbar` visible on hover.
- **Tests**: port every guard (table above) and every behavioural test file as Rust unit/UI tests; the l10n sweep runs headless Slint at the five reference window sizes × two text scales × two languages.

### Known Android defects (do not reproduce; code values win over misleading comments)
- `_openTwitchLinkInApp` (main.dart) returns false when `navigatorKey.currentState == null`; `handleDeepLink` then falls through to the channel path, which takes the first path segment (e.g. `videos`) as a login, fails the Helix lookup and shows the failure snackbar. PC: queue the link until the navigator exists.
- `launch_intro.dart` doc comment gives tablet landing values 8–52 % / 40–62 % / 44 %; the code uses 24–64 % / 48–68 % / 50 % (spec follows code).
- `state_views.dart` comment calls StatePill's hairline "16 %"; the value is 0x1F (12 %).
- `DraggableDivider.showDividerLine` is accepted but unused (the line only shows while hovered/dragged).
- `TwitchWebPage` sets its own `systemOverlayStyle` without a navigation-bar colour, which (per theme.dart's own comment) drops the theme's nav-bar colour on that page. PC: n/a, keep the window chrome consistent.
- `SkeletonText` picks a new random width on every build, so text skeletons change width when their parent rebuilds. PC: seed the width once per instance.
- `Uptime` shows a negative duration (e.g. `-0:00:05`) if the device clock is behind the stream start. PC: clamp at 0.
- `OnsetAlertDialog`'s "2 actions" and "more" branches are identical (harmless).
- `CoachMark` entrance ignores reduce motion (always 260 ms fade + scale, replayed when the target reappears). PC: use `motionDuration` (150 ms fade, no scale) under reduce motion.
- `ShareSheet._sendToChat` uses `channelName ?? ''`, so with a channel id but no name the snackbar reads `shareSentToChat(name: '')`. PC: fall back to a name-less wording (the `shareSendToChat` phrasing) when the name is unknown.
- `UserActionsModal` unpin mutates `pinnedChannelIds` in place (`[...list..remove(id)]`) before assigning the copy. PC: remove from a copy.
- `ReportSheet._send` has no try/catch: a throwing sender leaves the sheet stuck in "sending". PC: catch, map to `failed`, pop with that outcome (snackbar `viewerActionResult(status: failed)`).
- `splashFactory: null` gives Android the `InkSparkle` effect, not the ripple the code comment implies; PC uses InkRipple.

---

**Source file reference** — one section per source file of this leaf, with exact values (part of "PC equivalent": each describes what the Rust port must reproduce).

### lib/main.dart

Entry point. Imports ~90 modules (all API services, stores, services, screens used by routing, widgets). Contains `main()`, the global `navigatorKey`, `MyApp`/`_MyAppState` (routing, deep links, notification taps, MaterialApp builder stack).

**`main()` startup sequence, in exact order:**
1. `WidgetsFlutterBinding.ensureInitialized()`; `registerFontLicenses()` (adds `assets/fonts/OFL.txt` as a `LicenseEntryWithLineBreaks(['Inter'], text)` to the licence registry; fonts are assets so Flutter would not list them).
2. `final launchInfo = LaunchInfo.load()` — a Future started now over the `onset/launch` MethodChannel (`coldStart`, `fromLauncher`, `nativeTile`; `playsIntro = coldStart && fromLauncher`; `LaunchInfo.none` = no cold start, no tile), awaited only at `runApp`.
3. `markReady`: if `platformDispatcher.implicitView` is non-null, `OnsetMark.precacheFor(view)` (decode the mark image for the first frames; bounded so it never holds the launch), else completed future.
4. `MediaKit.ensureInitialized()` (native media_kit engine — the low-latency player).
5. `CustomCacheManager.scheduleOrphanSweep()`.
6. In parallel (record `.wait`): `Telemetry.initialize()` (Firebase only if the build carries config), `SharedPreferences.getInstance()`, `initUtils()` (from common_utils: on iOS detects an iPad via device_info_plus).
7. `firstRun = prefs.getBool('first_run') ?? true`. If firstRun: `FlutterSecureStorage().deleteAll()` fired UNAWAITED with catchError logging (workaround: secure storage survives uninstall on Android/iOS; non-blocking to avoid ANR on Android 14). Must be kept.
8. `settingsStore = SettingsStore.fromJson(jsonDecode(prefs.getString('settings') ?? '{}'))`.
9. `syncFirebaseCollection(settingsStore)` (collection follows the setting, never in debug).
10. `persistSettings(settingsStore, (json) => prefs.setString('settings', json))` — debounced save, immediate when app leaves screen.
11. `adoptSystemLanguage = await syncSystemLanguage(settingsStore, LocaleBridge.shared)`; `reaction(appLanguage → LocaleBridge.shared.push(language))`; `AppLifecycleListener(onResume: adoptSystemLanguage)` — Android 13+ per-app language kept in sync both ways.
12. `dioClient = DioClient.createClient()`; services on it: `TwitchApi`, `BTTVApi`, `FFZApi`, `SevenTVApi`.
13. `anonymousGqlDio = Dio(BaseOptions(connectTimeout: 5 s, receiveTimeout: 8 s))` with NO Twitch auth interceptor (must never carry the Helix token). Services on it: TwitchVodService, TwitchHypeTrainService, TwitchClipService, TwitchCommunityHighlightsService, TwitchChannelProfileService, TwitchDirectoryService, TwitchChatRulesService, TwitchChatHistoryService (web token per request, GQL only), TwitchFollowedCategoriesService (same), TwitchWatchStreakService (same), TwitchViewerActionsService, TwitchCommunityService, GiphyService, TwitchSocialService, TwitchAccountGqlService, TwitchReportService.
14. `realtimeClient = TwitchRealtimeClient()` (anonymous Hermes; connects on first subscription, sleeps after a minute in background); lifecycle listener onPause/onResume → realtimeClient; another → `SharedTimerService.instance.pause/resume`.
15. `GlobalAssetsStore(twitchApi, bttvApi, ffzApi, sevenTVApi)`.
16. `authStore = AuthStore(twitchApi)`; dioClient interceptors add `TwitchAuthInterceptor(authStore)` then `UnauthorizedInterceptor(authStore)` (401 handling).
17. `twitchTvSession = TwitchTvSessionStore(auth: TwitchTvAuthService(anonymousGqlDio), viewerId: logged-in user id or null)`; `twitchTvInterceptor = TwitchTvSessionInterceptor(credentials, onRejected: markRejected)` added to anonymousGqlDio; `twitchPointsService = TwitchPointsService.withDefaults(interceptors: [twitchTvInterceptor])`; `authStore.addSessionEndListener(twitchTvSession.endAccountSession)`.
18. twitchVodService wired: `webToken = () => authStore.twitchWebToken`, `onWebTokenRejected = authStore.renewTwitchWebToken`, `viewerId` (sub-only VODs, watch positions).
19. `await authStore.init()`.
20. `TwitchTvLoginOffer(store, context: navigatorKey.currentContext, logins: authStore.interactiveLogins)`; `reaction(user id → offer.accountChanged(id), fireImmediately: true)`.
21. `eventSubClient = TwitchEventSubClient(create: twitchApi.createEventSubSubscription(type, version, condition, sessionId), delete: deleteEventSubSubscription)`; lifecycle pause/resume.
22. `reaction(user id → GoLivePrefs.load().setUserId(id))` fireImmediately; a null id is ignored (a not-yet-logged launch keeps the last id; a real logout removes the token which stops the check).
23. `activityStore = ActivityStore(log: await ActivityLog.load())`; `reminders = ScheduleReminders(prefs, platform: LocalReminderPlatform())`, `ScheduleReminders.shared = reminders`; `refreshActivity()` = add `reminders.takeDue()` (errors logged "Reminders unavailable") then `activityStore.refresh()`; run now and on every resume.
24. `MentionAlerts.shared = MentionAlerts(post: show MentionNotifications.show(notice, L10n.current) + activity mentionEntry, inFront: appInFront)`.
25. `goLivePoller = GoLivePoller(check: await GoLiveNotifications.ready (timeout 20 s) then checkGoLiveInApp(api, prefs, loggedIn, notify: GoLiveNotifications.show + activity goLiveEntry per notice), playingInBackground: BackgroundAudio.shared.playing)`; `AppLifecycleListener(onStateChange: poller.onLifecycle)`; `start()`.
26. `whisperStore = WhisperStore(twitchApi, listen: eventSubClient.listen, currentUserId, credentials: authStore.token, mutedUserIds/archivedUserIds from settings, historyThreads/historyMessages via TwitchSocialService with twitchWebToken ?? '', onPreferencesChanged writes muted/archived lists back into settings in runInAction)`.
27. `Telemetry.setCustomKey('is_logged_in', bool)` — whether, never who (no user id in crash reports).
28. `await markReady`; `runApp(MultiProvider(...))`.

**Providers (all `Provider.value` unless noted), in order:** AuthStore, TwitchTvSessionStore, TwitchPointsService, SettingsStore, TwitchApi, BTTVApi, FFZApi, SevenTVApi, TwitchVodService, TwitchHypeTrainService, TwitchClipService, TwitchCommunityHighlightsService, TwitchChannelProfileService, TwitchDirectoryService, TwitchChatRulesService, TwitchChatHistoryService, TwitchFollowedCategoriesService, TwitchWatchStreakService, TwitchViewerActionsService, TwitchSocialService, `FollowActions(service: viewerActions, api, categories, webToken, tvToken: twitchTvSession.accessToken, viewerId, connectWebSession: authStore.ensureTwitchWebToken)`, TwitchCommunityService, GiphyService, TwitchAccountGqlService, TwitchReportService, TwitchRealtimeClient, GlobalAssetsStore, TwitchEventSubClient, WhisperStore, ActivityStore, `Provider<MiniPlayerStore>(create)`, `Provider<OnsetUpdater>(create)` (silent without UPDATE_REPO). Child: `MyApp(firstRun, launchInfo: await launchInfo)`.

**`navigatorKey`**: global `GlobalKey<NavigatorState>` (sleep timer, notifications, deep links push without context).

**`MyApp({firstRun = false, launchInfo = LaunchInfo.none})`.** `_MyAppState` holds `AppLinks _appLinks` and `_linkSubscription`.

`initState`: `AdvancedInAppReview().setMinDaysBeforeRemind(7).setMinDaysAfterInstall(1).setMinLaunchTimes(5).setMinSecondsBeforeShowDialog(3).monitor()`; `LinkRouter.inAppHandler = _openTwitchLinkInApp`; `LinkRouter.externalLinkGate = (url) => confirmExternalLink(navigatorKey.currentContext, url, ask: settings.confirmExternalLinks, stopAsking: () => settings.confirmExternalLinks = false)`; `_initDeepLinks()`; `_initGoLive()`; `NotificationSettingsLink().listen(_openNotificationSettings)`.

`_openNotificationSettings`: post-frame (and `scheduleFrame()` so it runs even when idle) push `MaterialPageRoute(name: settingsRouteName(SettingsPageId.notifications), SettingsScaffold(title: page.title(l10n), body: buildSettingsPage(page, settingsStore, authStore)))` — Android "notification settings" system link lands on ONSET's notification page.

`_initGoLive`: `GoLiveNotifications.init(onOpen: openChannel, onMention: _openMention)`; `launchNotice()` — if the app was started from a notice, after `endOfFrame`, open mention or channel; then `if (GoLivePrefs.enabled) GoLiveScheduler.start()` (re-registered each launch: Android drops it after force-stop). Errors → debugPrint + `Telemetry.recordError(reason: 'go-live init')`.

`_openGoLiveNotice(login)`: starts `StreamEndLookup(api, vods).latestBroadcastIfOffline(login)` in parallel with `handleDeepLink(https://www.twitch.tv/<login>)`; if the channel turned out offline and has a latest VOD, and the channel route (`VideoChat.routeOf(login)`) is still current, `navigator.replace` it with `VodScreen(vodId, vod)` (route name VodScreen.routeName).

`_openMention(login)`: computes `route = VideoChat.routeOf(login)`, routes above it from `OnsetShell.routeObserver.above(route)`, then `mentionTapFor(login, open, shown: route.isCurrent, closable: mentionMayClose(names above), miniLogin: MiniPlayerStore.userLogin)`: `bringToFront` → nothing; `backToChannel` → `popUntil(route)`; `notice` → clear snackbars and show SnackBar `mentionNotice(login)`; `restoreMini` → `GlobalMiniPlayer.restore(mini)`; `openChannel` → handleDeepLink(channel URL).

`_displayNameOf(login)`: Helix getUser display name, else login.

`_openCategoryLink(link, section = CategorySection.live)`: `CategoryStreams.idOf(api, link)`; found → post-frame push CategoryStreams(categoryId, initialSection); not found → `TwitchWebPage.open(title: link.name ?? l10n.deepLinkCategoryFallback, url: twitchCategoryUrl(link))`.

`_openAppDestination(link)`: BrowseLink → shell place browse; FollowingLink → following; ActivityLink → activity; SearchLink(term) → `Home.openSearch(term)`; CategoryVideosLink → category page on Videos section; CollectionLink → first video of collection via TwitchVodService then open as VodLink(vodId, collectionId) (false if none); others false. `_openShellPlace(place)`: if `VideoChat.leaveForShell()` → popUntil first; then `Home.openPlace(place)`.

`_openTwitchLinkInApp(link)` (returns bool) builds a route: VodLink → VodScreen(vodId, startAt, collectionId); ChannelVideosLink(login, type) → ChannelVideosScreen(userLogin, displayName, initialTab: type ?? VodType.archive); ClipLink(slug) → ClipScreen; ChannelClipsLink(login, period) → ChannelVideosScreen(startOnClips: true, clipPeriod: period ?? ClipPeriod.lastWeek); ChannelProfileLink(login, section) → ChannelProfileScreen(initialTab: about/schedule); ChannelVideosLink and ChannelClipsLink first AWAIT `_displayNameOf(login)` (Helix getUser, login on failure) before building the route; all other link kinds return false. Then: if `navigatorKey.currentState == null` → return false (no push); else post-frame push and return true.

**`build`**: `Observer` → `OnsetThemes(colorSchemeSeed: Color(settingsStore.accentColor))` → `MaterialApp(title: 'ONSET', locale: settingsStore.appLanguage.locale, supportedLocales/localizationsDelegates from AppLocalizations, localeListResolutionCallback: resolveAppLocale(AppLanguage.system, device ?? []), theme: light, darkTheme: dark, themeMode: system/light/dark from ThemeType, navigatorObservers: [...Telemetry.navigatorObservers(), LaunchIntro.navigatorObserver (any page opening ends the intro), OnsetShell.routeObserver], home: firstRun ? OnboardingFlow() : Home(), navigatorKey)`.

**Builder stack** (outermost → innermost): `LocaleSync(onLocale: [rememberUiLanguage(onChanged: ScheduleReminders.shared?.reschedule()), (_) => BackgroundAudio.shared.setLabels(mediaLabelsOf(L10n.current))])` → `LaunchIntro(play: launchInfo.playsIntro, fromTile: launchInfo.nativeTile, holdOnName: firstRun, splashTile: LaunchInfo.splashTile, slotKey: OnsetShell.markKey)` → `Stack([child, Positioned.fill(GlobalMiniPlayer())])`. So the mini player floats above every route, and the intro covers everything on cold start.

**Deep links** `_initDeepLinks`: subscribe `uriLinkStream` → handleDeepLink; `getInitialLink()` with 3 s timeout (null on timeout) → handleDeepLink. Errors logged.

`handleDeepLink(uri)`: `LaunchIntro.skipAll()` first; `link = TwitchLink.parse(uri)`; if `link.opensInApp && await _openTwitchLinkInApp(link)` return; CategoryLink → `_openCategoryLink` (never treated as a channel named "directory"); `_openAppDestination` → return if handled. Otherwise failure snackbar (localised from the navigator context): `AlertMessage(message: l.deepLinkFailed(uri), centered: false, trailingIcon: Icons.open_in_browser_rounded, trailingTooltip: l.deepLinkOpenInBrowser, onTrailingIconPressed: launchUrl(TwitchLink.webUri(uri) ?? uri, mode: inAppWebView))`. Channel name = ChannelLink/ChannelChatLink login, or first path segment when the uri is already a twitch web uri; if found → Helix getUser → post-frame push `VideoChat(userId, userName: displayName, userLogin, startChatOnly: link is ChannelChatLink, offerFollow: link is ChannelLink && followRequested)` route name VideoChat.routeName; API failure → failure snackbar. No channel name → failure snackbar. `dispose` cancels the subscription.

Route names used: VideoChat.routeName, VodScreen.routeName, ChannelVideosScreen.routeName, ClipScreen.routeName, ChannelProfileScreen.routeName, CategoryStreams.routeName, settingsRouteName(page).

### lib/constants.dart

Build-time and shared constants.
- `clientId = String.fromEnvironment('CLIENT_ID')` — Twitch application client id (login app, no secret).
- `tokenProxyUrl = String.fromEnvironment('TOKEN_PROXY_URL')` — Cloudflare Worker (`tool/token_proxy/`) that mints logged-out app access tokens; must be https; empty → logged-out Helix features fail quietly, everything else (login included) works. The app carries NO client secret (guarded).
- `updateToken = String.fromEnvironment('UPDATE_TOKEN')` — read-only GitHub token for in-app updates while the repo is private; empty when public/local.
- `updateRepo = String.fromEnvironment('UPDATE_REPO')` — `owner/name` whose releases carry updates; empty → never checks.
- `onsetRepoUrl = 'https://github.com/JLmehdi92/onset'` — Settings › About "Source code" row (empty would hide it).
- `zeroWidthEmotes` (BTTV overlays): SoSnowy, IceCold, SantaHat, TopHat, ReinDeer, CandyCane, cvMask, cvHazmat.
- `regexEnglish = [a-zA-Z]`; `regexNumbersOnly = ^\d+$`.
- `regexLink` (case-insensitive): left boundary `(?<![A-Za-z0-9_.-])`, then either a URL — optional `www.`, one or more DNS labels `[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.`, TLD `[A-Za-z]{2,63}`, optional `:\d{1,5}` port, optional `/[^\s]*` path — or a bare file name `[A-Za-z0-9_-]+\.(exe|png|jpe?g|gif|bmp|webp|mp4|avi|zip|rar|pdf)`; right boundary `(?![A-Za-z0-9-])`.
- `kCardBorderRadius = BorderRadius.all(Radius.circular(OnsetTokens.radiusSmall /*8*/))` — thumbnails and box art (deliberately small radius, they sit on the background not in a card).
- `defaultBadgeSize = 18.0`; `defaultEmoteSize = 28.0`.
- `chatColorNames` (15): blue, blue_violet, cadet_blue, chocolate, coral, dodger_blue, firebrick, golden_rod, green, hot_pink, orange_red, red, sea_green, spring_green, yellow_green. `chatColorValues`: blue #0000FF, blue_violet #8A2BE2, cadet_blue #5F9EA0, chocolate #D2691E, coral #FF7F50, dodger_blue #1E90FF, firebrick #B22222, golden_rod #DAA520, green #008000, hot_pink #FF69B4, orange_red #FF4500, red #FF0000, sea_green #2E8B57, spring_green #00FF7F, yellow_green #9ACD32.
- `kTwitchWebClientId = 'kimne78kx3ncx6brgo4mv6wki5h1ko'` (public twitch.tv web client id, anonymous GQL and realtime); `kTwitchGqlUrl = 'https://gql.twitch.tv/gql'`; `kTwitchTvClientId = 'ue6666qo983tsx6so1t0vnawi233wa'` (Twitch TV app client id, device-code TV session).

### lib/theme.dart

The whole visual system, named "Noir & Signal" (2.0 additions kept alongside the 1.0 values, which keep their names and values). Imports `dart:io` (for `Platform.isIOS`), material, services.

**`kOverlayShadow`** (top-level const list): one `Shadow(offset: (0, 1), blurRadius: 4, color: rgba(0,0,0,0.3))`. Used for overlay controls and text drawn on top of video.

**Design rules encoded by `OnsetTokens`** (doc comment, binding for the rewrite): backgrounds are pure neutral; every surface sits at the same elevation; there is NO elevation scale; depth is expressed only with hairlines, never with tints or drop shadows. The accent means "live" and is used ONLY for: the live badge, the active navigation icon, the active tab underline, a selected check, an enabled toggle (plus filled primary buttons/selected segments, see below). Metadata stays neutral grey. Red is not chrome: it only survives for the follower-only chat mode and destructive actions.

**`OnsetTokens`** (private ctor, all `static const`):
- Neutrals: `backgroundDark` #0A0A0A, `surfaceDark` #141414, `backgroundLight` #F8F8F8, `surfaceLight` #FFFFFF.
- Hairline: `hairlineWidth` 0.5 logical px; `hairlineDark` 0x14FFFFFF (white at alpha 0x14 = 20/255 ≈ 7.8 %); `hairlineLight` 0x14000000 (black at 7.8 %).
- `accent` #C8FF3D (electric lime) — reserved for live state and active selection.
- Type families: `displayFamily`, `bodyFamily`, `monoFamily` all `'Inter'` (Inter chosen as the free face closest to Twitch's licensed Roobert; numbers use Inter with tabular figures, not a monospace font).
- `displayWeight(double weight)` → `FontWeight.values[((weight / 100).round() - 1).clamp(0, 8)]` (e.g. 650 → round(6.5)=7 → index 6 → w700; 600 → w600; 700 → w700). Note Dart `round()` rounds half away from zero.
- Shape: `radiusCard` 12, `radiusDialog` 16, `radiusSmall` 8, `radiusPill` 100 (text inputs), `radiusLarge` 24 (hero cards and sheets), `radiusBadge` 6 (the LIVE badge). The documented radius scale is 8 / 12 / 16 / 24 / pill.
- 2.0 greys: `raisedDark` #1E1E1E (third grey above surface: chips, pressed cards, secondary buttons); `skeletonDark` #232323 and `skeletonSheenDark` #2F2F2F (skeleton fill and sheen highlight on dark; deliberately lighter than an older #161616 which vanished on sheets/cards).
- Dark text tiers: `textPrimaryDark` #F5F5F5 (names, titles), `textBodyDark` #D6D6D6 (live titles, chat), `textSecondaryDark` #A1A1A1 (metadata — same as `OnsetColors.dark.metadata`), `textTertiaryDark` #8A8A8A (inactive tabs, fine print).
- `hairlineRaisedDark` 0x1FFFFFFF (white 12 %, hairlines on raised surfaces), `hairlineStrongDark` 0x29FFFFFF (white 16 %, secondary buttons).
- `accentTint` 0x1AC8FF3D (lime at 10 %: fill of a selected chip outlined in accent).
- `hype` #12A87A (subs, gifts, hype train only; never a generic OK). `hypeText` #3DDBA6 (green text on hype-tinted fill, e.g. Subscribe button). `hypeTextLight` #0A7957 (light-theme variant, 4.5:1 on a light hype tint: Subscribe, watch streak, hype train sheet).
- `danger` #FF5A5F (destructive actions only).

**`OnsetSpacing`** (abstract final): 4-pt grid plus 2-pt hairline step: `xxs` 2, `xs` 4, `sm` 8, `md` 12, `lg` 16, `xl` 24, `xxl` 32; `gutterPhone` 16, `gutterTablet` 28 (tablets keep a wider margin rather than stretching).

**`OnsetType`** (abstract final, all Inter, styles carry NO colour; they are merged onto the theme via copyWith/DefaultTextStyle.merge so both themes use them). `_tabular = FontFeature.tabularFigures()` ("tnum").
- `display`: 34 / w800 / letterSpacing −0.035×34 = −1.19 / height 1.05 (hero numbers, empty-state headlines).
- `screenTitle`: 24 / w700 / letterSpacing −0.48.
- `section`: 18 / w700 / letterSpacing −0.27 ("Continue watching").
- `channelName`: 16 / w600 / letterSpacing −0.16.
- `body`: 14 / w400 / letterSpacing 0 / height 1.5 (live titles, chat).
- `meta`: 13 / w400 / letterSpacing 0 / tabular figures (viewer counts, uptime, latency).
- `label`: 11 / w600 / letterSpacing 0.14×11 = 1.54 (uppercase labels; caller upper-cases the string).
- `badge`: 11 / w800 / letterSpacing 0.66 (LIVE badge).
- `wordmark`: 20 / w800 / letterSpacing −0.7 (ONSET wordmark in header).
- `tabular(style)`: returns style unchanged if it already has tnum, else appends tnum to existing fontFeatures.

**`OnsetColors extends ThemeExtension`** — semantic colours outside Material roles. Material roles used directly: links → `ColorScheme.primary`, mentions → `ColorScheme.error`, first-time chatters → `ColorScheme.tertiary`. Accessed via `Theme.of(context).extension<OnsetColors>()!` or `context.onsetColors`. Fields (13): highlightedMessage, emoteOnly, followersOnly, slowMode, subOnly, uniqueMode, overlayOnSurface, live, metadata, hairline, subNoticeAccent, subNoticeBackground, subNoticeText.
- `light`: highlightedMessage #B15CFF (was Twitch #9146FF, moved to a colder violet), emoteOnly #E59A2E, followersOnly #D9534F, slowMode #2C7BE5, subOnly #2E9E5B, uniqueMode #9B4DCA, overlayOnSurface white, live #6B9E00 (lime darkened for white ground, rather than red), metadata #6B6B6B, hairline 0x14000000, subNoticeAccent #6B8A00 (lime darkened until a 4 dp bar shows on white), subNoticeBackground #EDEFE4 (accent at 8 % over light background), subNoticeText #4F6600 (5.6:1 on the tint).
- `dark`: highlightedMessage #B15CFF, emoteOnly #FFCC80, followersOnly #E57373, slowMode #64B5F6, subOnly #81C784, uniqueMode #BA68C8, overlayOnSurface white, live #C8FF3D, metadata #A1A1A1, hairline 0x14FFFFFF, subNoticeAccent #C8FF3D, subNoticeBackground #171B0E (accent at 7 % over dark bg), subNoticeText #C8FF3D.
- Sub/gift notices are lime (Twitch uses purple); green stays with the hype train.
- `copyWith` (all optional), `lerp` (each field `Color.lerp`, returns `this` if other is not OnsetColors).

**`OnsetTextStyles extends ThemeExtension`**: `metadata` and `label`. `_mono = TextStyle(fontFamily: Inter, fontFeatures: [tnum])`. `resolve(metadataColor)`: metadata = mono, 13, colour; label = mono, 11, letterSpacing 1.2, colour. copyWith, lerp (TextStyle.lerp), `==` and hashCode on both fields.

**`OnsetThemes({required colorSchemeSeed})`**: static caches `_light`/`_dark` maps keyed by `seed.toARGB32()` so a theme is built once per seed. `light` = `createBaseTheme(ColorScheme.fromSeed(seed), background #F8F8F8, surface #FFFFFF)`; `dark` = `ColorScheme.fromSeed(seed, brightness: dark)`, background #0A0A0A, surface #141414.

`createBaseTheme({colorScheme, backgroundColor?, surfaceColor?})`: isDark from scheme brightness; onsetColors = dark/light; borderColor = onsetColors.hairline; borderWidth 0.5; surface = surfaceColor ?? scheme.surface. Then ThemeData with:
- `extensions`: [onsetColors, OnsetTextStyles.resolve(onsetColors.metadata)]; `fontFamily` Inter; `splashFactory` NoSplash on iOS, else null → Flutter 3.38 default for Material 3: `InkSparkle` on Android (non-web), `InkRipple` on Windows/macOS/Linux (the PC port uses InkRipple); `scaffoldBackgroundColor` = background.
- `cardTheme`: elevation 0, colour = surface, surfaceTint = surface, RoundedRectangle radius 12, side hairline.
- `bottomSheetTheme`: showDragHandle true, elevation 0, background & tint = background.
- `menuTheme`: background/tint surface, elevation 0, padding vertical 4, shape radius 12 + hairline side. `menuButtonTheme`: visualDensity compact.
- `dialogTheme`: elevation 0, background/tint = background, radius 16 + hairline.
- `appBarTheme`: elevation 0, scrolledUnderElevation 0, background/tint = background, `centerTitle: false` (left titles everywhere), `titleSpacing: 0`, `systemOverlayStyle`: status bar transparent, status icons light on dark / dark on light, statusBarBrightness inverse (iOS), nav bar colour = background, nav divider transparent, nav icons light on dark / dark on light. Declared once here on purpose: a screen-local style replaces the object wholesale and would drop the nav bar colour.
- `listTileTheme`: visualDensity compact, minVerticalPadding 10.
- `elevatedButtonTheme`: elevation 0, bg surface, fg onSurface, tint surface, shadow transparent, hairline side.
- `filledButtonTheme`: elevation 0, background = onsetColors.live (#C8FF3D dark, #6B9E00 light; NOT ColorScheme.primary which desaturated to #BDCE8B), foreground #0A0A0A on dark / white on light, disabled background onSurface @ 12 % alpha, shadow transparent.
- `segmentedButtonTheme`: elevation 0, background live when selected else surface, foreground #0A0A0A/white when selected else onSurface, hairline side, radius 8.
- `expansionTileTheme`: transparent backgrounds, `Border()` shapes (no dividers when expanded).
- `switchTheme`: thumb #0A0A0A/white when selected (else default), track = live when selected, track outline transparent when selected.
- `sliderTheme`: active track & thumb = onSurface, inactive track onSurface @ 16 %.
- `checkboxTheme`: fill live when selected; check colour #0A0A0A/white. `radioTheme`: fill live when selected.
- `progressIndicatorTheme`: colour live.
- `chipTheme`: background & selected colour surface, showCheckmark false, side = 1 px live outline when selected else hairline, radius 8.
- `inputDecorationTheme`: contentPadding h16 v8, filled with surface, hint colour onSurfaceVariant normal weight; border/enabled/disabled = pill (radius 100) hairline; focused = pill with onSurface @ 40 % (default 1 px width).
- `navigationBarTheme`: elevation 0, bg/tint background, height 64, labels always hidden, indicator transparent CircleBorder, overlay transparent.
- `tabBarTheme`: divider transparent, alignment start, indicator live, indicator size label, label onSurface, unselected label metadata.
- `tooltipTheme`: padding h12 v8, showDuration 2 s, decoration surface + radius 12 + hairline border, text Inter onSurface.
- `snackBarTheme`: showCloseIcon true, elevation 0, bg background, hairline side + radius 12, floating behaviour.
- `dividerTheme`: thickness 0.5, space 0.5, hairline colour.
- `textTheme`: headlineSmall (alert dialog title) Inter displayWeight(650)=w700, 18, ls −0.019; titleLarge (app bar) w700 24 ls −0.4; titleMedium (section titles) w600 ls −0.011 (default size); titleSmall (tab bar) w600 16 ls −0.011; labelLarge w500 ls −0.006; labelMedium w500 ls 0; labelSmall w500 ls 0.005; bodyLarge w500 ls −0.011; bodyMedium ls −0.006; bodySmall ls 0. Unspecified sizes take Material 3 defaults (titleMedium 16, labelLarge 14, labelMedium 12, labelSmall 11, bodyLarge 16, bodyMedium 14, bodySmall 12).
- `_pill(side)`: OutlineInputBorder radius 100.

The seed colour is the user's chosen accent (`SettingsStore.accentColor`, default lime) — Material derives primary/secondary/tertiary/error from it, but chrome selection colours are pinned to `onsetColors.live`, not the seed.

### lib/utils/common_utils.dart

WCAG contrast helpers and small device helpers.
- `_linearize(c)`: `c <= 0.03928 ? c/12.92 : ((c+0.055)/1.055)^2.4` (sRGB channel in 0..1).
- `_relativeLuminance(color)` = 0.2126 R + 0.7152 G + 0.0722 B (linearised).
- `_contrastRatio(a, b)` = (Lhi + 0.05) / (Llo + 0.05).
- `adjustChatNameColor(context, color, {background, targetContrast = 4.5})`: background = given, else `theme.scaffoldBackgroundColor`; if that has alpha 0, `colorScheme.surface`. If the colour already meets the target, return it unchanged. Otherwise convert to HSL; `darkBg = luminance(bg) < 0.5`. Binary search lightness, 16 iterations: dark bg searches [hsl.lightness, 1.0], light bg [0.0, hsl.lightness]. For each mid: `t = |mid − 0.5| × 2`; saturation eased to `sat × (1 − 0.25 t²)` clamped 0..1; candidate passes → record bestL and move toward the original (dark: hi = mid; light: lo = mid), else move away (dark: lo = mid; light: hi = mid). Returns HSL(bestL, eased saturation). Callers use 4.5 for normal text, 3.0 for large/bold labels. Used to keep chat user-name colours readable on both themes.
- `getReadableName(displayName, username)`: returns displayName if equal to username, if it is all digits (`regexNumbersOnly`), or if it contains any English letter (`regexEnglish`); otherwise `'$displayName ($username)'` (e.g. CJK display names get the login in parentheses).
- `_isIPad` flag, `isIPad()`; `initUtils()` sets it on iOS when `DeviceInfoPlugin().iosInfo.model` lower-cased contains "ipad". Called at startup in parallel with prefs.

### lib/utils/content_labels.dart

Twitch content classification labels (Helix `content_classification_labels`).
- `_knownName(id, l)`: DrugsIntoxication → `contentLabelDrugs`, SexualThemes → `contentLabelSexualThemes`, ViolentGraphic → `contentLabelViolentGraphic`, Gambling → `contentLabelGambling`, ProfanityVulgarity → `contentLabelProfanity`, MatureGame → `contentLabelMatureGame`, DebatedSocialIssuesAndPolitics → `contentLabelPolitics`, else null.
- `knownContentLabelIds`: the seven ids above, in that stable order.
- `contentLabelName(id, l)`: known name, else CamelCase spaced out with regex `(?<=[a-z0-9])(?=[A-Z])` → ' ' and trimmed ("SomeNewLabel" → "Some New Label"); returns the id if spacing yields empty. Unknown ids are still shown so new labels still warn.
- `contentLabelIds(ids)`: trims, drops empty, de-duplicates (first occurrence wins), keeps order, stops at 8 (a hostile channel cannot flood the card).
- `contentLabelNames(ids, l)` = names of `contentLabelIds(ids)`.
Strings EN/FR: Drugs, intoxication, or excessive tobacco use / Drogues, intoxication ou consommation excessive de tabac; Sexual themes / Thèmes sexuels; Violent and graphic depictions / Représentations violentes et explicites; Gambling / Jeux d’argent; Significant profanity or vulgarity / Grossièretés ou vulgarité marquées; Mature-rated game / Jeu classé pour adultes; Politics and sensitive social issues / Politique et questions sociales sensibles.

### lib/utils/context_extensions.dart

Layout thresholds and BuildContext helpers.
- **`kLargeScreenShortestSide = 600.0`** dp — Android large-screen threshold / Material medium window class. `isLargeScreenSize(size) = size.shortestSide >= 600`.
- `LargeScreenScope({required bool large, child})` InheritedWidget: forces a subtree to large/phone layouts regardless of window (e.g. Browse's category pane narrower than 600 inside a tablet layout is still "tablet"). `maybeOf(context)` → bool? (dependOn). `updateShouldNotify` when `large` changes.
- `extension ContextExtensions on BuildContext`: `theme`, `colorScheme`, `textTheme`, `scaffoldColor`; `onsetColors` → theme extension or fallback `OnsetColors.dark/light` by brightness (never crashes in a bare MaterialApp/test); `onsetText` → extension or `OnsetTextStyles.resolve(onsetColors.metadata)`; `defaultTextStyle`; `screenWidth`/`screenHeight` (MediaQuery.sizeOf); **`isLargeScreen` = `LargeScreenScope.maybeOf ?? isLargeScreenSize(MediaQuery.sizeOf)`** (both sides ≥ 600; a split-screen half narrower keeps phone layouts); `safePaddingTop`; provider readers (`read`, no rebuild): twitchApi, authStore, settingsStore, ffzApi, bttvApi, sevenTVApi, twitchVodService, twitchClipService, twitchChannelProfileService, twitchCommunityHighlightsService, twitchHypeTrainService, realtimeClient, globalAssetsStore, miniPlayerStore; `isPortrait`, `isLandscape` (MediaQuery.orientationOf).
- `extension TextScalerExtensions on double`: `textScaler` → `TextScaler.linear(this)`.
- `extension ThemeSystemOverlay on ThemeData`: `systemOverlayStyle` → `appBarTheme.systemOverlayStyle ?? (dark ? SystemUiOverlayStyle.light : .dark)`.

### lib/utils/https_url.dart

`kTwitchImageHost = 'static-cdn.jtvnw.net'`. `twitchImageOrNull(url)`: returns url only if it parses, scheme is exactly `https`, host is exactly `static-cdn.jtvnw.net`, and there is no userInfo; else null (caller falls back to the channel's initial). Used for raid pictures named in Twitch payloads: nothing else is ever loaded for them.

### lib/utils/image_size.dart

`imagePixelWidth(logicalWidth, pixelRatio, {step = 160, max = 1920})`: non-finite or ≤ 0 width → `step`; else `ceil(logicalWidth × pixelRatio / step) × step`, clamped to [step, max]. Rounding to multiples of 160 keeps small layout changes hitting the image cache; 1920 is Twitch's largest preview size. E.g. 100 dp × 3.0 = 300 px → 320.

### lib/utils/irc_privmsg_builder.dart

Builds a synthetic IRC PRIVMSG for messages read elsewhere (VOD chat replay, pinned messages) so they go through the SAME chat render pipeline as live chat (badges, colours, Twitch emotes from the `emotes` tag, 7TV/BTTV/FFZ word lookup, mentions). It builds a raw line and parses it with the unchanged `IRCMessage.fromString`.

Regexes: `_twitchLogin ^[a-zA-Z0-9_]{1,25}$`; `_lineBreaks [\r\n]`; `_hexColor ^#[0-9A-Fa-f]{6}$`; `_badgePart ^[A-Za-z0-9_-]{1,64}$`; `_tagBreakers [;=\\\r\n]`; `_tagSafe ^[A-Za-z0-9_]+$`; `_controls [\x00-\x08\x0B\x0C\x0E-\x1F\x7F]` (control chars except line breaks; `\x01` would turn a line into /me); `_gifBreakers [,|\s]`.

`privmsgExtraTags` (the only caller-settable tags): historical, bits, source-room-id, reply-parent-msg-id, reply-parent-msg-body, reply-parent-user-id, reply-parent-user-login, reply-parent-display-name, reply-thread-parent-msg-id, reply-thread-parent-user-login, reply-thread-parent-display-name. Anything else (sender identity, roles, message kind) cannot be injected.

`buildPrivmsgIrcMessage({fragments: List<(text, emoteId?)>, login?, displayName?, id, channelId, channelLogin, sentAt, userId?, color?, badges = [], viewerLogin?, extraTags = {}, gifs: Map<int,(id,url)> = {}, action = false})`:
- For each fragment (indexed): text with line breaks → space and control chars removed; `length` = code points (runes). If emoteId non-null, part non-empty, emoteId tag-safe: record range `start-(start+part.length-1)` where start/length are UTF-16 code units (matching the parser's substring calls). If `gifs[index]` exists and fewer than `GifMessagePart.maxGifs` (5) entries so far, length > 0, id non-empty, neither id nor url contain `,`/`|`/whitespace, url has no control chars, and `ChatGif(start: characters, end: characters+length−1, id, url).isLoadable` → add `"<cpStart>-<cpEnd>|<id>|<url>"` (positions counted in code points, as Twitch counts characters). Append part; advance character count.
- Sender: `known = login matches _twitchLogin`; sender = login lower-cased, else `kDeletedUserLogin` ('deleted_user'); shown name = displayName with tag breakers removed and trimmed; name = known ? (shown or sender) : `kDeletedUserDisplayName` ('Deleted user').
- Badges kept only if both setId and version match `_badgePart`.
- Tags map (in insertion order): badges `set/version,...`; color only if valid #RRGGBB; display-name (tag-escaped); emotes `id:a-b,c-d/id2:...`; id; `mod=1` if any badge setId == 'moderator' (as live IRC does); room-id; tmi-sent-ts = sentAt millis; user-id only if known and userId given; gifs (IRCv3-escaped joined with ','); extra tags filtered by privmsgExtraTags (tag-escaped). Empty values dropped; serialized `k=v` joined by ';'.
- Channel = channelLogin lower-cased if valid login, else literal 'channel'.
- Body = action ? `\x01ACTION <text>\x01` : text (CTCP wrapper added after cleaning so positions count from after it).
- Line: `@<tags> :<sender>!<sender>@<sender>.tmi.twitch.tv PRIVMSG #<channel> :<body>` parsed with `userLogin: viewerLogin` (for mention detection).
- `_tagValue(v)`: drop `;`, `=`, `\`, CR, LF; spaces → `\s`. `_escapeTag(v)` (IRCv3, read back by `UserNotice.unescapeTag`, keeps every char): `\` → `\\`, `;` → `\:`, space → `\s`. `_validColor` → color or null.

### lib/utils/link_router.dart

`typedef UrlLauncher = Future<bool> Function(Uri, {LaunchMode mode})`. `isTwitchHost(uri)`: host lower-cased is `twitch.tv` or ends with `.twitch.tv`.

`abstract final class LinkRouter` (static state): `inAppHandler` (set by MyApp to `_openTwitchLinkInApp`; returns whether handled), `launcher` (visibleForTesting, default `launchUrl`), `externalLinkGate` (set by MyApp to the external-link confirmation dialog).

`open(text, {required launchExternal, confirm = false})`: parse `TwitchLink.parseText(text)`; if `opensInApp` and handler handles it → done. Otherwise `Uri.tryParse(text)`; a link without scheme (chat "youtube.com/…") becomes `https://<text>`; only http/https proceed (anything else silently ignored). If `confirm` and the host is not Twitch and a gate exists and the gate returns false → stop. Launch with `LaunchMode.externalApplication` if launchExternal else `LaunchMode.inAppBrowserView` (Custom Tab / SFSafariViewController). Twitch hosts never ask for confirmation.

### lib/utils/modal_bottom_sheet.dart

`showModalBottomSheetWithProperFocus<T>({context, builder, isScrollControlled = false, useRootNavigator = false, isDismissible = true, enableDrag = true, backgroundColor, elevation, shape, clipBehavior, constraints, barrierColor, barrierLabel, transitionAnimationController, anchorPoint, showDragHandle})`:
- Reads `SheetsUnderVideo.of(context)` (video bottom edge or null) BEFORE unfocusing; `FocusScope.of(context).unfocus()` clears focus history so the text field (chat input) is not auto-refocused after the sheet closes.
- No video edge → plain `showModalBottomSheet` with all params.
- With a video edge → pushes `_UnderVideoSheetRoute` on the (root) navigator: builder wrapped in `SheetsUnderVideo(top: videoBottom)` (nested sheets also start under the video) and `_UnderVideo`; captured themes from context to navigator; barrierLabel default `localizations.scrimLabel`; barrierOnTapHint `scrimOnTapHint(bottomSheetLabel)`; modalBarrierColor = barrierColor ?? theme.bottomSheetTheme.modalBarrierColor.
- On completion, if context still mounted, unfocus `FocusManager.instance.primaryFocus` again.

`SheetsUnderVideo({required double? top, child})` InheritedWidget: the video's bottom edge from screen top (null: normal sheets — no video, landscape, tablet). `gap = 12.0` dp between video and sheet top. `of(context)` uses `getInheritedWidgetOfExactType` (no dependency: read once when a sheet opens). updateShouldNotify on top change.

`_UnderVideo.applies(context, videoBottom)`: portrait (height > width) AND videoBottom ≤ 60 % of height — evaluated live, so rotating while open stops reserving room. Build: if applies, `ConstrainedBox(maxHeight: max(0, screenHeight − videoBottom − 12 + viewInsets.bottom))` (a keyboard lets the sheet grow by its height, partly covering video while typing).

`_UnderVideoSheetRoute extends ModalBottomSheetRoute`: overrides `buildModalBarrier` → Stack of a full-screen transparent `ModalBarrier(dismissible: barrierDismissible, barrierSemanticsDismissible: false)` (tap on the video still closes) plus the real scrim positioned from `top: applies ? videoBottom : 0` to bottom. Result: the live picture is never dimmed or blurred under a sheet on the phone channel screen, so latency stays visible.

### lib/utils/pip_callbacks.dart

`reclaimPipCallbacks(GlobalKey<PipWidgetState> key)`: simple_pip_mode keeps ONE platform handler (the last PipWidget created gets all PiP events). When a player screen is back on top, re-point events to its PipWidget: `SimplePip(onPipEntered, onPipExited, onPipAction from state).setPipActionsLayout(state.widget.pipLayout)` (unawaited); no-op if state null.

### lib/utils/punycode.dart

RFC 3492 Punycode encoder (used to show/compare IDN hosts in the external link dialog). Constants: base 36, tMin 1, tMax 26, skew 38, damp 700, initialBias 72, initialN 128.
- `asciiHost(host)`: percent-decode the host (`Uri.decodeComponent`, on ArgumentError/FormatException keep raw), split on '.', labels that are all ASCII (< 0x80) kept as-is, others become `xn--` + `punycodeEncode(label.toLowerCase())`; rejoin with '.'.
- `punycodeEncode(input)`: standard algorithm — copy basic code points, add '-' if any, then generalized variable-length integers with thresholds `t = k ≤ bias ? 1 : k ≥ bias+26 ? 26 : k − bias`, digits `v < 26 ? 'a'+v : '0'+(v−26)` (`v+97` / `v+22`), bias adaptation `_adapt(delta, points, first)`: delta /700 on first else /2; += delta/points; while > ((36−1)×26)/2=455 divide by 35 and k += 36; return k + 36×delta/(delta+38). E.g. "bücher" → "bcher-kva", "münchen.de" → "xn--mnchen-3ya.de".

### lib/utils/settings_lookup.dart

`maybeSettings(context)` → `Provider.of<SettingsStore>(listen: false)` or null on `ProviderNotFoundException` (widgets usable without the store, e.g. in tests). `viewerCountsHidden(context)` = settings.hideViewerCount ?? false. `featuredClipsOnly(context)` = settings.clipDiscovery == ClipDiscovery.featured.

### lib/utils/share_link.dart

`_sharing` module flag: while a share sheet is open a second tap is ignored (Android answers the FIRST, still-open request "unavailable" when a second share opens, which would trigger the clipboard fallback and also copy). `shareLink(context, url, {subject, @visibleForTesting SharePlus? sharer})`: guards with `_sharing` (reset in finally). `_share`: compute the origin rect from the context's RenderBox (`localToGlobal(Offset.zero) & size`, needed as anchor on iPad); `SharePlus.share(ShareParams(text: url, subject, sharePositionOrigin))`; if status is not `unavailable` → done. On `unavailable` or any exception (logged "Share failed"): `Clipboard.setData(url)` and, if mounted, SnackBar `vodLinkCopied` ("Link copied" / "Lien copié").

### lib/utils/stream_languages.dart

Language filter for live lists (Helix `language`, ISO 639-1) with endonyms (same in every UI language): en English, fr Français, es Español, de Deutsch, pt Português, it Italiano, ru Русский, ja 日本語, ko 한국어, zh 中文, ar العربية, tr Türkçe, pl Polski, nl Nederlands, sv Svenska. `kStreamLanguageCodes` (unmodifiable) = ['' (all), those 15 in that order, 'other']. `streamLanguageName(code, l)`: '' → `streamLanguageAll` ("All languages" / "Toutes les langues"), 'other' → `streamLanguageOther` ("Other" / "Autre"), else endonym or the code. `streamLanguageOrAll(code)` → code if known else ''.

### lib/utils/twitch_report.dart

`_login ^[a-zA-Z0-9_]{1,25}$`. `twitchReportUri(login)` → `https://www.twitch.tv/<login lower>/report` or null if invalid. `twitchModViewUri(login)` → `https://www.twitch.tv/moderator/<login lower>` or null. Invalid logins never build a URL.

### lib/utils/twitch_links.dart

Parser of twitch.tv links (chat, deep links, notifications) into a sealed `TwitchLink` hierarchy. Never throws.

**`opensInApp`**: true for VodLink, ChannelVideosLink, ClipLink, ChannelClipsLink, ChannelProfileLink (videos, clips and profile pages always open in-app, never in a browser); false for ChannelLink, CategoryLink, CategoryVideosLink, ChannelChatLink, CollectionLink, SearchLink, BrowseLink, FollowingLink, ActivityLink, OtherLink (categories open in-app only from a deep link via the app handler; tapped in chat they keep the browser).

**`parseText(text)`**: trim, strip trailing punctuation matching `[.,!?)\]]+$`, prefix `https://` if no `://`, `Uri.tryParse` → parse or OtherLink.

**`parse(uri)`**: `_parse` wrapped; FormatException (malformed escapes) → OtherLink.

**`webUri(uri)`**: http/https → uri itself; `twitch://` or `ttv://` app links → `_appToWeb`; else null; FormatException → null.

**`_appToWeb(uri)`** (host = app "verb", non-empty path segments, query): stream/channel/profile → `https://www.twitch.tv/<segments>` (null if none); open → `?stream=` or `?channel=` login → `/<login>`, else `/directory/following`; following → `/directory/following`; directory → `/directory/<segments>`; game → `/directory/game/<segments>` (null if none); search → `/search` with `term` from `term` or `query` param (omitted if empty); video → `/videos/<segments>` with `t` kept if present (null if no segments); activity → `/activity`; others null. Built with `Uri(scheme https, host www.twitch.tv, pathSegments, queryParameters null when empty)`.

**`_parse(uri)`**:
1. twitch/ttv → convert to web then parse (or OtherLink).
2. scheme must be http/https.
3. host `clips.twitch.tv` → `_clipsHost`: exactly one segment; `embed` → clip from `?clip=`; `create` → OtherLink; else that slug.
4. host must be one of twitch.tv, www.twitch.tv, m.twitch.tv, go.twitch.tv (case-insensitive) else OtherLink.
5. empty-filtered path segments; none → OtherLink. `first` = first segment lower-cased.
6. `/videos/<id>` or `/v/<id>` (2 segments) → `_vod`.
7. `/clip/<slug>` (2 segments, mobile web) → `_clip`.
8. `/directory...` → `_directory`.
9. single segment: following → FollowingLink; activity → ActivityLink; search → SearchLink(_searchTerm(?term)).
10. `/collections/<id>` with id matching `^[A-Za-z0-9_-]{1,64}$` → CollectionLink, else OtherLink.
11. first in `_reserved` or not matching `_login ^[a-z0-9_]{1,25}$` → OtherLink. Reserved: videos, v, directory, settings, search, p, downloads, jobs, turbo, subscriptions, wallet, inventory, drops, friends, messages, following, login, signup, prime, store, clips, clip, popout, moderator, broadcast, team, u, embed, products, activity, collections.
12. `/<ch>/v/<id>` or `/<ch>/video/<id>` (legacy, 3 segments) → `_vod`.
13. `/<ch>/clip/<slug>` → `_clip`.
14. `/<ch>/clips` → ChannelClipsLink(first, period: `_ranges[?range]`) with ranges 24hr → lastDay, 7d → lastWeek, 30d → lastMonth, all → allTime.
15. `/<ch>/videos[/<filter>]` or `?filter=`: filter `clips` → ChannelClipsLink (old clips tab, same range mapping); else ChannelVideosLink(first, type: `_types[filter]`) with archive/archives → archive, highlight/highlights → highlight, upload/uploads → upload, unknown → null type.
16. `/<ch>/about` or `/<ch>/schedule` (case-insensitive) → ChannelProfileLink(first, section).
17. `/<ch>/chat` (case-insensitive) → ChannelChatLink.
Case rules: the first segment is lower-cased (logins, `videos`/`v`/`clip`/`directory`/`collections` and reserved words match any case); `segments[1]` comparisons for `v`, `video`, `clip`, `clips`, `videos`, the `segments[2]` / `?filter=` value, `?range=` and `followChannel=true` are CASE-SENSITIVE; `about`, `schedule`, `chat` ignore case; directory `following` / `videos` ignore case. Examples: `/foo/Videos` → OtherLink, `/foo/Chat` → ChannelChatLink, `/foo/About` → ChannelProfileLink.
18. `/<ch>` → ChannelLink(first, followRequested: `?followChannel=true`).
19. else OtherLink.
Logins are lower-cased (first segment). Clip slugs are case-sensitive and kept as written.

`_directory(segments)`: `/directory` → BrowseLink; `/directory/following` → FollowingLink; fewer than 3 → OtherLink; `_category(kind, value)`: kind `category` with slug `^[a-z0-9]+(?:-[a-z0-9]+)*$` (case-insensitive) → CategoryLink(slug: lower-cased); kind `game` with trimmed name non-empty, ≤ 100 chars, not `.`/`..`, no `/`, `\`, or control chars → CategoryLink(name). 3 segments → category; 4th segment `videos` → CategoryVideosLink(category); else OtherLink.
`_searchTerm(raw)`: control chars → space, trimmed, cut to 100 chars.
`_clip(slug)`: `isValidClipSlug` (`^[A-Za-z0-9][A-Za-z0-9_-]{0,99}$`) → ClipLink else OtherLink.
`_vod(id, uri)`: id must be `^[0-9]{1,20}$`; `startAt = parseTwitchTimestamp(?t)` (accepts plain seconds up to 7 digits capped at 999 h, or `XhYmZs` with h ≤ 3 digits, m ≤ 4, s ≤ 6); `collectionId` from `?collection=` if valid.

**Link classes** (all `final`, with value `==`/hashCode/toString): `VodLink(vodId, {startAt, collectionId})`, `ClipLink(slug)`, `ChannelClipsLink(login, {period})`, `ChannelVideosLink(login, {type})`, `enum ProfileSection {about, schedule}`, `ChannelProfileLink(login, section)`, `ChannelLink(login, {followRequested = false})`, `CategoryLink({slug, name})` (exactly one non-null, asserted), `OtherLink`, `CategoryVideosLink(category)`, `ChannelChatLink(login)`, `CollectionLink(collectionId)`, `SearchLink(term)`, `BrowseLink`, `FollowingLink`, `ActivityLink`.

**`twitchCategoryUrl(link)`** → `https://www.twitch.tv/directory/category/<slug>` or `/directory/game/<name>` as one encoded path segment (never read as a path).

**`twitchCategorySlug(name)`**: lower-case; map accented chars: a ← àáâãäåāăą, c ← çćčĉ, d ← ďđ, e ← èéêëēėęě, g ← ğ, i ← ìíîïīı, l ← łľ, n ← ñńň, o ← òóôõöøō, r ← ř, s ← śšş, t ← ťţ, u ← ùúûüūů, y ← ýÿ, z ← źžż, ss ← ß, ae ← æ, oe ← œ; remove `'` and `’`; runs of `[^a-z0-9]+` → `-`; trim leading/trailing dashes ("Tom Clancy's Rainbow Six Siege" → `tom-clancys-rainbow-six-siege`).

**`twitchSubscribeUrl(login)`** → `https://www.twitch.tv/subs/<login lower>` if login matches `^[a-z0-9_]{1,25}$` after lower-casing, else null (subscription/gift happens on the web page; Twitch's in-app purchase uses Google Play billing in its own app).

### lib/widgets/motion/haptics.dart

`abstract final class Haptics` — the only haptic moments (Android guidance: less is more, never a buzz, nothing on scroll); fired at the same instant as the visual they accompany.
- `selection()` → `HapticFeedback.selectionClick()` — a tab, a chip, a segmented choice.
- `light()` → `HapticFeedback.lightImpact()` — follow, send a chat message, open the emote picker.
- `medium()` → `HapticFeedback.mediumImpact()` — subscribe, gift, a hype train level (the moments that also get the green burst).
PC: map to no-op by default (desktop has no haptics) but keep the call sites as a `Haptics` trait so a gamepad rumble/Windows haptic touchpad can be plugged in.

### lib/widgets/motion/motion.dart

`abstract final class OnsetMotion` — the motion tokens of Noir & Signal 2.0. Grammar: anything the finger moves or that moves in space uses a spring (interruptible, resumes from current position/velocity); entering things decelerate (`emphasizedDecelerate`), leaving things accelerate (`emphasizedAccelerate`) and are shorter (`exit` < `enter`); what enters from the right leaves by the right; under reduce motion everything becomes a short cross-fade (`reducedFade`): no travel, no overshoot, no stagger.
- `springStandard = SpringDescription.withDurationAndBounce(duration: 350 ms)` (bounce 0 → critically damped). Flutter 3.38.4 formula: mass 1, stiffness = 4π²·m / d² = 39.478 / 0.1225 = **322.27**, dampingRatio = 1/(bounce+1) = 1 → damping = 2·√(k·m) = **35.90**. Used for menus, tabs, things appearing.
- `springMomentum = withDurationAndBounce(duration: 400 ms, bounce: 0.2)`: stiffness = 39.478 / 0.16 = **246.74**, dampingRatio = 1 − 0.2 = 0.8 → damping = 0.8·2·√246.74 = **25.13**. After a swipe and a press release; carries gesture velocity.
- `emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1)` (entering).
- `emphasizedAccelerate = Cubic(0.3, 0, 0.8, 0.15)` (leaving).
- `standard = Cubic(0.2, 0, 0, 1)` (everything else that is not a spring: indicators, rings, rolls).
- `overshoot = Cubic(0.3, 1.5, 0.5, 1)` (launch tile settling: passes its size then lands).
- `pressScale = 0.97`; `pressDuration = 100 ms`.
- `enter = 350 ms`; `exit = 250 ms`.
- `reducedFade = 150 ms`.
- `staggerStep = 40 ms` (list rows); `launchStaggerStep = 60 ms` (home cards after the launch intro).
- `staggerCap = 8` (delay = step × min(index, 8): every row with 0-based index ≥ 8 (the 9th row onward) starts at 8 × step, the same moment as index 8, so a list settles within a few hundred ms: max delay 8×40 = 320 ms + 350 = 670 ms; launch 8×60 = 480 + 350 = 830 ms).
Cubic(a,b,c,d) is the CSS cubic-bezier with control points (a,b), (c,d).

### lib/widgets/motion/press_scale.dart

`PressScale({child, scale = 0.97, enabled = true})` — sinks a tappable card the moment a finger touches it and springs it back on release.
- Uses a raw `Listener` (onPointerDown/Move/Up/Cancel), never enters the gesture arena, so the wrapped InkWell/GestureDetector taps, long-presses and scrolling behave exactly as before.
- Controller: `AnimationController.unbounded(value: 1)` (unbounded so the release spring may overshoot 1 by a hair), drives a `ScaleTransition` (scale around centre).
- `_onDown`: ignored if a pointer is already tracked, if disabled, or under reduce motion. Records pointer id and position; `animateTo(scale, duration: 100 ms, curve: standard Cubic(0.2,0,0,1))`.
- `_onMove`: same pointer and moved more than `kTouchSlop` (18 logical px in Flutter) from the down position → release (a finger that starts scrolling lets go of the press).
- `_onUp`/cancel for the tracked pointer → release.
- `_release`: clear pointer; `animateWith(SpringSimulation(springMomentum, current value, target 1, current velocity))` — starts from wherever the press got to, so a quick tap never jumps.
- `didUpdateWidget`: becoming disabled while pressed → release.
- Reduce motion: nothing moves. Only one pointer at a time.
PC: on mouse press (left button) sink, on release/leave-with-drag spring back; keyboard activation (Space/Enter) may do the same press-release.

### lib/widgets/motion/reduce_motion.dart

`reduceMotionOf(context)`: true if `MediaQuery.maybeDisableAnimationsOf(context)` (Android "Remove animations") OR `View.maybeOf(context)?.platformDispatcher.accessibilityFeatures.reduceMotion` (iOS "Reduce Motion", which does not reach disableAnimations). Under reduce motion: every animation becomes a 150 ms cross-fade, no travel, no overshoot, no stagger, no looping shimmer or ping, and NO launch intro.
`motionDuration(context, normal)` → `reducedFade` (150 ms) when reduced, else `normal`.
PC: read Windows `SPI_GETCLIENTAREAANIMATION` (Settings › Accessibility › Visual effects › Animation effects off ⇒ reduce), macOS `NSWorkspace.accessibilityDisplayShouldReduceMotion`, GNOME `org.gnome.desktop.interface enable-animations`; re-evaluate on change.

### lib/widgets/motion/rolling_number.dart

`RollingNumber(text, {style, duration = 450 ms})` — a formatted number ("12 418", "1,000", "12.4K") whose changed places roll instead of jumping (viewer counts, channel points, hype train level).
- Controller (duration, initial value 1) + `CurvedAnimation(curve: OnsetMotion.standard)`.
- `didUpdateWidget`: updates duration; if text changed: `_from = old text`, `_up = rollsUp(old, new)`; reduce motion → value = 1 (instant), else `forward(from: 0)`.
- Build: style = `OnsetType.tabular(DefaultTextStyle.merge(style))` (tabular figures so width does not dance). Wrapped in `Semantics(label: text, excludeSemantics: true)` (screen readers get the whole number once). AnimatedBuilder: `now` = chars of new text; while animating `before` = chars of `_from` else `now`; both right-aligned to `length = max(len)`; `at(chars, i)` returns '' for positions before the string start. Row(min): for each position where the new char is non-empty: if rolling and old char differs → `_RollingPlace`, else plain `Text(char, softWrap: false)`. Places that vanish (new number shorter) are simply dropped.
- `_RollingPlace(from, to, up, progress, style)`: `ClipRect` → Stack(center): new char with `FractionalTranslation(0, dir × (1 − progress))` (dir = +1 up, −1 down; positive y = below, so rising numbers enter from below), and if `from` non-empty an old char positioned fill inside `OverflowBox(maxWidth: ∞)` with translation `(0, −dir × progress)` (leaves upward when growing). The new char sizes the place.
- `rollsUp(from, to)` (visibleForTesting): both readable → `b >= a`; any unreadable → true.
- `readCount(text)` (visibleForTesting): regex `(-?\d[\d.,\s  ']*)\s*((?:[kKmMbB](?![A-Za-z]))?)` — a unit letter only counts if not followed by another letter ("5 bits", "3 months" have no unit). Remove whitespace, NBSP, NNBSP, apostrophes. Decimal separator detection: both '.' and ',' present → the last one is decimal; only one kind → decimal only if it appears once AND (is not followed by exactly 3 digits OR a unit is present) ("1.000" = 1000; "1.2K" = 1200; "12,4 k" = 12400). Remove the other separator, turn decimal ',' into '.', parse; multiply k 1e3, m 1e6, b 1e9. Null if no number.

### lib/widgets/motion/signal_ping.dart

`SignalPing({size = 8, color, maxScale = 2.6, period = 1200 ms, ripples = 2, rest = 5 s})` — the live dot that sends a radio-like ripple.
- Bursts: `ripples` ripples back to back, then `rest` with NO ticker (a Timer), so an idle screen of live dots draws almost no frames (each frame also redraws the shell glass).
- Stops when app not resumed (WidgetsBindingObserver; `lifecycleState == null || resumed` counts as in front), off-screen via TickerMode (single ticker), and when scrolled out of every enclosing viewport (checked before each burst; if hidden, retry after `rest`).
- Reduce motion: still dot (controller value 0, stopped).
- State: `_controller` (duration = period), `_resting` Timer, `_ripplesLeft`. `didChangeDependencies` re-reads reduce motion and `_sync()`. `didUpdateWidget`: period change updates duration and continues. `_sync`: reduced → stop and value 0; not in front → stop; else if idle and not resting → `_burst()`. `_burst`: requires mounted, not reduced, in front; not in viewport → Timer(rest, _burst); else `_ripplesLeft = ripples; forward(from: 0)`. Status completed → if `--_ripplesLeft > 0` forward again else Timer(rest, _burst). `_inViewport`: transform own rect to global; walk up `RenderAbstractViewport.maybeOf` chain; any viewport whose global rect does not overlap → false.
- Build: `RepaintBoundary(SizedBox.square(size, CustomPaint(SignalPingPainter(progress: controller, color: color ?? onsetColors.live, maxScale))))`. Keeps its box size; ripple paints outside it.
- `SignalPingPainter` (repaint: progress): centre, radius = shortestSide/2; if 0 < t < 1: eased = standard(t); ripple circle radius `r × (1 + (maxScale − 1) × eased)` filled with colour at alpha `0.7 × (1 − eased)`; then the solid dot radius r on top. `shouldRepaint` on progress/color/maxScale change.
Timeline per burst: ripple 0–1200 ms, ripple 1200–2400 ms, rest 5000 ms, repeat (7.4 s cycle).

### lib/widgets/motion/staggered_entrance.dart

- `EntranceGate({required ValueListenable<bool> open, child})` (InheritedNotifier): holds every StaggeredEntrance below until `open` is true. The launch intro wraps the app in one, closed while the intro covers the screen, so Home builds and loads underneath and its cards cascade only once uncovered. Gated entrances use `launchStaggerStep` (60 ms). `_of` uses getInherited (no dependency).
- `StaggerScope({child})`: only the list's first appearance cascades. `_admit()`: first call starts the batch and schedules a post-frame callback that closes it; rows mounted in that same frame are admitted; rows mounted in any later frame (scrolled in, refresh) show at once. Exposed via private `_StaggerBatch` InheritedWidget (never notifies).
- `StaggeredEntrance({required index, child, step, offset = 16})`: rises `offset` px and fades in on emphasizedDecelerate, `index` steps after the first row. Decided once per mounted element in the first `didChangeDependencies` (rebuilds never replay). Under a scope that refuses → value 1 (shown) — this check comes first, so a refused entrance ignores the gate entirely. Under reduce motion a closed gate still holds the 150 ms fade until it opens. Reads reduce motion and gate. Gate closed → listen, prepare, wait; else prepare and forward.
- `_prepare`: reduced → duration 150 ms, progress = controller linear (fade only, no travel). Else step = widget.step ?? (`_heldByGate` ? 60 : 40 ms) — `_heldByGate` is true only if an EntranceGate exists AND it was CLOSED at the first didChangeDependencies; an entrance mounted under an already-open gate uses 40 ms; `delay = step × min(index, 8)`; `total = delay + 350 ms`; progress = `CurvedAnimation(Interval(delay/total, 1, curve: emphasizedDecelerate))` — a single controller, no timers.
- Build: `FadeTransition(opacity: progress)` + `Transform.translate(Offset(0, reduced ? 0 : (1 − progress) × offset))`.
- Example: index 3 not gated → total 470 ms, invisible 0–120 ms, then 350 ms rise from +16 px with fade.

### lib/widgets/launch/launch_intro.dart

`LaunchIntro({required child, play = false, fromTile = false, holdOnName = false, slotKey, splashTile})` — the cold-start launch intro drawn OVER the app (phone and tablet). Storyboard: signal dot lights → grows into the tile with small overshoot → ONSET icon fades/grows in on it and two rings leave the tile → O-N-S-E-T rise one by one over a lime underline → tile flies to its place in the header, taking on the header mark's corners → the black ground clears and home cards cascade 60 ms apart. 1.4 s total.

Rules: never blocks loading — the app (`child`) is built from frame one underneath; only its StaggeredEntrances wait via an `EntranceGate(open: _revealed)`. Plays only when `play` (cold start from the launcher), never under reduce motion, never with a screen reader (`MediaQuery.maybeAccessibleNavigationOf == true`). Ended at once by a tap, `skipAll()` (deep link, notification), any page push (`navigatorObserver`), or the app going inactive/hidden/paused (AppLifecycleListener onInactive/onHide/onPause → finish). Once the ground starts clearing (t ≥ reveal) the overlay ignores pointers so taps reach the app. No blur anywhere: fills and a soft shadow only.

Constants: `duration = 1400 ms`; `landingDuration = 1400 ms`; `landingFromTileDuration = 1250 ms`. Test keys: `overlayKey = ValueKey('launch-intro')`, `tileKey = ValueKey('launch-intro-tile')`, `ringKeys = [ValueKey('launch-intro-ring-1'), ValueKey('launch-intro-ring-2')]`.

Static state: `_running` and `_mounted` sets of states; `restingTile` (ValueNotifier<Rect?>, where the tile rested when a held intro ended — the onboarding picks it up); `landing` (ValueNotifier<bool>, true while `land` plays; pages that would open over the new page — release notes — wait until false); `landed()` future completing when landing false; `_swapping` flag (a landing's own page swap must not end the landing); `running` (ValueNotifier<bool>, true while any intro covers the app — e.g. a live preview's decoder waits); `skipAll()`; `land({required Rect from, required VoidCallback onCovered, appear = true})` → uses the last mounted intro, returns false (caller swaps the page itself) when none mounted, reduce motion or screen reader; `navigatorObserver = _SkipOnPush()` (didPush with a previousRoute and not swapping → `_skipAll(fromPush: true)`).

**Main timeline `_Timeline`** (fractions written for a 1.9 s storyboard, played over 1400 ms; ms = fraction × 1400):
| step | fractions | ms |
|---|---|---|
| dot grows (0 → 20 % of tile, curve standard) | 0 – 0.08 | 0 – 112 |
| tile grows (20 % → 100 %, curve overshoot Cubic(0.3,1.5,0.5,1)); radius settles 36 → 20 (standard) | 0.08 – 0.26 | 112 – 364 |
| icon fades in, scale 0.6 → 1.0 (Curves.ease) | 0.18 – 0.30 | 252 – 420 |
| ring 1 (border 2 dp, alpha 0.8 → 0, scale 1 → 2.8 phone / 3.2 tablet, standard) | 0.26 – 0.46 | 364 – 644 |
| ring 2 (border 1.5 dp, alpha 0.55 → 0, scale 1 → 3.6 phone / 4.4 tablet, standard) | 0.32 – 0.54 | 448 – 756 |
| letter i (i = 0..4) rises (emphasizedDecelerate), step 35/1900 ≈ 0.01842 ≈ 25.8 ms | 0.30 + i·0.01842 – 0.42 + i·0.01842 | O 420–588, N 446–614, S 472–640, E 497–665, T 523–691 |
| underline draws (scaleX 0 → 1 from left, standard) | 0.40 – 0.54 | 560 – 756 |
| first-run hold point (`holdEnd`) | 0.56 | 784 |
| tile flight to header slot (standard): centre lerp, scale to slot width/72, radius toward slot mark corners | 0.58 – 0.78 | 812 – 1092 |
| name fades out (Curves.ease) | 0.60 – 0.70 | 840 – 980 |
| ground (black #0A0A0A) fades out (Curves.ease) | 0.68 – 0.80 | 952 – 1120 |
| reveal: EntranceGate opens (home cards cascade, 60 ms step), overlay stops catching taps | 0.70 | 980 |
| tile fades out (linear) — only when there is NO real slot | 0.74 – 0.86 | 1036 – 1204 |
| completed → finish | 1.0 | 1400 |
`span(t, start, end, curve = linear)` = `curve(clamp((t − start)/(end − start), 0, 1))`.

`fromTile` (Android native splash already showed the tile): controller starts at 0.26 (364 ms), grow = 1, icon fully in, base radius = 20, and the tile glow fades in over 0.26–0.36 (364–504 ms) instead of being on from the start.

**State lifecycle (`_LaunchIntroState`)**: initState adds to `_mounted`, creates controller (1400 ms) with tick listener and completed → `_finish`. First `didChangeDependencies`: if `!play || !_canPlay` → done, revealed = true (gate open, no overlay). Else `_start()` (add to running, notify, lifecycle listener) and `forward(from: fromTile ? 0.26 : 0)`.
`_onTick`: landing → at t ≥ coverEnd call `_cover()` (once), at t ≥ reveal set revealed; normal → if holdOnName and t ≥ 0.56 → `_finish()`; at t ≥ 0.70 set revealed.
`_finish({deferCover})`: idempotent; if landing: cover now or after frame; else if holdOnName: `restingTile = _restingRect` (splash tile rect when fromTile and known, else 72×72 rect at screen centre); remove from running; dispose lifecycle; stop controller; revealed = true; clear landing (notifier false); setState done (overlay removed).
`_cover()`: runs `onCovered` exactly once with `_swapping = true`. `_coverAfterFrame()`: same in a post-frame callback + ensureVisualUpdate (when a push is in progress or the tree is locked). `dispose`: landing notifier false; `_coverAfterFrame()` (a landing cut by teardown still swaps the page); remove from sets; dispose.
`_land`: requires `_canPlay`; finishes any running intro; sets `_landing = _LandingTimeline(appear)`, landing notifier true, from rect, onCovered, revealed false, done false, `_start()`, controller duration = landing duration, forward from 0.

**Build**: `Stack[EntranceGate(open: _revealed, child), if !done Positioned.fill(key: overlayKey, ExcludeSemantics(RepaintBoundary(AnimatedBuilder(merge(controller, splashTile), IgnorePointer(ignoring: t ≥ reveal, GestureDetector(opaque, onTap: _finish, landing ? _LandingFrame : _IntroFrame))))))]`.
`_hasRealSlot`: slotKey's render object is a RenderBox. `_slotRadius`: if slot widget is an `OnsetMarkTile` and real: its radius ?? 20 × size/72. `_slotRect`: slot's rect relative to this widget when attached and sized; fallback (no slot): tablet (shortestSide ≥ 600) `Rect(28, top + 21, 30, 30)`, phone `Rect(16, top + 14, 28, 28)` with top = MediaQuery padding top.
`_landingRadius(radius, slot, slotRadius, flight)`: if slotRadius null or slot width ≤ 0 → radius; else `landed = slotRadius × 72 / slot.width`; return `radius + (landed − radius) × flight` (at 72 dp layout size, so once scaled it has the header mark's exact corners).

**`_IntroFrame`** (t, fromTile, splash rect, slot, slotIsReal, slotRadius): tile = 72, ground = #0A0A0A, accent #C8FF3D. centre = splash centre ?? screen centre; `rest = (splash width ?? 72)/72`. grow (see table); settle = span(0.08, 0.26, standard); flight = span(0.58, 0.78, standard); radius = landingRadius(fromTile ? 20 : 36 − 16×settle); tileCenter = lerp(centre, slot.centre, flight); `tileScale = grow × rest + (slot.width/72 − rest) × flight`; tileOpacity = slotIsReal ? 1 : 1 − span(0.74, 0.86); markIn = fromTile ? 1 : span(0.18, 0.30, ease); glowIn = fromTile ? span(0.26, 0.36) : 1; nameOut = 1 − span(0.60, 0.70, ease); underline = span(0.40, 0.54, standard); ground = 1 − span(0.68, 0.80, ease).
Ring(index, start, end, width): hidden when t < start − 0.01; p = span(standard); Positioned 72×72 at centre; `Transform.scale(key ringKeys[index], 1 + (maxScale − 1)p)` of a DecoratedBox radius 20 with border accent at alpha `startAlpha × (1 − p)` (0.8 / 0.55), width 2 / 1.5. Ring 1 only while t < 0.46, ring 2 while t < 0.54.
Layers (StackFit.expand, DefaultTextStyle Inter, no decoration): ground ColoredBox (#0A0A0A × ground) when ground > 0; rings; wordmark when nameOut > 0 positioned full width at `top = centre.dy + 36 + gapBelowTile (30 phone / 31 tablet)`, centred, `OnsetWordmark(tablet, letters: 5 spans, underline, opacity: nameOut)`; tile Positioned 72×72 at tileCenter, `Transform.scale(tileScale)` → `Opacity(key: tileKey, tileOpacity)` → `OnsetMarkTile(radius, drawnSize: 72 × tileScale, markOpacity: markIn, markScale: 0.6 + 0.4 markIn, glow: [BoxShadow(accent α 0.25 × glowIn, blurRadius 40 phone / 48 tablet)])`. When ground > 0.5 wrapped in `AnnotatedRegion(SystemUiOverlayStyle.light)` (light status-bar icons over black).

**Landing (`_LandingTimeline`)** — replay of the intro's end when the onboarding hands over to Home ("Let's go!"). The screen first fades to black over the onboarding (280 ms) and the page is swapped underneath at coverEnd; the flight never starts before the swap (the header it lands on only exists after). NOTE: the source doc comment (launch_intro.dart ~201-208) says tablet flight 8–52 %, header 40–62 %, cards from 44 %; the code uses 24–64 %, 48–68 %, 50 % (below). Code values win; the Rust port uses the table.
| | appear = true (phone, 1400 ms) | appear = false (tablet, tile already on screen, 1250 ms) |
|---|---|---|
| ground fades IN (emphasizedAccelerate) | 0 – 0.20 (0–280 ms) | 0 – 0.20 (0–250 ms) |
| page swap (onCovered) at | 0.20 (280 ms) | 0.20 (250 ms) |
| tile pops in (scale 0.6 → 1 via overshoot, opacity linear) | 0 – 0.18 (0–252 ms) | none (already 1) |
| one ring (2 dp, α 0.7 → 0, scale rest × (1 + 1.6·standard(p)), radius 20; linear p) | 0.18 – 0.40 (252–560 ms) | none |
| flight (standard) | 0.40 – 0.78 (560–1092 ms) | 0.24 – 0.64 (300–800 ms) |
| ground fades OUT (ease) | 0.64 – 0.80 (896–1120 ms) | 0.48 – 0.68 (600–850 ms) |
| reveal (cards cascade) | 0.66 (924 ms) | 0.50 (625 ms) |
| tile fade (only without real slot) | 0.74 – 0.86 (1036–1204 ms) | 0.60 – 0.72 (750–900 ms) |
`_LandingFrame`: rest = from.width/72; ground as above clamped; pop/popOpacity; centre lerp(from.centre, slot.centre, flight); `scale = (0.6 + 0.4 pop) × rest + (slot.width/72 − rest) × flight`; tileOpacity = popOpacity × (slotIsReal ? 1 : 1 − tileOut); tile glow accent α 0.25 × (1 − flight), blur 40/48; radius `_landingRadius(20, …)`. Same AnnotatedRegion rule.

### lib/widgets/launch/onset_mark.dart

**`OnsetMark`** (abstract final): `designSize = 72.0`, `designRadius = 20.0`, `ground = Color(0xFFD6F427)` (the icon's own lime ground: mean of its outer band — the tile fill behind the image, so the dot grows in the icon's lime and the icon comes in without an edge). Families `[30, 52, 72]` dp; ratios `[1.0, 1.5, 2.0, 3.0, 4.0]`. Assets written by `tool/onset_logo_assets.py`: `assets/icons/onset_logo_<family>.png` (1.0x) and `assets/icons/<r>x/onset_logo_<family>.png` (1.5x, 2.0x, 3.0x, 4.0x). The Android splash draws the 72 family with the same 20 dp corners (`res/drawable-*dpi/launch_tile.png`, test-checked) so the native splash hands over pixel-for-pixel at densities 1/1.5/2/3/4.
- `imageFor(size, {devicePixelRatio})` → `ExactAssetImage`: family = smallest ≥ size − 0.01 (else 72); ratio = smallest ≥ dpr − 0.001 (else 4.0); folder '' for 1.0 else `'<ratio.toStringAsFixed(1)>x/'`; scale = ratio. Chosen manually because AssetImage picks the nearest variant above 2.0 and would upscale on 2.5/3.5 screens.
- `precache({devicePixelRatio, size = 72, bundle, timeout = 300 ms})`: resolves the image stream, completes on first frame (disposing its handle) or error (debugPrint 'ONSET mark not precached: <type>'), or after timeout; never throws.
- `precacheFor(view, {bundle, timeout = 300 ms})`: if the view has no physical size yet, waits for first metrics (binding observer `_FirstMetrics.didChangeMetrics`) within the timeout; if still empty or no time left, returns; else precaches the 72 and the 30 families in parallel at the view's dpr with the remaining time.

**`OnsetMarkTile({size = 72, radius, markOpacity = 1, markScale = 1, glow, drawnSize})`**: sizes used — 72 launch intro, 52 release notes and update prompt, 28 phone header, 30 tablet header. Corners = radius ?? 20 × size/72. `Semantics(label: 'ONSET', image: true, excludeSemantics: true)` → SizedBox.square(size) → DecoratedBox(colour #D6F427, corners, boxShadow glow) → if opacity > 0: ClipRRect(corners) → Transform.scale(markScale) → `Image(imageFor(drawnSize ?? size, dpr), width/height size, fit cover, gaplessPlayback: true (family change mid-flight keeps the last image), excludeFromSemantics, opacity: AlwaysStoppedAnimation(opacity) when < 1)`. Default FilterQuality.medium (mipmapped bilinear) for downscaling.

**`OnsetWordmark({required tablet, letters = [1,1,1,1,1], underline = 1, opacity = 1, underlineColor = accent})`**: name 'ONSET'; `gapBelowTile` 30 phone / 31 tablet; `letterSize` 34 phone / 40 tablet; `widthFor(textScaler, tablet)` sums per-letter TextPainter widths. Letter style: Inter, size, w800, normal, no decoration, letterSpacing −0.035 × size, height 1.2. Rise distance 20 phone / 22 tablet. Build: `Semantics(header: true, label: 'ONSET', excludeSemantics)` → Column(min): Row(min) of 5 `_Letter`s; SizedBox(height 12); underline SizedBox(width 120 phone / 140 tablet, height 2) → Transform.scale(scaleX: underline, alignment centerLeft) → DecoratedBox(colour underlineColor with alpha a × opacity, radius 1). `_Letter`: `Transform.translate(0, rise × (1 − progress))` of Text in letter style with colour #F5F5F5 at alpha clamp(progress × opacity). One Text per letter so intro and onboarding lay out identically (onboarding's first frame equals the intro's last).

### lib/widgets/sheet/svg_path.dart

A small SVG path-data parser that turns ONSET's own 24 × 24 glyph strokes into paths exactly (no redrawing).
- `parseSvgPath(data)` supports M L H V C S Q T A Z, absolute (upper-case) and relative (lower-case). Tokenizer regex `[A-Za-z]|[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?` (handles "1-2", "1.5.5" → 1.5 and .5, "2e-3"). State: current point, subpath start, last cubic control (for S), last quad control (for T).
- Rules: a command letter must come first ("Path data must start with a command"); number missing → `FormatException('Missing number in path')`; M sets start and moveTo, then implicit following pairs become L/l; H/V update one coordinate; C records c2 as lastCubic; S reflects lastCubic about current (or uses current when previous was not a cubic); Q records lastQuad; T reflects lastQuad; A: |rx|, |ry|, rotation, largeArc flag, sweep flag, end → `arcToPoint(end, radius: elliptical(rx, ry), rotation, largeArc, clockwise: sweep)`, or lineTo when rx or ry is 0; arc flags may be glued ("a1 1 0 011 2 2"): a token of 0/1 digits longer than one char yields its first digit as the flag and keeps the rest as the next token; missing flag → FormatException('Missing arc flag in path'); Z closes, current = start, and a number directly after Z throws ('Number after closepath in path') to avoid an infinite loop; any other letter → FormatException('Unsupported path command X'). Every non-curve command resets the S/T reflection memory.
- `svgCircle(cx, cy, r)` → oval path; `svgRect(x, y, w, h, rx)` → rounded rect with radius max(0, rx).
- `glyphPathOf(shapes)`: concatenates entries: `c:cx,cy,r` circle, `r:x,y,w,h,rx` rounded rectangle, otherwise path data.
PC: implement with `kurbo::BezPath::from_svg` or a direct port; Skia `SkParsePath::FromSVGString` is equivalent but keep the glued-flag handling and the error cases.

### lib/widgets/sheet/sheet_glyph.dart

`enum SheetGlyphKind` (48 icons for the channel screen's sheets, menus and panels): emote, trash, clearChat, copy, paste, link, external, reply, whisper, profile, more, videos, block, bell, heart, share, flag, timer, unban, warn, chevronDown, chevronRight, chevronLeft, hourglass, star, unique, check, close, refresh, plug, palette, coin, gift, shield, rules, people, addChat, settings, monitor, filter, flame, trophy, poll, pin, cake, diamond, lock, contrast.

All drawn as 24 × 24 strokes with round caps and joins. Exact shape data (verbatim — this IS the icon design; copy it as-is into the Rust glyph table; adjacent Dart string literals are concatenated):
```dart
const Map<SheetGlyphKind, List<String>> _shapes = {
  SheetGlyphKind.emote: [
    'c:12,12,8',
    'M9 14.5c1.6 1.4 4.4 1.4 6 0',
    'M9.5 10h.01M14.5 10h.01',
  ],
  SheetGlyphKind.trash: ['M5 7h14M10 7V5h4v2M7 7l1 12h8l1-12'],
  SheetGlyphKind.clearChat: [
    'M4 7h10M10 7V5h4v2M6 7l1 12h7l1-6',
    'M16 14l5 5M21 14l-5 5',
  ],
  SheetGlyphKind.copy: ['r:9,9,11,11,2', 'M5 15V6a1 1 0 0 1 1-1h9'],
  SheetGlyphKind.paste: ['r:6,4.5,12,16,2', 'M9.5 3.5h5v3h-5z'],
  SheetGlyphKind.link: [
    'M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1',
    'M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1',
  ],
  SheetGlyphKind.external: [
    'M14 4h6v6M20 4l-9 9',
    'M18 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h5',
  ],
  SheetGlyphKind.reply: ['M10 8L5 12l5 4', 'M5 12h9a5 5 0 0 1 5 5v1'],
  SheetGlyphKind.whisper: ['M4 5h16v11H9l-5 4z'],
  SheetGlyphKind.profile: [
    'c:12,12,9',
    'c:12,10,3',
    'M6.6 18.2c1.4-2.1 3.3-3.1 5.4-3.1s4 1 5.4 3.1',
  ],
  SheetGlyphKind.more: ['c:5,12,1.4', 'c:12,12,1.4', 'c:19,12,1.4'],
  SheetGlyphKind.videos: [
    'r:3.5,7,17,12,2',
    'M7 4h10',
    'M10.5 10.5l4 2.5-4 2.5z',
  ],
  SheetGlyphKind.block: ['c:12,12,8.5', 'M6 6l12 12'],
  SheetGlyphKind.bell: [
    'M6 16V11a6 6 0 0 1 12 0v5l1.5 2h-15z',
    'M10 20a2 2 0 0 0 4 0',
  ],
  SheetGlyphKind.heart: [
    'M12 20s-7-4.5-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.5-7 10-7 10z',
  ],
  SheetGlyphKind.share: ['M12 4v11M7 9l5-5 5 5M5 14v5h14v-5'],
  SheetGlyphKind.flag: ['M5 21V4h11l-1.5 4L16 12H5'],
  SheetGlyphKind.timer: ['c:12,13,7.5', 'M12 13V9.5M10 2.5h4'],
  SheetGlyphKind.unban: ['M9 14L4 9l5-5', 'M4 9h11a5 5 0 0 1 0 10h-3'],
  SheetGlyphKind.warn: ['M12 4l9 16H3z', 'M12 10v4M12 17h.01'],
  SheetGlyphKind.chevronDown: ['M6 9l6 6 6-6'],
  SheetGlyphKind.chevronRight: ['M9 6l6 6-6 6'],
  SheetGlyphKind.chevronLeft: ['M15 6l-6 6 6 6'],
  SheetGlyphKind.hourglass: [
    'M7 3h10M7 21h10',
    'M8 3c0 5 8 5 8 9s-8 4-8 9M16 3c0 5-8 5-8 9s8 4 8 9',
  ],
  SheetGlyphKind.star: [
    'M12 4l2.4 5 5.6.7-4.1 3.8 1 5.5L12 16.4 7.1 19l1-5.5L4 9.7 9.6 9z',
  ],
  SheetGlyphKind.unique: [
    'c:12,12,8.5',
    'M9.6 9.6a2.5 2.5 0 1 1 3.4 2.3c-.6.3-1 .8-1 1.5v.4M12 16.5h.01',
  ],
  SheetGlyphKind.check: ['M5 12.5l4.5 4.5L19 7.5'],
  SheetGlyphKind.close: ['M6 6l12 12M18 6L6 18'],
  SheetGlyphKind.refresh: [
    'M19.5 11a7.5 7.5 0 0 0-13.4-3.6L4.5 9',
    'M4.5 4.5V9H9',
    'M4.5 13a7.5 7.5 0 0 0 13.4 3.6l1.6-1.6',
    'M19.5 19.5V15H15',
  ],
  SheetGlyphKind.plug: ['M9 3v4M15 3v4M7 7h10v4a5 5 0 0 1-10 0z', 'M12 16v5'],
  SheetGlyphKind.palette: [
    'M12 3a9 9 0 1 0 0 18c1.2 0 1.8-.9 1.4-2-.5-1.3.3-2.5 1.7-2.5H17a4 4 0 0 0 '
        '4-4c0-5-4-9.5-9-9.5z',
    'M7.5 11.5h.01M10 7.5h.01M14.5 7.5h.01',
  ],
  SheetGlyphKind.coin: [
    'c:12,12,8.5',
    'M14.5 9.5a2.5 2 0 0 0-2.5-1.5c-1.4 0-2.5.8-2.5 2s1.1 1.6 2.5 2 2.5.8 '
        '2.5 2-1.1 2-2.5 2a2.5 2 0 0 1-2.5-1.5M12 6.5V8M12 16v1.5',
  ],
  SheetGlyphKind.gift: [
    'r:4,9,16,4,1',
    'M5.5 13v7h13v-7M12 9v11',
    'M12 9c-1-3-5.5-4-5.5-1.5S10 9 12 9zM12 9c1-3 5.5-4 5.5-1.5S14 9 12 9z',
  ],
  SheetGlyphKind.shield: ['M12 3l7 3v6c0 4.5-3 7.5-7 9-4-1.5-7-4.5-7-9V6z'],
  SheetGlyphKind.rules: [
    'M6 4h10a3 3 0 0 1 3 3v13H9a3 3 0 0 1-3-3z',
    'M6 17a3 3 0 0 1 3-3h10M10 8h5',
  ],
  SheetGlyphKind.people: [
    'c:9,8.5,3.2',
    'M3.5 19c.8-3 3-4.5 5.5-4.5s4.7 1.5 5.5 4.5',
    'M16 5.4a3 3 0 0 1 0 5.6',
    'M17.5 14.6c1.6.6 2.7 2.1 3 4.4',
  ],
  SheetGlyphKind.addChat: ['M4 5h16v11H9l-5 4z', 'M12 8v5M9.5 10.5h5'],
  SheetGlyphKind.settings: [
    'c:12,12,3',
    'M19.4 15a1.6 1.6 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.6 1.6 0 0 '
        '0-1.8-.3 1.6 1.6 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.6 1.6 0 0 '
        '0-1-1.5 1.6 1.6 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.6 1.6 0 '
        '0 0 .3-1.8 1.6 1.6 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.6 1.6 0 0 0 '
        '1.5-1 1.6 1.6 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.6 1.6 0 0 '
        '0 1.8.3H9a1.6 1.6 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.6 1.6 0 0 0 1 '
        '1.5 1.6 1.6 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.6 1.6 0 0 '
        '0-.3 1.8V9a1.6 1.6 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.6 1.6 0 0 '
        '0-1.5 1z',
  ],
  SheetGlyphKind.monitor: ['r:3,5,18,12,2', 'M8 21h8M12 17v4'],
  SheetGlyphKind.filter: ['M4 7h16M7 12h10M10 17h4'],
  SheetGlyphKind.flame: [
    'M12 3c.8 3 4.5 4.6 4.5 9a4.5 4.5 0 0 1-9 0c0-2.2 1-3.6 2.2-4.6.1 2 1 '
        '3.2 2.3 3.3-.4-3 .2-5.3 0-7.7z',
  ],
  SheetGlyphKind.trophy: [
    'M8 4h8v5a4 4 0 0 1-8 0z',
    'M8 6H5a3 3 0 0 0 3 4M16 6h3a3 3 0 0 1-3 4M12 13v4M8.5 20h7',
  ],
  SheetGlyphKind.poll: ['M5 20V11M12 20V4M19 20v-6'],
  SheetGlyphKind.pin: ['M9 4h6l-1 6 3 3H7l3-3z', 'M12 13v7'],
  SheetGlyphKind.cake: [
    'M4 20h16M5 20v-7h14v7',
    'M5 16.5c2 0 2-1.6 3.5-1.6S10 16.5 12 16.5s2-1.6 3.5-1.6 1.5 1.6 3.5 1.6',
    'M12 13V9.5M12 6.5v.01',
  ],
  SheetGlyphKind.diamond: ['M12 3l7.5 7.5L12 21 4.5 10.5z', 'M4.5 10.5h15'],
  SheetGlyphKind.lock: ['r:6,11,12,9,2', 'M9 11V8a3 3 0 0 1 6 0v3'],
  SheetGlyphKind.contrast: ['c:12,12,8', 'M12 4v16', 'M12 8h4M12 12h6M12 16h4'],
};
```
- `_cache`: parsed once per kind; `sheetGlyphPath(kind)`.
- `SheetGlyph(kind, {color, size = 20, strokeWidth = 1.8})`: colour = given ?? `IconTheme.of(context).color` ?? DefaultTextStyle colour ?? #F5F5F5. `ExcludeSemantics` (decorative; the surrounding button carries the label) → SizedBox.square(size) → CustomPaint(`_SheetGlyphPainter`): canvas scaled by size/24 then stroke path with `strokeWidth` in 24-unit space (so 1.8 at size 20 is 1.5 px logical), PaintingStyle.stroke, round cap/join, antialias. `shouldRepaint` on kind/colour/width.

### lib/widgets/state_glyph.dart

`enum StateGlyphKind` (15) — icons of the shared states, Activity and Whispers: offline (no connection), retry ("Try again"), alert (something failed), account (logged out), bell (Activity empty state), live (go-live notification), mention (chat mention), calendar (schedule reminder), checkAll ("Mark all as read"), trash ("Remove notification"), chevronRight (a row that opens something, "See all"), back, reply (a whisper the viewer sent — the preview's "You"), send (send a whisper), whisper.

Exact shape data (verbatim; path data and `c:cx,cy,r` circles on the 24 × 24 grid):
```dart
const Map<StateGlyphKind, List<String>> _shapes = {
  StateGlyphKind.offline: [
    'M3 3l18 18',
    'M8.5 16.4a5 5 0 0 1 7 0',
    'M5 12.9a10 10 0 0 1 5-2.7M14.2 10.3a10 10 0 0 1 4.8 2.6',
    'M2 9a15 15 0 0 1 4-2.5M10.6 5.1A15 15 0 0 1 22 9',
    'M12 20h.01',
  ],
  StateGlyphKind.retry: ['M20 11a8 8 0 1 0-2.3 5.7', 'M20 5v6h-6'],
  StateGlyphKind.alert: ['c:12,12,8.5', 'M12 8v5M12 16h.01'],
  StateGlyphKind.account: [
    'c:10,8,4',
    'M3 20a7 7 0 0 1 14 0',
    'M17 8l4 4M21 8l-4 4',
  ],
  StateGlyphKind.bell: [
    'M6 16V11a6 6 0 0 1 12 0v5l1.5 2h-15z',
    'M10 20a2 2 0 0 0 4 0',
  ],
  StateGlyphKind.live: [
    'c:12,12,2',
    'M8.5 15.5a5 5 0 0 1 0-7M15.5 8.5a5 5 0 0 1 0 7',
    'M5.6 18.4a9 9 0 0 1 0-12.8M18.4 5.6a9 9 0 0 1 0 12.8',
  ],
  StateGlyphKind.mention: [
    'c:12,12,3.5',
    'M15.5 12v1.5a2.5 2.5 0 0 0 5 0V12a8.5 8.5 0 1 0-3.3 6.7',
  ],
  StateGlyphKind.calendar: [
    'M6 5h12a2 2 0 0 1 2 2v11a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V7a2 2 0 0 1 '
        '2-2z',
    'M4 10h16M9 3v4M15 3v4',
  ],
  StateGlyphKind.checkAll: ['M3 13l4 4 8-9', 'M11.5 16.5l.5.5 9-9.5'],
  StateGlyphKind.trash: ['M5 7h14', 'M10 7V5h4v2', 'M7 7l1 12h8l1-12'],
  StateGlyphKind.chevronRight: ['M9 6l6 6-6 6'],
  StateGlyphKind.back: ['M15 6l-6 6 6 6'],
  StateGlyphKind.reply: ['M9 7l-5 5 5 5', 'M4 12h10a6 6 0 0 1 6 6v1'],
  StateGlyphKind.send: ['M4 12l16-8-6 16-2.5-6.5z', 'M11.5 13.5L20 4'],
  StateGlyphKind.whisper: ['M4 5h16v11H9l-5 4z'],
};
```
Parsed once per kind (`_cache`, via `glyphPathOf`). `StateGlyph(kind, {required color, size = 20, strokeWidth = 1.8})`: `ExcludeSemantics` → SizedBox.square(size) → CustomPaint: canvas scaled size/24, stroke with round cap and join, antialiased; repaint on kind/colour/width change. Unlike SheetGlyph, colour is required.

### lib/widgets/sheet/onset_sheet.dart

The channel-screen sheet kit: colours, type, frame, rows, switch, status line, buttons, choice pills, dialog, text field, initial avatar.

**`SheetColors`** (25 fields) — `dark` / `light`:
| field | use | dark | light |
|---|---|---|---|
| sheet | a sheet | #141414 | #FFFFFF |
| panel | sheet over a sheet ("More", the bet), tablet anchored panel | #181818 | #FFFFFF |
| dialog | dialog card | #1E1E1E | #FFFFFF |
| raised | raised controls in a sheet (icon tile, chatters filter) | #1E1E1E | #F0F0F0 |
| well | card inside a sheet (message preview, watch streak) | #1A1A1A | #F5F5F5 |
| chip | unselected choice pill | #222222 | #EFEFEF |
| field | number field (stake) | #101010 | #F5F5F5 |
| emoteMenu | emote menu under chat input (phone) | #101010 | #F7F7F7 |
| handle | drag handle | #3A3A3A | #D4D4D4 |
| topHighlight | light edge along sheet top | 0x24FFFFFF (14 %) | 0x14000000 |
| hairline | separators | 0x14FFFFFF | 0x14000000 |
| ring | thin inner ring of pills/fields | 0x1AFFFFFF (10 %) | 0x1A000000 |
| ringStrong | outlined pill ring (Unban, Warn) | 0x2EFFFFFF (18 %) | 0x2E000000 |
| text | | #F5F5F5 | #0A0A0A |
| body | | #D6D6D6 | #3A3A3A |
| secondary | | #A1A1A1 | #6B6B6B |
| tertiary | | #8A8A8A | #6B6B6B |
| danger | destructive row text/icon (Delete, Clear chat, Ban) | #FF7A7F | #C62828 |
| dangerFill | destructive confirmation button | #FF5A5F | #E5484D |
| dangerTint | tint behind destructive pill | 0x24FF5A5F | 0x1FE5484D |
| switchOff | | #2E2E2E | #D6D6D6 |
| knobOff | | #A1A1A1 | #FFFFFF |
| disabledFill | primary button not pressable yet | #2A2A2A | #E6E6E6 |
| disabledText | | #8A8A8A | #9A9A9A |
| pagerOff | pager arrow with nowhere to go | #4A4A4A | #C4C4C4 |
`of(context)` by theme brightness; `accentOf` = `onsetColors.live`; `onAccentOf` = #0A0A0A dark / white light; `accentTintOf(context, {alpha = 0.10})`.

**`SheetText`** (Inter): `title` 18/w700/ls −0.27/h 1.25 ("Chat modes", "Clear chat?", dialog title); `subtitle` 17/w700/ls −0.25/h 1.25 (sub-view title by back chevron); `row` 15/w500/h 1.3; `rowDetail` 12.5/w400/h 1.3; `section` 11/w600/ls 1.54/h 1.3 upper-case ("RECENT MESSAGES", "REWARDS"); `body` 14/w400/h 1.5; `pill` 13/w600/h 1.2; `status` 12.5/w400/h 1.35 ("You timed out …"); `tabular(style)` → OnsetType.tabular.

Constants: `kSheetRadius = 24.0` (sheet top corners), `kPanelRadius = 20.0` (tablet panel), `kSheetScrim = 0x9E000000` (black 62 %).

**`showOnsetSheet<T>({context, builder, isScrollControlled = true, panel = false, showHandle = true, enableDrag = true, isDismissible = true, constraints, background})`**: background ?? (panel ? colors.panel : colors.sheet); calls `showModalBottomSheetWithProperFocus` with showDragHandle false (own handle), barrierColor 62 % scrim, clip antiAlias, top corners 24, builder wrapped in `SheetFrame(showHandle)`. On a phone channel screen it still starts under the video.

**`SheetFrame({child, showHandle = true})`**: foreground top border 0.5 dp `topHighlight`; `SafeArea(top: false)`; Column(min, stretch): `SheetHandle` if shown, `Flexible(child)`.
**`SheetHandle`**: padding top 8 bottom 4; centred 36 × 4 bar, colour handle, radius 2.
**`SheetSectionLabel(text, {padding = LTRB(16,12,16,6), color})`**: `Semantics(header)` Text upper-cased in section style, colour ?? secondary.
**`enum SheetRowEnd { none, chevron (goes deeper), external (leaves the app, twitch.tv) }`**.
**`SheetRow({required label, glyph, leading, detail, end = none, trailing, onTap, danger = false, color, minHeight, semanticsLabel})`**: enabled = onTap != null; label colour = color ?? (danger ? danger : text); icon colour = color ?? (danger ? danger : secondary). End glyph: chevron → chevronRight size 18 stroke 2 colour (color ?? tertiary); external → external size 17 tertiary. Leading = leading ?? SheetGlyph(glyph, colour iconColor) (size 20). `Semantics(button: enabled, enabled, label)` → transparent Material → InkWell → minHeight (minHeight ?? 52, or 60 with detail) → padding h16 v6 → Opacity(enabled 1 : 0.5) → Row(spacing 14): leading, Expanded Column(min, start, spacing 2) [label in row style, detail maxLines 2 ellipsis rowDetail secondary], trailing, end glyph.
**`SheetBackHeader({title, onBack})`**: height 48, padding left 4 right 8, Row(spacing 2): IconButton 44×44 fixed, zero padding, tooltip `commonBack`, chevronLeft 22 stroke 2 text colour; Expanded Semantics(header) title one line ellipsis subtitle style.
**`OnsetSwitch({value, onChanged, semanticsLabel})`**: custom switch. `Semantics(toggled, enabled, label, onTap)` → ExcludeSemantics → GestureDetector(opaque; tap → `HapticFeedback.selectionClick()` then onChanged(!value)) → SizedBox 52 × 44 (44 dp target) → Align centerEnd → Opacity(enabled ? 1 : 0.5) → AnimatedContainer(200 ms or 150 ms reduced; 44 × 26, padding 3, colour accent when on else switchOff, radius 13) → AnimatedAlign(260 ms standard curve; Duration.zero under reduce motion; centerEnd when on) → AnimatedContainer(260 ms / 150 ms; 20 × 20 circle, colour onAccent when on else knobOff).
**`SheetStatusLine({busy, message, ok = true, padding = LTRB(16,6,16,0), minHeight = 30, okGlyphColor})`**: busy → ClipRRect(r1) LinearProgressIndicator(minHeight 2, colour accent, background hairline); message → `Semantics(liveRegion)` Row(start, spacing 6): glyph check (ok) or warn, size 14, stroke 2.2, padding top 1, colour ok ? (okGlyphColor ?? secondary) : danger; text in status style secondary/danger; otherwise empty. Wrapped in minHeight box, padding, Align start, `AnimatedSwitcher(motionDuration(260 ms))` keyed by 'busy' or message.
**`enum SheetButtonTone { primary, danger, text }`**.
**`SheetButton({label, onPressed, tone = primary, large = false, icon, expand = false})`**: height 44 (48 large); text style tabular Inter 14 (15 large), w700 (w600 for text tone); label maxLines 2 ellipsis centred (never loses its words); icon + Flexible text in Row(spacing 8). Text tone → TextButton(fg text colour, minimum size (expand ? ∞ : 0, height), padding h18, StadiumBorder, shrinkWrap). Others → FilledButton(bg dangerFill or accent; fg #0A0A0A for danger, onAccent for primary; disabled bg disabledFill, fg disabledText; padding h20; stadium; elevation 0; shrinkWrap).
**`SheetChoicePill({label, selected, onSelected, large = false, tabular = false, role = SheetChoiceRole.radio})`**: text Inter 12 (13 large) w600, colour accent when selected else (large ? text : body). Shape stadium, side accent 0.5 (1 when large) when selected, else ring 0.5. `Semantics(selected, inMutuallyExclusiveGroup: role == radio, button)` → Material(colour accentTint 10 % when selected else chip, clip antiAlias) → InkWell (tap → selectionClick haptic, onSelected) → Container height 30 (36 large), padding h12 (14 large) → `Align(widthFactor: 1)` Text maxLines 1 (as wide as its label in a Wrap). `enum SheetChoiceRole { radio, tab }`.
**`OnsetDialog({title, leading, message, content, actions})`**: `Dialog(bg dialog #1E1E1E, tint transparent, elevation 0, insetPadding 24 all, shape radius 24 with 0.5 ring side)` → `Semantics(scopesRoute, namesRoute, explicitChildNodes, label: title)` → ConstrainedBox(maxWidth 326) → Column(min, stretch): Flexible SingleChildScrollView(padding LTRB 20,20,20,12) Column(spacing 12): title (or Row(spacing 12) leading + Expanded title), message in body style (body colour), content; then Padding(LTRB 20,2,20,20) `Wrap(alignment end, spacing 8, runSpacing 8, actions)`.
**`SheetTextField({controller, label, focusNode, autofocus = false, maxLength, keyboardType, inputFormatters, onChanged, counter = false, hint, textStyle, fill, maxLines = 1})`**: formatters = LengthLimitingTextInputFormatter(maxLength) + given; minLines 1; cursor accent; style textStyle ?? body (text colour, height 1.2); decoration: hint in body tertiary, dense, filled fill ?? sheet, contentPadding 14 all, border radius 12: default ring 1, enabled ringStrong 1, focused accent at 55 % alpha 1. Column(min, stretch, spacing 6): label (Inter 12 w600 secondary), field, counter (only when `counter && maxLength != null`) `'<characters> / <max>'` (grapheme count, emoji = 1) right-aligned, Inter 11.5 tabular tertiary, rebuilt on controller change.
**`InitialAvatar({name, size = 28})`**: palette #7CB7FF, #FF9ECF, #7CF0FF, #FFD27A, #B6F27A, #FFB38A, #C9A7FF, #9EE6C2; `colorOf(name)` = palette[0] when empty else `palette[(codeUnitAt(0) + name.length) % 8]`. ExcludeSemantics circle of that colour with the first grapheme upper-cased ('?' when empty), Inter size × 0.43, w800, height 1, colour #0A0A0A.

### lib/widgets/sheet/onset_panel.dart

Tablet anchored panels (popover with a nub) that replace bottom sheets on large screens: the emote menu and channel points above the chat input, the user card beside the chat.

- `enum PanelSide { above, below, left, right }`.
- `PanelPlacement(rect, side, nub)` (immutable, value equality, toString `PanelPlacement(<rect>, <side>, nub: <nub>)`): `nub` = position of the nub along the edge facing the anchor, measured from the panel's top (left/right sides) or left (above/below).
- `_within(value, low, high)`: clamp, but `high` wins when the range is empty (high < low).
- **`placePanel({bounds, anchor, size, sides, region, avoid, gap = 12, margin = 12})`** → PanelPlacement?: `inner = bounds.deflate(12)`; if size does not fit inner at all → null. `along = region ?? bounds` (region = chat column). For each side in order:
  - above/below: top = anchor.top − 12 − height (above) or anchor.bottom + 12 (below); skip if outside inner vertically. left = `_within(_within(anchor.cx − w/2, along.left + 12, along.right − 12 − w), inner.left, inner.right − w)` (centre on anchor, keep inside the chat column, then inside the screen). Skip if overlapping `avoid` (video). nub = `_within(anchor.cx − left, 20, w − 20)`.
  - left/right: left = anchor.left − 12 − w (left) or anchor.right + 12 (right); skip if outside inner horizontally. top = `_within(anchor.cy − 0.47 h, inner.top, inner.bottom − h)` (slightly above centred). If it overlaps the video: top = `min(avoid.bottom + 5, inner.bottom − h)`; still overlapping → skip. nub = `_within(anchor.cy − top, 20, h − 20)`.
  - none fits → null.
- `globalRectOf(context)`: render box global rect or null before layout.
- `PanelRegion` (SingleChildRenderObjectWidget with `RenderPanelRegion extends RenderProxyBox`): marks the chat column; `PanelRegion.of(context)` finds the ancestor render object and returns its global rect.
- `PanelAvoidHolder` (holds the video's RenderBox; `rect` global or null), `PanelAvoidScope(holder)` InheritedWidget (`of` via getInherited, read when a panel opens), `PanelAvoidTarget(holder)` render proxy that registers itself in the holder on attach and unregisters on detach / holder swap.
- **`SheetPresentation({panel, surface, child})`**: tells content whether it is in a tablet panel or a bottom sheet (no handle in a panel, own sizes). `isPanel(context)`; `surfaceOf(context)` = surface ?? (panel ? colors.panel : colors.sheet) (dependOn).
- **`OnsetPanelSurface({side, nub, child})`**: DecoratedBox colour panel (#181818 dark / #FFFFFF light), radius 20, shadows: [black α 0.65 dark / 0.18 light, offset (0, 24), blur 60] and [black α 0.40 / 0.10, offset (0, 2), blur 10]; inside a transparent Material with RoundedRectangle radius 20 and 0.5 dp `ring` side, clip antiAlias. Nub: 12 × 12 square of panel colour rotated 45°, half outside the edge facing the anchor: above → left nub − 6, bottom −6; below → left nub − 6, top −6; left → right −6, top nub − 6; right → left −6, top nub − 6. Stack(clip none). No scrim, no blur (video stays untouched).
- **`showSheetOrPanel<T>({context, builder, size, sides, anchor, region, panelSheet = false})`**: bounds = screen minus system padding. Placement only when anchor given AND `context.isLargeScreen`, via placePanel with `avoid: PanelAvoidScope.of(context)`. No placement → `showOnsetSheet(panel: panelSheet)` with content in `SheetPresentation(panel: false, surface: panelSheet ? colors.panel : null)`. Else unfocus and push `_PanelRoute(placement, openedAt: screen size, builder, capturedThemes, barrierLabel: modalBarrierDismissLabel)`.
- **`_PanelRoute extends PopupRoute`**: transparent barrier, dismissible (tap outside closes), transition 220 ms in, 160 ms out. `buildPage`: content = `Semantics(scopesRoute, namesRoute, explicitChildNodes)` → OnsetPanelSurface; wrapped in captured themes and `SheetPresentation(panel: true)`; a Builder reading MediaQuery: if size ≠ openedAt (rotation/window resize) → `_closeStale()` (post-frame pop if current else removeRoute; once); positions content at `panelClearOfKeyboard(rect, media)`. `buildTransitions`: one CurvedAnimation for the route life (curve standard, reverse emphasizedAccelerate). Reduce motion → fade only. Otherwise fade + "pop": scale 0.97 → 1.0 and translate y 6 → 0 about the origin at the nub on the anchor-facing edge (above: (nub, h); below: (nub, 0); left: (w, nub); right: (0, nub)).
- **`panelClearOfKeyboard(rect, media)`**: limit = screenHeight − viewInsets.bottom − 8; unchanged if no keyboard or rect.bottom ≤ limit; else top = `_within(limit − h, padding.top + 8, rect.top)` (never below where it was, never above status bar), bottom = min(top + h, limit), never < top.
PC: these panels are the natural desktop popover — on Windows every window ≥ 600 shortest side uses them; Escape and outside click dismiss; window resize closes a stale panel (same rule).

### lib/widgets/state_views.dart

Shared empty / error / logged-out states. Uses `FeedColors` (from `screens/home/stream_list/stream_card_parts.dart`; dark: text #F5F5F5, body #D6D6D6, secondary #A1A1A1, tertiary #8A8A8A, surface #141414, raised #1E1E1E, hairline 0x1AFFFFFF, pillBorder 0x1FFFFFFF, well #141414; light: text #0A0A0A, body #3A3A3A, secondary #6B6B6B, tertiary #6B6B6B, surface #FFFFFF, raised #F0F0F0, hairline 0x14000000, pillBorder 0x1F000000, well #EDEDED).

- `isConnectionProblem(message)` = `isConnectionProblemText(message)` — true when the message equals, in ANY supported locale, `apiErrorUnableToConnect` or `apiErrorNetwork` (the worded NetworkException). Errors are compared by their displayed text.
- `onFillColor(fill)`: luminance L; contrast vs black = (L + 0.05)/0.05, vs white = 1.05/(L + 0.05); returns #0A0A0A if black contrast ≥ white contrast, else white (the accent can be any colour the viewer picked).

**`FeedStatusView`** constructors:
- default `({message, detail, icon, glyph, action, onAction, actionGlyph, actionIcon, signalOff = false, primaryAction = false})`.
- `.empty({message, detail, glyph})`: signalOff = (glyph == null) — the "signal turned off" mark; with a glyph (Activity's bell) the glyph in its disc plus optional detail.
- `.error({message, required onRetry})`: glyph offline if connection problem else alert; action text `commonTryAgain` ("Try again"); action glyph retry.
- `.signIn({message, required onConnect})`: glyph account; action `commonConnectWithTwitch`; primaryAction true (accent pill).
Build: large = `context.isLargeScreen`. `quiet` (Activity empty style) = !signalOff && no action && no standard action && detail != null. Mark: signalOff → `SignalOffMark(size: large ? 104 : 88)`; else circle `markSize` = quiet 64 / large 88 / phone 72, fill surface, 0.5 border pillBorder, containing StateGlyph (colour secondary, size quiet 28 / large 34 / phone 30) or Icon (icon ?? info_outline_rounded). Layout: Center → Padding(LTRB 32, 24, 32, 48) → Column(min, spacing quiet 12 / large 18 / phone 16): ExcludeSemantics(mark); message capped at width 360 (large) / 260, centred, fontSize quiet 18 / signalOff (20 large, 17 phone) / other (20 large, 16 phone), height 1.3 quiet else 1.4, weight w700 when signalOff, quiet or large else w600, letterSpacing −0.255 (−0.015 × 17), colour text; detail capped 280, 14 / 1.5, secondary; action → `_PrimaryPill` (primaryAction) or `StatePill(glyph: actionGlyph, icon: actionIcon ?? visibility_outlined, height: large 48 / 44)`.
- `_CappedWidth` / `_RenderCappedWidth` (RenderConstrainedBox maxWidth): also caps the width used by intrinsic height queries (min/max intrinsic height computed at `min(width, maxWidth)`), so a status inside `SliverFillRemaining` measures its wrapped height correctly and does not overflow a short window.
- **`SignalOffMark({size})`**: circle with 0.5 hairline ring; inside padding 16 a disc (surface fill, 0.5 pillBorder) with a centred 12 × 12 dot #3A3A3A (dark) / #C4C4C4 (light).
- **`StatePill({label, onPressed, glyph, icon, height = 44, compact = false})`**: OutlinedButton.icon — minimum height 36 (compact) or `height`, padding h14 (compact) / h20, background raised (#1E1E1E), fg text, 0.5 pillBorder side (dark 0x1FFFFFFF = 12 % via `hairlineRaisedDark`, light 0x1F000000; the code comment "16 % hairline" is wrong — the value wins), StadiumBorder, text Inter 13 (compact) / 14 w600; icon = StateGlyph(colour text, size 15 compact / 17, stroke 2) or Icon(icon ?? refresh_rounded).
- **`_PrimaryPill`**: `PressScale(FilledButton(min height 48, padding h24, bg accent (onsetColors.live), fg onFillColor(accent), stadium, Inter 15 w700))`.
- **`InlineStatus({message, glyph = alert, onRetry, padding = h16 v12})`** and `.error` (offline glyph for connection problems): Center → Wrap(center, spacing 12, runSpacing 10): Row(min) [StateGlyph(secondary, 18) + 8 gap when glyph non-null (null = nothing found, no mark), Flexible message 14 / 1.4 / w500 secondary centred]; and if retryable `StatePill(commonTryAgain, glyph retry, compact)`.
Strings: commonTryAgain "Try again" / "Réessayer"; commonConnectWithTwitch "Log in with Twitch" / "Se connecter avec Twitch" (see Strings table).

### lib/widgets/skeleton_loader.dart

Loading placeholders in the exact shape of what loads, with a discreet screen-wide sheen.

**`SkeletonLoader({width, height, borderRadius})`**: an `AnimationController` (duration 1600 ms) repeated only to drive repaints (the band position comes from the frame clock); stopped under reduce motion (still block), started otherwise in `didChangeDependencies`. Colours: dark base `skeletonDark` #232323, highlight `skeletonSheenDark` #2F2F2F; light base `colorScheme.surfaceContainer`, highlight `lerp(base, white, 0.6)`. Sizing exactly like the decorated Container it replaced: `LimitedBox(maxWidth: 0, maxHeight: 0, ConstrainedBox(expand, SkeletonSheenBox(...)))` (fills bounded constraints, collapses to zero when unbounded), wrapped in `BoxConstraints.tightFor(width, height)` when either is given. Default radius 8 (radiusSmall).

**`SkeletonSheen`** (shared sweep): `period = 1600 ms`; `bandWidth = 300.0` (one repeat of the gradient; each period moves exactly one repeat so the loop has no seam); `_from = −150.0`; `direction = Offset(sin 100°, −cos 100°)` = (0.9848, 0.1736) (CSS 100°: a hair below horizontal, moving right and slightly down). `originAt(timestamp)`: phase = (µs mod 1.6 s)/1.6 s; origin = direction × (−150 + 300 × Curves.easeInOut(phase)). Curves.easeInOut = Cubic(0.42, 0, 0.58, 1).

**`SkeletonSheenBox`** (LeafRenderObjectWidget) → **`RenderSkeletonSheen`** (RenderBox, sizedByParent, dry layout = constraints.smallest): listens to the ticker (markNeedsPaint) while attached. Paint: base colour; if sheen: screen origin from `SchedulerBinding.currentSystemFrameTimeStamp`; local start = offset + origin − localToGlobal(0); `ui.Gradient.linear(start, start + direction × 300, [base, highlight, base], stops [0.3, 0.5, 0.7], TileMode.repeated)`; `debugLastSheenOrigin` (visibleForTesting) records the global origin (null without sheen). Draws `borderRadius.toRRect(offset & size)`. One band for the whole screen: a thumbnail and the text lines beside it show the same band crossing them; painted with a shader (no layer, no saveLayer); ticker stops off-screen (TickerMode).

**`SkeletonText({required height, minWidth, maxWidth, borderRadius})`**: random width uniformly in [min, max] where min = minWidth ?? 30 % screen width, max = maxWidth ?? 80 % (new Random each build); radius default 4.

**`ChannelSkeletonLoader({showSubtitle = true, index = 0})`**: dense ListTile, contentPadding h16 v4; leading 32×32 circle (radius 16); title SkeletonText(16, 60–140); subtitle SkeletonText(14, 30–80) only when showSubtitle && index < 4 (simulates live channels at top).

**`StreamCardSkeletonLoader({showThumbnail = true, showCategory = true})`**: padding top/bottom 8, left/right 16 (with thumbnail) or 4, plus system padding left/right. Row: Flexible AspectRatio 16/9 skeleton with `kCardBorderRadius` (8) when showThumbnail; Flexible(flex 2) padding left 12 Column(start, spacing 8): Row(spacing 4) [20×20 circle (radius 10), Expanded SkeletonText(16, 60–120)], SkeletonText(14, 100–200) title, SkeletonText(14, 60–120) category if shown, SkeletonText(14, 50–90) viewers.

### lib/widgets/blurred_container.dart

- `enum GradientDirection { up (top app bars: opaque at top), down (bottom bars: opaque at bottom), none (solid) }`.
- `BlurConfig`: sigmaX 16.0, sigmaY 16.0, lightModeAlpha 0.6, darkModeAlpha 0.3.
- `BlurredContainer({child, padding, sigmaX, sigmaY, backgroundAlpha, forceDarkMode, gradientDirection = none, onlyWhenSettled = false})`: isDark = forceDarkMode ?? theme dark; alpha = backgroundAlpha ?? (dark 0.3 / light 0.6); background colour = black when forceDarkMode == true else scaffold background. Decoration: none → solid background at alpha; up → LinearGradient top→bottom colours [bg, bg α0.7, bg α0.3, bg α0] stops [0, 0.3, 0.7, 1]; down → [bg α0, α0.3, α0.7, bg] same stops. Filter `ImageFilter.blur(sigmaX: sigmaX ?? 16, sigmaY: sigmaY ?? 16)` (overridable per axis; the photo viewer passes 4 / 4). `ClipRect(onlyWhenSettled ? SettledBlur(filter, content) : BackdropFilter(filter, content))`; content = Container(padding, decoration, child).
Hard rule: a page that slides over/away from a video must use `onlyWhenSettled` — nothing may ever blur over a video texture. Proven by `test/widgets/twitch_web_page_test.dart` (the header never blurs while the page slides over a channel); `test/guards/no_blur_over_video_test.dart` separately covers the chat photo viewer scrim and `OnsetNotification(overVideo: true)`.

### lib/widgets/settled_blur.dart

`SettledBlur({filter, child, enabled = true})`: a BackdropFilter that blurs only while its page is in place. Listens to `ModalRoute.of(context)?.animation` status (re-subscribing when the route animation changes); settled = status null or `completed`. While the route is pushing or popping (forward/reverse/dismissed), `BackdropFilter(enabled: false)` so the page below (Live feed's muted preview, a channel's video) is never blurred mid-transition; child drawn either way. `enabled: false` never blurs (layouts without glass).
PC: same rule with Slint/Skia — disable backdrop blur during page transitions over any video surface.

### lib/widgets/global_mini_player.dart

Floating, draggable in-app mini player rendered above the whole app (installed in `MaterialApp.builder` as `Positioned.fill(GlobalMiniPlayer())`). Stays visible while navigating; tap to restore; drag to any corner. Dragging is driven by ValueNotifiers and paint-time transforms so the video platform view is never rebuilt or re-laid-out mid-drag.

- `GlobalMiniPlayer.radius = 16.0`.
- `static restore(store)`: needs userLogin, userId, displayName; pushes `VideoChat(userId, userName: displayName, userLogin)` (route name VideoChat.routeName) on the global navigator WITHOUT closing the mini — the channel screen adopts the live player back, no reload.
- State: `_offset` ValueNotifier<Offset?>; `_dragging` ValueNotifier<bool> (window lifts to 1.04 and the four landing corners show); `_corner` (rest corner, initially `MiniCorner.topRight`; null while dragged/flying; stored as a corner so it stays a corner when the area changes); `_drawn` (last drawn offset); `_snapController` 240 ms with `_snapCurve` = Curves.easeOutCubic (created once); `_snapAnim` Tween begin current/end target → updates `_offset`; on completion (or cancel) when it reached target, `_corner = corner`.
- `_position(area, offset)`: corner set → `area.at(corner)`; else `area.clamp(offset ?? area.initial)`.
- Build (Observer on `MiniPlayerStore`): hidden (SizedBox.shrink) unless `store.visible && store.player != null`. `area = MiniWindowArea.fromMetrics(MediaQuery.sizeOf, MediaQuery.paddingOf, chrome: store.shellChrome)` (only those two MediaQuery aspects, so a keyboard sliding under does not rebuild every frame).
- Content (built once per Observer build): SizedBox(window size) → DecoratedBox(radius 16, shadows [0x99000000 offset (0,18) blur 40], [0x80000000 offset (0,2) blur 8]) — the only floating window that needs a shadow, to detach from bright thumbnails → ClipRRect(16) → black ColoredBox → Stack(expand): `IvsTextureVideo(videoStore: player)`; inner hairline border 0.5 dp 0x29FFFFFF (IgnorePointer); gesture layer `Semantics(container, button, label: miniPlayerReturn)` + GestureDetector(opaque): tap → restore; onPanDown → stop snap, `_offset = _drawn ?? _position(...)` (from where drawn, even mid-glide), `_corner = null`; onPanStart → dragging true; onPanUpdate → offset = clamp(offset + delta); onPanEnd → dragging false, snap to `area.nearest(offset)`; onPanCancel → dragging false. Top-right `_CloseButton(onPressed: store.close)`.
- Window stack: `Positioned.fill(IgnorePointer(RepaintBoundary(_CornerTargets)))` behind the window; window via `ValueListenableBuilder(_offset)` → `MiniWindowPlacement(offset: _position(area, offset), glide: _corner != null, onDrawn: save)` → `ValueListenableBuilder(_dragging)` → `AnimatedScale(scale: dragging && !reduceMotion ? 1.04 : 1, duration 90 ms, curve standard)`.
- Wrapped in `PipWidget(pipLayout: PipActionsLayout.mediaOnlyPause, onPipAction: player.handlePausePlay, pipChild: black + IvsTextureVideo)`: if the OS enters PiP while the mini is up, the PiP surface shows only the video. Mounted only while the mini is visible so it never competes with the channel screen's PipWidget.
- **`MiniWindowPlacement({offset, glide, child, onDrawn})`**: `glideDuration = 320 ms`; TweenAnimationBuilder<Offset>(end: offset, duration glide && !reduceMotion ? 320 ms : 0, curve standard) → Transform.translate; reports every drawn value (mid-glide included). A corner-resting window glides when the header/bar height changes; drags/snaps move directly.
- **`MiniWindowArea`** (immutable): `margin = 12.0`, `widthFraction = 0.42`. `fromMetrics(screen, padding, {chrome})`: window width = 0.42 × screen width, height = width × 9/16. cover = chrome (shell header/bottom bar insets) ?? (top: padding.top + kToolbarHeight (56), bottom: padding.bottom). `top = cover.top + 12`; `bottom = max(top, screenH − windowH − cover.bottom − 12)` (too short a screen: header wins). left = 12; right = max(12, screenW − windowW − 12). `initial` = top-right. `clamp(offset)`; `at(corner)`; `nearest(offset)` — compares the window centre to the screen centre (left if centre x < screenW/2, top if centre y < screenH/2); `snap(offset)`. `MiniWindowArea.of(media, {chrome})`.
- `enum MiniCorner { topLeft, topRight, bottomLeft, bottomRight }` with `left`/`top` flags.
- **`_CloseButton`**: Tooltip `miniPlayerClose`, Semantics(button), 44 × 44 target, aligned top-right, 26 × 26 disc margin top 6 right 6, colour 0x9E000000 (black 62 %), 0.5 border 0x2EFFFFFF, `PlayerGlyph(close, white, size 14, stroke 2.4)`.
- **`_CornerTargets`**: only while dragging; painter `_CornerTargetsPainter(area, nearest, accent)`: for each corner the window rect deflated 0.75, rounded 16, dashed 6 on / 4 off (step 10) along path metrics; each dash stroked by `cornerTargetStrokes(nearest, accent)` = [(0x73000000 halo, 3.5), (nearest ? accent α 0.9 : 0xB3FFFFFF, 1.5)] — readable over a dark stream and a light page.
Strings: miniPlayerReturn "Return to stream" / "Revenir au live"; miniPlayerClose "Close miniplayer" / "Fermer le mini-lecteur".
PC: on desktop, the mini player is an in-window overlay with the same geometry (42 % of window width, 16:9, 12 px margins, corner snapping, mouse drag). Optionally a separate always-on-top OS window replaces Android PiP (see PC equivalent).

### lib/widgets/follow/follow_actions.dart

`FollowActions` — follow/unfollow of channels and categories through Twitch GQL (`TwitchViewerActionsService`), provided app-wide in main.
- Ctor: `service`, `api` (Helix), `categories` (TwitchFollowedCategoriesService), `webToken()` (twitch.tv web session token), `tvToken()` (optional Twitch TV device session token), `viewerId()`, `connectWebSession()` (AuthStore.ensureTwitchWebToken), `now()` (injectable clock).
- Constants: `suggestionLimit = 5`, `connectCooldown = 1 minute`.
- Token choice `_token`: the TV token when non-empty (it passes Twitch's integrity check), else the web session token, else ''.
- `isSignedIn` = viewerId non-null. `canFollowInApp` = token non-empty && signed in.
- `connectWebSession()`: true if already can follow; false if not signed in; false if the last failed attempt was less than 1 minute ago (cooldown); else calls `_connectWebSession()` (errors logged by runtime type only), recomputes `canFollowInApp`, records failure time if still not connected.
- `followChannel/unfollowChannel(channelId)`, `followCategory/unfollowCategory(categoryId)` → `FollowResult` via the service with the chosen token.
- `followsCategory(categoryId)`: null if not signed in or no web session; else `getFollowedCategories(authToken: web session)` → null on failure, else whether any matches.
- `followsChannel(channelId)`: Helix `isFollowing(userId: viewer, broadcasterId)`; null on error.
- `channelFollowState(login)` → `(id, following)` via getUser + isFollowing; null on error/not signed in.
- `suggestionsAfterFollowing(channelId)`: viewer required; current stream's `gameId` via getStreamsByIds (none/empty → []); in parallel `getStreamsUnderCategory(gameId)` and `getFollowedStreams(id: viewer, first: 100, quiet: true)`; exclude followed user ids and the channel itself; take 5; unmodifiable; errors → [].
`FollowResult` enum (model): done, tooManyFollows, unverifiedEmail, unverifiedPhone, unverifiedPhoneAndEmail, forbidden, refused, noWebSession, signedOut, needsTvSession, tvSessionExpired, integrityRefused, gqlError, failed; `succeeded` (done), `needsWebSession` (noWebSession/signedOut), `needsTvConnect` (needsTvSession/tvSessionExpired), `canRetry` (refused/gqlError/failed).

### lib/widgets/follow/follow_flow.dart

UI flow around follow actions. `enum FollowTarget { channel, category }`.

**`FollowFlow`** (static): keys `confirmKey = ValueKey('follow-confirm')`, `tvConnectKey = ValueKey('follow-tv-connect')`.
- `actionsOf(context)` → FollowActions only if provided and signed in, else null (ProviderNotFoundException caught).
- `pending` ValueNotifier<Set<String>> of ids in flight; `isPending(id)`.
- `openLogin` (replaceable for tests) default pushes `LoginWebView`.
- **`toggle(context, {target, id, name, following, onChanged})` → bool?** (new state or null):
  1. Ignore if id pending. Capture root navigator, actions, TV session store.
  2. No actions or not signed in → snackbar `followSignInNeeded` with action `followLogInAction` (opens login on root navigator); return null.
  3. unfollow = following == true; unfollow requires `_confirmUnfollow` dialog (title `unfollowConfirmTitle(name)`, body `unfollowConfirmBody`, action `unfollowAction`, Cancel `commonCancel`).
  3b. After the dialog, `isPending(id)` is checked AGAIN (another tap may have started a request meanwhile) → return null.
  4. Mark pending; optimistic `onChanged(!unfollow)`; `_send`; finally remove pending.
  5. `needsTvSession` while the TV session status is `expired` → `tvSessionExpired`.
  6. Failure → `onChanged(following == true)` (revert).
  7. Show from the original context if mounted, else root.
  8. `needsTvSession` and `tvSession.shouldPrompt()`: only if the root navigator context exists and is mounted → `markPrompted()`, then `offerTvSession` dialog (if still mounted), return null; otherwise it falls through to step 9 (the needsTvSession snackbar with the TV-connect action).
  9. `showResult(...)` with a retry closure re-calling toggle on the root context with following = unfollow.
  10. Success → `HapticFeedback.lightImpact()`; return !unfollow.
- `offerTvSession(context, store, {message, onShown})`: OnsetDialog(title `twitchTvPromptTitle`, message ?? `twitchTvPromptBody`, actions [text `twitchTvPromptLater` → false, primary key tvConnectKey `twitchTvConnectAction` → true]); if true, mounted and `store.hasAccount` → `showTwitchTvConnectSheet`.
- `_send(actions, target, id, following, unfollow)`: hadSession = canFollowInApp; `connectWebSession()` false → `noWebSession`; if there was no session before or `following` unknown, read the current state (followsChannel/followsCategory) and if it already equals the desired state → `done` (no request); else call the matching follow/unfollow.
- `followFromPrompt(context, {id, name, following, confirm, onChanged})` (deep link `?followChannel=true`): no-op if already following; optional `confirmFollow` (title `followConfirmTitle(name)`, body `followDeepLinkBody`, action `channelFollow`); toggle channel follow; on success `suggestAfterFollowing`.
- `_showSnackBar`: hide current, show new SnackBar(text, action).
- `showResult(context, result, {name, followed, retry})`: success → `followDone(name)` or `unfollowDone(name)`; failure → `followError(status: result.name)` with action: TV connect needed → `twitchTvConnectSnackAction(context)`; web session needed → log-in action; retryable and retry given → `commonRetry`; else none.
- `suggestAfterFollowing(context, {channelId, name})`: suggestions non-empty → `showOnsetSheet(FollowSuggestionsSheet)`.

**`FollowSuggestionsSheet({name, suggestions, actions})`**: keys `followAllKey = ValueKey('follow-all')`, `rowKey(id) = ValueKey('follow-suggestion-<id>')`. State `_followed`, `_busy` sets. Layout: ConstrainedBox(maxHeight 85 % screen) → ListView(shrinkWrap, primary false, padding bottom 16): header (padding LTRB 16,6,16,2) `Semantics(header)` `followSuggestionsTitle(name)` subtitle style; subtitle line (LTRB 16,0,16,8) `followSuggestionsSubtitle` rowDetail secondary; one row per suggestion; then (LTRB 16,12,16,0) `SheetButton(followAllKey, followAll, large, expand, disabled when none remaining or busy)`.
Row (padding h16 v8, Row spacing 14): `InitialAvatar(name)` (readable name via getReadableName), Expanded Column(start, spacing 2): name 1 line ellipsis row style, detail `"<game> · <streamViewers(count)>"` (game omitted if empty) 2 lines rowDetail secondary; trailing: busy → 20 dp CircularProgressIndicator(stroke 2); else SheetButton(`channelFollowing` text tone disabled when followed, else `channelFollow` primary → follow one and showResult).
`_followAll`: confirm (title `followAllConfirmTitle(count)`, body `followAllConfirmBody`, action `followAll`); follow sequentially; stop at first failure; snackbar `followAllDone(count: done)` or `followAllStopped(done, name, reason: followError(status))`.

**`FollowPendingGate({id, child})`**: listens to `pending`; while busy: `Semantics(enabled: false)`, `AbsorbPointer`, `AnimatedOpacity(0.5, 160 ms, easeOut)`.

### lib/widgets/recommendations/recommended_channels.dart

Twitch recommendations (GQL via `TwitchSocialService`), "Not interested", a home shelf and the "Similar channels" sheet.

- **`Recommendations({service, token})`**: `of(context)` → null without a TwitchSocialService provider; token = `AuthStore.twitchWebToken` (empty → null, meaning signed-out/anonymous recommendations). `load(section, {channelLogin})` → `service.recommendations(section, channelLogin, authToken: token)` (`RecommendationSection.recommended` / `.similar`). `tellTwitch(channel, reason)` → `ViewerActionOutcome.signedOut` without token, else `service.notInterested(channelId: userId, reason, authToken)`.
- **`openRecommendedChannel(context, channel, {replace = false})`**: route name VideoChat.routeName → `VideoChat(userId, userName: displayName, userLogin: login)`; push or pushReplacement.
- **`pickNotInterestedReason(context, {name, sendsToTwitch})`**: showOnsetSheet → ListView(shrinkWrap): header (LTRB 16,6,16,8) `notInterestedTitle(name)` subtitle style; if sendsToTwitch a note (LTRB 16,0,16,8) `notInterestedSentToTwitch` rowDetail secondary; one SheetRow per `NotInterestedReason` (notInterested, offensive, other) with key `ValueKey('not-interested-<reason>')`, label `notInterestedReasonLabel`, glyph flag for offensive else close; tap pops the reason.
- `notInterestedReasonLabel(l, r)`: notInterested → `notInterestedReasonNotInterested`, offensive → `notInterestedReasonOffensive`, other → `notInterestedReasonOther`.
- **`markNotInterested(context, channel, {tellTwitch, signedIn})`**: pick reason (null → stop); `Haptics.light()`; `settings.markNotInterested(userId, displayName)` (local hide, persisted in settings `notInterestedChannels` map); if signed in send to Twitch; snackbar: not signed in → `notInterestedHiddenHere(name)`; done → `notInterestedDone(name)`; any other outcome → `notInterestedOnlyHere(name)`; action `commonUndo` → `settings.clearNotInterested(userId)`.
- **`RecommendationsShelf({load})`** (`shelfKey = ValueKey('recommendations-shelf')`): loads once in initState (custom `load` or recommended section); nothing shown until loaded / without settings. Observer filters out `settings.notInterestedChannels`; empty → nothing. large = isLargeScreen; gutter 28 tablet / 16 phone (+ system padding); tile width 132 tablet / 112 phone; textScale = `MediaQuery.textScalerOf(context).scale(1)`. Layout: Padding(top 14, bottom 8) Column(stretch, min, spacing 12): `FeedSectionTitle(recommendationsTitle)` (Inter 19 w700 ls −0.38 h 1.2, header semantics) aligned start with gutter padding; horizontal `ListView.separated` of height `tileWidth × 0.62 + 66 × textScale`, separator 12, padding gutter, items `RecommendedChannelTile(channel, width, onTap: open, onNotInterested: markNotInterested if recommendations available)`.
- **`RecommendedChannelTile({channel, width, onTap, onNotInterested})`**: avatar diameter = width × 0.62. SizedBox(width) → `Semantics(button, onLongPressHint: liveFeedNotInterested when long-press available)` → PressScale → GestureDetector(opaque, tap, long-press → not interested) → Column(spacing 4): ClipOval avatar (OnsetCachedNetworkImage cover, or InitialAvatar(name, size avatar) when no URL), SizedBox(2), name (getReadableName) 1 line ellipsis centred Inter 13 w700 text colour, then category ?? `streamViewers(count: viewers ?? 0)` 1 line Inter 12 secondary.
- **`SimilarChannelsSheet({name, load, onOpen, onNotInterested})`** (`rowKey(id) = ValueKey('similar-<id>')`): loads once; ConstrainedBox(maxHeight 85 %) → Observer → ListView(shrinkWrap, primary false, padding bottom 16): header (LTRB 16,6,16,8) `recommendationsSimilarTitle(name)`; loading → padding 24 centred adaptive progress; empty (after filtering hidden) → (LTRB 16,8,16,8) `recommendationsEmpty` rowDetail secondary; else rows. Row: InkWell(tap → onOpen) padding h16 v8 Row(spacing 14): 40 dp ClipOval avatar or InitialAvatar(40); Expanded Column(name row style 1 line; detail `"<category> · <streamViewers>"` 2 lines when non-empty); if onNotInterested: IconButton(key `ValueKey('similar-not-interested-<id>')`, tooltip `liveFeedNotInterested`, SheetGlyph more, secondary).
- **`showSimilarChannels(context, {login, name})`**: no recommendations → nothing; else showOnsetSheet(SimilarChannelsSheet(load similar for login, onOpen: pop sheet then open channel with **replace** (replaces the current channel screen), onNotInterested: markNotInterested from the sheet context)).

### lib/widgets/report/report_sheet.dart

In-app reporting through Twitch GQL (`TwitchReportService`) with a twitch.tv web fallback.
- `typedef ReportSender = Future<ViewerActionOutcome> Function(ReportReason reason, String description)`.
- **`reportFromOnset(context, {target, title, fallbackUrl})`**: `_senderFor` null (no service, no web token, or target not `TwitchReportService.isReportable`) → if a fallback URL exists, confirm with `_confirmWebReport` then `TwitchWebPage.open(title, url)`; else nothing. Otherwise `showOnsetSheet<ViewerActionOutcome>(ReportSheet(target, send))`; null (dismissed) → nothing; `done` → light haptic; snackbar `reportSent` on done else `viewerActionResult(status: outcome.name)`.
- `_senderFor`: reads TwitchReportService and AuthStore (ProviderNotFound → null); sender calls `report(target, reason, description, authToken: twitchWebToken)`.
- `_confirmWebReport`: showDialog(barrierColor 62 % scrim) OnsetDialog(title `reportWebFallbackTitle`, message `reportWebFallbackBody`, actions [Cancel text → false, key `ReportSheet.webFallbackKey` `reportOpenOnTwitchAction` → true]).
- **`ReportSheet({target, send})`**: keys `sendKey = ValueKey('report-send')`, `webFallbackKey = ValueKey('report-web-fallback')`, `reasonKey(reason) = ValueKey('report-reason-<name>')`. State: details controller, `_reason`, `_sending`. Build: `AnimatedSwitcher(duration: disableAnimations ? 0 : 260 ms, in easeOutCubic, out easeInCubic, transition: Fade + Slide from Offset(0.06, 0))` between `_ReasonPicker` (key 'reasons') and `_Confirmation` (key 'confirm'). `_send(reason)`: guarded, sets sending, awaits send(reason, details text) with NO try/catch, pops the outcome. If the sender throws, `_sending` stays true: Send and Back stay disabled and the sheet only closes by swiping down (defect; PC maps an exception to `ViewerActionOutcome.failed` and pops it).
- `_ReasonPicker`: SingleChildScrollView Column: title (LTRB 16,4,16,2, header semantics) `reportTitle(kind: target.kind.name, name: target.name)` SheetText.title; `SheetSectionLabel(reportWhy)`; a SheetRow per `target.reasons` with label `reportReason(reason: name)` and chevron end; SizedBox(8).
- `_Confirmation`: bottom padding = keyboard inset + 12; `SheetBackHeader(title: reportConfirmTitle, onBack)` (back disabled while sending → no-op); reason as title (LTRB 16,2,16,6); info row (LTRB 16,4,16,12, spacing 10): flag glyph 16 secondary (top padding 1) + `reportConfirmBody` Inter 13/1.45 secondary; `SheetTextField(label reportDetailsLabel, hint reportDetailsHint, maxLength TwitchReportService.maxDescriptionLength, counter, maxLines 3)` with h16 padding; `SheetStatusLine(busy: sending)`; (LTRB 16,4,16,0) `SheetButton(sendKey, reportSend, large, expand, disabled while sending)`.

### lib/widgets/share_sheet.dart

- `typedef ChatLinkSender = Future<void> Function({broadcasterId, senderId, message})`.
- **`showShareSheet(context, {url, channelId, channelName})`**: reads AuthStore, TwitchApi, WhisperStore (each optional). Not logged in or no API → plain `shareLink(context, url)` (system share). Else `showOnsetSheet(ShareSheet(url, viewerId, channelId, channelName, sendToChat: api.sendChatMessage, whisperStore, onShare: shareLink, pickWhisperTarget: pickWhisperTarget(sheetContext, me: viewerId)))`.
- **`ShareSheet`**: ListView(shrinkWrap): `SheetSectionLabel(shareTitle)`; if channelId: SheetRow(key 'share-chat', glyph addChat, label channelName == null ? `shareSendToChat` : `shareSendToChannelChat(name)`) → `_sendToChat`; if whisper store: SheetRow(key 'share-whisper', glyph whisper, `shareSendAsWhisper`) → `_whisper`; SheetRow(key 'share-system', glyph share, `shareOther`) → pop then system share.
- `_sendToChat`: name = `channelName ?? ''`; pops the sheet first, sends the URL as a chat message in the channel (Helix sendChatMessage with broadcasterId/senderId); snackbar `shareSentToChat(name)` (with an empty name when channelName is null — see Known Android defects); `UnauthorizedException` → `shareChatLogInAgain`; other error → `shareChatFailed`.
- `_whisper`: pick target (null → stay); pop sheet; `store.sendTo(userId, login, displayName, text: url)`; snackbar failure text or `shareWhisperSent(name: displayName)`.

### lib/widgets/user_actions_modal.dart

**`UserActionsModal({authStore, name, userLogin, userId, showPinOption = false, isPinned, showProfile = true})`** — the "More" sheet of the user card. ListView(primary false, shrinkWrap, padding bottom 10), rows in this order:
1. (if showProfile) glyph profile, `userActionsProfile` → pop, `ChannelProfileScreen.open(login, userId, displayName)`.
2. glyph videos, `userActionsVideos` → pop, `ChannelVideosScreen.open(userLogin, displayName)`.
3. (if showPinOption) glyph pin, `userActionsUnpin(name)` when pinned else `userActionsPin(name)` → pin: assigns a new list `[...pinnedChannelIds, userId]`; unpin: `[...pinnedChannelIds..remove(userId)]` — the cascade removes from the store's EXISTING list in place before the copy is assigned (defect; the PC port removes from a copy); then pop.
4. (logged in) glyph block, `userActionsBlock(name)` → `authStore.showBlockDialog(context, targetUser: name, targetUserId: userId, source: BlockSource.chat)` then pop if mounted.
5. (logged in) `GoLiveBellTile(channelId: userId, name)` (per-channel go-live notification toggle).
6. glyph settings, `userActionsChannelPrefs` → pop, `ChannelPreferencesScreen.open(channelId, name, settingsStore, loggedIn)`.
7. (logged in) `UserActionsFollowRow(name, userId)`.
8. glyph link, `userActionsCopyLink` → clipboard `https://www.twitch.tv/<userLogin>`, snackbar `userActionsLinkCopied`, pop.
9. glyph share, `userActionsShare(name)` → `shareLink(context, https://www.twitch.tv/<login>)` then pop.
10. glyph flag, `userActionsReport(name)` → `reportFromOnset(target: ReportTarget.user(userId, name), title: same label, fallbackUrl: twitchReportUri(login))`.

**`UserActionsFollowRow({name, userId})`**: empty userId → nothing. Loads `followsChannel(userId)` once via `FollowFlow.actionsOf`. Row inside `FollowPendingGate(id: userId)`: glyph heart, label `userActionsUnfollow(name)` when following else `userActionsFollow(name)`; tap → `FollowFlow.toggle(channel, following: _following (null = unknown), onChanged updates state)`; non-null result → pop the sheet.

### lib/widgets/onset_photo_view_dialog.dart

**`OnsetPhotoViewDialog({imageUrl, cacheKey, blurBackground = true})`** — full-screen zoomable image (stream thumbnails, emotes, profile pictures) with swipe-to-dismiss.
- State: scale state (initial), `_isFullResolution`, `_currentCacheKey` (starts as widget.cacheKey), `_dragOffset` (px, + down), reset controller 200 ms (Tween from drag to 0, linear), exit controller 220 ms with translate 0 → 1 and opacity 1 → 0 (Curves.easeOut), `_imageOpacity`, `_swipeDirection` (1 down / −1 up).
- Full-res URL = imageUrl with the first `-{width}x{height}` removed; `supportsFullRes` only when that changes the URL (stream thumbnails; emotes have no variant).
- fadeDistance = 20 % of screen height; buttons opacity = clamp(1 − |drag| / fadeDistance).
- Background: blurBackground → `BlurredContainer(sigma 4, 4, backgroundAlpha 0)` filling the screen; else (opened over a playing video from chat — never blur video) a plain `0x66000000` scrim.
- GestureDetector(opaque): vertical drags only while scale state is `initial` (not zoomed). Drag start stops the reset animation, direction = 1. End: dismiss if |drag| > fadeDistance OR |velocity| > 700 px/s; direction = sign(drag), or sign(velocity) when |drag| < 10; exit animation translates by `exit × screenHeight × 0.25 × direction` (on top of the drag) and fades, then pops. Otherwise animate back to 0 in 200 ms.
- `PhotoView(imageProvider: CachedNetworkImageProvider(full or normal URL, cacheKey: current (null forces fresh fetch for full-res), cacheManager: CustomCacheManager.instance), scaleStateChangedCallback, transparent background)` inside Transform.translate + Opacity.
- Close IconButton (tooltip `commonClose`, Icons.close in `overlayOnSurface` white) at top centre, AnimatedOpacity(buttonsOpacity, 100 ms).
- If supportsFullRes: at top = 80 % screen height, centred, SafeArea(top false), AnimatedOpacity(100 ms) `FilledButton.tonal` toggling resolution, label `photoViewThumbnail` when full-res else `photoViewOriginal`, text white.
PC: same dialog; mouse wheel zoom, drag to pan when zoomed, Escape closes; vertical drag dismiss kept for touch screens.

### lib/widgets/coach_mark.dart

**`CoachMark({feature, message, child, after, settings, delay = 600 ms})`** — a one-time lime bubble pointing at a new feature. Settings = given ?? `maybeSettings(context)`.
- First `didChangeDependencies`: nothing if no settings or `!settings.isNewFeature(feature.name)` (already seen: `seenNewFeatures` list in settings); if `after` is given and that feature is still new, wait (chaining: one coach mark at a time); otherwise schedule `Timer(delay, _show)` once.
- `_show`: needs mounted, no entry, an Overlay and a measurable target (own RenderBox rect relative to the overlay box). Records target and whether the control is hidden (`findAncestorWidgetOfExactType<IgnorePointer>()?.ignoring` — e.g. player controls faded out). Inserts an OverlayEntry and starts `_track()`: every frame (post-frame loop) re-measures; if rect or hidden changed, rebuilds the entry. Hidden or no target → empty.
- `_dismiss` → `markFeatureSeen(feature.name)` and remove entry. Dispose cancels timer and removes entry. Child is returned unchanged.
- **`_CoachBubble`**: width 240 clamped to screenW − 32. Below the target if target centre y < screenH/2 (top = target.bottom + 6) else above (bottom = screenH − target.top + 6). left = clamp(target.cx − w/2, 16, screenW − w − 16). Entrance: TweenAnimationBuilder 0 → 1 in 260 ms easeOutCubic: opacity t, scale 0.94 + 0.06 t. While the control is hidden the entry builds `SizedBox.shrink()`, so the entrance REPLAYS each time the target reappears. The entrance ignores reduce motion (always 260 ms) — see Known Android defects. `Semantics(liveRegion, container)` → `Material(key ValueKey('coach-mark'), colour OnsetTokens.accent #C8FF3D (raw lime, both themes), radius 14, elevation 6)` → padding LTRB 14,12,6,6 → Column(start, min): `newFeaturePill` upper-cased (Inter 10 w800 ls 0.6 #0A0A0A); 4 gap; message (padding right 8, Inter 14/1.35 w500 #0A0A0A); right-aligned TextButton `coachMarkGotIt` (fg #0A0A0A, Inter w700) → dismiss.

### lib/widgets/onset_chip.dart

**`OnsetChip({label, selected, onSelected, height = 34})`**; `filterHeight = 30.0` (filters inside a section: clip period, clip order). Selecting pill for views/filters.
- Tap: if not already selected `Haptics.selection()`; then `onSelected()`.
- `Semantics(button, selected, inMutuallyExclusiveGroup, label, onTap: select, excludeSemantics)` → PressScale → GestureDetector(opaque) → SizedBox(height 44: touch target) → Center(widthFactor 1) → `AnimatedContainer(duration motionDuration(200 ms), curve standard, height, padding h14 if height > 32 else h12, ShapeDecoration(colour selected ? accent α 0.10 : FeedColors.raised, StadiumBorder side 0.5 accent / pillBorder))` → Text(maxLines 1, Inter 13 / 1.2, w600 selected / w500, colour accent / body).

### lib/widgets/onset_scrollbar.dart

**`OnsetScrollbar({controller, child, padding})`** → `RawScrollbar(controller, thickness 5, radius 2.5, thumbColor onSurface α 0.3, interactive true (draggable), minThumbLength 48, padding)`; padding only offsets the thumb track (under app bars / nav bars).
PC: always-visible-on-hover thin scrollbar with the same metrics; draggable thumb; mouse wheel scrolls.

### lib/widgets/onset_notification.dart

**`OnsetNotification({message, onDismissed, showGradient = true, overVideo = false})`** — an in-flow info banner (e.g. chat notices). Row: Expanded Row(spacing 8)[Icon info_outline_rounded 20, Expanded Text(maxLines 3 ellipsis, w500)], plus close IconButton (close_rounded 20, compact, tooltip `commonDismiss`, colour onSurfaceVariant) when dismissible. Padding h12 v8. Container: overVideo (landscape full-screen chat over the live video) → opaque scaffold-colour ColoredBox (never blur over video); else `BlurredContainer(gradientDirection: showGradient ? up : none)`. Wrapped in `Semantics(container, liveRegion)`. Dismissible upward (`DismissDirection.up`, key ValueKey(message)) when onDismissed is set.

### lib/widgets/new_feature_pill.dart

`enum NewFeature { dataSaver, streamPreviews, clipDiscovery, hideViewerCount, notInterested, landscapeAlerts, cast, floatingPlayer }` — ids (`name`) stored in `SettingsStore.seenNewFeatures`; `isNewFeature(id)` = not in the list; `markFeatureSeen(id)` appends.
**`NewFeaturePill`**: Container padding h6 v2, colour `onsetColors.live` (theme-aware lime), radius 6; text `newFeaturePill` upper-cased, 10 / w800 / ls 0.6 / height 1.2, colour #0A0A0A. Used next to settings rows of new features ("NEW" / "NOUVEAU").

### lib/widgets/cast_button.dart

Chromecast (Google Cast) entry point. `typedef CastMediaSource = CastMedia? Function()` (built at tap time: url, title, subtitle, imageUrl, live, start).
- **`CastButton({media, onCastStarted, onCastStopped, store, color = white, size = 44, glyphSize = 22})`**: store = given ?? `sharedCastStore`; hidden when `!store.supported` (platform bridge absent, e.g. iOS build without Cast). Wrapped in `CoachMark(feature: NewFeature.cast, message: coachMarkCast)`. Observer: connected → tint = OnsetTokens.accent (lime) else `color`; Tooltip `castConnectedTo(device)` when connected with a device name else `castButton`; `Semantics(selected: connected)`; IconButton(key `ValueKey('cast-button')`, zero padding, tight size × size, highlight 0x1FFFFFFF, shrinkWrap) with Icons.cast_connected_rounded / cast_rounded, size glyphSize, shadow 0x66000000 blur 6 (readable over video) → `showCastSheet`.
- **`showCastSheet(context, {store, media, onCastStarted, onCastStopped})`** → showOnsetSheet(CastSheet).
- **`CastSheet({store, media, onCastStarted, onCastStopped, searchTimeout = 8 s})`**: initState → `store.beginDiscovery()` and a timer marking `_searchedLongEnough` after 8 s; dispose → cancel timer, `store.endDiscovery()`. `_started` → onCastStarted, `Navigator.maybePop`. `_castHere()` (already connected: send this video): media null → error `castNotReady`; `store.castHere(media, onLoaded: _started)` false → `castFailed`. `_castTo(device)`: media null → castNotReady; set connecting device; `store.castTo(device, media, onLoaded: _started)` false → clear connecting, `castFailed`.
- Build (Observer): ListView(shrinkWrap): `SheetSectionLabel(connected && device ? castConnectedTo(device) : castSheetTitle)`; body; error line `SheetStatusLine(busy false, message, ok false)` where error = local error ?? (store.loadFailed while connecting → castFailed); SizedBox(8).
- Body: `store.available == false` → note `castUnavailable`. Connected → SheetRow(key 'cast-this-video', Icon cast_connected_rounded 22, `castThisVideo`) and SheetRow(key 'cast-stop', Icon stop_circle_outlined 22, `castStop`, danger → `stopCasting()`, onCastStopped, pop). No devices → busy status line until 8 s, then note `castNoDevices` (before: `castSearching`). Devices → SheetRow(key `cast-device-<id>`, Icon tv_rounded 22, device name, trailing 18 dp spinner with semantics `castConnecting` for the connecting device, taps disabled while connecting; a load failure clears the connecting state).
- `_CastNote(text)`: padding LTRB 16,8,16,8, SheetText.body secondary.
PC: Windows has no Google Cast SDK; implement Cast discovery via mDNS `_googlecast._tcp` + CASTV2 protocol (rust crate `rust_cast`) so the feature is kept; DLNA optional.

### lib/widgets/notification_permission_prompt.dart

- `enum NotificationConsent { granted, refused, dismissed }`.
- `explainNotificationPermission(context)` → bool: `OnsetAlertDialog(title notificationPermissionTitle, message notificationPermissionMessage, actions [TextButton notificationPermissionNotNow → false, FilledButton notificationPermissionContinue → true])`; dismissed → false.
- `explainUnlessAllowed(context, allowed)`: `allowed()` (errors count as allowed) → true without dialog; else the explanation dialog (if still mounted).
- `askNotificationPermission(context, {allowed, request})`: explanation refused → `dismissed`; else `request()` → granted / refused. (Android 13 POST_NOTIFICATIONS pre-prompt.)

### lib/widgets/onset_alert_dialog.dart

**`OnsetAlertDialog({title, message, content, actions})`**: Material `AlertDialog(title: Text(title), content: SingleChildScrollView(Column(start: [message text, content, if actions: SizedBox(16), Row of actions each Expanded — one action full width, two actions 50/50 with 8 px gap after the first, more distributed evenly with 8 px gaps])))`. Inherits the theme's dialog shape (radius 16, hairline, background colour) and headlineSmall title (18, w700). The actions sit inside the content column, not in AlertDialog.actions.

### lib/widgets/onset_update_prompt.dart

In-app update flow (GitHub releases of `UPDATE_REPO`, see constants). Uses `SettingsColors`/`SettingsButton`/`SettingsDialog`/`confirmSettingsAction` from the settings kit and `SettingsGlyph(update)`.

**`offerUpdate(context, updater, update, {waitForResume})`**:
1. `_askUpdate` → true (Update) / false (Later). Not true → `updater.postpone(release)` (snooze this release) and stop.
2. `updater.canInstall()` false (Android "install unknown apps" not granted) → `confirmSettingsAction(title updateAllowTitle, message updateAllowMessage, confirm updateOpenSettings, danger false)`; refused → stop; else start waiting for the next resume (`waitForResume` or `_nextResume` via a one-shot AppLifecycleListener), `openInstallSettings()`, await back; still not allowed → snackbar `updateNotAllowed`; stop.
3. `showDialog(barrierDismissible false, barrierColor 62 % scrim, UpdateProgressDialog)` returning the error or null. Errors: `UpdateIntegrityException` → `updateCorrupted`; `UpdateInstallException` → `updateInstallFailed`; null or `UpdateCancelledException` → nothing; anything else → `updateDownloadFailed`. Snackbars use `AlertMessage(message, centered: false)`.

**`_askUpdate`**: content `UpdateAvailableDialog(release, currentBuild)`. Large screen → `Dialog(bg SettingsColors.dialog, no tint, elevation 0, insetPadding 40, radius 24 + 0.5 cardRing side)` with SizedBox(width 420) → scroll padding 24; not dismissible by barrier. Phone → `showModalBottomSheet(isDismissible false, enableDrag false, scrollControlled, no drag handle, bg SettingsColors.sheet, 62 % scrim, elevation 0, top radius 24)` → `PopScope(canPop false; back pops false = "Later")` → SafeArea(top false) → scroll padding LTRB 20,8,20,24 → Column: own handle 36 × 4 radius 2 colour handle with 16 margin below, then content. Never dismissed in passing: answered only by Update or Later.

**`UpdateAvailableDialog({release, currentBuild})`**: `Semantics(scopesRoute, namesRoute, explicitChildNodes, label: updateAvailable)` → Column(stretch, spacing 16):
- Row(spacing 14): 52 × 52 Stack(clip none): `OnsetMarkTile(size 52, radius 15)` (excluded from semantics) + badge at right −5 bottom −5: 24 dp circle #0A0A0A with 2 dp border in sheet colour, containing `SettingsGlyph(update, size 14, stroke 2.6, colour accent)`; Expanded Column(spacing 3): `updateNewBuild` (Inter 10.5 w800 ls 1.26 accent) and `Semantics(header)` `updateAvailable` (Inter 22 w800 ls −0.55 h 1.15 text).
- Column(spacing 4): `updateReady(build)` Inter 15 w600 text; info line joined with ' · ': `updateInstalledBuild(build)` if known, `updateSize(megabytes)` if apkSize > 0 (MiB, one decimal via ARB format), `updateChecked` — Inter 12.5 tabular secondary.
- Release notes (trimmed, if any): Container maxHeight 123, colour well, radius 14, 0.5 cardRing border, clip; Text(maxLines 6, clip, Inter 13 / 1.6, body) padding 14; bottom fade overlay 34 high gradient well α0 → well.
- Buttons Column(stretch, spacing 8): `SettingsButton(updateNow, primary, large, expand)` → true; `SettingsButton(updateLater, large, expand)` → false.

**`UpdateProgressDialog({updater, release})`**: Dio `CancelToken`; `_installing`, `_received`, `_total` (initially release.apkSize). Runs `updater.downloadAndInstall(release, cancelToken, onInstall: installing = true, onProgress: (received, total))`; pops the caught error or null. Dispose cancels if not cancelled. Build: `PopScope(canPop false)` → `SettingsDialog(title: updateInstalling / updateDownloading, content Column(spacing 14): LinearProgressIndicator(value: null (indeterminate) while installing or total ≤ 0 else clamp(received/total), minHeight 6, radius 3, colour accent, background switchOff); text `updateProgress(received MB, total MB)` or `updateSize(received MB)` Inter 13 tabular secondary; actions: Opacity(0.4 when installing) SettingsButton(commonCancel, disabled while installing or already cancelled → cancels)`.

**`mixin OnsetUpdateChecks<T> on State<T>`** (mixed into Home): initState reads `OnsetUpdater?`; none → nothing. Always `removeInstalledDownloads()` (cleanup). If `updater.enabled`: AppLifecycleListener(onResume: check) and a post-frame first check. `_checkForUpdate`: single-flight (`_updateBusy`); `updater.check()` → `UpdateAvailable` → `await beforeUpdateOffer()` (override hook: Home's one-time language sheet completes first so sheets never stack) → `offerUpdate`. Errors logged by runtime type only ("An update is never worth an error screen"); next resume retries. `_megabytes(bytes) = bytes / 1048576`.
PC: Windows updater = download the release installer/MSIX/zip from the same GitHub releases with the same integrity (checksum) check, same sheet/dialog (dialog form since desktop is "large"), "install unknown apps" step replaced by UAC/installer launch; Later = postpone that release.

### lib/widgets/accent_picker_controls.dart

Custom accent-colour picker controls (onboarding Setup and Settings › General).
- **`AccentSaturationValue({hsv, onChanged, height = 168, radius = 8})`**: LayoutBuilder width; `pick(position)` → hsv.withSaturation(clamp(x/width)) and withValue(1 − clamp(y/height)). `Semantics(label: accentSaturationBrightness, value: accentSaturationBrightnessValue(saturation %, brightness %))`. Input: `Listener(onPointerDown: pick)` (picks on touch) + GestureDetector(opaque, vertical and horizontal drag updates → pick) so drags in either axis win over a surrounding scrolling sheet and each reads both coordinates. Visual: SizedBox(height) Stack(clip none): rounded (radius) box with horizontal gradient white → pure hue (HSV(h,1,1)), overlaid with vertical gradient black (bottom) → transparent (top); thumb `AccentPickerThumb(colour hsv)` at (saturation × width − 10, (1 − value) × height − 10).
- **`AccentHueSlider({hue, onChanged, trackHeight = 12})`**: `namedHues = [22, 67, 112, 157, 202, 247, 292, 337]`. pick = clamp(x/width) × 360 on tapUp, horizontal drag start/update. SizedBox(height 44 target): track positioned at top (44 − 12)/2 = 16, height 12, radius 6, gradient #FF0000, #FFFF00, #00FF00, #00FFFF, #0000FF, #FF00FF, #FF0000; thumb at (hue/360 × width − 10, top 12) colour HSV(hue,1,1); 8 equal invisible Semantics buttons labelled `accentHue(degrees)` that set the named hue (screen reader access).
- **`AccentPickerThumb({color})`**: IgnorePointer 20 × 20 circle, fill colour, 2.5 white border, shadow 0x80000000 blur 4 offset (0,1).
- **`AccentThrottle(apply, {interval = 100 ms})`**: leading-edge throttle with trailing call: `call(color)` stores latest; if no timer: apply immediately and start a timer which on expiry clears itself and applies the latest. `flush()`: if a timer runs, cancel and apply latest now. `cancel()`. (Rebuilding the whole themed app on every drag frame is too costly; at most 10 theme updates/s.)
- `accentHex(color)` → "#RRGGBB" upper-case (alpha dropped).

### lib/widgets/adaptive_sliver_list.dart

**`AdaptiveSliverList({itemCount, itemBuilder, maxItemWidth = rowCardWidth})`**: phones → plain `SliverList.builder`; large screens → rows of as many cards as fit, each Expanded, `crossAxisAlignment.start` (rows size to their tallest card, cards keep natural height). Constants: `rowCardWidth = 560.0` (row cards, thumbnail beside text), `videoTileWidth = 320.0` (four tiles in a 1280 dp window), `videoTileGutter = 18.0` (with tiles' own 10 dp = the tablet's 28 dp gutter).
- `columnsFor(width, {maxItemWidth, largeScreen})` (visibleForTesting): 1 if not large or width ≤ 0; else `max(1, ceil(width / maxItemWidth))` (e.g. 1280/560 → 3 columns; 1280/320 → 4).
- Grid rows: `SliverList.builder(itemCount: ceil(n / columns))`, each a Row of `columns` Expanded cells; `MediaQuery.removePadding(removeLeft: column > 0, removeRight: column < last)` so only outer columns keep the window's side insets (cutouts); missing cells → SizedBox.shrink. itemBuilder still called once per item index (index-based paging triggers keep working).
- `videos({tiles, itemCount, itemBuilder})`: tiles → maxItemWidth 320 wrapped in SliverPadding horizontal 18; else rows of 560.

### lib/widgets/alert_message.dart

**`AlertMessage({message, centered = true, color, padding, vertical = false, trailingIcon, onTrailingIconPressed, trailingTooltip})`**: default colour onSurfaceVariant (vertical) / onSurface. Vertical: Column(center, min, spacing 8) [Icon info_outline_rounded, Text centred or start]. Horizontal: Row(center or start, spacing 8) [Icon info_outline_rounded, Flexible Text, optional SizedBox(8) + IconButton( — with the Row spacing that makes text → trailing button = 8 + 8 + 8 = **24 dp** total (icon → text 8 dp); tooltip trailingTooltip ?? `commonRetry`, icon trailingIcon, zero padding, no constraints, size 20, onPressed)]. Padding = given ?? (vertical ? horizontal 24 : none). Used in snackbars (deep link failure with "Open in browser", update errors).

### lib/widgets/announce.dart

`announce(context, message)`: if mounted, `SemanticsService.sendAnnouncement(View.of(context), message, Directionality.of(context))` — screen reader announcement (e.g. "Following X"). PC: UI Automation `RaiseNotificationEvent` (Windows Narrator) / NSAccessibility announcement (macOS) / AT-SPI.

### lib/widgets/draggable_divider.dart

**`DraggableDivider({onDrag, onDragStart, onDragEnd, minWidth = 0.2, maxWidth = 0.8, currentWidth, dragAreaWidth = 24.0, isResizableOnLeft = true, showHandle = true, showDividerLine = true, semanticLabel})`** — resizes the video/chat split (tablet and landscape layouts). `semanticStep = 0.05`.
- Pan start: dragging = true, reset end-haptic flags, onDragStart. Pan update: total width = first ancestor RenderBox's width (the Row); `delta% = dx / total`; new = current ± delta (+ when the resizable area is on the left, − when on the right), clamped to [min, max]; `onDrag(clamped)`; a single `HapticFeedback.lightImpact()` the first time the min or max is reached in a drag session. Pan end: dragging false, onDragEnd. Hover tracked via MouseRegion (cursor `SystemMouseCursors.resizeColumn`).
- Semantics: `slider`, label = semanticLabel ?? `draggableDividerChatWidth`, value/increasedValue/decreasedValue = `draggableDividerValue(percent)` (rounded % of clamped width), onIncrease/onDecrease step ±0.05 (disabled at the bounds). GestureDetector excluded from semantics.
- Visual (transparent box `dragAreaWidth` wide, Stack centred): when dragging or hovered, a centred line AnimatedContainer(150 ms easeOut) width 4 (dragging) / 3 (hovered), colour primary (dragging) / onSurface α0.3 (hovered), radius 2 (note: `showDividerLine` is accepted but the line shows only during interaction). Handle (if showHandle): AnimatedContainer(200 ms easeOut) 10 × 48 (12 × 52 dragging), colour `onsetColors.live` (accent, flat, no shadow), radius 12, containing a centred 2 × 16 (2 × 20 dragging) bar colour onPrimary radius 1.
PC: identical splitter; mouse is the primary input (hover state, resize cursor); keyboard arrows step 5 % when focused.

### lib/widgets/external_link_dialog.dart

- `typedef ExternalLinkChoice = ({bool dontAskAgain})`.
- `showExternalLinkDialog(context, url)` → showDialog(ExternalLinkDialog).
- **`ExternalLinkDialog({url})`**: host shown ASCII (`asciiHost` → punycode `xn--` for IDN, defeating homograph spoofing); `shown` = url with that host. `OnsetDialog(title: linkConfirmTitle, content Column(stretch, spacing 8): Text.rich of `linkConfirmBody(host: l10nMark(0))` with the host placed as a bold (w700, text colour) span via `l10nSpans` (body style, body colour); the full URL 2 lines ellipsis rowDetail secondary; MergeSemantics InkWell(radius 12, tap → selectionClick haptic + toggle) Row(spacing 8): Expanded `linkConfirmDontAsk` (row style) + `OnsetSwitch`; actions [Cancel text → null, `linkConfirmOpen` primary → (dontAskAgain)])`.
- **`confirmExternalLink(context, url, {ask, stopAsking})`**: returns true without asking when `ask` is false (setting `confirmExternalLinks`), context null or unmounted; dialog dismissed/cancel → false; open → if dontAskAgain call `stopAsking()` (sets setting false); true. Wired as `LinkRouter.externalLinkGate` in main (non-Twitch hosts only).

### lib/widgets/live_indicator.dart

`LiveIndicator({size = 8, color})` → `SignalPing(size, color)` — the live dot next to a live channel, in the theme live colour (the one place the accent may appear in lists).

### lib/widgets/onset_cached_network_image.dart

**`OnsetCachedNetworkImage({imageUrl, cacheKey, width, height, color, colorBlendMode, placeholder, errorWidget, useFade = true, useOldImageOnUrlChange = false, fit, memCacheWidth, memCacheHeight, semanticLabel})`** → `CachedNetworkImage` with `cacheManager: CustomCacheManager.instance` (disk cache, orphan sweep at startup), fade in/out 500 ms when useFade (else 0), fadeInCurve easeOut, fadeOutCurve easeIn, memCacheWidth/Height (decode at reduced size). Silent for screen readers unless `semanticLabel` is given (then `Semantics(label, image: true)`).
PC: an HTTP image cache on disk (e.g. `reqwest` + content-hash file store, LRU/size cap and stale sweep), decode at target size, 500 ms cross-fade.

### lib/widgets/profile_picture.dart

**`ProfilePicture({userLogin, radius = 20})`** — a channel avatar looked up by login through Helix `getUser(userLogin).profileImageUrl`.
- `retryDelays = [2 s, 10 s, 30 s]`; after the last failure it retries only when the app comes back to the front.
- Static caches shared by all instances: `_urlCache` login → URL, `_pendingRequests` login → in-flight Future (request de-duplication).
- `_url` future created once per login (in a late field, NOT in build: avoids placeholder flashes and repeated requests on parent rebuilds); `didUpdateWidget` with a new login resets failures, cancels retry and looks up anew.
- `_lookUp()`: on success (if still mounted and current) failures = 0 and the resume listener is disposed; on error: create `AppLifecycleListener(onResume: _retryNow)` once; if failures < 3 schedule `Timer(delays[failures++], _tryAgain)`. `_tryAgain` → setState new lookup. `_retryNow` → cancel timer, failures 0, try again.
- Build: ClipOval → FutureBuilder(future: _url, initialData: cached URL so a known picture shows from the first frame): data → `OnsetCachedNetworkImage(diameter × diameter, placeholder: surfaceContainer box)`; else a surfaceContainer box of the diameter.

### lib/widgets/scroll_to_top_button.dart

**`ScrollToTopButton({scrollController})`**: SafeArea → Padding(bottom 8) → Tooltip(`scrollToTop`, preferBelow false) → `FilledButton(CircleBorder, padding 12)` with Icon arrow_upward_rounded (theme filled button: lime fill, dark icon) → `animateTo(0, 500 ms, easeOut)`.

### lib/widgets/twitch_web_page.dart

**`TwitchWebPage({title, url})`** — a twitch.tv page inside the app, signed in with the login WebView's cookies (for what only twitch.tv can do: report fallback, mod view, subscribe page, category fallback).
- `debugBody` (visibleForTesting) replaces the WebView in tests.
- `open(context, {title, url})`: only `https` and host `twitch.tv` or `*.twitch.tv`; anything else is ignored (no push).
- WebViewController created once (late final; a new one per rebuild would reload and lose typed text): JavaScript unrestricted, navigation delegate logging resource errors, `loadRequest(url)`.
- Scaffold(bg scaffold, extendBody, extendBodyBehindAppBar): transparent AppBar (centerTitle false, elevation 0, overlay style transparent status bar with theme-appropriate icons — NOTE this local style omits the nav bar colour), leading back IconButton (tooltip `commonBack`, `Icons.adaptive.arrow_back_rounded`), title. Body Stack: WebView padded by top inset + 56 (kToolbarHeight); on top a `BlurredContainer(onlyWhenSettled: true, gradientDirection: up, padding: top/left/right insets, SizedBox(height 56))` — the channel video shows under the page while it slides, so the blur waits for the page to settle.
PC: an embedded WebView2 (Windows) / WKWebView (macOS) / WebKitGTK (Linux) sharing the login cookie store; same https-and-twitch-host restriction.

### lib/widgets/uptime.dart

**`Uptime({startTime, style, overflow})`**: subscribes to `SharedTimerService.instance` (one app-wide 1 s ticker, paused in background) and rebuilds each tick. `DateTime.tryParse(startTime)` null → nothing. Text = `(currentTime − start).toString().split('.')[0]` → "H:MM:SS" (hours unpadded, can exceed 24, e.g. "26:03:09"). Style = `onsetText.metadata` (Inter 13 tabular, metadata colour) merged with `style`, forced tabular figures (digits must not dance). maxLines 1 only when an overflow is given.

### lib/screens/onboarding/onboarding_parts.dart

Shared kit of the first-launch onboarding (always drawn in the intro's black, whatever theme Setup picks).

**`OnboardingColors`**: ground #0A0A0A; surface #141414; raised #1E1E1E; web #111111 (Twitch page panel); control #2A2A2A (dialog inner tile, switch off track); handle #3A3A3A; ring 0x14FFFFFF (card 0.5 ring, white 8 %); divider 0x0FFFFFFF (row divider in a card, 6 %); ringStrong 0x1FFFFFFF (pill ring, 12 %); ringNumber 0x29FFFFFF (16 %); text #F5F5F5; body #D6D6D6; secondary #A1A1A1; tertiary #8A8A8A; knobOff #8A8A8A; segmentDone 0x8CF5F5F5 (progress passed, 55 %); segmentTodo 0x24FFFFFF (14 %); scrim 0x9E000000 (62 %).

**`onAccentFor(accent)`**: L = luminance; onBlack = (L + 0.05)/0.0533 (#0A0A0A luminance ≈ 0.0033 + 0.05); onWhite = 1.05/(L + 0.05); #0A0A0A if onBlack ≥ onWhite else white.

**`OnboardingType`**: `title(tablet)` Inter size 40 (tablet) / 34, w800, ls −0.035 × size, height 1.08, text colour; `lead(tablet)` 16 / 15, height 1.5, secondary; `eyebrow` 11 w600 ls 1.54 secondary; `rowTitle` 15 w600 text; `rowDetail` 12.5 / 1.45 secondary.

**`onboardingCard({radius = 16})`**: BoxDecoration surface #141414, radius, 0.5 ring border.

**`enum OnboardingGlyphKind`** (17): arrowRight, login, chat, heart, smile, send, shield, scissors, userX, lock, help, chevronLeft, chevronRight, user, check, dice, refresh. Exact shape data (verbatim, 24 × 24, `c:` circles, `r:` rounded rects):
```dart
const Map<OnboardingGlyphKind, List<String>> _glyphs = {
  OnboardingGlyphKind.arrowRight: ['M5 12h14', 'M12 5l7 7-7 7'],
  OnboardingGlyphKind.login: [
    'M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4',
    'M10 17l5-5-5-5',
    'M15 12H3',
  ],
  OnboardingGlyphKind.chat: [
    'M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z',
  ],
  OnboardingGlyphKind.heart: [
    'M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 '
        '2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 '
        '7z',
  ],
  OnboardingGlyphKind.smile: [
    'c:12,12,10',
    'M8 14s1.5 2 4 2 4-2 4-2',
    'M9 9h.01',
    'M15 9h.01',
  ],
  OnboardingGlyphKind.send: ['M22 2l-7 20-4-9-9-4z', 'M22 2L11 13'],
  OnboardingGlyphKind.shield: [
    'M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 '
        '1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 '
        '17 5 19 5a1 1 0 0 1 1 1z',
  ],
  OnboardingGlyphKind.scissors: [
    'c:6,6,3',
    'M8.12 8.12L12 12',
    'M20 4L8.12 15.88',
    'c:6,18,3',
    'M14.8 14.8L20 20',
  ],
  OnboardingGlyphKind.userX: [
    'M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2',
    'c:9,7,4',
    'M17 8l5 5',
    'M22 8l-5 5',
  ],
  OnboardingGlyphKind.lock: ['r:3,11,18,11,2', 'M7 11V7a5 5 0 0 1 10 0v4'],
  OnboardingGlyphKind.help: [
    'c:12,12,10',
    'M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3',
    'M12 17h.01',
  ],
  OnboardingGlyphKind.chevronLeft: ['M15 18l-6-6 6-6'],
  OnboardingGlyphKind.chevronRight: ['M9 18l6-6-6-6'],
  OnboardingGlyphKind.user: [
    'M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2',
    'c:12,7,4',
  ],
  OnboardingGlyphKind.check: ['M20 6L9 17l-5-5'],
  OnboardingGlyphKind.dice: [
    'r:3,3,18,18,3',
    'M8 8h.01',
    'M16 8h.01',
    'M12 12h.01',
    'M8 16h.01',
    'M16 16h.01',
  ],
  OnboardingGlyphKind.refresh: ['M4 12a8 8 0 1 0 2.4-5.7', 'M4 4v4h4'],
};
```
Parsed once (`_paths`). **`OnboardingGlyph(kind, {size = 20, strokeWidth = 1.8, color})`**: colour ?? IconTheme ?? DefaultTextStyle ?? #F5F5F5; ExcludeSemantics; stroke painter like SheetGlyph (scale size/24, round caps/joins).

**`OnboardingButton({label, accent, onPressed, leading, trailing, height = 52})`**: `Semantics(button, enabled)` → PressScale → Material(colour accent, StadiumBorder, clip) → InkWell (tap → `Haptics.light()` then onPressed) → SizedBox(height) Row(center, spacing 8): optional leading glyph 18 / stroke 2 in onAccent; `Flexible(FittedBox(scaleDown, Text(maxLines 1, 15 w700 ls −0.15 onAccent)))` (shrinks rather than truncates); optional trailing glyph.
**`OnboardingTextButton({label, onPressed, height = 44, padding = h22, color = body #D6D6D6, fontSize = 15})`**: Semantics(button) → PressScale → transparent stadium Material → InkWell (tap → `Haptics.selection()`) → SizedBox(height) → padding → Center(widthFactor 1) Text(fontSize, w600, colour).
**`OnboardingIconButton({glyph, tooltip, onPressed, size = 22, strokeWidth = 2})`**: Tooltip(excludeFromSemantics) → Semantics(button, label tooltip) → PressScale → transparent CircleBorder Material → InkWell → 44 × 44 → glyph in text colour.
**`OnboardingSwitch({value, accent, onChanged, label})`**: Semantics(toggled, label, onTap) → ExcludeSemantics → GestureDetector(opaque, tap → selectionClick + toggle) → 52 × 44 target, Align end → AnimatedContainer(tint 200 ms / 150 ms reduced; 48 × 28, padding 3, colour accent on / #2A2A2A off, radius 14, 0.5 border 0x24FFFFFF) → AnimatedAlign(260 ms standard, 0 under reduce motion) → AnimatedContainer(tint duration; 22 dp circle colour onAccentFor(accent) on / #8A8A8A off, shadow 0x59000000 blur 2 offset (0,1)).

**`StepEntrance({animation, delays, total, child})`** (InheritedWidget): `stepDelays` = [0, 30, 70, 110, 150, 190, 230, 270] ms (`.d0`–`.d7`); `rise = 460 ms`. updateShouldNotify on animation/delays change.
**`StepRise({order, child})`**: no entrance → child. delay = delays[clamp(order)]; start = delay/total, end = (delay + 460 ms)/total, span ≥ 0.0001; t = clamp((value − start)/span); progress = emphasizedDecelerate(t); Opacity(progress) + translate (0, 12 × (1 − progress)). Parts rise 12 dp and fade in, each a bit after the previous; a step opened going back shows at once.
**`OnboardingStepLayout({tablet, padding})`**.
**`OnboardingStepFrame({layout, content, footer})`**: Column(stretch): Expanded SingleChildScrollView(padding LTRB left, top, right, 16) Column(stretch, content); footer padded (left, 0, right, bottom). Content scrolls on short windows, footer stays.
**`OnboardingFooter({tablet, primary, secondary, note, primaryWidth = 220})`**: tablet → Row(end, spacing 12)[secondary, Flexible(SizedBox(width 220, primary))]; phone → Column(min, stretch)[note with 14 bottom padding, primary, secondary with 4 top padding].

### lib/screens/onboarding/onboarding_intro.dart

Step 1 "Intro" (phone and tablet), the version line and the live mosaic.

**`OnboardingIntroPhone({nameBottom, fit, version, accent, bottomInset, language, onLanguage, onNext, column})`** — the flow draws the tile and the name; this draws the description, the language pill, the version and "Next". `languageWidth = 232.0` (pill width at text scale 1); `aboveNext = 24 + 52 + 16 = 92` (space under the version: Next 52 + 16 above it over a 24 bottom margin); `descriptionSide = 36.0`; `descriptionStyle` 15 / 1.5 secondary.
Layout (Stack): Positioned.fill Padding(left/right = column edges or 0, top = column.top ?? nameBottom + fit.descriptionGap, bottom = bottomInset + 92) → Column: Expanded(Align top → SingleChildScrollView(ClampingScrollPhysics, padding h36 (or h8 in a column)) → `StepRise(order 2, Text(onboardingIntroDescription, centred, descriptionStyle))`); SizedBox(fit.pillGap); `StepRise(order 5, SizedBox(width min(scaled 232, width − 32), OnboardingLanguageChoice(value, onChanged)))`; if fit.showVersion: SizedBox(versionGap) + `StepRise(order 3, OnboardingVersion)`. "Next": Positioned(left +16, right +16, bottom = bottomInset + 24) `StepRise(order 4, OnboardingButton(commonNext, accent, trailing arrowRight, onNext))`. The pill is always shown whole above Next; only the description scrolls.
`descriptionRoom(text, {body, textScaler, width})`: TextPainter of text (body merged with descriptionStyle, centred) at maxWidth → height, at least `textScaler.scale(70)` (three lines). The flow measures it in EVERY supported language and keeps the tallest so tapping the language pill never moves the tile.

**`IntroColumn({left, right, top, width})`** (landscape phone): value equality; `descriptionSide = 8.0`.

**`IntroPhoneFit({tileScale, tileGap, descriptionGap, pillGap, versionGap, showVersion})`**: `roomy` = (1, 30, 31, 24, 16, true); `tight` = (1, 18, 18, 16, 10, true); `minTileScale = 0.6`; `tileSize = 72`.
- `belowName(descriptionRoom, textScaler)` = descriptionGap + descriptionRoom + pillGap + `OnboardingLanguageChoice.heightFor(textScaler)` + (showVersion ? versionGap + `OnboardingVersion.heightFor(textScaler)` : 0).
- `needed(nameHeight, descriptionRoom, textScaler)` = 72 × tileScale + tileGap + nameHeight + belowName.
- `of({room, nameHeight, descriptionRoom, textScaler})`: roomy if it fits; else tight; else tight with the tile shrunk to `clamp((room − rest)/72, 0.6, 1)`; if that fits use it; else the same shrink with `showVersion: false` (the description then scrolls if still short). Decoration is lost in order: tighter gaps → smaller tile → no version line → description scroll; the pill never scrolls.
- `ofColumn({room, descriptionRoom, textScaler, tileScale, tileGap})`: tries roomy then tight (with the given tile scale) converted `_inColumn(tileGap)` (descriptionGap 0); first whose belowName ≤ room; else tight without version.
- value equality/hashCode.

**`OnboardingIntroTablet({layout, accent, language, onLanguage, onNext})`**: LayoutBuilder; content width = maxWidth − horizontal padding; headline size 40 if width ≥ 480 else 32. Column(stretch): Expanded Center Padding(LTRB left, top, right, 16) Column(start, min): Flexible SingleChildScrollView Column(start, spacing 20)[`StepRise(1, onboardingIntroEyebrow upper-cased, eyebrow style)`, `StepRise(2, Semantics(header) onboardingIntroDescription` Inter size w800 ls −0.035 × size h 1.12 text)]; SizedBox(24); `StepRise(5, SizedBox(width min(scaled 232, width), OnboardingLanguageChoice))`. Footer (padding LTRB left, 0, right, bottom): `OnboardingFooter(tablet: true, primary: StepRise(4, OnboardingButton(commonNext, trailing arrowRight)))`. (Tile, name and version live in the brand pane.)

**`OnboardingVersion({version})`**: e.g. "v5.0.5 (68)"; Text centred, 12 tabular tertiary #8A8A8A ('' while unknown). `heightFor(textScaler) = ceil(scale(12) × 1.25)`.

**`OnboardingMosaic({streams, tablet, landscape})`** — live pictures of Twitch top channels (quiet stand-ins when none; never bundled artwork), tilted −8°, drifting, under fades to black. `_drift` controller 28 s, `repeat(reverse: true)`; stopped under reduce motion. Build (ExcludeSemantics, RepaintBoundary, LayoutBuilder): scale = width/560 (tablet) or width/390 (phone); innerWidth = (780 tablet / 540 phone) × scale; columns = 4 if innerWidth > 900 else 3; gap 12 / 10; tile height 132 / 96; rows = ceil((height + 160)/(tileHeight + gap)) + 1; live tile index = 7 (tablet) / 4 (phone); tile width = (innerWidth − gap × (columns − 1))/columns; tile i shows `streams[i mod len]`. ClipRect Stack(expand): OverflowBox(topLeft, unbounded) → translate ((−110 tablet / −76 phone) × scale, −70 / −36) → SizedBox(innerWidth) → rotate −8° → drift translate y = −44 × easeInOut(drift) → RepaintBoundary(grid); then fades.
Fades: phone → one vertical LinearGradient stops [0, 0.20, 0.58, 0.96] colours [ground, ground α0.30, α0.40, ground]. Tablet → RadialGradient(centre (0, 0.08), radius 0.62, stops [0, 0.46, 1], colours ground α0.95, α0.78, α0.40) + vertical LinearGradient stops [0, 0.18, 0.80, 1] [ground, α0, α0, ground] + edge LinearGradient (left→right in landscape, top→bottom in portrait) stops [0.76, 1] [α0, ground].
`_MosaicTile`: request size 440 × 247 (tablet) / 320 × 180 (phone) (`thumbnailUrl` with `-{width}x{height}` replaced); ClipRRect radius 12; stand-in underneath; image cover, memCacheWidth = width, colour white α0.85 (live tile) / 0.6 with `BlendMode.modulate` (dimmed), no placeholder/error widgets. Live tile with a stream: badge at (8, 8), min height 20, padding h6, lime #C8FF3D radius 5, text `commonLiveBadge` 10 w800 ls 0.6 #0A0A0A.
`_MosaicStandIn`: diagonal gradient #1A1A1A → #111111 (top-left → bottom-right).

### lib/screens/onboarding/onboarding_language_choice.dart

**`LanguageChoiceColors({track, ring, indicator, selectedText, idleText})`**: `onboarding` = track #1E1E1E, ring 0x14FFFFFF, indicator #F5F5F5, selectedText #0A0A0A, idleText #D6D6D6; `.sheet(context)` (Home's one-time language question sheet) = track well, ring ring, indicator text, selectedText sheet, idleText body (from SheetColors in the current theme).

**`OnboardingLanguageChoice({value, onChanged, colors = onboarding})`** (asserts value ≠ AppLanguage.system): "English | Français" two-option segmented pill with a sliding indicator. `languages = [AppLanguage.en, AppLanguage.fr]`. `heightFor(textScaler) = max(44, ceil(scale(14) × 1.3 + 6 + 16))`.
- `Semantics(container, explicitChildNodes, label: languageChoiceSemantics)` ("Language · Langue", bilingual on purpose).
- Container(height heightFor, padding 3, colour track, radius pill 100, 0.5 ring border) → Stack: indicator `AnimatedAlign(320 ms standard, 0 under reduce motion; Alignment(−1 or +1, 0)) → FractionallySizedBox(width 1/2, height 1) → pill in indicator colour`; Row of two Expanded `Semantics(button, selected, inMutuallyExclusiveGroup)` GestureDetector (key `ValueKey('language-en')` / `'language-fr'`, opaque; tapping the selected one does nothing, otherwise `Haptics.selection()` + onChanged(language)) → Center → `AnimatedDefaultTextStyle(200 ms / 150 ms reduced; Inter 14 w600, selectedText or idleText)` → padding h8 → FittedBox(scaleDown) → `Text.rich(TextSpan(text: language.label(l), locale: language.locale), maxLines 1)` — each language named in its own language (endonym, spoken with its own locale), shrunk rather than cut.

### lib/screens/onboarding/onboarding_welcome.dart

- `onboardingTips(l)` = [`onboardingWelcomeTipGitHub`, `onboardingWelcomeTipChangelog`, `onboardingWelcomeTipRating`].
- **`OnboardingWelcomeStep({layout, accent, onFinish})`** (step 4): `OnboardingStepFrame` content: `StepRise(1, Semantics(header) onboardingWelcomeTitle in OnboardingType.title)`; SizedBox(12 tablet / 10); `StepRise(2, onboardingWelcomeLead lead style)`; SizedBox(28 / 24); three tips, each `StepRise(3 + i, _Tip(number i+1, text))` separated by 12 / 10. Footer: `OnboardingFooter(tablet, primary: StepRise(6, OnboardingButton(onboardingWelcomeGo, accent, trailing arrowRight, onFinish)))` ("Let's go!").
- `_Tip`: `onboardingCard()` padding 16 → MergeSemantics Row(start, spacing 14): number circle of size max(30, scale(22) + 8) with 0.5 ringNumber border, number tabular 13 w700 secondary; Expanded text 14.5 / 1.55 body.

### lib/screens/onboarding/onboarding_accent_picker.dart

**`showOnboardingAccentPicker(context, {tablet, initial, onChanged})`**: every change applies at once through `AccentThrottle(onChanged)` (≤ 10/s) so the whole onboarding and the preview show it; Cancel, the scrim and back restore `initial`; Done keeps the pick (`flush()`).
- Tablet: `showDialog(barrierColor 62 % scrim, Dialog(bg #1E1E1E, no tint, elevation 0, insetPadding 24, radius 24 + 0.5 ringStrong side, SizedBox(width 420, scroll padding 24, picker)))`.
- Phone: `showModalBottomSheet(scrollControlled, no drag handle, bg #141414, 62 % scrim, elevation 0, clip, top radius 24)` → foreground top hairline 0.5 0x24FFFFFF → SafeArea(top false) → scroll padding LTRB 24,10,24,24 → Column: handle 36 × 4 #3A3A3A radius 2, SizedBox(14), picker.
- After close: done == true → `apply.flush()`; else `apply.cancel()` and `onChanged(initial)`.
- The picker is wrapped in the caller's Theme.
**`_AccentPicker`**: state `_hsv = HSVColor.fromColor(initial)`, Random. `_set(hsv)` setState + onChanged(color). `_setHue(h)` clamps 0..359.999. `_randomize()`: `Haptics.light()`; HSV(random int 0..359, saturation 0.76, value 1). Layout `Semantics(scopesRoute, namesRoute, explicitChildNodes, label accentColorTitle)` Column(stretch, spacing 14): Row[Expanded title `accentColorTitle` 18 w700 ls −0.27 text; hex `accentHex(color)` 13 tabular secondary; SizedBox(8); 22 dp swatch circle with 0.5 0x4DFFFFFF border]; `AccentSaturationValue(hsv, _set)` (168 high, radius 8); `AccentHueSlider(hue, _setHue)`; "Random" button: Semantics(button) Material #1E1E1E StadiumBorder 0.5 ringStrong → InkWell → 44 high Row(center, spacing 8)[dice glyph 17 text, `accentColorRandom` 14 w600]; Padding(top 4) Row(end, spacing 8)[`OnboardingTextButton(commonCancel, fontSize 14, padding h18)` → false; SizedBox(width 96, `OnboardingButton(commonDone, accent: current colour, height 44)`) → true].

### lib/screens/onboarding/onboarding_login.dart

Step 2 "Log in": what logging in lets ONSET do, in plain words, before Twitch opens.

**`OnboardingPermission({glyph, title(l), detail(l), scopes})`** and **`onboardingPermissions`** (in order; a test checks every scope of `AuthBase.loginScopes` appears here):
1. chat glyph — `onboardingPermissionChatTitle` / `…ChatDetail` — scopes `chat:read`, `chat:edit`, `user:read:chat`, `user:write:chat`.
2. heart — `…FollowsTitle` / `…FollowsDetail` — `user:read:follows`.
3. smile — `…EmotesTitle` / `…EmotesDetail` — `user:read:emotes`.
4. send — `…WhispersTitle` / `…WhispersDetail` — `user:manage:whispers`.
5. shield — `…ModerationTitle` / `…ModerationDetail` — `moderator:manage:banned_users`, `moderator:manage:chat_messages`, `moderator:manage:chat_settings`, `moderator:manage:warnings`, `moderator:read:followers`, `moderator:manage:announcements`, `moderator:manage:shoutouts`, `moderator:manage:shield_mode`, `moderator:manage:automod`, `moderator:manage:blocked_terms`, `moderator:manage:unban_requests`, `moderator:manage:suspicious_users`, `moderator:read:moderators`, `moderator:read:vips`.
6. scissors — `…ClipsTitle` / `…ClipsDetail` — `clips:edit`.
7. userX — `…BlocksTitle` / `…BlocksDetail` — `user:read:blocked_users`, `user:manage:blocked_users`, `user:manage:chat_color`.

**`OnboardingLoginStep({layout, accent, onConnect, onSkip})`**: `OnboardingStepFrame` content: `StepRise(1, header onboardingLoginTitle title style)`; SizedBox(12 tablet / 10); `StepRise(2, onboardingLoginLead)`; SizedBox(24 / 20); `StepRise(3, tablet ? _PermissionGrid : _PermissionList)`; tablet only: SizedBox(18) + `StepRise(4, onboardingLoginDisclaimer 12.5 / 1.5 tertiary)`. Footer `OnboardingFooter(tablet, primaryWidth 250, note (phone): StepRise(4, disclaimer centred 12 / 1.5 tertiary), primary: StepRise(tablet 6 / phone 5, OnboardingButton(commonConnectWithTwitch, accent, leading login glyph, onConnect)), secondary: StepRise(tablet 5 / phone 6, OnboardingTextButton(onboardingLoginSkip, height 52 tablet / 44 phone, onSkip)))`. Connect → Twitch page (web step); Skip → Setup without an account.
- `_PermissionList` (phone): one `onboardingCard()` padding LTRB 14,4,14,6: header (padding top 12 bottom 6, Semantics header) `onboardingLoginAuthorizeHeader` upper-cased eyebrow; rows separated by 0.5 top borders in divider colour (none on the first), each padding v8 `_PermissionRow(tile 32)`.
- `_PermissionGrid` (tablet): header (bottom 12); `Wrap(spacing 12, runSpacing 12)` of cards width (maxWidth − 12)/2, `onboardingCard(radius 14)` padding 12, `_PermissionRow(tile 36)`.
- `_PermissionRow`: MergeSemantics Row(spacing 12): tile square (32 or 36) #1E1E1E radius 9 (32) / 10 (36) with glyph 16 body colour; Expanded Column(start, spacing 1 / 2): title 14 w600 text; detail 12.5 / 1.35 secondary.

### lib/screens/onboarding/onboarding_setup.dart

Step 3 "Setup": who is logged in, a live preview following theme and accent, theme, accent colour, chat history, crash reports.
- `_robotty = 'https://recent-messages.robotty.de/'`.
- **`enum OnboardingLogin { none (not tried or done — the store says who is logged in), pending (Twitch returned a token, login in progress), failed }`**.
- **`OnboardingSetupStep({layout, accent, settings, auth, login, preview, onNext})`**: `_robottyLink` TapGestureRecognizer → `launchUrl(robotty, mode: settings.launchUrlExternal ? externalApplication : inAppBrowserView)`; disposed with the state.
Content (`OnboardingStepFrame`): `StepRise(1, header onboardingSetupTitle)`; SizedBox(12 tablet / 10); `StepRise(2, onboardingSetupLead)`; SizedBox(14); `StepRise(3, Align start _AccountPill)`; SizedBox(16); `StepRise(4, onboardingCard padding h16 → Observer → Column(stretch))`:
  1. Padding v12 `_Preview(stream: preview, accent, light: theme light / dark / system → platformBrightness == light, tablet)`.
  2. `_Divided` (0.5 top border divider colour) → padding top 12 bottom 14 `_ThemeChoice(value: settings.themeType, onChanged sets it)`.
  3. `_Divided` → `_AccentRow` → `showOnboardingAccentPicker(tablet, initial: Color(settings.accentColor), onChanged: settings.accentColor = color.toARGB32())`.
  4. `_Divided` → `_SwitchRow(title onboardingSetupHistoryTitle, detail: Text.rich of onboardingSetupHistoryDetail(link: l10nMark(0)) with a tappable span 'recent-messages.robotty.de' (semanticsLabel = full URL, text colour, underline in accent), rowDetail style, value settings.showRecentMessages)`.
  5. `_Divided` → padding bottom 2 → `_SwitchRow(onboardingSetupCrashTitle, detail onboardingSetupCrashDetail, value settings.shareCrashLogsAndAnalytics)` (Firebase collection follows it via syncFirebaseCollection).
Footer: `OnboardingFooter(tablet, primary: StepRise(tablet 6 / phone 5, OnboardingButton(commonNext, trailing arrowRight, onNext)))`.
- **`_AccountPill`** (Observer): details = logged in AND login ≠ failed (a failure is said even if an older account was logged in). Logged in: leading 24 dp circle avatar (profileImageUrl, memCacheWidth 72, #1E1E1E fallbacks); text.rich `onboardingSetupLoggedInAs(name: mark)` with the readable name bold w700 text, rest 13 body, 1 line ellipsis; trailing 16 dp accent circle with check glyph 10 / stroke 3 in onAccentFor(accent). Pending: 14 dp CircularProgressIndicator(stroke 2, accent; determinate 0.25 under reduce motion) + `loginSigningIn` 13 secondary. Else: user glyph 14 / stroke 2 secondary + `onboardingSetupLoginFailed` (failed) or `onboardingSetupNotLoggedIn` 13 secondary. Container `Semantics(liveRegion)`, minHeight 32, padding start 4 (avatar) / 10, top 4, end 12, bottom 4, colour #141414, pill radius, 0.5 ringStrong border; Row(min, spacing 8).
- **`_Preview`**: duration motionDuration(260 ms); text = #0A0A0A (light) / #F5F5F5; meta = #5C5C5C (light) / #A1A1A1; picture 128 × 72 (tablet) / 96 × 54. Name = readable stream name or `onboardingSetupPreviewChannel`; detail = "<game> · <formatViewers(count, compact: false)>" with an empty game dropped (then only the viewers, no leading " · ") or `onboardingSetupPreviewDetail`. `Semantics(label: onboardingSetupPreviewSemantics(name, detail), excludeSemantics)` → `AnimatedContainer(key Key('setup-preview'), 260 ms standard, padding 8, colour white (light) / #0A0A0A, radius 12, 0.5 border 0x1A000000 / 0x1AFFFFFF)` → Row(spacing 12): ClipRRect(8) picture (stand-in or thumbnail `-320x180`, memCacheWidth 320, cover) with LIVE badge at (5,5) AnimatedContainer min height 16, padding h5, accent fill radius 4, `commonLiveBadge` 9 w800 ls 0.54 onAccentFor(accent); Expanded Column(start, spacing 2): AnimatedDefaultTextStyle `onboardingSetupPreviewBadge` (Inter 10.5 w600 ls 1.26 meta); name Inter 14 w700 text 1 line ellipsis; detail Inter 12 tabular meta (stand-in wraps; live detail 1 line ellipsis). Shows the app's look live as theme/accent change.
- `_PlaceholderPicture`: diagonal gradient #1F1F1F → #121212.
- **`_ThemeChoice`**: Column(stretch, spacing 10) of the header row and the pill. Header Row(baseline, spacing 12): `onboardingSetupThemeTitle` rowTitle; Expanded note right-aligned 12 tertiary: system → `onboardingSetupThemeSystemNote`, light → `…LightNote`, dark → `…DarkNote`. Segmented pill `Semantics(container, label theme title)`: height max(44, scale(13) × 1.3 + 14), padding 3, #1E1E1E, pill radius, 0.5 ring; indicator AnimatedAlign(320 ms standard / 0 reduced; Alignment(−1 + index, 0) for index 0..2) FractionallySizedBox 1/3 white-ish #F5F5F5 pill; three Expanded Semantics(button, selected, inMutuallyExclusiveGroup) GestureDetectors (tap on selected does nothing; else selection haptic + onChanged) → AnimatedDefaultTextStyle(200 / 150 ms; Inter 13 w600; #0A0A0A selected / body) → padding h6 → FittedBox(scaleDown) Text(theme.label(l)) — ThemeType order: system, light, dark.
- **`_AccentRow`**: `Semantics(button, label accentColorSemantics(hex), onTap, excludeSemantics)` → InkWell → minHeight 56 Row(spacing 12): Expanded `accentColorTitle` 15 w600 text; hex 13 w500 tabular secondary; AnimatedContainer(260 ms) 26 dp accent circle with two spread shadows (surface #141414 spread 2, then 0xE6F5F5F5 spread 3.5: a white ring); chevronRight glyph 16 / stroke 2 tertiary.
- **`_SwitchRow({title, detail, value, accent, onChanged})`**: padding v12 Row(start, spacing 12): Expanded Column(start, spacing 4)[title rowTitle, detail]; `Transform.translate(0, −8)` OnboardingSwitch(value, accent, label title).

### lib/screens/onboarding/login_webview.dart

The "Connect with Twitch" page (Twitch OAuth in a WebView) — used standalone (login from Profile, "Session expired" prompt, clip creation, follow flow log-in action) and embedded as the onboarding's web step.

**`LoginWebView({routeAfter, @visibleForTesting pageBuilder})`**: tablet = isLargeScreen; accent = SettingsStore.accentColor ?? lime; always dark theme `OnsetThemes(seed accent).dark`; `AnnotatedRegion(onboardingBars)`; Scaffold (so the page shrinks above the keyboard) bg #0A0A0A → Column: top inset spacer; bar of height 72 (tablet) / 56 with horizontal padding 28 / 6 containing `LoginBar(tablet, inOnboarding: false, onBack: maybePop)`; Expanded `TwitchLoginPanel(tablet, accent, routeAfter, pageBuilder)`. Signing in pops it, or replaces it with `routeAfter`.

**`onboardingBars`** (SystemUiOverlayStyle): status bar transparent, light icons (iOS brightness dark), nav bar #0A0A0A, nav divider transparent, light nav icons.

**`LoginBar({tablet, inOnboarding, onBack})`**: Row: `OnboardingIconButton(chevronLeft, tooltip commonBack, onBack)`; Expanded `Semantics(header)` centred `commonConnectWithTwitch` (1 line ellipsis, 18 tablet / 17 phone, w700, ls −0.015 × size, text); `OnboardingIconButton(help glyph, tooltip loginHelpTooltip, size 21, stroke 1.8)` → `showLoginHelp`.

**`showLoginHelp(context, {tablet, inOnboarding = true})`**: showDialog(barrierColor 62 % scrim) with the caller's theme → `_OnboardingDialog(width: 440 on tablet, label loginHelpTooltip)` children: 40 × 40 tile #2A2A2A radius 12 with help glyph; `loginHelpTitle` (18 w700 ls −0.27 h 1.3 text); `loginHelpBodyOnboarding` or `loginHelpBodyElsewhere` (14 / 1.55 body) — advice on getting past Twitch's cookie banner, the last advice differs because only the onboarding has a step to go back to; end-aligned `OnboardingTextButton(commonClose, 14, text colour, padding h18)`.
`_OnboardingDialog({children, label, width})`: Dialog(bg #1E1E1E, no tint, elevation 0, insetPadding h20 v24, radius 24 + 0.5 ringStrong) → `Semantics(scopesRoute, namesRoute, explicitChildNodes, label)` → SizedBox(width) → scroll padding LTRB 24,24,24,12 → Column(min, start, spacing 12).

**`TwitchLoginPanel({tablet, accent, routeAfter, onSignedIn, onTokenCaptured, pageBuilder})`** — `signingInLimit = 20 s`. Every login rule lives in `AuthStore`: authorization page, token taken from the redirect (implicit grant `#access_token`), the cookie banner capped at 20 % of the page height (injected JS MutationObserver setting `.fAVISI` max-height 20vh + overflow auto), a desktop/mobile browser user agent (Android: `Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Mobile Safari/537.36`; iOS Safari 26 UA) so Google sign-in is allowed.
State: controller from `_auth.createAuthWebViewController(onSignedIn: _onTwitchSignedIn, onTokenCaptured, onNotSignedIn, onPage, onError)`; `_page` (initially https://id.twitch.tv); `_signingIn`; `_failed` + `_failedPage`; `_loginFailed`; `_signingLimit` timer; `_login` future + `_loginWorked`; `_twitchDone`; `_signingLimitPassed`; `_finished`.
- `_pageOf(uri)`: remove fragment, normalise path, empty path with authority → '/'. `_onPage(uri)`: updates the shown page; a failure is cleared only when the page moves to a different page than the failed one.
- `_onTokenCaptured(login)`: forwards to `onTokenCaptured`; resets state; starts the 20 s limit; shows "Signing you in…". When the login resolves (errors = false) and is still the current one: refused → cancel limit, hide overlay, show failure line (also when another account is already logged in); worked after the limit passed → `_closeAfterHarvest()`; if Twitch's redirect already came → `_afterTwitch()`.
- `_onTwitchSignedIn` (redirect to twitch.tv, where the store harvests the twitch.tv web cookie "auth-token" used as the 2K/GQL token): `_twitchDone = true; _afterTwitch()`.
- `_afterTwitch`: wait if login still in flight; a failed login stays on the page (standalone) — but the onboarding moves on regardless (Setup shows the failure); else `_finish()`.
- `_onSigningLimit` (20 s without redirect): if login worked → `_closeAfterHarvest()`; else hide overlay (page shows again).
- `_closeAfterHarvest`: `harvestTwitchWebToken(pageCookies: runJavaScriptReturningResult('document.cookie') (errors → ''))` with a 5 s timeout → then `_finish()`.
- `_finish` (once): cancel limit; onboarding → `onSignedIn()`; else only its own route: not current → removeRoute; routeAfter → pushReplacement; else pop.
- `_onNotSignedIn` (Twitch signed the page in without giving this login a token: the user declined): hide overlay, show failure line.
- `_onError(error)`: only main-frame errors, not while signing in; iOS cancelled (−999) / interrupted (102) ignored; failed page = error URL or current page.
- `_retry()`: reset login state; clear failures; `_auth.retryLogin(controller)` (new OAuth `state`; earlier state no longer accepted); reload failure → failed state.
- dispose: cancel timer, `_auth.closeLogin(controller)` (state no longer accepted).
Build: fade = motionDuration(220 ms). Page = test builder or WebViewWidget; on tablet centred with maxWidth 560 (it is a phone page). DecoratedBox(#111111, 0.5 top border ring) → Column: `_HostStrip(page)`; `_LoginFailedLine(onRetry)` when login failed; Expanded Stack(expand)[page, AnimatedSwitcher(fade, switchIn standard)(`_SigningIn` key 'signing-in' | `_LoadFailed` key 'load-failed' | nothing)].
- **`_HostStrip`**: never shows path/query/fragment (they carry the OAuth state and token). secure = https with host. label = `scheme:` without host, host (secure), or `scheme://host`. 30 high, 0.5 bottom divider, centred Row(min, spacing 6): lock glyph 12 / stroke 2 tertiary when secure; label 12 tertiary 1 line, semanticsLabel `loginHostSecure(host)` or `loginHostPage(host)`.
- **`_LoginFailedLine`**: `Semantics(liveRegion)` full-width padding LTRB 16,2,8,2, colour danger #FF5A5F at 12 %: Expanded `loginFailedLine` 13 text; TextButton `commonTryAgain` (fg text, min 44 × 44).
- **`_SigningIn`**: #111111 cover, `Semantics(liveRegion)` centred Column(spacing 14): 28 dp CircularProgressIndicator(stroke 2.4, round cap, accent, track ringStrong; determinate 0.25 under reduce motion); `loginSigningIn` 14 secondary.
- **`_LoadFailed`**: #111111 cover, centred scroll padding 24 Column(min, spacing 8): `loginLoadFailedTitle` 17 w700 centred text; `loginLoadFailedDetail` 14 / 1.5 secondary; SizedBox(8); SizedBox(width 200, `OnboardingButton(commonTryAgain, accent, height 44, leading refresh)`).
PC: Windows uses WebView2 with the same UA override, the same JS banner cap, the same token/redirect interception (NavigationStarting), cookie read through `CoreWebView2CookieManager` for the twitch.tv `auth-token`; alternatively the system browser + loopback redirect, but the in-app page must stay available because the twitch.tv cookie harvest needs it.

### lib/screens/onboarding/onboarding_flow.dart

The first-launch flow: Intro → Log in (with the Twitch page) → Setup → Welcome → app. Shown as `home` when `first_run` is true.

- `typedef LoginPanelBuilder = Widget Function(BuildContext, VoidCallback onSignedIn, ValueChanged<Future<bool>> onTokenCaptured)` (test seam).
- **`enum OnboardingStep { intro, login, web, setup, welcome }`**; `progress`: intro 0, login/web 1, setup 2, welcome 3 (four segments); `back`: intro → null, login → intro, web → login, setup → login (not the Twitch page), welcome → setup.
- **`OnboardingFlow({@visibleForTesting loadLiveStreams, loginPanelBuilder, homeBuilder})`**: `stepDuration = 730 ms`, `handDuration = 1460 ms`. Private constants: `_enterShare = 360/730`, `_leaveShare = 240/730`, `_leaveCurve = Cubic(0.4, 0, 1, 1)`.

Rules (doc): continues the launch intro — its first frame is the intro's last (same tile, same place, same black, name underlined), then mosaic and text come in around it; on a tablet the tile slides into the brand pane (left in landscape, top in portrait) and stays for every step. Always drawn in the intro's black (`OnboardingColors.ground`) with a dark theme from the current accent; the accent picked in Setup applies at once; the light/dark theme choice only affects Setup's preview (and the app after). Back (bar or system) goes one step back; on Intro it leaves the app (`PopScope(canPop: step == intro && !finishing)`). Reaching Welcome writes `first_run = false` (as "Let's go!" does again). Phone is held in portrait (`SystemChrome.setPreferredOrientations([portraitUp, portraitDown])`), tablet turns freely (`[]`), orientations released on dispose.

**State**: `_step`, `_previous`, `_forward`, `_rising` (step came in forward and not reduced → its parts rise), `_introFresh` (Intro not left yet: its parts use the hand-over timing), `_switch` controller (730 ms, initial value 1; on completion clears `_previous`), `_hand` controller (1460 ms), `_handStarted`, `_launchTile` (rect where the held intro left the tile), `_reduce`, `_phone`, `_version` ("v<version> (<build>)" from PackageInfo; errors logged), `_streams` (≤ 24 top streams), `_login` (OnboardingLogin), `_finishing`, settings and auth stores, `_covered` (route secondary animation), `_latestLogin`.
- initState: if `LaunchIntro.running` → listen and on end take `LaunchIntro.restingTile` and start the hand-over; else start it post-frame. Load version and streams (`_loadStreams`: skipped when `settings.showThumbnails` is off; default loader `TwitchApi.getTopStreams(quiet: true)`; errors leave stand-ins).
- didChangeDependencies: reduce motion; phone = !isLargeScreenSize → hold orientation on change; subscribe to the route's secondaryAnimation: when a page that covered the onboarding (deep-linked player) is dismissed, re-hold portrait two frames later (that page releases orientation on dispose, after its exit animation).
- `_startHand`: once; duration 150 ms under reduce motion else 1460 ms; forward.
- `_go(to, {forward})`: ignored if same step or finishing; `Haptics.selection()`; leaving Intro clears `_introFresh`; going to Welcome → `_markFirstRunDone()` (SharedPreferences `first_run` = false; errors logged); set previous/step/forward/rising; switch duration 150 ms (reduced) or 730 ms; `forward(from: 0)`.
- `_back()` → `_go(step.back, forward: false)`.
- `_onTokenCaptured(login)`: latest login, `_login = pending`; on completion (errors = false), if still latest: none (worked) or failed.
- `_finish(geometry)` ("Let's go!"): once; mark first run again (unawaited); route = this page's route; `LaunchIntro.land(from: 72 × 72 rect at geometry.tileCenter, appear: !tablet, onCovered: replace this route in place with a zero-duration PageRouteBuilder of Home (or pushAndRemoveUntil when the route is inactive) — a page opened over it meanwhile stays on top)`. If the landing cannot play (reduce motion, screen reader) → pushAndRemoveUntil Home with a FadeTransition of motionDuration(280 ms).
- `_handSpan(startMs, endMs, curve)`: under reduce motion returns the raw hand value (pure fade); else curve(clamp((value × 1460 − start)/(end − start))).
- `_stepMotion(step)` → (opacity, x-offset): current step, no switch → (1, 0); current while switching: reduced → (v, 0); else p = standard(clamp(v / (360/730))) → (p, ±32 × (1 − p)) (+32 forward = enters from the right); previous while switching: reduced → (1 − v, 0); else q = Cubic(0.4,0,1,1)(clamp(v / (240/730))) → (1 − q, ∓32 × q) (leaves to the left going forward); others (0, 0).

**Hand-over timeline** (from the launch intro's held frame, 1460 ms; reduce motion: everything fades together in 150 ms):
| part | phone | tablet | curve |
|---|---|---|---|
| tile slides from launch rect to rest (centre lerp, scale lerp launchWidth/72 → tileScale), name follows (centre x lerp from screen centre, top lerp) | 240–880 ms | 240–880 ms | standard |
| mosaic (and tablet divider + version) fade in | 280–1180 ms | 560–1460 ms | standard |
| top bar fades in | 600–1200 ms | 860–1460 ms | linear |
| Intro parts (StepRise orders 0..5, rise 460 ms each, emphasizedDecelerate, 12 dp) | delays [0, 340, 420, 500, 560, 460] → order 0: 0–460, 1: 340–800, 2 (description): 420–880, 3 (version): 500–960, 4 (Next): 560–1020, 5 (language pill): 460–920 | delays [0, 620, 690, 760, 830, 760] | emphasizedDecelerate |
Without a held launch tile, the launch rect is a 72 × 72 rect at the screen centre (or at rest when reduced).

**Step change** (730 ms): incoming step fades in and slides 32 dp over 0–360 ms (standard); outgoing fades out and slides 32 dp the other way over 0–240 ms (Cubic(0.4,0,1,1)); incoming parts (forward only) rise with `StepEntrance.stepDelays` [0, 30, 70, 110, 150, 190, 230, 270] ms, 460 ms each. Going back: the step shows at once (only the slide/fade). Leaving step is IgnorePointer + ExcludeSemantics.

**Build**: Observer → `Theme(OnsetThemes(seed accent).dark)` → `AnnotatedRegion(onboardingBars)` → PopScope → `Material(color #0A0A0A)` → `_layout`.
`_layout`: geometry from size, padding, nameHeight = scaled letter size (34/40) × 1.2 + 14, nameWidth = `OnsetWordmark.widthFor`, descriptionRoom = max over all supported locales of `OnboardingIntroPhone.descriptionRoom(onboardingIntroDescription)` (so switching language never moves the tile). Built once: mosaic view, version view, tile view (`OnsetMarkTile` with lime glow α 0.25, blur 48 tablet / 40), name view (centred OnsetWordmark), step layout. `content(step)`: Intro while fresh and not reduced → `StepEntrance(animation: _hand, delays: phone/tablet intro delays, total 1460 ms)`; others → `StepEntrance(animation: current && rising ? _switch : complete, delays stepDelays, total 730 ms)`. Top bar padded by `barSide`.
AnimatedBuilder(merge switch, hand) → Stack[brand, steps, topBar]:
- brand: phone shows it only on Intro (opacity/shift follow the Intro's step motion, Visibility(maintainState)); tablet always. Contains: mosaic at geometry.mosaic with opacity; tablet: 0.5 divider (ring colour) and version (left = brand.left + 40, bottom offset = screenH − brand.bottom + (landscape ? 32 + bottom inset : 20)); tile Positioned 72 × 72 at tileCenter scaled; name Positioned(left nameCenterX − 160, width 320, top nameTop) where nameTop = tileCenter.dy + lerp(36, 36 × tileScale) + lerp(gapBelowTile, tileGap).
- steps at geometry.steps: ClipRect (hard edge on tablet, none on phone) Stack of previous and current `stepView`s (KeyedSubtree ValueKey(step); IgnorePointer/ExcludeSemantics when leaving; Opacity; translate x; Intro under reduce motion fades with the hand value while fresh).
- top bar at geometry.bar with bar opacity.

**Step contents** (`_stepContent`): language = `resolveAppLanguage(settings.appLanguage, platform locales)`; `next()` on Intro also calls `settings.chooseLanguage(language)` (chosen for good even without a tap, so new installs never get Home's one-time language question) then goes to login. Language pill tap → `settings.chooseLanguage(language)` (app switches language at once).
- intro: tablet `OnboardingIntroTablet`; phone `OnboardingIntroPhone(nameBottom, fit, column, version, accent, bottomInset, language, onLanguage, onNext)`.
- login: `OnboardingLoginStep(onConnect → web, onSkip → setup)`.
- web: panel = test builder or `TwitchLoginPanel(tablet, accent, onSignedIn: → setup if still on web, onTokenCaptured)`; Padding(top webTop) → ColoredBox #111111 → bottom padding = max(keyboard inset, bottomInset) (page shrinks above the keyboard).
- setup: `OnboardingSetupStep(settings, auth, login: _login, preview: first stream or null, onNext → welcome)`.
- welcome: `OnboardingWelcomeStep(onFinish → _finish(geometry))`.

**`_Geometry`** (all rects in window coordinates):
- Phone portrait: descriptionHeight = descriptionRoom(w − 72); top = padding.top + 56 + 8; nextTop = h − bottom − 92; fit = `IntroPhoneFit.of(room: nextTop − top, …)`; tileHalf = 36 × fit.tileScale; lowest = nextTop − belowName − nameHeight − gap − tileHalf; highest = top + tileHalf; cy = clamp(h/2, highest, max(highest, lowest)) (tile in the middle where the intro left it, raised on short windows). brand = steps = full window; mosaic = (0, 0, w, min(0.52 h, 440)); divider none; bar = (0, top inset, w, 56); barSide 6; stepPadding LTRB(24, top + 68, 24, bottom + 20); tileCenter (w/2, cy); tileScale fit.tileScale; tileGap fit.tileGap; nameBottom = cy + tileHalf + gap + nameHeight; webTop = top inset + 56.
- Phone landscape (`_phoneLandscape`): top = top inset + 64; usable = w − left − right insets; brandWidth = min(max(0.42 usable, nameWidth + 48), 0.5 usable); column from left inset + brandWidth to right inset + 16; room = h − bottom − 16 − top; gap = roomy 30 if 72 + 30 + nameHeight ≤ room else tight 18; tileScale = clamp((room − gap − nameHeight)/72, 0.6, 1); group centred vertically in room; fit = `IntroPhoneFit.ofColumn(room: h − bottom − 92 − top, descriptionRoom(columnWidth − 16), …)`; tileCenter (left inset + brandWidth/2, cy); introColumn set; other values as phone portrait; landscape flag false.
- Tablet landscape: pane = clamp(0.4375 w, 360, 560); brand = mosaic = (0, 0, pane, h); divider (pane, 0, 0.5, h); steps = (pane, 0, w − pane, h); side = 80 if steps width ≥ 600 else 48; bar = (pane, top inset, w − pane, 72); barSide 28; stepPadding LTRB(side, top + 104, side, bottom + 40); tileCenter (pane/2, h/2); tileScale 1; tileGap 31; introFit roomy; webTop top inset + 72.
- Tablet portrait: pane = clamp(0.36 h, 320, 480); brand = mosaic = (0, 0, w, pane); divider (0, pane, w, 0.5); steps (0, pane, w, h − pane); bar (0, pane, w, 72); barSide 28; stepPadding LTRB(64, 104, 64, bottom + 40); group = 72 + 31 + nameHeight; groupTop = (top inset + pane − group)/2; tileCenter (w/2, groupTop + 36); webTop 72.

**`_TopBar({step, tablet, accent, onBack})`**: on the web step → `LoginBar(tablet, inOnboarding: true, onBack)`. Otherwise Row: back `OnboardingIconButton(chevronLeft, commonBack)` wrapped in IgnorePointer/ExcludeSemantics/AnimatedOpacity(200 ms motion) hidden on Intro; Expanded centred `_Progress(index: step.progress)`; a 44 × 44 spacer.
**`_Progress`**: `Semantics(label onboardingProgressLabel, value onboardingProgressValue(step: index + 1, count: 4), excludeSemantics)` Row(min, spacing 8 tablet / 6): 4 AnimatedContainers (motionDuration 360 ms, standard) width 28 for the current else 14, height 4, radius 2, colour accent (current) / segmentDone 0x8CF5F5F5 (passed) / segmentTodo 0x24FFFFFF (to come).

