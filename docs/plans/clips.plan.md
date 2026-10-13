# Implementation Plan: E2 "Clips" (list, player, chat replay, links, ONSET design)

## Overview

Channel clips appear in a **Clips** tab of `ChannelVideosScreen`, with period and sort chips. A clip plays in-app in a `ClipScreen`:

- **Engine:** media_kit (libmpv) plays the signed CloudFront MP4 on Android and iOS. The Twitch clip embed in a WebView is the fallback.
- **Reuse:** the screen reuses the VOD pieces: `VodOverlay`, `VodSeekBar`, `VodErrorView`, `VodChatReplayStore` and `PlaybackFocus`.
- **Controls:**
  - quality, loop toggle, copy link
  - channel link and "Clipped by"
  - "Watch full video", which opens the VOD at `videoOffsetSeconds`
  - chat replay from that VOD while it still exists
- **Links:** `clips.twitch.tv/<slug>`, `/<login>/clip/<slug>`, the `m.` variants and `/<login>/clips` open in-app, from App Links and from chat.

The live player, `TwitchStreamService`, `ChatStore`, `irc.dart` and `chat_message.dart` are not touched.

## Requirements

1. Clips play in-app, never in a browser.
2. Player:
   - play/pause, seek, quality, loop, mute/volume, speed
   - PiP on Android
   - fit/fill on large screens
   - immersive landscape
3. Clip actions: "Watch full video" (when `video{id}` and `videoOffsetSeconds` are set), "Copy link", channel link, "Clipped by".
4. Clips tab:
   - periods 24 h / 7 d / 30 d / All, sorts Top / Trending
   - up to 100 clips, laid out with `AdaptiveSliverList` (rows on the tablet)
   - skeletons, empty and error states, pull-to-refresh
5. One audible player at a time: the live or VOD screen beneath pauses and resumes, and the mini player closes.
6. ONSET design only; works on the Pad 7 (1600×1067 dp, both orientations) and on phones.
7. No new dependency. Login-token features (PRF-19/20/21) are out.

## Verified facts (2026-10-13, anonymous GQL, public web Client-ID, full query text)

Raw notes are in `~/twitch-re/clips/FINDINGS.md`, outside the repo.

**Channel clips list**

- `user(login){clips(first≤100, criteria:{period, sort}){edges{cursor node{…}} pageInfo{hasNextPage}}}` works.
- `period`: `LAST_DAY` / `LAST_WEEK` / `LAST_MONTH` / `ALL_TIME`.
- `sort`: only `VIEWS_DESC` and `TRENDING`. The others return "server error".
- Paging with `after:` returns `IntegrityCheckFailed`, so only the first page is available, as with VODs.
- Node fields that work: `id slug title viewCount createdAt durationSeconds thumbnailURL url videoOffsetSeconds language curator{id login displayName} broadcaster{…} game{id name} video{id}`.

**Clip playback**

- `clip(slug){playbackAccessToken(params:{platform:"web",playerBackend:"mediaplayer",playerType:"site"}){signature value} videoQualities{quality frameRate sourceURL} assets{type aspectRatio videoQualities{quality codecs sourceURL}}}` works.
- An unknown slug returns `clip: null`.
- `sourceURL` needs `?sig=…&token=<encoded value>`: 401 unsigned, 206 signed, range requests supported.
- The token JSON carries `authorization.forbidden` and `authorization.reason`.
- One sample's 1080 rendition listed `avc1` without `mp4a`, but its file does carry an `mp4a` track (verified in the `moov` box): `codecs` is incomplete and is not used to filter.
- The `RECOMPOSED` asset is a vertical 9:16 version.

**Other**

- `game(id){clips}` works; it is kept for E8.

## Patterns to mirror

| Area | Source |
|---|---|
| Anonymous GQL service | `lib/apis/twitch_vod_service.dart`: `_gql` helper, `isIntegrity`, id validation, `@visibleForTesting` builders, one bad node skipped |
| Shared Dio | `lib/main.dart` `anonymousGqlDio`; `Provider<…>.value`; `context_extensions.dart` getters |
| Player contract | `lib/screens/vod/vod_player_controller.dart`; `test/helpers/fake_vod_controller.dart` |
| media_kit | `lib/screens/channel/video/stores/native_video_store.dart`, `native_video.dart` |
| Screen lifecycle | `lib/screens/vod/vod_screen.dart`: mini player, `PlaybackFocus`, wakelock, `PipWidget`, `_switchPlayer`, system UI |
| Web fallback | `lib/screens/vod/stores/web_vod_store.dart` |
| List | `lib/screens/vod/channel_videos.dart`, `stores/channel_videos_store.dart`, `lib/widgets/adaptive_sliver_list.dart` |
| Links | `lib/utils/twitch_links.dart`, `lib/utils/link_router.dart`, `main.dart` deep links |

## Commits

| # | Commit | Content |
|---|---|---|
| C1 | add twitch clip gql service and models | `lib/models/clip.dart`, `lib/apis/twitch_clip_service.dart` (list, metadata, playback, slug validation, rendition choice, signed URL), provider wiring |
| C2 | parse twitch clip links | `ClipLink`, `ChannelClipsLink` in `twitch_links.dart` |
| C3 | let the vod overlay show any playable media | `PlayerMediaInfo` instead of `Vod`, option to hide ±10 s, extra actions and settings tiles; error view subject |
| C4 | extract a shared video card layout | `video_card_layout.dart`; `VodCard` unchanged pixel for pixel |
| C5 | add the clip player store | `ClipMediaBackend` (media_kit adapter), `ClipPlayerStore implements VodPlayerController` |
| C6 | add the clip player screen | `ClipScreen`, `ClipInfoPanel`, tablet side panel in landscape |
| C7 | play clips in the twitch embed when media_kit fails | `WebVodStore.forUrl`, `webClipEmbedUrl` |
| C8 | add clip chat replay | `VodChatReplayStore` at `offset + position` when the VOD exists |
| C9 | add a clips tab to channel videos | `ChannelClipsStore`, `ClipFilterBar`, `ClipCard`, "More clips" |
| C10 | open twitch clip links in the app | `LinkRouter`, deep links, manifest host `clips.twitch.tv` |
| C11 | update gap and roadmap for clips | GAP, roadmap, architecture |

Each commit keeps `flutter analyze` clean and `flutter test` green, written test-first:

- mocktail
- `http_mock_adapter` with the full URL `https://gql.twitch.tv/gql`
- `fake_async`
- a `FakeClipBackend`

## Risks

- **media_kit cannot run in tests.** Everything goes through `ClipMediaBackend`; the real backend is a thin adapter.
- **Codec list incomplete.** `codecs` is not used: the 1080 file carries audio despite listing only `avc1`.
- **Token expiry during a long pause.** Fetch a fresh token once (mpv's burst of errors for one failure counts once), then use the WebView fallback.
- **CDN.** The token is only sent to the clip CloudFront host seen live and Twitch's own domains; any other host plays in the embed.
- **Token leakage.** Signed URLs only go to libmpv or the WebView and are never logged.
- **Live regression.** The clip gets its own `Player` instance; the live stores and the chat layer are untouched.
- **CRLF files.** `AndroidManifest.xml` and `channel.dart` must keep their line endings.

## Decisions (defaults applied)

1. **Engine:** media_kit for clips on every platform, with the embed as fallback. IVS is not used because its progressive MP4 support is unverified.
2. **Loop:** off by default and remembered.
3. **"Watch full video":** starts at the clip offset and is pushed on top, so Back returns to the clip.
4. **CHT-45 clip cards in chat:** deferred. They would touch `chat_message.dart`, cause async height jumps in the reversed list, and multiply GQL calls in busy chats. Clip links tapped in chat do open in-app.
5. **Share:** copy to clipboard only. A share sheet would need `share_plus`, a new dependency.
6. **Vertical `RECOMPOSED` assets:** not used yet; kept for E8.
7. **List size:** the first 100 clips, with a footer.
8. **PRF-19/20/21:** out of scope, because they need the `clips:edit` scope or export.

## Regression checklist (device)

- **R1** Live IVS: latency badge, stats, emotes, moderation rendering.
- **R2** Mini player: it closes when a clip opens.
- **R3** Live → clip → back: live resumes and catches up.
- **R4** VOD: unchanged.
- **R5** VOD → clip link in replay chat → back: the VOD resumes.
- **R6** WebView engines still launch.
- **R7** Channel deep links unchanged; non-Twitch links follow the external setting.
- **R8** PiP for live, VOD and clip.
- **R9** Pad 7 grids and phone layouts: no overflow.
