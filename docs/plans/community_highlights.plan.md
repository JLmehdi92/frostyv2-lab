# Implementation Plan: E5 "community highlights" (viewer side, read-only)

Builds on E3 (Hermes client) and E4 (Hype Train).

## Overview

A per-channel `CommunityHighlightsStore` shows four kinds of highlight above chat:

- **Poll:** live bars with percentages, votes, time left, final results, then auto-dismiss.
- **Prediction:** 2–10 outcomes with colours, points, users and return ratio, time left, and the locked, pending, resolved (winner) and canceled states.
- **Pinned chat message:** sender with badges and colour, emotes through the existing chat emote pipeline, expiry.
- **Outgoing raid:** "Raiding <target> with N viewers", a countdown, then "Watch <target>", which opens that channel in-app.

Data comes from three places:

- **Initial state:** anonymous GQL with full documents.
- **Live updates:** four public Hermes topics on the shared `TwitchRealtimeClient`.
- **Ordering:** a recency stack, following the Twitch web reducer rules, picks the visible card.

The Hype Train stays a separate tier above it. Voting and predicting need the user's own Twitch web session, so they are out of scope here (roadmap E9). Every failure just turns the feature off.

The chat layer gets zero diff: `chat_message.dart`, `irc.dart`, `ChatStore`.

## Verified facts (2026-10-13, anonymous)

Samples and scripts live outside the repo, in `~/twitch-re/e5/`. Test copies are in `test/fixtures/community_highlights_payloads.dart`.

- **Hermes subscriptions:**
  - `polls.<id>`, `predictions-channel-v1.<id>`, `raid.<id>` and `pinned-chat-updates-v1.<id>` subscribe anonymously.
  - User topics are refused with `SUB007`.
  - A socket holds at most 150 subscriptions (`SUB006`).
- **Polls:**
  - GQL `user(id){viewablePoll{…}}` goes ACTIVE → COMPLETED (about 60 s) → null when archived.
  - Hermes event types: `POLL_CREATE`, `POLL_UPDATE` (frequent), `POLL_COMPLETE`, `POLL_TERMINATE`, `POLL_ARCHIVE`.
- **Predictions:**
  - GQL `GetActivePrediction` must keep `resolvedPredictionEvents`.
  - A partial "server error" on `createdBy` happens and must be tolerated.
  - The "last resolved" event can be days old, so filter it by age.
  - Hermes `event-created` / `event-updated`, with status ACTIVE, LOCKED, RESOLVE_PENDING, RESOLVED, CANCEL_PENDING or CANCELED.
  - `event-updated` is high-volume.
  - Outcomes are all BLUE when there are three or more.
- **Raids** (on the source channel):
  - Event types `raid_update_v2` (about 1/s), `raid_go_v2` (sent 5×) and `raid_cancel_v2`.
  - There is no `data` wrapper.
  - `target_viewer_count` is a string.
- **Pinned messages:**
  - GQL `pinnedChatMessages(first:1, messageType:MOD)`; `endsAt` can be null.
  - Hermes `pin-message` (times in epoch **seconds**), `update-message {id, updated_at}` (refetch), `unpin-message {id}`.
  - Natural expiry sends no event, so the client must expire pins on `ends_at`.
- **Twitch web stack ordering** (`fix_highlight_ordering` reducer):
  - There is no fixed priority; the stack works by recency.
  - The same id is replaced in place.
  - Sticky items are appended.
  - A new item is inserted at the current index.
  - If the current item is expanded and visible, the new one goes after it and a "new" pill appears.
  - An unexpanded pinned item never blocks insertion.

## Commits

| # | Commit |
|---|---|
| C1 | add community highlight models and event parsing |
| C2 | add the community highlights gql service |
| C3 | extract a shared privmsg builder from vod chat replay |
| C4 | convert pinned chat messages to irc messages |
| C5 | add community highlight reducers and math |
| C6 | add the highlight stack |
| C7 | add the community highlights store |
| C8 | add poll, prediction, pinned and raid highlight cards |
| C9 | add the highlight slot, compact row, video pill and sheet |
| C10 | add a community highlights setting |
| C11 | share the channel top overlay between hype train and highlights |
| C12 | show community highlights in the channel screen |
| C13 | update gap and architecture docs for community highlights |

## Decisions (defaults)

1. **Hype Train and highlights:** two tiers, the Hype Train on top plus one community card with paging.
2. **Channels:** the primary (video) channel only.
3. **Setting:** one "Show community highlights" switch, on by default.
4. **Raid "Watch":** opens the target with `pushReplacement`; no auto-follow.
5. **Lingering:**
   - A poll stays until ARCHIVE, or 60 s after it ends.
   - A resolved prediction stays 60 s, a canceled one 30 s.
   - A resolved prediction older than 2 min is skipped.
6. **Card size:** collapsed on phones; expanded on large screens when the chat is at least 480 dp wide.
7. **Voting:** no vote or predict buttons or links.
8. **Dismiss:** per id, for the session only.
9. **Shared code:** the PRIVMSG builder is extracted from the VOD chat replay.

## Risks

- **Rebuild volume:** updates are coalesced (at most 2 commits per second), and countdowns run inside the widgets.
- **Subscriptions:** 5 per channel screen; a refusal falls back to GQL polling.
- **Stale state:**
  - Every event's channel id is checked.
  - A generation counter guards fetches.
  - The store is disposed with the screen and is never moved to the mini player.
- **Schema changes:** each kind has its own kill switch, and the UI never sees an exception.
- **Space on phones:**
  - Cards are collapsed while a Hype Train shows.
  - Nothing shows with the landscape keyboard open on phones.
  - Details open in a sheet when the card is compact.
