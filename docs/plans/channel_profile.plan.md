# Implementation Plan: E6 "channel profile" (home, about, schedule, videos, clips)

## Overview

A `ChannelProfileScreen` shows a channel the way the Twitch app's profile does, in the ONSET design:

- **Header:** banner (or the accent colour), avatar with the live ring, name with the partner check, followers, LIVE or RERUN badge with viewers, and actions: **Watch** (live) or **Chat** (offline), **Share** (copy link), and the existing long-press actions (pin, block, report).
- **Tabs:** Home, About, Schedule, Videos, Clips.
  - **Home:** the live stream card, or the offline image with the last broadcast; then recent past broadcasts and the week's top clips, each with "View all".
  - **About:** bio, followers, join date, social links, and the channel panels (image, title, Markdown description, link).
  - **Schedule:** the next stream and the coming segments by day, cancelled ones struck through, times local.
  - **Videos and Clips:** the existing tabs of `ChannelVideosScreen` (stores and widgets reused).

Data comes from one anonymous GQL document per screen (profile) and one for the schedule, both live-verified. A failed profile query still shows the header from Helix `/users`, plus Videos, Clips and a Chat button: the screen never blocks reaching the channel.

The live player, chat, hype train and highlights are not touched.

## Entry points (Twitch app behaviour)

1. Tapping an **offline** followed channel, or an offline search result, opens the profile (it opened offline chat before; **Chat** on the profile still opens it).
2. Tapping the channel avatar or name in the stream info bar under the video.
3. **Profile** in the chat user card and in the long-press channel actions.
4. Links `twitch.tv/<login>/about` and `/schedule`, from chat and App Links.
5. "My channel" in the account page keeps opening the player (as today).

## Verified facts (2026-10-13, anonymous GQL, public web Client-ID)

Samples are in `~/twitch-re/e6/`, outside the repo.

- `user(login){id login displayName description createdAt profileImageURL(width:300) bannerImageURL offlineImageURL primaryColorHex roles{isPartner isAffiliate} followers{totalCount} channel{socialMedias{name title url}} panels{id type ... on DefaultPanel{title imageURL linkURL description altText}} lastBroadcast{id title startedAt game{id displayName}} stream{id type viewersCount}}` works without a token.
- `panels` mixes `DEFAULT` and `EXTENSION` entries; extensions have no data and are skipped. Panel `description` is Markdown and may hold links.
- `channel{schedule{segments{id startAt endAt title isCancelled categories{id name}} nextSegment{id startAt}}}`: `segments` takes no `first` argument; it returns the current week and the next, past ones included. `schedule` is null for channels without one; `segments` can be null.
- Images come from `static-cdn.jtvnw.net` and `panels.twitch.tv` only (checked before display).

## Commits

| # | Commit |
|---|---|
| P1 | add channel profile models and parsing |
| P2 | add the channel profile gql service |
| P3 | extract the channel videos and clips tabs |
| P4 | add the channel profile store |
| P5 | add the profile header |
| P6 | add the profile home, about and schedule tabs |
| P7 | add the channel profile screen |
| P8 | open the channel profile from offline channels, the info bar and user cards |
| P9 | open about and schedule links in the profile |
| P10 | update gap and architecture docs for the channel profile |

## Decisions (defaults)

1. Offline channel taps open the profile (Twitch behaviour); live ones still open the player.
2. No follow button: following needs a scope Helix does not offer to third-party apps (E9).
3. Social and panel links open through `LinkRouter` (Twitch links in-app, the rest per the "open links externally" setting).
4. Panel images are capped at 320 dp wide, two columns on the tablet.
5. Schedule reminders (PRF-06) need the user's session: not done.
6. Large screens: header and tabs in a 720 dp readable column, grids reuse `AdaptiveSliverList`.

## Risks

- **Schema changes:** each block (bio, socials, panels, schedule, last broadcast) is optional; parsing never throws and the screen falls back to Helix.
- **Untrusted strings:** URLs pass a scheme check (https only), image hosts are pinned, text is length-capped.
- **Regression:** the offline tap change keeps chat one tap away; the existing Videos and Clips screens stay for their links.
