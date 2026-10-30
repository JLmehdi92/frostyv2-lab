# Contributing to ONSET

Thanks for helping. Bug reports and feature requests go through the
[issue templates](../../issues/new/choose). This page is for code changes.

## Setup

- Flutter **3.38.4** (Dart 3.10.3). Newer releases break `extended_text_field`
  and `simple_icons`; older ones break `app_links`.
- A Twitch application's **Client ID** for logging in (no client secret is
  needed), and optionally the token proxy for logged-out viewers
  ([`tool/token_proxy/README.md`](tool/token_proxy/README.md)). The
  [README](README.md#for-developers) walks through both.
- Copy `.env.example` to `.env` and fill in `CLIENT_ID` and `TOKEN_PROXY_URL`;
  the VS Code launch configurations read it.

## Commands

```bash
flutter pub get                                            # install dependencies
dart run build_runner build --delete-conflicting-outputs   # regenerate .g.dart files (MobX stores, JSON models)
flutter run --dart-define=CLIENT_ID=<id> --dart-define=TOKEN_PROXY_URL=<https://worker-url>
flutter analyze                                            # static analysis, must stay clean
flutter test                                               # all tests, must stay green
flutter test test/path/to/file_test.dart                   # a single test file
```

The token proxy has its own tests: `node --test` in `tool/token_proxy/`
(Node 18 or newer).

## Source structure

- `lib/main.dart`, `lib/theme.dart`, `lib/constants.dart`: entry point, theme
  and build-time constants (`--dart-define` values).
- `lib/apis/`: HTTP services, all extending `BaseApiClient`
  (`lib/apis/base_api_client.dart`).
- `lib/models/`: data models (`@JsonSerializable`, generated `.g.dart`).
- `lib/screens/<feature>/`: one folder per feature, with its own `stores/` and
  `widgets/`. Code used by a single feature lives in that feature's folder.
- `lib/stores/`: global MobX stores only.
- `lib/services/`: app-level services (playback, real-time sockets,
  notifications, updates, image cache).
- `lib/widgets/`: widgets shared by several features.
- `lib/utils/`: helpers (general ones in `common_utils.dart`).
- `android/`: the host app and the native IVS player bridge (Kotlin).
- `packages/simple_pip_mode/`: a vendored plugin.
- `test/`: mirrors `lib/`. `test/guards/` holds repository-wide checks,
  `test/helpers/` and `test/fixtures/` shared test code.
- `tool/`: developer scripts outside the app (README media, the mark's
  bitmaps) and `token_proxy/`, the Cloudflare Worker that hands logged-out
  viewers an app token, with an optional EventSub cleanup script.
- `docs/`: [`ARCHITECTURE.md`](docs/ARCHITECTURE.md) (layers, player engines
  and their fallback, stores, chat) and the in-app update setup
  ([`MISES_A_JOUR.md`](docs/MISES_A_JOUR.md), in French).

## Architecture notes

- New API services extend `BaseApiClient`; do not add standalone API classes.
- Feature stores go in `lib/screens/<feature>/stores/`. Only truly global
  stores belong in `lib/stores/`.
- MobX stores use the generated mixin pattern; see
  `lib/screens/settings/stores/auth_store.dart` for a complete example.
- The native IVS player is Android-only. Keep the Dart code iOS-compatible:
  guard anything Android-specific, and keep the Twitch web player working as
  the fallback engine.
- No Twitch client secret may ever be in the app or the repository
  (`test/guards/no_client_secret_test.dart` fails if anything reads one).

## Gotchas

- After changing a MobX store or a `@JsonSerializable` model, run
  `dart run build_runner build --delete-conflicting-outputs`. Never edit
  `.g.dart` files by hand, and commit the regenerated ones.
- The secure storage cleanup in `main.dart` looks unnecessary but handles an
  Android/iOS case where secure storage survives an uninstall. Keep it.
- Several files use CRLF line endings (`pubspec.yaml`, `AndroidManifest.xml`,
  some Dart files): edit them in place without converting the whole file.

## Code style

- Package imports (`import 'package:onset/...'`), never relative imports.
- Single quotes.
- Trailing commas everywhere, so `dart format` keeps one argument per line.

## Testing

- HTTP mocking: `http_mock_adapter` (`DioAdapter`), with full URLs in
  `onGet` / `onPost`.
- Other mocks: `mocktail` (no code generation).
- Shared fixtures live in `test/fixtures/` (for example `irc_messages.dart`
  and `api_responses.dart`).
- Add or update tests with any change to testable logic.

## Commits and pull requests

- Commit messages are lowercase, with no prefix, one change each, for example
  `fix landscape bottom padding in chat bottom bar`.
- Keep a pull request to one change. Run `flutter analyze` and `flutter test`
  first, and say what you checked on a device.
- CI runs `flutter analyze` and `flutter test` on every pull request to
  `main`.

By contributing, you agree that your contribution is licensed under the
[AGPL-3.0-or-later](LICENSE), like the rest of ONSET.
