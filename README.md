<div align="center">

<img src=".github/assets/onset-logo.gif" width="160" alt="ONSET logo: a black italic ON with three rays above it and a dot below it, on a lime halftone tile">

<h1>ONSET</h1>

<p><strong>A Twitch client for Android, close to the live edge.</strong><br>
A native low-latency player and a full-featured chat.</p>

<p>
  <img alt="Flutter 3.38.4" src="https://img.shields.io/badge/Flutter-3.38.4-C8FF3D?style=flat-square&labelColor=0A0A0A&logo=flutter&logoColor=white">
  <img alt="Platform: Android 7.0+" src="https://img.shields.io/badge/Android-7.0%2B-C8FF3D?style=flat-square&labelColor=0A0A0A&logo=android&logoColor=white">
  <a href="LICENSE"><img alt="License: AGPL-3.0-or-later" src="https://img.shields.io/badge/License-AGPL--3.0--or--later-C8FF3D?style=flat-square&labelColor=0A0A0A"></a>
</p>

<p>
  <a href="../../releases/latest"><img alt="Download for Android" height="36" src="https://img.shields.io/badge/Download_for-Android-C8FF3D?style=for-the-badge&labelColor=0A0A0A&logo=android&logoColor=C8FF3D"></a>
  &nbsp;
  <a href="https://github.com/JLmehdi92/onset/issues/1"><img alt="iOS: join the waitlist" height="36" src="https://img.shields.io/badge/iOS-Join_the_waitlist-5C5C5C?style=for-the-badge&labelColor=0A0A0A&logo=apple&logoColor=white"></a>
</p>

</div>

---

## Install on Android

1. **Download** `onset-arm64.apk` from the
   [latest release](../../releases/latest) (under *Assets*). It is for 64-bit
   Android phones and tablets running Android 7.0 or later.
2. **Open the file.** If Android asks, allow installing apps from this
   source (your browser or file manager), then tap **Install**.
3. **Open ONSET**, tap **Next**, then **Connect with Twitch** to log in with
   your Twitch account. You can also tap **Skip** and log in later from
   Profile.

Updates then arrive inside the app (see
[How do updates work?](#faq) in the FAQ).

No Twitch developer account, Firebase project or build tools are needed to
use the app.

## Why ONSET

The Twitch web player, embedded in an app, keeps the picture several seconds
behind the broadcast. ONSET plays live streams with the **Amazon IVS player**
instead, built on the same video technology as Twitch, and keeps it near the
live edge.

- **Native player by default.** On Android, live channels open in the IVS
  player. It speeds up slightly or jumps ahead (your choice) when it falls
  behind, and reloads if it drifts too far.
- **A fallback that always plays.** The Twitch web player stays one switch
  away in *Settings › Video*. If the native player cannot get the stream or
  fails, the channel switches to the web player on its own, so a change on
  Twitch's side does not leave you without video.
- **Latency you can see.** The player overlay shows the measured delay to the
  broadcaster (on by default); tap it for live video stats. The chat can
  follow that delay, so messages line up with the picture.
- **A head start.** The stream's playback token is requested as soon as you
  press a stream card, before the channel screen opens.

## Features

<table>
<tr>
<td width="50%" valign="top">
<b>Watching</b>
<ul>
<li>Low-latency IVS player, with the Twitch web player as fallback</li>
<li>Latency pill and video stats in the overlay</li>
<li>Picture-in-picture, a floating mini player, background audio</li>
<li>Landscape and full screen, with side or overlay chat</li>
<li>Past broadcasts with chat replay, clips, followed videos</li>
</ul>
</td>
<td width="50%" valign="top">
<b>Chat</b>
<ul>
<li>7TV, BetterTTV and FrankerFaceZ emotes and badges</li>
<li>Emote menu, autocomplete for emotes and mentions</li>
<li>Moderation tools, deleted-message reveal, timeouts and bans</li>
<li>Chat delay synced to the stream, recent message history</li>
<li>Chatter list, filters and muted keywords</li>
</ul>
</td>
</tr>
<tr>
<td valign="top">
<b>Discovery</b>
<ul>
<li>Following, with Continue watching and followed categories</li>
<li>Live and top streams, categories, search, channel profiles</li>
<li>Hype trains, raids, polls, predictions, channel points, whispers</li>
</ul>
</td>
<td valign="top">
<b>App</b>
<ul>
<li>Phone and tablet layouts, light and dark themes, custom accent</li>
<li>Follows the system's reduce-motion setting</li>
<li>Go-live and mention notifications, schedule reminders</li>
<li>In-app updates from this project's releases, installed only when you tap Update</li>
</ul>
</td>
</tr>
</table>

## Screenshots

<table>
<tr>
<td width="33%" align="center" valign="top">
<img src=".github/assets/screenshots/home-phone.png" alt="The Following feed on a phone: Continue watching, the live channels and the navigation bar"><br>
<sub>Following</sub>
</td>
<td width="34%" align="center" valign="top">
<img src=".github/assets/screenshots/player-phone.png" alt="The player overlay with the latency pill reading 1.8 seconds"><br>
<img src=".github/assets/screenshots/chat-phone.png" alt="Chat with a deleted message, a timeout notice and a highlighted mention"><br>
<sub>Player overlay and chat</sub>
</td>
<td width="33%" align="center" valign="top">
<img src=".github/assets/screenshots/settings-phone.png" alt="The profile tab with the settings sections"><br>
<sub>Profile and settings</sub>
</td>
</tr>
</table>

<img src=".github/assets/screenshots/home-tablet.png" alt="The Following feed on a tablet: the hero stream, Continue watching, followed categories and a grid of live channels">
<p align="center"><sub>Following on a tablet</sub></p>

<img src=".github/assets/screenshots/settings-tablet.png" alt="Settings on a tablet, with the sections beside the General page">
<p align="center"><sub>Settings on a tablet</sub></p>

<sub>Rendered from the app's own widgets with sample channels; stream previews
and avatars are placeholder art.</sub>

## FAQ

**Is it safe to install?**
ONSET is open source. Each APK is built by GitHub Actions from this
repository, signed with the project's release key, and published with a
SHA-256 checksum next to it (`onset-arm64.apk.sha256`), so you can check the
file you downloaded. It is not reviewed by an app store, so only install
APKs taken from this repository's releases.

**How do updates work?**
ONSET looks for a newer build when it starts and when it comes back to the
foreground (at most every 6 hours once it is up to date). When one exists it
shows **Update available**. The first time you tap **Update**, ONSET asks
to be allowed to install apps: tap **Open settings**, turn on *Allow from this
source*, and come back. ONSET then downloads the update, checks its SHA-256
and opens Android's installer, which asks you to confirm. **Later** hides
that build for 24 hours. A download that does not match its checksum is
deleted and never installed. You can also check by hand with **Check for updates** in the
Updates section of Settings.

**Why isn't it on the Play Store?**
ONSET is an independent open-source client. It is distributed through this
repository's GitHub releases.

**Is there an iPhone version?**
Not yet. An iOS version is planned; how it will be distributed is not
decided yet. To be counted, add a 👍 to the
[iOS waitlist issue](https://github.com/JLmehdi92/onset/issues/1) and subscribe to it to hear when it
ships.

**Found a bug or have an idea?**
[Open an issue](../../issues/new/choose) and pick *Bug report* or *Feature
request*. For a bug, say which device and Android version you use and what
you did just before it happened.

**Is ONSET affiliated with Twitch?**
No. It is an independent project, not affiliated with, endorsed by or
sponsored by Twitch.

## For developers

<details>
<summary><b>Build from source</b></summary>

### Getting started

1. Install Flutter **3.38.4** (Dart 3.10.3). Newer releases break
   `extended_text_field` and `simple_icons`; older ones break `app_links`.
2. Register an application in the
   [Twitch developer console](https://dev.twitch.tv/console) for logging in,
   to get its **Client ID**. The app needs no client secret.
3. Set up the token proxy, a small Cloudflare Worker that hands logged-out
   viewers a Twitch app token minted for a second Twitch application nobody
   logs in to (it holds that application's secret):
   [`tool/token_proxy/README.md`](tool/token_proxy/README.md). Without it the
   app still runs, but logged-out viewers get no Twitch emotes, badges,
   browsing or search.
4. Copy `.env.example` to `.env` and fill in `CLIENT_ID` and `TOKEN_PROXY_URL`
   (the Worker's `https://` address; the VS Code launch configurations read
   the file with `--dart-define-from-file=.env`).
5. Fetch the dependencies and generate the MobX / JSON code:

   ```bash
   flutter pub get
   dart run build_runner build --delete-conflicting-outputs
   ```

6. Run or build:

   ```bash
   flutter run --dart-define=CLIENT_ID=<id> --dart-define=TOKEN_PROXY_URL=<https://worker-url>
   flutter build apk --release --dart-define=CLIENT_ID=<id> --dart-define=TOKEN_PROXY_URL=<https://worker-url>
   ```

   A release build without `android/key.properties` is signed with the debug
   key.

The native player is Android-only (7.0 and later), drawn into a Flutter
texture. The Dart code stays iOS-compatible, and iOS plays through the web
player.

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
native collection stays off until the app applies the setting. The update
workflow passes the same values from the `FIREBASE_*` repository secrets when
they exist.

### Signed releases and in-app updates

Each push to `main` can build a signed arm64 APK and publish it as a
`build-N` release of this repository, with its SHA-256. Builds made by that
workflow check the latest release, download the APK, verify it and hand it to
the Android installer; local builds never check. The one-time setup (signing
key, secrets, public or private repository) is in
[docs/MISES_A_JOUR.md](docs/MISES_A_JOUR.md) (in French).

</details>

<details>
<summary><b>Project structure, development and contributing</b></summary>

### Project structure

```
lib/
  apis/        HTTP services (all extend BaseApiClient)
  models/      data models, with generated .g.dart files
  screens/     one folder per feature, with its own stores/ and widgets/
  services/    playback, real-time sockets, notifications, updates
  stores/      global MobX stores
  widgets/     widgets shared by several features
android/       host app and the native IVS player bridge (Kotlin)
packages/      simple_pip_mode (vendored)
test/          mirrors lib/
tool/          developer scripts (the mark's bitmaps, README media)
docs/          architecture and update setup
```

The layers, the player engines and their fallback, the stores and the chat are
described in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

### Development

```bash
flutter analyze   # must stay clean
flutter test      # must stay green
dart run build_runner build --delete-conflicting-outputs   # after changing a store or a model
```

- State management is [MobX](https://mobx.netlify.app/): rerun `build_runner`
  after changing a store or a `@JsonSerializable` model, and commit the
  generated `.g.dart` files.
- Code style: package imports (`package:onset/...`), single quotes, trailing
  commas. Feature stores live in `lib/screens/<feature>/stores/`.
- Commits: lowercase, no prefix, one change each (for example
  `fix landscape bottom padding in chat bottom bar`).
- CI runs `flutter analyze` and `flutter test` on every pull request to
  `main`.
- README media live in `.github/assets/`. `python3 tool/readme_logo.py`
  rebuilds the animated logo from the app icon
  (`assets/icons/icon_onset.png`): the SVG source and the GIF the README
  shows (rendered with Playwright Chromium and ffmpeg), and
  `python3 tool/readme_shots/render.py` renders the screenshots.

### Contributing

Bug reports and feature requests are welcome through the issue templates.
For a pull request, keep it to one change, run `flutter analyze` and
`flutter test` first, and describe what you checked on a device. The
contributor guide, [CONTRIBUTING.md](CONTRIBUTING.md), has the commands, the
code layout and the conventions.

</details>

## Privacy

ONSET has no account system of its own, and the builds published here send
no crash reports or analytics. What the app stores and sends is described in
the [privacy policy](PRIVACY.md) ([version française](PRIVACY.fr.md)).

## Credits

ONSET is based on [Frosty](https://github.com/tommyxchow/frosty) by Tommy
Chow, licensed under AGPL-3.0, and has been extensively modified.

## License

ONSET is a modified version of an AGPL-3.0 licensed open-source Twitch client
(see [Credits](#credits)). It is distributed under the
[AGPL-3.0-or-later](LICENSE).
`packages/simple_pip_mode` is a vendored copy of the MIT-licensed
`simple_pip_mode` plugin (see its `LICENSE`).

ONSET is an independent project. It is not affiliated with, endorsed by or
sponsored by Twitch Interactive, Inc. Twitch is a trademark of Twitch
Interactive, Inc.
