# CLAUDE.md

Fork of **Frosty** (mobile Twitch client, Flutter) whose goal is to **drastically cut stream latency** while keeping **every** existing feature.

> Base conventions, commands, source structure and gotchas live in **`AGENTS.md`** — read it first; it is the source of truth for how this codebase works. This file only adds what is specific to the fork.

## Mission (why this fork exists)

- Upstream Frosty plays video via the **Twitch web player inside a `webview_flutter` WebView** (`lib/screens/channel/video/`), which sits ~8–15s behind live.
- We are adding a **native low-latency HLS player** (target ~2–4s, official-app level) as the new default, with the **WebView kept as a selectable fallback**.
- **Non-negotiable:** no feature may be removed. The chat layer (7TV/BTTV/FFZ emotes, deleted-message reveal, timeout/ban rendering, chat-delay sync, badges, autocomplete) is independent of the player and must stay untouched.

## Hard constraints

- **Platform:** Android-first (developer is on Windows; iOS needs a Mac to build). Keep all code iOS-compatible — do not use Android-only APIs without a guard.
- **Personal use** build; not published. Twitch ToS concerns (raw HLS / ad handling) are acceptable to the user but must be isolated so a WebView fallback always works.
- The native player and Twitch-token logic must degrade gracefully: if Twitch GQL/usher changes, the app must still run via the WebView engine.

## Commands (see AGENTS.md for full list)

```bash
flutter pub get
flutter run --dart-define=CLIENT_ID=ID --dart-define=SECRET=SECRET   # NOTE: env names are UPPERCASE (constants.dart uses String.fromEnvironment('CLIENT_ID'/'SECRET')); AGENTS.md's lowercase clientId/secret is wrong
flutter analyze            # run after every change — must be clean
flutter test
dart run build_runner build --delete-conflicting-outputs   # after MobX/JSON model changes
```

## Conventions (from AGENTS.md — enforced)

- Package imports only (`import 'package:frosty/...'`), single quotes, trailing commas everywhere.
- Feature stores go in `lib/screens/{feature}/stores/` (e.g. the new player store). Only `lib/stores/` holds global stores.
- All API services extend `BaseApiClient` (`lib/apis/base_api_client.dart`) — the Twitch stream/token service must follow this.
- Never edit `.g.dart` files; regenerate them. Commit `.g.dart` files.
- Commits: lowercase, no prefixes, tightly scoped.

## Skills to use for this project

- **`dart-flutter-patterns`** — Flutter/Dart/MobX implementation patterns.
- **`security-review`** + **`code-review`** / **`pr-review-toolkit`** — run before considering any change done.
- **`superpowers:test-driven-development`**, **`superpowers:systematic-debugging`**, **`superpowers:verification-before-completion`** — process discipline.
- **`full-output-enforcement`** — never emit truncated code or `// ...` placeholders.

## Restore / rebuild from scratch (this repo is the backup)

If the working copy is broken, restore from GitHub and rebuild:

```bash
git clone https://github.com/JLmehdi92/frostyv2.git
cd frostyv2
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build apk --debug --dart-define=CLIENT_ID=<id> --dart-define=SECRET=<secret>
```

- **Flutter version: 3.38.4** (Dart 3.10.3). Newer (3.44+) breaks `extended_text_field`/`simple_icons`; older (3.35) breaks `app_links`. Pin with the matching stable tag.
- `android/app/google-services.json` and `lib/firebase_options.dart` are committed — no extra setup needed.
- `android/local.properties` is git-ignored and regenerated automatically.
- Twitch `CLIENT_ID`/`SECRET` are NOT in the repo (build-time only) — supply them via `--dart-define`.

## Definition of done (per change)

1. `flutter analyze` clean, `flutter test` green.
2. Every pre-existing feature still works (chat/emotes/mod-actions/PiP/theater/followed streams).
3. Latency is visible in the overlay so it can be measured on a real device.
4. WebView fallback engine still launches.
