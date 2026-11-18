# 03 — Chat core (logic, stores, details, emote menu, mod tools)

> Cross-spec decisions in [00-index.md](00-index.md) (section "Decisions") override any conflicting PC suggestion in this file.

Scope: everything under `lib/screens/channel/chat/` EXCEPT `lib/screens/channel/chat/widgets/` (the message row renderer, bottom bar, user card, banners and other chat widgets are specified in their own leaf). Generated files (`*.g.dart`) are not described file by file: they are MobX/JSON boilerplate for the stores below and must be reproduced as plain Rust state + change notification. Every number, key, URL and string below was read from the source on 2026-11-18.

## Purpose

The chat core is the part of ONSET that turns one Twitch channel's chat into a live, readable, moderatable list of lines, independent of the video player. It must be rewritten with nothing lost because it is the feature set the fork promises never to drop (7TV/BTTV/FFZ emotes, deleted-message reveal, timeout/ban rendering, chat-delay sync, badges, autocomplete, moderation).

What it does, end to end:
- Connects to Twitch IRC over WebSocket (`wss://irc-ws.chat.twitch.tv:443`), anonymously (`justinfan888`) or as the viewer, parses every IRC line (PRIVMSG, NOTICE, USERNOTICE, CLEARCHAT, CLEARMSG, ROOMSTATE, USERSTATE, GLOBALUSERSTATE, PING, 001 welcome, RECONNECT), keeps up to 5000 lines, renders the newest 100 while pinned, buffers lines while the viewer scrolls up, and flushes every 200 ms.
- Reconnects automatically (first retry immediate, then 1, 2, 4, 8 s; 5 attempts; then a `chatDisconnected` line with a `chatReconnect` action), with a silence watchdog (90 s → PING, 10 s more → close and reconnect).
- Delays chat to match a video that is behind live ("chat delay sync"): every payload (IRC frame, 7TV event, BTTV event, ONSET local notice) waits `effectiveChatDelay` seconds in a FIFO; confirmations (USERSTATE, GLOBALUSERSTATE, ROOMSTATE, NOTICE), PING and RECONNECT bypass it. A countdown line `chatSyncIn` ("Chat will sync in Ns…") is shown at the start.
- Loads chat history on join (Twitch GQL `ChatHistory` with the viewer's twitch.tv web token; fallback to the third-party recent-messages service when allowed), inserts it above live lines in one go without duplicates, applies moderation that happened while it loaded, and never lets history trigger live effects.
- Loads emotes and badges: Twitch (global, channel, viewer's own sub/follower/unlocked sets, cheermotes), 7TV, BTTV, FFZ (global from a shared store; channel per chat), Shared Chat participants' emotes and badges, and third-party cosmetics (7TV badges, name paints, personal emotes; BTTV Pro personal emotes; FFZ room badges). Live emote changes arrive through the 7TV EventAPI and the BTTV socket and are announced in chat.
- Filters lines: blocked users (unless the viewer moderates), muted words (substring or whole-word), AutoMod-rating "chat filters" (masking with reveal), gift-sub notices (hide or collapse gift bombs).
- Lets the viewer send messages (optimistic local copy confirmed by USERSTATE, replies with `reply-parent-msg-id`, `/me`), and runs ~50 slash commands itself because Twitch ignores IRC commands (moderation through Helix, whispers, colour, block, user card, help, disconnect).
- Shows the one restriction that matters (ban, timeout countdown, slow-mode countdown, account refusals, room modes) above the input, gates the input behind the channel's chat rules the first time, and words every Twitch NOTICE in the UI language.
- Gives moderators and the broadcaster their tools: room modes, clear chat, announcements, shoutouts, Shield Mode, AutoMod queue (EventSub), live mod-action feed, blocked terms, unban requests, roles (mods, VIPs, lead mod), polls, predictions, reward redemptions, stream info, raids, markers, commercials, suspicious-user monitor/restrict, user-card moderation status.
- Hosts several chat tabs (up to 10) with lazy activation, persistence, and a merged view interleaving all tabs by Twitch timestamp.
- Provides the emote menu (Recent, Twitch, 7TV, BTTV, FFZ, GIFs), the chat details sheet (modes, chatters, colour, badges, sleep timer, preferences…), and the overlay-chat placement frame.

## Screens and layouts

All sizes are logical pixels (Flutter dp). "Sheet" = ONSET's bottom sheet (`showOnsetSheet`), which becomes a centered panel on tablets when `panel: true`.

1. **Chat column (`Chat`, chat.dart)** — vertical: [Expanded Stack: reversed message list (newest at the bottom) with bottom padding = input bar height (68 + 41 reply bar + 56 autocomplete row + 28/48 restriction bar) + safe-area bottom; top overlay = Shared Chat banner (full width, slides/fades from the top) and a red "Shield Mode on" pill aligned to the end edge 8 px in; the input bar (`ChatBottomBar`) wrapped in the chat-rules prompt at the bottom; a floating "Resume scroll / N new messages" elevated button with a down arrow, 4 px from the sides, sitting just above the input; on tablets the emote panel overlay] then the inline emote menu (phone) whose height animates between 0 and ⅓ of the screen (portrait) or ½ (landscape), background #101010 with a hairline on top. A scrollbar runs along the list, clear of the input. Message text size = `fontSize` setting scaled by `messageScale`.
2. **Emote menu** — underlined provider tabs row (46 px phone / 48 px panel) with an optional trash button on the Recent tab; per provider a row of set pills (Channel / Global, or Twitch sections: Channel, Global, Unlocked, Other, then each channel by first word of its name); a grid of emote cells (8 columns portrait, 6 landscape beside video, 16 landscape chat-only; panel 6 columns × 54 px). Locked emotes are dimmed to 42 %; animated emotes have a small 13 px play badge. Recent empty state: emote glyph + "No recent emotes". GIF tab: search field (pill), progress line, 140 px max tiles grid, "Powered by GIPHY" footer; confirmation dialog with preview before sending.
3. **Tablet emote panel** — 376 × 372 panel anchored above the emote button with a nub, 10 px gap, inside the chat area; falls back to the inline menu if it does not fit.
4. **Chat details sheet** (max 600 px tall) — menu rows: Live Together strip, Shared Chat strip, active mode pills (horizontal), Chat only / Show video, Refresh emotes (spinner → check), Reconnect, Username colour ›, Chat badge ›, Points, polls & predictions ↗, Subscribe ↗, Gift a sub ↗, Mod tools ›, Chat modes ›, Chat rules, Chatters ›, Add chat ›, Sleep timer ›, Preferences (6 switches), Settings ›. Sub-views replace the menu in place with a back header: Sleep timer (Cancel + 16 durations), Username colour (preview card, 15 colour rows with dots, Cancel/Save footer), Rules.
5. **Chatters sheet** (80 % of screen height) — filter field (44 px, focus ring), "N chatters" count, 48 px rows with initial avatar + login, empty states, pull to refresh, scroll-to-top button.
6. **Chat modes sheet** (moderators) — header "Chat modes · Moderator", 5 rows (≥ 56 px) with glyph, name, optional duration dropdown under the name (34 px, ≤ 220 px wide), switch at the end; hairline; red "Clear chat" row; status line.
7. **Mod tools hub sheet** — title + caption (Broadcaster/Moderator), sections Live (Shield Mode switch, AutoMod queue with pending count, Action log, Show actions in chat switch), Chat (Chat modes, Announce, Shoutout, Blocked terms, Permitted terms ↗ (owner), Unban requests), Channel (owner: Stream info, Polls, Predictions, Reward requests, Moderators, VIPs, Raid, Cancel raid, Marker, Commercial), Mod View ↗, status line. Rows lacking a scope read `modToolsLogInToEnable` ("Log in again to use this"). Sub-sheets open as stacked panels: AutoMod queue, Action log, Role list (add field + list), Blocked terms (add field + list), Unban requests, Reward requests (+ web queue link), Announce (text + 5 colour pills + send), Poll / Prediction (live state or form), Stream info (title, category search with ≤ 5 results, tag pills + add field, Save). Dialogs: text/login dialog, commercial length pills, confirmations, unban resolution note.
8. **User card moderation parts** — red status pills (Banned, Timed out, Warned, Monitored, Restricted) and a "Moderation" actions sheet (shoutout, monitor, restrict, mod, VIP).
9. **Overlay chat frame** — the chat as a column over the video, placed by fractional top/height (min 30 %), with a move grip at the top and a resize grip at the bottom (72×28 hit area, 36×4 white 60 % pill) visible only while controls show; snaps left/right by where the drag ends.
10. **In-chat notice lines** — every synthetic line (connecting, welcome, reconnecting countdown, disconnected + Reconnect action, sync countdown, moderation notices, server notices, command outcomes, emote add/remove/rename, held-message decisions, mod actions, AutoMod held + Review action, shoutout + View action, animated-emotes callout + Show action, raid welcome) is an `IRCMessage` notice rendered by the row widget (out of scope) with optional action button.

## Behaviour and state

Core state machine (per chat, `ChatStore`):
- **Connection**: `connecting` (initial "Connecting to chat…" line, `hasConnected=false`) → `connected` (on `:tmi.twitch.tv 001 … Welcome, GLHF!`: welcome line, 200 ms flush timer started, 7TV/BTTV sockets opened, reconnect line replaced in place by `chatReconnected` ("Reconnected (N attempts, Ss)"), retries reset, `isConnected = hasConnected = true`) → `dropped` (socket done: `isConnected=false`, countdown cancelled) → `reconnecting k/5` (line updated in place; backoff 0, 1, 2, 4, 8 s with a per-second countdown) → `connected`, or after 5 failures `disconnected` (line with Reconnect action that resets retries). Login/logout closes the socket (code 1000) which triggers the same reconnect path with new credentials. `/disconnect` and the details "Reconnect" also use it. Watchdog: any frame re-arms 90 s; silence → PING; 10 s more → close 4000.
- **Delay**: active iff `showVideo && effectiveChatDelay > 0`. Held payloads keep arrival order, are released by the 200 ms flush when `arrivedAt <= now − delay` (delay read at flush time), survive reconnects, flush all at once when the delay turns 0 or the video is hidden, are dropped on dispose. Countdown line on first connect / video shown / first auto-sync value; not on reconnects; `chatDelaySyncCompleted` prevents repeats until reset (video hidden, delay 0, socket drop).
- **Message list**: `messages` (oldest first, ≤ 5000, trim 1000 oldest), `messageBuffer` (pending lines), `autoScroll` (true when the reversed list is at offset ≤ 0). While scrolled up or in background, the buffer is moved into the list only when it reaches 1000 lines. `renderMessages` = last 100 while pinned. In-place moderation marks (command changes) force a new list instance at the next flush.
- **Send**: idle → waiting-for-ack (PRIVMSG sent, optimistic copy prepared from the last USERSTATE) → confirmed on next USERSTATE (copy added with Twitch's id or `local-<ms>`, input and reply cleared, slow-mode clock starts) | rejected on a `msg_*` NOTICE (heavy vibration and notification with the localized reason only when the NOTICE has text; always: text kept, restriction updated) | timed out after 10 s (`chatMaybeNotSent`). A second send while waiting → medium vibration + "wait" notification. Slash commands run one at a time (`runningCommand`).
- **Restriction**: recomputed on ROOMSTATE, USERSTATE, own CLEARCHAT, rejections, acknowledgements and timers (`until + 50 ms`). Priority: banned > timed out > sticky account refusal > (privileged → none) > slow-mode wait > emote-only > subs-only > followers-only.
- **History**: pending until the GQL (or fallback) answer; live CLEARCHAT/CLEARMSG remembered meanwhile; one insert at the top; ids remembered so the live copy is skipped.
- **Shared chat**: mode = latest line carries `source-room-id`; entering fetches participants' assets; banner once per chat for 15 s, wording depends on whether an unshared message was seen first.
- **Gift bombs / raids**: per USERNOTICE after the delay; latest banner-worthy bomb and latest incoming raid exposed for pins.
- **Moderation reactions**: CLEARCHAT marks lines (timed out/banned with duration), adds "X has been timed out for …" (setting), updates mod-tools user status, own ban/timeout restriction. CLEARMSG marks a line deleted (revealable) and tells the viewer when it was theirs.
- **Tabs**: primary + ≤ 9 secondary, lazy stores, persisted secondary tabs, merged mode with frozen snapshot while scrolled up and "N new messages" count.
- **Mod tools**: started when logged in and `canModerate` (USERSTATE mod or owner), per token; scopes read from `/oauth2/validate`; EventSub topics subscribed per allowed feature; stopped on logout / demotion.
- **Rules gate**: logged-in viewer + channel with rules + not accepted on this device → focusing the input opens the rules sheet instead; accepting stores `chat_rules_accepted_<viewer>_<channel>`.

Edge cases worth keeping verbatim: a reply id is only sent if it matches `^[A-Za-z0-9-]{1,64}$`; recent-messages strings are split on every line break and force-marked historical; history-ids and tracked-notice ids prevent double counting of gifts; a channel suspended on join is not treated as a refused send (only while waiting for an ack); "follow to chat" refusal is forgotten once followers-only turns off; a held deletion still applies after a reconnect; per-user maps capped at 4000, gift bombs at 100, mod actions 200, held messages 100, user statuses 500, recent emotes 48, tracked notices 1000.
## Animations and motion

Motion tokens (`lib/widgets/motion/motion.dart`): `OnsetMotion.emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1)`, `emphasizedAccelerate = Cubic(0.3, 0, 0.8, 0.15)`, `standard = Cubic(0.2, 0, 0, 1)`, `reducedFade = 150 ms`. `motionDuration(context, d)` returns `d`, or 150 ms when reduce motion is on (the system "remove animations" / app reduce-motion setting); transitions that check `reduceMotionOf(context)` additionally drop slides/scales and keep only a fade.

| Where | What | Duration | Curve | Reduce motion |
|---|---|---|---|---|
| Shared Chat banner slot (chat.dart) | fade + size from top in/out | 240 ms | in emphasizedDecelerate, out emphasizedAccelerate | 150 ms (fade+size kept) |
| Inline emote menu height (chat.dart) | height 0 ↔ ⅓ / ½ screen | 260 ms | standard | 150 ms |
| Inline emote menu content | cross-fade in/out | 100 ms | easeOut / easeIn | 150 ms |
| Resume-scroll button padding | follows input height | 200 ms | linear | unchanged (200 ms) |
| Resume-scroll button appear | AnimatedSwitcher (fade) | 200 ms | easeOut / easeIn | unchanged |
| Emote tabs change | TabController animateTo | 300 ms (`kTabScrollDuration`) | Material default (ease) | 150 ms |
| Emote tab underline | opacity 0 ↔ 1 | 200 ms | linear | 150 ms |
| Tablet emote panel | fade + scale 0.97→1 from bottom-left | open 220 ms, close 160 ms | default (linear) | fade only, 150 ms |
| Chat details sub-views | fade + horizontal slide ±6 % (menu from left, sub-views from right) | 240 ms | emphasizedDecelerate / emphasizedAccelerate | fade only, 150 ms |
| Chat details height | AnimatedSize | 260 ms | standard | 150 ms |
| Refresh emotes trailing | spinner ↔ check (shown 2 s) | 200 ms | linear | 150 ms |
| Colour row check | opacity | 160 ms | linear | 150 ms |
| Chatters filter field | border/ring change | 160 ms | linear | 150 ms |
| Chatters scroll-to-top button | AnimatedSwitcher | 200 ms | easeOut / easeIn | unchanged |
| Shield Mode pill | AnimatedSwitcher fade | 220 ms | linear | 150 ms |
| Haptics (not motion, same moment) | selectionClick on tab change, compact mod buttons, preference rows; lightImpact on emote long-press, refresh success, chatters pull-to-refresh; mediumImpact on send-while-waiting; heavyImpact on rejected / timed-out send | — | — | — |

Timed (non-animation) UI: notification above chat auto-hides after 5 s; Shared Chat banner after 15 s; refresh check after 2 s; sync countdown ticks every 1 s; reconnect countdown every 1 s; restriction countdown banner re-evaluated at its end + 50 ms (the banner widget itself ticks the visible clock, out of scope).

## Settings

Every `SettingsStore` key read or written in this area (defaults from `settings_store.dart`):

| Key | Default | Effect here |
|---|---|---|
| `showVideo` (getter = `savedShowVideo && !chatOnlyForPage`) | true | Chat delay only applies while true; toggling starts the sync countdown / flushes held lines; details "Chat only / Show video" flips it; emote grid 6 vs 16 columns in landscape |
| `chatDelay` | 0.0 s | Manual delay (used when auto sync is off) |
| `autoSyncChatDelay` | true (one-time migration turns it on when `chatDelay == 0`) | When on, `effectiveChatDelay = syncedChatDelay` (measured video latency, runtime only); a first non-zero value starts the countdown |
| `effectiveChatDelay` (computed) | — | Seconds of chat delay (`toInt()`) |
| `mutedWords` | [] | Lines containing any are dropped (live, history) |
| `matchWholeWord` | true | Whole-word vs substring muting |
| `chatFiltersEnabled` | false | AutoMod-rating masking master switch ("Hide offensive messages" in details) |
| `chatFilterDiscrimination` / `chatFilterSexual` / `chatFilterHarassment` / `chatFilterProfanity` | true each | Categories masked from level 3 |
| `collapseGiftBombs` | true | Gifts of bombs ≥ 5 folded into the header row |
| `hideGiftSubNotices` | false | Gift notices (and their banners) not shown at all |
| `showModerationNotices` | true | "X has been timed out/banned" lines |
| `showModActionsInChat` | true | Mod action feed lines in chat (switch in mod tools hub) |
| `showEmoteChangeNotices` | true | 7TV/BTTV emote added/removed/renamed lines |
| `showRecentMessages` | false | Fallback third-party history when Twitch gives none |
| `mentionNotifications` | true | Background notifications for mentions |
| `autocomplete` | true | Autocomplete row height counted in `bottomBarHeight` |
| `animateEmotes` | true | Row rendering; animated-emotes callout precondition; preference switch |
| `animatedEmotesCalloutShown` | false | One-time callout flag (set true when shown) |
| `showGifs` / `animateGifs` | true / true | Row rendering; preference switches (animated GIFs enabled only when GIFs shown) |
| `readableNameColors` / `increaseChatContrast` | true / false | `nameColorContrast` (high when contrast increased, readable otherwise, null when both off); preference switches (readable locked on while contrast is on) |
| `timestampType`, `emoteScale`, `badgeScale`, `launchUrlExternal`, `showDeletedMessages` | disabled, 1.0, 1.0, false, true | Row-cache inputs (rendering is out of scope); `launchUrlExternal` also for emote details |
| `fontSize` | 12.0 | Default text size of the chat list |
| `messageScale` | 1.0 | Text scaler of the chat list |
| `showTwitchEmotes`, `showTwitchBadges`, `show7TVEmotes`, `showBTTVEmotes`, `showBTTVBadges`, `showFFZEmotes`, `showFFZBadges` | true each | Which providers are fetched; changing any refetches assets and opens/closes the 7TV/BTTV sockets; emote menu tabs |
| `show7TVBadges`, `show7TVPaints`, `show7TVPersonalEmotes`, `showBTTVPersonalEmotes`, `showFFZRoomBadges` | true each | Cosmetics lookups/maps; 7TV cosmetic subscriptions |
| `emoteMenuButtonOnLeft` | false | Where the tablet panel's nub points (start vs end of the input) |
| `landscapeForceVerticalChat` | false | Whether landscape uses the portrait layout (bottom safe padding, panel inset) |
| `tapToCloseOverlayChat` | false | Tapping the overlay chat list sets `fullScreenChatOverlay = false` |
| `fullScreenChatOverlay` | false | Written by the tap above |
| `keepScreenAwake` | true | Wakelock enabled while the chat tabs store lives |
| `persistChatTabs` | true | Secondary tabs restored / saved |
| `secondaryTabs` | [] | Persisted `PersistedChatTab` list |

Device preferences outside SettingsStore: SharedPreferences `recent_emotes` (JSON list, ≤ 48) and `chat_rules_accepted_<viewerId>_<channelId>` (bool). Secure storage: extra mod scopes requested via `openModLogin`.

## Strings

Every ARB key referenced by this area (generated with `spec-strings.mjs --emit`), English and French exactly as in `lib/l10n/app_en.arb` / `app_fr.arb`. ICU placeholders (`{name}`, plural/select) must be preserved in the Rust i18n layer (e.g. Fluent or ICU4X). Literal provider names `Twitch`, `7TV`, `BTTV`, `FFZ` are not translated.

| Key | EN | FR |
|---|---|---|
| `channelSubscribe` | Subscribe | S’abonner |
| `chatAlreadyBlocked` | {name} is already blocked. | Utilisateur déjà bloqué : {name}. |
| `chatAnimatedEmotesCallout` | Animated emotes can be turned off in Settings › Chat. | Vous pouvez désactiver les emotes animées dans Paramètres › Chat. |
| `chatAnimatedEmotesCalloutShow` | Show me | Me montrer |
| `chatAnonymousGifter` | An anonymous gifter | Anonyme |
| `chatAutoModHeld` | AutoMod is holding a message from {name}. | Message de {name} retenu par l’AutoMod. |
| `chatAutoModReview` | Review | Examiner |
| `chatBadgeTitle` | Your chat badge | Votre badge du chat |
| `chatBlockFailed` | Couldn’t block {login}. | Impossible de bloquer {login}. |
| `chatBlockedUser` | Blocked {name}. | Utilisateur bloqué : {name}. |
| `chatBttvEmoteAdded` | The BTTV emote “{emote}” was added to chat. | L’emote BTTV « {emote} » a été ajoutée au chat. |
| `chatBttvEmoteRemoved` | The BTTV emote “{emote}” was removed from chat. | L’emote BTTV « {emote} » a été retirée du chat. |
| `chatBttvEmoteRenamed` | The BTTV emote “{old}” was renamed “{emote}”. | L’emote BTTV « {old} » a été renommée « {emote} ». |
| `chatCannotSendDisconnected` | Can’t send: chat is disconnected. Reconnecting… | Impossible d’envoyer le message : le chat est déconnecté. Reconnexion… |
| `chatChattersFilter` | Filter chatters | Filtrer les utilisateurs |
| `chatChattersFound` | {count, plural, one{{count} chatter found} other{{count} chatters found}} | {count, plural, one{{count} utilisateur trouvé} other{{count} utilisateurs trouvés}} |
| `chatChattersNoMatch` | No matching chatters | Aucun utilisateur correspondant |
| `chatChattersNone` | No chatters found | Aucun utilisateur trouvé |
| `chatClear` | Clear | Effacer |
| `chatCollapsedAnnouncement` | Chat collapsed | Chat réduit |
| `chatColorChanged` | Your name color was changed. | Couleur du pseudo modifiée. |
| `chatColorFailedHex` | Couldn’t change your name color (hex colors need Turbo or Prime). | Impossible de changer la couleur de votre pseudo (les couleurs hexadécimales nécessitent Turbo ou Prime). |
| `chatColorName` | {color, select, blue{Blue} blue_violet{Blue violet} cadet_blue{Cadet blue} chocolate{Chocolate} coral{Coral} dodger_blue{Dodger blue} firebrick{Firebrick} golden_rod{Goldenrod} green{Green} hot_pink{Hot pink} orange_red{Orange red} red{Red} sea_green{Sea green} spring_green{Spring green} yellow_green{Yellow green} other{}} | {color, select, blue{Bleu} blue_violet{Bleu-violet} cadet_blue{Bleu cadet} chocolate{Chocolat} coral{Corail} dodger_blue{Bleu Dodger} firebrick{Rouge brique} golden_rod{Verge d’or} green{Vert} hot_pink{Rose vif} orange_red{Rouge orangé} red{Rouge} sea_green{Vert océan} spring_green{Vert printemps} yellow_green{Jaune-vert} other{}} |
| `chatColorPreview` | How it will look in chat | Voici à quoi ressemblera votre pseudo |
| `chatColorUpdateFailed` | Couldn’t update your name color. Try again. | Impossible de modifier la couleur du pseudo. Réessayez. |
| `chatColorUpdated` | Name color updated | Couleur du pseudo modifiée ! |
| `chatCommandArgChannel` | channel | chaîne |
| `chatCommandArgColor` | color | couleur |
| `chatCommandArgDescription` | description | texte |
| `chatCommandArgLength` | length | durée |
| `chatCommandArgMessage` | message | message |
| `chatCommandArgMessageId` | message id | ID du message |
| `chatCommandArgReason` | reason | motif |
| `chatCommandArgSeconds` | seconds | secondes |
| `chatCommandArgUser` | user | utilisateur |
| `chatCommandBadLength` | Unknown length “{length}”. Try 30, 10m, 2h, 1d, or 1w. | Durée non reconnue : « {length} ». Utilisez par exemple 30, 10m, 2h, 1d ou 1w. |
| `chatCommandDescription` | {command, select, me{Speak in the third person} color{Change your name color} block{Block a user} unblock{Unblock a user} w{Whisper a user} user{Open a user’s card} disconnect{Reconnect to chat} help{List the commands} ban{Ban a user} unban{Lift a ban} timeout{Time out a user (default 10m; s, m, h, d, w)} untimeout{Lift a timeout} warn{Warn a user} delete{Delete a message} clear{Delete every message} slow{Turn slow mode on (default 30s)} slowoff{Turn slow mode off} followers{Turn followers-only mode on (m, h, d, w, mo)} followersoff{Turn followers-only mode off} subscribers{Turn subscribers-only mode on} subscribersoff{Turn subscribers-only mode off} emoteonly{Turn emote-only mode on} emoteonlyoff{Turn emote-only mode off} uniquechat{Turn unique chat mode on (no repeated messages)} uniquechatoff{Turn unique chat mode off} announce{Send an announcement} announceblue{Send a blue announcement} announcegreen{Send a green announcement} announceorange{Send an orange announcement} announcepurple{Send a purple announcement} shoutout{Give a shoutout to a channel} shield{Turn shield mode on} shieldoff{Turn shield mode off} monitor{Monitor a user’s messages} unmonitor{Stop monitoring a user} restrict{Restrict a user (only moderators see their messages)} unrestrict{Lift a user’s restriction} mods{List the moderators} vips{List the VIPs} mod{Make a user a moderator} unmod{Remove a moderator} vip{Make a user a VIP} unvip{Remove a VIP} leadmod{Add a lead moderator} unleadmod{Remove a lead moderator} marker{Add a stream marker} commercial{Run an ad break (30, 60, 90, 120, 150, or 180 seconds)} raid{Raid a channel} unraid{Cancel the raid} other{}} | {command, select, me{Parler à la troisième personne} color{Changer la couleur de votre pseudo} block{Bloquer un utilisateur} unblock{Débloquer un utilisateur} w{Chuchoter à un utilisateur} user{Afficher le profil d’un utilisateur} disconnect{Se reconnecter au chat} help{Afficher la liste des commandes} ban{Bannir un utilisateur du chat} unban{Lever le bannissement d’un utilisateur} timeout{Exclure temporairement un utilisateur (10m par défaut ; s, m, h, d, w)} untimeout{Lever l’exclusion temporaire d’un utilisateur} warn{Avertir un utilisateur} delete{Supprimer un message} clear{Supprimer tous les messages} slow{Activer le mode lent (30s par défaut)} slowoff{Désactiver le mode lent} followers{Activer le mode followers uniquement (m, h, d, w, mo)} followersoff{Désactiver le mode followers uniquement} subscribers{Activer le mode abonnés uniquement} subscribersoff{Désactiver le mode abonnés uniquement} emoteonly{Activer le mode emotes uniquement} emoteonlyoff{Désactiver le mode emotes uniquement} uniquechat{Activer le mode chat unique (pas de messages répétés)} uniquechatoff{Désactiver le mode chat unique} announce{Envoyer une annonce} announceblue{Envoyer une annonce bleue} announcegreen{Envoyer une annonce verte} announceorange{Envoyer une annonce orange} announcepurple{Envoyer une annonce violette} shoutout{Faire une dédicace à une chaîne} shield{Activer le mode bouclier} shieldoff{Désactiver le mode bouclier} monitor{Surveiller les messages d’un utilisateur} unmonitor{Arrêter de surveiller un utilisateur} restrict{Restreindre un utilisateur (seuls les modérateurs voient ses messages)} unrestrict{Lever la restriction d’un utilisateur} mods{Afficher la liste des modérateurs} vips{Afficher la liste des VIP} mod{Attribuer le rôle de modérateur} unmod{Retirer le rôle de modérateur} vip{Attribuer le statut VIP} unvip{Retirer le statut VIP} leadmod{Attribuer le rôle de modérateur principal} unleadmod{Retirer le rôle de modérateur principal} marker{Ajouter un repère au live} commercial{Lancer une publicité (30, 60, 90, 120, 150 ou 180 secondes)} raid{Lancer un raid vers une chaîne} unraid{Annuler le raid} other{}} |
| `chatCommandFollowAgeRange` | Follow age must be between 0 minutes and 3 months (e.g., 10m, 1w, 3mo). | L’ancienneté de suivi va de 0 minute à 3 mois (par exemple 10m, 1w, 3mo). |
| `chatCommandNotInApp` | /{command} is not available in this app. | /{command} n’est pas disponible dans cette application. |
| `chatCommandSlowRange` | Slow mode must be between 3 and 120 seconds. | Le délai du mode lent va de 3 à 120 secondes. |
| `chatCommandTimeoutRange` | Timeouts must be between 1 second and 2 weeks. | Une exclusion temporaire dure de 1 seconde à 2 semaines. |
| `chatCommandUnknown` | Unknown command /{command}. Type /help for the commands you can use. | Commande inconnue : /{command}. Tapez /help pour voir les commandes disponibles. |
| `chatCommandUnknownColor` | Unknown color. Try Blue, Coral, HotPink, or #RRGGBB (Turbo or Prime). | Couleur inconnue. Essayez blue, coral, hotpink… ou #RRGGBB (Turbo ou Prime). |
| `chatCommandUsage` | Usage: {usage} | Utilisation : {usage} |
| `chatConnecting` | Connecting to chat… | Connexion au chat… |
| `chatDetailsAddChat` | Add chat | Ajouter un chat |
| `chatDetailsChatOnly` | Chat only | Chat seul |
| `chatDetailsChatters` | Chatters | Utilisateurs dans le chat |
| `chatDetailsGiftSub` | Gift a sub | Offrir un abonnement |
| `chatDetailsHideOffensive` | Hide offensive language | Masquer les propos choquants |
| `chatDetailsModes` | Chat modes | Modes du chat |
| `chatDetailsModesDetail` | Slow, followers-only, clear chat… | Lent, followers, effacer le chat… |
| `chatDetailsOpensTwitch` | Opens twitch.tv | Ouvre twitch.tv |
| `chatDetailsOpensTwitchChat` | Opens the chat on twitch.tv | Ouvre le chat sur twitch.tv |
| `chatDetailsPointsPollsPredictions` | Channel points, polls, and predictions | Points de chaîne, sondages et prédictions |
| `chatDetailsPreferences` | Preferences | Préférences |
| `chatDetailsRefreshAssets` | Refresh emotes and badges | Actualiser les emotes et les badges |
| `chatDetailsShowVideo` | Show video | Afficher la vidéo |
| `chatDetailsSleepTimer` | Sleep timer | Minuteur de mise en veille |
| `chatDetailsTwitchChat` | Twitch chat | Chat Twitch |
| `chatDetailsUsernameColor` | Name color | Couleur du pseudo |
| `chatDisconnected` | Chat disconnected. Check your connection. | Chat déconnecté. Vérifiez votre connexion Internet. |
| `chatDurationDays` | {count, plural, one{{count} day} other{{count} days}} | {count, plural, one{{count} jour} other{{count} jours}} |
| `chatDurationHours` | {count, plural, one{{count} hour} other{{count} hours}} | {count, plural, one{{count} heure} other{{count} heures}} |
| `chatDurationMinutes` | {count, plural, one{{count} minute} other{{count} minutes}} | {count, plural, one{{count} minute} other{{count} minutes}} |
| `chatDurationMonths` | {count, plural, one{{count} month} other{{count} months}} | {count, plural, one{{count} mois} other{{count} mois}} |
| `chatEmoteMenu` | Emote menu | Menu des emotes |
| `chatExpandedAnnouncement` | Chat expanded | Chat agrandi |
| `chatHeldDecision` | {decision, select, approved{Moderators approved your held message} denied{Moderators denied your held message} other{Your held message can no longer be reviewed}} | {decision, select, approved{Les modérateurs ont approuvé votre message retenu} denied{Les modérateurs ont refusé votre message retenu} other{Votre message retenu ne peut plus être examiné}} |
| `chatHeldQuoted` | {decision}: “{quote}” | {decision} : « {quote} » |
| `chatHelpCommands` | Commands: {commands} | Commandes : {commands} |
| `chatLogInToChangeColor` | Log in to change your name color. | Connectez-vous pour changer de couleur. |
| `chatLogInToModerate` | Log in to moderate. | Connectez-vous pour modérer. |
| `chatLogInToWhisper` | Log in to whisper. | Connectez-vous pour chuchoter. |
| `chatMaybeNotSent` | Your message may not have been sent. Try again. | Le message n’a peut-être pas été envoyé. Réessayez. |
| `chatMessageTooLong` | Messages can be {max} characters at most. | Les messages sont limités à {max} caractères |
| `chatModAction` | {action, select, ban{{moderator} banned {user}.} timeout{{moderator} timed out {user} for {duration}.} timeoutUnknown{{moderator} timed out {user}.} unban{{moderator} unbanned {user}.} untimeout{{moderator} lifted the timeout on {user}.} warn{{moderator} warned {user}.} delete{{moderator} deleted a message from {user}.} clear{{moderator} cleared the chat.} mod{{moderator} made {user} a moderator.} unmod{{moderator} removed {user} as a moderator.} vip{{moderator} made {user} a VIP.} unvip{{moderator} removed {user} as a VIP.} raid{{moderator} started a raid on {user}.} unraid{{moderator} canceled the raid on {user}.} addBlockedTerm{{moderator} added a blocked term.} removeBlockedTerm{{moderator} removed a blocked term.} addPermittedTerm{{moderator} added a permitted term.} removePermittedTerm{{moderator} removed a permitted term.} approveUnbanRequest{{moderator} approved the unban request from {user}.} denyUnbanRequest{{moderator} denied the unban request from {user}.} emoteonly{{moderator} turned emote-only mode on.} emoteonlyoff{{moderator} turned emote-only mode off.} followers{{moderator} turned followers-only mode on.} followersoff{{moderator} turned followers-only mode off.} slow{{moderator} turned slow mode on.} slowoff{{moderator} turned slow mode off.} subscribers{{moderator} turned subscribers-only mode on.} subscribersoff{{moderator} turned subscribers-only mode off.} uniquechat{{moderator} turned unique chat mode on.} uniquechatoff{{moderator} turned unique chat mode off.} other{{moderator} took a moderation action.}} | {action, select, ban{{moderator} a banni {user}.} timeout{{moderator} a exclu temporairement {user} ({duration}).} timeoutUnknown{{moderator} a exclu temporairement {user}.} unban{{moderator} a débanni {user}.} untimeout{{moderator} a levé l’exclusion temporaire visant {user}.} warn{{moderator} a averti {user}.} delete{{moderator} a supprimé un message envoyé par {user}.} clear{{moderator} a effacé le chat.} mod{{moderator} a attribué le rôle de modérateur à {user}.} unmod{{moderator} a retiré le rôle de modérateur à {user}.} vip{{moderator} a attribué le statut VIP à {user}.} unvip{{moderator} a retiré le statut VIP à {user}.} raid{{moderator} a lancé un raid vers la chaîne {user}.} unraid{{moderator} a annulé le raid vers la chaîne {user}.} addBlockedTerm{{moderator} a ajouté un terme bloqué.} removeBlockedTerm{{moderator} a retiré un terme bloqué.} addPermittedTerm{{moderator} a ajouté un terme autorisé.} removePermittedTerm{{moderator} a retiré un terme autorisé.} approveUnbanRequest{{moderator} a accepté la demande de débannissement envoyée par {user}.} denyUnbanRequest{{moderator} a refusé la demande de débannissement envoyée par {user}.} emoteonly{{moderator} a activé le mode emotes uniquement.} emoteonlyoff{{moderator} a désactivé le mode emotes uniquement.} followers{{moderator} a activé le mode followers uniquement.} followersoff{{moderator} a désactivé le mode followers uniquement.} slow{{moderator} a activé le mode lent.} slowoff{{moderator} a désactivé le mode lent.} subscribers{{moderator} a activé le mode abonnés uniquement.} subscribersoff{{moderator} a désactivé le mode abonnés uniquement.} uniquechat{{moderator} a activé le mode chat unique.} uniquechatoff{{moderator} a désactivé le mode chat unique.} other{{moderator} a effectué une action de modération.}} |
| `chatModActionWithReason` | {line} Reason: “{reason}”. | {line} Motif : « {reason} ». |
| `chatModAnnounced` | Announcement sent. | Annonce envoyée. |
| `chatModBanned` | You banned {name}. | Vous avez banni {name}. |
| `chatModBroadcasterOnly` | {command} only works in your own channel. | {command} ne fonctionne que sur votre propre chaîne. |
| `chatModCannotModerate` | Twitch says you can’t moderate this chat. | Twitch indique que vous ne pouvez pas modérer ce chat. |
| `chatModCleared` | You cleared the chat. | Vous avez effacé le chat. |
| `chatModCommercialStarted` | Ad break started ({duration}). | Publicité lancée ({duration}). |
| `chatModFailed` | Couldn’t {command, select, ban{ban the user} timeout{time out the user} untimeout{lift the timeout} unban{unban the user} warn{warn the user} delete{delete the message} clear{clear the chat} slowOn{turn slow mode on} slowOff{turn slow mode off} followersOn{turn followers-only mode on} followersOff{turn followers-only mode off} subscribersOn{turn subscribers-only mode on} subscribersOff{turn subscribers-only mode off} emoteOnlyOn{turn emote-only mode on} emoteOnlyOff{turn emote-only mode off} uniqueChatOn{turn unique chat mode on} uniqueChatOff{turn unique chat mode off} announce{send the announcement} shoutout{send the shoutout} mods{list the moderators} vips{list the VIPs} mod{add the moderator} unmod{remove the moderator} vip{add the VIP} unvip{remove the VIP} shieldOn{turn shield mode on} shieldOff{turn shield mode off} marker{add the stream marker} commercial{start the ad break} raid{start the raid} unraid{cancel the raid} monitor{monitor the user} unmonitor{stop monitoring the user} restrict{restrict the user} unrestrict{lift the restriction} blockTerm{add the blocked term} unblockTerm{remove the blocked term} allowMessage{allow the message} denyMessage{deny the message} approveUnban{approve the unban request} denyUnban{deny the unban request} createPoll{start the poll} endPoll{end the poll} createPrediction{start the prediction} lockPrediction{lock the prediction} resolvePrediction{confirm the result} cancelPrediction{cancel the prediction} fulfil{complete the request} refund{refund the request} updateStream{save the stream info} load{load the list} loadStream{load the stream info} other{do that}}: {reason} | Impossible {command, select, ban{de bannir} timeout{d’exclure temporairement} untimeout{de lever l’exclusion temporaire} unban{de débannir} warn{d’avertir} delete{de supprimer le message} clear{d’effacer le chat} slowOn{d’activer le mode lent} slowOff{de désactiver le mode lent} followersOn{d’activer le mode followers uniquement} followersOff{de désactiver le mode followers uniquement} subscribersOn{d’activer le mode abonnés uniquement} subscribersOff{de désactiver le mode abonnés uniquement} emoteOnlyOn{d’activer le mode emotes uniquement} emoteOnlyOff{de désactiver le mode emotes uniquement} uniqueChatOn{d’activer le mode chat unique} uniqueChatOff{de désactiver le mode chat unique} announce{d’envoyer l’annonce} shoutout{d’envoyer la dédicace} mods{d’afficher les modérateurs} vips{d’afficher les VIP} mod{d’attribuer le rôle de modérateur} unmod{de retirer le rôle de modérateur} vip{d’attribuer le statut VIP} unvip{de retirer le statut VIP} shieldOn{d’activer le mode bouclier} shieldOff{de désactiver le mode bouclier} marker{d’ajouter le repère} commercial{de lancer la publicité} raid{de lancer le raid} unraid{d’annuler le raid} monitor{de surveiller l’utilisateur} unmonitor{d’arrêter la surveillance} restrict{de restreindre l’utilisateur} unrestrict{de lever la restriction} blockTerm{d’ajouter le terme bloqué} unblockTerm{de retirer le terme bloqué} allowMessage{d’autoriser le message} denyMessage{de refuser le message} approveUnban{d’accepter la demande de débannissement} denyUnban{de refuser la demande de débannissement} createPoll{de lancer le sondage} endPoll{de terminer le sondage} createPrediction{de lancer la prédiction} lockPrediction{de verrouiller la prédiction} resolvePrediction{de confirmer le résultat} cancelPrediction{d’annuler la prédiction} fulfil{de valider la demande} refund{de rembourser la demande} updateStream{d’enregistrer les infos du live} load{de charger la liste} loadStream{de charger les infos du live} other{d’effectuer cette action}}. {reason} |
| `chatModFailedUnexpected` | Couldn’t {command, select, ban{ban the user} timeout{time out the user} untimeout{lift the timeout} unban{unban the user} warn{warn the user} delete{delete the message} clear{clear the chat} slowOn{turn slow mode on} slowOff{turn slow mode off} followersOn{turn followers-only mode on} followersOff{turn followers-only mode off} subscribersOn{turn subscribers-only mode on} subscribersOff{turn subscribers-only mode off} emoteOnlyOn{turn emote-only mode on} emoteOnlyOff{turn emote-only mode off} uniqueChatOn{turn unique chat mode on} uniqueChatOff{turn unique chat mode off} announce{send the announcement} shoutout{send the shoutout} mods{list the moderators} vips{list the VIPs} mod{add the moderator} unmod{remove the moderator} vip{add the VIP} unvip{remove the VIP} shieldOn{turn shield mode on} shieldOff{turn shield mode off} marker{add the stream marker} commercial{start the ad break} raid{start the raid} unraid{cancel the raid} monitor{monitor the user} unmonitor{stop monitoring the user} restrict{restrict the user} unrestrict{lift the restriction} blockTerm{add the blocked term} unblockTerm{remove the blocked term} allowMessage{allow the message} denyMessage{deny the message} approveUnban{approve the unban request} denyUnban{deny the unban request} createPoll{start the poll} endPoll{end the poll} createPrediction{start the prediction} lockPrediction{lock the prediction} resolvePrediction{confirm the result} cancelPrediction{cancel the prediction} fulfil{complete the request} refund{refund the request} updateStream{save the stream info} load{load the list} loadStream{load the stream info} other{do that}} (unexpected error). | Impossible {command, select, ban{de bannir} timeout{d’exclure temporairement} untimeout{de lever l’exclusion temporaire} unban{de débannir} warn{d’avertir} delete{de supprimer le message} clear{d’effacer le chat} slowOn{d’activer le mode lent} slowOff{de désactiver le mode lent} followersOn{d’activer le mode followers uniquement} followersOff{de désactiver le mode followers uniquement} subscribersOn{d’activer le mode abonnés uniquement} subscribersOff{de désactiver le mode abonnés uniquement} emoteOnlyOn{d’activer le mode emotes uniquement} emoteOnlyOff{de désactiver le mode emotes uniquement} uniqueChatOn{d’activer le mode chat unique} uniqueChatOff{de désactiver le mode chat unique} announce{d’envoyer l’annonce} shoutout{d’envoyer la dédicace} mods{d’afficher les modérateurs} vips{d’afficher les VIP} mod{d’attribuer le rôle de modérateur} unmod{de retirer le rôle de modérateur} vip{d’attribuer le statut VIP} unvip{de retirer le statut VIP} shieldOn{d’activer le mode bouclier} shieldOff{de désactiver le mode bouclier} marker{d’ajouter le repère} commercial{de lancer la publicité} raid{de lancer le raid} unraid{d’annuler le raid} monitor{de surveiller l’utilisateur} unmonitor{d’arrêter la surveillance} restrict{de restreindre l’utilisateur} unrestrict{de lever la restriction} blockTerm{d’ajouter le terme bloqué} unblockTerm{de retirer le terme bloqué} allowMessage{d’autoriser le message} denyMessage{de refuser le message} approveUnban{d’accepter la demande de débannissement} denyUnban{de refuser la demande de débannissement} createPoll{de lancer le sondage} endPoll{de terminer le sondage} createPrediction{de lancer la prédiction} lockPrediction{de verrouiller la prédiction} resolvePrediction{de confirmer le résultat} cancelPrediction{d’annuler la prédiction} fulfil{de valider la demande} refund{de rembourser la demande} updateStream{d’enregistrer les infos du live} load{de charger la liste} loadStream{de charger les infos du live} other{d’effectuer cette action}} (erreur inattendue). |
| `chatModLogInAgain` | Log in again to moderate from this app. | Reconnectez-vous pour modérer depuis cette application. |
| `chatModMarkerAdded` | Stream marker added. | Repère ajouté au live. |
| `chatModMessageDeleted` | Message deleted. | Message supprimé. |
| `chatModModeratorList` | {count, plural, one{Moderator ({count}): {names}} other{Moderators ({count}): {names}}} | {count, plural, one{Modérateur ({count}) : {names}} other{Modérateurs ({count}) : {names}}} |
| `chatModNoUser` | no user named {login}. | Aucun utilisateur nommé {login}. |
| `chatModNotThrough` | That didn’t go through. Try again. | L’action n’a pas abouti. Réessayez. |
| `chatModPinChanged` | {state, select, pinned{Message pinned for 20 minutes.} other{Message unpinned.}} | {state, select, pinned{Message épinglé pendant 20 minutes.} other{Message désépinglé.}} |
| `chatModRaidCanceled` | Raid canceled. | Raid annulé. |
| `chatModRaidStarted` | Preparing the raid on {name}. | Préparation du raid vers la chaîne {name}. |
| `chatModRoleChanged` | {change, select, moderatorAdded{{name} is now a moderator.} moderatorRemoved{{name} is no longer a moderator.} vipAdded{{name} is now a VIP.} vipRemoved{{name} is no longer a VIP.} leadModeratorAdded{{name} is now a lead moderator.} leadModeratorRemoved{{name} is no longer a lead moderator.} other{{name}’s role changed.}} | {change, select, moderatorAdded{Rôle de modérateur attribué : {name}.} moderatorRemoved{Rôle de modérateur retiré : {name}.} vipAdded{Statut VIP attribué : {name}.} vipRemoved{Statut VIP retiré : {name}.} leadModeratorAdded{Rôle de modérateur principal attribué : {name}.} leadModeratorRemoved{Rôle de modérateur principal retiré : {name}.} other{Rôle modifié : {name}.}} |
| `chatModRoleListEmpty` | {role, select, moderator{This channel has no moderators.} vip{This channel has no VIPs.} other{Nobody has this role.}} | {role, select, moderator{Cette chaîne n’a aucun modérateur.} vip{Cette chaîne n’a aucun VIP.} other{Personne n’a ce rôle.}} |
| `chatModShield` | {state, select, on{Shield mode is on.} other{Shield mode is off.}} | {state, select, on{Mode bouclier activé.} other{Mode bouclier désactivé.}} |
| `chatModShoutoutSent` | Shoutout sent to {name}. | Dédicace envoyée à la chaîne {name}. |
| `chatModSuspicion` | {change, select, monitor{{name} is now monitored.} unmonitor{{name} is no longer monitored.} restrict{{name} is now restricted.} unrestrict{{name} is no longer restricted.} other{{name}’s status changed.}} | {change, select, monitor{Surveillance activée : {name}.} unmonitor{Surveillance levée : {name}.} restrict{Restriction activée : {name}.} unrestrict{Restriction levée : {name}.} other{Statut modifié : {name}.}} |
| `chatModTimedOut` | You timed out {name} for {duration}. | Vous avez exclu {name} pendant {duration}. |
| `chatModUnbanned` | You unbanned {name}. | Vous avez débanni {name}. |
| `chatModUntimedOut` | You lifted {name}’s timeout. | Exclusion temporaire levée : {name}. |
| `chatModViewList` | View list | Voir la liste |
| `chatModVipList` | {count, plural, one{VIP ({count}): {names}} other{VIPs ({count}): {names}}} | {count, plural, one{VIP ({count}) : {names}} other{VIP ({count}) : {names}}} |
| `chatModWarned` | You warned {name}. | Vous avez averti {name}. |
| `chatModeChanged` | {mode, select, slow{Slow mode} followers{Followers-only mode} subscribers{Subscribers-only mode} emoteOnly{Emote-only mode} uniqueChat{Unique chat mode} other{}} {state, select, on{on} other{off}}. | {mode, select, slow{Mode lent} followers{Mode followers uniquement} subscribers{Mode abonnés uniquement} emoteOnly{Mode emotes uniquement} uniqueChat{Mode chat unique} other{}} {state, select, on{activé} other{désactivé}}. |
| `chatModeExplainer` | {mode, select, emoteOnly{Messages can only contain emotes.} followersNow{Only followers can chat.} followers{Only followers can chat, once they’ve followed for the time shown.} slow{Everyone must wait the time shown between messages.} subscribers{Only subscribers can chat.} uniqueChat{Each message must be unique: repeated messages are refused.} other{}} | {mode, select, emoteOnly{Les messages ne peuvent contenir que des emotes.} followersNow{Seuls les followers peuvent écrire dans le chat.} followers{Seuls les followers peuvent écrire dans le chat, après avoir suivi la chaîne pendant la durée indiquée.} slow{Chacun doit attendre la durée indiquée entre deux messages.} subscribers{Seuls les abonnés peuvent écrire dans le chat.} uniqueChat{Chaque message doit être unique : les messages répétés sont refusés.} other{}} |
| `chatModeFollowersOn` | Followers-only mode on (must follow for {duration}). | Mode followers uniquement activé (followers depuis au moins {duration}). |
| `chatModeSlowOn` | Slow mode on ({duration}). | Mode lent activé ({duration}). |
| `chatModesAnyFollower` | Any follower | Tous les followers |
| `chatModesClearChat` | Clear chat | Effacer le chat |
| `chatModesClearMessage` | Every message is deleted for everyone. | Tous les messages sont supprimés pour tout le monde. |
| `chatModesClearTitle` | Clear chat? | Effacer le chat ? |
| `chatModesModerator` | Moderator | Modérateur |
| `chatModesSlowWait` | {seconds}s between messages | {seconds} s entre les messages |
| `chatNewMessages` | {count, plural, one{{count} new message} other{{count} new messages}} | {count, plural, one{{count} nouveau message} other{{count} nouveaux messages}} |
| `chatNoticeBanned` | {name} has been permanently banned. | Bannissement définitif : {name}. |
| `chatNoticeOwnMessageDeleted` | Your message was deleted: “{message}”. | Votre message a été supprimé : « {message} ». |
| `chatNoticeTimedOut` | {name} has been timed out. | Exclusion temporaire : {name}. |
| `chatNoticeTimedOutFor` | {name} has been timed out for {duration}. | Exclusion temporaire ({duration}) : {name}. |
| `chatReconnect` | Reconnect | Se reconnecter |
| `chatReconnected` | {attempts, plural, one{Reconnected ({attempts} attempt, {seconds}s)} other{Reconnected ({attempts} attempts, {seconds}s)}} | {attempts, plural, one{Chat reconnecté ({attempts} tentative, {seconds} s)} other{Chat reconnecté ({attempts} tentatives, {seconds} s)}} |
| `chatReconnecting` | Reconnecting… (attempt {attempt} of {max}) | Reconnexion… (tentative {attempt} sur {max}) |
| `chatReconnectingIn` | Reconnecting in {seconds}s… (attempt {attempt} of {max}) | Reconnexion dans {seconds} s… (tentative {attempt} sur {max}) |
| `chatReconnectingNotice` | Reconnecting to chat… | Reconnexion au chat… |
| `chatRestrictionAccount` | {reason, select, verifiedEmail{Verified email required} verifiedPhone{Verified phone required} emailAliasBanned{Email banned here} phoneAliasBanned{Phone banned here} accountRestricted{Account restricted} channelRestricted{Chat suspended here} followRequired{Follow to chat} warned{Warning received} other{}} | {reason, select, verifiedEmail{E-mail vérifié requis} verifiedPhone{Téléphone vérifié requis} emailAliasBanned{E-mail banni ici} phoneAliasBanned{Téléphone banni ici} accountRestricted{Compte restreint} channelRestricted{Chat suspendu ici} followRequired{Suivez la chaîne} warned{Avertissement reçu} other{}} |
| `chatRestrictionBanned` | Permanently banned | Bannissement définitif |
| `chatRestrictionEmoteOnly` | Emote-only chat | Mode emotes uniquement |
| `chatRestrictionFollowersFor` | Followers-only · {duration} | Followers depuis {duration} |
| `chatRestrictionFollowersOnly` | Followers-only chat | Followers uniquement |
| `chatRestrictionSlow` | Slow mode · you can chat again in {wait} | Mode lent · encore {wait} |
| `chatRestrictionSubscribersOnly` | Subscribers-only chat | Mode abonnés uniquement |
| `chatRestrictionTimedOut` | You’re timed out | Exclusion temporaire |
| `chatRestrictionTimedOutFor` | You’re timed out · {wait} | Exclusion temporaire · {wait} |
| `chatResumeScroll` | Resume scroll | Revenir en bas |
| `chatSave` | Save | Enregistrer |
| `chatServerNotice` | {notice, select, rateLimit{Couldn’t send your message. You’re sending messages too quickly.} duplicate{Couldn’t send your message. It’s the same as one you sent less than 30 seconds ago.} subsOnly{Couldn’t send your message. This chat is in subscribers-only mode: subscribe to the channel to chat.} emoteOnly{Couldn’t send your message. This chat is in emote-only mode.} uniqueChat{Couldn’t send your message. This chat is in unique chat mode, and your message isn’t original.} followRequired{Couldn’t send your message. This chat is in followers-only mode: follow the channel to chat.} followedTooRecently{Couldn’t send your message. You haven’t followed this channel long enough to chat yet.} verifiedEmail{Couldn’t send your message. This channel requires a verified email address: verify yours in your Twitch security settings.} verifiedPhone{Couldn’t send your message. This channel requires a verified phone number: verify yours in your Twitch security settings.} emailAliasBanned{Couldn’t send your message. Your email address is banned from this channel.} phoneAliasBanned{Couldn’t send your message. Your phone number is banned from this channel.} channelSuspended{This channel doesn’t exist or is suspended.} accountSuspended{Couldn’t send your message. Your account is suspended.} channelBlocked{Couldn’t send your message. Your account isn’t in good standing in this channel.} userRestricted{Couldn’t send your message. Your account can’t send chat messages for now. Learn more at appeals.twitch.tv.} channelRestricted{Couldn’t send your message. This channel can’t receive chat messages for now.} invalidReply{Couldn’t send your reply. That message can’t be replied to.} unexpected{Couldn’t send your message. Try again.} badCharacters{Couldn’t send your message. It contains too many characters Twitch can’t process.} rejectedBySettings{Couldn’t send your message. It conflicts with the channel’s moderation settings.} tooManyChats{Too many chats are open at once. Leave one to join this one.} warned{Couldn’t send your message. A moderator warned you: acknowledge the warning on twitch.tv to chat again.} banned{You’re permanently banned from this chat.} followersOnNow{This chat is now in followers-only mode.} noPermission{You don’t have permission to do that.} other{}} | {notice, select, rateLimit{Impossible d’envoyer votre message. Vous envoyez des messages trop vite.} duplicate{Impossible d’envoyer votre message. Il est identique à un message envoyé il y a moins de 30 secondes.} subsOnly{Impossible d’envoyer votre message. Le chat est en mode abonnés uniquement : abonnez-vous à la chaîne pour écrire.} emoteOnly{Impossible d’envoyer votre message. Le chat est en mode emotes uniquement.} uniqueChat{Impossible d’envoyer votre message. Le chat est en mode chat unique et votre message n’est pas original.} followRequired{Impossible d’envoyer votre message. Le chat est en mode followers uniquement : suivez la chaîne pour écrire.} followedTooRecently{Impossible d’envoyer votre message. Vous ne suivez pas cette chaîne depuis assez longtemps pour écrire.} verifiedEmail{Impossible d’envoyer votre message. Cette chaîne exige une adresse e-mail vérifiée : vérifiez la vôtre dans les paramètres de sécurité de Twitch.} verifiedPhone{Impossible d’envoyer votre message. Cette chaîne exige un numéro de téléphone vérifié : vérifiez le vôtre dans les paramètres de sécurité de Twitch.} emailAliasBanned{Impossible d’envoyer votre message. Votre adresse e-mail est bannie de cette chaîne.} phoneAliasBanned{Impossible d’envoyer votre message. Votre numéro de téléphone est banni de cette chaîne.} channelSuspended{Cette chaîne n’existe pas ou est suspendue.} accountSuspended{Impossible d’envoyer votre message. Votre compte est suspendu.} channelBlocked{Impossible d’envoyer votre message. Votre compte n’est pas en règle sur cette chaîne.} userRestricted{Impossible d’envoyer votre message. Votre compte ne peut pas envoyer de messages pour le moment. En savoir plus sur appeals.twitch.tv.} channelRestricted{Impossible d’envoyer votre message. Cette chaîne ne peut pas recevoir de messages pour le moment.} invalidReply{Impossible d’envoyer votre réponse. Il n’est pas possible de répondre à ce message.} unexpected{Impossible d’envoyer votre message. Réessayez.} badCharacters{Impossible d’envoyer votre message. Il contient trop de caractères que Twitch ne peut pas traiter.} rejectedBySettings{Impossible d’envoyer votre message. Il est contraire aux paramètres de modération de la chaîne.} tooManyChats{Trop de chats sont ouverts en même temps. Quittez-en un pour rejoindre celui-ci.} warned{Impossible d’envoyer votre message. Vous avez reçu un avertissement d’un modérateur : confirmez-en la lecture sur twitch.tv pour écrire de nouveau.} banned{Bannissement définitif : vous ne pouvez plus écrire dans ce chat.} followersOnNow{Le chat est maintenant en mode followers uniquement.} noPermission{Vous n’avez pas l’autorisation de faire cela.} other{}} |
| `chatServerNoticeSlowMode` | Couldn’t send your message. This chat is in slow mode: you can chat again in {wait}. | Impossible d’envoyer votre message. Le chat est en mode lent : vous pourrez écrire de nouveau dans {wait}. |
| `chatServerNoticeTimedOut` | You’re timed out: you can chat again in {wait}. | Exclusion temporaire : vous pourrez écrire de nouveau dans {wait}. |
| `chatServerNoticeUnknownCommand` | Unknown command: {command}. | Commande inconnue : {command}. |
| `chatSevenTvEmoteAdded` | {name} added the 7TV emote “{emote}” to chat. | {name} a ajouté l’emote 7TV « {emote} » au chat. |
| `chatSevenTvEmoteRemoved` | {name} removed the 7TV emote “{emote}” from chat. | {name} a retiré l’emote 7TV « {emote} » du chat. |
| `chatSevenTvEmoteRenamed` | {name} renamed the 7TV emote “{old}” to “{emote}”. | {name} a renommé l’emote 7TV « {old} » en « {emote} ». |
| `chatSevenTvEmoteSetSwitched` | {name} switched this channel’s 7TV emotes to the set “{set}”. | {name} a remplacé les emotes 7TV de la chaîne par l’ensemble « {set} ». |
| `chatSevenTvSomeone` | Someone | Quelqu’un |
| `chatShieldModeChangedBy` | {state, select, on{{moderator} turned shield mode on.} other{{moderator} turned shield mode off.}} | {state, select, on{{moderator} a activé le mode bouclier.} other{{moderator} a désactivé le mode bouclier.}} |
| `chatShortHours` | {hours}h | {hours} h |
| `chatShortHoursMinutes` | {hours}h {minutes}m | {hours} h {minutes} min |
| `chatShortMinutes` | {minutes}m | {minutes} min |
| `chatShortMinutesSeconds` | {minutes}m {seconds}s | {minutes} min {seconds} s |
| `chatShortSeconds` | {seconds}s | {seconds} s |
| `chatShoutoutNotice` | Shoutout to {name}! Check out their channel. | Dédicace à la chaîne {name} ! Allez la découvrir. |
| `chatShoutoutView` | View | Voir |
| `chatSyncIn` | Chat will sync in {seconds}s… | Synchronisation du chat dans {seconds} s… |
| `chatTimedOutForLength` | Timed out for {duration} | Exclusion temporaire ({duration}) |
| `chatUnblockFailed` | Couldn’t unblock {login}. | Impossible de débloquer {login}. |
| `chatUnblockedUser` | Unblocked {name}. | Utilisateur débloqué : {name}. |
| `chatUserCardFailed` | Couldn’t open the user card for {login}. | Impossible d’ouvrir le profil du compte {login}. |
| `chatUserCardNoUser` | Couldn’t open the user card: no user named {login}. | Impossible d’ouvrir le profil. Aucun utilisateur nommé {login}. |
| `chatWaitCommand` | Running the previous command… | Patientez, exécution de la commande précédente… |
| `chatWaitMessage` | Sending the previous message… | Patientez, envoi du message précédent… |
| `chatWelcome` | Welcome to {name}’s chat! | Bienvenue dans le chat de la chaîne {name} ! |
| `chatWhisperFailed` | Couldn’t whisper. | Impossible de chuchoter. |
| `chatWhisperFailedBecause` | Couldn’t whisper: {reason} | Impossible de chuchoter. {reason} |
| `chatWhisperNoUser` | Couldn’t whisper: no user named {login}. | Impossible de chuchoter. Aucun utilisateur nommé {login}. |
| `chatWhisperSent` | Whisper sent to {name}. The conversation is in your whispers. | Chuchotement envoyé à {name}. La conversation est dans vos chuchotements. |
| `chatWhisperSentNoReplies` | Whisper sent to {name}. Replies can’t reach this app until you log in again. | Chuchotement envoyé à {name}. Les réponses ne pourront pas arriver dans cette application avant votre prochaine connexion. |
| `commonCancel` | Cancel | Annuler |
| `commonRetry` | Retry | Réessayer |
| `emoteMenuAnimated` | {name}, animated emote | {name}, emote animée |
| `emoteMenuChannel` | Channel | Chaîne |
| `emoteMenuClearRecent` | Clear recent emotes | Effacer les emotes récentes |
| `emoteMenuFollowerInfo` | Follower emotes can only be used in {channel}’s chat. | Les emotes de follower ne peuvent être utilisées que dans le chat de la chaîne {channel}. |
| `emoteMenuGlobal` | Global | Globales |
| `emoteMenuLocked` | {name}, locked | {name}, verrouillée |
| `emoteMenuNoRecent` | No recent emotes | Aucune emote récente |
| `emoteMenuOther` | Other | Autres |
| `emoteMenuRecent` | Recent | Récentes |
| `emoteMenuRecentCleared` | Recent emotes cleared | Emotes récentes effacées |
| `emoteMenuUnlocked` | Unlocked | Débloquées |
| `gifLoadFailed` | Couldn’t load GIFs. Try again in a moment. | Impossible de charger les GIF. Réessayez dans un instant. |
| `gifNoResults` | No GIFs found. Try another search. | Aucun GIF trouvé. Essayez une autre recherche. |
| `gifPoweredBy` | Powered by GIPHY | Powered by GIPHY |
| `gifSearchHint` | Search GIPHY | Rechercher sur GIPHY |
| `gifSend` | Send | Envoyer |
| `gifSendDisclosure` | Everyone in this chat will see it. You’re responsible for the GIFs you send, so follow Twitch’s community guidelines. | Tout le chat le verra. Vous êtes responsable des GIF que vous envoyez : respectez les règles de la communauté de Twitch. |
| `gifSendResult` | {status, select, cooldown{{seconds, plural, =1{You can send another GIF in 1 second.} other{You can send another GIF in {seconds} seconds.}}} refused{Twitch declined this GIF.} integrityRefused{Twitch’s anti-bot check refused this. Connect a Twitch session in Settings › Account, then try again.} signedOut{Log in again to send GIFs from ONSET.} other{Couldn’t send the GIF. Try again.}} | {status, select, cooldown{{seconds, plural, one{Vous pourrez envoyer un autre GIF dans {seconds} seconde.} other{Vous pourrez envoyer un autre GIF dans {seconds} secondes.}}} refused{Twitch a refusé ce GIF.} integrityRefused{Le contrôle anti-robot de Twitch a refusé cette action. Connectez une session Twitch dans Paramètres › Compte, puis réessayez.} signedOut{Reconnectez-vous pour envoyer des GIF depuis ONSET.} other{Impossible d’envoyer le GIF. Réessayez.}} |
| `gifSendTitle` | Send this GIF? | Envoyer ce GIF ? |
| `gifSubscribersOnly` | You can’t send GIFs in this chat yet. On this channel, GIFs are a subscriber benefit. | Vous ne pouvez pas encore envoyer de GIF dans ce chat. Sur cette chaîne, les GIF sont un avantage réservé aux abonnés. |
| `gifTab` | GIFs | GIF |
| `gifUnavailable` | GIFs aren’t available in this chat. | Les GIF ne sont pas disponibles dans ce chat. |
| `modToolsActionLog` | Mod actions | Actions de modération |
| `modToolsActionLogCaption` | Actions taken in this chat since you opened it. | Actions effectuées dans ce chat depuis son ouverture. |
| `modToolsActionLogDetail` | Who did what, live | Qui a fait quoi, en direct |
| `modToolsActionLogEmpty` | No mod actions yet | Aucune action de modération pour l’instant |
| `modToolsAdd` | Add | Ajouter |
| `modToolsAddChoice` | Add a choice | Ajouter un choix |
| `modToolsAddOutcome` | Add an outcome | Ajouter un résultat |
| `modToolsAllow` | Allow | Autoriser |
| `modToolsAnnounce` | Send an announcement | Envoyer une annonce |
| `modToolsAnnounceCaption` | Highlighted in chat for everyone. | L’annonce est mise en avant dans le chat, pour tout le monde. |
| `modToolsAnnounceColor` | Color | Couleur |
| `modToolsAnnounceColorName` | {color, select, primary{Channel color} blue{Blue} green{Green} orange{Orange} purple{Purple} other{Channel color}} | {color, select, primary{Couleur de la chaîne} blue{Bleu} green{Vert} orange{Orange} purple{Violet} other{Couleur de la chaîne}} |
| `modToolsAnnounceLabel` | Announcement | Texte de l’annonce |
| `modToolsAnnounceSend` | Send | Envoyer |
| `modToolsApprove` | Approve | Accepter |
| `modToolsAutoModCaption` | Messages AutoMod is holding for review. | Messages retenus par l’AutoMod, en attente de décision. |
| `modToolsAutoModEmpty` | No messages are waiting | Aucun message en attente |
| `modToolsAutoModEmptyDetail` | Nothing to review | Rien à examiner |
| `modToolsAutoModPending` | {count, plural, one{{count} message waiting} other{{count} messages waiting}} | {count, plural, one{{count} message en attente} other{{count} messages en attente}} |
| `modToolsAutoModQueue` | AutoMod queue | File de l’AutoMod |
| `modToolsBlockedTermAdded` | Blocked term added. | Terme bloqué ajouté. |
| `modToolsBlockedTermRemoved` | Blocked term removed. | Terme bloqué retiré. |
| `modToolsBlockedTermTooShort` | A blocked term needs at least 2 characters. | Un terme bloqué doit comporter au moins 2 caractères. |
| `modToolsBlockedTerms` | Blocked terms | Termes bloqués |
| `modToolsBlockedTermsCaption` | Messages with these terms never reach chat. | Les messages contenant ces termes n’apparaissent jamais dans le chat. |
| `modToolsBlockedTermsEmpty` | No blocked terms | Aucun terme bloqué |
| `modToolsCaptionBroadcaster` | You own this channel | Vous êtes propriétaire de cette chaîne |
| `modToolsCaptionModerator` | You moderate this channel | Vous modérez cette chaîne |
| `modToolsCategoryLabel` | Category | Catégorie |
| `modToolsCategoryNone` | No category | Aucune catégorie |
| `modToolsChannelLabel` | Channel name | Nom de la chaîne |
| `modToolsChoiceLabel` | Choice {number} | Choix {number} |
| `modToolsClearResolved` | Clear resolved | Effacer les messages traités |
| `modToolsCommercial` | Run an ad | Lancer une publicité |
| `modToolsCommercialMessage` | Every viewer sees the ad. Pick its length. | Tous les spectateurs verront la publicité. Choisissez sa durée. |
| `modToolsCommercialStart` | Run ad | Lancer |
| `modToolsCommercialTitle` | Run an ad? | Lancer une publicité ? |
| `modToolsConfirm` | Confirm | Confirmer |
| `modToolsDeny` | Deny | Refuser |
| `modToolsEntryDetail` | AutoMod, terms, shield mode, and more | AutoMod, termes, mode bouclier et plus |
| `modToolsFulfil` | Complete | Valider |
| `modToolsFulfilled` | Request completed. | Demande validée. |
| `modToolsHeldLevel` | {reason} · level {level} | {reason} · niveau {level} |
| `modToolsHeldReason` | {reason, select, automod{AutoMod} blockedTerm{Blocked term} blockedLink{Blocked link} other{AutoMod}} | {reason, select, automod{AutoMod} blockedTerm{Terme bloqué} blockedLink{Lien bloqué} other{AutoMod}} |
| `modToolsHeldStatus` | {status, select, pending{Waiting} approved{Allowed} denied{Denied} expired{Expired} other{Waiting}} | {status, select, pending{En attente} approved{Autorisé} denied{Refusé} expired{Expiré} other{En attente}} |
| `modToolsLogInToEnable` | Log in again to use this | Reconnectez-vous pour y accéder |
| `modToolsMakeModerator` | Make moderator | Attribuer le rôle de modérateur |
| `modToolsMakeVip` | Make VIP | Attribuer le statut VIP |
| `modToolsMarker` | Add a stream marker | Ajouter un repère |
| `modToolsMarkerAdd` | Add | Ajouter |
| `modToolsMarkerLabel` | Description (optional) | Description (facultative) |
| `modToolsMarkerTitle` | Add a stream marker | Ajouter un repère |
| `modToolsModView` | Mod View | Vue modérateur |
| `modToolsModeratorCount` | {count, plural, one{{count} moderator} other{{count} moderators}} | {count, plural, one{{count} modérateur} other{{count} modérateurs}} |
| `modToolsModerators` | Moderators | Modérateurs |
| `modToolsMonitor` | Monitor messages | Surveiller ses messages |
| `modToolsOutcomeLabel` | Outcome {number} | Résultat {number} |
| `modToolsPermittedTerms` | Permitted terms | Termes autorisés |
| `modToolsPollDuration` | Duration | Durée |
| `modToolsPollEnd` | End poll | Terminer le sondage |
| `modToolsPollEndMessage` | Voting stops now and the results show. | Le vote s’arrête maintenant et les résultats s’affichent. |
| `modToolsPollEndTitle` | End the poll? | Terminer le sondage ? |
| `modToolsPollEnded` | Poll ended. | Sondage terminé. |
| `modToolsPollLive` | Poll in progress | Sondage en cours |
| `modToolsPollStart` | Start poll | Lancer le sondage |
| `modToolsPollStarted` | Poll started. | Sondage lancé. |
| `modToolsPolls` | Polls | Sondages |
| `modToolsPollsCaption` | Ask chat a question. | Posez une question au chat. |
| `modToolsPredictionCancel` | Cancel prediction | Annuler la prédiction |
| `modToolsPredictionCancelMessage` | Everyone gets their channel points back. | Tous les participants récupèrent leurs points de chaîne. |
| `modToolsPredictionCancelTitle` | Cancel the prediction? | Annuler la prédiction ? |
| `modToolsPredictionLive` | Prediction in progress | Prédiction en cours |
| `modToolsPredictionLock` | Lock | Verrouiller |
| `modToolsPredictionLockMessage` | No one can predict after this, and it can’t be undone. | Plus personne ne pourra participer. Ce verrouillage est définitif. |
| `modToolsPredictionLockTitle` | Lock the prediction? | Verrouiller la prédiction ? |
| `modToolsPredictionLocked` | Prediction locked | Prédiction verrouillée |
| `modToolsPredictionPickWinner` | Pick as result | Choisir ce résultat |
| `modToolsPredictionPoints` | {count, plural, one{{count} point} other{{count} points}} | {count, plural, one{{count} point} other{{count} points}} |
| `modToolsPredictionResolve` | Confirm result | Confirmer le résultat |
| `modToolsPredictionResolveMessage` | “{outcome}” wins. Channel points go to the people who picked it. | « {outcome} » l’emporte. Les points de chaîne reviennent aux participants qui l’ont choisi. |
| `modToolsPredictionResolveTitle` | Confirm the result? | Confirmer le résultat ? |
| `modToolsPredictionStart` | Start prediction | Lancer la prédiction |
| `modToolsPredictionStarted` | Prediction started. | Prédiction lancée. |
| `modToolsPredictionUpdated` | {state, select, locked{Prediction locked.} resolved{Result confirmed.} canceled{Prediction canceled.} other{Prediction updated.}} | {state, select, locked{Prédiction verrouillée.} resolved{Résultat confirmé.} canceled{Prédiction annulée.} other{Prédiction mise à jour.}} |
| `modToolsPredictionUsers` | {count, plural, one{{count} predictor} other{{count} predictors}} | {count, plural, one{{count} participant} other{{count} participants}} |
| `modToolsPredictionWindow` | Time to predict | Durée pour participer |
| `modToolsPredictions` | Predictions | Prédictions |
| `modToolsPredictionsCaption` | Let chat bet channel points. | Laissez le chat miser des points de chaîne. |
| `modToolsQuestionLabel` | Question | Intitulé |
| `modToolsRaid` | Raid a channel | Lancer un raid |
| `modToolsRaidCancel` | Cancel the raid | Annuler le raid |
| `modToolsRaidCancelMessage` | Your viewers stay here. | Vos spectateurs restent ici. |
| `modToolsRaidCancelTitle` | Cancel the raid? | Annuler le raid ? |
| `modToolsRaidMessage` | Your viewers leave for this channel once the countdown ends. | Vos spectateurs rejoindront cette chaîne à la fin du compte à rebours. |
| `modToolsRaidStart` | Start raid | Lancer le raid |
| `modToolsRaidTitle` | Raid a channel | Lancer un raid |
| `modToolsRedemptionReward` | {reward} · {cost, plural, one{{cost} point} other{{cost} points}} | {reward} · {cost, plural, one{{cost} point} other{{cost} points}} |
| `modToolsRefund` | Refund | Rembourser |
| `modToolsRefundMessage` | {name} gets back the points spent on “{reward}”. | Les points dépensés pour « {reward} » seront rendus à {name}. |
| `modToolsRefundTitle` | Refund this request? | Rembourser cette demande ? |
| `modToolsRefunded` | Request refunded. | Demande remboursée. |
| `modToolsRemove` | Remove | Retirer |
| `modToolsRemoveModerator` | Remove moderator | Retirer le rôle de modérateur |
| `modToolsRemoveTag` | Remove {tag} | Retirer {tag} |
| `modToolsRemoveTermMessage` | Messages with “{term}” will reach chat again. | Les messages contenant « {term} » pourront de nouveau apparaître dans le chat. |
| `modToolsRemoveTermTitle` | Remove this blocked term? | Retirer ce terme bloqué ? |
| `modToolsRemoveVip` | Remove VIP | Retirer le statut VIP |
| `modToolsRequestedOn` | Sent {date} | Envoyée le {date} |
| `modToolsRestrict` | Restrict | Restreindre |
| `modToolsRestrictMessage` | Only moderators will see messages from {name}. | Seuls les modérateurs verront les messages envoyés par {name}. |
| `modToolsRestrictTitle` | Restrict this user? | Restreindre cet utilisateur ? |
| `modToolsRewardQueueWeb` | Full reward queue | File complète des récompenses |
| `modToolsRewardRequests` | Reward requests | Demandes de récompenses |
| `modToolsRewardRequestsCaption` | Twitch only lets this app manage rewards created in ONSET. The full queue is on twitch.tv. | Twitch ne permet à cette application de gérer que les récompenses créées dans ONSET. La file complète est sur twitch.tv. |
| `modToolsRewardRequestsEmpty` | No requests waiting | Aucune demande en attente |
| `modToolsRoleConfirmMessage` | {change, select, addModerator{{name} will be able to moderate this chat.} removeModerator{{name} will no longer be able to moderate this chat.} addVip{{name} will get the VIP badge.} removeVip{{name} will lose the VIP badge.} other{{name}’s role will change.}} | {change, select, addModerator{{name} pourra modérer ce chat.} removeModerator{{name} ne pourra plus modérer ce chat.} addVip{{name} recevra le badge VIP.} removeVip{{name} perdra le badge VIP.} other{Le rôle changera pour {name}.}} |
| `modToolsRoleConfirmTitle` | {change, select, addModerator{Make moderator?} removeModerator{Remove moderator?} addVip{Make VIP?} removeVip{Remove VIP?} other{Change role?}} | {change, select, addModerator{Attribuer le rôle de modérateur ?} removeModerator{Retirer le rôle de modérateur ?} addVip{Attribuer le statut VIP ?} removeVip{Retirer le statut VIP ?} other{Modifier le rôle ?}} |
| `modToolsSave` | Save | Enregistrer |
| `modToolsSeconds` | {count, plural, one{{count}s} other{{count}s}} | {count, plural, one{{count} s} other{{count} s}} |
| `modToolsSectionChannel` | Your channel | Votre chaîne |
| `modToolsSectionChat` | Chat tools | Outils du chat |
| `modToolsSectionLive` | Live | En direct |
| `modToolsShieldMode` | Shield mode | Mode bouclier |
| `modToolsShieldModeDetail` | Your preset protections, in one tap | Vos protections prédéfinies, en un geste |
| `modToolsShieldModeOn` | Shield mode on | Mode bouclier activé |
| `modToolsShoutout` | Give a shoutout | Faire une dédicace |
| `modToolsShoutoutDetail` | Point chat to another channel | Faire découvrir une autre chaîne au chat |
| `modToolsShoutoutSend` | Send | Envoyer |
| `modToolsShoutoutTitle` | Give a shoutout | Faire une dédicace |
| `modToolsShoutoutUser` | Give a shoutout | Faire une dédicace |
| `modToolsShowActionsInChat` | Show mod actions in chat | Afficher les actions de modération dans le chat |
| `modToolsStreamInfo` | Edit stream info | Modifier les infos du live |
| `modToolsStreamInfoCaption` | Title, category, and tags | Titre, catégorie et tags |
| `modToolsStreamInfoSaved` | Stream info saved. | Infos du live enregistrées. |
| `modToolsStreamTitleLabel` | Title | Titre |
| `modToolsTagInvalid` | Tags can only contain letters and numbers, up to 25 characters. | Un tag ne peut contenir que des lettres et des chiffres (25 caractères au maximum). |
| `modToolsTagLabel` | Add a tag | Ajouter un tag |
| `modToolsTagLimit` | {count, plural, one{A stream can have up to {count} tag.} other{A stream can have up to {count} tags.}} | {count, plural, one{Un live peut avoir jusqu’à {count} tag.} other{Un live peut avoir jusqu’à {count} tags.}} |
| `modToolsTags` | Tags | Tags |
| `modToolsTermLabel` | Term or phrase | Terme ou expression |
| `modToolsTermTemporary` | Temporary | Temporaire |
| `modToolsTitle` | Mod tools | Outils de modération |
| `modToolsUnbanCaption` | Banned users asking to come back. | Utilisateurs bannis qui demandent à revenir. |
| `modToolsUnbanDialogMessage` | {decision, select, approved{{name} will be unbanned. You can add a note for them.} denied{{name} stays banned. You can add a note for them.} other{You can add a note for {name}.}} | {decision, select, approved{Le bannissement sera levé pour {name}. Vous pouvez ajouter une note à son intention.} denied{Le bannissement est maintenu pour {name}. Vous pouvez ajouter une note à son intention.} other{Vous pouvez ajouter une note pour {name}.}} |
| `modToolsUnbanDialogTitle` | {decision, select, approved{Approve the request?} denied{Deny the request?} other{Answer the request?}} | {decision, select, approved{Accepter la demande ?} denied{Refuser la demande ?} other{Répondre à la demande ?}} |
| `modToolsUnbanEmpty` | No unban requests | Aucune demande de débannissement |
| `modToolsUnbanNoteLabel` | Note (optional) | Note (facultative) |
| `modToolsUnbanRequests` | Unban requests | Demandes de débannissement |
| `modToolsUnbanResolved` | {decision, select, approved{Request from {name} approved.} denied{Request from {name} denied.} other{Request from {name} answered.}} | {decision, select, approved{Demande acceptée : {name}.} denied{Demande refusée : {name}.} other{Demande traitée : {name}.}} |
| `modToolsUnmonitor` | Stop monitoring | Arrêter la surveillance |
| `modToolsUnrestrict` | Lift restriction | Lever la restriction |
| `modToolsUserActionsTitle` | Mod actions | Actions de modération |
| `modToolsUserLabel` | Username | Nom d’utilisateur |
| `modToolsUserPill` | {pill, select, banned{Banned} timedOut{Timed out} warned{Warned} monitored{Monitored} restricted{Restricted} other{Flagged}} | {pill, select, banned{Bannissement} timedOut{Exclusion temporaire} warned{Avertissement} monitored{Sous surveillance} restricted{Restriction} other{Signalement}} |
| `modToolsVipCount` | {count, plural, one{{count} VIP} other{{count} VIPs}} | {count, plural, one{{count} VIP} other{{count} VIP}} |
| `modToolsVips` | VIPs | VIP |
| `modToolsVotes` | {count, plural, one{{count} vote} other{{count} votes}} | {count, plural, one{{count} vote} other{{count} votes}} |
| `overlayChatMove` | Move chat | Déplacer le chat |
| `overlayChatResize` | Resize chat | Redimensionner le chat |
| `settingsAnimateEmotes` | Animate emotes | Animer les emotes |
| `settingsAnimatedGifs` | Animated GIFs | GIF animés |
| `settingsIncreaseChatContrast` | Increase chat contrast | Augmenter le contraste du chat |
| `settingsReadableNameColors` | Readable name colors | Couleurs de pseudo lisibles |
| `settingsReadableNameColorsLocked` | Always on while chat contrast is increased. | Toujours activé tant que le contraste du chat est augmenté. |
| `settingsShowGifs` | Show GIFs in chat | Afficher les GIF dans le chat |
| `settingsTitle` | Settings | Paramètres |
| `viewerActionResult` | {status, select, done{Done.} refused{Twitch declined this.} integrityRefused{Twitch’s anti-bot check refused this. Connect a Twitch session in Settings › Account, then try again.} signedOut{Log in again to do this from ONSET.} other{Couldn’t reach Twitch. Try again.}} | {status, select, done{C’est fait.} refused{Twitch a refusé.} integrityRefused{Le contrôle anti-robot de Twitch a refusé cette action. Connectez une session Twitch dans Paramètres › Compte, puis réessayez.} signedOut{Reconnectez-vous pour le faire depuis ONSET.} other{Impossible de joindre Twitch. Réessayez.}} |

## Network and data

**Sockets**
- Twitch IRC: `wss://irc-ws.chat.twitch.tv:443`. On open send, in order: `CAP REQ :twitch.tv/tags twitch.tv/commands`, `PASS oauth:<token>` (user token, or the app token when logged out), `NICK <login>` (logged out: `justinfan888`), `JOIN #<channel login>`. Reply `PONG :tmi.twitch.tv` to `PING :tmi.twitch.tv` immediately (bypasses delay). Send: `[@reply-parent-msg-id=<id> ]PRIVMSG #<channel> :<text>`. Watchdog: 90 s silence → send `PING :tmi.twitch.tv`; 10 s more silence → close(4000). Reconnect: max 5 retries; delays 0, 1, 2, 4, 8 s (cap 8); then manual. Close codes used: 1000 (normal: logout/login, /disconnect, dispose), 4000 (watchdog).
- 7TV EventAPI: `wss://events.7tv.io/v3`. Subscribe frames `{"op":35,"d":{"type":T,"condition":C}}`: `emote_set.update {object_id: <set id>}` (channel set, plus each personal set first seen, ≤ 100 sets), `user.update {object_id: <7TV user id of the channel>}`, and when any 7TV cosmetic setting is on `cosmetic.create`, `entitlement.create`, `entitlement.delete` with `{ctx: "channel", platform: "TWITCH", id: <twitch channel id>}`. Only `op == 0` dispatches are handled. Watchdog 75 s silence → close(4000). Reconnect backoff `min(60, 2^min(attempt,6))` s × jitter 0.5–1.0; the attempt counter resets after 60 s connected.
- BTTV: `wss://sockets.betterttv.net/ws`; send `{"name":"join_channel","data":{"name":"twitch:<channel id>"}}`; handle `emote_create` / `emote_update` / `emote_delete` for `data.channel == "twitch:<id>"` and `lookup_user` (Pro personal emotes); reconnect with the same backoff (counter reset on every frame); no watchdog.
- EventSub (shared client outside this area, topics requested here): `channel.chat.user_message_update` v1 `{broadcaster_user_id, user_id}` (held-message decisions for the viewer, scope `user:read:chat`); moderators: `channel.moderate` v2, `channel.shield_mode.begin` v1, `channel.shield_mode.end` v1, `automod.message.hold` v2, `automod.message.update` v2, all with `{broadcaster_user_id, moderator_user_id}`.

**HTTP (Helix base `https://api.twitch.tv/helix`, user or app token + Client-Id; all services extend `BaseApiClient`)**
- Assets: `GET /chat/emotes?broadcaster_id=`, `GET /chat/badges?broadcaster_id=`, `GET /bits/cheermotes?broadcaster_id=`, `GET /chat/emotes/user?user_id=&broadcaster_id=` (scope `user:read:emotes`), `GET /chat/emotes/set?emote_set_id=`, `GET /users?id=…` / `?login=`, `GET /shared_chat/session?broadcaster_id=`, `GET /chat/color?user_id=`, `PUT /chat/color?user_id=&color=`, `PUT|DELETE /users/blocks` (via the user store), `POST /whispers` (via WhisperStore).
- Moderation: `POST /moderation/bans`, `DELETE /moderation/bans`, `POST /moderation/warnings`, `DELETE /moderation/chat[?message_id=]`, `PATCH /chat/settings`, `POST /chat/announcements`, `POST /chat/shoutouts`, `GET|POST|DELETE /moderation/moderators`, `GET|POST|DELETE /channels/vips`, `GET|PUT /moderation/shield_mode`, `POST /streams/markers`, `POST /channels/commercial` (30–180 s), `POST|DELETE /raids`, `POST|DELETE /moderation/suspicious_users` (`ACTIVE_MONITORING` / `RESTRICTED`), `GET /moderation/banned`, `POST /moderation/automod/message` (`ALLOW`/`DENY`), `GET|POST|DELETE /moderation/blocked_terms`, `GET|PATCH /moderation/unban_requests` (status pending; approved/denied + `resolution_text` ≤ 500), `GET|POST|PATCH /polls` (end = `TERMINATED`), `GET|POST|PATCH /predictions` (`LOCKED`/`CANCELED`/`RESOLVED` + `winning_outcome_id`), `GET /channel_points/custom_rewards?only_manageable_rewards=true`, `GET /channel_points/custom_rewards/redemptions?status=UNFULFILLED&sort=OLDEST` (≤ 2 pages per reward), `PATCH /channel_points/custom_rewards/redemptions` (`FULFILLED`/`CANCELED`), `GET|PATCH /channels?broadcaster_id=`, `GET /search/categories?query=`. Many mod calls are "quiet" (no global 401 dialog).
- Token scopes: `GET https://id.twitch.tv/oauth2/validate` → `scopes`.
- 7TV REST `https://7tv.io/v3`: `GET /users/twitch/<id>` (channel set id, 7TV user id, emotes), `GET /emote-sets/<id>`, `GET /emote-sets/global` (global store); cosmetics via `https://7tv.io/v4/gql` (global service, batched).
- BTTV REST `https://api.betterttv.net/3/cached`: `GET /users/twitch/<id>`, `GET /emotes/global`, `GET /badges`. FFZ `https://api.frankerfacez.com/v1`: `GET /room/id/<id>`, `GET /set/global`, `GET /badges/ids`.
- Twitch GQL `https://gql.twitch.tv/gql` (POST, `Client-ID: kimne78kx3ncx6brgo4mv6wki5h1ko`):
  - `ChatHistory` with `Authorization: OAuth <twitch.tv web token>`, no redirects, 4 s timeout, ≤ 200 newest messages, variables `{channelLogin (lowercased), channelID}`, query:
    `query ChatHistory($channelLogin: String!, $channelID: ID) { channel(name: $channelLogin) { recentChatMessages { id sentAt deletedAt content { text fragments { text content { __typename ... on Emote { id } ... on CheermoteToken { bitsAmount } ... on GifContent { id url } } } } sender { id login displayName chatColor } senderBadges(channelID: $channelID) { setID version } senderChatColor sourceChannel { id } parentMessage { id content { text } sender { id login displayName } } threadParentMessage { id sender { id login displayName } } } } }`. Inputs validated (`^[a-zA-Z0-9_]{1,25}$`, `^[0-9]{1,20}$`); any error → empty.
  - `ChatRules` anonymous: `query ChatRules($userID: ID!) { user(id: $userID) { id displayName profileImageURL(width: 150) chatSettings { rules } } }`.
  - Viewer actions (web token): pin/unpin message, set lead moderator, acknowledge warning, GIF picker config, send GIF, select badge, hide sub flair; community: shoutout profile, chat identity, Guest Star session, costreamers (all in services outside this area; outcomes `done/refused/integrityRefused/signedOut/failed`).
- Third-party history: `GET https://recent-messages.robotty.de/api/v2/recent-messages/<login>` → `{messages: [raw IRC strings]}`.
- GIPHY: `https://api.giphy.com/v1/gifs/search|trending?api_key&limit=24&offset=0&rating[&q≤50 chars]`.
- Web pages opened in-app (`TwitchWebPage`): `https://www.twitch.tv/popout/<login>/chat`, the subscribe page (`twitchSubscribeUrl`), `https://www.twitch.tv/popout/<login>/reward-queue`, `https://dashboard.twitch.tv/u/<login>/settings/moderation/blocked-terms`, `https://www.twitch.tv/moderator/<login>`, `https://www.twitch.tv/settings/security`.

**IRC tags read**: `id`, `tmi-sent-ts`, `historical` (ONSET's own marker), `source-room-id`, `user-id`, `display-name`, `msg-id`, `msg-param-recipient-id`, `emote-sets`, `ban-duration`, `target-user-id`, `target-msg-id`, `login`, `flags` (AutoMod ratings), `badges`, `badge-info`, `color`, `bits`, `reply-parent-*`, `reply-thread-parent-*`, `mod`, `subscriber`, `vip` (USERSTATE). ROOMSTATE fields: `emote-only`, `followers-only` (−1 off, 0 any, N minutes), `r9k`, `slow` (seconds), `subs-only`.

**Persistence**: SharedPreferences (`recent_emotes`, `chat_rules_accepted_*`), SettingsStore JSON (keys above), secure storage (extra scopes). No local message persistence.

## Tested behaviour

Behavioural oracle — every test file of the area and what it asserts:
- `test/screens/channel/chat/chat_banner_a11y_test.dart` — Shared Chat banner names the partner channels; joining an already-shared chat says it is shared (not "started"); screen reader hears chat expand/collapse announcements; chat notifications are read as they appear.
- `test/screens/channel/chat/chat_commands_test.dart` — plain text and `/me` are SendAsIs; `/color` names and hex; `/block` `/unblock` one login; help, whispers, moderator and unknown commands; `/ban` user + optional reason; `/timeout` length parsing with 10 min default; `/unban` `/untimeout`; `/warn` needs a reason; `/delete` id, `/clear` no args; room modes; moderator commands suggested to moderators only; suggestions while typing the name; `/user` one login, `/disconnect` nothing.
- `test/screens/channel/chat/chat_commands_mod_test.dart` — announce colours keep one line; shoutout/raid/roles take one login; shield/marker/commercial; monitor/restrict and opposites; only owner commands named broadcaster-only; moderators get new commands, viewers not; `/pin` refused as not in app.
- `test/screens/channel/chat/lead_mod_command_test.dart` — `/leadmod` `/unleadmod` parse one user, are broadcaster-only and suggested to moderators; broadcaster adds/removes; a moderator is told only the broadcaster can; refusal and missing web session are worded.
- `test/screens/channel/chat/moderation_test.dart` — `/ban` looks up the login then bans; known id skips lookup; unban/untimeout; warn/delete/clear; room modes change only their field; failures: offline, unknown login, Twitch refusal, not a moderator / missing scopes, unknown login named in the log; French wording of failure kinds and quoting rules (no quote without Twitch words or for long text); anything else never escapes.
- `test/screens/channel/chat/moderation_channel_commands_test.dart` — moderator announces and shouts out; moderator told owner commands aren't theirs; owner raids, adds roles, lists them; role list cut after 30 names; shield/ad/marker outcomes; monitor/restrict name the user; missing scope asks to log in, refusal says why; every new command has a failure name.
- `test/screens/channel/chat/moderation_notice_test.dart` — timeout lines say the length like Twitch; ban is permanent; whole clear / odd target → no line; name as shown in chat; length wording; notice line keeps Twitch time, history mark, stable id; blocked target → none; newest name wins (buffer before history); other-script name keeps login; unreadable duration still a timeout.
- `test/screens/channel/chat/server_notice_test.dart` — every `msg_` notice refuses the pending message, command answers/mode changes do not; each refusal worded per language; every Twitch refusal has a sentence; followers-only asks to follow; removed IRC command replies keep Twitch text; numbers read from Twitch text; unexpected shape/unknown id keep Twitch text.
- `test/screens/channel/chat/chat_restrictions_test.dart` — nothing in an open chat; ban/timeout first and lock input; slow mode waits except privileged; room modes inform without locking; only the viewer's own CLEARCHAT counts; timeout counts from Twitch send time, history ignored; waits read like a clock; account/channel refusals each named, shown after ban/timeout and before room modes, worded per language with verification link.
- `test/screens/channel/chat/chat_filters_test.dart` — flags tag parsing (ranges, levels, skipping unreadable); level ≥ 3 hidden when its filter is on; master switch off hides nothing; per-category switches; masking end-inclusive with spaces kept; null when nothing hidden; positions count code points (emoji = 1); emoji inside kept; invalid ranges dropped; overlapping range skipped; mark never in the text; 100-range cap.
- `test/screens/channel/chat/muted_words_test.dart` — substring mode case-insensitive inside words; whole-word mode ignores parts and punctuation; blank entries never match; punctuation entries (bot commands, links) still match whole.
- `test/screens/channel/chat/chat_delay_queue_test.dart` — release after delay; order kept when delay shrinks; shrinking delay releases due items at once; growing delay holds; zero/negative delay releases all; flushAll order and clear drops; a payload enqueued during a flush is kept for later.
- `test/screens/channel/chat/chat_history_test.dart` — history line equals the live IRC line (emotes, badges, colour); historical mark; deleted shown deleted; blocked dropped by id or login; no usable sender dropped; muted dropped; oldest first; hostile text cannot forge tags/lines/sender; cheers sum to `bits`; GIF keeps its place, allowed host only; replies carry reply tags and @name; reply without parent text is plain; Shared Chat source; mentions highlighted; moderator line carries `mod=1`; `/me` rendered as action; thread parent with bad login omitted; `newHistoryLines` drops shown and repeated.
- `test/screens/channel/chat/chat_history_layout_test.dart` — history landing above keeps the view still (pinned and at each place), including while scrolled up.
- `test/screens/channel/chat/emote_entitlements_test.dart` — own subs and received gifts change emotes; set changes only on real set differences; animated emote detection by word.
- `test/screens/channel/chat/gift_bomb_tracker_test.dart` — header and every gift shown by default; bomb described from header; anonymous marked; collapsed hides gifts after a shown header but shows gifts arriving first; keys by origin id; single gifts never hidden; remembers 100 bombs, keeps active ones; collapse only from 5, decided at the header; recipients ordered, capped (every gift still counted); a gift before its header is shown but NOT counted (received stays 0); `watch` follows gifts, same listenable on repeated header, none for unknown/forgotten; malformed counts never collapse/banner/negative; banner rules (live ≥ 5, not 4, not history, not another shared channel, not a gift); `bannerDuration` thresholds; shared-chat partner bombs collapse too.
- `test/screens/channel/chat/held_messages_test.dart` — subscribes the viewer's held-message topic; says the decision; quote on one short line; keeps emoji/script joiners when cutting; other viewers/unknown statuses silent, odd text omitted; non-numeric ids refused; dispose releases the topic.
- `test/screens/channel/chat/incoming_raid_test.dart` — live raid on this channel yields who/avatar/viewers; history or other shared channel → no pin; non-raid → none; non-https or non-Twitch picture dropped; never negative viewers.
- `test/screens/channel/chat/overlay_chat_placement_test.dart` — moving stays on screen; resizing keeps ≥ 30 % and stays on screen; out-of-range saved values made safe; drag end half picks the side.
- `test/screens/channel/chat/overlay_chat_frame_test.dart` — chat takes its saved share of height; drag down, resize, switch side; no handles while controls hidden.
- `test/screens/channel/chat/chat_emote_panel_test.dart` — tablet opening settles on the panel; RTL nub points at the mirrored button; phone always inline.
- `test/screens/channel/chat/chat_keyboard_test.dart` — opening the keyboard rebuilds no chat row; after Reply the resume button and scrollbar clear the reply bar.
- `test/screens/channel/chat/chat_overlay_tap_test.dart` — with the setting on, tapping overlay chat hides it; off, it stays; chat beside video never closes.
- `test/screens/channel/chat/chat_row_cache_test.dart` — unchanged rows reused on new lines; deleted line redraws; ban then longer timeout each redraw; late emote set redraws; settings change redraws; hidden tab builds no rows until shown.
- `test/screens/channel/chat/chat_shoutout_card_test.dart` — shoutout opens its card and Profile opens the user card; without the service the user card opens directly.
- `test/screens/channel/chat/chat_user_card_test.dart` — a `/user` request opens that user's card from the shown chat.
- `test/screens/channel/chat/points_intro_test.dart` — covers the channel-points intro widget (`widgets/points_intro.dart`, specified with the widgets leaf) and the Chat settings entry that brings it back: intro dismiss/learn-more, explainer content in EN and FR, "Show the channel points intro again" resets `pointsIntroSeen`, new-feature pill until used. Listed here because it lives in this test folder.
- `test/screens/channel/chat/details/chat_details_test.dart` — menu golden at sizes/brightness; moderator gets chat modes with active ones on top; logged out hides colour/points/subscribe; chat-only flips video and closes; sleep timer in place and back; back returns to menu then closes; colour current ticked and Save sends; throwing save keeps the pick and frees Save; rules in place with back; preference switches; readable colours locked while contrast increased; animated GIFs wait for GIFs; add chat callback; reduce motion cross-fades.
- `test/screens/channel/chat/details/chat_mode_controls_test.dart` — switches mirror the room; turning on sends the chosen length; throwing change reported and switches freed; off sends no length; new follow age applies at once while on; tap on a mode title changes nothing; refused length reverts; clear asks first; 56 dp rows, red clear row, no overflow.
- `test/screens/channel/chat/details/chat_modes_tooltip_test.dart` — tapping a pill explains the mode; followers-only with no wait says just that.
- `test/screens/channel/chat/details/chat_users_list_test.dart` — filter ring and Cancel follow focus; long list filtered once per build.
- `test/screens/channel/chat/emote_menu/emote_menu_test.dart` — phone tabs, set pills, 8-column grid (both themes); clearing recents shows the empty state; another channel's sub emote greyed with explanation; tablet 376×372 panel with 6 columns; taps in a sheet opened from the panel don't close it; closed draws nothing.
- `test/screens/channel/chat/emote_menu/emote_menu_section_test.dart` — each cell is read by its name.
- `test/screens/channel/chat/emote_menu/emote_menu_unlock_test.dart` — locked sub emote explains unlocking; follower emotes come with the note; animated mark and label; one recent emote removable; limited-time emote says so in details.
- `test/screens/channel/chat/emote_menu/gif_picker_panel_test.dart` — confirmed GIF sent and menu closes; typing searches after a pause; loading line over old results; cooldown says how long; non-sender sees why + Subscribe; no config → message; GIPHY failure message.
- `test/screens/channel/chat/mod_tools/mod_events_test.dart` — timeout keeps target, reason, end; few-ms-short timeouts read whole minutes; mode/term/unban-request actions as sentences; unknown/shared/malformed dropped; timeout without end reads; held message and update; shoutout of this channel read, others dropped.
- `test/screens/channel/chat/mod_tools/mod_tools_store_test.dart` — login asks every mod scope; moderator subscribes topics as themselves; pre-mod-tools login asked to log in again; unreadable scopes leave tools off; mod action → chat line + log; malformed event costs only itself; shield follows events and is said once; shield on via Helix; held message waits, announced, resolved; IRC bans/timeouts mark the user; owner reads ban from Helix, moderator never asks; statuses bounded, latest kept; stop cancels and forgets; held message queued once.
- `test/screens/channel/chat/mod_tools/mod_tools_sheets_test.dart` — hub shows live/chat tools to moderators and channel tools to the owner; missing scopes → log in again; shield switch via Helix; raid asks channel then confirmation; ad break confirmed with length; AutoMod allow and clear; removing a moderator confirmed; announcement with colour; ending a poll; new poll needs question + two choices; locked prediction resolved after confirmation; refund confirmed then removed; unban approved with note; short blocked term refused locally; stream info saves title/category/tags; card shows Twitch status; restricting from the card confirmed; shield pill visible while on; stream info load failure offers Retry not Save; title-only change never sends tags; blocked term removal confirmed; adding a moderator by name confirmed; locking a prediction confirmed.
- `test/screens/channel/chat/stores/chat_assets_store_cosmetics_test.dart` — 7TV badge/paint/personal emotes looked up per chatter; nothing when all off; turning one off forgets only it; regranting same notifies nobody; revoked entitlement removes; personal set entitlement loads set; personal set change updates every owner; BTTV Pro follows toggle; channel emotes renamed/removed/swapped by set; 7TV set switch replaces 7TV channel emotes; FFZ room badges follow toggle; badge map observable; per-user cosmetics keep most recent chatters; room FFZ user badges come from the catalog.
- `test/screens/channel/chat/stores/chat_assets_store_user_emotes_test.dart` — menu gets every usable emote by channel; token without scope falls back; unnamed channel still sectioned; failed name lookup keeps emotes; ended shared chat clears channels; reloading keeps one copy (Helix and fallback).
- `test/screens/channel/chat/stores/chat_rules_store_test.dart` — logged-in never-accepted viewer must see rules; acceptance remembered per viewer+channel; nothing when logged out / no rules / before load; failing query shows nothing and is asked once; focusing the input opens the rules; closing without accepting asks again; sends without focus are gated too.
- `test/screens/channel/chat/stores/chat_store_delay_test.dart` — held chat survives a dropped connection; held deletion still deletes after a drop; bypass lines leave a shared frame while held lines stay; PING answered at once while held.
- `test/screens/channel/chat/stores/chat_store_emotes_test.dart` — animated callout once, never with animations off; USERSTATE set change reloads once; own sub/gift reloads; without Helix the latest USERSTATE sets are read; logged out asks nothing; Shared Chat banner shows once for a while, not "started" when already shared, partners cleared when unshared, dismissible.
- `test/screens/channel/chat/stores/chat_store_history_test.dart` — asks Twitch with web token for this channel; nothing without token; IRC connects at once; history on top in one go, oldest first, live after; no duplicates either direction; deleted history arrives deleted; blocked excluded; recent-messages fallback rules (setting on + no token / empty / failed / throwing; never if Twitch answered or setting off), its lines on top too; history triggers no live effects; history after close dropped; reply never sends non-id-shaped id; recent-messages strings split into lines and cannot unmark themselves; unexpected failures caught; live moderation before history applies (timeout marks, deletion deletes, clear stays cleared); recent-messages gift bombs fold and their live copies stay out, already-counted gifts not recounted, its own timeouts/deletions apply.
- `test/screens/channel/chat/stores/chat_store_mod_tools_test.dart` — shoutout said once and opens the card; `/mods` lists moderators with a View list action; `/leadmod` asks first, names the user, stops when declined; owner's chat starts mod tools, viewer's not; CLEARCHAT marks the user for the card.
- `test/screens/channel/chat/stores/chat_store_moderation_redraw_test.dart` — deletions/timeouts/bans redraw in a quiet chat without a new message; ban wave of absent users redraws nothing; of present users at most once per flush; repeated identical timeout redraws nothing.
- `test/screens/channel/chat/stores/chat_store_notices_test.dart` — each refusal id stops sending immediately, text kept; verified-phone refusal shows its bar; warning shows acknowledge bar, goes after acknowledgement, double acknowledge ignored, refusal keeps bar, no web token sends nothing, no warning sends nothing; channel suspended on join is not a refused send; follow-to-chat goes when followers-only off; server notice in the on-screen language; own deleted message said with text, others/replayed not; gift subs shown by default, hidden when the viewer hides them; `/user` opens the card or says no such user; `/disconnect` closes to reconnect.
- `test/screens/channel/chat/stores/chat_store_raids_test.dart` — live raid on this channel handed to the pin, replayed not; local notice joins chat, none after dispose, can carry an action; raid welcome right after joining, once; local notice waits like chat when delayed, and is fine released outside an action; recent messages count as history (no raid pin); already-marked history left as is.
- `test/screens/channel/chat/stores/chat_store_socket_watchdog_test.dart` — silent IRC socket pinged at 90 s then closed after 10 s and reopened once (no duplicate socket); a reply keeps it open; silent 7TV socket closed (4000) and reopened; a 7TV hello does not reset backoff, a healthy minute does; lines wait in background and show at once on resume.
- `test/screens/channel/chat/stores/chat_store_third_party_live_test.dart` — 7TV socket follows set, channel user and cosmetics (only emotes when cosmetics off); adds/renames/removals reach chat (silently with notices off); personal set changes go to that user; channel set switch swaps emotes and says so; other user's update ignored; cosmetics/entitlements go to assets; chatters handed to cosmetics lookup; BTTV joins channel, add/rename/remove reach chat, Pro user to personal emotes, BTTV updates wait for the delay; BTTV off closes socket, no BTTV channel → no socket, back on reopens; cosmetic settings handed to assets and followed; dropped 7TV reconnects with growing capped delay, healthy minute resets; dropped BTTV reconnects and rejoins; nothing reconnects after dispose or with provider off; dispose closes both.

## Wide and tablet layout

Tablet = `context.isLargeScreen`; these variants become the PC layout:
- **Emote menu as a floating panel** (376 × 372) above the input, anchored to the emote button with a nub, 10 px gap, kept inside the chat column and away from `PanelAvoidScope` regions; closes on any tap outside the panel and the input (but not on taps inside sheets it opened) and when the input gains focus; falls back to the inline menu when it cannot fit (re-checked after each layout: rotation, video toggle). Panel tab row 48 px, tab spacing 20, pill padding top 10, grid 6 columns × 54 px, cell padding 6.
- **Sheets become panels**: mod tools sub-views (`panel: true`), the shoutout card (max width 560), and every `showOnsetSheet(panel: true)`; the chat details opens from the tablet chat header instead of the "⋯" beside points.
- **Landscape**: with `landscapeForceVerticalChat` off, no bottom safe padding; emote grid 6 columns beside the video, 16 when chat-only; inline menu ½ screen tall.
- **Overlay chat** (fullscreen/landscape overlay mode): `OverlayChatFrame` placement fractions and left/right side, grips only while controls show, tap-to-close when enabled.
- **Merged multi-tab view** is the natural wide-screen mode (all channels in one list, source channel shown per line).

## PC equivalent

Rust + Slint mapping (Windows first; macOS/Linux later). Nothing is dropped; touch gestures get mouse/keyboard equivalents.
- **Architecture**: one `ChatSession` actor per tab (tokio task) owning the IRC `tokio-tungstenite` socket, 7TV and BTTV sockets, `ChatDelayQueue` (`VecDeque<(Instant, Payload)>`), timers (`tokio::time`), and state mirrored to the UI through a Slint model (`VecModel<ChatLine>` for messages, observable properties for `auto_scroll`, `restriction`, `notification`, etc.). The 200 ms flush becomes a periodic tick that batches model updates. MobX computed values become derived getters recomputed on the relevant events. `ChatTabsStore` → `ChatTabs` owning sessions; merged view = k-way merge by `tmi-sent-ts`, dedupe by id, last 100, snapshot while scrolled up.
- **Persistence**: SharedPreferences keys → a JSON settings file in `%APPDATA%\ONSET\` (same key names: `recent_emotes`, `chat_rules_accepted_<viewer>_<channel>`, settings keys); secure storage → Windows Credential Manager (`keyring` crate).
- **Input & keyboard**: Enter sends, Shift+Enter is not a newline (single-line chat); Up/Down navigate autocomplete chips (emotes, `@mentions`, `/commands`), Tab/Enter accepts (mirrors `addEmote(autocompleteMode)`); Esc closes in order: emote panel → reply bar → input focus → overlay chat (if tap-to-close) — mirroring the tap priority; Ctrl+E (or the emote button) toggles the emote panel; Ctrl+Shift+R reconnect (details "Reconnect"); End or clicking "Resume scroll" jumps to newest; PageUp/PageDown scroll the chat; Ctrl+Tab / Ctrl+Shift+Tab switch chat tabs, Ctrl+T add chat, Ctrl+W deactivate/remove secondary tab, Ctrl+M toggle merged mode; drag tabs to reorder (primary pinned first).
- **Mouse/hover**: hovering a message shows reply/copy/mod actions (touch long-press equivalents in the row leaf); hover on emote cells shows a tooltip with the name (replaces semantics labels) and right-click opens emote details (= long press); right-click on recent emote → "Remove from recent"; mode pills show their explainer on hover as well as click; overlay chat grips become a draggable title strip and a bottom-edge resize handle with resize cursor; side snapping on drop by pointer x vs window midpoint.
- **Scrolling**: wheel scrolling sets `auto_scroll=false` when not at bottom; new lines go to the buffer, "N new messages" button shown — identical semantics.
- **Haptics** → none on PC; replace heavy-impact rejection feedback with a brief red flash of the input border plus the notification.
- **Notifications above chat** → in-window toast with 5 s timeout; background mention alerts → Windows toast notifications (`winrt-notification`).
- **Wakelock** (`keepScreenAwake`) → `SetThreadExecutionState(ES_DISPLAY_REQUIRED | ES_CONTINUOUS)` while a chat window is open.
- **Web pages** (`TwitchWebPage`: popout chat, subscribe, reward queue, dashboard blocked terms, Mod View, security settings) → embedded WebView2 window (fallback: system browser).
- **Screen reader announcements** (chat expand/collapse, live region for Shield pill, notifications) → Slint accessibility properties / UIA live regions.
- **Reduce motion** → read Windows "Show animations" (`SPI_GETCLIENTAREAANIMATION`) plus the app setting; apply the same 150 ms fade rule.
- **Sleep timer** → closes the stream window / returns to home after the duration (same 16 presets).
- **i18n** → keep ARB keys; convert to Fluent with identical IDs and ICU plural/select semantics; EN and FR shipped.

### Known Android defects

Real bugs found in the Android code. The PC port must not copy them; each entry gives what Android does and the PC fix.
1. **7TV reconnect reverts to the old emote set.** Android: `listenToSevenTVEmoteSet.onDone` retries with the set id captured when that socket opened. After the broadcaster switches sets (`user.update` → `_switchSevenTvSet` updates `_sevenTvActiveSetId` and the assets, but does not reopen the socket), a dropped socket reconnects with the OLD id. `_sevenTvActiveSetId` reverts while `assetsStore.sevenTvEmoteSetId` keeps the new one, and updates to the real set go to `applyPersonalEmoteSetChange`, which drops them (no owners). PC fix: reconnect with the current active set id.
2. **Live edits to personal 7TV sets are lost after a resubscribe.** Android: every `listenToSevenTVEmoteSet` clears `_sevenTvSubscribedSets` and resubscribes only the channel set. This happens on reconnect, on a cosmetics toggle, and on any of the 7 provider settings. `onPersonalEmoteSetSeen` fires only on a set's first sighting, so earlier personal sets are never subscribed again. PC fix: on every (re)connect, resubscribe every known personal set id (`sevenTvPersonalSetIds`, up to 100).
3. **One failed lookup aborts the `userEmotesFuture` fallback.** Android: an uncaught `getUser(id: ownerId)` failure aborts the whole fallback. No sections are built, later emotes are not added to `userEmoteToObject`, and the error is an uncaught async error (unawaited). PC fix: catch per owner and use the `Other Channels` section, as the Helix path does.
4. **Blocked-user filter: case-sensitive live, case-insensitive in history.** Android: live lines are dropped only when `user == blockedUser.userLogin` exactly (case-sensitive, no id check). History and recent-messages lower-case logins and also match `user-id`. PC fix: compare lowercase logins and user ids on both paths.
5. **`dispose()` does not clear the BTTV delay queue.** Android: the chat and 7TV queues are cleared, `_pendingBttvCallbacks` is not; held BTTV closures stay referenced (harmless because nothing flushes after dispose). PC fix: drop all three queues on close.
6. **`ChatDetailsStore.filteredUsers` is case-sensitive.** Android: the chatters filter does `login.contains(filterText)` on lowercase logins without lowercasing the typed text, so "Foo" finds nothing. PC fix: lowercase (and trim) the filter text.
7. **`ChatModeControls` resets the picker on any rebuild.** Android: `_readDurations()` runs in every `didUpdateWidget` (each ROOMSTATE and each parent Observer rebuild). While a mode is ON, a new pick sends the change, but any rebuild before the confirming ROOMSTATE resets the dropdown to the room's old value. The dropdown flickers back, and if that ROOMSTATE never comes it shows the old value while Helix applied the new one. While the mode is OFF the pick is kept, because nothing is read for an inactive mode. PC fix: re-read only when the room's value actually changes, and keep a pending pick until it is confirmed.
8. **`ChattersList._open` has an unhandled error.** Android: a failed `getUser(userLogin)` (network error, renamed or banned account) throws inside the tap handler. The error is unhandled and nothing is shown. PC fix: catch it and show an error toast (e.g. reuse `chatUserCardFailed(login)` / `chatUserCardNoUser(login)`).

9. **A locked Recent emote never offers Subscribe.** Android: `RecentEmotesPanel` calls `showEmoteDetails` without `locked`, so a locked twitchChannel emote opened from Recent shows no Subscribe action, while the same emote from its section does. PC fix: pass `locked` (the panel already computes it).
10. **User-card role rows do not update after a change.** Android: `UserCardModActions` gets `isModerator` / `isVip` as fixed values. After "Make moderator" succeeds, the row still says `modToolsMakeModerator` and grants again on tap, until the sheet is reopened. PC fix: keep local role state and flip it when `outcome.ok`.
11. **RoleListSheet add field.** Android: Add stays enabled while busy (`ModAddField` has no `enabled: !busy`, and `_change` ignores `busy`). Any `@` is stripped, not only a leading one. The login is never validated, so a malformed name fails only at the Helix lookup. PC fix: disable while busy, strip only a leading `@`, validate `^[a-zA-Z0-9_]{1,25}$` before confirming.
12. **AnnounceSheet re-entry and stale status.** Android: `_send` sets busy without clearing the previous status line and has no busy guard of its own. PC fix: use the `runModAction` pattern (return if busy, clear the status at start).
13. **StreamInfoSheet category and title.** Android: there is no way to clear the category (only picking a search result sets `_gameId`). The baseline title is raw while the field is compared single-lined, so titles with stray whitespace or control characters enable Save with no edit. PC fix: add a "No category" choice that sends `game_id: ""`, and store the baseline as `singleLine(channel.title)`.
14. **ChattersList not live.** Android: the chatters count and rows refresh only on a rebuild (filter typing, pull-to-refresh, reopening); new chatters arriving while the sheet is open do not appear. PC fix: notify the model when `chatUsers` grows, throttled (e.g. every 1 s).

## Per-file reference

### lib/screens/channel/chat/chat_delay_queue.dart

`ChatDelayQueue` — the FIFO that holds incoming chat payloads so chat lines up with a video that runs behind live (the "chat delay sync" feature). Pure Dart, no Flutter dependency, fully deterministic (time is always passed in).

Data: a private `List<_Delayed> _pending`; `_Delayed` is an immutable pair `(DateTime arrivedAt, void Function() callback)`. A "payload" is an arbitrary closure (in `ChatStore` it is the closure that applies one parsed IRC frame, a 7TV event or a BTTV event, or adds a local notice).

API and exact semantics:
- `bool isEmpty` — `_pending.isEmpty`.
- `add(callback, {required DateTime now})` — appends `_Delayed(now, callback)`. The arrival time is stored; the delay is NOT read at arrival.
- `flushDue(DateTime now, Duration delay)` — `cutoff = now - delay`. Walks from the head counting entries whose `arrivedAt` is NOT after `cutoff` (i.e. `arrivedAt <= cutoff`, inclusive boundary: a payload that arrived exactly `delay` ago is due). Stops at the first entry that is not yet due (strict FIFO). If zero are due, returns without doing anything. Otherwise the due prefix is copied out and removed from `_pending` BEFORE any callback runs (a callback may enqueue more payloads; they must neither run in the same flush nor corrupt the iteration), then callbacks run oldest first.
- Because the delay is read at flush time, a shrinking delay (the video caught up with live) makes everything now due leave at once, oldest first; a growing delay just holds things longer. A later message never overtakes an earlier one, so a deletion (CLEARMSG) or timeout (CLEARCHAT) can never reach the chat before the message it acts on.
- `flushAll()` — no-op when empty; otherwise copies the list, clears it, then runs every callback in arrival order (used when the delay is switched off, becomes 0, or the video is hidden).
- `clear()` — drops everything without running anything (the store is disposed).

Rust mapping: `VecDeque<(Instant, Payload)>`; same inclusive cutoff, drain-prefix-then-run rule. Oracle: `test/screens/channel/chat/chat_delay_queue_test.dart` and `test/screens/channel/chat/stores/chat_store_delay_test.dart`.

### lib/screens/channel/chat/muted_words.dart

Top-level function `bool isMuted(String message, Iterable<String> mutedWords, {required bool wholeWord})` used by the chat store (live lines, recent-messages history) and `chatHistoryLines` to hide messages containing muted words (settings `mutedWords` list and `matchWholeWord` toggle).

Module-level constants:
- `_wordBreak = RegExp(r'[\s.,!?;:"()\[\]{}<>]+')` — whitespace and the punctuation set `. , ! ? ; : " ( ) [ ] { } < >` (one or more).
- `_wordChar = RegExp(r'[a-z0-9_]')`.
- `_phrases` — a process-wide cache `Map<String, RegExp>` keyed by the normalized muted entry (memoized phrase regexes, never evicted).

Algorithm:
1. `text = message.toLowerCase()`.
2. For each raw muted entry: `muted = raw.trim().toLowerCase()`; empty → skipped (blank entries never match).
3. `wholeWord == false`: plain substring test `text.contains(muted)` → true.
4. `wholeWord == true`:
   - The message is split once (lazily, only when first needed) on `_wordBreak` into a `Set` of words.
   - If the muted entry itself contains a break character (a phrase like `bad word`, or punctuation like `!sr`, `twitch.tv`, `:D`), it is matched as a whole with the regex `(^|BEFORE)ESCAPED($|AFTER)`, where BEFORE is the break class `[\s.,!?;:"()\[\]{}<>]` if the entry's FIRST char is a word char (`[a-z0-9_]`), otherwise just `\s`; AFTER likewise from the LAST char. So `!sr` must be preceded by the start or whitespace (`hey!sr` does not match), while `twitch.tv` may follow punctuation (`(twitch.tv)` matches).
   - Otherwise (a single word): `words.contains(muted)`.
5. First match → true; none → false.
Case-insensitivity uses `toLowerCase`; `_wordChar` only recognises ASCII letters/digits/underscore, so an entry starting with an accented letter uses the `\s` boundary. Oracle: `test/screens/channel/chat/muted_words_test.dart`.

### lib/screens/channel/chat/emote_entitlements.dart

Three pure predicates the chat store uses to decide when to refresh the viewer's own emote sets and when to show the animated-emotes callout.

- `bool changesOwnEmotes(IRCMessage message, {required String? ownUserId})` — false if `ownUserId == null`, the message is not `Command.userNotice` (USERNOTICE), or it is replayed history (`tags['historical'] == '1'`). Otherwise switch on `tags['msg-id']`:
  - `sub`, `resub`, `extendsub`, `giftpaidupgrade`, `anongiftpaidupgrade`, `primepaidupgrade` → true iff `tags['user-id'] == ownUserId` (the viewer themself subscribed / upgraded).
  - `subgift`, `anonsubgift` → true iff `tags['msg-param-recipient-id'] == ownUserId` (the viewer received a gift).
  - anything else → false.
  Effect: the store schedules `scheduleEmoteRefresh()` (3 s later reloads the viewer's emotes: newly unlocked sub emotes appear in the menu).
- `bool emoteSetsChanged(String? before, String? after)` — true only when both are non-null and the comma-separated lists differ as SETS (order and duplicates ignored, `SetEquality<String>`). Used on successive USERSTATE `emote-sets` tags.
- `bool hasAnimatedEmote(IRCMessage message, Map<String, Emote> emotes)` — false unless a PRIVMSG with non-null text and not historical; then splits the text on single spaces and returns true if any word maps to an emote with `animated == true` (drives the one-time animated-emotes callout).
Oracle: `test/screens/channel/chat/emote_entitlements_test.dart`.

### lib/screens/channel/chat/overlay_chat_placement.dart

Immutable value type `OverlayChatPlacement {double top; double height}` — the vertical placement of the overlay chat (chat drawn over the video in landscape/fullscreen), both FRACTIONS of the available height (0..1).

- `static const minHeight = 0.3` — overlay chat never shorter than 30 % of the video height.
- `static const full = OverlayChatPlacement(top: 0, height: 1)` — the default.
- `factory clamped({top, height})`: `safeHeight = height.isFinite ? clamp(height, 0.3, 1.0) : 1.0`; `safeTop = top.isFinite ? clamp(top, 0.0, 1.0 - safeHeight) : 0.0`. NaN/infinite inputs fall back to full height / top 0 (a corrupted persisted value cannot hide the chat).
- `movedBy(double fraction)` → `clamped(top: top + fraction, height: height)` (move grip; cannot leave the frame).
- `resizedBy(double fraction)` → `clamped(top: top, height: clamp(height + fraction, 0.3, 1.0 - top))` — resizing from the bottom grip keeps the top fixed and never pushes the bottom past the frame.
- Value equality on (top, height), `hashCode = hash(top, height)`, `toString` → `OverlayChatPlacement(top, height)`.
- Top-level `bool overlayChatOnLeftAfterDrag({pointerX, screenWidth}) => pointerX < screenWidth / 2` — when a move drag ends, the overlay snaps to the LEFT side if the finger ended on the left half of the screen, else the right (exactly the midpoint → right).
Oracle: `test/screens/channel/chat/overlay_chat_placement_test.dart`.

### lib/screens/channel/chat/mod_tools/mod_action_text.dart

Formats one moderation-feed entry (`ModActionEntry`, from `mod_events.dart`) into the localized chat line of the mod action feed.

- `String modActionKey(String action)` — snake_case → camelCase: each `_x` (underscore + lowercase letter) becomes the uppercase letter (`add_blocked_term` → `addBlockedTerm`, `approve_unban_request` → `approveUnbanRequest`; `emoteonlyoff` unchanged).
- `String modActionLine(AppLocalizations l, ModActionEntry entry)`:
  - `duration` = '' if `entry.timeoutLength` is null or negative; else `timeoutLength(roundedTimeoutSeconds(length), l)`.
  - `key = modActionKey(entry.action)`; when key is `timeout` and duration is empty, the ICU select value becomes `timeoutUnknown`.
  - `line = l.chatModAction(action: key, moderator: entry.moderatorName, user: entry.userName ?? '', duration)` — ICU select cases: ban, timeout, timeoutUnknown, unban, untimeout, warn, delete, clear, mod, unmod, vip, unvip, raid, unraid, addBlockedTerm, removeBlockedTerm, addPermittedTerm, removePermittedTerm, approveUnbanRequest, denyUnbanRequest, emoteonly, emoteonlyoff, followers, followersoff, slow, slowoff, subscribers, subscribersoff, uniquechat, uniquechatoff, other.
  - Non-empty `entry.reason` → `l.chatModActionWithReason(line, reason)` = `{line} Reason: “{reason}”.`
- `int roundedTimeoutSeconds(Duration length)`: `seconds = ms / 1000`; below 60 s → nearest second; 60 s and above → nearest whole MINUTE (×60). Clamped to `[1, 1209600]` (1 s … 14 days). EventSub gives an end timestamp while the app stamps the event with its own clock, so the length drifts by milliseconds; rounding gives "10 minutes" not "599 seconds".
Oracle: `test/screens/channel/chat/mod_tools/mod_events_test.dart`.

### lib/screens/channel/chat/mod_tools/mod_features.dart

`enum ModFeature` — every mod tool, with the OAuth scopes it needs and whether only the broadcaster may use it. Drives which mod tools appear and which scopes the login asks for (`static Set<String> allScopes` = union of all scopes).

| feature | scopes | broadcasterOnly |
|---|---|---|
| announcements | moderator:manage:announcements | no |
| shoutouts | moderator:manage:shoutouts | no |
| shieldMode | moderator:manage:shield_mode | no |
| autoMod | moderator:manage:automod | no |
| blockedTerms | moderator:manage:blocked_terms | no |
| unbanRequests | moderator:manage:unban_requests | no |
| suspiciousUsers | moderator:manage:suspicious_users | no |
| actionFeed | moderator:read:moderators, moderator:read:vips, moderator:manage:blocked_terms, moderator:manage:chat_settings, moderator:manage:unban_requests, moderator:manage:banned_users, moderator:manage:chat_messages, moderator:manage:warnings | no |
| moderators | channel:manage:moderators | yes |
| vips | channel:manage:vips | yes |
| streamInfo | channel:manage:broadcast | yes |
| marker | channel:manage:broadcast | yes |
| commercial | channel:edit:commercial | yes |
| raid | channel:manage:raids | yes |
| polls | channel:manage:polls | yes |
| predictions | channel:manage:predictions | yes |
| redemptions | channel:manage:redemptions | yes |
| bans | moderator:manage:banned_users | yes |

A feature is usable when the token holds ALL its scopes and, if broadcasterOnly, the viewer is the channel owner (`ModToolsStore.canUse`). `actionFeed` needs all eight scopes because EventSub `channel.moderate` v2 requires them. Oracle: `test/screens/channel/chat/mod_tools/mod_tools_store_test.dart`, `test/screens/channel/chat/stores/chat_store_mod_tools_test.dart`.

### lib/screens/channel/chat/incoming_raid.dart

Two immutable value types for the "incoming raid" banner pinned above chat.

`IncomingRaid {String raiderName; String? raiderLogin; int viewers; String? avatarUrl}`:
- `static IncomingRaid? fromNotice(UserNotice notice, {required String channelId})` → null when: `notice.kind != UserNoticeKind.raid`; `notice.isHistorical` (replayed history must not pop a banner); `notice.sourceRoomId` non-null and different from `channelId` (a raid announced in ANOTHER channel of a Shared Chat session); or the name is null/blank. Name = first non-null of `raiderDisplayName`, `displayName`, `login`, trimmed.
- `raiderLogin = notice.login?.toLowerCase()`; `viewers = max(0, raidViewerCount ?? 0)`; `avatarUrl = twitchImageOrNull(notice.raiderAvatarUrl)` — only an https URL on Twitch's image host is kept (`utils/https_url.dart`), anything else → null.
- `raiderKey = (raiderLogin ?? raiderName).toLowerCase()` — identity used to de-duplicate one raid heard twice.

`IncomingRaidBanner {IncomingRaid raid; String id; DateTime endsAt}` — the raid as a highlight-stack entry (`id` in the highlight stack, `endsAt` = auto-dismiss time set by the banner owner). ChatStore only exposes `latestIncomingRaid`; the banner lifetime is handled by the highlight widgets (out of this area). Oracle: `test/screens/channel/chat/incoming_raid_test.dart`, `test/screens/channel/chat/stores/chat_store_raids_test.dart`.

### lib/screens/channel/chat/server_notice.dart

Localizes Twitch IRC `NOTICE` lines (by their `msg-id` tag) into the UI language.

- `bool isSendRejection(String msgId) => msgId.startsWith('msg_')` — every `msg_*` notice is Twitch refusing the viewer's own message (the store then rolls back the pending send, keeps the text, vibrates and shows a notification).
- `const kPlainServerNotices` (msg-id → ICU select value of `chatServerNotice`): `msg_ratelimit`→rateLimit, `msg_duplicate`→duplicate, `msg_subsonly`→subsOnly, `msg_emoteonly`→emoteOnly, `msg_r9k`→uniqueChat, `msg_followersonly`→followRequired, `msg_followersonly_zero`→followRequired, `msg_followersonly_followed`→followedTooRecently, `msg_verified_email`→verifiedEmail, `msg_requires_verified_phone_number`→verifiedPhone, `msg_banned_email_alias`→emailAliasBanned, `msg_banned_phone_number_alias`→phoneAliasBanned, `msg_channel_suspended`→channelSuspended, `msg_suspended`→accountSuspended, `msg_channel_blocked`→channelBlocked, `msg_user_has_consequence`→userRestricted, `msg_channel_has_consequence`→channelRestricted, `msg_invalid_reply_parent`→invalidReply, `msg_unexpected_error`→unexpected, `msg_bad_characters`→badCharacters, `msg_rejected_mandatory`→rejectedBySettings, `msg_concurrent_channel_limit_reached`→tooManyChats, `msg_warned`→warned, `msg_banned`→banned, `followers_on_zero`→followersOnNow, `no_permission`→noPermission.
- Regexes: `_seconds = (\d+) (?:more )?seconds?`; `_unrecognized = Unrecognized command: /(\S+)`.
- `String serverNoticeText(String? msgId, String twitchText, AppLocalizations l)`: no msg-id → Twitch's text verbatim. Plain table hit → `l.chatServerNotice(notice: kind)`. `msg_timedout` → seconds from the text → `chatServerNoticeTimedOut(wait: timeoutLength(seconds))`; `msg_slowmode` → `chatServerNoticeSlowMode(wait: timeoutLength(seconds))`; `unrecognized_cmd` → `chatServerNoticeUnknownCommand(command: commandInChatLine(command))` (slash + word joiner + name). A number/command that cannot be parsed, or an unknown msg-id → Twitch's original text (never an empty line).
Oracle: `test/screens/channel/chat/server_notice_test.dart`.

### lib/screens/channel/chat/held_messages.dart

`HeldMessageWatcher` — tells the logged-in viewer what moderators decided about THEIR messages held by AutoMod. IRC only says "your message is being checked", never the outcome; the outcome comes from EventSub.

Constructor `HeldMessageWatcher({listen, broadcasterId, userId, onNotice})`:
- Both ids must match `^[0-9]{1,20}$` else `ArgumentError.value(id)` is thrown (no subscription with junk ids; ChatStore catches and logs).
- Subscribes `listen(EventSubTopic('channel.chat.user_message_update', '1', {'broadcaster_user_id': broadcasterId, 'user_id': userId}))` (scope `user:read:chat`) and listens to `handle.events`, reacting only to `EventSubData` events.
- `_onUpdate(event)`: ignored if `event['user_id'] != userId`. `status` must be a String among `approved`, `denied`, `invalid`, else ignored. `decision = L10n.current.chatHeldDecision(decision: status)` (language on screen now). Quote = `whisperPreview(event['message']['text'])` (the one-line preview normalizer from whisper_store: collapses whitespace/newlines) when `message` is a map with a String `text`, else ''. Output:
  - empty quote → `'$decision.'`;
  - quote longer than `_maxQuote = 100` CODE POINTS (runes, so emoji are never cut in half) → first 100 runes + `…` → `chatHeldQuoted(decision, quote)`;
  - else `chatHeldQuoted(decision, quote)` = `{decision}: “{quote}”`.
- `dispose()` cancels the handle and the stream subscription (unawaited).
Oracle: `test/screens/channel/chat/held_messages_test.dart`.
### lib/screens/channel/chat/moderation_notice.dart

Builds the synthetic chat lines for moderation events and the duration wording reused everywhere in chat.

- `_login = ^[a-z0-9_]{1,25}$` — a valid (lowercased) Twitch login.
- `String? moderationNotice(IRCMessage clearChat, {displayNameOf})` — for a TARGETED CLEARCHAT (the IRC trailing parameter is the target login). Login = trimmed, lowercased trailing; null or not a valid login → null (whole-chat clear or odd target). Name = `displayNameOf(login)`. Wording in `L10n.current`. Tag `ban-duration` absent → `chatNoticeBanned(name)` ("{name} has been permanently banned."); present but not an int → `chatNoticeTimedOut(name)` (a timeout, not a ban); int → `chatNoticeTimedOutFor(name, duration: timeoutLength(seconds))`.
- `IRCMessage? moderationNoticeLine(clearChat, {hiddenLogins, newestFirst})` — null if no target or the target is in `hiddenLogins` (blocked people: their messages are hidden, so is their ban line). Name = `chatNameOf(login, newestFirst)`. Creates `IRCMessage.createNotice(message: text)`; copies `tmi-sent-ts` (merged chats sort by it) and `historical=1`; when both `target-user-id` and `tmi-sent-ts` exist the notice `id` is `clearchat-<targetId>-<sentAt>` so a shared chat open in two tabs shows it once (merged view dedupes by id).
- `IRCMessage? ownDeletedMessageNotice(clearMessage, {ownLogin})` — for a CLEARMSG of the viewer's OWN message: requires ownLogin, tag `login` equal case-insensitively, not historical, non-empty text. Notice `chatNoticeOwnMessageDeleted(message: text)` ("Your message was deleted: “…”."), copies `tmi-sent-ts`, id `clearmsg-<target-msg-id>`.
- `String timeoutLength(int seconds, [l])` — the largest unit that divides EXACTLY: weeks (604800), days (86400), hours (3600), minutes (60), else seconds; negative → "0 seconds". So 90 → "90 seconds", 600 → "10 minutes", 3660 → "61 minutes", 1209600 → "2 weeks". ICU plurals `chatDurationWeeks/Days/Hours/Minutes/Seconds`.
- `String followAgeLength(Duration age, [l])` — followers-only follow age: whole multiples of 30 days that are whole days → months (`chatDurationMonths`, 30 d = 1 month, 90 d = 3 months); otherwise `timeoutLength(age.inSeconds)` ("1 week", "10 minutes").
- `String chatNameOf(login, newestFirst)` — display name of the target's newest message (`tags['display-name']`, through `getReadableName(name, login)`: equal to the login, digits only, or containing any ASCII letter → the display name alone; otherwise (non-Latin script) `Name (login)`), or the login when they have not chatted / the display-name is empty.
- `String timedOutLabel(int seconds, l)` → `chatTimedOutForLength(duration: timeoutLength(seconds))` — header above the messages of a timed-out user ("Timed out for 10 minutes").
Oracle: `test/screens/channel/chat/moderation_notice_test.dart`.

### lib/screens/channel/chat/overlay_chat_frame.dart

`OverlayChatFrame` (StatefulWidget) — positions the overlay chat inside the video area and provides two drag grips to move and resize it.

Props: `width` (fixed width of the overlay column), `placement` (`OverlayChatPlacement`), `showHandles` (grips visible), `leftSide`, `onPlacementChanged(OverlayChatPlacement)`, `onLeftSideChanged(bool)`, `child` (the chat).

Layout: `LayoutBuilder` → `SizedBox(width, height = maxHeight)` → `Stack` → `Positioned(top: height × placement.top, height: height × placement.height, left 0, right 0)` → inner `Stack(fit: expand)` with the child and, when `showHandles`, a move grip aligned top-center (key `overlay-chat-move`, label `overlayChatMove` "Move chat") and a resize grip aligned bottom-center (key `overlay-chat-resize`, label `overlayChatResize` "Resize chat").

Grip `_Grip`: `Semantics(label)` + `Tooltip(message: label)` + `GestureDetector(behavior: opaque, onPanUpdate, onPanEnd)`; hit area 72×28 logical px with a centered pill 36×4, colour `0x99FFFFFF` (60 % white), radius 2.

Interactions:
- Move drag update: remembers `globalPosition.dx` in `_pointerX`; emits `placement.movedBy(delta.dy / height)`.
- Move drag end: if a pointer x was recorded → `overlayChatOnLeftAfterDrag(pointerX, screenWidth: MediaQuery width)`; emits `onLeftSideChanged(left)` only when it differs from `leftSide`; clears `_pointerX`. Horizontal motion does not move the chat continuously; it only decides the side on release.
- Resize drag update: emits `placement.resizedBy(delta.dy / height)` (top fixed). No end handler.
No animation. Oracle: `test/screens/channel/chat/overlay_chat_frame_test.dart`.

### lib/screens/channel/chat/details/stores/chat_details_store.dart

MobX store `ChatDetailsStore` (generated mixin `_$ChatDetailsStore` in `chat_details_store.g.dart`) backing the chat details sheet: room modes and the chatters list.

Fields: `twitchApi`, `channelName`; `scrollController` (chatters list), `textController` (chatter filter field), `textFieldFocusNode`.
Observables: `roomState` (`ROOMSTATE`, default const — the room modes; ChatStore replaces it with `roomState.fromIRCMessage(line)` on every ROOMSTATE, merging partial updates), `showJumpButton` (false), readonly `_filterText` ('').
`chatUsers` — a `SplayTreeSet<String>` (sorted, unique logins of everyone seen chatting: live senders and history senders) — NOT observable itself (readers rebuild through other observables).
Computed `filteredUsers` = `chatUsers.where((user) => user.contains(_filterText))` — case-sensitive substring on the login (logins are lowercase; the typed filter is not lowercased, so typing capitals finds nothing).
Constructor listeners: scroll → `showJumpButton = !(position.atEdge || position.outOfRange)` (scroll-to-top button visible whenever the list is away from both edges); text → `_filterText = textController.text`.
`dispose()` disposes the three controllers. Oracle: `test/screens/channel/chat/details/chat_users_list_test.dart`, `test/screens/channel/chat/details/chat_details_test.dart`.
### lib/screens/channel/chat/chat_history.dart

Converts Twitch's chat history (GQL `ChatHistory`, model `ChatHistoryMessage` in `lib/models/chat_history.dart`) into the SAME `IRCMessage` model live chat uses, so every live render path (Twitch/7TV/BTTV/FFZ emotes, badges, colours, mentions, replies, cheers, GIFs, the deleted-message reveal) works unchanged on history lines. Also the helpers that insert history above live lines without duplicates.

Constants: `_twitchLogin = ^[a-zA-Z0-9_]{1,25}$`; `_actionPrefix = '\x01ACTION '`; `_actionSuffix = '\x01'` (IRC CTCP `/me` wrapper); `_never(text) => false`.

`List<IRCMessage> chatHistoryLines(history, {required channelId, required channelLogin, viewerLogin, hiddenUserIds = {}, hiddenLogins = {}, muted})`:
1. `isMuted = muted ?? _never`; hidden logins lower-cased.
2. Copies and STABLE-sorts (merge sort) by `sentAt` ascending — oldest first whatever order Twitch answers in; equal timestamps keep their order.
3. For each message:
   - Dropped if no sender, no sender login, or an invalid login (like the official app, messages without a sender are dropped).
   - Dropped if the lowercase login is hidden or the sender id is in `hiddenUserIds` (blocked users).
   - `fragments` = records `(text, emoteId)` from `message.fragments`.
   - `/me`: `_unwrapAction(fragments)` (below) tells whether the line is an action; the wrapper is removed here and re-added by the builder.
   - GIFs: map fragment index → `(id, url)` for fragments that carry a GIF.
   - Bits = sum of `fragment.bits`.
   - `extraTags`: `historical: '1'` (ALWAYS — keeps it out of everything reacting to "now": mention alerts, raid and gift banners, emote refresh, restrictions), `bits` when > 0, `source-room-id` = `message.sourceChannelId` when non-null (Shared Chat origin).
   - Replies: when `parent` exists with text and a valid parent login: parentName = parent display name, or the login when empty; tags `reply-parent-msg-id`, `reply-parent-msg-body`, `reply-parent-user-login` (lower), `reply-parent-display-name`, `reply-parent-user-id` (if known). Live replies always start with `@parentname` (the renderer hides that first word); if the history text's first word (split on a single space, lowercased) is neither `@<parentLogin>` nor `@<parentName lowercased>`, a fragment `'@<parentLogin lowercased> '` is INSERTED at index 0 and every GIF index shifts by +1. A `threadParent` with a valid login adds `reply-thread-parent-msg-id`, `reply-thread-parent-user-login` (lower), `reply-thread-parent-display-name` (display name; a NULL name → login, an EMPTY name is kept as '' — unlike the reply parent where empty also falls back).
   - Built with `buildPrivmsgIrcMessage(fragments, login, displayName, id, channelId, channelLogin, sentAt, userId, color, badges, viewerLogin, extraTags, gifs, action)` (shared builder in `utils/irc_privmsg_builder.dart`: `emotes` tag from fragment emote ids, mention detection against `viewerLogin`, etc.).
   - If the built text is muted → dropped.
   - If `message.deleted` → the line's command becomes `Command.clearMessage` (shown deleted, exactly as a live CLEARMSG leaves it; the reveal works).
4. Returns lines oldest first.

`bool _unwrapAction(fragments)` (in place): false if empty; the joined text must be at least 9 chars (`len('\x01ACTION ') + len('\x01')`), start with the prefix and end with the suffix; additionally the FIRST fragment must itself start with the prefix and the LAST end with the suffix (the wrapper must not span fragments), and a single fragment shorter than 9 chars fails. Then strips the prefix from the first fragment and the suffix from the last (keeping their emote ids); returns true.

`List<IRCMessage> newHistoryLines(history, {shown})` — set of `tags['id']` of shown lines; keeps a history line whose id is null (always kept) or not yet seen; the set is updated while iterating, so duplicates INSIDE the history are dropped too. A line seen live while the history was loading is not shown twice.

`List<IRCMessage> insertHistory(messages, history, {alsoShown = []})` — fresh lines against `messages` followed by `alsoShown` (the store's buffer), inserted all at index 0 of `messages` in ONE insert (in the reversed chat list that is "above everything", which does not move what is on screen: a pinned chat stays pinned, a scrolled-up chat stays put), returned.
Oracle: `test/screens/channel/chat/chat_history_test.dart`, `test/screens/channel/chat/chat_history_layout_test.dart`, `test/screens/channel/chat/stores/chat_store_history_test.dart`.

### lib/screens/channel/chat/chat_filters.dart

The official Twitch app's personal "Edit Chat Filters" (masking by AutoMod ratings), reproduced client-side from the IRC `flags` tag.

`const _invisible = '\u{E0000}'` — the invisible tag character some clients append to repeat a message; never masked.

`class AutoModFlag {int start, end; int identity = 0, sexual = 0, aggressive = 0, profanity = 0}` — one rating: characters `start..end` INCLUSIVE (code-point positions, like the `emotes` tag), level 0–7 per category.

`const _maxFlags = 100` — at most 100 ratings read from one tag.

`List<AutoModFlag> parseAutoModFlags(String? tag)` — format `start-end:A.n/I.n/P.n/S.n`, entries separated by commas. Null/empty → const []. Per entry (stop after 100): needs a `:`; the range split on `-` must have exactly 2 integer parts, else the entry is skipped; levels split on `/`, each split on `.`, needs ≥ 2 parts and an int value, else that level is ignored; `I`→identity, `S`→sexual, `A`→aggressive, `P`→profanity, other letters ignored.

`class ChatFilterSettings {bool enabled, discrimination, sexual, harassment, profanity}`:
- `factory of(SettingsStore s)` reads `chatFiltersEnabled`, `chatFilterDiscrimination`, `chatFilterSexual`, `chatFilterHarassment`, `chatFilterProfanity`.
- `static const threshold = 3` — a category is hidden from level 3 up.
- `hides(flag)` = `enabled && ((harassment && aggressive >= 3) || (discrimination && identity >= 3) || (profanity && profanity >= 3) || (sexual && sexual >= 3))` (mapping: harassment ↔ A, discrimination ↔ I).
- `copyWith`, value `==`, `hashCode`.

`({String text, String mark})? maskFilteredText(text, flags, settings)`:
- null when there are no flags or filters are disabled.
- `starts` = UTF-16 index where each code point starts (a low surrogate right after a high surrogate is not a start).
- Flags sorted by start. Each is skipped if `start < 0`, `start >= end` (single-character ranges are never used), or `end >= code point count`; skipped if it starts inside the previously TAKEN range (`start < next`); then `next = end + 1` (taken even when not hidden); if `settings.hides(flag)`, UTF-16 range `[starts[start], starts[end + 1] or text.length)` is added to `hidden`.
- No hidden range → null. `mark = _absentMark(text)` = the first Private-Use-Area char U+E000…U+F8FF absent from the text (6400 candidates; a 500-char message cannot hold all) — null → null.
- Iterates grapheme clusters: a cluster overlapping a hidden range becomes `mark` repeated `cluster.length` times (one per UTF-16 unit, so emote positions stay valid) UNLESS it is whitespace, the invisible `\u{E0000}`, or an emoji (`regexEmoji`) — those stay so the masked text splits into the same words. Returns `(text: masked, mark)` if anything changed, else null.
The renderer draws runs of `mark` as a masked block with a "Show message" reveal (`ChatStore.revealFilteredMessage`). Oracle: `test/screens/channel/chat/chat_filters_test.dart`.

### lib/screens/channel/chat/chat_restrictions.dart

Computes the one restriction banner above the chat input (like the official app's mode banners) and the viewer's own ban/timeout state.

`enum ChatRestrictionKind { banned, timedOut, slowMode, emoteOnly, subscribersOnly, followersOnly, verifiedEmail, verifiedPhone, emailAliasBanned, phoneAliasBanned, accountRestricted, channelRestricted, followRequired, warned }`.

`_accountRefusals` (msg-id of a send-refusal NOTICE → sticky restriction): `msg_verified_email`→verifiedEmail, `msg_requires_verified_phone_number`→verifiedPhone, `msg_banned_email_alias`→emailAliasBanned, `msg_banned_phone_number_alias`→phoneAliasBanned, `msg_user_has_consequence`/`msg_suspended`/`msg_channel_blocked`→accountRestricted, `msg_channel_has_consequence`/`msg_channel_suspended`→channelRestricted, `msg_followersonly`/`msg_followersonly_zero`→followRequired, `msg_warned`→warned. `accountRestrictionOf(msgId)` looks it up.

`kTwitchSecuritySettingsUrl = 'https://www.twitch.tv/settings/security'`.

`class ChatRestriction(kind, {DateTime? until, int? minutes})`:
- `blocksInput` — only timedOut and slowMode (input locked until `until`). A BAN does not lock the input: Twitch says nothing on an unban, so sending is how the viewer finds out (a refused send re-bans).
- `showsBar` — false for emoteOnly, subscribersOnly, followersOnly (said in the input placeholder instead); true otherwise.
- `acknowledgeable` = warned (banner offers "acknowledge"); `appealable` = banned (banner offers "appeal").
- `barHeight` = `kRestrictionBarHeight` 28.0 when no helpUrl, not acknowledgeable, not appealable; else `kRestrictionBarTapHeight` 48.0.
- `helpUrl` = the security settings URL for verifiedEmail / verifiedPhone; else null.
- `describe(Duration? left, [l])`: banned→`chatRestrictionBanned`; timedOut→`chatRestrictionTimedOut` when left is null, else `chatRestrictionTimedOutFor(wait: formatWait(left))`; slowMode→`chatRestrictionSlow(wait: formatWait(left ?? 0))`; emoteOnly→`chatRestrictionEmoteOnly`; subscribersOnly→`chatRestrictionSubscribersOnly`; followersOnly→ minutes null or 0 → `chatRestrictionFollowersOnly`, else `chatRestrictionFollowersFor(duration: followAgeShort(minutes))`; every account kind → `chatRestrictionAccount(reason: kind.name)`.

`followAgeShort(Duration age, l)`: < 60 min → `chatShortMinutes` ("10m" / « 10 min »); < 1440 min or not whole days → whole hours `chatShortHours` ("3h") or `chatShortHoursMinutes`; else days → multiple of 30 → `chatDurationMonths(days / 30)`, else `chatDurationDays(days)`.

`formatWait(Duration left, [l])`: negative → 0; < 60 s → `chatShortSeconds` ("12s" / « 12 s »); else `H:MM:SS` when hours > 0, otherwise `M:SS` (seconds zero-padded to 2; minutes padded only in the H form).

`ChatRestriction? chatRestriction({room, privileged, subscriber, now, banned = false, timedOutUntil, lastSentAt, refusedFor})`, priority:
1. banned → banned.
2. `timedOutUntil` after now → timedOut(until).
3. `refusedFor` → that kind.
4. privileged (broadcaster, moderator, VIP) → null.
5. slow = int(room.slowMode) or 0; > 0 with a known lastSentAt and lastSentAt + slow s after now → slowMode(until).
6. room.emoteOnly == '1' → emoteOnly.
7. room.subMode == '1' and not subscriber → subscribersOnly.
8. followers = int(room.followersOnly) or −1; ≥ 0 → followersOnly(minutes) (0 = any follower).
9. null.

`ownClearChat(clearChat, {ownUserId, now})` → `({bool banned, DateTime? until})?`: null unless `target-user-id == ownUserId` and not historical. No/invalid `ban-duration` → `(banned: true, until: null)`. Else sent = `tmi-sent-ts` ms UTC, or now when absent; a future sent time (clock skew) counts from now; until = from + seconds; `(banned: false, until)` only when until is after now, else null. Counting from Twitch's send time means a DELAYED chat does not lengthen the timeout.
Oracle: `test/screens/channel/chat/chat_restrictions_test.dart`.
### lib/screens/channel/chat/chat_commands.dart

The slash-command parser and the command catalogue suggested by the input. Twitch no longer runs commands sent over IRC (except `/me`), so the app parses each typed line and runs commands itself (Helix / GQL) or sends the line as a normal message.

**Sealed hierarchy `ChatCommand`:**
- `SendAsIs` — a normal message or `/me` (`.me` too): sent over IRC unchanged.
- `ColorCommand(String color)` — Helix colour: named (`blue_violet`) or `#RRGGBB` (hex needs Turbo/Prime).
- `BlockCommand(login)`, `UnblockCommand(login)`.
- `WhisperCommand(login, message)` — `/w`, `/whisper`.
- `UserCardCommand(login)` — `/user` opens the user card.
- `DisconnectCommand` — `/disconnect`.
- `HelpCommand` — `/help` or `/commands`.
- `sealed ModerationCommand` (moderators/broadcaster, through Helix): `BanCommand(login, reason)`, `TimeoutCommand(login, Duration duration, reason)`, `UnbanCommand(login, {timeout = false})` (`/untimeout` sets `timeout`; both lift either), `WarnCommand(login, reason)`, `DeleteMessageCommand(messageId)`, `ClearChatCommand`, `ChatModeCommand(ChatMode mode, {required on, Duration? duration})` (duration = slow wait or follow age; null otherwise and when turning off), `AnnounceCommand(message, AnnouncementColor color)`, `ShoutoutCommand(login)`, `RoleListCommand(ChannelRole role)`, `RoleCommand(login, role, {granted})`, `LeadModCommand(login, {granted})`, `ShieldCommand({on})`, `MarkerCommand(description)`, `CommercialCommand(int seconds)`, `RaidCommand(login)`, `UnraidCommand`, `SuspicionCommand(login, SuspiciousStatus status, {on})`.
- `UnsupportedCommand(CommandProblem problem)` with `text(l) => problem.text(l)` — said as a local notice line in chat (input text kept).
- `enum ChatMode { slow, followers, subscribers, emoteOnly, uniqueChat }` (named by `ChatModeLabel` in `l10n/enum_labels.dart`: `label` = `chatModeName(mode)`, `pill` = `chatModePill(mode)`).

**Problems (sealed `CommandProblem`, each `text(l)`; commands, lengths and colour names stay as Twitch reads them):**
- `UsageProblem(name)` → `chatCommandUsage(usage)`, usage = the catalogue entry's `usage(l, inChatLine: true)` (e.g. `/⁠ban <user> [reason]`) or `commandInChatLine(name)` for a name not in the catalogues (mode commands such as `r9kbeta`).
- `BadLengthProblem(length)` → `chatCommandBadLength(length)`.
- `RangeProblem(ChatMode? mode)` → slow `chatCommandSlowRange`; followers `chatCommandFollowAgeRange`; null (timeout) `chatCommandTimeoutRange`.
- `UnknownColorProblem` → `chatCommandUnknownColor`.
- `NotInAppProblem(command)` → `chatCommandNotInApp(command)`.
- `UnknownCommandProblem(command)` → `chatCommandUnknown(command)`.

**Arguments** `enum ChatCommandArg { user, message, color, reason, length, seconds, messageId, channel, description }` → `word(l)` = `chatCommandArgUser/Message/Color/Reason/Length/Seconds/MessageId/Channel/Description` (translated placeholder words; the command NAME is never translated).

`commandInChatLine(name) = '/⁠' + name` — a WORD JOINER (U+2060) after the slash so a wrapped chat line never leaves the slash alone at the end of a row. Only in displayed lines, never in what is typed.

`ChatCommandInfo(name, {required = [], optional = []})`: `usage(l, {inChatLine = false})` = `['/name' (or the joined form), '<word>' per required, '[word]' per optional].join(' ')`; `description(l) = chatCommandDescription(command: name)`.

**`kChatCommands`** (everyone, in order): `me <message>`, `color <color>`, `block <user>`, `unblock <user>`, `w <user> <message>`, `user <user>`, `disconnect`, `help`.

**`kModeratorChatCommands`** (moderators/broadcaster, in order): `ban <user> [reason]`, `unban <user>`, `timeout <user> [length] [reason]`, `untimeout <user>`, `warn <user> <reason>`, `delete <messageId>`, `clear`, `slow [seconds]`, `slowoff`, `followers [length]`, `followersoff`, `subscribers`, `subscribersoff`, `emoteonly`, `emoteonlyoff`, `uniquechat`, `uniquechatoff`, `announce <message>`, `announceblue <message>`, `announcegreen <message>`, `announceorange <message>`, `announcepurple <message>`, `shoutout <channel>`, `shield`, `shieldoff`, `monitor <user>`, `unmonitor <user>`, `restrict <user>`, `unrestrict <user>`, `mods`, `vips`, `mod <user>`, `unmod <user>`, `vip <user>`, `unvip <user>`, `leadmod <user>`, `unleadmod <user>`, `marker [description]`, `commercial [seconds]`, `raid <channel>`, `unraid`.

`kCommercialLengths = [30, 60, 90, 120, 150, 180]` (seconds).

`broadcasterOnlyName(cmd)` → the typed name for broadcaster-only commands (`mods`, `vips`, `mod`, `unmod`, `vip`, `unvip`, `leadmod`, `unleadmod`, `marker`, `commercial`, `raid`, `unraid`), else null.

**`kChatNamedColors`** (key = lowercase name without underscores → Helix spelling): blue→blue, blueviolet→blue_violet, cadetblue→cadet_blue, chocolate→chocolate, coral→coral, dodgerblue→dodger_blue, firebrick→firebrick, goldenrod→golden_rod, green→green, hotpink→hot_pink, orangered→orange_red, red→red, seagreen→sea_green, springgreen→spring_green, yellowgreen→yellow_green.

`_otherModeratorCommands = {'pin'}` → NotInAppProblem.

**Regexes:** `_login = ^@?([a-zA-Z0-9_]{1,25})$` (optional @, result lowercased); `_hex = ^#?([0-9a-fA-F]{6})$` (result upper-cased with `#`); `_length = ^(\d+)(s|m|h|d|w|mo)?$` case-insensitive; `_messageId = ^[0-9a-fA-F-]{1,64}$`; `_digit = ^\d`.

**Bounds:** timeout default 10 min, min 1 s, max 14 days; slow default 30 s, min 3 s, max 120 s; follow age default 0, max 90 days, whole minutes only; `_maxLengthSeconds = 1000000000` (~31 years).

`Duration? parseCommandLength(text, {required Duration unit})`: the regex must match; more than 9 digits → treated as 999999999 (overflow guard); suffix s=1, m=60, h=3600, d=86400, w=604800, mo=2592000 (30 days); no suffix → `unit.inSeconds`; result `min(count × unitSeconds, 1e9)` seconds ("30" = 30 s for timeout/slow, but 30 min for followers).

`List<ChatCommandInfo> matchCommands(text, {moderator = false})` — autocomplete: empty unless the text starts with `/` and contains NO space; term = rest lowercased; catalogue entries (user commands, plus moderator ones when `moderator`) whose name starts with the term, in catalogue order. `/` alone lists all.

**`ChatCommand parseChatCommand(String text)`**:
1. `trimmed = text.trim()`; not starting with `/` or `.` → SendAsIs.
2. Split the rest on `\s+`; name = first part lowercased; args = remaining non-empty parts.
3. Starts with `.` and name ≠ `me` → SendAsIs (`.` only starts `.me`, like Twitch).
4. Switch:
   - `me` → SendAsIs.
   - `help` / `commands` → HelpCommand.
   - `color`: exactly 1 arg else Usage('color'); named lookup on `arg.toLowerCase().replaceAll('_','')` → ColorCommand(Helix name); else hex → ColorCommand('#RRGGBB' upper); else UnknownColorProblem.
   - `block` / `unblock`: exactly 1 valid login else Usage(name) → Block/UnblockCommand(lowercase).
   - `w` / `whisper`: first arg a valid login and ≥ 2 args else Usage('w') → WhisperCommand(login, rest joined with single spaces).
   - `user`: exactly 1 valid login else Usage('user') → UserCardCommand.
   - `disconnect`: no args else Usage('disconnect').
   - a name in `_moderationNames` (every moderator catalogue name + `r9kbeta`, `r9kbetaoff`) → `_parseModeration`.
   - `pin` → NotInAppProblem('pin').
   - else UnknownCommandProblem(name).
   (The parser does not check that the viewer moderates; Helix does.)

`_parseChannelCommand(name, args)` (`onlyLogin()` = exactly one arg that is a valid login):
- announce / announceblue / announcegreen / announceorange / announcepurple → message = `singleLine(args.join(' '), maxLength: 500)` (control characters → spaces, trimmed, cut to 500 code points then right-trimmed); empty → Usage(name); else AnnounceCommand(message, primary / blue / green / orange / purple).
- `shoutout` → onlyLogin or Usage.
- `mods` / `vips` → no args (else Usage) → RoleListCommand(moderator / vip).
- `mod` / `unmod` / `vip` / `unvip` → onlyLogin → RoleCommand(login, ends with 'mod' ? moderator : vip, granted: !startsWith('un')).
- `leadmod` / `unleadmod` → onlyLogin → LeadModCommand(granted: name == 'leadmod').
- `shield` / `shieldoff` → no args → ShieldCommand(on: name == 'shield').
- `marker` → MarkerCommand(singleLine(args.join(' '), maxLength: 140)) — the description may be empty.
- `commercial` → > 1 arg → Usage; seconds = 30 with no arg, else int of the arg with one trailing `s` removed; must be in kCommercialLengths else Usage.
- `raid` → onlyLogin → RaidCommand. `unraid` → no args → UnraidCommand, else Usage.
- `monitor` / `unmonitor` / `restrict` / `unrestrict` → onlyLogin → SuspicionCommand(login, ends with 'monitor' ? monitored : restricted, on: !startsWith('un')).
- otherwise null.

`_parseModeration(name, args)`: channel commands first, then:
- `ban`: first arg a valid login else Usage('ban') → BanCommand(login, rest joined) (reason may be empty).
- `timeout`: first arg a valid login else Usage; with ≥ 2 args, `length = parseCommandLength(args[1], unit: 1 s)`; null length but args[1] starts with a digit ("5min", "1h30m") → BadLengthProblem(args[1]) (a mistyped length is never taken as the reason); duration = length ?? 10 min; outside [1 s, 14 d] → RangeProblem(null); reason = args after the length (or after the login when no length).
- `unban` / `untimeout`: exactly one valid login → UnbanCommand(timeout: name == 'untimeout').
- `warn`: valid login and ≥ 2 args else Usage → WarnCommand(login, reason).
- `delete`: exactly one arg matching the message-id regex → DeleteMessageCommand, else Usage('delete').
- `clear`: no args → ClearChatCommand, else Usage.
- `slow`: > 1 arg → Usage; wait = 30 s default or parsed (seconds unit); null or outside [3 s, 120 s] → RangeProblem(slow) → ChatModeCommand(slow, on: true, duration: wait).
- `followers`: > 1 arg → Usage; age = 0 default or parsed (a bare number = MINUTES); null, > 90 days or not whole minutes → RangeProblem(followers) → ChatModeCommand(followers, on: true, duration: age).
- toggles: `slowoff` (slow, off), `followersoff` (followers, off), `subscribers` / `subscribersoff`, `emoteonly` / `emoteonlyoff`, `uniquechat` | `r9kbeta` (on), `uniquechatoff` | `r9kbetaoff` (off); any arg → Usage(name); else ChatModeCommand(mode, on). An unexpected name throws `StateError` (unreachable).
Oracle: `test/screens/channel/chat/chat_commands_test.dart`, `test/screens/channel/chat/chat_commands_mod_test.dart`, `test/screens/channel/chat/lead_mod_command_test.dart`, `test/screens/channel/chat/moderation_channel_commands_test.dart`.

### lib/screens/channel/chat/moderation.dart

`ChatModeration` — runs a parsed `ModerationCommand` in one chat as one moderator through Helix, always returning an outcome line (never throws). Re-exports `chatErrorText` and `maxQuotedTwitchReason` from `l10n/api_errors.dart`.

Types: `typedef ModerationOutcome = ({bool ok, String message})`; `moderationFailed` getter = `(ok: false, message: L10n.current.chatModNotThrough)` (when an action threw unexpectedly, so a busy bar never stays busy). Private exceptions `_BroadcasterOnly(command)`, `_ViewerActionNotDone(ViewerActionOutcome outcome)`, `_NoSuchUser(login)` (extends `NotFoundException`, message `no user named <login>`). `typedef LeadModeratorSetter = Future<ViewerActionOutcome> Function(String userId, {required bool granted})` (lead moderator is a GQL viewer action; outcomes done / refused / integrityRefused / signedOut / failed).

Constructor: `api` (TwitchApi), `broadcasterId`, `moderatorId` (the viewer's id; equal ids = the broadcaster), optional `setLeadModerator`.

`run(command, {userId})`: success → `(ok: true, message)`. On error: debugPrint; if the error is NOT `ApiException`, `_BroadcasterOnly` or `_ViewerActionNotDone` it goes to telemetry (`Telemetry.recordError(..., reason: 'moderation <Type>')`); returns `(ok: false, message: moderationFailure(error, moderationCommand(command)))`.

`_run(command, knownId)`: `target(login)` → `(id: knownId, name: login)` when the caller knows the id (user card), else `api.getUser(userLogin: login)` → `(id, displayName)`; NotFound → `_NoSuchUser(login)` (stack kept). Not the broadcaster and `broadcasterOnlyName(command) != null` → `_BroadcasterOnly(typed)` BEFORE any network call. Per command (Helix base `https://api.twitch.tv/helix`):
- Announce → `POST /chat/announcements` (broadcaster_id, moderator_id, message, color) → `chatModAnnounced`.
- Shoutout → target → `POST /chat/shoutouts` → `chatModShoutoutSent(name)`.
- RoleList → `getRoleUsers` (`GET /moderation/moderators` or `GET /channels/vips`, up to 10 pages of 100 (≤ 1000 entries; anything past that is silently not shown)) → `roleListLine`.
- Role → target → `setRole` (`POST` / `DELETE` on `/moderation/moderators` or `/channels/vips`) → `chatModRoleChanged(change: '<moderator|vip><Added|Removed>', name)`.
- LeadMod → no setter → `_ViewerActionNotDone(signedOut)`; target; `setter(id, granted)`; outcome ≠ done → `_ViewerActionNotDone(outcome)`; → `chatModRoleChanged(change: leadModeratorAdded | leadModeratorRemoved, name)`.
- Shield → `PUT /moderation/shield_mode` (is_active) → `chatModShield(state: on|off from the RETURNED status)`.
- Marker → `POST /streams/markers` (description) → `chatModMarkerAdded`.
- Commercial → `POST /channels/commercial` (length) → `chatModCommercialStarted(duration: timeoutLength(granted length))`.
- Raid → target → `POST /raids` → `chatModRaidStarted(name)`; Unraid → `DELETE /raids` → `chatModRaidCanceled`.
- Suspicion → target → `setSuspiciousStatus` (`POST /moderation/suspicious_users` with `ACTIVE_MONITORING` / `RESTRICTED`, or `DELETE` when turning off) → `chatModSuspicion(change: monitor|unmonitor|restrict|unrestrict, name)`.
- Ban → `POST /moderation/bans` (reason, no duration) → `chatModBanned(name)`.
- Timeout → `POST /moderation/bans` with duration → `chatModTimedOut(name, duration: timeoutLength(seconds))`.
- Unban → `DELETE /moderation/bans` → `chatModUntimedOut(name)` when typed /untimeout, else `chatModUnbanned(name)`.
- Warn → `POST /moderation/warnings` (reason) → `chatModWarned(name)`.
- DeleteMessage → `DELETE /moderation/chat` with message_id → `chatModMessageDeleted`; ClearChat → `DELETE /moderation/chat` without id → `chatModCleared`.
- ChatMode → `PATCH /chat/settings` with only that mode's field: slow_mode (+ slow_mode_wait_time seconds when on), follower_mode (+ follower_mode_duration minutes when on), subscriber_mode, emote_mode, unique_chat_mode → `_modeOutcome`.

`_modeOutcome(l, mode, on, duration)`: on with a duration: slow → `chatModeSlowOn(duration: timeoutLength)`; followers with duration > 0 → `chatModeFollowersOn(duration: followAgeLength)`; else `chatModeChanged(mode: mode.name, state: on|off)`.

`moderationCommand(cmd)` — ICU key naming the command in failure lines: ban, timeout, untimeout/unban, warn, delete, clear, `<mode>On|Off` (`slowOn`, `followersOff`, `emoteOnlyOn`, `uniqueChatOff`…), announce, shoutout, mods/vips, mod/unmod, vip/unvip, leadmod/unleadmod, shieldOn/shieldOff, marker, commercial, raid, unraid, monitor/unmonitor, restrict/unrestrict.

`roleListLine(l, role, names)`: empty → `chatModRoleListEmpty(role: role.name)`; else the first `_maxListedNames = 30` names joined by `, `, `…` appended when there are more → `chatModModeratorList(count: total, names)` or `chatModVipList(count, names)`.

`moderationFailure(error, command)` (language on screen): `UnauthorizedException` → `chatModLogInAgain` (the login dialog also shows: the moderator scopes came with an app update); `_ViewerActionNotDone` → `viewerActionResult(status: outcome.name)`; `_BroadcasterOnly` → `chatModBroadcasterOnly(command: commandInChatLine(typed))`; `_NoSuchUser` → `chatModFailed(command, reason: chatModNoUser(login))`; `ApiException` 403 → `chatModFailed(command, reason: chatModCannotModerate)`; other `ApiException` → `chatModFailed(command, reason: chatErrorText(l, error))` (Twitch's message quoted, bounded by maxQuotedTwitchReason); anything else → `chatModFailedUnexpected(command)`.
Oracle: `test/screens/channel/chat/moderation_test.dart`, `test/screens/channel/chat/moderation_channel_commands_test.dart`, `test/screens/channel/chat/lead_mod_command_test.dart`.

### lib/screens/channel/chat/gift_bomb_tracker.dart

Follows mass sub gifts ("gift bombs": one `submysterygift` header USERNOTICE, then one `subgift` per recipient), decides which notices get a chat row and which bombs earn the pinned banner above chat. A pure helper fed by ChatStore with each USERNOTICE AFTER the chat delay (so the banner appears in step with the video).

`GiftBomb` (immutable): `key` (the id shared by header and gifts, `UserNotice.giftBombKey`), `gifterName` ('' when anonymous), `isAnonymous`, `gifter(l)` → `chatAnonymousGifter` or the name, `count` (announced number), `tier` (`Tier 1`/`Tier 2`/`Tier 3` or null), `received` (gifts arrived so far, default 0), `recipients` (first 100 names, default []), `collapsed` (gifts folded into the header row, decided once when the header arrives). `complete` = count > 0 && received ≥ count. `withGift(recipient)` → copy with received + 1 and the recipient appended (unmodifiable list) unless the recipient is null/empty or 100 names are kept already (still counted). Value `==` / `hashCode` including the recipients list; `toString` `GiftBomb(key, name|(anonymous), count, received)`.

`GiftBombBanner {bomb, startedAt, endsAt, ValueListenable<GiftBomb>? live}` — `total = endsAt − startedAt`; `id` = bomb.key, or `at-<startedAt ms>` when the key is empty (a header heard twice is ONE banner and stays dismissed). `live` follows the bomb as gifts arrive (null when the chat does not follow it).

`GiftBombDecision {show, header?, banner?}` (private constructor); constants `shown`, `suppressed`.

`Duration? bannerDuration(int count)`: < 5 → null (no banner); 5–24 → 10 s; 25–49 → 15 s; 50–74 → 20 s; 75–99 → 25 s; ≥ 100 → 30 s (Twitch's rule).

`GiftBombTracker`: `maxTracked = 100` bombs remembered (LRU), `maxRecipients = 100`, `collapseFrom = 5`. State `_bombs`: insertion-ordered `Map<String, ValueNotifier<GiftBomb>>` (least recently active first). `length`, `bomb(key)`, `watch(key)` (the notifier; a forgotten bomb's notifier stays with its holder, frozen).

`onNotice(notice, {collapse, channelId})`:
- Header (`notice.isMassGiftHeader`): GiftBomb(key ?? '', gifterName '' if anonymous else `readableNoticeName(displayName ?? login ?? '', login)`, count = `massGiftCount ?? 0`, tier, and — when the key is known and the bomb is ALREADY tracked (i.e. the same header heard twice) — that bomb's `received` / `recipients`; gifts that arrived before their first header were never tracked, so a fresh header starts at received 0, `collapsed = collapse && count >= 5`). Remembered if the key is non-null. Banner deserved iff `bannerDuration(count) != null`, not historical, and `sourceRoomId` null or equal to channelId (not another Shared Chat channel). Returns show = true, header = bomb, banner = bomb or null.
- Not a gift (`subGift` / `anonSubGift`), or no key, or untracked bomb → `shown`.
- Gift of a tracked bomb → remembers `bomb.withGift(readableNoticeName(recipientDisplayName ?? recipientLogin ?? '', recipientLogin))`; returns `suppressed` if the bomb is collapsed, else `shown`. A gift before its header is always shown (suppressing it would lose the event) and is NOT counted: nothing is remembered for an unknown key, so when the header arrives its `received` stays 0 (asserted by the test "a gift before its header counts towards it", whose comment says the gift was not tracked).
- `_remember(bomb)`: removes and re-inserts as most recent, reusing the existing notifier (listeners see the change); beyond 100 evicts the least recent.
`collapse` = setting `collapseGiftBombs` ("Collapse gift bombs"). Oracle: `test/screens/channel/chat/gift_bomb_tracker_test.dart`.
### lib/screens/channel/chat/stores/chat_store.dart

`ChatStore` (MobX, `ChatStoreBase with Store`, generated mixin `_$ChatStore` in `chat_store.g.dart`) — the store and view-model of ONE channel chat: the Twitch IRC WebSocket, the 7TV and BTTV event sockets, the chat delay sync, message list and buffering, history, moderation, slash commands, restrictions, autocomplete, notifications, shared chat, gift bombs, raids, sleep timer. It is the heart of the chat; everything else in this area plugs into it.

#### Top-level constants and types
- `emoteRefreshDelay = 3 s` — debounce before reloading the viewer's emotes after an entitlement change.
- `sharedChatBannerDuration = 15 s` — how long the "Shared Chat" banner stays.
- `typedef ChatUserCardRequest = ({String login, String id, String displayName})` — emitted on `userCardRequests` (opened by `/user` or a tap).
- `_messageLimit = 5000` — total messages kept; when exceeded `_messagesToRemove = 1000` (20 %) oldest are removed.
- `_renderMessageLimit = 100` — while autoscroll is on, only the newest 100 are rendered (`renderMessages`).
- `_delayBypassCommands = {USERSTATE, GLOBALUSERSTATE, ROOMSTATE, NOTICE}` — IRC commands applied immediately even when the chat delay is active (confirmations/state; NOTICE because rejections need instant feedback).
- Bottom bar geometry: `_baseBottomBarHeight = 68.0`, `_autocompleteHeight = 56.0` (row of chips with hairline), `_replyBarHeight = 41.0` (Container + Divider).
- `_maxTrackedNotices = 1000`; `_lineBreak = \r\n|\r|\n`; `_replyId = ^[A-Za-z0-9-]{1,64}$` (a reply parent id must match before it is put into an outgoing IRC tag — prevents IRC injection); `_secondsLeft = (\d+) (?:more )?seconds?`; `_meAction = ^[/.]me\s` case-insensitive.
- `_maxRetries = 5` (IRC reconnect attempts before giving up).

#### `splitDelayedIrc(String data)` (static, visible for testing)
Splits one IRC WebSocket frame into `(now, held)`: lines (split on `\r\n` after trimRight, empty skipped) that bypass the delay vs lines held by it; each part re-joined with `\r\n`. Line-by-line so a held message sharing a frame with a bypass line is not shown early. `_bypassesDelay(line)`: starts with `PING` → true (a late PONG costs the connection); tagged line (`@...`) → `parts[2]` (space-split) in `_delayBypassCommands`; untagged → `parts[1] == 'RECONNECT'` (about the connection, not chat).

`_chatDelaySeconds = settings.effectiveChatDelay.toInt()`; `_hasActiveChatDelay = settings.showVideo && _chatDelaySeconds > 0` (the delay only applies while the video is shown).

#### Injected dependencies (constructor fields)
`twitchApi`, `auth` (AuthStore), `chatDetailsStore`, `assetsStore` (ChatAssetsStore), `settings` (SettingsStore), `channelName` (login), `channelId`, `displayName`; optional `whispers` (WhisperStore, for /w), `chatHistory` (TwitchChatHistoryService — Twitch's recent chat shown on join), `viewerActions` (TwitchViewerActionsService — GQL viewer actions: pin, lead mod, acknowledge warning), `listenEvents` (EventSub topic listener), `mentionAlerts` (MentionAlerts — notifications for mentions while app in background; default the app's own), `chatRules` (ChatRulesStore), `_connectSocket` (factory `WebSocketChannel Function(Uri)`, injectable for tests). Mutable `confirmLeadModerator: Future<bool> Function(LeadModCommand)?` — UI confirmation dialog before /leadmod.

#### Controllers and private state
`textFieldFocusNode`, `scrollController`, `textController`; `toSend` (IRCMessage awaiting USERSTATE ack — the optimistic own message); `reactions` (MobX disposers); `_messageBufferTimer` (periodic flush); `messageBuffer` (ObservableList of lines waiting to be added); `_pendingChatCallbacks`, `_pendingSevenTVCallbacks`, `_pendingBttvCallbacks` (three `ChatDelayQueue`s); `_giftBombs` (GiftBombTracker); sockets `_channel`/`_channelListener` (IRC), `_sevenTVChannel`/`_sevenTVChannelListener`, `_bttvChannel`/`_bttvChannelListener`; `_shouldDisconnect` (true once disposing: every async continuation checks it and bails); `_retries`, `_backoffTime`, `_reconnectMessage` (the in-place "reconnecting" line), `_reconnectStartTime`; history: `_historyIds` (ids of history lines shown and history gifts folded into their bomb, so the same message arriving live is not shown/counted twice), `_historyPending = true`, `_moderationBeforeHistory` (CLEARMSG/CLEARCHAT received live while history loads, re-applied to it when it lands), `_trackedNoticeIds` (ids handed to the gift tracker, newest 1000); `_heldMessages` (HeldMessageWatcher); timers `_notificationTimer`, `_sendingTimeoutTimer`, `_chatDelayCountdownTimer`, `_restrictionTimer`, `_sharedChatBannerTimer`, `_emoteRefreshTimer`, `sleepTimer`; `_countdownMessage`, `_chatDelaySyncCompleted` (prevents the countdown reappearing when later latency updates arrive); restriction inputs `_banned`, `_timedOutUntil`, `_lastSentAt`, `_refusedFor`; `_runningCommand` (one slash command at a time — a double tap must not repeat a ban); `_acknowledging`; `_linesMarkedInPlace`; `_sawUnsharedMessage`, `_sharedChatAnnounced`; `_shoutoutIds`; `_globalEmoteSets`, `_userStateEmoteSets`; `_pendingArrival` (RaidArrival); `expandedGiftBombs` (Set, most recent last, max 100).

Broadcast streams exposed: `userCardRequests` (ChatUserCardRequest), `chatSettingsRequests` (void — open chat settings), `shoutoutRequests` (ShoutoutNotice — open the shoutout card), `modToolsRequests` (= `modTools.requests`, ModToolsView).

#### Observables / computed
- `timeRemaining` (Duration, sleep timer), readonly `_notification` (String? shown above chat), readonly `_messages` (ObservableList<IRCMessage>, oldest first), `renderMessages` (computed: all messages when autoscroll off or < 100, else last 100).
- readonly `_autoScroll = true`, `_inputText = ''`, `_showSendButton`, `_showEmoteAutocomplete`, `_showMentionAutocomplete`, `_isInSharedChatMode`, `_showSharedChatBanner`, `_sharedChatStartedNow`, `_isWaitingForAck`, `_isConnected`, `_hasConnected` (distinguishes "connecting" from "disconnected" in the UI), `_userState` (USERSTATE, const default), `_restriction` (ChatRestriction?), `_latestGiftBomb`, `_latestIncomingRaid`.
- `expandChat` (observable bool), `replyingToMessage` (IRCMessage?).
- `revealedMessageIds` (ObservableSet; `revealMessage(id)` action — deleted-message reveal), `revealedFilteredMessageIds` (`revealFilteredMessage(id)` — "Show message" on a chat-filter-masked message).
- `sharedChatPartners` (computed): when in shared chat mode, `assetsStore.sharedChatChannelIds` except this channel mapped through `assetsStore.channelIdToUserTwitch` (unknown ids skipped).
- `canModerate` = `_userState.mod || channelName == auth.user.details?.login`.
- `shieldModeActive` = `canModerate && modTools.shieldActive`.
- `matchingEmotes`: empty unless emote autocomplete shown; term = last space-separated word lowercased; empty → []; candidates in order user (Twitch) emotes, BTTV, FFZ, 7TV, filtered by `name.toLowerCase().contains(term)`.
- `matchingChatters`: empty unless mention autocomplete shown; term = last word without the first `@`, lowercased; `chatDetailsStore.chatUsers` containing term (sorted set order).
- `matchingCommands` = `matchCommands(_inputText, moderator: canModerate)`.
- `bottomBarHeight` = 68 + 41 if replying + 56 if `settings.autocomplete` and (emote matches shown & non-empty, or mention matches shown & non-empty, or command matches non-empty) + `restriction.barHeight` (28 or 48) when logged in and the restriction `showsBar`. Used to pad the message list.

#### `modTools` (late final)
`ModToolsStore(twitchApi, broadcasterId: channelId, listenEvents, showActionsInChat: () => settings.showModActionsInChat, onChatLine: _addModLine)`. `_addModLine(text, {actionLabel, onAction})` adds a notice line (with optional action button) to `messageBuffer` unless disconnecting. `_followModTools(moderatorId)`: null → `modTools.stop()`, else `modTools.start(moderatorId)` (unawaited) — called when the viewer becomes / stops being a moderator.

#### Gift bombs, arrivals, local notices
- `watchGiftBomb(key)` → tracker's notifier. `setGiftBombExpanded(key, expanded)`: removes key; if expanded re-adds as most recent; evicts the oldest beyond 100 (row expansion state must outlive rebuilt rows).
- `addArrivalNotice(RaidArrival)`: ignored when disposing; if the chat is not joined yet (`_messageBufferTimer == null`) it is parked in `_pendingArrival` (shown right after "Welcome to X's chat!"); else adds `IRCMessage.raidWelcome(arrival)` ("You followed X's raid").
- `addLocalNotice(text, {actionLabel, onAction})`: ONSET's own line (e.g. a celebration said quietly); added as a notice, through the delay queue when the delay is active (so it shows in step with the video), immediately otherwise; always inside `runInAction`.
- `addShoutout(ShoutoutNotice)`: deduped by id (`_shoutoutIds`); adds `chatShoutoutNotice(name: targetName)` with action `chatShoutoutView` that pushes the shoutout on `shoutoutRequests`.

#### Shared chat banner
`_announceSharedChat(message)` — first live (non-historical) PRIVMSG seen in shared-chat mode: sets `_sharedChatAnnounced`, `_sharedChatStartedNow = _sawUnsharedMessage` (a session that started while watching vs one already running at join — changes the banner wording), shows the banner and auto-hides it after 15 s. `dismissSharedChatBanner()` cancels the timer and hides it.

#### Moderation notices
`_addModerationNotice(clearChat, buffer)` adds `moderationNoticeLine(...)` with `hiddenLogins` = the viewer's blocked users' logins unless the viewer can moderate (moderators and the owner see notices of blocked people, as they see their messages), `newestFirst` = buffer reversed followed by `_messages` reversed. `_wordServerNotice(notice)` rewrites a NOTICE's text with `serverNoticeText(msg-id, text, L10n.current)`.

#### Restrictions
`_updateRestriction()` (action): cancels the timer; computes `chatRestriction(room: chatDetailsStore.roomState, privileged: canModerate || _userState.vip, subscriber: _userState.subscriber, now, banned, timedOutUntil, lastSentAt, refusedFor)`; if the result has `until`, schedules itself again at `until - now + 50 ms` (so the countdown banner disappears exactly when the wait ends).
`_forgetFollowRefusalWhenOpen()`: a sticky `followRequired` refusal is dropped when the room's followers-only is off (< 0).
`acknowledgeWarning(service)` (action): only when `_refusedFor == warned` and not already acknowledging; no web token → `signedOut`; calls `service.acknowledgeWarning(channelId, authToken)` (GQL); on `done` while still warned → clears `_refusedFor` and recomputes. Returns the outcome.
`_resetOwnRestrictions()`: clears banned, refusedFor, timedOutUntil, lastSentAt; recomputes.
`_applyRejection(msgId, message)`: an account refusal (`accountRestrictionOf`) → `_refusedFor = kind` and recompute. Else seconds from `_secondsLeft` in Twitch's text: `msg_banned` → `_banned = true`; `msg_timedout` with seconds → `_timedOutUntil = now + seconds`; `msg_slowmode` with seconds → `_lastSentAt = now + (seconds - slowModeSeconds)` (back-computes the last send so the countdown matches Twitch); otherwise nothing; then recompute.

#### Slash commands — `_runCommand(command, submitted)`
Lines are worded in the language currently on screen. `say(text)` adds a notice to `messageBuffer`. `done()` clears the input only if it still holds exactly `submitted` (not a draft typed meanwhile) and not disposing. `me` = viewer id.
- `SendAsIs` → return (caller sends it).
- `HelpCommand` → `chatHelpCommands(commands: usages joined ', ')` of kChatCommands plus kModeratorChatCommands when canModerate (usages in chat-line form) → done.
- `ModerationCommand` → `LeadModCommand` first asks `confirmLeadModerator` (no callback or false → return, input kept); `moderate(command)`; ok → done (a failed command keeps its text for another try).
- `UnsupportedCommand` → say its text (input kept).
- `WhisperCommand` → not logged in or no whisper store → `chatLogInToWhisper`. Else `getUser(login)` → `whispers.sendTo(userId, login, displayName, text)`; an error result → say `error.text(l)`; success → `chatWhisperSentNoReplies(name)` if `whispers.status == WhisperStatus.refused` (the viewer can send but not receive) else `chatWhisperSent(name)`, done. `NotFoundException` → `chatWhisperNoUser(login)`; `ApiException` → `chatWhisperFailedBecause(reason: chatErrorText)`; other → telemetry (`/w`) + `chatWhisperFailed`. All guarded by `_shouldDisconnect`.
- `UserCardCommand` → `_openUserCard(login, say)` then done. `_openUserCard`: `getUser` → emits `(login, id, displayName)` on `userCardRequests`; NotFound → `chatUserCardNoUser(login)`; other → `chatUserCardFailed(login)`.
- `DisconnectCommand` → done, then `_channel.sink.close(1000)` (normal close; reconnect logic then applies as for any close — see connection section).
- `ColorCommand` → not logged in → `chatLogInToChangeColor`; `twitchApi.updateUserChatColor(userId, color)` (Helix `PUT /chat/color`) → true: `chatColorChanged` + done; false: `chatColorFailedHex` (hex colours need Turbo/Prime).
- `Block`/`UnblockCommand` → `getUser`; blocking someone already in `auth.user.blockedUsers` → `chatAlreadyBlocked(name)` + done. Else `auth.user.block(targetId, displayName: user.login)` (the LOGIN is stored, because the chat filter compares logins) / `unblock(targetId)`; then verifies the list actually changed (the user store reports nothing) — mismatch throws; success → `chatBlockedUser(name)` / `chatUnblockedUser(name)` + done; any failure → `chatBlockFailed(login)` / `chatUnblockFailed(login)`.

#### Animated emotes callout
`_calloutAnimatedEmotes(message)`: once ever — on the first PRIVMSG containing an animated emote while `settings.animateEmotes` is on and `settings.animatedEmotesCalloutShown` is false: sets the flag true and adds notice `chatAnimatedEmotesCallout` with action `chatAnimatedEmotesCalloutShow` → `chatSettingsRequests`.

#### Viewer emote sets
`scheduleEmoteRefresh()`: needs logged-in and not disposing; restarts a 3 s timer that calls `_loadUserEmotes(_currentEmoteSets)`. `_currentEmoteSets` = union of GLOBALUSERSTATE sets and the latest USERSTATE `emote-sets` (USERSTATE alone if no global; global alone if no USERSTATE). `_noteEmoteSets(userState)`: if `emoteSetsChanged(previous, new)` → schedule refresh; remembers the new sets (keeps previous if tag absent). `_loadUserEmotes(setIds)`: first tries `assetsStore.userEmotesFromHelix(userId, broadcasterId)` (Helix `GET /chat/emotes/user`, includes follower emotes); if that returns true, done; otherwise falls back to `assetsStore.userEmotesFuture(emoteSets: setIds, headers: auth.headersTwitch)` (Helix `GET /chat/emotes/set`), errors logged → [].

#### `moderate(command, {userId})` → `ModerationOutcome?`
Not logged in → `(false, chatLogInToModerate)`. Else `ChatModeration(api, broadcasterId: channelId, moderatorId: me, setLeadModerator: _leadModeratorSetter).run(command, userId)` — Helix decides permissions (USERSTATE, behind canModerate, arrives after joining and misses someone modded meanwhile). Disposed meanwhile → null. On ok → `_noteModerated` (Shield → `modTools.noteShieldMode(on)`; Suspicion with known userId → `modTools.noteSuspicion(userId, on ? status : null)`). Adds the outcome line as a notice; for a successful `RoleListCommand` the notice carries action `chatModViewList` → `modTools.request(ModToolsView.moderators | vips)`. Returns the outcome.
`_leadModeratorSetter` → null without viewerActions; else calls `service.setLeadModerator(channelId, userId, granted, authToken: auth.twitchWebToken ?? '')`.

#### Pinning (GQL viewer actions)
`canPinMessages` = canModerate && viewerActions != null && a non-empty web token. `pinMessage(messageId)` / `unpinMessage(pinId)` → `_sayPinOutcome`: no service → null; sends with the web token; disposed → null; adds notice `chatModPinChanged(state: pinned|unpinned)` on done, else `viewerActionResult(status: outcome.name)`; returns outcome.

#### Constructor (order matters)
1. `chatRules?.attach(textFieldFocusNode)` then `chatRules.load()` — the rules show before the first message, like the official app.
2. Reaction on `auth.isLoggedIn` → `_channel.sink.close(1000)`: closing triggers the normal reconnect path, which re-joins with the new credentials (log in / log out reconnects chat).
3. Reaction (fireImmediately) on `(loggedIn ? userId : null, auth.token)` → `_watchHeldMessages(userId)`: disposes the previous watcher; with a listener and a user id creates `HeldMessageWatcher(broadcasterId: channelId, userId, onNotice: add notice to messageBuffer)`; an `ArgumentError` (non-numeric ids) is logged and ignored. Re-created per token (logging in again may grant a missing scope).
4. Reaction (fireImmediately) on `(loggedIn && canModerate ? userId : null, auth.token)` → `_followModTools`.
5. Reaction on `[showTwitchEmotes, showTwitchBadges, show7TVEmotes, showBTTVEmotes, showBTTVBadges, showFFZEmotes, showFFZBadges]` → closes the 7TV socket if 7TV off, BTTV socket if BTTV off; `getAssets()` then (re)subscribes: 7TV on and `sevenTvEmoteSetId` known → `listenToSevenTVEmoteSet`; BTTV on, `bttvChannelId` known and no socket → `listenToBttvChannel()`.
6. `assetsStore.onPersonalEmoteSetSeen = _watchPersonalEmoteSet`; reaction on `(show7TVBadges, show7TVPaints, show7TVPersonalEmotes, showBTTVPersonalEmotes, showFFZRoomBadges)` → `_configureCosmetics(resubscribe: true)`; initial `_configureCosmetics(resubscribe: false)`.
7. Reaction on `settings.showVideo`: shown and `effectiveChatDelay > 0` → `_startChatDelayCountdown()`; hidden → flush all three delay queues (`flushAll`), cancel the countdown, `_chatDelaySyncCompleted = false`.
8. Reaction on `settings.effectiveChatDelay`: becomes 0 → flush all, cancel countdown, sync not completed; else if `autoSyncChatDelay` and video shown and delay > 0 and the initial sync not completed → start the countdown (auto sync mode: the delay arrives once the player measures latency).
9. `assetsStore.init()`.
10. `_messages.add(notice chatConnecting)` ("Connecting to chat…").
11. `connectToChat()` FIRST, then `loadHistory()` (unawaited) — history is inserted above whatever live chat has shown by then, so it never holds the chat back.
12. Scroll listener: `pixels <= 0` → `_autoScroll = true`; `> 0` → false (the list is reversed: 0 = newest at the bottom).
13. Focus listener: gaining focus hides the emote menu (`assetsStore.showEmoteMenu = false`); losing focus sets `expandChat = false`.
14. Text listener: `_inputText = text`; `_showEmoteAutocomplete = !_showMentionAutocomplete && focused && lastWord.isNotEmpty` (computed with the PREVIOUS mention flag); `_showSendButton = text.isNotEmpty`; `_showMentionAutocomplete = focused && lastWord.startsWith('@')`.

#### Chat delay plumbing
`_enqueueDelayedCallback(queue, cb)` → `queue.add(cb, now: clock.now())` (package `clock`, so tests use fake time). `_flushDueDelayedCallbacks()` → `flushDue(now, Duration(seconds: _chatDelaySeconds))` on the chat, 7TV and BTTV queues — the delay read NOW (follows video latency; shrinks when the player catches up). `_flushPendingDelayedCallbacks()` → `flushAll` on all three.

#### IRC connection — `connectToChat({isReconnect = false})`
1. `getAssets()` (errors logged) — assets first so they are available for all messages.
2. Cancels the old listener. Held (delayed) payloads are KEPT across reconnects: each payload is whole (dropping a held CLEARMSG/CLEARCHAT would leave a deleted/timed-out message visible) and they release on schedule, in order.
3. Closes the old socket (1000) and opens `wss://irc-ws.chat.twitch.tv:443` via `_connectSocket`; arms the IRC watchdog.
4. Not a reconnect and delay active → `_startChatDelayCountdown()` (countdown only on initial connection / video toggle, never on reconnects).
5. Listener per frame: re-arm watchdog; delay inactive → `flushAll` the chat queue first (whatever is held goes first so nothing overtakes it) then `_handleIRCData(frame)`; delay active → `splitDelayedIrc`; `now` part handled immediately; `held` part enqueued as ONE callback.
6. `onError` → debugPrint + `Telemetry.recordError(reason: 'IRC WebSocket error')`.
7. `onDone` (async): cancel watchdog; `_isConnected = false`; cancel countdown; sync not completed. If disposing → close 7TV and BTTV sockets and stop. If `_retries >= 5` → `Telemetry.log('WebSocket reconnection failed after 5 attempts')`, remove the reconnect line, reset start time, add DIRECTLY to `_messages` (not the buffer, so it shows immediately) a notice `chatDisconnected` with action `chatReconnect` whose callback resets retries/backoff and calls `connectToChat(isReconnect: true)`; stop. Otherwise `_retries++`, `Telemetry.log('WebSocket reconnecting: attempt N/5')`. Backoff: the first retry is IMMEDIATE (catches brief hiccups); from the second, `_backoffTime` = 1, then doubled each time, capped at 8 s (sequence 0, 1, 2, 4, 8 s). The reconnect status line is ONE message updated in place (`updateReconnectMessage`: first call records `_reconnectStartTime` and appends; later calls replace at its index, or re-append if it was dropped by the limit cleanup). With backoff > 0: shows `chatReconnectingIn(seconds, attempt, max: 5)` and counts down each second (`Future.delayed(1 s)` loop); if disposed during the countdown the line is removed and it stops. Then `chatReconnecting(attempt, max: 5)`, cancel listener, `connectToChat(isReconnect: true)`.
8. Sends, in order: `CAP REQ :twitch.tv/tags twitch.tv/commands`, `PASS oauth:<auth.token>` (user token or the app token for anonymous), `NICK <login>` (or `justinfan888` when logged out), `JOIN #<channelName>`.

IRC watchdog: `ircSilenceLimit = 90 s` without any frame → sends `PING :tmi.twitch.tv`; then `ircPongLimit = 10 s` without a frame → `sink.close(4000)` (triggers onDone → reconnect). Every received frame re-arms it.

#### `_handleIRCData(data)` (action) — per CRLF-separated line
Tagged lines (`@...`) are parsed with `IRCMessage.fromString(line, userLogin: viewer login)` (the userLogin lets the model flag mentions):
1. PRIVMSG / USERNOTICE whose `id` is in `_historyIds` → skipped (already shown from history).
2. Sender login added to `chatDetailsStore.chatUsers`.
3. Blocked users filtered (unless `_userState.mod` or owner): any line whose `user` EXACTLY equals (case-sensitive, login only, no id match) a blocked user's `userLogin` is dropped — unlike history (`_hiddenSenders`), which lower-cases logins and also matches `user-id`.
4. Muted words: a line with text that is not a CLEARCHAT/CLEARMSG and `isMuted(text, settings.mutedWords, wholeWord: settings.matchWholeWord)` → dropped (only that line; the batch continues).
5. PRIVMSG → `assetsStore.noteChatter(user-id)` (for cosmetics lookups).
6. Switch:
   - **PRIVMSG / NOTICE / USERNOTICE**: if NOTICE while waiting for ack and its msg-id `isSendRejection` → cancel the 10 s send timer, clear waiting/toSend (the input text is preserved for retry), only when the NOTICE carries text: `HapticFeedback.heavyImpact()` + `updateNotification(serverNoticeText(...))`; always `_applyRejection(msgId, text)`. Any NOTICE text is localized (`_wordServerNotice`). Shared chat: `_isInSharedChatMode = tags contains 'source-room-id'`; in shared mode → `_announceSharedChat`; a PRIVMSG outside it sets `_sawUnsharedMessage`. On the transition into shared mode → `assetsStore.fetchSharedChatAssets(channelId, headers, error handlers, show* flags)`. USERNOTICE: `_trackGiftBomb` decision; `hidden = settings.hideGiftSubNotices && notice.isGiftNotice`; if the decision has a banner and not hidden → `_latestGiftBomb = banner`; `IncomingRaid.fromNotice` → `_latestIncomingRaid`; not shown or hidden → skip the line. Then `alertChatMention(message, enabled: settings.mentionNotifications, ownLogin, channelId, channelLogin, channelName: displayName, alerts: mentionAlerts ?? MentionAlerts.shared)` (unawaited — background notification for mentions), add to `messageBuffer`, `changesOwnEmotes` → `scheduleEmoteRefresh()`, `_calloutAnimatedEmotes`.
   - **CLEARCHAT**: if history pending, remembered in `_moderationBeforeHistory`; `IRCMessage.clearChat(messages, bufferedMessages: messageBuffer, ircMessage)` — whole-chat clear (no trailing) empties both lists and adds `chatClearedByModerator`; targeted → every line of that user (in list and buffer) gets command CLEARCHAT and the `ban-duration` tag; returns whether something changed → `_linesMarkedInPlace = true`. If canModerate → `modTools.noteClearChat(target-user-id, ban-duration int)`. If `settings.showModerationNotices` → `_addModerationNotice`. `ownClearChat(...)` → sets `_banned`/`_timedOutUntil` and recomputes the restriction.
   - **CLEARMSG**: remembered if history pending; `IRCMessage.clearMessage` marks the line with `target-msg-id` as CLEARMSG (list and buffer) → `_linesMarkedInPlace`; `ownDeletedMessageNotice` → add notice.
   - **ROOMSTATE**: `chatDetailsStore.roomState = roomState.fromIRCMessage(msg)` (merges partial updates); `_forgetFollowRefusalWhenOpen`; `_updateRestriction`; `continue` (no limit bookkeeping).
   - **USERSTATE**: `_userState = _userState.fromIRCMessage(msg)`; `_noteEmoteSets`. If `toSend` is pending, this USERSTATE confirms the send (even without an `id` tag): `toSend.tags['id']` = the tag or fallback `local-<ms>`, `toSend` added to the buffer, cleared; cancel the 10 s timer, waiting = false, `textController.clear()`, `replyingToMessage = null`, `_banned = false`, `_refusedFor = null`, `_lastSentAt = now` (slow mode counts from now). Recompute restriction.
   - **GLOBALUSERSTATE**: `_globalEmoteSets` = `emote-sets` split; `_loadUserEmotes(setIds)`; continue.
   - **none** (unknown command): debugPrint; continue.
7. After a buffered line: when autoscroll is off OR the app is in background and `messageBuffer.length >= 1000`, the buffer is moved into `_messages` (prevents unbounded memory). When `_messages.length >= 5000`, the oldest 1000 are dropped (`_messages = sublist(1000)` — a NEW observable list).
Untagged lines: every untagged line other than the two below is ignored — notably `:tmi.twitch.tv RECONNECT` is NOT acted on explicitly (it only bypasses the delay); Twitch then closes the socket and the normal onDone reconnect runs; JOIN/353/366/CAP ACK lines are ignored. Exactly `PING :tmi.twitch.tv` → reply `PONG :tmi.twitch.tv` and return (rest of the frame ignored); a line containing `Welcome, GLHF!` (001 welcome) → new connection: `_resetOwnRestrictions()`; add notice `chatWelcome(name: getReadableName(displayName, channelName))`; flush a pending raid arrival (`IRCMessage.raidWelcome`); (re)start the 200 ms periodic `addMessages` timer (cancelled immediately if in background); subscribe 7TV (if enabled, set id known, not disposing) and BTTV (if enabled and BTTV channel id known); if a reconnect line exists, replace it in place with `chatReconnected(attempts: retries, seconds: elapsed)`; reset retries and backoff; `_isConnected = _hasConnected = true`.

#### `getAssets()` (action)
`assetsStore.assetsFuture(channelId, headers: auth.headersTwitch, onEmoteError → [] (logged), onBadgeError → [], showTwitchEmotes, showTwitchBadges, show7TVEmotes, showBTTVEmotes, showBTTVBadges, showFFZEmotes, showFFZBadges)`; in shared chat mode also `fetchSharedChatAssets(..., force: true)` in parallel (`Future.wait`).

#### `addMessages()` (action, every 200 ms)
`_flushDueDelayedCallbacks()` first. Reads and resets `_linesMarkedInPlace`. If autoscroll is off or the buffer is empty: if lines were marked in place, `_messages = ObservableList.of(_messages)` (a NEW list instance so the UI redraws in-place moderation marks within 200 ms even on a quiet chat, once per flush however many marks — a ban wave); return. Else append the whole buffer to `_messages` and clear it. (While scrolled up, new lines wait in the buffer so the list does not shift under the finger.)

#### `resumeScroll()` (action)
`_autoScroll = true`, `scrollController.jumpTo(0)`, and again in a post-frame callback (a message added in the same frame).

#### Chat delay countdown
`_cancelChatDelayCountdown()`: cancels the periodic timer and removes `_countdownMessage` from the list.
`_startChatDelayCountdown()`: cancel previous; flush the buffer into `_messages` (so the countdown sits at the bottom); `remaining = _chatDelaySeconds`; adds notice `chatSyncIn(seconds: remaining)`; every 1 s (in `runInAction`): remaining--; if the countdown message vanished (limit cleanup) → stop; if remaining > 0 replace it in place with the new count; else remove it, `_chatDelaySyncCompleted = true`, stop.

#### 7TV EventAPI — `listenToSevenTVEmoteSet({emoteSetId})` (action)
Closes the previous socket, clears subscribed sets; captures `generation = _sevenTvGeneration`; opens `wss://events.7tv.io/v3`; `_sevenTvActiveSetId = emoteSetId`. `_sevenTvHealthyTimer` = after `thirdPartyHealthyAfter` (60 s) connected, `_sevenTvRetries = 0`. Watchdog: `sevenTvSilenceLimit` 75 s without any frame → `sink.close(4000)` (7TV sends heartbeats). Each frame re-arms the watchdog; no active delay → flush the 7TV queue and handle now; else enqueue. `onError` → log + telemetry (`7TV WebSocket error`). `onDone`: ignored if the generation changed (a deliberate close) or 7TV disabled; else stop timers, null the socket and schedule a reconnect after `_thirdPartyBackoff(_sevenTvRetries++)` that re-listens with the `emoteSetId` ARGUMENT captured by that listen call — NOT `_sevenTvActiveSetId` (so after a `user.update` set switch, a dropped socket reverts the active set id to the original set; see Known Android defects). Every listen call clears `_sevenTvSubscribedSets` and resubscribes only the active set: personal sets subscribed earlier are not resubscribed (their first-sighting callback never fires again), so personal-set live edits stop after any reconnect, cosmetics toggle or provider-setting change.
Subscriptions (op 35 frames `{"op":35,"d":{"type":T,"condition":C}}` via `SevenTVEvent`/`SevenTVEventData`): `emote_set.update` `{object_id: setId}`; `user.update` `{object_id: sevenTvUserId}` when known (the broadcaster switching their active set); when any of show7TVBadges/Paints/PersonalEmotes is on: `cosmetic.create`, `entitlement.create`, `entitlement.delete` with `{ctx: 'channel', platform: 'TWITCH', id: channelId}`.
`_watchPersonalEmoteSet(setId)` (called by assetsStore when a chatter's personal set is first seen): only with an open socket, fewer than `_maxSevenTvSetSubscriptions = 100` sets, and a new id → subscribe `emote_set.update` for it.
`_thirdPartyBackoff(attempt)`: ceiling = min(60, 2^min(attempt,6)) seconds; jitter factor 0.5–1.0 (`thirdPartyJitter`, a replaceable `Random` for tests); result = ceiling × 1000 × factor ms (attempt 0 → 0.5–1 s, 1 → 1–2 s, … 6+ → 30–60 s).
`_closeSevenTvChannel()`: generation++, cancel retry timer, stop timers, cancel listener, close (1000), null.
`_onSevenTvEvent(data)`: JSON decode (FormatException → ignore); `SevenTvDispatch.parse` (only `op == 0` dispatches): `emote_set.update` for the ACTIVE set → `_applyChannelSevenTvChange`; for another set → `assetsStore.applyPersonalEmoteSetChange`; `user.update` → `_switchSevenTvSet`; `cosmetic.create` → `assetsStore.defineSevenTvCosmetic`; `entitlement.create/delete` → `assetsStore.applySevenTvEntitlement`; null → ignore.
`_applyChannelSevenTvChange(change)`: actor name = `getReadableName(actor.displayName, actor.username)` or `chatSevenTvSomeone`. For each removed name: `removeChannelEmote(name)` + announce `chatSevenTvEmoteRemoved(name: actor, emote)`; each rename: remove old name, add new `Emote.from7TV(emote, sevenTVChannel)` if its url non-empty, announce `chatSevenTvEmoteRenamed(name, old, emote)`; each added: add + `chatSevenTvEmoteAdded(name, emote)`.
`_switchSevenTvSet(change)`: ignored unless it is the channel owner's 7TV user and a different set; `assetsStore.switchSevenTvSet(setId)` must succeed and the socket still be open; then sets active id, subscribes it if new, announces `chatSevenTvEmoteSetSwitched(name, set: setName)`.
`_configureCosmetics({resubscribe})`: `assetsStore.configureCosmetics(sevenTvBadges, sevenTvPaints, sevenTvPersonalEmotes, bttvPersonalEmotes, ffzRoomBadges)`; with resubscribe, 7TV on, an open socket and a set id → `listenToSevenTVEmoteSet` again (to add/remove cosmetic subscriptions).
`_announceEmoteChange(text)`: only when `settings.showEmoteChangeNotices`; adds a notice.

#### BTTV socket — `listenToBttvChannel()` (action)
Closes previous; generation captured; opens `wss://sockets.betterttv.net/ws`; each frame resets `_bttvRetries = 0` and is handled now or enqueued (same delay rule). `onError` logged. `onDone`: ignored if generation changed or BTTV off; else nulls and retries after `_thirdPartyBackoff(_bttvRetries++)`. Sends `{"name":"join_channel","data":{"name":"twitch:<channelId>"}}`. No watchdog for BTTV.
`_onBttvEvent(data)`: JSON decode; `BttvSocketEvent.parse(decoded, channelId)` (`emote_create`/`emote_update`/`emote_delete` only for `data.channel == 'twitch:<channelId>'`; `lookup_user` for any): created → `Emote.fromBTTV(emote, bttvChannel)` added + `chatBttvEmoteAdded(emote)`; updated(id, code) → `renameChannelEmote(where: provider id matches and type bttvChannel/bttvShared, to: renamed(code))` and if the old name differs → `chatBttvEmoteRenamed(old, emote)`; deleted(id) → `removeChannelEmoteWhere`; only when it returned an emote → `chatBttvEmoteRemoved(emote)` (an unknown id says nothing); `BttvProUser` → `assetsStore.applyBttvProUser` (BTTV Pro personal emotes/badges).

#### Sending — `sendMessage(message)` (action)
1. Empty → return.
2. `chatRules?.gate()` true → return (the rules dialog must be accepted first; text stays).
3. More than `kChatMessageMaxLength` (500) grapheme characters → notification `chatMessageTooLong(max: 500)` (code-set text skips the input's own limit).
4. `parseChatCommand`: not SendAsIs → if a command is running → notification `chatWaitCommand`; else mark running and `_runCommand(command, message).whenComplete(running = false)`; return.
5. Waiting for ack → `HapticFeedback.mediumImpact()` + `chatWaitMessage`; return.
6. Socket null or closed (`closeCode != null`) → notice `chatCannotSendDisconnected` in the buffer; return.
7. `_isWaitingForAck = true`. Reply id = `replyingToMessage.tags['id']` only if it matches `_replyId`. Sends `@reply-parent-msg-id=<id> PRIVMSG #<channel> :<message>` (prefix only when replying) or `PRIVMSG #<channel> :<message>`. Input text and reply state are NOT cleared now (only on USERSTATE confirmation) so a rejected message (slow mode…) keeps its text.
8. 10 s safety timer: if still waiting → clear waiting/toSend, heavy haptic, notification `chatMaybeNotSent`.
9. Optimistic local copy: from `_userState.raw` (the last USERSTATE line, which carries the viewer's badges/colour/display-name tags): for `/me` or `.me ` (`_meAction`) appends ` :\x01ACTION <message without its first 3 chars, trimmed>\x01`; else ` :` + (`@<reply display-name> ` when replying) + trimmed message. Parsed into an IRCMessage; `localEmotes` gets the viewer's Twitch emotes (`userEmoteToObject`) so their own emotes render; `user-id` set; reply tags `reply-parent-msg-id`, `reply-parent-display-name`, `reply-parent-msg-body` when replying; `tmi-sent-ts` defaulted to now (merged-mode sorting). Stored in `toSend` until USERSTATE confirms it. With no USERSTATE yet (`raw` null) no local copy is made.

#### `addEmote(emote, {autocompleteMode = false})` (action)
Empty input or ending in space → append `name + ' '`; autocomplete mode while emote autocomplete is shown → replace the last word with `name + ' '`; else append `' ' + name + ' '`. Moves the emote to the front of `assetsStore.recentEmotes` (removing any same name+type). Cursor to end.

#### Notifications
`updateNotification(text)`: cancels the previous timer (no flicker on repeated copies), sets `_notification`, clears it after **5 s** (the comment says 3 s; the code is 5 s). `clearNotification()` clears now.

#### Sleep timer
`updateSleepTimer({duration, onTimerFinished})`: cancels an existing one, `timeRemaining = duration`, periodic 1 s: at 0 s → cancel and `onTimerFinished()` (closes the player/app); else decrement by one second. `cancelSleepTimer()` → cancel and reset to zero.

#### History
`markHistorical(line)` (static): untagged → `@historical=1 <line>`; tagged: if every `historical` tag already equals `historical=1` (and at least one exists) → unchanged; otherwise removes every `historical`/`historical=*` tag and empty tags and prefixes `historical=1` (`@historical=1;rest tail`) — a line can never pass for live.
`_hidesGift(notice)` = `settings.hideGiftSubNotices && notice.isGiftNotice`.
`_trackGiftBomb(message, notice)`: remembers its id in `_trackedNoticeIds` (newest 1000, FIFO eviction), then `_giftBombs.onNotice(notice, collapse: settings.collapseGiftBombs, channelId)`.
`_hiddenSenders`: empty for a moderator/owner; else blocked users' lowercase logins and ids.
`_muted(text)` = isMuted with the muted-words settings.
`loadHistory()` (visible for testing): `_twitchHistory()`; if null and `settings.showRecentMessages` ("Fallback chat history (third-party)") → `_recentMessagesHistory()`; non-empty → `_insertHistory`. Any error → `debugPrint('Chat history not shown: <type>')` (type only, never content). Finally `_historyPending = false` and clear `_moderationBeforeHistory`. History goes in ONE insert above everything, never through the live path: no delay, no held messages, sounds, mentions or other notices, raid/celebration/gift/hype pins, restrictions or moderation reactions.
`_twitchHistory()`: needs the service and a non-empty twitch.tv web token (`auth.twitchWebToken`) else null; `service.getRecentMessages(channelLogin, channelId, authToken)` — errors → null; empty → null; else `chatHistoryLines(..., viewerLogin, hidden logins/ids, muted)`.
`_recentMessagesHistory()`: `twitchApi.getRecentMessages(userLogin)` (`GET https://recent-messages.robotty.de/api/v2/recent-messages/<login>` → `messages` array of raw IRC strings); errors → null. `shown` = ids in `_messages` + buffer + `_trackedNoticeIds`. Every string chunk is split on any line break (`\r\n|\r|\n`, so an embedded break cannot smuggle a second command into a tag), each line marked historical and parsed (unparseable skipped); already-shown ids skipped; sender added to chatters; hidden senders skipped. PRIVMSG/NOTICE/USERNOTICE: muted → skip; NOTICE localized; USERNOTICE through the gift tracker — folded into its bomb or hidden gift → its id added to `_historyIds` (so the live copy is not counted again) and skipped; else appended to the batch. CLEARCHAT → `IRCMessage.clearChat` on the batch, plus a moderation notice line when `showModerationNotices`. CLEARMSG → `clearMessage` on the batch. Others ignored. Empty batch → null. (A historical bomb never earns the banner — the tracker checks `isHistorical`.)
`_applyModerationBeforeHistory(lines)`: replays each remembered live moderation on the history lines: CLEARMSG → mark deleted; targeted CLEARCHAT → mark timed-out/banned; whole-chat CLEARCHAT → keep only lines with `tmi-sent-ts` strictly after the clear's `tmi-sent-ts` (no timestamp on the clear → drop everything).
`_insertHistory(lines)` (action): `history.insertHistory(_messages, applied, alsoShown: messageBuffer)`; each fresh line's id → `_historyIds`, sender → chatters; if `_messages.length >= 5000` → keep only the newest `5000 - 1000` = 4000 (`sublist(length - 5000 + 1000)`).

#### Background / resume
`handleAppBackground()`: `_inBackground = true`, cancel the 200 ms timer (lines accumulate in the buffer; the 1000-line overflow rule moves them into the list). `handleAppResume()`: only if in background; if the timer was ever started and not disposing → `addMessages()` immediately and restart the 200 ms timer.

#### `dispose()`
`_shouldDisconnect = true`; clears the chat and 7TV delay queues (the BTTV queue is not explicitly cleared — harmless since its socket closes; replicate or fix consciously); cancels buffer, notification, sending, restriction timers, countdown, sleep timer; closes the three broadcast controllers; cancels shared-chat-banner and emote-refresh timers; disposes the held-message watcher, `modTools`, `chatRules`; cancels IRC watchdog and listener; closes IRC (1000), 7TV, BTTV; runs all reaction disposers; disposes focus node, text and scroll controllers, `assetsStore`, `chatDetailsStore`.

`unfocusInput()` / `safeRequestFocus()` actions toggle the input focus.

Oracle tests for this store: `test/screens/channel/chat/stores/chat_store_delay_test.dart`, `test/screens/channel/chat/stores/chat_store_emotes_test.dart`, `test/screens/channel/chat/stores/chat_store_history_test.dart`, `test/screens/channel/chat/stores/chat_store_mod_tools_test.dart`, `test/screens/channel/chat/stores/chat_store_moderation_redraw_test.dart`, `test/screens/channel/chat/stores/chat_store_notices_test.dart`, `test/screens/channel/chat/stores/chat_store_raids_test.dart`, `test/screens/channel/chat/stores/chat_store_socket_watchdog_test.dart`, `test/screens/channel/chat/stores/chat_store_third_party_live_test.dart`.
### lib/screens/channel/chat/stores/chat_assets_store.dart

`ChatAssetsStore` (MobX, generated `chat_assets_store.g.dart`) — per-chat emotes, badges, cheermotes, recent emotes, the viewer's own Twitch emotes by section, Shared Chat participants, and third-party cosmetics (7TV badges / paints / personal emotes, BTTV Pro personal emotes, FFZ room badges). Global assets (Twitch global emotes and badges, 7TV / BTTV / FFZ globals, FFZ and BTTV user badges, the 7TV cosmetics lookup service) live in the app-wide `GlobalAssetsStore` (`lib/stores/global_assets_store.dart`) and are merged here.

`abstract final class UserEmoteSection` — KEYS (not text; the emote menu localizes them) of the non-channel sections of `userEmoteSectionToEmotes`: `channel = 'Channel Emotes'`, `global = 'Global Emotes'`, `unlocked = 'Unlocked Emotes'`, `other = 'Other Channels'`. Any other key is a channel's display name (its sub/follower emotes the viewer owns).

Dependencies: `twitchApi`, `bttvApi` (`https://api.betterttv.net/3/cached`), `ffzApi` (`https://api.frankerfacez.com/v1`), `sevenTVApi` (`https://7tv.io/v3`), `globalAssetsStore`.

**State**
- `ffzRoomInfo` (RoomFFZ? — custom FFZ mod/VIP badges and per-user room badge ids); the setter also caches `_ffzRoomBadgeIdsByUser = room.badgeIdsByUser`. `ffzRoomBadgesFor(userId)` → null unless `showFfzRoomBadges`, the user id is known, the user has ids and `globalAssetsStore.ffzBadgeDefinitions` is loaded; returns the defined badges in id order (unknown ids skipped), null if none. Getter `ffzRoomBadges` = room info only when the setting is on.
- `sevenTvEmoteSetId`, `sevenTvUserId` (the channel owner's 7TV user), `bttvChannelId` (set when BTTV channel emotes loaded — tells ChatStore the BTTV socket can join).
- Shared chat: `_loadedSharedChannelIds`, `sharedSevenTvSetIds` (ObservableMap broadcasterId → setId), `channelIdToUserTwitch` (ObservableMap id → UserTwitch), `sharedChatChannelIds` (ObservableList).
- readonly `_recentEmotes` (ObservableList<Emote>), `_channelEmoteToObject` (ObservableMap name → Emote: channel emotes of every provider plus Shared Chat participants'), `_channelTwitchBadges` (Map id → ChatBadge), `_cheermotes` (default `Cheermotes.empty`), `_userEmoteToObject` (name → Emote, the viewer's usable Twitch emotes), `_userEmoteSectionToEmotes` (section key → list).
- Cosmetics: `_userTo7TVBadges` (ObservableMap userId → [badge]), `userTo7TVPaint` (ObservableMap userId → NamePaint), `userToPersonalEmotes` (ObservableMap userId → (name → Emote), merged BTTV + 7TV personal), `_sevenTvPaintDefinitions`, `_sevenTvBadgeDefinitions` (cosmetic id → definition), `_sevenTvPersonalSetOwners` (setId → Set<userId>), `_bttvPersonalEmotes`, `_sevenTvPersonalEmotes` (userId → map), `_lookedUpChatters` (Set). Flags `showSevenTvBadges`, `showSevenTvPaints`, `showSevenTvPersonalEmotes`, `showBttvPersonalEmotes`, `showFfzRoomBadges` (default true; set by `configureCosmetics`). Callback `onPersonalEmoteSetSeen` (ChatStore subscribes that set on the 7TV socket). `perUserCapacity = 4000`.
- `showEmoteMenu` (observable bool, false).
- Pass-throughs: `userToFFZBadges` = global `ffzBadges`; `userToBTTVBadges` = global `bttvBadges`; `userTo7TVBadges`; `paintFor(userId)`; `personalEmotesFor(userId)`; `sevenTvPersonalSetIds`.

**Computed and PRIORITY (rendering depends on it)**
- `emoteToObject` = copy of `globalAssetsStore.globalEmoteMap`, then `addAll(_channelEmoteToObject)` → a CHANNEL emote beats a GLOBAL emote with the same name.
- Within channel emotes loaded by `assetsFuture`, the provider lists are concatenated in the order Twitch channel, 7TV, BTTV, FFZ (enabled providers only) and folded into a name-keyed map, so on a name collision the LATER provider wins: **FFZ > BTTV > 7TV > Twitch channel**. Live additions (`addChannelEmote`) overwrite; `replaceSevenTvChannelEmotes` uses putIfAbsent (a 7TV set switch never displaces another provider's emote of the same name). Shared Chat participants' emotes overwrite by name. Per-user personal emotes: 7TV personal overrides BTTV personal. (How personal, channel and native Twitch emote ids combine at render time is in the message renderer, out of this area.)
- `twitchBadgesToObject` = global Twitch badges overridden by channel badges.
- `bttvEmotes` (bttvChannel / bttvGlobal / bttvShared), `ffzEmotes` (ffzChannel / ffzGlobal), `sevenTVEmotes` (sevenTVChannel / sevenTVGlobal) — filters of `emoteToObject.values`; helpers `isBTTV`, `isFFZ`, `is7TV`.

**`init()`** (action): reads SharedPreferences key `recent_emotes` (StringList of JSON-encoded Emote) into `_recentEmotes` (empty if absent); installs an `autorun` that, on every change, removes the LAST (oldest) when the list is longer than **48** and writes the list back to `recent_emotes`. `dispose()` disposes the autorun.

**`assetsFuture({channelId, headers, onEmoteError, onBadgeError, show… flags})`** (action), all in parallel:
1. `globalAssetsStore.ensureLoaded(flags)` (cached across all tabs, fetched once).
2. Channel emotes: Twitch `getEmotesChannel(id)` (Helix `GET /chat/emotes?broadcaster_id=`) — also stored as section `Channel Emotes`; 7TV `getChannel(id)` (`GET https://7tv.io/v3/users/twitch/<id>`) — stores `sevenTvEmoteSetId` and `sevenTvUserId`; BTTV `getEmotesChannel(id)` (`GET /users/twitch/<id>`) — sets `bttvChannelId = channelId`; FFZ `getRoomInfo(id)` (`GET /room/id/<id>`) → `(RoomFFZ, emotes)`, stores `ffzRoomInfo`. Each failure → `onEmoteError` (→ []). The result REPLACES `_channelEmoteToObject` (new observable map).
3. Cheermotes `getCheermotes(broadcasterId)` (Helix `GET /bits/cheermotes`) — failure logged, `Cheermotes.empty` (cheers stay text).
4. When `showTwitchBadges`: `getBadgesChannel(id)` (Helix `GET /chat/badges`) → `_channelTwitchBadges`; failure → onBadgeError.

**Shared chat**
`fetchSharedChatAssets({channelId, headers, onEmoteError, onBadgeError, flags, force = false})`: `force` clears the loaded set and `sharedSevenTvSetIds`; `populateSharedChatParticipants` → new ids; none → return; for each new id in parallel `_fetchEmotesForChannel` (Twitch; 7TV `getEmotesChannel` → `(setId, emotes)` storing `sharedSevenTvSetIds[id]`; BTTV; FFZ — each erroring to []) merged into `_channelEmoteToObject` by name, and when `showTwitchBadges` `_fetchBadgesForChannel` (merged into the channel badges; errors → onBadgeError).
`populateSharedChatParticipants({channelId, onBadgeError})`: `getSharedChatSession(broadcasterId)` (Helix `GET /shared_chat/session`); error → onBadgeError, []; null session → clears `sharedChatChannelIds`, []; else replaces `sharedChatChannelIds` with the deduped participant broadcaster ids; ids not loaded yet are returned and their profiles fetched concurrently (`getUser(id)` → `channelIdToUserTwitch[id]`; errors → onBadgeError).

**The viewer's emotes**
`userEmotesFromHelix({userId, broadcasterId})` → bool: `getUserEmotes` (Helix `GET /chat/emotes/user?user_id=&broadcaster_id=`, needs `user:read:emotes`, includes this channel's follower emotes); error → false (caller falls back to emote sets). Owner ids = owners of "owned" emotes (`_ownedSection`: type twitchSub or twitchFollower and owner ≠ 'twitch') matching `^[0-9]{1,20}$`; `getUsersByIds` (Helix `GET /users?id=…`) → id → displayName (failure → the channels are just not named). Sections start with the existing `Channel Emotes` section (if loaded); each emote goes to: owned → owner display name, or `Other Channels` when unnamed; type twitchGlobal or owner 'twitch' → `Global Emotes`; else → `Unlocked Emotes`. Replaces the sections and `_userEmoteToObject`. Returns true.
`userEmotesFuture({emoteSets, headers, onError})` (fallback): `getEmotesSets(setId)` (Helix `GET /chat/emotes/set?emote_set_id=`) for every set in parallel (errors → onError). Per non-empty set, by its FIRST emote's type: twitchSub owned by 'twitch' (Turbo / monkey sets) → Global; twitchSub otherwise → section named by `getUser(id: ownerId).displayName` (awaited one by one, NOT caught: one failed owner lookup aborts the whole fallback — no sections, remaining emotes not added — and surfaces as an uncaught async error because `_loadUserEmotes` is unawaited; see Known Android defects); twitchGlobal → Global; twitchUnlocked → Unlocked; other types are not sectioned. Every emote also goes into `_userEmoteToObject`. Final sections = existing `Channel Emotes` followed by the new ones.

**Recent emotes and live edits**: `removeRecentEmote(emote)` (same name and type). `addChannelEmote(emote)` / `removeChannelEmote(name)`. `renameChannelEmote({where, to})` → removes the first matching entry, inserts `to(entry)` under its new name, returns the OLD emote (null if none). `removeChannelEmoteWhere(where)` → the removed emote or null. `switchSevenTvSet(setId)` → `sevenTVApi.getEmoteSet(id, type: sevenTVChannel)` (`GET /emote-sets/<id>`); error → false; else `replaceSevenTvChannelEmotes` (drop every sevenTVChannel emote, putIfAbsent the new ones) and `sevenTvEmoteSetId = setId`; true.

**Cosmetics**
`configureCosmetics({sevenTvBadges, sevenTvPaints, sevenTvPersonalEmotes, bttvPersonalEmotes, ffzRoomBadges})` (action): stores the flags; clears the badge map / paint map / 7TV personal / BTTV personal stores for every one turned off; `_refreshPersonalEmotes()`; when any 7TV lookup is wanted, re-runs `noteChatter` for every chatter looked up before (clearing the set first) so turning a cosmetic back on fetches again.
`noteChatter(userId)`: ignored for null/empty ids or when no 7TV cosmetic is wanted; once per user (`_lookedUpChatters`); `globalAssetsStore.sevenTvCosmetics.lookup(userId)` (7TV v4 GQL `https://7tv.io/v4/gql`, batched by the global service) → `_applySevenTvCosmetics`.
`_applySevenTvCosmetics(userId, cosmetics)` (action): badge (if enabled) → `_setBadge` (replaced only when different; remove + insert keeps recency order); paint (if enabled and `paint.isDrawable`) → `_setPaint`; trim; personal set (if enabled) → `_ownPersonalSet` (the first sighting of a set calls `onPersonalEmoteSetSeen`) and store that user's personal emotes by name, refresh.
`defineSevenTvCosmetic(cosmetic)`: remembers the paint and/or badge definition by cosmetic id (`cosmetic.create`).
`applySevenTvEntitlement(entitlement)` (`entitlement.create/delete`, keyed by Twitch user id): badge → granted with a known definition → set + trim; revoked → remove; paint → granted, known and drawable → set + trim; revoked → remove; emoteSet → revoked: remove the user from the set's owners, drop their personal emotes, refresh; granted: own the set, fetch `sevenTvCosmetics.emoteSet(refId)` and (if still enabled) store + refresh. Each kind is a no-op when its setting is off.
`applyPersonalEmoteSetChange(change)` (7TV `emote_set.update` of a personal set): needs known owners and the setting on; invalidates the cached set (`forgetEmoteSet`); for each owner applies removed, renamed (new `sevenTVPersonal` emote if its url is non-empty) and added emotes, then refresh.
`applyBttvProUser(user)`: only when BTTV personal emotes are on; not pro or no emotes → drop; else replace with `code → Emote.fromBTTV(emote, bttvPersonal)`; refresh that user (key `providerId` = Twitch user id).
`_refreshPersonalEmotes([onlyUserId])`: for that user (or every user of any personal map) merges `{BTTV personal if on, then 7TV personal if on}`; empty → remove; different from the current (`mapEquals`) → remove and re-insert; then trim.
`_trimPerUserMaps()`: each per-user map (`_sevenTvPersonalEmotes`, `_bttvPersonalEmotes`, `userToPersonalEmotes`, `_userTo7TVBadges`, `userTo7TVPaint`) and `_lookedUpChatters` capped at 4000 entries, evicting the oldest inserted first.
Oracle: `test/screens/channel/chat/stores/chat_assets_store_cosmetics_test.dart`, `test/screens/channel/chat/stores/chat_assets_store_user_emotes_test.dart`, `test/screens/channel/chat/stores/chat_store_emotes_test.dart`, `test/screens/channel/chat/stores/chat_store_third_party_live_test.dart`.
### lib/screens/channel/chat/stores/chat_rules_store.dart

`ChatRulesStore` (MobX, generated `chat_rules_store.g.dart`) — a channel's chat rules and the official app's "Chat Rules" gate: the first time a LOGGED-IN viewer goes to type in a channel that has rules, the rules sheet shows instead of the keyboard until they tap "OK, Got it!". Acceptance is remembered on the device per viewer and channel. The rules come from ANONYMOUS GQL (`TwitchChatRulesService`: POST `https://gql.twitch.tv/gql` with only `Client-ID: kimne78kx3ncx6brgo4mv6wki5h1ko` (the public web client id), operation `ChatRules`, query `query ChatRules($userID: ID!) { user(id: $userID) { id displayName profileImageURL(width: 150) chatSettings { rules } } }`); any failure just shows nothing.

Fields: `service`, `channelId`, `viewerId` (a closure returning the logged-in viewer id or null — re-read every time, so login/logout is followed). Key prefix `_prefix = 'chat_rules_accepted_'`; key = `chat_rules_accepted_<viewerId>_<channelId>` (bool true once accepted). Private: `_loading` (memoized future), `_prefs`, `_focus`, `_disposed`.

Observables: readonly `_rules` (ChatRules? — null before load or on failure), `_acceptedVersion` (int bumped on accept so the computed re-runs), readonly `_prompting` (true while the rules sheet must be on screen in place of the input).

Computed `mustShowBeforeChatting`: depends on `_acceptedVersion`; false when no viewer, prefs not loaded, or `rules.hasRules != true`; else `prefs.getBool(key) != true`.

- `load()` → `_loading ??= _load()` (once per store; after a failure only a new store retries). `_load`: `Future.wait([service.getRules(channelId), SharedPreferences.getInstance()])`; disposed → stop; sets prefs and rules in an action; errors → `debugPrint('Chat rules unavailable: …')`.
- `attach(FocusNode focus)` — detaches the previous node and listens to this one. `_onFocus`: when the node GAINS focus and the rules must show → `focus.unfocus()` (the keyboard never opens) and `_prompting = true`.
- `gate()` — for a send that did not go through focus (an emote picked and sent): if the rules must show → `_prompting = true`, return true (`ChatStore.sendMessage` stops; the text stays); else false.
- `dismissPrompt()` (action) — closed without accepting → `_prompting = false`; it shows again on the next try, like Twitch.
- `accept()` — `_prompting = false` at once; no viewer → return; `setBool(key, true)` (loading prefs if needed); unless disposed, bump `_acceptedVersion`.
- `dispose()` — `_disposed = true`, removes the focus listener.
Oracle: `test/screens/channel/chat/stores/chat_rules_store_test.dart`.

### lib/screens/channel/chat/stores/chat_tabs_store.dart

`ChatTabsStore` (MobX, generated `chat_tabs_store.g.dart`) — several chat tabs on one channel screen (the primary channel plus up to 9 more), lazy activation, persistence, and the MERGED view interleaving all activated tabs by Twitch timestamp.

`PersistedChatTab` (`@JsonSerializable`, generated `fromJson` / `toJson`): `channelId`, `channelLogin`, `displayName`; `fromChatTabInfo(info)`. No ChatStore (sockets cannot be persisted). Saved in the setting `secondaryTabs` when `persistChatTabs` is on.

`ChatTabInfo`: `channelId`, `channelLogin`, `displayName`, mutable `chatStore` (null until activated — lazy), `isPrimary` (first tab: cannot be removed, moved or deactivated), `isActivated = chatStore != null`.

`MergedMessage {IRCMessage ircMessage; ChatStore chatStore}` — a line with the store it came from (per-tab emotes, badges, actions).

Constants: `maxTabs = 10`; `_mergedRenderLimit = 100`.

Dependencies: `twitchApi`, `bttvApi`, `ffzApi`, `sevenTVApi`, `authStore`, `settingsStore`, `globalAssetsStore`, optional `whisperStore`, `listenEvents`, `chatRulesService`, `chatHistoryService`, `viewerActionsService`; the primary channel's id, login and display name.

State: readonly `_tabs` (ObservableList<ChatTabInfo>), observable `activeTabIndex = 0`, computed `activeTab`, `activeChatStore` (non-null by invariant), `canAddTab` (< 10), `showTabBar` (> 1 tab); observable `mergedMode = false` (session only); `_tabChannelProfiles` (ObservableMap id → UserTwitch, for channel badges in the merged view); `mergedScrollController`; readonly `_mergedAutoScroll = true`, `_mergedRenderedMessages = []`; `_mergedRenderedStates` (`(command, ban-duration)` per rendered line); `_mergedRenderTimer`; `_mergedSnapshot` (frozen list while scrolled up); `_mergedSnapshotTotalCount`.

Computed `mergedChannelIdToUserTwitch` = union of every activated tab's `assetsStore.channelIdToUserTwitch` plus `_tabChannelProfiles` (later wins).

Merged algorithm:
- `_compareByTimestamp` — `tmi-sent-ts` as int (missing/invalid → 0), ascending (Dart `List.sort`, not guaranteed stable).
- `_collectMessages(store, out, seenIds, {tailCount})` — `store.messages` (only the last `tailCount` when given), skipping an `id` already seen (Shared Chat delivers one message on several IRC connections; lines without id are always kept); when the tab's OWN autoscroll is off its `messageBuffer` is included too (a paused tab never flushes, so those lines would otherwise be invisible).
- `_computeAllMergedMessages()` — every message of every activated tab, deduped, sorted.
- `_computeRecentMergedMessages()` — the last 100 of each tab, deduped, sorted, then the last 100 overall.
- `mergedMessages` (computed) — the snapshot while scrolled up (`!_mergedAutoScroll && snapshot != null`), else `_mergedRenderedMessages`.
- `_refreshMergedMessages()` (action, every 200 ms like single-chat flushes) — no-op while scrolled up; recent list; states = `(command, ban-duration)`; same length, same states and every line and store IDENTICAL to the previous render → nothing (no rebuild); else both replaced (so an in-place moderation mark — a command change — also redraws).
- `_totalMessageCount()` — sum of messages + buffer over activated tabs. `mergedBufferCount` (computed) — while scrolled up with a snapshot: max(0, total − snapshot total) for the "N new messages" button; else 0.

Constructor: `settingsStore.keepScreenAwake` → `WakelockPlus.enable()` (once for all tabs); `_addPrimaryTab` (its ChatStore created immediately); `persistChatTabs` → `_restoreSecondaryTabs` (each persisted tab except the primary channel, stopping at 10, added WITHOUT a store — lazy, shown dimmed until tapped). Merged scroll listener (needs clients), in an action: `pixels <= 0` while not auto-scrolling → drop the snapshot, auto-scroll on; `pixels > 0` while auto-scrolling → snapshot = all merged messages, snapshot count = total, auto-scroll off.

`_createChatStore({channelId, channelLogin, displayName})`: ChatStore with whispers, chatHistory, viewerActions, listenEvents, a `ChatRulesStore(service, channelId, viewerId: () => loggedIn ? user id : null)` when a rules service exists (else null), a new `ChatDetailsStore(twitchApi, channelName: login)` and a new `ChatAssetsStore(twitchApi, ffzApi, bttvApi, sevenTVApi, globalAssetsStore)`.

Actions:
- `toggleMergedMode()` — flips; entering: auto-scroll on, snapshot cleared, channel profiles of activated tabs fetched (`_fetchTabChannelProfile`: skip if known; `getUser(id)`; failure logged), immediate refresh, 200 ms periodic refresh; leaving: timer stopped, rendered list emptied.
- `resumeMergedScroll()` — snapshot null, auto-scroll on, immediate refresh, `jumpTo(0)` now and after the frame (if clients).
- `activateTab(index)` — bounds-checked; creates the store if missing.
- `addTab({channelId, channelLogin, displayName})` → bool: false at 10 tabs; an existing channel → `setActiveTab(existing)` and false (no duplicates); else appends a non-primary tab, activates it, makes it active, fetches its profile in merged mode, syncs persistence, true.
- `deactivateTab(index)` — not primary and activated: if active, active becomes 0; in merged mode drop its profile and the snapshot; dispose its store (closes IRC) and null it (the tab stays, dimmed; tapping re-activates); leave merged mode (timer, list) when fewer than 2 activated tabs remain.
- `removeTab(index)` → bool: invalid or primary → false; drops profile and snapshot; disposes the store; removes; leaves merged mode when ≤ 1 tab remains; fixes `activeTabIndex` (clamped to the last, or −1 when a tab before it went); activates the new active tab; syncs; true.
- `reorderTab(oldIndex, newIndex)` — index 0 can neither move nor be displaced (either is 0 → return); ReorderableListView semantics (`newIndex -= 1` when moving down); equal → return; moves; the active index follows the moved tab or shifts by ±1; syncs.
- `setActiveTab(index, {silent = false})` — in range: switching to another tab, not silent and NOT merged → on the current store hide the emote menu, unfocus, clear the input, clear the reply (in merged mode tabs are send-target selectors, so drafts are kept; `silent` is for programmatic switches like reply/paste routing). Activates the target; merged mode → fetch its profile; sets the index.
- `_syncSecondaryTabsToSettings()` — when persistence is on: `settingsStore.secondaryTabs` = non-primary tabs as PersistedChatTab (the settings store's autorun saves it).
- `dispose()` — stops the merged timer, disposes every store, clears the tabs, disposes the merged scroll controller, `WakelockPlus.disable()`.
Oracle: the tab bar widgets are tested under the excluded widgets folder; this store is exercised through `test/screens/channel/chat/chat_keyboard_test.dart` and `test/screens/channel/chat/chat_row_cache_test.dart` (merged rows).
### lib/screens/channel/chat/chat.dart

The `Chat` widget — the chat column of the channel screen: message list (single tab or merged), top overlays (Shared Chat banner, Shield Mode indicator), the input bar inside the rules prompt, the "resume scroll / N new messages" button, and the emote menu (inline under the input on phones, a floating panel on tablets). It also wires every ChatStore request stream to UI (user cards, shoutout card, chat settings, mod tools, lead-mod confirmation).

**Top-level openers (injectable for tests):**
- `typedef ChatSettingsOpener = void Function(BuildContext, SettingsStore)`; default `openChatSettings` → `openSettingsPage(context, id: SettingsPageId.chat, builder: ChatSettings(settingsStore))` (unawaited).
- `typedef ChatUserCardOpener = void Function(BuildContext, {required ChatStore chatStore, required ChatUserCardRequest user})`; default `openChatUserCard` → `showChatUserCard(context, chatStore, username: login, userId: id, displayName)`.

**`_SharedChatBannerSlot`** (Observer on `chatStore.showSharedChatBanner`): `AnimatedSwitcher` duration `motionDuration(240 ms)` (150 ms cross-fade under reduce motion), switch-in `OnsetMotion.emphasizedDecelerate` = Cubic(0.05, 0.7, 0.1, 1), switch-out `OnsetMotion.emphasizedAccelerate` = Cubic(0.3, 0, 0.8, 0.15); transition = FadeTransition + SizeTransition (axisAlignment −1: grows from the top). Shown: `SharedChatBanner(key 'shared-chat-banner', partners: sharedChatPartners, startedNow: sharedChatStartedNow, onDismiss: dismissSharedChatBanner)`; hidden: a full-width empty SizedBox.

**`Chat` props:** `chatStore` (the active / input store), `listPadding`, `onAddChat` (for the bottom bar's chat-details menu: add a chat tab), `chatTabsStore` (non-null ⇒ MERGED mode: lines from all tabs, the active tab is the send target), `openUserCard`, `openSettings`.

**State `_ChatState`:**
- `_rows` — `Expando<(Object, ChatMessage)>` row cache keyed by the IRCMessage object (weak): a built `ChatMessage` is reused while its stale key is equal: `(rowInputs, chatStore, message.command, message.tags['ban-duration'])` — a moderation mark (command change) or a new timeout length rebuilds the row, nothing else does.
- `_rowInputs(store)` = tuple of settings `timestampType, emoteScale, badgeScale, animateEmotes, showGifs, animateGifs, nameColorContrast, launchUrlExternal, showDeletedMessages, chatFiltersEnabled` and assets `emoteToObject, twitchBadgesToObject, cheermotes`; any change invalidates every row.
- `_mergedProfiles` (kept identical while `mapEquals`, so rows are not invalidated), `_shownList` (the last built list; while `TickerMode` is off — route covered or app hidden — the last list is returned unchanged).
- Subscriptions `_userCards`, `_shoutoutCards`, `_settingsRequests`, `_modToolsRequests`; reaction `_expandAnnouncer`.

**Lifecycle:** `initState` → `_listenUserCards()` + `_announceExpansion()`; `didUpdateWidget` with another store → both again; `dispose` cancels everything.
- `_announceExpansion()`: reaction on `chatStore.expandChat` → screen-reader `announce(context, expanded ? chatExpandedAnnouncement : chatCollapsedAnnouncement)`.
- `_listenUserCards()`: `chatStore.confirmLeadModerator = (cmd) => mounted ? confirmLeadModerator(context, cmd) : Future.value(false)` (dialog in widgets/lead_mod_confirm.dart); user-card requests → `widget.openUserCard`; shoutout requests → `_openShoutout`; settings requests → `widget.openSettings(context, chatStore.settings)`; mod-tools requests → `showModTools(context, chatStore, view)`.
- `_openShoutout(notice)`: `openProfile()` opens the user card of the shoutout target. Without a `TwitchCommunityService` provider → open the profile directly. Else `showOnsetSheet<bool>(panel: true, maxWidth 560, ShoutoutCard(notice, load: service.getShoutoutProfile(channelLogin, targetLogin, authToken: web token), onViewProfile: pop(true)))`; true and still mounted → open the profile.

**Emote panel placement (tablet):** `_emotePanelPlacement()` → `PanelPlacement?`: chat rect = `globalRectOf(context)` (null/empty → null). `isHorizontalLandscape` = landscape && !`landscapeForceVerticalChat`; bottom inset = 0 in horizontal landscape, else the safe-area bottom. `barTop = chat.bottom − bottomInset − chatStore.bottomBarHeight`. Anchor = the emote button: `atStart = settings.emoteMenuButtonOnLeft` (the input's START, i.e. right in RTL); inset 32 px from the start edge when at start, else 120 px from the end edge; `buttonX = (atStart != rtl) ? chat.left + inset : chat.right − inset`. `placePanel(bounds: screen minus safe padding, anchor: Rect(buttonX − 18, barTop, 36, 44), size: EmoteMenu.panelSize (376×372), sides: [above], region: chat, avoid: PanelAvoidScope.of(context), gap: 10)` → null when it doesn't fit (the menu then opens inline as on a phone). `_recheckPlacement()` re-evaluates after the frame (rotation, video toggle, first open) and rebuilds if inline-vs-panel flipped (`_builtInline`).

**build (Observer):**
- `showEmoteMenu`; `tapClosesOverlay = settings.tapToCloseOverlayChat && OverlayChatScope.of(context)`; `tablet = context.isLargeScreen`; `emoteMenuInline = showEmoteMenu && (!tablet || placement == null)`.
- Layout: `PanelRegion` → Column[ Expanded(Stack(bottomCenter)[ list layer, top overlays, bottom bar, resume button, tablet panel overlay ]), inline emote menu ].
- List layer: `GestureDetector(opaque)` onTap priority: emote menu open → close it; else input focused → `unfocusInput()`; else `tapClosesOverlay` → `settings.fullScreenChatOverlay = false`. Only the list is wrapped (taps on the bar don't unfocus). Inside: `_MessageTextScale(scale: settings.messageScale)` (MediaQuery copy with that `textScaler`), `DefaultTextStyle(fontSize: settings.fontSize)`. `safeBottom = !emoteMenuInline && !isHorizontalLandscape`. Scroll controller = the merged one in merged mode, else the store's. The list Observer builds `_buildMergedList` / `_buildNormalList`; an outer Observer wraps it in `_ChatScrollbar(controller, bottomBarHeight, safeBottom)` so input-height changes (reply bar, autocomplete, restriction bar) rebuild the scrollbar without rebuilding the list.
- Top overlay: Column(stretch)[ `_SharedChatBannerSlot`, Align(end) Padding(8) `ShieldModeIndicator(chatStore)` ].
- Bottom: `ChatRulesPrompt(rules: chatStore.chatRules, focus: textFieldFocusNode, child: ChatBottomBar(chatStore, onAddChat, emoteMenuInline, channelDisplayName: merged ? getReadableName(activeTab.displayName, activeTab.channelLogin) : null))` — in merged mode the bar names the target channel.
- Tablet only: `EmoteMenuPanelOverlay(chatStore, open: showEmoteMenu && !emoteMenuInline, onClose: hide the menu, placement: _emotePanelPlacement)`.

**`_buildNormalList`:** `messages = chatStore.renderMessages`; `_ChatListView` (reversed `ListView.custom`) with a `SliverChildBuilderDelegate` building index i from the END (`messages[length − 1 − i]`, newest at the bottom) as a cached `ChatMessage(key: ObjectKey(message), ircMessage, chatStore)`; `findChildIndexCallback` maps an ObjectKey back with `lastIndexOf` (row state survives shifts); `addAutomaticKeepAlives: false`.

**`_buildMergedList`:** rows from `chatTabsStore.mergedMessages`; the stale key adds the per-store row inputs (memoized per store per build), the source store, the profiles map and `currentChannelId` (the active tab). Row = `ChatMessage(ircMessage, chatStore: merged.chatStore (source), inputChatStore: chatStore (the sending store), onActivateSourceTab: silently switch to the source channel's tab when different, overrideChannelIdToUserTwitch, overrideCurrentChannelId)` — lines from other tabs show their source channel.

**Resume button `_buildResumeScrollButton(emoteMenuInline)`:** `AnimatedPadding` 200 ms (linear), padding L/T/R 4, bottom = `bottomBarHeight + (inline menu or horizontal landscape ? 0 : safe bottom)`. Inside, an `AnimatedSwitcher` 200 ms, easeOut in / easeIn out: nothing while auto-scrolling; else `ElevatedButton.icon(arrow_downward_rounded, label: bufferCount > 0 ? chatNewMessages(count) : chatResumeScroll, metadata text style)`; `bufferCount` = merged buffer count or the store's `messageBuffer.length`; tap → `resumeMergedScroll` / `resumeScroll`. These two 200 ms animations do NOT go through `motionDuration` (unchanged under reduce motion).

**Inline emote menu `_buildEmoteMenu(open)`:** `AnimatedContainer`, curve `OnsetMotion.standard` = Cubic(0.2, 0, 0, 1), duration `motionDuration(260 ms)`; height = screen height / 3 in portrait, / 2 in landscape when open, else 0; colour `SheetColors.emoteMenu` (#101010); child `AnimatedSwitcher` `motionDuration(100 ms)`, easeOut / easeIn: when open a ClipRect Column[hairline (`OnsetTokens.hairlineWidth`, `colors.ring`), Expanded(EmoteMenu(chatStore))].

**`_ChatListView`:** reversed `ListView.custom`, padding = `listPadding` + bottom (`bottomBarHeight + (safeBottom ? safe bottom : 0)`), `semanticChildCount: count`; reads the safe padding itself so the keyboard animation rebuilds only this widget (the delegate is reused). **`_ChatScrollbar`:** `OnsetScrollbar` with top padding = safe top, bottom = bottomBarHeight + safe bottom when `safeBottom`.
Oracle: `test/screens/channel/chat/chat_keyboard_test.dart`, `test/screens/channel/chat/chat_row_cache_test.dart`, `test/screens/channel/chat/chat_emote_panel_test.dart`, `test/screens/channel/chat/chat_banner_a11y_test.dart`, `test/screens/channel/chat/chat_overlay_tap_test.dart`, `test/screens/channel/chat/chat_shoutout_card_test.dart`, `test/screens/channel/chat/chat_user_card_test.dart`.
### lib/screens/channel/chat/emote_menu/emote_menu.dart

The emote picker. Phone: under the chat input (inline, see chat.dart). Tablet: a floating panel above the input (`EmoteMenuPanelOverlay`).

**`EmoteMenu({chatStore, panel = false})`** — `static const panelSize = Size(376, 372)`. Observer building `EmoteTabsView(panel, headers, tabActions, children)`:
- Provider headers (underlined tabs), in order: `emoteMenuRecent`, then — each only when its setting is on — literal `Twitch` (`showTwitchEmotes`), `7TV` (`show7TVEmotes`), `BTTV` (`showBTTVEmotes`), `FFZ` (`showFFZEmotes`) (provider names are never translated), then `gifTab` when the GIF picker is available.
- `tabActions`: when recent emotes exist, tab 0 shows at the end of the tab row an `IconButton` (44×44, no padding, tooltip `emoteMenuClearRecent`, `SheetGlyph(trash, size 19, colour secondary)`) that clears `assetsStore.recentEmotes` and shows the notification `emoteMenuRecentCleared` (`chatStore.updateNotification`, 5 s). No confirmation.
- Children: `RecentEmotesPanel`; Twitch → `EmoteMenuPanel(twitchEmotes: assetsStore.userEmoteSectionToEmotes)`; 7TV → `EmoteMenuPanel(emotes: sevenTVEmotes)`; BTTV → `bttvEmotes`; FFZ → `ffzEmotes`; the GIF picker last.
- `_gifPicker(context)` → null (no tab) when the providers `TwitchViewerActionsService?` / `GiphyService?` are missing (`ProviderNotFoundException` caught) or null, when logged out, or when the twitch.tv web token is empty. Else `GifPickerPanel(channelLogin, channelName: getReadableName(displayName, channelName), giphy, loadConfig: actions.gifPickerConfig(channelId, authToken), send: actions.sendGif(channelId, gif, searchTerm, authToken), onSent: hide the emote menu)` (Twitch's native chat GIFs through GQL viewer actions).

**`enum EmoteTabsStyle { underline, pills }`** — providers as text tabs with an accent underline; a provider's sets (Channel, Global…) as pills.

**`EmoteTabsView({headers, children, tabActions = {}, style = underline, panel = false})`** (asserts equal lengths; TickerProviderStateMixin): a `TabController(length)` whose listener `setState`s; recreated in `didUpdateWidget` when the number of headers changes (a provider toggled). `_select(index)`: same index → nothing; else `HapticFeedback.selectionClick()` and `animateTo(index, duration: motionDuration(kTabScrollDuration = 300 ms))` (150 ms under reduce motion). Pages are a swipeable `TabBarView`.
- `_underlineTabs`: Container height 48 (panel) / 46, padding start 16, end 6 (panel) / 4, bottom hairline border (`colors.hairline`, `OnsetTokens.hairlineWidth`). Row: horizontally scrollable tabs (spacing 20 panel / 22) + the current tab's action (if any) centered at the end. Each tab: `Semantics(selected, button)` + opaque `GestureDetector` → `_select`; label in `OnsetTokens.bodyFamily` 14 px, letterSpacing −0.07, weight w700 selected / w600, colour `colors.text` selected / `colors.tertiary`; underline 2.5 px, accent colour (`SheetColors.accentOf`), radius 2, at the bottom, `AnimatedOpacity` 1/0 over `motionDuration(200 ms)`.
- `_pillTabs`: horizontal scroll, padding (12, 10 panel / 8, 12, 2), spacing 6, `SheetChoicePill(label, role: tab, selected, onSelected: _select)`.
- build: `LayoutBuilder`; maxHeight < 48 (menu animating open/closed) → an empty expanded box (no overflow); else Column[tabs, Expanded(TabBarView)].

**`EmoteMenuPanelOverlay({chatStore, open, onClose, placement})`** (tablet): an `OverlayPortal` shown from initState (always mounted; its content switches). Placement = open ? `placement()` : null. `AnimatedSwitcher` duration `motionDuration(220 ms)`, reverse `motionDuration(160 ms)`; transition = fade, plus (unless reduce motion) `ScaleTransition` 0.97 → 1.0 anchored bottom-left; previous and current stacked. Closed → `SizedBox.shrink(key 'closed')`. Open → `Positioned.fromRect(placement.rect)` → `TextFieldTapRegion(onTapOutside: onClose)` (a tap anywhere but the panel and the input closes it; taps inside a sheet opened from the panel, e.g. emote details, are not "outside" — tested) → `SheetPresentation(panel: true)` → `OnsetPanelSurface(side, nub)` (nub pointing at the emote button) → `Semantics(container, label: chatEmoteMenu, explicitChildNodes)` → `EmoteMenu(panel: true)`. Focusing the input also closes it (ChatStore focus listener).
Oracle: `test/screens/channel/chat/emote_menu/emote_menu_test.dart`, `test/screens/channel/chat/chat_emote_panel_test.dart`, `test/screens/channel/chat/emote_menu/gif_picker_panel_test.dart`.

### lib/screens/channel/chat/emote_menu/emote_menu_panel.dart

`EmoteMenuPanel({chatStore, emotes, twitchEmotes})` — one provider page of the emote menu, with set pills.

- Third-party page (`emotes` given): globals = types bttvGlobal / ffzGlobal / sevenTVGlobal; channel = bttvChannel / bttvShared / ffzChannel / sevenTVChannel. `EmoteTabsView(style: pills, panel: SheetPresentation.isPanel(context))`, headers `emoteMenuChannel` (only when there are channel emotes) and `emoteMenuGlobal` (always, even when empty), children an `EmoteMenuSection` each. Order inside a section = the provider list order (`emoteToObject` insertion order).
- Twitch page (`twitchEmotes` = `userEmoteSectionToEmotes`): `isSubbed = chatStore.userState.subscriber`. It REMOVES (mutating the store's map) every section whose key lowercased equals the channel login (the channel's emotes already sit in `Channel Emotes`). Headers via `_sectionTab`: `Channel Emotes` → `emoteMenuChannel`, `Global Emotes` → `emoteMenuGlobal`, `Unlocked Emotes` → `emoteMenuUnlocked`, `Other Channels` → `emoteMenuOther`, a channel display name → its FIRST WORD (`split(' ')[0]`). Each section: `EmoteMenuSection(emotes, disabled: key == Channel Emotes && !isSubbed, usable: names in userEmoteToObject (follower and Bits emotes of the channel stay usable), followerInfo: for the channel section `emoteMenuFollowerInfo(channel: displayName)`)`.
Oracle: `test/screens/channel/chat/emote_menu/emote_menu_test.dart`, `test/screens/channel/chat/emote_menu/emote_menu_unlock_test.dart`.

### lib/screens/channel/chat/emote_menu/recent_emotes_panel.dart

`RecentEmotesPanel({chatStore})` (Observer):
- Empty: centered, never hand-scrollable column (spacing 6; scrolls instead of overflowing while the menu folds): `SheetGlyph(emote, size 26, strokeWidth 1.6, tertiary)` + `emoteMenuNoRecent` in `SheetText.status` 13 px tertiary.
- Otherwise `GridView.builder` (top MediaQuery padding removed), `emoteGridDelegate(panel)`, padding (6 panel / 4, 4, 6 / 4, 10), one cell per recent emote (max 48, most recent first). `match` = the first of `emoteToObject[name]` and `userEmoteToObject[name]` that is non-null AND has the same TYPE as the recent entry (a recent emote missing here, or present only from another provider, is locked). `locked = match == null`. `EmoteCell(emote, url: match?.url ?? emote.url, locked)`: tap → locked ? details : `chatStore.addEmote(emote)`; long press → `HapticFeedback.lightImpact()` + details. Details = `showEmoteDetails(chatStore, emote, onRemoveRecent: assetsStore.removeRecentEmote(emote))` (the details sheet offers removal from Recent). `locked` is NOT passed (defaults to false), so a locked twitchChannel emote opened from Recent never offers Subscribe, unlike the same emote in its section (Known Android defects).
Oracle: `test/screens/channel/chat/emote_menu/emote_menu_test.dart`.

### lib/screens/channel/chat/emote_menu/emote_menu_section.dart

Grid page of emotes plus shared cell widgets.

**`EmoteMenuSection({chatStore, emotes, disabled = false, usable = {}, followerInfo})`** — kept alive across tab swipes (`AutomaticKeepAliveClientMixin`, `wantKeepAlive = true`). `CustomScrollView` (top padding removed): an optional `EmoteMenuNote(followerInfo)` sliver, shown only when `followerInfo` is set AND the section has at least one `twitchFollower` emote; then `SliverPadding(side = 6 panel / 4, top 4, bottom 10)` around a `SliverGrid(emoteGridDelegate)`. Cell: `locked = disabled && !usable.contains(name)`; tap → locked ? details : `addEmote(emote)`; long press → light haptic + `showEmoteDetails(chatStore, emote, locked)`.

**`showEmoteDetails(context, {chatStore, emote, locked = false, onRemoveRecent})`** → `IRCMessage.showEmoteDetailsBottomSheet(context, emote, launchExternal: settings.launchUrlExternal, onRemoveRecent, onSubscribe)`; `onSubscribe` only for a LOCKED `twitchChannel` emote: `TwitchWebPage.open(title: channelSubscribe, url: twitchSubscribeUrl(channelLogin))` (the in-app twitch.tv subscribe page).

**`EmoteMenuNote({text})`**: padding (12, 8, 12, 2), Row(start, spacing 8)[ heart `SheetGlyph(size 15, secondary)` 1 px lower, Expanded text `SheetText.rowDetail` in secondary ].

**`emoteGridDelegate(context, {panel})`**: panel → 6 columns, cell height (`mainAxisExtent`) 54; phone → square cells, 8 columns in portrait, 6 in landscape with the video shown (`settingsStore.showVideo`), 16 in landscape chat-only.

**`EmoteCell({emote, locked, onTap, onLongPress, url})`**: semantics label `emoteMenuLocked(name)` when locked, `emoteMenuAnimated(name)` when animated, else none (the image gets `semanticLabel = name`). `InkWell` radius 12, padding 5, centered Stack: `OnsetCachedNetworkImage(url ?? emote.url, height: emote.height ?? 28 (`defaultEmoteSize`), width: emote.width, memCacheHeight: ceil(height × devicePixelRatio), when locked colour white at 42 % with `BlendMode.modulate` — dimmed by colour, not an opacity layer, cheap for grids full of sub emotes)`; animated emotes get an `AnimatedEmoteMark` at end −6, bottom −4.

**`AnimatedEmoteMark`**: excluded from semantics; a 13×13 circle, fill `colors.raised`, hairline `colors.ring` border, centered `_PlayMarkPainter` 5×6 filled triangle (play glyph) in `colors.secondary`; repaints only when the colour changes.
Oracle: `test/screens/channel/chat/emote_menu/emote_menu_section_test.dart`, `test/screens/channel/chat/emote_menu/emote_menu_unlock_test.dart`.

### lib/screens/channel/chat/emote_menu/gif_picker_panel.dart

`GifPickerPanel` — Twitch's native chat GIFs (GIPHY-powered) as the last emote-menu tab. Keys: `searchKey 'gif-search'`, `sendKey 'gif-send'`, `loadingKey 'gif-loading'`, `tileKey(id) = 'gif-<id>'`. Props: `channelLogin`, `channelName`, `loadConfig()` → `GifPickerConfig?` (GQL viewer action → `{isEnabled, isAllowlisted, apiKey (^[A-Za-z0-9]{8,64}$), rating}`; `canSend = enabled && allowlisted && apiKey non-empty`), `giphy` (GiphyService, `https://api.giphy.com/v1/gifs`: `/search?q=` with the query trimmed and cut to 50 chars, or `/trending` when empty; params `api_key`, `limit` 24, `offset` 0, `rating`), `send(gif, searchTerm)` → `GifSendResult(status: sent | cooldown | refused | integrityRefused | signedOut | failed, secondsUntilCanSend)`, `onSent`.

State: `_query` controller, `_debounce`, `_config`, `_gifs` (null = failed / not loaded), `_loadingConfig = true`, `_loadingGifs`, `_sending`, `_searchEpoch` (drops stale answers).
- initState → `_loadConfig()`: awaits the config; stores it; `canSend` → `_search()` (trending first).
- Typing → 350 ms debounce → `_search()`; submitting (search action) → immediate search. `_search()`: epoch++, loading on, `giphy.search(config, query)`; the answer is ignored if unmounted or superseded.
- Tap a tile (disabled while sending) → `_confirmAndSend(gif)`: `OnsetDialog(title: gifSendTitle, message: gifSendDisclosure, content: the preview in its aspect ratio with the small radius, actions: [text button commonCancel → false, button gifSend (key gif-send) → true])`. Confirmed → sending on → `send(gif, query)` → sending off; `sent` → `onSent()` (closes the menu); otherwise a SnackBar `gifSendResult(status: name, seconds)` replacing the current one.
- build: loading config → 22 px spinner (stroke 2). No config or not enabled → message `gifUnavailable`. Enabled but cannot send → message `gifSubscribersOnly` with a `SubscribeButton(login, name, height 36)` (from channel_info). Else Column: search field (padding 12, 8, 12, 6; dense; maxLength 50 with hidden counter; hint `gifSearchHint`; search icon 20; filled `colors.field`; pill radius, no border); a 2 px slot showing a `LinearProgressIndicator` (key gif-loading) while re-searching with results on screen; results: loading without results → spinner; null → `gifLoadFailed`; empty → `gifNoResults`; else a grid (max cell extent 140, spacing 6, padding 12, 0, 12, 8) of tiles (semantics button, label = title or `gifTab`; `InkWell` small radius; preview over `colors.well`); footer `gifPoweredBy` 11 px tertiary, bottom padding 6.
`_Message`: centered scrollable column padded 20, text 14 px secondary centered, optional action 12 px below.
Oracle: `test/screens/channel/chat/emote_menu/gif_picker_panel_test.dart`.
### lib/screens/channel/chat/details/chat_modes.dart

`ChatModes({roomState})` — the read-only pills of the ACTIVE room modes at the top of the chat details menu. It is re-rendered by the parent menu Observer (`chat_details.dart` `_menu`, which reads `chatDetailsStore.roomState` and passes a new value); its own `Observer` only reads the plain immutable `roomState` field and tracks nothing. One tuple (pill label, glyph, optional duration, explainer) per active mode:
- emote-only (`roomState.emoteOnly != '0'`) → `ChatMode.emoteOnly.pill(l)` (= `chatModePill(mode: 'emoteOnly')`), glyph emote, explainer `chatModeExplainer(mode: 'emoteOnly')`.
- followers-only (`followersOnly != '-1'`) → pill followers, glyph heart, duration `_getFollowersDuration`, explainer `followersNow` when the value is `'0'` (any follower) else `followers`.
- slow (`slowMode != '0'`) → pill slow, glyph hourglass, duration `_getSlowModeDuration`, explainer `slow`.
- subscribers (`subMode != '0'`) → glyph star, explainer `subscribers`.
- unique chat (`r9k != '0'`) → glyph unique, explainer `uniqueChat`.
Sorted alphabetically by the localized pill label (the order follows the language). A Row (min size, spacing 6) of `Tooltip(message: explainer, triggerMode: tap)` around `_ModePill` (tap a pill to read what the mode means).
- `_getFollowersDuration`: '0' → null; ≥ 60 minutes → `chatShortHours(hours)` or `chatShortHoursMinutes(hours, minutes)`; else `chatShortMinutes(minutes)`. (`int.parse`: a non-numeric value would throw; ROOMSTATE values are numeric.)
- `_getSlowModeDuration`: ≥ 60 s → `chatShortMinutes` or `chatShortMinutesSeconds`; else `chatShortSeconds`.
`_ModePill`: height 30, horizontal padding 11, stadium shape filled `colors.raised` with a hairline `colors.ring` border; Row(spacing 6)[glyph 14 px `colors.body`, label body font 12 px w600 `colors.body`, optional duration 12 px w500 `colors.secondary` in tabular figures].
Oracle: `test/screens/channel/chat/details/chat_modes_tooltip_test.dart`, `test/screens/channel/chat/details/chat_details_test.dart`.

### lib/screens/channel/chat/details/chat_users_list.dart

`ChattersList({chatDetailsStore, chatStore, userLogin})` — the "Chatters" sheet: a filterable list of the logins SEEN in this chat session (`ChatDetailsStore.chatUsers`, filled from IRC senders and history; there is no API listing every viewer).
- Height = 80 % of the screen.
- Filter field (padding 16, 4, 16, 10): `ListenableBuilder` on the focus node + Observer; `AnimatedContainer` (`motionDuration(160 ms)`) height 44, padding start 12 end 4, `colors.raised`, radius 12, border = accent at 55 % alpha, 1 px when focused, else hairline `colors.ring`. Row(spacing 10)[filter glyph 18 secondary, TextField(the store's controller and focus node, autocorrect off, accent cursor, row style w400, hint `chatChattersFilter`, no borders, dense, zero content padding), clear button when focused or the text is non-empty: 40×40 IconButton, tooltip `commonCancel` when the filter is empty else `chatClear`, close glyph 18 stroke 2; tap → with an empty filter unfocus; always clears the text].
- List: `RefreshIndicator.adaptive` (pull to refresh = light haptic + `setState`, a redraw only, no network). Stack(bottomCenter)[ `OnsetScrollbar` around a `CustomScrollView` (always scrollable, the store's scroll controller), the scroll-to-top button ].
- Slivers (Observer; `filteredUsers.toList()` computed once per build): with an empty filter, a header `chatChattersFound(count: chatUsers.length)` (13 px secondary, tabular, padding 16, 2, 16, 8); no chatters → empty state `chatChattersNone`; no match → `chatChattersNoMatch`; else `SliverList.builder` (bottom padding 16) of 48 px rows (padding 16, spacing 12): `InitialAvatar(name: login)` + the login (1 line, ellipsis, row style w400). Tap → `_open(login)`: `TwitchApi.getUser(userLogin)` (provider), then if mounted `showChatUserCard(chatStore, username, userId, displayName)`. No error handling: a failed lookup leaves an unhandled future error (the PC version should show an error toast instead).
- `_empty`: padding 16 / 48, Column(spacing 8)[people glyph 26 stroke 1.6 tertiary, text body tertiary].
- Jump button: Observer → `AnimatedSwitcher` 200 ms easeOut / easeIn (not reduce-motion aware) showing `ScrollToTopButton(scrollController)` while `showJumpButton`.
- Not live: `chatUsers` is a plain `SplayTreeSet` and `filteredUsers` a lazy `where`, so the count header and the rows change only on a rebuild (typing in the filter, pull-to-refresh `setState`, reopening); chatters who arrive while the sheet is open are not shown until then.
- `dispose()` resets `chatDetailsStore.showJumpButton = false`.
Oracle: `test/screens/channel/chat/details/chat_users_list_test.dart`.

### lib/screens/channel/chat/details/chat_mode_controls.dart

`ChatModeControls({roomState, onModerate})` — the moderator's room-mode switches and "Clear chat" (sheet opened from chat details when `canModerate`, wrapped in an Observer so it follows every ROOMSTATE). `onModerate` = `ChatStore.moderate` (Helix, also writes the outcome line in chat; null if the chat closed).

Constants: `kSlowModeWaits` = 3, 5, 10, 20, 30, 60, 120 seconds. `kFollowAges` = 0 (any follower), 10 min, 30 min, 1 h, 1 day, 7 days, 30 days, 90 days. `_followAgeLabel(age)` = `chatModesAnyFollower` for zero, else `followAgeLength(age)` ("10 minutes", "1 hour", "1 day", "1 week", "1 month", "3 months").

State: `_busy`, `_last` (ModerationOutcome), `_slowWait = 30 s`, `_followAge = 0`. `_readDurations()` (initState and every didUpdateWidget): an active slow mode sets `_slowWait` to its seconds; an active followers mode sets `_followAge` to its minutes (the pickers show the room's real values).

`_run(command)`: busy on; awaits `onModerate`; a THROW is caught → `moderationFailed` (`chatModNotThrough`) so buttons never stay disabled; if mounted: busy off, `_last = outcome`; a refused / failed change re-reads the durations (pickers return to what the room still has).
`_clear()`: `OnsetDialog(title chatModesClearTitle, message chatModesClearMessage, actions [text commonCancel → false, danger chatClear → true])`; confirmed → `_run(ClearChatCommand())`.
`_picker({value, values, label, onChanged})`: 34 px select, max width 220, top margin 6, padding start 12 end 8, `colors.raised`, radius 10, hairline ring; `DropdownButton<Duration>` (no underline, dense, expanded, dialog-colour menu, radius 12, chevron-down glyph 16 stroke 2.2 secondary). The current value is selected only when it is a preset; otherwise the hint shows its label (e.g. a 45 s slow mode set elsewhere). Disabled while busy. Labels 13 px w500.
Row `mode(mode, on, glyph, {duration, picker})`: min height 56, padding 16 / 8, Row(spacing 14)[glyph secondary, Expanded Column(name `mode.label(l)` = `chatModeName(mode)`, the picker under it), `OnsetSwitch(value: on, semanticsLabel: name, onChanged: busy ? null : toggle)`]. The picker sits apart from the switch so a tap beside it does not change the room for everyone. `toggle(mode, value, duration)` → `ChatModeCommand(mode, on: value, duration: value ? duration : null)`.
Picker change: sets the local value; if the mode is ON applies at once (`ChatModeCommand(slow | followers, on: true, duration)`); if OFF the value waits for the switch.
Layout (`ListView`, shrinkWrap, bottom padding 12): header row (baseline, padding 16, 4, 16, 6) `chatDetailsModes` (semantics header, title style) + `chatModesModerator` at the end (status 12 px secondary); switches: slow (hourglass, picker labelled `chatModesSlowWait(seconds)`), followers (heart, follow-age picker), subscribers (star), emote-only (emote), unique chat (unique); hairline divider (margin 16 / 6); `SheetRow(glyph clearChat, label chatModesClearChat, danger, onTap: busy ? null : _clear)`; `SheetStatusLine(busy, message: last?.message, ok: last?.ok ?? true, minHeight 26, padding 16, 2, 16, 0)` — a spinner while busy, then the outcome line (success / error colour).
Oracle: `test/screens/channel/chat/details/chat_mode_controls_test.dart`.

### lib/screens/channel/chat/details/chat_details.dart

The chat details sheet ("⋯" beside the channel points button, or a tablet's chat header): a menu whose sub-views (sleep timer, username colour, rules) replace it in place.

`showChatDetails(context, {chatStore, onAddChat})` → `showOnsetSheet(ChatDetails(chatDetailsStore: chatStore.chatDetailsStore, chatStore, userLogin: chatStore.channelName, onAddChat))`.

`chatPreferenceRows(context, settings)` (reused elsewhere): section label `chatDetailsPreferences`, then `ChatPreferenceSwitch`es:
1. glyph emote, `settingsAnimateEmotes` ↔ `settings.animateEmotes`.
2. glyph videos, `settingsShowGifs` ↔ `showGifs`.
3. glyph videos, `settingsAnimatedGifs` ↔ `animateGifs`, enabled only while `showGifs`.
4. glyph filter, `chatDetailsHideOffensive` ↔ `chatFiltersEnabled` (the chat filters master switch).
5. glyph palette, `settingsReadableNameColors`: ON when `readableNameColors || increaseChatContrast`; writes `readableNameColors`; disabled while `increaseChatContrast` is on, with detail `settingsReadableNameColorsLocked`.
6. glyph contrast, `settingsIncreaseChatContrast` ↔ `increaseChatContrast`.
`ChatPreferenceSwitch({glyph, label, read, write, enabled, detail})`: Observer; `MergeSemantics(SheetRow(glyph, label, detail, trailing OnsetSwitch(value, onChanged when active), onTap when active: selection haptic + toggle))`.

`enum ChatDetailsView { menu, sleep, color, rules }`. Statics: `maxHeight = 600`; `sleepDurations` = 5, 10, 15, 30 minutes, then every hour from 1 to 12.

State: `_scrollController` (colour list), `_view = menu`, `_liveTogether`, `_isRefreshingAssets`, `_showRefreshSuccess`, `_refreshSuccessTimer`, `_rules`, `_pickedColor`, `_loadingColor`, `_savingColor`.
- initState → `_readLiveTogether()`: with a `TwitchCommunityService` provider, `loadLiveTogether(guestStar: service.getGuestStarSession(channelId), costream: service.getCostreamers(channelLogin))` (GQL Guest Star / Stream Together roster) → stored when non-null.
- `_openBadges()`: sheet `ChatBadgeSheet(load: community.getChatIdentity(channelId, authToken: web token), select: actions.selectBadge(scope, channelId, authToken, badge) ?? failed, setFlairHidden: actions.setSubFlairHidden(hidden, authToken) ?? failed)` (choose the displayed chat badge, hide sub flair).
- `_openLiveTogether(member)`: pops the sheet and REPLACES the channel route with `VideoChat(userId, userName: displayName, userLogin)` (route name `VideoChat.routeName`).
- `formatDuration(d)`: < 60 min → `chatDurationMinutes(count)`; else `chatDurationHours(count: inHours)`. `formatTimeLeft(d)`: hours > 0 → `chatShortHoursMinutes(h, m)`; minutes > 0 → `chatShortMinutesSeconds(m, s)`; else `chatShortSeconds(s)`.
- `_hexToColorName(hex)`: strips `#`, uppercases, compares with each `chatColorValues` RGB → the Helix name or null (custom hex / Turbo colour → nothing preselected).
- `_openColorPicker()`: guarded by `_loadingColor`; spinner on; `_getCurrentUserColor()` = `twitchApi.getUserChatColor(userId)` (Helix `GET /chat/color?user_id=`) → name or null (errors ignored); then the colour view with that colour preselected.
- `_saveColor(color)`: saving on; `updateUserChatColor(userId, color)` (Helix `PUT /chat/color`); a throw counts as failure; back to the menu only on success (a failure keeps the pick for another try); SnackBar `chatColorUpdated` / `chatColorUpdateFailed`.
- `_hasActiveModes()`: subMode ≠ '0' or followersOnly ≠ '-1' or emoteOnly ≠ '0' or slowMode ≠ '0' or r9k ≠ '0'.
- `_handleRefreshAssets()`: spinner on; `chatStore.getAssets()`; success → light haptic, a check mark for 2 s; failure → spinner off. `_refreshTrailing`: AnimatedSwitcher `motionDuration(200 ms)`: 18 px accent spinner (key busy) / check glyph stroke 2.4 accent (key success) / nothing.

**Menu (`_menu`, Observer — follows a login while open), rows in order:**
1. `LiveTogetherStrip(roster, channelId, onOpen: _openLiveTogether)` (nothing without a roster).
2. `SharedChatStrip(channels: sharedChatPartners)` when non-empty.
3. Active mode pills (`ChatModes`) in a horizontal scroll (padding 16, 4, 16, 8) when a mode is on.
4. Video toggle (Observer): video shown → glyph whisper, `chatDetailsChatOnly`; hidden → glyph monitor, `chatDetailsShowVideo`; tap flips `settings.showVideo` and closes the sheet.
5. `chatDetailsRefreshAssets` (glyph refresh, spinner / check trailing; disabled while refreshing).
6. `chatReconnect` (glyph plug): closes the sheet, notification `chatReconnectingNotice`, `chatStore.connectToChat()` (a fresh connect, not flagged as reconnect, so the delay countdown can show).
7. Logged in: `chatDetailsUsernameColor` (palette, chevron, spinner while loading) → colour view.
8. Logged in: `chatBadgeTitle` (star, chevron, key `chat-badge-row`) → badge sheet.
9. Logged in: `chatDetailsPointsPollsPredictions` (coin, detail `chatDetailsOpensTwitchChat`, external) → closes and opens `TwitchWebPage(title chatDetailsTwitchChat, url https://www.twitch.tv/popout/<login>/chat)`.
10. Logged in, NOT the owner, and a subscribe URL exists (`twitchSubscribeUrl(login)`): `channelSubscribe` (star, detail `chatDetailsOpensTwitch`, external) and `chatDetailsGiftSub` (gift, same detail) → both open the channel's twitch.tv subscription page in `TwitchWebPage` (purchases happen there).
11. `canModerate`: `modToolsTitle` (flag, detail `modToolsEntryDetail`, chevron) → `showModTools(context, store)`.
12. `canModerate`: `chatDetailsModes` (shield, detail `chatDetailsModesDetail`, chevron) → sheet `Observer(ChatModeControls(roomState, onModerate: store.moderate))`.
13. `ChatRulesTile(rules: store.chatRules, onOpen: rules → _rules, rules view)`.
14. `chatDetailsChatters` (people, chevron) → sheet `GestureDetector(tap unfocuses) → ChattersList`.
15. `chatDetailsAddChat` (addChat, chevron) → `onAddChat`.
16. Sleep timer (Observer): a running timer shows the time left (`formatTimeLeft`) in accent; else `chatDetailsSleepTimer`; chevron → sleep view.
17. `chatPreferenceRows(...)`.
18. `settingsTitle` (settings, chevron) → pushes `Settings(settingsStore)` (route `Settings.routeName`).
ListView: shrinkWrap, key `ValueKey(menu)`, bottom padding 14.

**Sleep view:** `SheetBackHeader(chatDetailsSleepTimer, back → menu)`; with an active timer an Observer row (close glyph, `commonCancel`, trailing time left 14 px w600 accent tabular) → `cancelSleepTimer()` and back; then a 48 px row per duration (hourglass, `formatDuration`) → `updateSleepTimer(duration, onTimerFinished: navigatorKey.currentState.popUntil(first route))` (back to the home screen) and back to the menu.

**Rules view:** `ChatRulesSheet(key rules, rules, onAccept: chatRules.accept() (unawaited) then menu, onBack: menu)`; nothing without rules.

**Colour view:** fixed height 600; `SheetBackHeader(chatDetailsUsernameColor)`; with a pick, a preview card (margin 16, 0, 16, 8; padding 14 / 12; `colors.well`, radius 14, hairline) holding `_ColorPreview`; a scrollable list of `_ColorRow` for the 15 `chatColorNames` (blue, blue_violet, cadet_blue, chocolate, coral, dodger_blue, firebrick, golden_rod, green, hot_pink, orange_red, red, sea_green, spring_green, yellow_green; RGB 0000FF, 8A2BE2, 5F9EA0, D2691E, FF7F50, 1E90FF, B22222, DAA520, 008000, FF69B4, FF4500, FF0000, 2E8B57, 00FF7F, 9ACD32); footer (top hairline, padding 16, 10, 16, 16, spacing 10): expanded text button `commonCancel` → menu, expanded button `chatSave` (disabled without a pick or while saving) → `_saveColor`.
`_ColorRow`: semantics selected + mutually exclusive group; 48 px `SheetRow(label: chatColorName(color: name), leading 22 px circle in `adjustChatNameColor(context, value)` (the same readability adjustment as names in chat), trailing check glyph (stroke 2.4, accent) with `AnimatedOpacity` `motionDuration(160 ms)`)`.
`_ColorPreview`: a mock PRIVMSG (display name, the pick's hex colour, user id, mod / subscriber from USERSTATE, id `preview-message`, now timestamp, `badges` / `badge-info` copied from the raw USERSTATE) with text `chatColorPreview`, rendered through the real `generateSpan` (emote / badge scales, animate emotes; links disabled).

**build:** `PopScope(canPop: view == menu, onPopInvoked: not popped → menu)` — back / scrim closes ONE level. `ConstrainedBox(maxHeight 600)` → `AnimatedSize` (`motionDuration(260 ms)`, `OnsetMotion.standard`, top-center) → `AnimatedSwitcher` (`motionDuration(240 ms)`, in `emphasizedDecelerate`, out `emphasizedAccelerate`, stacked top-center); transition = fade, plus (no reduce motion) a horizontal slide of 6 % of the width: the menu comes from the left (−0.06), sub-views from the right (+0.06). `dispose` cancels the success timer and the scroll controller.
Oracle: `test/screens/channel/chat/details/chat_details_test.dart`, `test/screens/channel/chat/details/chat_mode_controls_test.dart`, `test/screens/channel/chat/details/chat_modes_tooltip_test.dart`, `test/screens/channel/chat/details/chat_users_list_test.dart`.
### lib/screens/channel/chat/mod_tools/mod_events.dart

Parsers and value types for moderator EventSub payloads (mod action feed, AutoMod held messages, Shield Mode) and shoutouts.

`ModActionEntry {action, moderatorName, at, userId?, userName?, reason = '', timeoutEndsAt?}`; `timeoutLength = timeoutEndsAt − at` (null without an end).

`enum HeldMessageStatus { pending, approved, denied, expired }`. `HeldMessage {id, userId, userName, text, reason, category = '', level = 0, heldAt, status = pending}`; `isPending`; `withStatus(s)` copy.

`kModActions` — `channel.moderate` v2 actions shown in the feed (others ignored): ban, timeout, unban, untimeout, warn, delete, clear, mod, unmod, vip, unvip, raid, unraid, add_blocked_term, remove_blocked_term, add_permitted_term, remove_permitted_term, approve_unban_request, deny_unban_request, emoteonly, emoteonlyoff, followers, followersoff, slow, slowoff, subscribers, subscribersoff, uniquechat, uniquechatoff.

`_targetObjects` — for targeted actions, the sub-object holding the target: ban→`ban`, timeout→`timeout`, unban→`unban`, untimeout→`untimeout`, warn→`warn`, delete→`delete`, mod→`mod`, unmod→`unmod`, vip→`vip`, unvip→`unvip`, raid→`raid`, unraid→`unraid`, approve_unban_request / deny_unban_request→`unban_request`. Helpers `_string` (non-empty String or null), `_map` (`Map<String, Object?>` or null).

`parseModerateEvent(event, {now})`: null when the action is missing or not in kModActions; moderator = `moderator_user_name` ?? `moderator_user_login`, required; target = `event[_targetObjects[action]]`; userName = target `user_name` ?? `user_login` — REQUIRED for targeted actions; `expires_at` → `timeoutEndsAt` (`DateTime.tryParse`); reason = target `reason` ?? `moderator_message` ?? ''; userId = target `user_id`; `at = now` (the app's clock).

`parseHeldMessage(event)` (`automod.message.hold` v2): requires `message_id`, `user_id`, a name (`user_name` ?? `user_login`) and `message.text`; reason = `reason` ?? `'automod'`; `automod.category` (default '') and `automod.level` (int, default 0); `heldAt` = parsed `held_at`, else now.

`parseHeldMessageUpdate(event)` (`automod.message.update` v2) → `(id, status)` for a status (case-insensitive) approved / denied / expired; else null.

`shieldModerator(event)` = `moderator_user_name` ?? `moderator_user_login`.

`ShoutoutNotice {id, targetId, targetLogin, targetName}`; `parseShoutout(type, data, {channelId})`: only `type == 'create'`, `data.broadcasterUserID == channelId`, `targetLogin` matching `^[a-zA-Z0-9_]{1,25}$`, `targetUserID` matching `^[0-9]{1,20}$`; id = `shoutoutID` or `<targetId>-<now>`; login lowercased; name = `targetUserDisplayName` or the login. (Fed by the realtime shoutout topic outside this area; ChatStore.addShoutout dedupes by id.)
Oracle: `test/screens/channel/chat/mod_tools/mod_events_test.dart`.

### lib/screens/channel/chat/mod_tools/stores/mod_tools_store.dart

`ModToolsStore` (MobX `ModToolsBase`, generated `mod_tools_store.g.dart`) — the moderator side of one chat: which mod features the token allows, the live mod-action feed, the AutoMod held-message queue, Shield Mode state, per-user moderation status (for the user card), and requests to open the mod tools sheet.

`enum ModToolsView { hub, autoMod, moderators, vips }`. `typedef ModChatLine = void Function(String text, {String? actionLabel, VoidCallback? onAction})`.

`UserModStatus {banned = false, timeoutUntil?, warned = false, suspicion? (SuspiciousStatus)}`; `timedOutAt(now)` = !banned && timeoutUntil after now; `copyWith` (nullable fields passed as closures so they can be set to null).

Constructor: `twitchApi`, `broadcasterId`, `onChatLine`, optional `listenEvents`, `showActionsInChat` (default always true; ChatStore passes `settings.showModActionsInChat`), `clock` (default `DateTime.now`). Limits `maxActions = 200`, `maxHeldMessages = 100`, `maxUserStatuses = 500`.

State: `_handles`, `_subscriptions`, `_requests` (broadcast `ModToolsView` stream → `requests`), `_session` counter (invalidates async work after stop / restart); readonly `_moderatorId`, `_scopes` (Set<String>?), `_shieldActive`; `actions` (ObservableList, newest first), `heldMessages` (ObservableList, newest first), `userStatuses` (ObservableMap, recency order). Computed `isBroadcaster` (moderatorId == broadcasterId), `pendingHeldCount`.

Gates: `canUse(f)` — scopes known and moderator set; broadcaster-only features need the broadcaster; all scopes held. `needsLogin(f)` — scopes known, the feature applies to this role, a scope missing (the UI offers to log in again). `shows(f)` — a moderator is set and (not broadcaster-only or broadcaster).

`request(view)` — added to the stream unless closed.

`start(moderatorId)`: `stop()`; new session; moderator set; `getTokenScopes()` (GET `https://id.twitch.tv/oauth2/validate`, quiet on 401) — failure → empty set; stale session → abort; scopes set; `_listen()`; Shield Mode allowed → `_loadShieldMode(session)` (Helix `GET /moderation/shield_mode` → `_shieldActive` if the session is unchanged; errors logged).
`stop()` (action): session++; cancels handles and subscriptions; clears moderator, scopes, shield flag and held messages (the action feed and user statuses are KEPT). `dispose()` = stop + close the request stream.

`_listen()` — EventSub condition `{broadcaster_user_id, moderator_user_id}`; each handler only takes `EventSubData` and is wrapped (an exception is logged as `Mod event dropped (<type>)`):
- actionFeed → `channel.moderate` v2 → `_onModerate`.
- shieldMode → `channel.shield_mode.begin` v1 / `channel.shield_mode.end` v1 → `_onShield(active: true / false)`.
- autoMod → `automod.message.hold` v2 → `_onHeld`; `automod.message.update` v2 → `_onHeldUpdate`.

`_onModerate(event)`: parse with `now = clock()`; insert at 0, trim to 200; `_noteAction` (ban → banned, timeout cleared; timeout → timeoutUntil = end; unban / untimeout → not banned, timeout cleared; warn → warned); `showActionsInChat()` → `onChatLine(modActionLine(L10n.current, entry))`.
`_update(userId, change)`: remove and re-insert (most recent last), evict the oldest beyond 500.
`noteClearChat(userId, banSeconds)` (from IRC CLEARCHAT): empty id ignored; no seconds → banned; else timeoutUntil = now + seconds.
`noteShieldMode(active)`; `noteSuspicion(userId, status)` (after a successful /monitor, /restrict…).
`_onShield(event, {active})`: no-op when unchanged; sets the flag; chat line `chatShieldModeChangedBy(moderator, state)`, or `chatModShield(state)` without a moderator name.
`_onHeld(event)`: parse; ignore a duplicate id; insert at 0, trim to 100; chat line `chatAutoModHeld(name)` with action `chatAutoModReview` → `request(ModToolsView.autoMod)`.
`_onHeldUpdate` → `_setHeldStatus(id, status)` (replaces the entry when present). `clearResolvedHeld()` removes non-pending entries.
`resolveHeld(id, AutoModDecision decision)` → `String?` error: no moderator → `chatLogInToModerate`; Helix `POST /moderation/automod/message {user_id, msg_id, action: ALLOW | DENY}`; success → status approved / denied, null; error → `modToolsFailure(error, 'allowMessage' | 'denyMessage')`.
`setShieldMode(active)`: no moderator → `chatLogInToModerate`; else `PUT /moderation/shield_mode`; success → flag from the response; error → `modToolsFailure(error, 'shieldOn' | 'shieldOff')`.
`loadBan(userId)`: only with the `bans` feature; Helix `GET /moderation/banned?broadcaster_id=&user_id=` → banned = a ban without end; timeoutUntil = its end; errors logged.
`statusOf(userId)` → status or the default.

`modToolsFailure(error, command)`: Unauthorized → `chatModLogInAgain`; 403 → `chatModFailed(command, reason: chatModCannotModerate)`; other ApiException → `chatModFailed(command, reason: chatErrorText)`; else `chatModFailedUnexpected(command)`.
Oracle: `test/screens/channel/chat/mod_tools/mod_tools_store_test.dart`, `test/screens/channel/chat/mod_tools/mod_tools_sheets_test.dart`, `test/screens/channel/chat/stores/chat_store_mod_tools_test.dart`.
### lib/screens/channel/chat/mod_tools/widgets/shield_mode_indicator.dart

`ShieldModeIndicator({chatStore})` — the red "Shield Mode on" pill shown at the top-end corner of the chat (placed by chat.dart in a Padding(8), aligned end, under the Shared Chat banner) while `chatStore.shieldModeActive` (viewer can moderate AND `modTools.shieldActive`). Observer → `AnimatedSwitcher` (`motionDuration(220 ms)`; default fade) between `_ShieldPill(key 'shield')` and `SizedBox.shrink(key 'none')`. Tap → `showModTools(context, chatStore)` (the hub, where the switch is).

`_ShieldPill`: `Semantics(liveRegion: true, button: true, label: modToolsShieldModeOn, onTap)` (announced when it appears) wrapping excluded semantics of a `Material` (colour `colors.dangerTint`, stadium shape, border `colors.danger` at 50 % alpha, hairline width, anti-alias clip) → `InkWell(onTap)` → min height 32, horizontal padding 10, Row(min, spacing 5)[shield glyph 14 px stroke 2.2 `colors.danger`, text `modToolsShieldModeOn` in `SheetText.pill` 12 px `colors.danger`].
Oracle: `test/screens/channel/chat/mod_tools/mod_tools_sheets_test.dart`.

### lib/screens/channel/chat/mod_tools/widgets/mod_sheet_parts.dart

Shared building blocks of every mod tools sheet.

- `ModSheetTitle(title, {caption})`: padding 16, 4, 16, 6; Column(start, spacing 2)[`Semantics(header)` title in `SheetText.title` text colour, optional caption `SheetText.status` secondary].
- `ModSheetBody({children})`: `maxHeightFactor = 0.85` — max height 85 % of the screen; a shrink-wrapped non-primary `ListView` with bottom padding 12.
- `ModNote(text, {padding, strong = false})`: default padding 16, 8, 16, 8; strong → `SheetText.subtitle` text colour; else `SheetText.body` secondary.
- `ModHairline`: hairline, margin 16 / 6, `colors.hairline`.
- `ModCompactButton({label, onPressed, danger = false, primary = false})`: `OutlinedButton`, foreground danger → `colors.danger`, primary → accent, else text colour; min size 44×36, horizontal padding 14, stadium; border danger at 50 % alpha / accent at 55 % / `colors.ringStrong`; text `SheetText.pill`; a press plays `HapticFeedback.selectionClick()` first; disabled when `onPressed` is null.
- `ModItemTile({title, subtitle, body, actions = [], leading})`: padding 16 / 8, Row(start, spacing 12)[leading or `InitialAvatar(name: title, size 32)`, Expanded Column(spacing 3)[title `SheetText.row`, subtitle `SheetText.rowDetail` secondary, body `SheetText.body` in `colors.body`, actions in a `Wrap(spacing 8, runSpacing 6)` 4 px below]].
- `ModAddField({label, actionLabel, onSubmit, maxLength, enabled = true})`: padding 16, 4, 16, 4; Row(end, spacing 10)[Expanded `SheetTextField(controller, label, maxLength)`, `SheetButton(actionLabel)` enabled only when `enabled` and the trimmed text is non-empty (rebuilt on every keystroke)]. `_submit`: trimmed text; empty → nothing; `await onSubmit(text)` true and still mounted → clear the field (a failure keeps the text).
- `confirmModAction(context, {title, message, confirmLabel, danger = false})` → bool: `OnsetDialog` with text-tone `commonCancel` (false) and `confirmLabel` (danger or primary tone → true); dismissal → false.
- `openModLogin(context, authStore, scopes)`: `authStore.requestScopes(scopes)` (adds only scopes listed in `channelToolScopes` to the extra scopes, persisted in secure storage under the extra-scopes key; a write error is logged) then pushes `LoginWebView` (with the AuthStore provided) so the viewer logs in again and grants them.
- `mixin ModActionState<T> on State<T>`: fields `busy = false`, `statusMessage`, `statusOk = true`. `runModAction(action, {required command, success})` → bool: already busy → false; busy on and message cleared; runs the action; an exception → `modToolsFailure(error, command)` (logged as `Mod tools <command> failed`); unmounted → returns success-ness; else busy off, `statusOk = failure == null`, `statusMessage = failure ?? success`. `statusLine()` = `SheetStatusLine(busy, message, ok, minHeight 26, padding 16, 2, 16, 0)`.
Oracle: `test/screens/channel/chat/mod_tools/mod_tools_sheets_test.dart`.

### lib/screens/channel/chat/mod_tools/widgets/mod_tools_sheet.dart

The mod tools hub and its entry function.

`showModTools(context, chatStore, {view = ModToolsView.hub})` → `showOnsetSheet` (`panel: view != hub` — sub-views open as panels on tablets) with: hub → `ModToolsSheet(chatStore)`; autoMod → `AutoModQueueSheet(tools)`; moderators / vips → `RoleListSheet(chatStore, role)`. `_open(context, builder)` = `showOnsetSheet(panel: true, builder)` for every page opened from the hub (stacked over it).

**`ModToolsSheet`** (with `ModActionState`): `_chat` = the store, `_tools` = `chatStore.modTools`.
- `_run(command)`: busy on, message cleared; `await _chat.moderate(command)` (writes the chat line too); a throw → `moderationFailed`; if mounted busy off, `statusOk = outcome?.ok ?? true`, `statusMessage = outcome?.message`.
- `_toggleShield(active)`: busy; `_tools.setShieldMode(active)` → error string or null; status = error, or `chatModShield(state: on|off)` on success.
- `_shoutout()`: `showModTextDialog(title modToolsShoutoutTitle, label modToolsChannelLabel, confirm modToolsShoutoutSend, loginOnly: true)` → `_run(ShoutoutCommand(login.toLowerCase()))`.
- `_addMarker()`: dialog (modToolsMarkerTitle, modToolsMarkerLabel, modToolsMarkerAdd, maxLength 140, optional) → `_run(MarkerCommand(description))`.
- `_runCommercial()`: `showCommercialDialog` → seconds → `_run(CommercialCommand(seconds))`.
- `_raid()`: dialog (modToolsRaidTitle, modToolsChannelLabel, modToolsRaidStart, loginOnly, message modToolsRaidMessage) → `_run(RaidCommand(login lowercased))`.
- `_cancelRaid()`: `confirmModAction(modToolsRaidCancelTitle, modToolsRaidCancelMessage, modToolsRaidCancel, danger)` → `_run(UnraidCommand())`.
- `_row(feature, {glyph, label, detail, onTap, end = chevron, trailing})`: hidden (`SizedBox.shrink`) unless `_tools.shows(feature)`; when `needsLogin(feature)` → a row with detail `modToolsLogInToEnable`, chevron, tap → `openModLogin(context, auth, feature.scopes)`; else a row with the detail, `end` (none when a trailing widget is given), trailing, tap only when `canUse(feature) && !busy`.

Build (Observer) inside `ModSheetBody`:
1. `ModSheetTitle(modToolsTitle, caption: broadcaster ? modToolsCaptionBroadcaster : modToolsCaptionModerator)`.
2. While `tools.scopes == null` (still reading the token): a centered spinner (padding 16).
3. Section `modToolsSectionLive`: Shield Mode row (glyph shield, `modToolsShieldMode`, detail `modToolsShieldModeDetail`, trailing `OnsetSwitch(value: shieldActive, semanticsLabel, onChanged when usable and not busy)`, row tap toggles); AutoMod queue row (filter glyph, `modToolsAutoModQueue`, detail `modToolsAutoModPending(count)` when pending > 0 else `modToolsAutoModEmptyDetail`) → `AutoModQueueSheet`; action log row (rules glyph, `modToolsActionLog`, detail `modToolsActionLogDetail`) → `ModActionLogSheet`; when the action feed is usable, a `ChatPreferenceSwitch` (whisper glyph, `modToolsShowActionsInChat` ↔ `settings.showModActionsInChat`).
4. Section `modToolsSectionChat`: room modes row (unique glyph, `chatDetailsModes`, detail `chatDetailsModesDetail`) → panel `Observer(ChatModeControls(roomState, onModerate: _chat.moderate))` (always shown to moderators — Helix decides); announcements (bell, `modToolsAnnounce`) → `AnnounceSheet`; shoutouts (heart, `modToolsShoutout`, detail `modToolsShoutoutDetail`, no chevron) → `_shoutout`; blocked terms (block glyph, `modToolsBlockedTerms`) → `BlockedTermsSheet`; broadcaster only: permitted terms (check glyph, `modToolsPermittedTerms`, detail `chatDetailsOpensTwitch`, external) → `TwitchWebPage(https://dashboard.twitch.tv/u/<login>/settings/moderation/blocked-terms)` (no Helix API for permitted terms); unban requests (unban glyph, `modToolsUnbanRequests`) → `UnbanRequestsSheet`.
5. Broadcaster only, section `modToolsSectionChannel`: stream info (settings glyph, `modToolsStreamInfo`) → `StreamInfoSheet`; polls (poll, `modToolsPolls`) → `PollSheet`; predictions (trophy, `modToolsPredictions`) → `PredictionSheet`; reward requests (coin, `modToolsRewardRequests`) → `RedemptionsSheet`; moderators (shield, `modToolsModerators`) → `RoleListSheet(moderator)`; VIPs (diamond, `modToolsVips`) → `RoleListSheet(vip)`; raid (flame, `modToolsRaid`, no chevron) → `_raid`; cancel raid (close glyph, `modToolsRaidCancel`, feature raid) → `_cancelRaid`; marker (pin, `modToolsMarker`) → `_addMarker`; commercial (monitor, `modToolsCommercial`) → `_runCommercial`.
6. Mod View (key `mod-view`, monitor glyph, `modToolsModView`, detail `chatDetailsOpensTwitch`, external) when `twitchModViewUri(login)` is valid → `TwitchWebPage(https://www.twitch.tv/moderator/<login>)`.
7. `statusLine()`.

**`showModTextDialog(context, {title, label, confirmLabel, message, maxLength, loginOnly = false, optional = false})`** → `String?`: `_ModTextDialog` with `maxLength ?? (loginOnly ? 26 : null)` (25-char login + optional @). Valid: loginOnly → trimmed text matches `^@?[a-zA-Z0-9_]{1,25}$`; else `optional || non-empty`. Value = `singleLine(text)` (control chars to spaces, trimmed) with the first `@` removed for logins. `OnsetDialog(title, message, content: SheetTextField(label, autofocus, maxLength, counter shown only for non-login fields with a limit), actions: [text commonCancel → null, confirmLabel enabled only when valid → value])`, rebuilt on each keystroke.

**`showCommercialDialog(context)`** → `int?`: `OnsetDialog(title modToolsCommercialTitle, message modToolsCommercialMessage, content: Wrap(spacing 8, runSpacing 8) of large `SheetChoicePill(label: modToolsSeconds(count))` for 30, 60, 90, 120, 150, 180 (default 30 selected), actions: [text commonCancel, danger `modToolsCommercialStart` → seconds])`.
Oracle: `test/screens/channel/chat/mod_tools/mod_tools_sheets_test.dart`.
### lib/screens/channel/chat/mod_tools/widgets/mod_queue_sheets.dart

The AutoMod queue and the moderation action log sheets.

`_clock(context, at)` — the local time of day of `at`, formatted by `MaterialLocalizations.formatTimeOfDay` honouring the system 24-hour preference (e.g. "14:05" or "2:05 PM").

**`AutoModQueueSheet({tools})`**: state `_working` (ids being resolved), `_failure`.
- `_resolve(message, decision)`: adds the id to `_working`, clears the failure; `tools.resolveHeld(id, decision)` → error or null; if mounted removes the id and shows the error (if any).
- `_reason(l, message)`: `modToolsHeldReason(reason: blockedTerm | blockedLink | automod)` from `message.reason` (`blocked_term`, `blocked_link`, anything else → automod); when `level > 0` wrapped as `modToolsHeldLevel(reason, level)`.
- Build (Observer on `heldMessages`): `ModSheetBody[ ModSheetTitle(modToolsAutoModQueue, caption: modToolsAutoModCaption), ModNote(modToolsAutoModEmpty) when empty, one `ModItemTile` per held message (newest first): title = user name, subtitle = `[time, reason, (if resolved) modToolsHeldStatus(status: approved|denied|expired)].join(' · ')`, body = the message text, actions for a pending message: `ModCompactButton(modToolsAllow, primary)` and `ModCompactButton(modToolsDeny, danger)`, both disabled while that message is being resolved; when any message is resolved, a text `SheetButton(modToolsClearResolved)` → `tools.clearResolvedHeld()` (start-aligned, padding 16, 8, 16, 0); a `SheetStatusLine(busy false, message: _failure, ok false, minHeight 26)` ]`.

**`ModActionLogSheet({tools})`** (Observer on `actions`): `ModSheetTitle(modToolsActionLog, caption: modToolsActionLogCaption)`; `ModNote(modToolsActionLogEmpty)` when empty; per entry (newest first, max 200) `ModItemTile(title: moderatorName, subtitle: time, body: modActionLine(l, entry))`. The feed exists only since the sheet's store started listening (no history fetch).
Oracle: `test/screens/channel/chat/mod_tools/mod_tools_sheets_test.dart`.

### lib/screens/channel/chat/mod_tools/widgets/user_card_mod_panel.dart

Moderation parts of the user card (the card itself is in the excluded chat widgets folder).

`enum UserModPill { banned, timedOut, warned, monitored, restricted }`; `userModPills(status, now)` lists, in that order: banned if banned; timedOut if `timedOutAt(now)` (not banned and timeout in the future); warned; monitored / restricted from `suspicion`.

**`UserCardModPills({tools, userId, dense = false})`**: initState → `tools.loadBan(userId)` (Helix ban lookup when the `bans` feature is usable — broadcaster with the scope). Observer: no pills → nothing; else padding (16, 8 dense / 10, 16, 0), `Wrap(spacing 6, runSpacing 6)` of pills: height 24 dense / 26, horizontal padding 10, stadium filled `colors.dangerTint` with border `colors.danger` at 45 % alpha (hairline), centered text `modToolsUserPill(pill: name)` in `SheetText.pill` 11.5 (dense) / 12 px, `colors.danger`. (Status is evaluated against `DateTime.now()` at build; a timeout expiring does not by itself rebuild the pill.)

**`UserCardModActions({chatStore, login, userId, name, isModerator, isVip})`** (with `ModActionState`): the extra moderation actions sheet of the user card.
- `_run(command, {confirmTitle, confirmMessage, confirmLabel})`: when a confirm title is given → `confirmModAction(..., danger: true)`; cancelled or unmounted → stop. Busy; `chatStore.moderate(command, userId: userId)` (the known id skips the login lookup; the outcome line also goes to chat); status = outcome message, ok = `outcome?.ok ?? true`.
- `_row(feature, {glyph, label, onTap, danger})`: hidden unless `shows(feature)`; `needsLogin` → row with detail `modToolsLogInToEnable` → `openModLogin`; else a row (danger styling optional) tappable when `canUse(feature) && !busy`.
- `isModerator` / `isVip` are fixed constructor values and the Observer only tracks `statusOf(userId)` (ban/timeout/warn/suspicion), so after a successful role change the role rows keep their old label and offer the same change again until the sheet is reopened (Known Android defects).
- Build (Observer on `statusOf(userId)`): `ModSheetTitle(modToolsUserActionsTitle, caption: name)`; rows: shoutout (heart, `modToolsShoutoutUser`) → `ShoutoutCommand(login)`; monitor toggle (monitor glyph, `modToolsUnmonitor` when monitored else `modToolsMonitor`) → `SuspicionCommand(login, monitored, on: !monitored)` (no confirmation); restrict toggle (lock glyph, `modToolsUnrestrict` / `modToolsRestrict`, danger when restricting) → `SuspicionCommand(login, restricted, on: !restricted)` with confirmation only when restricting (`modToolsRestrictTitle`, `modToolsRestrictMessage(name)`, confirm `modToolsRestrict`); moderator role (shield, `modToolsRemoveModerator` / `modToolsMakeModerator`, danger when removing) → `RoleCommand(login, moderator, granted: !isModerator)` always confirmed (`modToolsRoleConfirmTitle(change: removeModerator|addModerator)`, `modToolsRoleConfirmMessage(change, name)`, confirm `modToolsRemove` / `modToolsConfirm`); VIP role (diamond, `modToolsRemoveVip` / `modToolsMakeVip`, danger when removing) → `RoleCommand(login, vip, granted: !isVip)` confirmed (`change: removeVip|addVip`); `statusLine()`. Login is lowercased before use.
Oracle: `test/screens/channel/chat/mod_tools/mod_tools_sheets_test.dart`, `test/screens/channel/chat/stores/chat_store_mod_tools_test.dart`.
### lib/screens/channel/chat/mod_tools/widgets/mod_list_sheets.dart

List-type mod tools sheets: moderators / VIPs, blocked terms, unban requests, channel-points reward requests. Helix base `https://api.twitch.tv/helix`.

**`_ModListState<W, T>`** (abstract, with `ModActionState`): `items` (null = loading), `loadFailure`; abstract `chat` (ChatStore) and `load()`; `moderatorId` = viewer id or ''. initState → `reload()`: clears the failure; `load()` → items; error → `loadFailure = modToolsFailure(error, 'load')` (logged). `listState({empty, tile})`: failure → [`ModNote(failure)`, start-aligned text `SheetButton(commonRetry)` → reload]; loading → [centered spinner, padding 20]; empty → [`ModNote(empty)`]; else one tile per item.

**`RoleListSheet({chatStore, role})`** (moderators or VIPs; broadcaster only): `load()` = `moderation.getRoleUsers(broadcasterId, role)` (`GET /moderation/moderators` or `GET /channels/vips`, up to 10 pages of 100 (≤ 1000 entries; anything past that is silently not shown)).
- `_add(login)`: name = text with the FIRST `@` anywhere removed (`replaceFirst('@','')`, not only a leading one); no login validation (any text goes to `RoleCommand` and fails later at the `getUser` lookup); the `ModAddField` is NOT given `enabled: !busy` (unlike BlockedTermsSheet) and `_change` does not check `busy`; confirmation `modToolsRoleConfirmTitle(change: addModerator|addVip)`, `modToolsRoleConfirmMessage(change, name)`, confirm `modToolsConfirm` (not danger); confirmed → `_change(name, granted: true)` → ok → reload. Returns ok (ModAddField clears on true).
- `_change(login, {granted})`: busy; `chat.moderate(RoleCommand(login lowercased, role, granted))` (also writes the chat line); status ok = `outcome?.ok ?? false`, message = outcome message.
- `_remove(user)`: confirmation (`removeModerator|removeVip`, name = display name, confirm `modToolsRemove`, danger) → `_change(user.userLogin, granted: false)` → ok → reload.
- Build: `ModSheetTitle(modToolsModerators | modToolsVips, caption: count known → modToolsModeratorCount(count) | modToolsVipCount(count))`; `ModAddField(label modToolsUserLabel, action modToolsAdd, maxLength 26, onSubmit _add)`; `statusLine()`; list (empty → `chatModRoleListEmpty(role)`): `ModItemTile(title displayName, subtitle: the login when the display name lowercased differs from it, actions [danger ModCompactButton(modToolsRemove) disabled while busy])`.

**`BlockedTermsSheet({chatStore})`**: `load()` = `getBlockedTerms(broadcasterId, moderatorId)` (`GET /moderation/blocked_terms`, up to 10 pages of 100 (≤ 1000 entries; anything past that is silently not shown)).
- `_add(text)`: `singleLine(text)` shorter than `ModTextLimits.blockedTermMin` (2) code points → status error `modToolsBlockedTermTooShort`, false. Else `runModAction(addBlockedTerm(broadcasterId, moderatorId, text)` (`POST /moderation/blocked_terms`), command `blockTerm`, success `modToolsBlockedTermAdded)`; on ok the returned term is put FIRST and any same-id term removed (no reload).
- `_remove(term)`: confirmation (`modToolsRemoveTermTitle`, `modToolsRemoveTermMessage(term)`, `modToolsRemove`, danger) → `runModAction(removeBlockedTerm(broadcasterId, moderatorId, termId)` (`DELETE /moderation/blocked_terms?id=`), command `unblockTerm`, success `modToolsBlockedTermRemoved)` → removed locally.
- Build: `ModSheetTitle(modToolsBlockedTerms, caption modToolsBlockedTermsCaption)`; `ModAddField(label modToolsTermLabel, action modToolsAdd, maxLength 500 (`ModTextLimits.blockedTerm`), enabled while not busy)`; `statusLine()`; list (empty `modToolsBlockedTermsEmpty`): `ModItemTile(leading block glyph secondary, title term.text, subtitle `modToolsTermTemporary` when it has an expiry, actions [danger remove])`.

**`UnbanRequestsSheet({chatStore})`**: `load()` = `getPendingUnbanRequests(broadcasterId, moderatorId)` (`GET /moderation/unban_requests?status=pending`, up to 10 pages of 100 (≤ 1000 entries; anything past that is silently not shown)).
- `_resolve(request, {approve})`: `_askResolution` → `_ResolutionDialog` returns the note (null = cancelled); `runModAction(resolveUnbanRequest(broadcasterId, moderatorId, requestId, approve, resolution: note)` (`PATCH /moderation/unban_requests` with status approved/denied and resolution_text), command `approveUnban` / `denyUnban`, success `modToolsUnbanResolved(decision: approved|denied, name))` → removed locally.
- Build: `ModSheetTitle(modToolsUnbanRequests, caption modToolsUnbanCaption)`; `statusLine()`; list (empty `modToolsUnbanEmpty`): `ModItemTile(title displayName, subtitle `modToolsRequestedOn(date)` when `createdAt` non-empty (date = `formatMediumDate` of the parsed ISO date in local time, or the raw string if unparsable), body = the request text, actions [primary `modToolsApprove`, danger `modToolsDeny`] disabled while busy)`.
- `_ResolutionDialog({name, approve})`: `OnsetDialog(title modToolsUnbanDialogTitle(decision), message modToolsUnbanDialogMessage(decision, name), content SheetTextField(label modToolsUnbanNoteLabel, maxLength 500 (`ModTextLimits.resolution`), counter), actions [text commonCancel → null, `modToolsApprove` (primary) / `modToolsDeny` (danger) → `singleLine(note)` (may be empty)])`.

**`RedemptionsSheet({chatStore})`** (broadcaster): `load()` = `getPendingRedemptions(broadcasterId)` (`GET /channel_points/custom_rewards?broadcaster_id=&only_manageable_rewards=true` — only rewards created by this app's client id are returned, the API filters the rest; reward ids not matching `^[A-Za-z0-9_-]{1,64}$` are skipped; then, ONE REWARD AFTER ANOTHER (sequential, not parallel), `GET /channel_points/custom_rewards/redemptions?broadcaster_id=&reward_id=&status=UNFULFILLED&sort=OLDEST` with `first=100` and at most 2 pages (≤ 200 per reward); the merged list is sorted ascending by `redeemedAt`, so the sheet shows the OLDEST first).
- `_resolve(redemption, decision)`: a refund (`RedemptionDecision.canceled`) asks first (`modToolsRefundTitle`, `modToolsRefundMessage(name, reward)`, confirm `modToolsRefund`, danger); `runModAction(resolveRedemption(broadcasterId, rewardId, redemptionId, decision)` (`PATCH /channel_points/custom_rewards/redemptions` status FULFILLED / CANCELED), command `refund` / `fulfil`, success `modToolsRefunded` / `modToolsFulfilled`) → removed locally.
- Build: `ModSheetTitle(modToolsRewardRequests, caption modToolsRewardRequestsCaption)`; `statusLine()`; list (empty `modToolsRewardRequestsEmpty`): `ModItemTile(title displayName, subtitle modToolsRedemptionReward(reward title, cost), body = user input when non-empty, actions [primary `modToolsFulfil`, danger `modToolsRefund`])`; `ModHairline`; row (coin glyph, `modToolsRewardQueueWeb`, detail `chatDetailsOpensTwitch`, external) → `TwitchWebPage(title modToolsRewardRequests, url https://www.twitch.tv/popout/<login>/reward-queue)` for rewards Helix cannot manage.
Oracle: `test/screens/channel/chat/mod_tools/mod_tools_sheets_test.dart`.
### lib/screens/channel/chat/mod_tools/widgets/mod_compose_sheets.dart

Mod tools sheets that compose something: announcements, polls, predictions, stream info. Helix base `https://api.twitch.tv/helix`; text limits from `ModTextLimits` (announcement 500, pollTitle 60, pollChoice 25, poll choices 2–5, poll duration 15 s–30 min, predictionTitle 45, predictionOutcome 25, outcomes 2–10, prediction window 30 s–30 min, streamTitle 140, tagsMax 10, tag 25).

`kAnnouncementColors`: primary → null (drawn in the accent colour), blue `#00D6D6`, green `#00DB84`, orange `#FFB31A`, purple `#9147FF`. `_FormPadding` = padding 16, 6, 16, 6.

**`AnnounceSheet({chatStore})`** (ModActionState): `_message` controller, `_color = primary`.
- `_send()`: sets `busy = true` only — unlike `runModAction` it neither clears `statusMessage` (the previous outcome stays visible under the spinner) nor returns early when already busy (no re-entry guard; the button is disabled while busy, which is the only protection); `chatStore.moderate(AnnounceCommand(singleLine(text), color))` (`POST /chat/announcements`; the outcome line also goes to chat); a throw → `moderationFailed`; status from the outcome (`ok ?? true`); success clears the field.
- Build: `ModSheetTitle(modToolsAnnounce, caption modToolsAnnounceCaption)`; `SheetTextField(label modToolsAnnounceLabel, maxLength 500, counter)`; section `modToolsAnnounceColor`; a `Wrap(spacing 8, runSpacing 8)` of [10 px colour dot (swatch or accent) + large `SheetChoicePill(modToolsAnnounceColorName(color: primary|blue|green|orange|purple), selected)`]; large expanded `SheetButton(modToolsAnnounceSend)` disabled while busy or when the single-lined text is empty (rebuilt per keystroke); `statusLine()`.

`kPollDurations` = 1, 2, 5, 10, 30 minutes (default 2 min). `kPredictionWindows` = 30 s, 1, 2, 5, 10 min (default 2 min). `_ChoiceFields({controllers, label(number), maxLength, max, onAdd, addLabel})`: one `SheetTextField(label(index + 1), maxLength)` per controller, then a start-aligned text button `addLabel` while fewer than `max`. `_DurationPills({values, selected, onSelected})`: large pills labelled `timeoutLength(seconds)` ("1 minute", "30 seconds"). `_controllers(count)` makes N controllers.

**`PollSheet({chatStore})`** (broadcaster): `_title`, `_choices` (2 to start), `_duration = 2 min`, `_poll`, `_loading = true`.
- initState → `_load()`: `getLatestPoll(broadcasterId)` (`GET /polls`, first) — errors logged → `_poll` (or null), loading off.
- `_ready` = non-empty title and at least 2 non-empty choices.
- `_create()`: `runModAction(createPoll(broadcasterId, title, choices, duration)` (`POST /polls {title, choices: [{title}], duration seconds}`; the API keeps only non-empty single-lined choices cut to 25 and validates 2–5 and 15 s–30 min), command `createPoll`, success `modToolsPollStarted)` → the created poll is shown.
- `_end(poll)`: confirmation (`modToolsPollEndTitle`, `modToolsPollEndMessage`, `modToolsPollEnd`, danger) → `runModAction(endPoll(broadcasterId, pollId)` (`PATCH /polls status TERMINATED`), command `endPoll`, success `modToolsPollEnded)` → shows the ended poll.
- Build: `ModSheetTitle(modToolsPolls, caption modToolsPollsCaption)`; loading → spinner; an ACTIVE poll → section `modToolsPollLive`, `ModNote(title, strong)`, one tile per choice (`leading` 4 px spacer, title, subtitle `modToolsVotes(count)`), danger expanded `modToolsPollEnd` button; otherwise the form: title field (`modToolsQuestionLabel`, max 60, counter, setState per change), `_ChoiceFields(label modToolsChoiceLabel(number), max length 25, max 5, add `modToolsAddChoice`)`, section `modToolsPollDuration`, duration pills, large expanded `modToolsPollStart` (disabled while busy or not ready; rebuilt when any choice changes); `statusLine()`.

**`PredictionSheet({chatStore})`** (broadcaster): `_title`, `_outcomes` (2), `_window = 2 min`, `_prediction`, `_loading`.
- `_load()`: `getLatestPrediction(broadcasterId)` (`GET /predictions`, first), errors logged.
- `_ready` = title and ≥ 2 non-empty outcomes. `_create()`: `createPrediction(broadcasterId, title, outcomes, window)` (`POST /predictions {title, outcomes: [{title}], prediction_window seconds}`, validated 2–10 outcomes, 30 s–30 min), command `createPrediction`, success `modToolsPredictionStarted`.
- `_end(prediction, end, {winner})`: confirmation titled `modToolsPredictionLockTitle` / `modToolsPredictionCancelTitle` / `modToolsPredictionResolveTitle`, message `modToolsPredictionLockMessage` / `modToolsPredictionCancelMessage` / `modToolsPredictionResolveMessage(outcome: winner title)`, confirm `modToolsPredictionLock` / `modToolsPredictionCancel` / `modToolsPredictionResolve`, danger unless resolving → `endPrediction(broadcasterId, predictionId, end, winningOutcomeId)` (`PATCH /predictions status LOCKED | CANCELED | RESOLVED (+ winning_outcome_id)`), command `lockPrediction` / `resolvePrediction` / `cancelPrediction`, success `modToolsPredictionUpdated(state: locked|resolved|canceled)` → shows the updated prediction.
- Build: `ModSheetTitle(modToolsPredictions, caption modToolsPredictionsCaption)`; loading → spinner; an OPEN prediction (active or locked) → section `modToolsPredictionLocked` / `modToolsPredictionLive`, `ModNote(title, strong)`, per outcome a tile (subtitle `modToolsPredictionUsers(count) · modToolsPredictionPoints(count)`, action primary `modToolsPredictionPickWinner` → resolve with it), then a Wrap with text button `modToolsPredictionLock` (only while still active, not locked) and danger `modToolsPredictionCancel`; otherwise the form: title (`modToolsQuestionLabel`, max 45, counter), `_ChoiceFields(label modToolsOutcomeLabel(number), max length 25, max 10, add `modToolsAddOutcome`)`, section `modToolsPredictionWindow`, window pills, large `modToolsPredictionStart`; `statusLine()`.

**`StreamInfoSheet({chatStore})`** (broadcaster, `channel:manage:broadcast`): controllers `_title`, `_category` (search), `_tag`; state `_tags`, `_gameId`, `_gameName`, `_results` (≤ 5 categories), `_loading`, `_tagProblem`, `_loadFailure`, and the loaded baseline `_loadedTitle`, `_loadedGameId`, `_loadedTags`.
- `_load()`: `twitchApi.getChannel(userId: channelId)` (Helix `GET /channels?broadcaster_id=`) → title, game id/name, tags (and their baseline copies); error → `_loadFailure = modToolsFailure(error, 'loadStream')`.
- `_tagsChanged` (length or any position differs), `_changed` = `singleLine(title field)` differs from `_loadedTitle`, game differs, or tags changed. `_loadedTitle` is the RAW `channel.title`, so a stored title with leading/trailing spaces or control characters counts as changed without any edit and Save is enabled at once (Known Android defects).
- `_search(query)`: empty → clear results; else `twitchApi.searchCategories(query)` (Helix `GET /search/categories`) — applied only if the field still holds that query (stale answers dropped) → first 5; errors logged.
- `_addTag()`: tag = single-lined text with all spaces removed; empty → nothing; invalid (`isValidStreamTag`: `^[\p{L}\p{M}\p{N}]{1,25}$`, letters/marks/digits only) → `_tagProblem = modToolsTagInvalid`; already 10 tags → `modToolsTagLimit(count: 10)`; else problem cleared, appended unless an equal tag (case-insensitive) exists, field cleared.
- `_save()`: `runModAction(updateStreamInfo(broadcasterId, title: changed only, gameId: changed only, tags: changed only)` (Helix `PATCH /channels?broadcaster_id=` with only the changed fields; the API would clear the category with game id '', but the sheet has NO UI to clear it — `_gameId` is only set from a search result), command `updateStream`, success `modToolsStreamInfoSaved)`; on success the baseline becomes the saved values.
- Build: loading → title + spinner; failure → title, `ModNote(failure)`, text button `commonRetry` → `_load`; else `ModSheetTitle(modToolsStreamInfo, caption modToolsStreamInfoCaption)`; title field (`modToolsStreamTitleLabel`, max 140, counter); category field (`modToolsCategoryLabel`, hint = current game name or `modToolsCategoryNone`, search on change); one `SheetRow` per result (check glyph accent on the current game; tap selects it, clears results and the field); section `modToolsTags`; a Wrap of `_TagPill`s (remove tooltip `modToolsRemoveTag(tag)`); `ModAddField(label modToolsTagLabel, action modToolsAdd, maxLength 25, onSubmit: put the text in `_tag`, `_addTag()`, return no problem)`; the tag problem note (padding 16, 0, 16, 4); large expanded `modToolsSave` disabled while busy, with an empty title, or when nothing changed; `statusLine()`.
`_TagPill`: min height 36, padding start 14, `colors.chip` stadium with `colors.ring` border; tag text `SheetText.pill`; compact `IconButton(tooltip, close glyph 14 stroke 2.2 secondary)` removing it.
Oracle: `test/screens/channel/chat/mod_tools/mod_tools_sheets_test.dart`.
