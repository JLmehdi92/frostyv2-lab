# Implementation Plan: tablet layouts (Xiaomi Pad 7, ONSET design)

## Overview

The owner mainly uses the app on a Xiaomi Pad 7: 11.2", 3200×2136 px, about
1600×1067 dp, 144 Hz, HyperOS. Upstream Frosty has no tablet layout. Every
decision keys off `Orientation`, so the tablet gets phone cards stretched to
1600 dp. Its video buttons also rotate the screen instead of changing the
layout, which Android 16 ignores on large screens (targetSdk 36).

Source: the read-only tablet audit (2026-10-13). Each fix is scoped to large
screens, so phones keep their exact behaviour.

## Breakpoint

A "large screen" has a window shortest side of at least 600 dp (Material
"medium" and up, and Android's own large-screen threshold). Only that
breakpoint is used.

Split-screen windows narrower than 600 dp keep the phone behaviour.

## Commits

| # | Commit | Audit items |
|---|--------|-------------|
| T1 | add a large screen breakpoint | — |
| T2 | change the layout instead of rotating on large screens | HIGH 1, MED 4, MED 13 |
| T3 | size the landscape chat input by its width | HIGH 2 |
| T4 | show streams, categories and videos in grids on large screens | HIGH 3 |
| T5 | add a navigation rail on large screens | MED 7 |
| T6 | cap the mini player and the emote grid cells | MED 5, MED 6 |
| T7 | fetch thumbnails at the size they are drawn | MED 8, MED 11, LOW art |
| T8 | fit the hype train banner to wide chats | MED 9 |
| T9 | center settings pages on wide screens | MED 10 |
| T10 | ask for the highest refresh rate on android | MED 12 |

### T2 behaviour on large screens

- **Video overlay (live):**
  - The rotate button is hidden, as upstream already does on iPad.
  - The fullscreen button shows in both orientations:
    - In landscape it toggles `fullScreen` with the chat hidden; leaving restores the side chat column. It never calls `setPreferredOrientations`, and it releases any lock the app holds.
    - In portrait it requests landscape (both sides allowed) with the chat overlay, as on phones.
- **VOD overlay:** same rules. In landscape the button toggles `fullScreen` instead of rotating.
- **`enterLandscape`:** locks both landscape sides on large screens, so turning the tablet 180° works.
- **Onboarding:** keeps its portrait lock on phones only.

### T10

This needs no new dependency. `MainActivity` picks, at startup, the display mode with the highest refresh rate at the current resolution (`preferredDisplayModeId`). It is Android-only, guarded by API ≥ 23. iOS is unaffected; ProMotion is handled by the engine.

## Not done (needs a decision or is out of scope)

- A two-pane settings layout (centring is enough for now).
- Changing `immersiveSticky` in landscape: kept as Twitch does in theater mode.

## Verification

- Widget tests at 1600×1067, 1067×1600, 800×1280 (portrait tablet) and 360×740 / 740×360 (phone, unchanged) for every touched layout.
- `flutter analyze` clean, full `flutter test` green.
- Debug APK builds.
- An emulator smoke test at tablet size (`-skin 2560x1600`) where feasible.
- Real-device checks on the Pad 7 are listed in the final report.
