# ONSET

ONSET is a mobile Twitch client for Android (iOS-compatible code), built with
Flutter, that aims to watch live streams as close to real time as the official
app while keeping a full-featured chat.

ONSET is a modified version of an AGPL-3.0 licensed open-source Twitch client.

## Features

- Low-latency live playback with a native player (Amazon IVS), plus a
  `media_kit` engine and the Twitch web player as selectable fallbacks;
  latency shown in the player overlay
- 7TV, BetterTTV and FrankerFaceZ emotes and badges, emote menu,
  autocomplete for emotes and mentions
- Moderation tools, deleted-message reveal, timeout and ban rendering,
  chat delay sync, local chat history, chatter list and filters
- Followed and top streams, categories, search, channel profiles
- VODs with chat replay, clips, followed videos
- Hype trains, raids, community highlights, channel points, whispers
- Picture-in-picture, mini player, background audio, theater and fullscreen
- Go-live and mention notifications, schedule reminders
- Phone and tablet layouts, light and dark themes, reduce motion
- In-app updates from this repository's releases (optional, see
  `docs/MISES_A_JOUR.md`)

## Build

1. Install Flutter **3.38.4** (Dart 3.10.3). Newer releases break
   `extended_text_field` and `simple_icons`; older ones break `app_links`.
2. Register an application in the [Twitch developer console](https://dev.twitch.tv/console)
   to get a **Client ID** and a **Client Secret**.
3. Copy `.env.example` to `.env` and fill in `CLIENT_ID` and `SECRET` (the
   VS Code launch configurations read it with `--dart-define-from-file=.env`).
4. Fetch the dependencies and generate the MobX / JSON code:

   ```bash
   flutter pub get
   dart run build_runner build --delete-conflicting-outputs
   ```

5. Run or build:

   ```bash
   flutter run --dart-define=CLIENT_ID=<id> --dart-define=SECRET=<secret>
   flutter build apk --release --dart-define=CLIENT_ID=<id> --dart-define=SECRET=<secret>
   ```

   A release build without `android/key.properties` is signed with the debug
   key.

### Firebase (optional)

No Firebase project is committed. Without configuration the app runs with
crash reports, analytics and performance traces off, and the "Share crash logs
and analytics" setting has no effect. To enable them, create your own Firebase
project with an Android app `app.onset` (and an iOS app `app.onset` if needed)
and pass:

```bash
--dart-define=FIREBASE_API_KEY=<api key>
--dart-define=FIREBASE_APP_ID_ANDROID=<1:…:android:…>
--dart-define=FIREBASE_APP_ID_IOS=<1:…:ios:…>
--dart-define=FIREBASE_MESSAGING_SENDER_ID=<project number>
--dart-define=FIREBASE_PROJECT_ID=<project id>
--dart-define=FIREBASE_STORAGE_BUCKET=<bucket>   # optional
```

Placing your `google-services.json` in `android/app/` (git-ignored) also
applies the Firebase Gradle plugins (Crashlytics mapping upload, automatic
performance traces); the dart-defines are still what starts Firebase, and
native collection stays off until the app applies the setting. The update workflow passes the same values from the
`FIREBASE_*` repository secrets when they exist.

## Development

- `flutter analyze` must stay clean and `flutter test` green.
- State management is [MobX](https://mobx.netlify.app/): rerun `build_runner`
  after changing a store or a `@JsonSerializable` model, and commit the
  generated `.g.dart` files.
- Conventions and architecture: `AGENTS.md`, `CLAUDE.md`,
  `docs/ARCHITECTURE.md`.

## License

[AGPL-3.0-or-later](LICENSE). `packages/simple_pip_mode` is a vendored copy of
the MIT-licensed `simple_pip_mode` plugin (see its `LICENSE`).
