# Implementation Plan: E3 "minimal realtime layer" + E4 "Hype Train (viewer side, ONSET design)"

Planner: ECC `planner` (read-only; the repo was not modified). Repo: `/home/user/frostyv2-lab`. Base: `wip/vod` @ `921077b` (E1 VOD still in progress). E3/E4 branch from E1's landed tip.
**Complexity:** Large. About 16 small commits (Dart only, no Kotlin): 3 for E3 (+1 optional), 12 for E4 (+1 optional).
**WAITING FOR CONFIRMATION:** no code is written until the user approves the "Decisions to confirm" section at the end.

---

## Overview

**E3** adds one small app-wide realtime client, `TwitchRealtimeClient` (`lib/services/realtime/`). It speaks the Hermes websocket protocol anonymously, using the public web Client-ID. It handles:
- per-topic subscribe/unsubscribe with reference counting
- the keepalive watchdog
- reconnect with backoff and jitter, then resubscribe
- app pause/resume
- an injectable socket, so it can be tested without a network

It is fully isolated: it has its own socket and never touches the IRC or 7TV sockets in `ChatStore`. Its failures only surface as a per-topic "unavailable" event.

**E4** builds the viewer-side Hype Train on top of it:
- **Initial state:** an anonymous GQL `GetHypeTrainExecution`-equivalent full document (`TwitchHypeTrainService extends BaseApiClient`).
- **Live updates:** the `hype-train-events-v2.<channelId>` topic.
- **Logic:** pure, unit-tested parts (models, a reducer, a back-pressure queue, a sequence planner that turns each event into timed animation steps) driven by a MobX `HypeTrainStore`. The store owns the state machine (Init/Idling/Approaching/Ongoing), one-at-a-time pacing, the 1 s countdown, the +10 s expiry fallback and the 20 s approaching rule.
- **UI**, all ONSET (Frosty theme plus `lib/widgets`), with no Twitch assets or strings:
  - a banner above chat (portrait), compact in landscape, and a pill over the video when landscape chat is hidden
  - an expanded detail sheet
  - end strips: rewards or expired, 20 s each
  - every variant (Regular, Golden Kappa, Treasure, Community, Mythic, All-Time-High, Shared), with animations rebuilt as Flutter explicit animations and `CustomPainter`s

Chat code (`chat.dart`, `chat_store.dart`, `chat_tabs_store.dart`, `chat_tabs.dart`, `irc.dart`) gets **zero** diff. The banner sits in the screen-owned `chat` `Stack` in `channel.dart`, the same slot `FrostyNotification` already uses.

## Requirements (restated)

1. **E3 realtime client:**
   - connect lazily, subscribe/unsubscribe per topic (ref-counted), keepalive watchdog
   - reconnect with backoff and jitter, then resubscribe; app-resume handling; idle close
   - injectable socket for tests; anonymous public topics only
   - a failure never affects chat, video, PiP, the mini player or VOD
2. **E4 data:**
   - GQL initial state when the channel opens, on app resume, after a realtime resubscribe, and on unappliable events
   - realtime events applied through a pure reducer
   - defensive parsing: both camelCase and snake_case keys, unknown enums tolerated, never throws
3. **E4 state machine:**
   - Init → Idling → Approaching / Ongoing → end sequence → strip → Idling
   - a queue of at most 100 events with back-pressure: at ≥5 queued, small progressions are dropped; conductor updates replace queued ones per source; the queue is flushed on end
   - one animation at a time; animations are skipped when no presenter is visible
   - 1 s countdown, forced end at `expiresAt + 10 s`, approaching only when the first deadline is more than 20 s away
4. **E4 UI:**
   - portrait banner above chat, collapsible
   - landscape: a compact banner in the chat column or overlay chat, a pill over the video when chat is hidden
   - expanded sheet: variant explainer, level target line, shared contributions, conductors, reward emotes with lock, all-time-high line, learn-more link
   - end sequences: completed → rewards strip for 20 s; expired → expired strip for 20 s
   - all variants with their animation sequences, using the timing table in the RE notes
5. **Accessibility:**
   - semantic labels, a live region for announcements (the per-second countdown is not announced)
   - `MediaQuery.disableAnimations` honoured
   - text scaling up to 2.0, 48 dp targets, AA contrast
6. **Viewer actions** that need a session (subscribe, gift, cheer, share reward) are hidden. This is an E9 decision.
7. **No regressions:**
   - 7TV/BTTV/FFZ, deleted-message reveal, ban/TO durations, chat delay, badges, autocomplete
   - live latency and the stats panel, PiP, mini player, VOD, WebView fallback, iOS (web engine)
8. **Optional, separate commit:** a Hype Train level pill on followed stream cards, via the bulk status query.

## Verified facts (live from this container, 2026-10-13 15:50–16:05 UTC; public web Client-ID `kimne78kx3ncx6brgo4mv6wki5h1ko`; no user token; no integrity header; sockets opened only briefly)

### GQL (`POST https://gql.twitch.tv/gql`, full document)

- **The full `GetHypeTrainExecution`-equivalent document built from the RE field list resolves with no `errors` and no integrity challenge.**
  - The document covers `user(id){channel{hypeTrain{execution{…} approaching{…}}}}` with every field in notes §1.1:
    - `progress{level{id value goal rewards{… on HypeTrainEmoteReward{emote{id token}} … on HypeTrainBadgeReward{badge{id setID imageURL(size: DOUBLE)}}}} goal progression total remainingSeconds allTimeHighState}`
    - conductors, the full config, `allTimeHigh`, Treasure/Community/Mythic fragments, `sharedHypeTrainDetails @include(if: $includeSharedHypeTrain)` with users `profileImageURL(width:150)`
    - every approaching field
  - GraphQL validates the whole document, so **every field name, including the approaching/Community/Mythic/Shared ones that came back null, is schema-valid.**
  - Tested on an active channel (level 7 train), two idle channels, and an active Golden Kappa train.
  - Idle channel: `execution: null, approaching: null`.
  - **Right after a train ends, `execution` becomes `null` within seconds.** GQL cannot show an end state; only the realtime `hype-train-end` can.
- **Level semantics (important):**
  - `progress.level.goal` is **cumulative**: level 7 had `goal 19200` = end-of-level running total.
  - `progress.goal` and `progress.progression` are **in-level** (4700 and 1540).
  - `progress.total` is cumulative (16040). Check: 16040 − 1540 = 14500 = level 6 goal.
  - Percent must use `progression / progress.goal`.
  - `config.difficultySettings` lists only the current difficulty: `EASY`, `maxLevel: 392`, `levels` = 55 entries. The "final level" rule therefore almost never fires.
- **Config facts:**
  - `primaryHexColor` comes as `"BD0078"` (no `#`), or `null` even when `willUseCreatorColor: true`.
  - `participationConversionRates` includes junk entries (`UNKNOWN/UNKNOWN 0`, `UNKNOWN/BITS 1`) next to `TIER_1_SUB 500`, `TIER_2_* 1000`, `TIER_3_* 2500`, `CHEER 1`, `POLLS 1`, `BITS_ON_EXTENSION 1`.
  - `conductorRewards` has six entries: `BITS`/`SUBS`/`EXPLICIT_PURCHASE` × `CURRENT`/`FORMER`, all `BADGE` (`setID "hype-train"`, `imageURL` on `static-cdn.jtvnw.net/badges/v1/...`).
  - `calloutEmote` is the channel emote or `Kappa`.
- **Payload size:** the full document is about 57 KB, mostly `difficultySettings.levels[].rewards`. The lean document (`difficultySettings{difficulty maxLevel}` only) is **about 4.6 KB**. Use the lean one; current-level rewards are in `progress.level.rewards`.
- **RN-superset fields also resolve anonymously:**
  - `execution.isFastMode`, `participations{source action quantity}`
  - `config.kickoff{minPoints}`, `config.potentialRewards{id level value{…emote}}` (unordered; sort by `level`)
  - `CommunityTrainDetails.maxRewardLevel`, `approaching.expiresAt`, `approaching.potentialRewards`
  - `execution.self` → `null` (anonymous)
- **Golden Kappa:** `isGoldenKappaTrain: true` and `variantTrainDetails.__typename == "GoldenKappaTrainDetails"`. This union member is not in the notes.
- **APQ:** the Android persisted hashes (`GetHypeTrainExecution` `94aa6425…`, `BulkAllActiveHypeTrainStatusesQuery` `8ff353f4…`) **also work with the web Client-ID**, without the document. The plan still sends full documents (decision D8).
- **`allActiveHypeTrainStatuses(channelIDs:[…100 ids])`** works anonymously and found 2–10 active trains among about 830 live channels (including a `TREASURE` one). It returns `{id channel{id} level isAllTimeHighTrain isSharedTrain hypeTrainType}`.
- **Unrelated but noted:**
  - `streams(after:)` cursor paging fails with `IntegrityCheckFailed`
  - `streams(first:)` is capped at 30

### Hermes (`wss://hermes.twitch.tv/v1?clientId=kimne78kx3ncx6brgo4mv6wki5h1ko`)

- **Handshake:** a plain WS upgrade → `101`. No Origin, cookie or auth is needed; it works with a `Dart/3.x (dart:io)` user agent. With `clientId=` missing, the server closes immediately with **4130 "client ID required"**.
- **WS-level ping:** the server sends a ping frame **at connect and about every 60 s**. Without a pong within about 10 s it closes with **4100 "ping pong failed"**. `dart:io` `WebSocket` (behind `WebSocketChannel.connect` on Android/iOS) answers pings automatically; a device check in R3 confirms this.
- **Exact frames observed** (ids shortened):
  - welcome: `{"type":"welcome","id":"…","timestamp":"2026-…Z","welcome":{"keepaliveSec":15,"recoveryUrl":"wss://hermes.twitch.tv/<a|b|c>/v1?clientId=…&t=<opaque token>","sessionId":"…"}}`
  - subscribe (client → server): `{"type":"subscribe","id":"<msgId>","timestamp":"<iso>","subscribe":{"id":"<subId>","type":"pubsub","pubsub":{"topic":"hype-train-events-v2.<channelId>"}}}`
  - subscribe OK, about 100 ms later: `{"type":"subscribeResponse","id":"…","parentId":"<msgId>","timestamp":"…","subscribeResponse":{"subscription":{"id":"<subId>"},"result":"ok"}}`
  - subscribe error: `…"subscribeResponse":{"subscription":{"id":"<subId>"},"result":"error","error":"invalid topic","errorCode":"SUB002"}`
  - keepalive: `{"type":"keepalive","id":"…","timestamp":"…"}`, sent after about **10 s** of downstream silence (so `keepaliveSec: 15` is the client's dead-man window)
  - notification: `{"type":"notification","id":"<uuid>-msg0-topic1<subId>","timestamp":"<server time>","notification":{"subscription":{"id":"<subId>"},"type":"pubsub","pubsub":"<JSON STRING: {\"type\":\"hype-train-…\",\"data\":{…}}>"}}`. The inner payload is double-encoded.
  - unsubscribe: `{"type":"unsubscribe","id":"<msgId>","timestamp":"…","unsubscribe":{"id":"<subId>"}}` → `{"type":"unsubscribeResponse","parentId":"<msgId>","unsubscribeResponse":{"subscription":{"id":"<subId>"},"result":"ok"}}`
  - `reconnect` was not observed. Its shape is taken from the notes (`reconnect` carries a URL).
- **Subscription quirks:**
  - The auth-only topic `hype-train-events-v1.rewards.<userId>` returned `result:"ok"` anonymously. The server does not enforce `requiresAuth` at subscribe time, so the client must never subscribe auth topics anonymously.
  - `video-playback-by-id.<channelId>` subscribes fine anonymously. This is useful later for PLY-09 stream up/down.
- **Legacy PubSub** (`wss://pubsub-edge.twitch.tv/v1`) still accepts an anonymous `LISTEN` for the same topic (`{"type":"RESPONSE","error":"","nonce":"n1"}`). It answers `PING` with `PONG`, and it also sends WS pings and closes with 4100 when they go unanswered. It is a viable fallback (optional R4).

### Realtime hype-train payloads (captured: 34 notifications over 10 channels)

Captured types: `hype-train-progression` ×24, `hype-train-level-up` ×5, `hype-train-end` ×3 (1 `COMPLETED`, 2 `EXPIRED`), `hype-train-conductor-update` ×2.

- **progression `data`:**
  - `id` (**the train id**, not a per-event id: shared by every progression, the level-up `hype_train.id` and the end), `user_id`, `user_login`, `user_display_name`, `user_profile_image_url`
  - `sequence_id`, `action`, `source`, `quantity`, `initiator_currency` (null), `is_large_event`, `is_fast_mode`, `is_boost_train`
  - **`expires_at` (ISO)**, `sharedProgress` (null)
  - `progress{level{value, goal(cumulative), rewards[{type,id,token,set_id,group_id,reward_level,reward_end_date}]}, value(in-level), goal(in-level), total, remaining_seconds, all_time_high_state}`
  - `treasureTrainDetails` **and** `variantTrainDetails`, both carrying the same Treasure object **with both camelCase and snake_case keys** (`discountPercentage`/`discount_percentage`, `status`/`discount_status`, …)
- **progression quirks:**
  - **`sequence_id == progress.total`** in every capture. It is a monotonic ordering key; `(train id, sequence_id)` is the dedupe key. *Correction (H1 review): no progression was actually delivered twice; the earlier "duplicate" was two progressions of one train sharing the train id.*
  - **The level-up and the progression that caused it come in either order**: the progression first in 3 of 5 captures (about 1–2 s before, for example level-2 progression at :27 and level-up at :28), the level-up first in 2 of 5 (about 0.1 s before). Both carry the same total, so a progression whose `sequence_id` equals the current total is not stale: it still names the contributor.
  - **Unknown action value `EXTENSION`** (quantity 500) was seen. It is not in the RE enum list.
- **level-up `data`:**
  - `time_to_expire` is **epoch milliseconds**, for example `1791907526000`.
  - `progress{…same snake shape…}`
  - `hype_train` in **GQL shape** with `__typename`s: `id, startedAt, expiresAt, updatedAt, endedAt, endReason:"IN_PROGRESS"` (GQL returns `null` here), `isGoldenKappaTrain`, `progress{goal progression total level{…rewards[{__typename,emote}]}}`, `conductors[{id:"<trainId>-SUBS", source, participation, user{…profileImageURL}}]`, `config{… potentialRewards, kickoff{minPoints}, difficultySettings[{difficulty,maxLevel}]}`, `allTimeHigh`, `isFastMode`, `participations`, `sharedHypeTrainDetails`, `isTreasureTrain`, `variantTrainDetails{__typename:"GoldenKappaTrainDetails"}`
  - `is_boost_train`
- **conductor-update `data`:** `id:"<trainId>-SUBS"`, `source`, `user{id, login, display_name, profile_image_url}`, `participations:{"SUBS.TIER_1_GIFTED_SUB":10,"SUBS.TIER_1_SUB":1}`.
- **end `data`:**
  - `id`, **`ended_at` (epoch ms)**, `ending_reason:"COMPLETED"` (seen for trains that ended at levels 2 and 9)
  - `participation_totals[{source, action, quantity}]` (no currency)
  - **`rewards[{__typename:"HypeTrainEmoteReward", id, type, emote{id, token}}]`**: every emote earned (10–11). This field is not in the notes.
  - `shared_train_details`, `is_boost_train`
- **Not observed live, so the notes stay the source and fixtures are marked (TBC):** `hype-train-approaching`, `hype-train-start`, `-cooldown-expiration`, `-shared-merge-trains`, `-shared-channel-left`, `-shared-conversion`, `EXPIRED` ends, Community, Mythic, Shared and ATH payloads.

---

## Patterns to Mirror

| Category | Source | Pattern |
|---|---|---|
| Anonymous GQL service | `lib/apis/twitch_vod_service.dart:44-90, ~300 _gql` | `extends BaseApiClient` with its own `Dio` (connect 5 s / receive 8 s, built in `main.dart:122`). `Client-ID` header only. Full query documents as `static const` strings. `_gql(op, query, vars)` throws a typed exception when `errors` is present and sets `isIntegrity` when a message contains "integrity". Tolerant node parsing (one bad node does not hide the rest). Id validation regex (`tryNormalizeVodId`). |
| Existing websocket | `chat_store.dart:798 listenToSevenTVEmoteSet`, `:884 connectToChat` (backoff l.976-981) | `WebSocketChannel.connect(Uri)`, `stream.listen(onData,onError,onDone)`, `sink.close(1000)`, exponential backoff capped at 8 s. Mirror the API usage, but **do not touch or refactor** these sockets. |
| Injectable time | `lib/services/playback_token_cache.dart:16` (`DateTime Function()? now`) | Time injected for tests. E4 standardises on `package:clock` (`clock.now()`) plus `fakeAsync`, so `Timer`s and the clock advance together. |
| Feature store | `lib/screens/settings/stores/auth_store.dart`, `lib/screens/vod/stores/vod_chat_replay_store.dart` | `Foo = FooBase with _$Foo`, `@readonly` private observables, `@action`, `part '*.g.dart'`; timers cancelled in `dispose()`. |
| Store tests | `test/screens/vod/stores/vod_chat_replay_store_test.dart` | mocktail `Mock implements Service`, helper builders, `tearDown(store.dispose)`. |
| API tests | `test/apis/twitch_vod_service_test.dart` | `DioAdapter` with the full URL `https://gql.twitch.tv/gql`, `data: Matchers.any`, fixtures in `test/fixtures/*.dart`. |
| Model parsing | `lib/models/vod.dart`, `vod_comment.dart`, `hls_variant.dart` | Hand-written `fromGql` / `fromJson` (no codegen); strict on ids, tolerant elsewhere. |
| Screen layout | `lib/screens/channel/channel.dart:479 build`, `:534 video` Stack (stats panel `Positioned` l.540-553), `:559 chat` Stack (`FrostyNotification` at top), `:258 didChangeAppLifecycleState`, `:330 _minimizeToMiniPlayer`, `:946 dispose` | Screen-owned overlays in Stacks. The `chat` widget is reused by the portrait column, the landscape side column and the overlay chat, so one slot covers all three. |
| Settings | `settings_store.dart` (`static const defaultX`, `@JsonKey(defaultValue:)`, `resetChatSettings()` l.346), `chat_settings.dart:181 'Alerts'` with `SettingsListSwitch` | New boolean setting plus switch; regenerate `.g.dart`. |
| ONSET UI | `lib/theme.dart` (`FrostyColors`, `kOverlayShadow`, Inter, text theme), `lib/constants.dart:46 kCardBorderRadius`, `lib/widgets/{frosty_cached_network_image,profile_picture,blurred_container,section_header,alert_message,live_indicator}.dart`, `lib/utils/modal_bottom_sheet.dart` | Colours come from `colorScheme` (accent-seeded) and `FrostyColors`; 0.5 px `outlineVariant` borders; radius 8/12; `BlurredContainer` for translucent bars; bottom sheets via the shared helper. |
| Dev harness | `lib/dev_player_harness.dart` (`flutter run -t …`, not shipped) | Separate entrypoint for device checks without credentials. |
| Emote CDN | `lib/models/irc.dart:27` `_twitchEmoteBaseUrl` | `https://static-cdn.jtvnw.net/emoticons/v2/<id>/default/dark/3.0`. |

Logging: `debugPrint('<Class> <op> failed: $e')` only behind `kDebugMode`. Never log `recoveryUrl` (it carries an opaque session token) or raw payloads. No Crashlytics `recordError` with payloads; at most a `FirebaseCrashlytics.instance.log('hermes close <code>')` breadcrumb.

---

## Architecture (summary)

```
lib/constants.dart                       + kTwitchWebClientId (new code only; live/VOD services untouched)
lib/services/realtime/
  hermes_protocol.dart                   pure: frame decode/encode, close-code classes, topic validation, ids
  realtime_socket.dart                   RealtimeSocket interface + WebSocketChannelSocket adapter
  twitch_realtime_client.dart            TwitchRealtimeClient (ref-counted topics, watchdog, backoff, lifecycle)
lib/apis/twitch_hype_train_service.dart  TwitchHypeTrainService extends BaseApiClient (lean full document)
lib/models/hype_train.dart               execution/approaching/progress/level/reward/conductor/config/variants/shared/ATH
lib/models/hype_train_event.dart         sealed HypeTrainEvent + HypeTrainEvent.parse(String) (never throws)
lib/screens/channel/hype_train/
  hype_train_timings.dart                timing table constants
  hype_train_math.dart                   percent, final level, level target, shares, ATH %, totals, treasure/community state
  hype_train_reducer.dart                applyEvent(train, event) → HtApplyResult (pure)
  hype_train_queue.dart                  HtEventQueue (cap 100, back-pressure, conductor replace, drain-on-end)
  hype_train_sequence.dart               planSequence(...) → List<HtStep> (pure; timing table)
  hype_train_clock.dart                  server-skew estimator (Hermes notification timestamps)
  hype_train_palette.dart                HtStyle → colours/icons derived from ColorScheme (+ creator colour)
  hype_train_format.dart                 mm:ss, compact numbers, a11y strings (our own English copy)
  stores/hype_train_store.dart (+.g)     MobX state machine + timers + presentation loop
  widgets/ hype_train_slot.dart, hype_train_banner.dart, hype_train_progress_bar.dart,
           hype_train_marquee.dart, hype_train_level_pill.dart, hype_train_countdown.dart,
           hype_train_approaching_banner.dart, hype_train_end_strip.dart, hype_train_pill.dart,
           hype_train_sheet.dart, hype_train_emote.dart, hype_train_avatar_stack.dart
  widgets/effects/ coin_unlock.dart, rocket_launch.dart, rainbow_sweep.dart, trophy_burst.dart,
           mythic_reveal.dart, merge_aura.dart
lib/dev_hype_train_harness.dart          dev-only entrypoint (fixture replay + live finder)
```

Data flow:

```
TwitchRealtimeClient ──topic events──┐
                                     ▼
TwitchHypeTrainService ─snapshot─▶ HypeTrainStore ──(reducer + queue + sequence planner + timers)──▶ observables
                                     ▲                                                                   │
           VideoChat (resume, settings toggle, presenter attach/detach)                                   ▼
                                                                         HypeTrainSlot / Pill / Sheet (Observer)
```

Store state machine (notes §2.1, adjusted to the verified ordering):

```
Init ─channel set─▶ Idling ─GQL ongoing / start / level-up─▶ Ongoing ─end (or +10 s fallback)─▶ Ending(sequence) ─▶ Rewards|Expired strip (20 s) ─▶ Idling
          Idling ─approaching (first deadline > 20 s away)─▶ Approaching ─start / any train event─▶ Ongoing (bar drawn full first)
          Approaching ─all deadlines passed + 5 s without start─▶ Idling (GQL refetch confirms)
          any ─app resume / resubscribe─▶ GQL refetch (single-flight, 2 s debounce) reconciles
```

---

## Commit sequence and dependencies

```
R1 hermes codec ─▶ R2 realtime client ─▶ R3 provide client ─┐   (R4 optional pubsub fallback)
H1 models ─▶ H2 gql service ────────────────────────────────┤
H1 ─▶ H3 reducer + queue ─▶ H4 sequence planner ────────────┤
                                                            ▼
                                     H5 HypeTrainStore (needs R2, H2, H3, H4)
                                                            ▼
                     H6 banner + approaching + end strips ─▶ H7 dev harness ─▶ H8 variant effects ─▶ H9 sheet
                                                            ▼
                                     H10 setting toggle ─▶ H11 channel integration ─▶ (H12 optional followed pills) ─▶ H13 docs
```

Each commit must pass `flutter analyze` with no issues and keep `flutter test` green, and must leave the app working. Commit messages are lowercase with no prefix. Up to H10, the new code is unreferenced by the app, so there is zero runtime risk.

---

### R1: `add the hermes realtime protocol codec`

**Goal:** pure, fully tested encode/decode of Hermes frames, with no I/O.

**Files**
- UPDATE `lib/constants.dart`: `const kTwitchWebClientId = 'kimne78kx3ncx6brgo4mv6wki5h1ko';` (public, not a secret). `twitch_stream_service.dart` and `twitch_vod_service.dart` keep their private copies, so the live path stays byte-for-byte (follow-up in D13).
- CREATE `lib/services/realtime/hermes_protocol.dart`:
  - `final hermesEndpoint = Uri.parse('wss://hermes.twitch.tv/v1?clientId=$kTwitchWebClientId');`
  - `sealed class HermesFrame` with these members:
    - `HermesWelcome(sessionId, keepalive: Duration (default 15 s when missing or ≤0), recoveryUrl: String?)`
    - `HermesKeepalive`
    - `HermesSubscribeResult(parentId, subscriptionId, ok, error?, errorCode?)`
    - `HermesUnsubscribeResult(parentId, subscriptionId, ok)`
    - `HermesNotification(id, subscriptionId, payload: String (inner pubsub JSON; when the server sends an object instead of a string, re-encode it), serverTime: DateTime?)`
    - `HermesReconnect(url: String?)`
    - `HermesAuthenticateResult`
    - `HermesUnknown(type)`
    - `HermesMalformed`
  - `HermesFrame decodeHermesFrame(String text)`:
    - never throws
    - rejects text longer than 256 KB (`HermesMalformed`)
    - reads the `type` key
    - takes `timestamp` with `DateTime.tryParse`
  - `String encodeSubscribe({required String messageId, required String subscriptionId, required String topic, required DateTime now})` and `encodeUnsubscribe({messageId, subscriptionId, now})`. Use the exact verified shapes, with `timestamp` as UTC ISO-8601 with milliseconds.
  - `enum HermesCloseKind { normal, reconnect, fatal }` and `HermesCloseKind classifyHermesClose(int? code)`:
    - `fatal`: 4010, 4111, 4112, 4120–4123, 4130 (verified "client ID required"), 4131
    - `normal`: 1000 when we initiated it (the caller passes `initiatedByUs`)
    - `reconnect`: everything else, including 4001, 4002, **4100** (verified "ping pong failed"), 1006 and `null` (D10)
  - `bool isValidPubSubTopic(String t)` = `^[a-z0-9-]+(?:\.[a-z0-9-]+)*\.[0-9]{1,20}$`. The channel id ends up in a frame, so it is validated.
  - `String newHermesId(Random rng)`: a UUID-v4-format string from `Random.secure()`; no new package.
- CREATE `test/fixtures/hermes_frames.dart`: the verified frames above, with the opaque `recoveryUrl` token and session ids replaced by placeholders.

**Tests first** (`test/services/realtime/hermes_protocol_test.dart`)
- decode: the welcome (keepalive 15 s, recoveryUrl and sessionId read), the keepalive, subscribe ok, subscribe error `SUB002` (error and errorCode kept), unsubscribe ok
- the notification: subscriptionId, `serverTime`, inner payload kept as the raw string, an object-form payload re-encoded
- `reconnect` with and without a url
- an unknown `type` → `HermesUnknown`
- non-JSON, a JSON array, a missing `type`, a 300 KB string → `HermesMalformed`; none of them throw
- encode: the exact key set and nesting for subscribe/unsubscribe; the timestamp format; the round trip `decode(encode)` is not needed (client frames only)
- `classifyHermesClose`: 4130/4010/4131 → fatal; 4100/4001/1006/null → reconnect
- `isValidPubSubTopic`:
  - accepts `hype-train-events-v2.123`, `video-playback-by-id.1`
  - rejects `hype-train-events-v2.`, `x.12a`, `a b.1`, `../1`, a 21-digit id
- `newHermesId`: matches the UUID-v4 regex; 1000 calls give unique values

**Risks:** the unobserved `reconnect` shape (Low). Mitigation: tolerant parsing; any reconnect frame triggers a fresh connect.
**Acceptance:** tests green, analyze clean, no other file touched besides `constants.dart`.

---

### R2: `add the realtime client with reconnect and resubscribe`

**Goal:** a reusable, isolated, fully fake-time-tested Hermes client.

**Files**
- UPDATE `pubspec.yaml`. The file is CRLF: preserve the line endings. Both packages are already in the lockfile as transitive dependencies.
  - `clock: ^1.1.2` under `dependencies`
  - `fake_async: ^1.3.3` under `dev_dependencies`
- CREATE `lib/services/realtime/realtime_socket.dart`:
  - `abstract interface class RealtimeSocket { Stream<String> get messages; Future<void> get ready; void send(String text); Future<void> close([int? code, String? reason]); int? get closeCode; String? get closeReason; }`
  - `typedef RealtimeSocketFactory = RealtimeSocket Function(Uri uri);`
  - `class WebSocketChannelSocket implements RealtimeSocket` wraps `WebSocketChannel.connect(uri)` (web_socket_channel 3.0.3; on Android/iOS this is `IOWebSocketChannel`, so WS pings get automatic pongs). Binary frames are ignored.
- CREATE `lib/services/realtime/twitch_realtime_client.dart`:
  - `sealed class RealtimeTopicEvent`:
    - `RealtimeMessage(String payload, DateTime? serverTime)`
    - `RealtimeSubscribed({required bool isResubscribe})`
    - `RealtimeUnavailable(String reason, {bool permanent})`
  - `class RealtimeTopicSubscription { final String topic; Stream<RealtimeTopicEvent> get events; Future<void> cancel(); }`
  - `enum RealtimeConnectionState { idle, connecting, connected, reconnecting, paused, failed }`
  - `class TwitchRealtimeClient`:
    - Constructor parameters:
      - `RealtimeSocketFactory? connect`, `Uri? endpoint` (default `hermesEndpoint`), `Random? random`
      - `Duration idleClose = const Duration(seconds: 30)`, `Duration backgroundGrace = const Duration(seconds: 60)`
      - `Duration unsubscribeDelay = const Duration(milliseconds: 500)` (the Android flag `Android-Hermes-Unsubscribe-Delay-Millis = 500`)
      - `Set<String> authTopicPrefixes = const {'hype-train-events-v1.rewards.', 'whispers.', …}`: the client refuses these anonymously (verified that the server does not)
    - `RealtimeTopicSubscription subscribe(String topic)` throws `ArgumentError` for an invalid topic and `StateError` for an auth-only topic.
    - `RealtimeConnectionState get state`; `Stream<RealtimeConnectionState> get states` (broadcast)
    - `void onAppPaused()`, `void onAppResumed()`, `Future<void> dispose()`
  - Behaviour:
    - **Lazy connect:** the first `subscribe` opens one socket; later subscribes reuse it.
    - **On welcome:** record the keepalive. Start the **watchdog** = `keepalive + 5 s` (20 s by default). Any frame resets it; expiry → reconnect. Send `subscribe` for every registered topic. Frames sent before the welcome are queued.
    - **Topic registry** `topic → {refCount, subscriptionId, pendingMessageId, StreamController.broadcast}`. The subscription id is fresh for each session. Two `subscribe(topic)` calls make one Hermes subscribe. When the reference count reaches 0, the unsubscribe is sent after `unsubscribeDelay`, and only if the count is still 0, so a fast channel switch does not churn. Once no topics remain, the socket closes after `idleClose`.
    - **Subscribe results:**
      - `ok` emits `RealtimeSubscribed(isResubscribe: sessionCount > 1)`. Consumers refetch on a resubscribe, because events may have been missed in the gap.
      - `error` emits `RealtimeUnavailable(errorCode, permanent: true)`, with no retry for that topic until the next session.
    - **Notifications** route by subscription id to the topic controller. An unknown id is ignored. Each `add` goes through a `try/catch`, so a throwing listener cannot break the socket loop.
    - **Close and reconnect:**
      - `onDone` / `onError` / watchdog expiry → `reconnecting`, then backoff: 1, 2, 4, 8, 16 s, then 30 s cap, ±20% jitter.
      - The first retry after a long healthy session is immediate.
      - The backoff resets once a session has stayed connected for 60 s.
      - A reconnect always opens a **fresh `/v1` session** and resubscribes everything; `recoveryUrl` is not used (D9).
      - A `reconnect` frame → immediate reconnect with no backoff.
      - A `fatal` close → `failed`, plus `RealtimeUnavailable(permanent: true)` to all topics. There is no retry loop, but a new `subscribe` or `onAppResumed` retries once, at most every 5 min.
    - **Lifecycle:**
      - `onAppPaused` starts the background grace timer. When it fires, the socket closes (state `paused`) and the registry is kept.
      - `onAppResumed` cancels the grace timer. If the socket is closed, it reconnects at once and resubscribes, and consumers get `isResubscribe: true`.
      - PiP keeps the app `inactive`, not `paused`, so the socket stays up during PiP.
    - `dispose()` closes the socket with code 1000, cancels every timer and closes the controllers.
    - Debug logging covers state transitions, close codes and topic *families* only.
- CREATE `test/helpers/fake_realtime_socket.dart`: `FakeRealtimeSocket` (records `sent`, can `serverSend(String)`, `serverClose(int code, [reason])` and `failConnect()`) and `FakeRealtimeSocketFactory` (records the URIs it opened and returns the scripted sockets).

**Tests first** (`test/services/realtime/twitch_realtime_client_test.dart`, all inside `fakeAsync`)
- no socket until the first `subscribe`; the URI equals the Hermes endpoint with `clientId`
- a second topic reuses the socket
- subscribe frames are sent only after the welcome, with type `pubsub`, the right topic and unique ids
- `subscribeResponse ok` → `RealtimeSubscribed(isResubscribe:false)`; `SUB002` → `RealtimeUnavailable(permanent:true)` and no retry
- a notification is delivered only to its topic, as the raw inner string, with `serverTime`
- an unknown subscription id and a malformed frame are ignored
- a listener that throws does not stop delivery to another topic
- watchdog:
  - silence for 20 s → reconnect
  - keepalives every 10 s for 120 s → no reconnect
  - the welcome's `keepaliveSec: 30` → the watchdog becomes 35 s
- close 1006 → reconnect after 1 s, then 2 s, then 4 s (jitter seeded by an injected `Random`)
- on success, every topic is resubscribed and `RealtimeSubscribed(isResubscribe:true)` is emitted
- the backoff resets after 60 s connected
- close 4130 → `failed`, `RealtimeUnavailable` to all topics, no reconnect for 10 min of fake time; a new `subscribe` retries once
- close 4100 → reconnect
- a `reconnect` frame → immediate new socket; the old one is closed
- reference counting:
  - subscribe ×2 and cancel ×1 → no unsubscribe sent
  - cancel ×2 → unsubscribe after 500 ms
  - re-subscribe within 500 ms → no unsubscribe and no new subscribe
  - all cancelled → socket closed after 30 s; a later subscribe reopens it
- lifecycle:
  - paused for 59 s, then resumed → socket untouched
  - paused for 61 s → closed (`paused`); resumed → new socket, resubscribed, `isResubscribe:true`
- `dispose` → close code 1000 sent; `async.pendingTimers` is empty; streams are done
- `subscribe('hype-train-events-v1.rewards.1')` → `StateError`; `subscribe('bad topic')` → `ArgumentError`
- a frame larger than 256 KB is dropped

**Risks**
- `dart:io` not answering pings, which would cause a 4100 close loop every 10 s (Low). Mitigation: verified by the R3 device check (connection survives 3 min); otherwise add `pingInterval` in the adapter.
- Timer leaks (Medium). Mitigation: the `pendingTimers`-empty assertion.

**Acceptance:** tests green; `fake_async` used only under `test/`; nothing in the app references the client yet.

---

### R3: `provide the realtime client app-wide`

**Files**
- UPDATE `lib/main.dart`:
  - create `final realtimeClient = TwitchRealtimeClient();` next to `twitchVodService` (l.~122)
  - `AppLifecycleListener(onPause: realtimeClient.onAppPaused, onResume: realtimeClient.onAppResumed)`, kept alive for the app lifetime
  - `Provider<TwitchRealtimeClient>.value(value: realtimeClient)` in the `MultiProvider` (l.~155)
- UPDATE `lib/utils/context_extensions.dart`: `TwitchRealtimeClient get realtimeClient => read<TwitchRealtimeClient>();`

**Tests first:** `test/services/realtime/twitch_realtime_client_test.dart` asserts that constructing the client opens no socket (lazy). The app-level wiring is trivial and covered by the device check.

**Device check** (debug build, temporary harness call or `flutter run -t lib/dev_hype_train_harness.dart` once H7 exists): subscribe one active topic for 3 min, then confirm `connected` throughout. This proves the WS ping is answered.

**Acceptance:** the app launches; no Hermes socket opens (no `TwitchRealtimeClient` debug log) until something subscribes; analyze and tests green.

---

### R4 (optional, D7): `add a legacy pubsub fallback transport`

A `PubSubProtocol` codec (`LISTEN`/`UNLISTEN` with nonce, `RESPONSE`, `MESSAGE{data{topic,message}}`, client `PING` every 4 min plus a 10 s `PONG` deadline, `RECONNECT`) behind the same `TwitchRealtimeClient` API. The client switches to it after 3 consecutive fatal Hermes failures. Verified anonymous today. Skip unless the user wants belt and braces.

---

### H1: `add hype train models and event parsing`

**Goal:** typed, defensive models for GQL and realtime shapes; parsing never throws.

**Files**
- CREATE `lib/models/hype_train.dart`. All parsing is hand-written, with key helpers `_str(m, ['camel','snake'])`, `_int`, `_bool`, `_date` (ISO or epoch ms).
  - **Enums:**
    - `HtVariant { regular, goldenKappa, treasure, community, mythic }`; PINATA → regular (D16)
    - `HtAthState { none, approaching, reached, justReached }`
    - `HtSource { bits, subs, explicitPurchase, admin, raid, unknown }`
    - `HtAction` with `unknown` that keeps `raw`; `EXTENSION` maps to `unknown` with `raw:'EXTENSION'`
    - `HtEndReason { completed, expired, inProgress, unknown }`
    - `HtUnlockStatus { none, approaching, reached }`
  - **`HtReward`** `{type: emote|badge|unknown, id, token?, imageUrl?, setId?}`.
    - Emote rewards come in the PubSub flat form `{type,id,token}` or the GQL form `{__typename?, id, type, emote{id token}}`.
    - `Uri? emoteUrl` is built only when `id` matches `^[A-Za-z0-9_]+$`, as `<_twitchEmoteBaseUrl>/<id>/default/dark/3.0`.
    - `badgeUrl` is accepted only for `https://static-cdn.jtvnw.net/...`.
  - **`HtLevel`** `{value, cumulativeGoal, rewards}`
  - **`HtProgress`** `{level: HtLevel, goal (in-level), value (in-level; GQL progression / PubSub value), total, remainingSeconds?, athState}`
  - **`HtConductor`** `{source, userId, login, displayName, profileImageUrl?, participations: Map<String,int>}`. It accepts the GQL `participation[]` list and the PubSub `"SOURCE.ACTION"` map.
  - **`HtConfig`** `{difficulty?, maxLevel?, conversionRates: Map<String action,int> (ignores UNKNOWN and 0), currentConductorBadge: Map<HtSource,String url>, calloutEmote: HtReward?, creatorColor: int? ('BD0078' or '#BD0078' → 0xFFBD0078; null when willUseCreatorColor is false or the value is invalid), kickoffMinPoints?}`
  - **Variant details:**
    - `HtTreasure {discountPercentage, threshold, status}`, reading camel or snake keys (verified duplicates)
    - `HtCommunity {current, next, previous, threshold (default 5), status, maxRewardLevel?}`
    - `HtMythic {selectedEmote?, pool}`
  - **Shared and ATH:**
    - `HtSharedChannel {userId, login, displayName, profileImageUrl?, progress?, ath?}`
    - `HtShared {id, channels, conductorsByChannel}`
    - `HtAth {level, goal, progression, total}`
  - **`HypeTrainExecution`** `{id, startedAt?, expiresAt?, endedAt?, endReason, progress, conductors, config, ath?, variant, treasure?, community?, mythic?, shared?, isFastMode}`.
    - `fromGql(map)` also accepts the level-up `hype_train` (GQL shape, `endReason:"IN_PROGRESS"`).
    - Variant precedence: Mythic, then Community, then Golden (`isGoldenKappaTrain` or `__typename GoldenKappaTrainDetails`), then Treasure (`isTreasureTrain`, `treasureTrainDetails`, or `variantTrainDetails.__typename == TreasureTrainDetails`), then Regular. `shared` is orthogonal.
  - **`HypeTrainApproaching`** `{id, goal, creatorColor?, deadlines: Map<int events, int secondsRemaining>, participants: Set<String>, levelOneRewards, variant}`. It accepts the GQL `eventsRemaining[{events,secondsRemaining}]` list and the PubSub `events_remaining_durations{"1":286}` map (TBC: not observed live). Keys and values must be positive integers.
- CREATE `lib/models/hype_train_event.dart`:
  - `sealed class HypeTrainEvent`, built by `static HypeTrainEvent parse(String pubsubJson)`. It catches everything; a bad payload → `HtUnknownEvent(type)`.
  - **Event types:**

    | Class | Fields |
    |---|---|
    | `HtApproachingEvent` | `approaching` |
    | `HtStartEvent` | `train` (also built from `hype-train-shared-conversion`) |
    | `HtProgressionEvent` | `trainId, sequenceId (falls back to progress.total), userId, login, displayName, profileImageUrl?, action, source, quantity, isLarge, progress, expiresAt?, sharedProgress?, treasure?` |
    | `HtLevelUpEvent` | `timeToExpire: DateTime (epoch ms), progress, train?` |
    | `HtConductorEvent` | `conductor` (blank user id → `HtUnknownEvent`) |
    | `HtEndEvent` | `endedAt?, reason, totals: List<(source, action, quantity)>, rewards` |
    | `HtMergeEvent` | `train, prevProgress?, prevUsers, joiningUsers` |
    | `HtChannelLeftEvent` | `trainId, continuesIn?, shouldEnd` |
    | `HtIgnoredEvent` | `type` (cooldown-expiration, reward-eligibility) |
    | `HtUnknownEvent` | `type` |

- CREATE `test/fixtures/hype_train_payloads.dart`:
  - **Verified captures**, trimmed to two rewards each and anonymised (user ids, logins, avatar URLs): GQL lean regular, GQL golden, GQL none, progression (with treasure duplicates), duplicate progression, early next-level progression, level-up (golden), conductor-update, end COMPLETED
  - **From the notes (TBC):** approaching (GQL and PubSub), start, end EXPIRED, community, mythic, shared, ATH, merge, channel-left, conversion

**Tests first**
- `test/models/hype_train_test.dart`:
  - lean GQL regular: level 7, in-level 1540/4700, total 16040, cumulative goal 19200, `maxLevel` 392
  - conversion rates without the UNKNOWN entries; the conductor badge for CURRENT only
  - `creatorColor` `'BD0078'` → `0xFFBD0078`; `null` stays null; `'zzz'` → null
  - golden detected from the flag and from `__typename`
  - treasure from either key casing
  - community threshold defaults to 5
  - mythic pool parsed
  - shared channels with progress
  - PINATA → regular
  - approaching from the GQL list and from the PubSub map; a bad key like `"x"` is skipped
  - emote URL rejects `../x` and badge URL rejects `http://evil`
- `test/models/hype_train_event_test.dart`:
  - progression: every field read; `EXTENSION` → `unknown` with `raw`; `sequenceId` equals the total
  - level-up `time_to_expire` → `DateTime.utc(2026,10,13,16,5,26)`; `hype_train` parsed into a golden execution
  - conductor map `"SUBS.TIER_1_GIFTED_SUB":10` parsed; a blank user → unknown
  - end: epoch-ms `ended_at`, totals and rewards in GQL shape
  - `hype-train-shared-conversion` → `HtStartEvent`
  - cooldown → `HtIgnoredEvent`
  - an unknown type → `HtUnknownEvent`
  - `'{'`, `'[]'`, `'{"type":"hype-train-progression","data":{}}'` → unknown and never throw

**Risks**
- Unobserved shapes: approaching, start, community, mythic, shared (Medium). Mitigation: tolerant parsing and (TBC) fixtures. When a train of that kind runs, capture it with the H7 harness's "record" mode and replace the fixture.

**Acceptance:** tests green; no codegen.

---

### H2: `add the hype train gql service`

**Files**
- CREATE `lib/apis/twitch_hype_train_service.dart`: `class TwitchHypeTrainService extends BaseApiClient`. It has its own `Dio` with timeouts of 5 s / 8 s, like the VOD service.
  - `static const _executionQuery`: the **lean** verified document. It has operation name `GetHypeTrainExecution`, variables `$channelId: ID!, $includeSharedHypeTrain: Boolean!`, and fragments for level, progress, completed and user. It uses `difficultySettings{difficulty maxLevel}` without `levels`, and adds `isFastMode` and `config.kickoff{minPoints}`.
  - `Future<HypeTrainSnapshot> getHypeTrain(String channelId)` returns `sealed HypeTrainSnapshot { HtNoTrain, HtApproachingSnapshot(approaching), HtOngoingSnapshot(train, fetchedAt) }`:
    - `user == null` → `HtNoTrain`
    - `execution` present with `isActive` → ongoing
    - else `approaching` → approaching
    - else → none
    - GQL `errors` → `HypeTrainApiException(message, isIntegrity)`; transport errors propagate as `ApiException`
  - `Future<List<(int level, List<HtReward>)>> getUpcomingRewards(String channelId)`: a separate lazy document for the sheet, `config.potentialRewards{level value{…emote}}`, sorted by level. It never throws and returns `[]` on failure.
  - `static String normalizeChannelId(String raw)`: `^[0-9]{1,20}$`, otherwise `ArgumentError`.
- UPDATE `lib/main.dart` (provider) and `lib/utils/context_extensions.dart` (`twitchHypeTrainService`).

**Tests first** (`test/apis/twitch_hype_train_service_test.dart`, DioAdapter, `https://gql.twitch.tv/gql`)
- the request carries the `Client-ID` header, `operationName`, `channelId` and `includeSharedHypeTrain: true`
- the query does not contain `levels {`
- the regular fixture → ongoing, level 7; the golden fixture → variant `goldenKappa`
- none → `HtNoTrain`; an approaching fixture (TBC) → approaching
- `user: null` → none
- `errors` → `HypeTrainApiException`; an integrity message sets `isIntegrity`
- `getUpcomingRewards` sorts by level; an `errors` response → `[]`
- `normalizeChannelId('12a')` throws

**Risks:** schema drift or integrity gating later (Medium). Mitigation: the typed exception; the store treats it as "no snapshot" and stays realtime-only.
**Acceptance:** tests green; no change to the other services.

---

### H3: `add the hype train reducer and event queue`

**Files** (all pure Dart under `lib/screens/channel/hype_train/`)
- `hype_train_math.dart`:
  - `int percent(HtProgress p)` = `(p.value / p.goal * 100).round().clamp(0, 100)`; goal ≤ 0 → 0. Uses in-level values (verified).
  - `bool isFinalLevel(train)` = `maxLevel != null && level >= maxLevel`
  - `({int subs, int bits}) levelTarget(train)` = `ceil(progress.goal / rate['TIER_1_SUB'] ?? 500)` and `ceil(progress.goal / rate['CHEER'] ?? 1)`. This is the in-level goal, for parity (D6).
  - `List<(HtSharedChannel, int pct)> topShares(shared, {int n = 3})` = `channel.total / Σ total`, sorted descending
  - `int athPercent(HtAth a)` capped at 100
  - `({int bits, int subs}) endTotals(totals)`: Bits = sum where source is BITS; subs = sum where source is SUBS
  - `TreasureState treasureState(train)` → `{locked, oneLevelAway (level + 1 == threshold), unlocked (level ≥ threshold), unlockNow (level == threshold)}`
  - `CommunityState` likewise, with threshold default 5
- `hype_train_reducer.dart`: `HtApplyResult applyEvent(HypeTrainExecution t, HypeTrainEvent e, {required Set<String> seenIds})` → `{train, applied, ignoredReason?, levelChangedFrom?, athTransition (none/approaching/reached), treasureUnlockedNow, communityUnlockedNow, deferredNextLevel}`:
  - **Progression:**
    - ignore if `trainId:sequenceId` is already in `seenIds` (redelivery) or `e.sequenceId < t.progress.total` (stale); equal is allowed (the level-up may have come first)
    - if `e.progress.level.value == t.level + 1`, mark `deferredNextLevel` and do not apply (verified ordering); the store waits up to 3 s for the level-up
    - any other level mismatch → ignore
    - otherwise replace the progress, `expiresAt` (from `expires_at` when present), the ATH state (shared: this channel's entry), and the treasure details
  - **Level-up:** replace the progress; `expiresAt = timeToExpire`; refresh variant, shared and config details from `train` when present; record `levelChangedFrom`; compute `unlockNow` flags
  - **Conductor:** upsert by source; a new source goes to the top
  - **End:** set the reason, totals and rewards
  - **Merge:** replace the whole train; keep `prev`/`joining`
  - **Channel left:** `shouldEnd` → synthesise an end with reason COMPLETED; otherwise record `continuesIn`
- `hype_train_queue.dart`: `class HtEventQueue` with `maxLength = 100` (the oldest is dropped beyond it).
  - `enqueue(e)`:
    - when ≥5 are already queued, drop a non-large progression
    - a conductor update replaces a queued conductor for the same source in place
    - a level-up whose level equals the last merge-announced level becomes a plain progress
  - `HypeTrainEvent? pop()`
  - `List<HypeTrainEvent> drainForEnd()`
  - `clear()`
  - `int get length`

**Tests first**
- `test/screens/channel/hype_train/hype_train_math_test.dart`:
  - percent 1540/4700 = 33; 0 goal → 0; overflow clamps to 100
  - final level at 392
  - level target 4700 → 10 subs / 4700 Bits; a missing rate falls back
  - top shares sorted and capped at 3
  - ATH capped at 100
  - end totals from the captured fixture (subs 4, bits 0)
  - treasure: oneLevelAway, unlockNow and unlocked across levels 1, 2, 3 with threshold 2
  - community threshold default 5
- `test/screens/channel/hype_train/hype_train_reducer_test.dart`:
  - progression applies at the same level
  - a duplicate `id` is ignored
  - a lower `sequence_id` is ignored
  - a next-level progression is deferred, not applied
  - a two-level jump is ignored
  - level-up sets `expiresAt` from epoch ms and records `levelChangedFrom`
  - level-up with `train` refreshes the variant (golden)
  - a conductor with a new source goes to the top; the same source replaces
  - end sets the totals and rewards
  - channel-left `shouldEnd` → completed; merge replaces the id and level
  - ATH NONE→APPROACHING and APPROACHING→REACHED transitions are flagged
  - treasure `unlockNow` only at the threshold level
- `test/screens/channel/hype_train/hype_train_queue_test.dart`:
  - FIFO
  - the 5th small progression is dropped while a large one is kept
  - a conductor replaces in place (order kept)
  - `drainForEnd` returns everything in order and empties the queue
  - the cap of 100
  - merge-level dedupe

**Acceptance:** tests green; pure Dart (no Flutter import except `foundation` for `@immutable`).

---

### H4: `add the hype train sequence planner`

**Files**
- `hype_train_timings.dart`: `HtTimings`, from notes §2.5:

  | Constant | ms |
  |---|---|
  | `textLong` | 6000 |
  | `scrollLong` | 3000 |
  | `scrollDefault` | 2500 |
  | `textShort` | 2000 |
  | `fade` | 1000 |
  | `short` | 500 |
  | `extraShort` | 200 |
  | `endStrip` | 20000 |
  | `stripTick` | 500 |
  | `approachingTick` | 500 |
  | `unlockEffect` | 1600 (ours: the Lottie length is unknown) |

  Also: `rainbowCycle` levelUp 2000 / complete 4500 / athComplete 4200, with `rainbowCycles = 3`; `approachingMinWindow = Duration(seconds: 20)`; `expiryGrace = Duration(seconds: 10)`.
- `hype_train_sequence.dart`:
  - `enum HtStepKind { fadeIn, fadeOut, progress, fillTo, flash100, marquee, instruction, levelComplete, sharedAvatars, sharedTop3, largeContribution, coinUnlock, rocketLaunch, mythicPool, mythicSelect, mythicReveal, athReached, athOtherChannel, mergeAura, channelLeftSummary, continuesIn, totals, summary, rewardsStrip, expiredStrip }`
  - `class HtStep { kind, duration, Map data; bool rainbow; }`
  - `List<HtStep> planSequence(HtPlanInput input)`. The input holds `{event, before, after, applyResult, style, compact (pill/landscape), reduceMotion, presenterVisible}`.
  - Mapping (notes §3.2):

    | Event | Steps |
    |---|---|
    | Start (non-shared) | fadeIn 500 → marquee 3000 (callout emote ×3; mythic: pool) → instruction 2000 → treasure/community "reach level X" 2000 → progress |
    | Start (shared) | fadeIn 500 → sharedAvatars 6000 → instruction 2000 |
    | Progression | fillTo 200 |
    | Large progression | fadeOut 500 → largeContribution 6000 → fadeIn 500 → fillTo 200 |
    | Level-up (new level ≥ 2) | fillTo(100) 200 → flash100 500 → marquee 2500 (shared: `rainbow` on, 3 × 2000) → levelComplete 500 → [shared: sharedTop3 1000 + 2500] → [treasure unlockNow: coinUnlock 1600 → marquee 3000 → instruction 2000 \| oneLevelAway: instruction 2000] → [community unlockNow: rocketLaunch 1600 → marquee 3000 → instruction 2000] → [mythic: mythicPool 2500 → instruction 2000] → fillTo(new %) 200 |
    | ATH transition to reached | athReached 6000 → [shared: athOtherChannel 6000 per other channel that newly reached] |
    | ATH transition to approaching | fadeIn 500 (style switch only) |
    | Merge | mergeAura 1000 → marquee 3000 (level pill counts from previous to merged) → progress |
    | Channel left | channelLeftSummary 2000 → continuesIn 3000 (or instruction 3000 "see you next time") |
    | Conductor | [] (zero time) |
    | End COMPLETED | marquee 3000 (shared rainbow 3 × 4500; ATH 3 × 4200) → [mythic: mythicSelect 2000 → mythicReveal 2000] → [community: instruction 2000] → totals 6000 → [shared: sharedTop3 1000 + 2500] → summary 2000 (ATH variant) → rewardsStrip 20000 |
    | End EXPIRED / UNKNOWN | expiredStrip 20000 |

  - Modifiers:
    - `reduceMotion`: marquees become static text with the same hold time; no rainbow; coin and rocket become a static icon for 1000.
    - `compact` (pill): only levelComplete 2500 for a level-up and the strips; everything else is [].
    - `!presenterVisible`: every duration becomes 0 except the strips, which are skipped. This is the notes' "skip when not shown" rule.

**Tests first** (`test/screens/channel/hype_train/hype_train_sequence_test.dart`)
- One test per row: the exact kinds in order, their durations and `total`.
- The level-up at level 1 has no animation; level 2 gets the full sequence.
- Treasure: threshold vs one-before vs after.
- Community threshold; mythic pool.
- Large contribution total 7200.
- Shared rainbow flag set; ATH-reached adds one slide per newly reached other channel.
- End completed in its regular, mythic, community, shared and ATH flavours.
- End expired → only `expiredStrip` 20000.
- reduceMotion: no `rainbow`, no `coinUnlock`, same total hold for text.
- compact.
- Invisible presenter → total 0 and no strips.

**Acceptance:** tests green; pure.

---

### H5: `add the hype train store`

**Files**
- `hype_train_clock.dart`: `class ServerClock`. `observe(DateTime serverTime)` keeps the median of the last 5 offsets against `clock.now()`. `DateTime now()` = `clock.now() + offset`. Untrusted offsets larger than 10 min are ignored.
- `stores/hype_train_store.dart` (+ `hype_train_store.g.dart` via build_runner): `HypeTrainStore = HypeTrainStoreBase with _$HypeTrainStore`.
  - Constructor: `{required String channelId, required TwitchHypeTrainService service, required TwitchRealtimeClient realtime, String? Function()? viewerId}`. The viewer id is used only for the local `participants` check.
  - **Observables** (`@readonly` unless noted):
    - `HtPhase phase { hidden, approaching, ongoing, ending, rewards, expired }`
    - `HypeTrainExecution? train`, `HypeTrainApproaching? approaching`
    - `HtStep? step`, `int stepIndex`
    - `Duration remaining`
    - `double approachingFraction`, `int approachingChecks`, `bool approachingCompleted`
    - `double stripFraction`
    - `HtEndSummary? endSummary` (reason, level, bits, subs, rewards, ath?)
    - `List<HtReward> unlockedRewards` (session cache of earned emotes)
    - `bool realtimeDegraded`
    - plain observables: `bool expanded`, `bool collapsed`
  - **Computed:** `percent`, `level`, `style` (priority: ATH-approaching > ATH-reached > Golden > Mythic > Shared > Treasure > Community > Default), `isFinalLevel`, `levelTarget`, `bool visible` (phase ≠ hidden), `String semanticsSummary`.
  - **Actions:** `attachPresenter({bool compact})` / `detachPresenter()` (counted), `toggleExpanded()`, `setCollapsed(bool)`, `handleAppResume()`, `@visibleForTesting injectEvent(HypeTrainEvent)`, `dispose()`.
  - **Startup:** `realtime.subscribe('hype-train-events-v2.$channelId')` plus `_refetch()`.
  - **Refetch** (`_refetch`): single-flight with a minimum interval of 2 s.
    - Ongoing → `train = snapshot`. The queue is cleared and no start animation plays: the progress shows immediately (the notes' "Progress marker").
    - Approaching → apply the 20 s rule.
    - None while `ongoing` → if the `expiresAt + 10 s` fallback is still pending, wait for it; otherwise go `hidden` with no end animation (the train ended unseen).
    - Exception → keep the state and count failures.
  - **Realtime events:**
    - `RealtimeMessage` → `ServerClock.observe` → `HypeTrainEvent.parse`.
    - In `hidden`/idling:
      - Start or level-up-with-train → build the train locally and go ongoing.
      - Approaching → 20 s rule.
      - Progression or conductor with no train → `_refetch()` (the notes' MissedStartPubSub).
    - In `approaching`: any train event → `approachingCompleted = true` (bar full), then queue it.
    - In `ongoing`: `queue.enqueue`.
    - End: `drainForEnd()` is applied instantly (reducer only, no steps), then the end is presented.
  - **`RealtimeSubscribed(isResubscribe: true)`** → `_refetch()`.
  - **`RealtimeUnavailable`** → `realtimeDegraded = true`. While a train or approaching is active, poll `_refetch()` every 20 s (D12); stop when hidden.
  - **Presentation loop:** `_pump()`.
    - If `busy` or the queue is empty, return.
    - Otherwise pop → reducer → `planSequence` → set `step` and schedule a `Timer` per step → `busy` until the last step → `_pump()` again.
    - A deferred next-level progression starts a 3 s timer; with no level-up by then → `_refetch()`.
  - **Timers** (all `clock`-based):
    - **Countdown:** `Timer.periodic(1 s)` recomputes `remaining = expiresAt − serverClock.now()`, floored at 0. It runs only while ongoing.
    - **Expiry fallback:** at `expiresAt + 10 s` with no end → synthesise `HtEndEvent(reason: level >= 2 ? completed : expired)` (D5). It is rescheduled whenever `expiresAt` changes.
    - **Approaching:**
      - each `deadlines[n]` becomes an absolute time
      - accepted only if `deadline[1] − now > 20 s`
      - a 500 ms tick drives `approachingFraction` (span measured from arrival)
      - checks: #1 while key 1 exists, #2 while key 2 exists, #3 never prefilled
      - "N more" when the viewer id is in `participants`
      - all deadlines passed + 5 s with no start → `_refetch()`, then hidden
    - **Strips:** 20 s with a 500 ms tick for `stripFraction`, then `hidden`, clearing the train and `unlockedRewards`. A new approaching or start event cuts a strip short.
  - **Presenter detached** (no banner on screen, for example the mini player or chat hidden with no pill): the queue is applied with zero-duration steps and strips are skipped, so the store never stalls in the background.
  - `dispose()` cancels the subscription, timers and polling. It is idempotent.

**Tests first** (`test/screens/channel/hype_train/stores/hype_train_store_test.dart`, `fakeAsync`; `MockTwitchHypeTrainService`; a `MockTwitchRealtimeClient` whose `subscribe` returns a fake subscription backed by a `StreamController`)

Startup and refetch:
- startup subscribes the right topic and fetches once
- an ongoing snapshot → `phase ongoing`, percent 33, `remaining` counts down 1 s per tick, no start sequence
- a none snapshot → hidden

Approaching:
- approaching 25 s away → `approaching`; 15 s away → ignored (20 s rule)
- deadline keys 1/2 → checks; key 1 passing clears check #1
- the viewer in `participants` → `nMore` flag
- approaching + start event → bar completed, then ongoing with the start sequence `[fadeIn, marquee, instruction]`, and `step` advancing at 500 / 3500 / 5500 ms

Pacing and back-pressure:
- events are presented one at a time (a progression queued behind the start applies only after 5.5 s)
- back-pressure: 10 small progressions during a long sequence leave ≤5 queued
- conductor update → no step and no delay
- duplicate progression (same id) → one application
- next-level progression followed 1 s later by a level-up → level-up sequence; percent from the level-up
- next-level progression with no level-up → refetch after 3 s

End and expiry:
- end COMPLETED → queue drained instantly, end steps, then `rewards` for 20 s, then hidden; `endSummary` totals from the fixture
- no end event: at `expiresAt + 10 s` → completed when level ≥ 2, expired when level 1
- an end event arriving at +9 s cancels the fallback
- an approaching event during the rewards strip cuts it short

Presenter, recovery and lifecycle:
- presenter detached → a whole level-up applies in 0 ms
- `RealtimeSubscribed(isResubscribe:true)` → refetch; two within 2 s → one fetch
- `RealtimeUnavailable` while ongoing → refetch every 20 s; stops when hidden
- service throws → state kept and no crash
- `ServerClock`: notification timestamps 3 s ahead → countdown 3 s shorter
- `handleAppResume` → refetch
- `dispose` → `pendingTimers` empty, subscription cancelled

**Risks**
- Timing interplay bugs (Medium). Mitigation: fake-time tests per transition.
- MobX actions inside `Timer` callbacks (Low). Mitigation: all mutations go through `@action`/`runInAction`.

**Acceptance:** tests green; `dart run build_runner build --delete-conflicting-outputs` produces only `hype_train_store.g.dart`, which is committed.

---

### H6: `add the hype train banner, approaching banner and end strips`

**Files** (`lib/screens/channel/hype_train/widgets/`). All widgets are `Observer`-scoped to the fields they read, with a `RepaintBoundary` at the banner root. Copy is our own English.
- `hype_train_palette.dart` (pure): `HtPalette.of(HtStyle, ColorScheme, {int? creatorColor, Brightness})` → `{background, onBackground, fill, fillEnd?, track, icon IconData, iconColor, a11yName}`.
  - Regular: `primary`/`primaryContainer`; the bar fill is the creator colour when present.
  - Golden: amber 0xFFFFC94D → 0xFFFFA000. Treasure: teal → gold. Community: blue. Mythic: magenta → violet. ATH-approaching: orange. ATH-reached: deep orange/red. Shared: `tertiary` with a rainbow sweep on events.
  - Icons are Material: `Icons.train_rounded`, `Icons.star_rounded` (golden), `Icons.savings_rounded` (treasure), `Icons.rocket_launch_rounded`, `Icons.auto_awesome_rounded`, `Icons.emoji_events_rounded` (ATH), `Icons.groups_rounded` (shared).
  - Contrast-checked (≥4.5:1 text on background) in light and dark.
- `hype_train_progress_bar.dart`: a rounded 6 px bar driven by an `AnimationController` (`fillTo` uses the step duration, 200 ms) with the gradient fill from the palette.
- `hype_train_countdown.dart`: `mm:ss`, tabular figures, its own `Observer` on `remaining` only, `ExcludeSemantics` (it is in the banner label instead).
- `hype_train_level_pill.dart`: "LVL n" pill; `TweenAnimationBuilder<int>` counts on merge.
- `hype_train_marquee.dart`: a single-line text plus inline emotes (`FrostyCachedNetworkImage` 20 px). It slides from the trailing edge to off the leading edge over the step duration, mirrored in RTL via `Directionality`. With reduceMotion it is centred static text.
- `hype_train_banner.dart` (`HypeTrainBanner({required HypeTrainStore store, bool compact})`):
  - **Layout:** icon + level pill | title and subtitle (or the active step's content) | big % | countdown | expand chevron | collapse affordance. Below them, the progress bar. Height is about 72 default and about 48 compact, plus text scaling.
  - **Step content** via an `AnimatedSwitcher(duration: HtTimings.short)` keyed by `ValueKey('ht-step-${step.kind.name}')`: marquee, instruction, levelComplete, largeContribution, flash100 (a scale and opacity pulse on the %), totals, summary.
  - Tap → `store.toggleExpanded()` (the sheet arrives in H9; until then this is a no-op). A swipe up or the collapse button → `setCollapsed(true)`. Collapsed is a 28 px pill with icon, level and %.
  - Sub/gift buttons are **not rendered** (D4).
  - Semantics:
    - root `Semantics(button: true, label: store.semanticsSummary, hint: 'Double tap to show details')`
    - step text inside `Semantics(liveRegion: true)` (level complete, train started, completed)
    - the countdown is excluded
- `hype_train_approaching_banner.dart`: icon + title + subtitle ("N more" variant) + three check circles (filled when `approachingChecks ≥ i`, creator-tinted) + a countdown bar with 500 ms ticks (`approachingFraction`); full when `approachingCompleted`.
- `hype_train_end_strip.dart`:
  - `rewards`: up to 3 earned emotes, "Rewards are on their way" (golden: an extra 24 h golden-emote line), and a draining bar from `stripFraction`
  - `expired`: "This Hype Train has ended", a draining bar, non-tappable
- `hype_train_slot.dart` (`HypeTrainSlot({store, compact})`): picks approaching, banner, collapsed pill or strip by `store.phase`, with `AnimatedSize` and `AnimatedSwitcher`. It calls `store.attachPresenter` in `initState` and `detachPresenter` in `dispose`. It renders `SizedBox.shrink()` when hidden.

**Tests first** (`test/screens/channel/hype_train/widgets/`). These are widget tests with a real `HypeTrainStore` on a mocked service and fake realtime. `testWidgets` runs in a FakeAsync zone, so `clock.now()` and `Timer`s advance with `tester.pump(d)`.
- `hype_train_palette_test.dart`:
  - each style gives a distinct icon and `a11yName`
  - creator colour overrides the regular fill only
  - computed contrast is ≥4.5 for title on background in light and dark for every style
- `hype_train_banner_test.dart`:
  - an ongoing snapshot → "LVL 7", "33%", "00:16" visible
  - pump 1 s → "00:15"
  - a progression event → the bar's `AnimationController.value` moves to 0.43 within 200 ms
  - large contribution:
    - `find.byKey(ValueKey('ht-step-largeContribution'))` present between 500 and 6500 ms
    - absent at 7300 ms
    - the default content back
  - level-up phases in order:
    - `flash100` at 250 ms
    - `marquee` at 800 ms, with its `Transform` x offset decreasing between 1000 and 2500 ms
    - `levelComplete` at 3300 ms
    - "LVL 3" at 3600 ms
  - RTL: the marquee offset sign is mirrored
  - reduceMotion (`MediaQuery(disableAnimations: true)` → `store.reduceMotion`): no `Transform` translation, the text is present
  - semantics:
    - the root label contains "level 7", "33 percent" and "seconds left"
    - the `levelComplete` text node is a live region
    - the countdown text has no separate semantics node
  - collapse → compact pill; expand → full banner
  - text scale 2.0 → no overflow (`tester.takeException()` is null) at 360 px width
- `hype_train_approaching_banner_test.dart`: checks for keys {1,2} → two filled; the bar advances every 500 ms; the "N more" subtitle when the viewer participated; the bar is full on start.
- `hype_train_end_strip_test.dart`: rewards strip with 3 emotes; the bar drains (0.5 at 10 s); gone at 20 s; the expired strip is non-tappable; golden copy.
- `hype_train_slot_test.dart`: attach/detach counts; hidden → zero size; phase transitions animate size.

**Acceptance:** tests green; no golden files; every widget builds in light and dark.

---

### H7: `add a dev hype train harness`

**Files**
- CREATE `lib/dev_hype_train_harness.dart` (`flutter run -t lib/dev_hype_train_harness.dart`, not shipped, mirrors `dev_player_harness.dart`):
  - **Replay mode:** a list of scenarios (regular full run, large contribution burst of 12 events for back-pressure, golden, treasure through threshold, community through threshold, mythic end reveal, shared start/merge/left, ATH approaching→reached, expired, missed end → +10 s fallback). Each feeds fixture events through `store.injectEvent` with realistic gaps, against a `HypeTrainSlot` in a phone-width frame plus a landscape preview, with a "reduce motion" toggle.
  - **Live mode:** the anonymous `allActiveHypeTrainStatuses` over the top streams (verified) lists active trains; tapping one creates a real store on the real `TwitchRealtimeClient`.
  - **Record mode:** appends raw payloads to the app documents directory, so new fixtures can be captured for the (TBC) shapes. It is debug-only and never uploaded.
  - It uses the anonymous services only (no credentials).

**Tests first:** none (dev tool). It must pass `flutter analyze`.
**Acceptance:** runs on a device; every scenario plays end-to-end.

---

### H8: `add hype train variant effects`

**Files** (`widgets/effects/`). Explicit animations and painters only; no Lottie and no assets. Each takes `duration` from the step and a `reduceMotion` flag.
- `coin_unlock.dart`: a `CustomPainter` coin (gold radial gradient, embossed ring, "%" glyph from the discount). It flips with `scaleX = cos(πt·4)` decaying, then a burst of 8 sparkles (painted stars scaling and fading) at 70% of the duration, and a lock icon morphing to unlocked (`AnimatedCrossFade`). Duration 1600.
- `rocket_launch.dart`: an `Icons.rocket_launch_rounded` translated on a quadratic bezier from bottom-left to top-right, rotated along the path tangent, with a painted flame trail (fading circles) and a 4-point star burst at the apex. Duration 1600.
- `rainbow_sweep.dart`: a 4-colour `LinearGradient` whose stops shift, looping `cycles` times over `cycleDuration`, behind the banner content at 35% opacity. Used for shared level-up and completion.
- `trophy_burst.dart`: a trophy scale-in (elastic) plus ring pulse, for ATH-reached.
- `mythic_reveal.dart`:
  - `mythicPool`: an inline emote row with a shimmer sweep
  - `mythicSelect`: a highlight cycling through the pool, decelerating like a roulette, landing on `selectedEmote`
  - `mythicReveal`: scale and glow
- `merge_aura.dart`: up to 6 previous plus 6 joining avatars (`ProfilePicture`-style circles from `profileImageUrl` allowlisted, a fallback initial avatar otherwise) with a radial glow, "+" between the groups, and fade-ins staggered by 80 ms.
- `hype_train_avatar_stack.dart`: an overlapping avatar stack (−8 px), used by shared start, top-3 and channel-left.
- UPDATE `hype_train_banner.dart`: map the step kinds `coinUnlock`, `rocketLaunch`, `athReached`, `athOtherChannel`, `mythicPool`, `mythicSelect`, `mythicReveal`, `mergeAura`, `sharedAvatars`, `sharedTop3`, `channelLeftSummary`, `continuesIn` and the `rainbow` flag to the effects. The style background cross-fades (`AnimatedContainer` 500 ms) when the style changes (ATH approaching/reached, treasure unlocked). The treasure lock/unlock background is a painted padlock watermark at 8% opacity.

**Tests first** (`test/screens/channel/hype_train/widgets/effects_test.dart` + banner additions)
- Each effect at t = 0, 50% and 100%: the controller value; key elements present (`ValueKey('coin')`, `'sparkle-0'` appears only after 70%, `'rocket'` position moves up and right, and the rainbow gradient's first stop differs between 0 and 1000 ms); `reduceMotion` → a static icon with no `AnimatedBuilder` ticks.
- Banner with the treasure fixture: a level-up to the threshold shows `coinUnlock` 2.4–4.0 s into the sequence, then the "unlocked" marquee; the background style becomes `treasureUnlocked`.
- Community threshold → `rocketLaunch` step.
- Mythic end → `mythicSelect` lands on the selected emote at the end (the highlighted index equals the pool index).
- Shared level-up → the `RainbowSweep` widget is present only during the marquee; top-3 avatars with % text.
- ATH reached → trophy plus the 6 s marquee; one `athOtherChannel` slide per channel.
- Merge → the level pill counts 3 → 5 (`find.text('LVL 4')` mid-way).
- All effects dispose their controllers (no "ticker active" errors at test end).

**Acceptance:** tests green; the harness shows every variant on a device at 60 fps with no jank, checked in `--profile` with the performance overlay.

---

### H9: `add the hype train detail sheet`

**Files**
- `widgets/hype_train_sheet.dart`, opened from the banner (`store.expanded`):
  - Portrait: below the banner, an `AnimatedSize` expanding panel inside the chat slot, max 60% of the chat height, scrollable. This matches "expands below".
  - Landscape or pill: `showModalBottomSheet` via `lib/utils/modal_bottom_sheet.dart`, width-constrained to 480.
- Sections, top to bottom:
  1. **Variant explainer** (Treasure: discount threshold, or "unlocked: N% off 5+ gifts"; Community: "reach level X and chat gets N emotes", or unlocked; Mythic: pool size plus the pool row; Golden: golden-emote note).
  2. **Level target line:** "About 10 subs or 4,700 Bits completes this level" (`levelTarget`, D6).
  3. **Shared contributions:** top channels with avatar and %.
  4. **Conductors:** two rows, subs and Bits. Each has the conductor badge image (`currentConductorBadge`, allowlisted), the name and the amount, with empty-slot copy.
  5. **Rewards:**
     - "Level N rewards": a horizontal list of the current level's emotes with a lock overlay (`Icons.lock_rounded`, semantics "locked reward")
     - "Unlocked so far": `unlockedRewards`, unlocked
     - "Coming up": lazy `getUpcomingRewards`, collapsed by default
  6. **All-time-high line** with trophy and % (channel or shared).
  7. **"How Hype Trains work"** opens `https://help.twitch.tv/s/article/hype-train-guide` with the existing `launchUrl` helper and respects `launchUrlExternal` (D4).
  8. **No subscribe/gift/cheer buttons** (D4/E9).
- **Approaching sheet:** an explainer, the level-1 rewards, the countdown bar.
- The sheet updates live (it is an `Observer`). On end it switches to the summary and auto-collapses when the strip ends.

**Tests first** (`test/screens/channel/hype_train/widgets/hype_train_sheet_test.dart`)
- Each section renders from the regular fixture; the level target shows "10 subs" and "4,700 Bits".
- The conductors' names and amounts; an empty slot shows the invite copy.
- Current-level emotes have lock semantics; unlocked ones do not.
- Treasure and community copy before and after the threshold.
- "Coming up" calls `getUpcomingRewards` once on first expand and shows an empty state on failure.
- The learn-more tap invokes the injected launcher.
- Approaching sheet.
- The sheet closes when the store goes hidden.
- No `ElevatedButton` labelled "Subscribe" or "Gift" exists.
- Semantics headings for sections.

**Acceptance:** tests green.

---

### H10: `add a hype train setting`

**Files**
- UPDATE `lib/screens/settings/stores/settings_store.dart`: `static const defaultShowHypeTrain = true;` and `@JsonKey(defaultValue: defaultShowHypeTrain) @observable var showHypeTrain = defaultShowHypeTrain;`, reset in `resetChatSettings()` (l.346). Regenerate `settings_store.g.dart`.
- UPDATE `lib/screens/settings/chat_settings.dart` (`'Alerts'` section, l.181): `SettingsListSwitch(title: 'Show Hype Trains', subtitle: Text('Shows Hype Train progress, levels and rewards above chat.'), …)`.

**Tests first** (`test/screens/settings/stores/settings_store_test.dart`): default `true`; JSON round trip; `resetChatSettings` restores it; old JSON without the key → `true`.

**Acceptance:** tests green; generated file committed.

---

### H11: `show the hype train above chat`

**Files**
- UPDATE `lib/screens/channel/channel.dart` (CRLF: preserve line endings; additive only):
  - **Store lifecycle:**
    - State field `HypeTrainStore? _hypeTrainStore`, created in `initState` when `settingsStore.showHypeTrain` (`channelId: widget.userId`, `context.twitchHypeTrainService`, `context.realtimeClient`, `viewerId: () => context.authStore.user.details?.id`).
    - A `reaction` on `settingsStore.showHypeTrain` creates or disposes the store.
    - The banner always follows the **primary (video) channel**, not the active chat tab (D2).
  - `didChangeAppLifecycleState` (l.258): `if (state == AppLifecycleState.resumed) _hypeTrainStore?.handleAppResume();`.
  - `_minimizeToMiniPlayer` (l.330) and `dispose` (l.946): **always** dispose the hype-train store, even when `_handedOff`. The mini player shows no banner; restoring the channel builds a new store, which refetches.
  - **`chat` Stack** (l.559):
    - Replace the lone top `Align(FrostyNotification)` with an `Align(topCenter)` → `Column(mainAxisSize: min)` holding `[if (_hypeTrainStore != null) HypeTrainSlot(store, compact: landscapeChat), notification]`.
    - The top padding is the existing chat-only `safePaddingTop` plus 48 when `_chatTabsStore.showTabBar`, so the banner sits under the tab bar.
    - Hidden while `context.isLandscape && MediaQuery.viewInsetsOf(context).bottom > 0` (keyboard open in landscape).
    - This one slot covers the portrait column, the landscape side column and the landscape overlay chat (the `chat` widget is reused; the overlay chat gets the dark theme already applied at l.674).
  - **`video` Stack** (l.534): `if (landscape && settingsStore.fullScreen && !settingsStore.fullScreenChatOverlay && store.visible) Positioned(top: 48, left/right on the chat side, child: HypeTrainPill(store))`. `HypeTrainPill` is a compact `HypeTrainSlot` variant. Tap → the sheet in a modal; the semantic label equals the banner's.
  - PiP: `pipChild` is the player only, so no banner (the presenter is detached and events apply instantly).
- CREATE `widgets/hype_train_pill.dart` (landscape-hidden-chat pill states: approaching with filled circles, ongoing with fraction ring, levelling "LVL n" 2.5 s, completed) and its test.

**Tests first**
- `test/screens/channel/hype_train/widgets/hype_train_pill_test.dart`: states, tap → sheet callback, semantics.
- `test/screens/channel/hype_train/hype_train_layout_test.dart`: a small pure helper `hypeTrainPlacement({required bool landscape, required bool forceVertical, required bool fullScreen, required bool overlayChat, required bool showVideo, required bool keyboardOpen})` → `{bannerFull, bannerCompact, pill, none}`, extracted so the `channel.dart` logic is unit-tested without pumping the whole screen. Every combination is covered.

**Device regression:** the full R1–R16 checklist below.

**Acceptance:**
- `git diff --stat` shows **no** changes in `lib/screens/channel/chat/**`, `lib/models/irc.dart` or `lib/screens/channel/video/**`
- the banner appears on a channel with an active train (found with the H7 live mode)
- analyze and tests green

---

### H12 (optional, separate, D11): `show hype train level pills on followed streams`

- `TwitchHypeTrainService.getActiveStatuses(List<String> ids)` → `Map<String channelId, HtCardStatus{level, type, isShared, isAth}>`. Chunks of 100; never throws (`{}`).
- `StreamListStore` (followed `ListType` only): after each refresh of streams, fetch statuses into an `ObservableMap`; skipped when `showHypeTrain` is off.
- `StreamCard`: an optional small pill over the thumbnail, bottom-left: variant icon and "LVL n", with the palette from H6.
- Tests: service chunking and parsing; store calls it only for the followed list; the card renders the pill only when a status exists.

### H13: `update gap and architecture docs for realtime and hype train`

- `docs/GAP.md`:
  - INT-15/16/17 → ✅ (variants: list which are verified live and which are TBC)
  - MSC-03 → ⚠️/✅ (Hermes client; anonymous public topics)
  - PLY-09 note: `video-playback-by-id` is subscribable anonymously (follow-up)
  - CHT-41 partial (a stack with one highlight type)
  - the line "EventSub exige le diffuseur" is replaced with the verified anonymous route
- `docs/ARCHITECTURE.md`: a "Realtime" section (client, topics, lifecycle, isolation) and a "Hype Train" section.
- `docs/plans/roadmap.md`: E3 and E4 marked done.

---

## Testing Strategy

- **Pure units** (no Flutter bindings):
  - `hermes_protocol`, models and events (fixtures)
  - `hype_train_math`, `hype_train_reducer`, `hype_train_queue`, `hype_train_sequence`, `ServerClock`, the placement helper
- **Client:** `TwitchRealtimeClient` with `FakeRealtimeSocketFactory` inside `fakeAsync`. It covers reconnect, backoff, watchdog, refcount, idle, lifecycle and dispose with `pendingTimers.isEmpty`.
- **Service:** `DioAdapter` with captured, anonymised fixtures.
- **Store:** `fakeAsync` plus `package:clock`. `clock.now()` and `Timer`s move together, so the countdown, +10 s fallback, 20 s approaching rule, strips, pacing and polling are asserted to the millisecond.
- **Animations, without goldens.** `testWidgets` already runs in a FakeAsync zone with `clock` patched. Each animation step:
  1. drives the store to a known step with `injectEvent`;
  2. `tester.pump(Duration(ms))` to exact offsets taken from `HtTimings`;
  3. asserts the **phase** by key (`ValueKey('ht-step-<kind>')`), visible text and semantics;
  4. asserts **motion** by reading `AnimationController.value` through the effect widget's `@visibleForTesting` getter, or a `Transform`/`Opacity`/`FractionallySizedBox` property at the mid-point and end;
  5. asserts the reduceMotion path via `MediaQuery(disableAnimations: true)`.

  `pumpAndSettle` is never used while the 1 s countdown runs. Every test disposes the store, and the test fails on pending timers.
- **Unchanged suites must stay green:** `ivs_video_store_test.dart`, `irc_test.dart`, the VOD suites, `settings_store_test.dart`, the API tests.
- **Validation per commit:**
  ```bash
  flutter pub get
  dart run build_runner build --delete-conflicting-outputs   # H5, H10
  flutter analyze
  flutter test
  flutter build apk --debug --dart-define=CLIENT_ID=<id> --dart-define=SECRET=<secret>
  ```
- **Reviews before each commit is done:**
  - `flutter-reviewer` on every commit
  - `security-review` on R1/R2 (frame parsing, URL and topic validation, no token or recovery-URL logging), H1 (URL allowlists) and H11
  - `code-review` before H11 lands

## Regression checklist (device, after H11 and H12; live items extended from `vod.plan.md`)

1. **R1** Live on IVS: chat connects; 7TV/BTTV/FFZ emotes; a 7TV live emote add/remove notice still appears.
2. **R2** Latency badge and stats panel medians unchanged against the baseline, **while a hype-train level-up animates**. The banner `RepaintBoundary` is checked with the debug repaint rainbow: it must not repaint the video.
3. **R3** Mini player: swipe down → mini with no reload, no banner in the mini; restore → banner back within 1 s at the right level (refetch).
4. **R4** PiP (auto and button): no banner; on return the banner shows the current state; no stale animation burst (events applied instantly while detached).
5. **R5** Landscape:
   - side column → compact banner
   - overlay chat → compact banner (dark)
   - hidden chat → pill; double-tap cycles through all three
   - fullscreen; divider drag; landscape left/right side
   - keyboard open → banner hidden
6. **R6** The WebView engine is selectable and the forced fallback still launches; iOS web engine plus banner.
7. **R7** Offline channel: no banner and no error; the socket is subscribed but idle.
8. **R8** Deep links unchanged.
9. **R9** Moderation rendering (deleted-message reveal, timeout/ban durations) unchanged; `git diff` shows zero chat-layer lines.
10. **R10** Chat delay (auto and manual): the countdown and the delayed messages behave exactly as before. The hype-train banner is not delayed (D3).
11. **R11** VOD: no banner; live → VOD → back: the live banner state resyncs.
12. **R12** Chat tabs: secondary tabs do not change the banner (primary channel only); the tab bar does not overlap the banner.
13. **R13** Airplane mode for 30 s with a train ongoing:
    - chat shows its usual reconnect notices
    - the hype-train client reconnects with backoff, then refetches, and the banner corrects itself
    - chat and video recover independently
14. **R14** Background the app for 2 min (longer than the 60 s grace) → resume → the socket reopens and the GQL refetch shows the current state or hides an ended train.
15. **R15** Setting off → the banner disappears immediately, the topic is unsubscribed after 500 ms and the socket closes after 30 s (debug log); on → back.
16. **R16** TalkBack: the banner reads its summary; level-complete and train-started announcements are read once; the countdown is not chatty; the sheet sections are navigable; 200% font with no clipping.

## Manual test protocol (Hype Train specific, real Android phone, release build)

- **M1 Find live trains:** the H7 live mode (anonymous bulk statuses over the top streams). It typically finds 2–10 active trains, as verified on 2026-10-13. Open two of them in Frosty and twitch.tv side by side, then compare:
  - level, % (within one event) and countdown (±1 s)
  - conductor names; the sheet's level emotes
- **M2 Event parity:** leave a busy train open for 5 min. Every level-up in the browser plays the Frosty level-up sequence within about 2 s. No double level-up (the verified early progression is deferred).
- **M3 End:** stay until the train ends. COMPLETED → success marquee, then totals, then the 20 s rewards strip with the earned emotes, then hidden. With a socket killed beforehand (airplane mode at T−20 s), the +10 s fallback ends it.
- **M4 Variants:** replay every scenario in the harness (both orientations, light and dark, reduce motion on and off). Also verify any live Golden or Treasure train found by M1 (both verified to exist).
- **M5 Stress:** the harness's back-pressure scenario (40 progressions in 10 s plus large ones): the banner never lags more than one sequence behind and the large ones all show.
- **M6 Resilience:** rotate during a level-up; open and close the sheet mid-sequence; swipe to the mini player during a strip; lock the screen for 3 min.

## Risks & Mitigations

- **Twitch changes Hermes, or requires auth or integrity for anonymous sockets** (Medium).
  - Topics go `RealtimeUnavailable`, and the store polls GQL every 20 s while a train is active.
  - Optional R4 adds the legacy PubSub transport (verified anonymous today).
  - Chat and video are untouched: separate socket and separate service.
- **GQL schema drift or integrity gating** (Medium). Typed exception; the realtime `start` / `level-up` payloads can still build the train locally (verified level-up carries a full GQL-shaped train).
- **Payload drift** (High likelihood over months).
  - Tolerant parsing with both casings (verified duplicated keys), unknown enums kept raw (verified `EXTENSION`), `HtUnknownEvent` ignored, fixtures from real captures, and harness record mode for new shapes.
  - Verified traps: `data.id` is the train id (dedupe by `trainId:sequence_id`), level-up and its progression in either order (deferral plus a 3 s refetch; an equal `sequence_id` still applies).
- **Clock skew** (Medium): `ServerClock` from Hermes notification timestamps; `remainingSeconds` used for GQL snapshots.
- **Animation jank or battery** (Medium): `RepaintBoundary`; controllers only while a presenter is attached; one 1 s timer only while ongoing; profile-mode check in H8.
- **Banner hides chat** (Low/Medium): it overlays only the top (oldest) messages of the reversed list; collapsible to a 28 px pill; compact in landscape; hidden with the landscape keyboard.
- **Leaks, timers after dispose** (Medium): `pendingTimers`-empty assertions in client and store tests; `dispose` is idempotent.
- **Security** (Medium impact):
  - channel ids and topics validated by regex
  - image URLs allowlisted (`https://static-cdn.jtvnw.net`), emote ids validated
  - text rendered as plain `Text` (no markup)
  - frames over 256 KB dropped
  - `recoveryUrl` never logged or used
  - no user token ever sent; the viewer id is used only locally
  - auth-only topics refused client-side (the server accepts them, verified)
- **ToS / undocumented endpoints:** anonymous, read-only, isolated behind one setting; the WebView and chat paths do not depend on it.
- **CRLF files** (`channel.dart`, `pubspec.yaml`, `pubspec.lock`): preserve line endings; avoid whole-file diffs.

## Decisions to confirm (defaults the plan applies unless told otherwise)

1. **D1 Placement:** the banner **overlays** the top of chat (it does not push the list), with a collapse-to-pill affordance. The alternative is to reserve list padding, which needs a `listPadding` change through `ChatTabs`. That is still chat-layer-neutral, but the chat jumps when the banner appears.
2. **D2** The banner follows the **primary (video) channel** only, not the active chat tab or the other channels of a shared chat.
3. **D3** Hype-train events are **not delayed** by the chat-delay setting (official-app parity; with the low-latency player the gap is about 2–4 s). An option to follow `effectiveChatDelay` can come later.
4. **D4** Subscribe, gift, cheer and "share your reward" (`hype-train-events-v1.rewards.<userId>`, login-only) are **hidden until E9**. "How Hype Trains work" opens Twitch's help page with the existing external-link setting; alternatively, hide it.
5. **D5** The +10 s fallback ends as **COMPLETED when level ≥ 2, else EXPIRED**. This deviates from the official client, which always forces EXPIRED. Every live end captured with level ≥ 2 reported COMPLETED, so always showing "you missed it" would be wrong.
6. **D6** The level-target line uses the **in-level goal** (official parity: "about 10 subs completes this level"). The alternative is the **remaining** points.
7. **D7** E3 ships **Hermes only**; the legacy PubSub transport (R4) is optional.
8. **D8** Full GQL documents, not APQ hashes, even though the Android APQ hashes work with the web Client-ID (verified). Documents survive hash rotation, and the lean document is about 4.6 KB.
9. **D9** Every reconnect is a fresh session plus a resubscribe plus a GQL refetch; `recoveryUrl` is not used.
10. **D10** Close 4100 (ping failure) is treated as **reconnectable** (Twilight lists it as fatal). The fatal set is 4010, 4111, 4112, 4120–4123, 4130, 4131.
11. **D11** Followed-card level pills (H12) ship as a separate, optional commit.
12. **D12** When realtime is unavailable, GQL is polled every 20 s **only while a train or approaching state is active**.
13. **D13** Later cleanup: make `twitch_stream_service.dart` and `twitch_vod_service.dart` use `kTwitchWebClientId`. This is not done now, to keep the live path byte-for-byte.
14. **D14** PLY-09 (stream up/down push) via `video-playback-by-id.<id>` on the new client is a **follow-up** outside E3/E4. It replaces the EventSub idea in the roadmap, which needs a user token.
15. **D15** The `showHypeTrain` setting defaults to **on**, in Chat settings → Alerts.
16. **D16** Pinata trains (upstream RN-only) render as Regular.
17. **D17** The mini player shows no hype train. Its store is disposed on hand-off and recreated (refetched) on restore.

## Success Criteria

- [ ] `TwitchRealtimeClient`:
  - anonymous Hermes connect, subscribe/unsubscribe, keepalive watchdog, backoff reconnect plus resubscribe, app-resume handling
  - fully fake-time tested
  - no effect on chat or video when it fails
- [ ] On a channel with an active train, the banner shows the correct level, %, countdown and conductors within 1 s of opening (GQL), and follows realtime events with one-at-a-time pacing and back-pressure.
- [ ] Approaching (20 s rule, checks, "N more"), level-ups, large contributions, ATH, shared merge/left and end sequences play per the timing table. Completed → 20 s rewards strip; expired or fallback → 20 s expired strip.
- [ ] Golden Kappa, Treasure, Community, Mythic, All-Time-High and Shared each have a distinct ONSET style and animation, verified in the harness. Golden and Treasure are also verified live.
- [ ] The sheet shows the variant explainer, level target, shared contributions, conductors, locked/unlocked reward emotes and the ATH line.
- [ ] Portrait, landscape column, landscape overlay, landscape hidden (pill), chat-only, PiP, mini player and VOD all behave as specified; TalkBack and reduce-motion pass.
- [ ] Zero diff in the chat layer, `irc.dart` and the video folder. Regression checklist R1–R16 passes. `flutter analyze` is clean and `flutter test` is green with all new suites.
- [ ] GAP.md, ARCHITECTURE.md and roadmap.md are updated.

### Critical Files for Implementation

- `/home/user/frostyv2-lab/lib/screens/channel/channel.dart`: `video` Stack l.534, `chat` Stack l.559, lifecycle l.258, mini hand-off l.330, dispose l.946 (CRLF)
- `/home/user/frostyv2-lab/lib/apis/twitch_vod_service.dart`: template for `twitch_hype_train_service.dart` (`_gql`, own Dio, id validation)
- `/home/user/frostyv2-lab/lib/screens/channel/chat/stores/chat_store.dart`: websocket usage reference (l.798, l.884); **must stay untouched**
- `/home/user/frostyv2-lab/lib/main.dart`: providers (l.~122-165), `AppLifecycleListener` wiring
- `/home/user/frostyv2-lab/lib/screens/settings/stores/settings_store.dart` and `/home/user/frostyv2-lab/lib/screens/settings/chat_settings.dart`: the `showHypeTrain` setting
- `/home/user/frostyv2-lab/lib/theme.dart`, `/home/user/frostyv2-lab/lib/constants.dart`, `/home/user/frostyv2-lab/lib/widgets/`: ONSET tokens and components
- `/home/user/frostyv2-lab/lib/dev_player_harness.dart`: template for `lib/dev_hype_train_harness.dart`
- `/root/twitch-re/notes/hype_train.md` §2–§3 and `/root/twitch-re/notes/protocols.md` §2.1: behaviour spec (not copied)
- Live-verification scripts and raw captures (scratch only, not for the repo): `/tmp/claude-0/-home-user/3ed6b763-835a-5414-a8f4-34d9902c2253/scratchpad/ht/` (`exec.py` = the verified query document builder, `hermes.py`, `captures.jsonl`, `run2.log`). Anonymise before turning anything into `test/fixtures/`.