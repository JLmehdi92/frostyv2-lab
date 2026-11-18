# 07 — Social: channel profile, team, channel preferences, Activity, Twitch notifications, whispers

> Cross-spec decisions in [00-index.md](00-index.md) (section "Decisions") override any conflicting PC suggestion in this file.

Scope (source of truth: `/home/user/frostyv2-lab`): `lib/screens/channel_profile/**`, `lib/screens/activity/**`, `lib/screens/notifications/**`, `lib/screens/whispers/**`, and their tests under `test/screens/channel_profile/**`, `test/screens/activity/**`, `test/screens/notifications/**`, `test/screens/whispers/**`. Generated MobX parts (`*.g.dart`) are not described line by line: they are regenerated from the stores (they hold the `_$Store` mixins: atoms for every `@readonly`/`@observable`, `Computed` wrappers, `AsyncAction`s for `_load`/`_loadSchedule`/`refresh`/`loadMore`/`sendRead`, and `ActionController` wrappers for the sync actions). Everything outside the scope that these screens call (Twitch services, `WhisperStore`, `ScheduleReminders`, `ActivityLog`, `FollowFlow`, shared widgets) is summarised only as far as needed to rebuild the behaviour, and is specified in its own leaf.

## Purpose

These screens are ONSET's "social" surface — everything about people and channels that is not the player or the chat:

1. **Channel profile** (`ChannelProfileScreen`): a Twitch-app-style profile page for any channel, reachable from a followed channel, the channel info bar avatar, the channel actions sheet, a team member, links and deep links. It shows the banner, avatar (with a pulsing live ring), name, followers and partner/affiliate role, the live/last-broadcast card, Watch/Chat, Follow and Subscribe, Share and More, and six tabs: Home (trailer, next stream, recaps shelf, recent broadcasts, popular clips), Videos (past broadcasts, highlights, uploads), Clips, Collections (only when the channel has some), Schedule (by day, vacation banner, weekly tags, reminders, slot sheet) and About (bio, facts, teams, socials, Markdown panels). It degrades gracefully: the profile comes from anonymous GQL; if GQL fails, the Helix `/users` header still lets the viewer reach the channel, and "not found" is only said once Helix agrees.
2. **Team page** (`TeamScreen`): a Twitch team with live members first (most watched first) then the others.
3. **Channel preferences** (`ChannelPreferencesScreen`): per-channel switches — go-live bell, chat notices, pin, hide from Browse.
4. **Activity** (`ActivityScreen`): Twitch's Activity tab, rebuilt locally: the notifications ONSET itself posted on this device (go-live, chat mentions, schedule reminders), "Most recent" / "Earlier", unread dots, mark all read, remove with a fold animation, a Follow button on rows about channels the viewer does not follow, and — when logged in — the whispers (a tab on phone, a column on tablet). The Home bell count is `newCount` (cleared by opening Activity).
5. **Twitch notifications** (`NotificationCenterScreen` + `TwitchInboxEntry`): the twitch.tv on-site notification inbox (needs the twitch.tv web session token): paging, unseen badge, mark all read with Undo.
6. **Whispers** (`WhispersScreen`, `WhisperConversation`, actions, kit, notice): the viewer's direct messages: thread list, conversation with bubbles and composer, mute/archive/hide/stop-replies, new whisper search, status note when whispers may not arrive, in-app notice for incoming whispers; phone slide-over with edge swipe, tablet two-pane.

The fork mission (low-latency player) touches these screens only through `preloadChannel` (finger-down on Watch/live card starts the playback token request early) and `VideoChat` navigation; no feature here may be lost in the Windows rewrite.

## Screens and layouts

**Colour note (applies to the whole document).** "Live colour" / "signal colour" always means `context.onsetColors.live`, which is theme-dependent: **#C8FF3D in dark, #6B9E00 in light** (`lib/theme.dart` `OnsetColors.dark/light`). It is used by the live ring and badges, Watch pill, tab indicator, date-tile and remind highlights (dark only), tile progress bars, Activity unread dot / go-live kind badge / Follow button, whisper unread pill, selected-thread bar, send button, composer cursor and the whisper notice's "Open". It is NOT `OnsetTokens.accent`, which is a fixed #C8FF3D in both themes and is used here only by the Twitch-notifications unread dot and the inbox entry's unseen pill (with black text).

**Channel profile — phone** (window not large, or width < 720): a `NestedScrollView` whose header is ONE pinned `SliverPersistentHeader` (`ProfilePhoneHeader`): banner (height `clamp(screenHeight * 0.2, 96, 168)`) with Back (left) and Share / More (right) round 44 dp buttons over it; under it the measured `ProfileHeader` (avatar 88 dp hanging 44 dp over the banner edge, name 24/800 + "followers · role", restricted-channel banner (phone `ProfileHeader` only: `ProfileRail` on tablet never shows it), live card 112x63, Watch/Chat + Follow + Subscribe pills of 44 dp) and the tab strip (40 dp + text scale). Scrolling folds the banner into a 56 dp bar (ground colour fading in, the name fading in over the last 30 % of the fold) with the tabs pinned under it. Tab bodies scroll beneath (`SliverOverlapInjector`), each with pull to refresh offset below the pinned header. Content padding: Home, Schedule and About LTRB(16 + safeLeft, 14, 16 + safeRight, safeBottom + 24); Videos: its type pills row padded LTRB(16 + safeLeft, 12, 16 + safeRight, 4) above the shared `ChannelVideosTab` list; Collections: a 12 dp top sliver and a bottom sliver of safeBottom + 16; Clips: the shared `ChannelClipsTab` padding (clips leaf).

**Channel profile — tablet** (large screen AND width >= 720): a `Stack`: full-width banner `safeTop + 230` tall; a left rail (280 wide, 330 at >= 1100) starting at `safeTop + 150`, x = 32 + safeLeft (avatar 120 with 4 dp ring, name 30/800, full-width "Watch live" 48 dp signal pill with a 16 dp play glyph while live — offline the same slot is an outlined raised 48 dp "Chat" pill with NO glyph (the glyph only exists on the live FilledButton when height > 44) — Follow and Subscribe side by side under it, bio, social pills), scrollable; the content pane from x = rail end + 38 to 32 from the right edge, starting at `safeTop + 196`: tab strip (44 dp, 16 sp) above a `TabBarView`; Back at (20 + safeLeft, safeTop + 16), Share/More row (spacing 8) at (20 from right, safeTop + 16), discs at 50 % black. Tab content padding top 20, bottom safeBottom + 24. Home on tablet puts the big 16:9 stream card (480 wide) beside "COMING UP" (two next streams) when the pane is >= 778 wide, else stacked.

**Not found**: full-screen "Channel not found." with Try again and a Back button (bar style) at (8 + safeLeft, safeTop + 6).

**Team page**: Material AppBar (team name, or "Teams"), a centred column max 760 wide with gutter 16/28: logo 64 + name 22/800 + "N members"; info; "Live now" grid; "Members" grid (1 column, 2 when large and >= 600 wide); member rows 36 dp initial avatar, name, game/title, viewers in the live colour.

**Channel preferences**: settings scaffold titled "Channel preferences" with an intro note and three groups (Notifications: bell; Chat: notices; Lists: pin, hide).

**Activity — phone**: a section of the navigation shell; the shell header carries the Notifications/Whispers tabs (badges = unread). Notifications list: Twitch notifications entry card, "Most recent" (with "Mark all as read"), rows, "Earlier", rows, footer note. Rows 44 dp avatar with unread dot and kind badge. Long press -> bottom sheet "Remove notification". Whispers tab = `WhispersList`.

**Activity — tablet**: page title "Activity" 30/800 + note, "Mark all as read" pill with the count; notifications in rounded cards (radius 20) "Most recent" / "Earlier"; when logged in a whispers column (320, 392 at >= 1100) on the right with "See all"; long press -> popup menu at the row's top right. Without whispers the list is centred, max 860.

**Twitch notifications**: AppBar "Twitch notifications" with a mark-all icon; list max 760 on tablet; rows 44/48 avatar, body (3 lines), time, accent unread dot; infinite scroll.

**Whispers — phone**: list page (56 dp header: back, "Whispers" 20/700, new-whisper button) with the status note, thread rows (72 dp, 48 avatar), archived toggle; tapping a thread slides the conversation over the list (340 ms, list parallax -28 % and dimming to 40 %); conversation page: 56 dp header (back, 32 dp avatar, name, more), reversed bubble list with the session note on top, error line, composer pill + 44 dp send disc.

**Whispers — tablet**: padding 28; left list column 320 (372 at >= 1000) with header (back, "Whispers" 26/800, new, "N unread"/"All read"); right pane (radius 24, ring) with the conversation (72 dp header with 44 avatar, name and login; column centred max 720/760) or "Choose a conversation" / empty state; the most recent conversation auto-opens.

**Incoming whisper notice**: floating snackbar card (480 wide on tablet; margins 10 on phone) with avatar + whisper badge, "Name text" on two lines, "Open".

## Behaviour and state

- **Profile loading**: `load()` and `loadSchedule()` start in `initState` (schedule at once because Home shows the next stream). Concurrent calls join the in-flight request. Extras (trailer, teams, collections, DJ flag) load in parallel after a profile; each failure is swallowed. A GQL `null` user triggers a Helix check; only when Helix also has nothing is `notFound` set. A GQL failure sets `error` and fetches the Helix header once (`fallback`), so name/avatar/id still show and Chat/More work. Retry after a failure that Helix answers updates the header. `refresh()` reloads the schedule only if it was shown before. Pull-to-refresh failures over a shown profile show the snackbar "Couldn’t refresh this channel.".
- **Tabs**: Collections appears only when collections load non-empty; the controller is rebuilt keeping the current tab (or switching to an initially requested tab once it exists — deep link to Collections lands there). Selecting Schedule with no schedule and no load in progress triggers a load. A window resize between phone and tablet keeps the tab (same controller). Each tab keeps its scroll (PageStorageKey per tab, per video type).
- **Follow**: a `ChannelInfoStore` is created once the channel id is known (from store or caller), never on the viewer's own channel; viewer changes call `viewerChanged()`; Follow is hidden when logged out. Subscribe shows for partners/affiliates with a valid login, even logged out, never on one's own channel.
- **Watch/Chat**: live -> "Watch" (phone) / "Watch live" (tablet) signal pill; offline -> "Chat" raised pill. From the channel screen (`fromChannel`) Watch pops back instead of opening a second player, and no preload happens. Without any id, Chat shows "Couldn’t open this channel. Check your connection." (`profileOpenFailed`). Finger-down on Watch or the live card calls `preloadChannel` (playback token early).
- **Share**: shares `https://www.twitch.tv/<login>`; where no share sheet exists the link is copied and "Link copied" is shown (shared `shareLink`). **More**: `UserActionsModal` with pin option, no "profile" entry.
- **Reminders**: the schedule reaction calls `ScheduleReminders.shared.sync(login, segments)` so reminders move or disappear with the schedule. Setting a reminder first explains notification permission if not granted; refusal -> "profileReminderRefused" snackbar, failure -> "profileReminderFailed".
- **Live avatar pulse**: runs only when live, app resumed, avatar visible (not under the folded bar), not reduce-motion; otherwise no frames are scheduled.
- **Team page**: loads team (Helix), then live statuses of the first 100 members; live first by viewers desc; tapping a live member opens the player, others open their profile; failures show a retry; a failed live lookup still lists members.
- **Activity**: opening (or returning to the foreground on) Activity refreshes from storage and marks viewed (bell count cleared; unread stay bold). Anything arriving while Activity is seen is marked viewed immediately; while in the background it stays new. Tap = mark read + open channel. Remove = removed from storage at once, row folds 300 ms (instant under reduce motion); if storage refuses, the row comes back. "Most recent" = last 24 h; if nothing is that recent, the older ones are shown as "Most recent". Follow button on mention/reminder rows when the viewer does not follow (one lookup per channel, cached), never on go-live rows or when logged out. Logged out: no Whispers tab whatever the requested tab.
- **Twitch notifications**: shown only with a twitch.tv web session; unseen count fetched on show and re-fetched after returning from the inbox. Mark all: optimistic, Undo for the snackbar's life, the mutation sent only after the snackbar closes; on failure rows return to unread and the outcome text is shown. Rows open the channel (User extra) or a twitch.tv link in the in-app Twitch page; others are inert. Pages of 30, dedup, capped at 300.
- **Whispers**: opening a conversation marks it read (`store.open`), closing it (`store.close`) makes later whispers count as unread again; whispers arriving in the open conversation are read already and slide in (280 ms) if their row is first built within 1 s of arrival (the arrival time is removed from the map on that first build, whether or not it animates). Sending shows a ring in the send disc, prevents a second send, keeps the text on failure and shows the reason; success clears only if the text did not change meanwhile. An account change closes the open conversation. Phone: back (system or button) closes the conversation before leaving; left-edge swipe (20 dp + safeLeft) follows the finger; on release it closes when `velocity > 700 || (velocity > -700 && value < 0.5)` (velocity in px/s, positive = rightwards), otherwise it settles back open. Tablet: auto-opens the most recent thread until the viewer closes/hides one. A conversation opened "alone" (from chat/notice) leaves the page on back. Long press on a thread / More in a conversation: mute, archive, stop replies (if a remote thread id and web session exist), hide (confirmed). From a conversation's More, Hide also closes it (`onHidden`: phone back / tablet empty pane); a long-press Hide in `WhispersList` passes no `onHidden`, so on a tablet the hidden conversation stays open in the pane (see Known Android defects). History (`refreshHistory`) is throttled by `WhisperStore.historyRefreshGap = 30 s`: called from `WhispersScreen.initState` and `WhispersList.initState`, a second call within 30 s of the last request does nothing. The throttle is per account: an account change (`me` changes) clears `_historyAskedAt` (and `_historyAvailable`, threads, remote thread ids, hidden-at times, open ids), so the new account fetches its history at once even inside the 30 s. `WhisperStore.unreadCount` sums `unread` over non-archived (`threads`) and non-muted threads only. Archived threads are listed behind a toggle. New whisper: debounced (300 ms) Helix channel search excluding the viewer. Logged out: sign-in invitation. The status note explains refused/interrupted/unavailable/off.
- **Whisper notice**: "Open" works only for the account that was current when it was shown.

## Animations and motion

All tokens from `lib/widgets/motion/motion.dart` (`OnsetMotion`): `standard = Cubic(0.2, 0, 0, 1)`; `springMomentum` = spring with duration 400 ms, bounce 0.2; `pressScale = 0.97`, `pressDuration = 100 ms`; `reducedFade = 150 ms` (what `motionDuration` returns under reduce motion).

| Element | Animation |
|---|---|
| `PressScale` (cards, pills, buttons, rows everywhere here) | on pointer down scale to 0.97 in 100 ms with `standard`; on release a spring (`springMomentum`, from current value/velocity) back to 1; cancelled when the pointer moves beyond touch slop; disabled under reduce motion and when `enabled: false` (send button not ready). |
| Profile avatar live ring pulse | 1600 ms repeating; ring spread 0 -> 14 dp (16 on tablet) eased with `Cubic(0.2,0,0,1)`, opacity 0.55 -> 0; stops (value 0) when offline, reduce motion, app not resumed, avatar hidden under the bar, or off-screen. |
| Phone profile header fold | scroll-driven (no timer): `t = shrinkOffset / (bannerHeight - 56)`; bar background alpha = t; title opacity = `(t - 0.7) / 0.3`; round buttons lose their disc and lerp glyph colour by t; status-bar style switches at t > 0.6. |
| Tab change (profile) | Material `TabController.animateTo` (300 ms, ease) for "See all"; the indicator (2/2.5 dp signal line) follows swipes; `Haptics.selection()` on tap. |
| Live card uptime | text rebuilt each minute (shared 1 s clock, minute change only); live preview image refreshed every 5 minutes via cache key, old image kept until the new one loads (`useOldImageOnUrlChange`). |
| Skeletons | `SkeletonLoader` global sheen (shared shimmer) for avatar meta line, tiles, schedule cards, About lines. |
| Activity row removal (`_Folding`) | 300 ms reverse: size with `standard` (axisAlignment -1, collapses toward the top), fade with `Interval(1/3, 1)`; skipped under reduce motion (removed at once). |
| Whispers phone slide | `AnimationController` created at 340 ms whatever reduce motion says (an initial `initial` conversation starts at value 1, so nothing plays); `_select`/`_back` reset the duration to `motionDuration(340 ms)` (150 ms under reduce motion); value eased with `standard` except during a drag (linear under the finger); conversation `FractionalTranslation(1 - t)` with left shadow `#8C000000`/`#29000000`, offset (-18, 0), blur 40 while moving; list translates `-0.28 * width * t` and fades to `1 - 0.6 t`; reduce motion: no translation, list opacity `1 - t`, conversation opacity `t` (cross-fade). Drag release: always `340 * remaining` ms with `standard`, even under reduce motion. |
| Whisper bubble arrival | 280 ms `SizeTransition` + `FadeTransition` with `standard` for whispers whose first build happens < 1 s after arrival (the arrival entry is consumed by that first build); none under reduce motion. |
| Whisper status note | `AnimatedSize` 300 ms `standard` (top aligned) + `AnimatedSwitcher` 300 ms cross-fade; both 150 ms under reduce motion; interrupted state shows an indeterminate 14 dp spinner. |
| Archived toggle chevron | `AnimatedRotation` 0 -> 0.5 turns, fixed 200 ms, default LINEAR curve (no curve given), and it ignores reduce motion (still rotates 200 ms) — Known Android defect 7; PC rotates with `standard` in 200 ms and switches instantly under reduce motion. |
| Send button | `AnimatedContainer` colour change 200 ms (`standard`; 150 ms reduce motion); spinner 18 dp while sending. |
| Haptics | `Haptics.light()` only on the `ProfileRemindButton` pill (Home/next-stream card) and on whisper send — NOT on the schedule `_SegmentRow` bell `IconButton`, NOT on the slot sheet's Remind row; `HapticFeedback.lightImpact()` on the Home tiles' long-press enlarge (`_TilePicture`) but NOT on the live card's long-press enlarge; `Haptics.selection()` on profile tab tap and Activity row menu. |
| Live badge (tablet card) | shared `LiveBadge` with its own ping; phone card badge static. |

## Settings

| Key / owner | Default | Used here |
|---|---|---|
| `SettingsStore.pinnedChannelIds` (List<String>) | `[]` | Channel preferences "Pin" switch; More sheet `isPinned`. |
| `SettingsStore.hiddenChannelIds` | `[]` | Channel preferences "Hide from Browse". |
| `SettingsStore.noticesHiddenChannelIds` | `[]` | Channel preferences "Show notices" (inverse). |
| `SettingsStore.showUserNotices` | `true` | Enables the per-channel notices switch; `showsNoticesIn(id) = showUserNotices && !noticesHidden.contains(id)`. |
| `SettingsStore.launchUrlExternal` | `false` | Profile links (`LinkRouter.open(..., confirm: true)`). |
| `SettingsStore.clipDiscovery` | `ClipDiscovery.all` | `featuredClipsOnly(context)` (featured only when `ClipDiscovery.featured`) for both clip stores. |
| `GoLivePrefs` SharedPreferences `go_live_enabled` | `false` | Bell switch enabled state. |
| `GoLivePrefs` `go_live_muted` (string list) | empty | Bell value per channel (`setMuted`). |
| `ActivityLog` `activity_log` (string list of JSON, max 100) / `activity_viewed_at` | empty / null | Activity entries and bell "new" cut-off. |
| `SettingsStore.mutedWhisperUserIds` / `SettingsStore.archivedWhisperUserIds` (List<String>) | `[]` / `[]` | Seeded into `WhisperStore` at startup and written back through its `onPreferencesChanged` callback (lib/main.dart) whenever mute/archive changes: thread actions, the muted bell icon on rows, the archived section. Muted threads are excluded from `WhisperStore.unreadCount` (badges). "Hide" is NOT persisted: `hide(userId)` records an in-memory hidden-at time (history older than it is not re-shown), removes the thread, closes it and unarchives it. |
| `ScheduleReminders` persisted reminders | none | Remind me state per segment id. |
| Reduce motion (OS accessibility / `MediaQuery.disableAnimations`) | OS | Disables pulses, slides, folds, arrivals. |
| Text scale | OS | Tab heights, header guess, pills grow with it. |

No new settings keys are defined in this area.

## Strings

Keys read directly by this area (generated by `desktop/tools/spec-strings.mjs --emit`; EN and FR exactly as in `lib/l10n/app_en.arb` / `app_fr.arb`, ICU syntax kept):

| Key | EN | FR |
|---|---|---|
| `activityEarlier` | Earlier | Plus anciennes |
| `activityEmpty` | Hooray! You’re up to date | Parfait ! Vous êtes à jour |
| `activityEmptyDetail` | Check back soon for alerts about you and the broadcasters you follow. | Revenez bientôt pour voir les alertes qui vous concernent et celles des chaînes que vous suivez. |
| `activityMarkAllRead` | Mark all as read | Tout marquer comme lu |
| `activityMostRecent` | Most recent | Récentes |
| `activityNoWhispers` | No whispers yet. Whispers you get while the app is open show up here. | Aucun chuchotement pour l’instant. Ceux que vous recevez quand l’application est ouverte s’affichent ici. |
| `activityNote` | Notifications ONSET has shown on this device. | Les notifications envoyées par ONSET sur cet appareil. |
| `activityOptions` | Options | Options |
| `activityRemove` | Remove notification | Supprimer la notification |
| `activityTitle` | Activity | Activité |
| `activityUnread` | Unread | Non lue |
| `channelFollow` | Follow | Suivre |
| `channelFollowTooltip` | Follow {name} | Suivre {name} |
| `channelFollowing` | Following | Suivie |
| `channelPrefsBell` | Live notifications | Notifications de live |
| `channelPrefsBellDetail` | Get a notification when {name} goes live. | Recevez une notification quand la chaîne {name} lance un live. |
| `channelPrefsBellLoggedOut` | Log in to get live notifications. | Connectez-vous pour recevoir les notifications de live. |
| `channelPrefsBellOff` | Turn on live notifications in Settings to use the bell. | Activez les notifications de live dans les Paramètres pour utiliser la cloche. |
| `channelPrefsChat` | Chat | Chat |
| `channelPrefsHide` | Hide from Browse | Masquer dans Parcourir |
| `channelPrefsHideDetail` | Leaves this channel out of Browse, category, and tag lists. Following still shows it. | Retire cette chaîne de Parcourir et des listes de catégories et de tags. Suivis l’affiche toujours. |
| `channelPrefsIntro` | These choices apply to {name} only. | Ces choix ne s’appliquent qu’à la chaîne {name}. |
| `channelPrefsLists` | Lists | Listes |
| `channelPrefsNotices` | Show notices | Afficher les événements |
| `channelPrefsNoticesDetail` | Subs, gifts, raids, and announcements in this chat. | Abonnements, cadeaux, raids et annonces dans ce chat. |
| `channelPrefsNoticesOff` | Notices are turned off for every chat in Settings › Chat. | Les événements sont masqués dans tous les chats (Paramètres › Chat). |
| `channelPrefsNotifications` | Notifications | Notifications |
| `channelPrefsPin` | Pin to the top | Épingler en haut |
| `channelPrefsPinDetail` | Shows this channel first in Following when it’s live. | Affiche cette chaîne en premier dans Suivis quand elle est en direct. |
| `channelPrefsTitle` | Channel preferences | Préférences de la chaîne |
| `channelRestrictedBanner` | {name}’s account is temporarily restricted for breaking Twitch’s community guidelines. | Le compte de {name} est temporairement restreint pour non-respect des règles de la communauté de Twitch. |
| `clipClippedBy` | Clipped by {curator} | Créé par {curator} |
| `clipUntitled` | Untitled clip | Clip sans titre |
| `commonBack` | Back | Retour |
| `commonCancel` | Cancel | Annuler |
| `commonLiveBadge` | LIVE | LIVE |
| `commonSeeAll` | See all | Tout voir |
| `commonUndo` | Undo | Annuler |
| `goLiveBellFailed` | Couldn’t change the bell. | Impossible de modifier la cloche. |
| `notificationCenterEmpty` | No notifications from Twitch | Aucune notification de Twitch |
| `notificationCenterEntryDetail` | From your Twitch account | Depuis votre compte Twitch |
| `notificationCenterFailed` | Couldn’t load your Twitch notifications. | Impossible de charger vos notifications Twitch. |
| `notificationCenterMarkedRead` | {count, plural, one{{count} notification marked as read.} other{{count} notifications marked as read.}} | {count, plural, one{{count} notification marquée comme lue.} other{{count} notifications marquées comme lues.}} |
| `notificationCenterTitle` | Twitch notifications | Notifications Twitch |
| `notificationCenterUnseen` | {count, plural, one{{count} new} other{{count} new}} | {count, plural, one{{count} nouvelle} other{{count} nouvelles}} |
| `profileAboutTitle` | About {name} | À propos de la chaîne {name} |
| `profileAffiliate` | Affiliate | Affilié |
| `profileCancelled` | Canceled | Annulé |
| `profileChat` | Chat | Chat |
| `profileCollectionVideos` | {count, plural, one{{count} video} other{{count} videos}} | {count, plural, one{{count} vidéo} other{{count} vidéos}} |
| `profileComingUp` | Coming up | À venir |
| `profileDjBadge` | Official Twitch DJ | DJ officiel de Twitch |
| `profileFollowers` | {count, plural, one{{count} follower} other{{count} followers}} | {count, plural, one{{count} follower} other{{count} followers}} |
| `profileFollowersShort` | {count, plural, one{{followers} follower} other{{followers} followers}} | {count, plural, one{{followers} follower} other{{followers} followers}} |
| `profileHighlights` | Highlights | Temps forts |
| `profileJoined` | Joined {date} | Membre depuis {date} |
| `profileLastLive` | Last live {when} | Dernier live {when} |
| `profileLive` | Live | En direct |
| `profileLoadFailed` | Couldn’t load this channel’s profile. | Impossible de charger le profil de cette chaîne |
| `profileMore` | More | Plus d’options |
| `profileNextStreamAt` | Next stream · {time} | Prochain live · {time} |
| `profileNextStreamIn` | Next stream {when} · {time} | Prochain live {when} · {time} |
| `profileNoBio` | No bio yet. | Aucune bio pour l’instant. |
| `profileNoDetails` | No details | Aucun détail |
| `profileNoHighlights` | No highlights | Aucun temps fort |
| `profileNoPastBroadcasts` | No past broadcasts | Aucune ancienne diffusion |
| `profileNoSchedule` | No streams scheduled | Aucun live prévu |
| `profileNoUploads` | No uploads | Aucune mise en ligne |
| `profileNotFound` | Channel not found. | Chaîne introuvable |
| `profileOpenFailed` | Couldn’t open this channel. Check your connection. | Impossible d’ouvrir cette chaîne. Vérifiez votre connexion Internet. |
| `profilePanelImage` | Panel image | Image du panneau |
| `profilePartner` | Partner | Partenaire |
| `profilePastBroadcasts` | Past broadcasts | Anciennes diffusions |
| `profilePopularClips` | Popular clips | Clips populaires |
| `profileRecentBroadcasts` | Recent broadcasts | Diffusions récentes |
| `profileRecording` | Recording | En cours |
| `profileRefreshFailed` | Couldn’t refresh this channel. | Impossible d’actualiser cette chaîne |
| `profileRemindMe` | Remind me | Me le rappeler |
| `profileReminderFailed` | Couldn’t set the reminder. | Impossible de programmer le rappel. |
| `profileReminderRefused` | Allow notifications for this app in the system settings. | Autorisez les notifications de cette application dans les paramètres du système. |
| `profileReminderSet` | Reminder set | Rappel activé |
| `profileRerun` | Rerun | Rediffusion |
| `profileRerunBadge` | RERUN | REDIFF |
| `profileScheduleFailed` | Couldn’t load the schedule. | Impossible de charger le planning |
| `profileShare` | Share | Partager |
| `profileStreamUntitled` | Untitled stream | Live sans titre |
| `profileSubscribersOnly` | Subscribers only | Réservé aux abonnés |
| `profileTabAbout` | About | À propos |
| `profileTabClips` | Clips | Clips |
| `profileTabCollections` | Collections | Collections |
| `profileTabHome` | Home | Accueil |
| `profileTabSchedule` | Schedule | Planning |
| `profileTabVideos` | Videos | Vidéos |
| `profileTeams` | Teams | Équipes |
| `profileThumbnail` | Thumbnail | Miniature |
| `profileTrailer` | Trailer | Bande-annonce |
| `profileTrailerOpen` | Play trailer: {title} | Lire la bande-annonce : {title} |
| `profileUploads` | Uploads | Mises en ligne |
| `profileWatchLive` | Watch live | Regarder le live |
| `profileWatched` | Watched | Regardée |
| `recapClipCount` | {count, plural, one{{count} clip} other{{count} clips}} | {count, plural, one{{count} clip} other{{count} clips}} |
| `recapLabel` | Recap | Récap |
| `recapOpen` | Watch the recap {title}, {details} | Regarder le récap {title}, {details} |
| `recapUntitled` | Untitled recap | Récap sans titre |
| `recapsTitle` | Stream recaps | Récaps de live |
| `scheduleRepeatsWeekly` | Repeats every week | Se répète chaque semaine |
| `scheduleShareSlot` | Share this stream | Partager ce live |
| `scheduleVacation` | On a break from {start} to {end}. The schedule resumes after that. | En pause du {start} au {end}. Le planning reprendra ensuite. |
| `scheduleWeekly` | Weekly | Chaque semaine |
| `startsInDays` | {count, plural, one{in {count} day} other{in {count} days}} | {count, plural, one{dans {count} jour} other{dans {count} jours}} |
| `startsInHours` | {count, plural, one{in {count} hour} other{in {count} hours}} | {count, plural, one{dans {count} heure} other{dans {count} heures}} |
| `startsInMinutes` | {count, plural, one{in {count} minute} other{in {count} minutes}} | {count, plural, one{dans {count} minute} other{dans {count} minutes}} |
| `startsNow` | starting now | imminent |
| `streamEnlargeHint` | enlarge | agrandir |
| `streamListLiveNow` | Live now | En direct |
| `streamOffline` | Offline | Hors ligne |
| `streamViewers` | {count, plural, one{{count} viewer} other{{count} viewers}} | {count, plural, one{{count} spectateur} other{{count} spectateurs}} |
| `streamWatch` | Watch | Regarder |
| `streamWatchingShort` | {count, plural, one{{viewers} watching} other{{viewers} watching}} | {count, plural, one{{viewers} spectateur} other{{viewers} spectateurs}} |
| `teamFailed` | Couldn’t load this team. | Impossible de charger cette équipe. |
| `teamLiveNow` | Live now | En direct |
| `teamMembers` | Members | Membres |
| `teamMembersCount` | {count, plural, one{{count} member} other{{count} members}} | {count, plural, one{{count} membre} other{{count} membres}} |
| `videoUntitled` | Untitled | Sans titre |
| `videoViewsShort` | {count, plural, one{{views} view} other{{views} views}} | {count, plural, one{{views} vue} other{{views} vues}} |
| `viewerActionResult` | {status, select, done{Done.} refused{Twitch declined this.} integrityRefused{Twitch’s anti-bot check refused this. Connect a Twitch session in Settings › Account, then try again.} signedOut{Log in again to do this from ONSET.} other{Couldn’t reach Twitch. Try again.}} | {status, select, done{C’est fait.} refused{Twitch a refusé.} integrityRefused{Le contrôle anti-robot de Twitch a refusé cette action. Connectez une session Twitch dans Paramètres › Compte, puis réessayez.} signedOut{Reconnectez-vous pour le faire depuis ONSET.} other{Impossible de joindre Twitch. Réessayez.}} |
| `whisperArchive` | Archive | Archiver |
| `whisperHide` | Hide conversation | Masquer la conversation |
| `whisperHideConfirm` | Hide | Masquer |
| `whisperHideConfirmMessage` | Your whispers with {name} will be removed from this app. A new whisper will start a new conversation. | Vos chuchotements avec {name} seront retirés de cette application. Un nouveau chuchotement ouvrira une nouvelle conversation. |
| `whisperHideConfirmTitle` | Hide this conversation? | Masquer cette conversation ? |
| `whisperHint` | Whisper {name} | Chuchoter à {name} |
| `whisperMore` | Conversation options | Options de la conversation |
| `whisperMute` | Mute notifications | Couper les notifications |
| `whisperMuted` | Notifications muted | Notifications coupées |
| `whisperOpen` | Open | Ouvrir |
| `whisperSend` | Send | Envoyer |
| `whisperSessionNote` | Twitch keeps no history the app can show, so only this session’s whispers appear here. | Twitch ne conserve aucun historique que l’application puisse afficher : seuls les chuchotements de cette session apparaissent ici. |
| `whisperStatusInterrupted` | Reconnecting… whispers will arrive again soon. | Reconnexion… les chuchotements reviendront bientôt. |
| `whisperStatusOff` | Log in to get whispers. | Connectez-vous pour recevoir des chuchotements. |
| `whisperStatusRefused` | Twitch refused to send your whispers to this app. Log out and log in again to allow them. | Twitch refuse d’envoyer vos chuchotements à cette application. Déconnectez-vous puis reconnectez-vous pour les autoriser. |
| `whisperStatusUnavailable` | Twitch isn’t sending whispers to this app right now. ONSET will try again when you come back to the app. | Twitch n’envoie pas de chuchotements à cette application pour le moment. Une nouvelle tentative aura lieu à votre retour dans l’application. |
| `whisperStopReplies` | Stop {name}’s replies | Empêcher {name} de répondre |
| `whisperStopRepliesBody` | While you block whispers from strangers, {name} can’t reply to you again until you whisper them. | Tant que vous bloquez les chuchotements d’inconnus, {name} ne pourra plus vous répondre, sauf si vous lui chuchotez à nouveau. |
| `whisperStopRepliesConfirm` | Stop replies | Empêcher les réponses |
| `whisperStopRepliesTitle` | Stop {name}’s replies? | Empêcher {name} de répondre ? |
| `whisperUnarchive` | Unarchive | Désarchiver |
| `whisperUnmute` | Unmute notifications | Réactiver les notifications |
| `whisperYou` | You | Vous |
| `whispersAllRead` | All read | Tout est lu |
| `whispersArchived` | {count, plural, one{Archived conversation ({count})} other{Archived conversations ({count})}} | {count, plural, one{Conversation archivée ({count})} other{Conversations archivées ({count})}} |
| `whispersChoose` | Choose a conversation | Choisissez une conversation |
| `whispersEmpty` | No whispers yet | Aucun chuchotement pour l’instant |
| `whispersEmptyDetail` | Whispers you get while the app is open show up here. | Les chuchotements reçus pendant que l’application est ouverte s’affichent ici. |
| `whispersNew` | New whisper | Nouveau chuchotement |
| `whispersNewFailed` | Couldn’t search. Check your connection and try again. | Impossible de lancer la recherche. Vérifiez votre connexion, puis réessayez. |
| `whispersNewNoMatch` | No one matches “{query}”. | Personne ne correspond à « {query} ». |
| `whispersNewSearch` | Search for someone | Rechercher une personne |
| `whispersTitle` | Whispers | Chuchotements |
| `whispersUnreadCount` | {count, plural, one{{count} unread} other{{count} unread}} | {count, plural, one{{count} non lu} other{{count} non lus}} |

Strings reached indirectly through models and shared widgets (ActivityEntry `titleIn`/`bodyIn` and `streamNoticeBody`, which returns the title alone, the category alone, `notifReminderUntitled` for an untitled reminder, or `notifStreamBody` when both exist; `ActivityKind.label`; `WhisperFailure.text`; `FollowButton`/`SubscribeButton`/`_EntryFollow`; `shareLink`):

| Key | EN | FR |
|---|---|---|
| `notifGoLiveTitle` | {name} is live | {name} est en direct |
| `notifReminderTitle` | {name}’s stream is starting | Le live de la chaîne {name} commence |
| `notifMentionTitle` | {sender} mentioned you in {channel} | {sender} vous mentionne dans le chat de la chaîne {channel} |
| `notifReminderUntitled` | Untitled stream | Live sans titre |
| `notifStreamBody` | {title} · {category} | {category} · {title} |
| `activityKindLive` | Live | En direct |
| `activityKindMention` | Chat mentions | Mentions dans le chat |
| `activityKindReminder` | Events | Événements |
| `chatLogInToWhisper` | Log in to whisper. | Connectez-vous pour chuchoter. |
| `whisperOtherAccount` | This conversation belongs to another account. | Cette conversation appartient à un autre compte. |
| `whisperTooLong` | Whispers can be {max} characters at most. | Les chuchotements sont limités à {max} caractères. |
| `whisperLogInAgain` | Log in again to whisper from this app. | Reconnectez-vous pour chuchoter depuis cette application. |
| `chatWhisperFailedBecause` | Couldn’t whisper: {reason} | Impossible de chuchoter. {reason} |
| `whisperFailedUnexpected` | Couldn’t whisper (unexpected error). | Impossible de chuchoter (erreur inattendue). |
| `channelFollow` | Follow | Suivre |
| `channelFollowing` | Following | Suivie |
| `channelSubscribe` | Subscribe | S’abonner |
| `channelSubscribeTooltip` | Subscribe to {name} · opens twitch.tv | S’abonner à {name} · ouvre twitch.tv |
| `vodLinkCopied` | Link copied | Lien copié |

`WhisperRefused` fills `chatWhisperFailedBecause` with `chatErrorText(l, error)` (chat leaf). The whisper back button uses `MaterialLocalizations.backButtonTooltip` (Flutter, not ARB). French typography follows `docs/L10N.md`; `scheduleDayTitle` adds the French `1er` ordinal and the capital itself because intl does not.

## Network and data

All GQL goes to `kTwitchGqlUrl` (`https://gql.twitch.tv/gql`) as a POST with `{operationName, query, variables}` (full documents, no persisted-query hashes) and header `Client-ID: kTwitchWebClientId` (the public twitch.tv web client id); user-scoped GQL adds `Authorization: OAuth <twitchWebToken>` (the twitch.tv first-party session token held by `AuthStore`). Helix calls go through `TwitchApi` (`https://api.twitch.tv/helix`, app/user token + `Client-Id`).

**Anonymous GQL (`TwitchChannelProfileService`, no user token)** — every login is trimmed, lower-cased and must match `^[a-zA-Z0-9_]{1,25}$` (else `ArgumentError`); errors in the body are joined with `; `; a missing `data` map throws `ChannelProfileApiException`; nested resolver errors leave the rest usable.
- `ChannelProfile($login)`: `user(login) { id login displayName description createdAt profileImageURL(width: 300) bannerImageURL offlineImageURL primaryColorHex roles { isPartner isAffiliate } followers { totalCount } channel { id socialMedias { name title url } } panels { id type ... on DefaultPanel { title imageURL linkURL description altText } } lastBroadcast { id title startedAt game { id displayName } } stream { id type viewersCount createdAt game { displayName } } }`. `user == null` without errors -> no such channel (null); with errors -> throws; unreadable user -> throws "Unreadable profile".
- `ChannelSchedule($login)`: `user { id channel { id schedule { id segments { id startAt endAt title isCancelled categories { id name } } nextSegment { id startAt } } } }` (this week and next; up to 100 segments, sorted by start); a null schedule with errors throws, otherwise empty.
- `ChannelTrailer($login)`: `user { id channel { id trailer { video { id title lengthSeconds previewThumbnailURL(width: 640, height: 360) } } } }`; video id must be numeric 1–20 digits; title max 300; only https thumbnails.
- `ChannelDjRole($login)`: `user { id roles { isParticipatingDJ } }` -> bool, false on any error.
- `ChannelProfileRestriction($channelID: ID!)`: `user(id) { id channelSafetyStatus }` -> restricted if any of RESTRICTED / SUSPENDED / TEMPORARILY_RESTRICTED.

**Helix (`TwitchApi`)**: `GET /users?login=` (fallback header, `ProfilePicture`, follow lookup); `GET /teams/channel?broadcaster_id=` (profile teams); `GET /teams?name=` (team page, first result); `GET /streams?user_id=…&first=100` (team live members, up to 100 ids); `GET /schedule?broadcaster_id=&first=25` (schedule extras: `vacation.start_time/end_time`, segment `is_recurring` keyed by UTC start, up to 100 segments); `GET /clips?broadcaster_id=&started_at=&ended_at=&first=100` (Clips tab date ranges via `getClipsBetween`; times in UTC ISO-8601); `GET /search/channels?first=8&query=` (new whisper); `POST /whispers?from_user_id=&to_user_id=` body `{message}` (1–10000 chars, needs `user:manage:whispers`); follow state via `getUser` + `isFollowing` (`GET /channels/followed?user_id=&broadcaster_id=`); follow/unfollow through `FollowFlow` (outside).

**Other services**: `twitchVodService.getChannelCollections(userId)` (collections), channel videos per type (`ChannelVideosStore`: archive/highlight/upload, paged), `twitchClipService` (top clips for the week, featured-only option, `getChannelRecaps(id)`), `preloadChannel(context, login)` (usher playback token prefetch — player leaf).

**User-scoped GQL (`TwitchSocialService`, OAuth web token)**:
- `OnsiteNotificationsForUserQuery($user, $limit: 30, $cursor, $language, $capabilities)` -> `user.notifications(first, after, language, capabilities).edges { cursor node { ...OnsiteNotificationFragment } }` (fragment: actions { body type url } body category createdAt creators { profileImageURL(width: 70) id displayName } destinationType displayType extra {…User { login id }…} id isRead thumbnailURL type updatedAt). `language` = first subtag of the app locale (2–3 letters). User id numeric; cursors and ids `^[A-Za-z0-9_:.\-]{1,256}$`. Next cursor only when the page was full (30).
- `OnsiteNotificationsSummaryQuery($user)` -> `summary { lastSeenAt unseenCount … }` (entry badge).
- `ReadOnsiteNotificationMutation($input: ReadNotificationsInput!)` with `{ids}` -> success when `readNotifications.count` is an int; flagged as a user action for the twitch.tv session interceptor; 401 -> `signedOut`.
- `UserWhisperThreadsQuery($limit: 30, $cursor)`, `WhisperMessageQuery($thread, $numMessages: 50)` (history for the list and conversations, via `WhisperStore.refreshHistory`/`loadConversation`).
- `RemoveWhisperThreadWhitelistMutation($threadID)` (stop replies).
- Errors in any query -> null (treated as failure); mutations map to `ViewerActionOutcome { done, refused, integrityRefused, signedOut, failed }`.

**Realtime**: incoming whispers arrive over the EventSub WebSocket topic `user.whisper.message` v1 with condition `{user_id: me}` (`WhisperStore`, outside), feeding the thread list, unread counts, the status (`connecting`, `listening`, `interrupted`, `refused`, `unavailable`, `off`) and `whisperNotice`. GQL history (`UserWhisperThreadsQuery`) is refreshed at most once per 30 s (`historyRefreshGap`), the timer being reset on an account change.

**Images**: `static-cdn.jtvnw.net/previews-ttv/live_user_<login>-<w>x<h>.jpg` (live preview, h = min(w*9/16, 1080), cache key per 5 minutes); banner, avatar, offline image, panel images (memCacheWidth 640), team logos, notification avatars (https, `*.jtvnw.net` / `*.twitch.tv` only). Markdown images in panels are never fetched.

**Local data**: `ActivityLog` (SharedPreferences `activity_log`, `activity_viewed_at`), `GoLivePrefs` (`go_live_enabled`, `go_live_muted`), `ScheduleReminders` (scheduled local notifications per segment), `SettingsStore` lists.

## Tested behaviour

Every test file of the area and what it pins:

- `test/screens/channel_profile/channel_profile_screen_test.dart` (phone 390x844, tablet 1280x854 and 854x1280, dark and light): header/stream/actions/tabs order and texts ("12.6m followers · Partner", LIVE, Watch, Subscribe when signed out, no Follow, Back/Share/More tooltips, tab labels in order, avatar 88 hanging beside the name); About bio without a second schedule request ("No streams scheduled"); Home next stream with Remind Me scheduling a notice; scrolled header folds (Back stays on screen, tabs pinned between 56 and 80 dp, avatar under the bar, Back pops); the folded bar absorbs taps; every tab has a pull-to-refresh under the pinned header; landscape phone 800x360 keeps Back/More/avatar clear of the cutout; text x1.3 at 360x740 keeps Watch/Follow/Subscribe on one line; fits 360x740, 800x360, 320x640@1.6; Collections: deep link lands on it once loaded, no tab when none/failed, tab after Clips keeps the shown tab and lists "12 videos · 2 days ago" / "2:00:00"; tablet rail + tabs, avatar 120, big card right of the rail, size change keeps the tab; signed in "Following" read from Twitch + Subscribe; neither on own channel (nothing asked); finger-down on live card or Watch preloads; `fromChannel` Watch pops back without preload; Share copies `https://www.twitch.tv/xqc` with "Link copied" where no share sheet; Videos tab empty texts per type; broken GQL still shows Helix header with "Couldn’t load this channel’s profile." + Try again + Chat + More; unknown channel "Channel not found." with Try again and Back; motion: ring pulses and holds still under reduce motion, stops under the bar, hidden avatar does not pulse; caller id allows More before load; no id -> Chat explains; Helix-only retry updates the header; failed refresh over a profile is said; hidden videos list not kept alive; deep link to Schedule; French sweep of every tab and of Follow/Subscribe states at `frenchScreenSizes` (360x640, 390x844, 1280x854, 854x1280, 844x390) x text 1.0/1.3, not-found and failed schedule in French.
- `test/screens/channel_profile/stores/channel_profile_store_test.dart`: one request for concurrent loads; unknown channel only once Helix agrees; GQL miss + Helix hit keeps the page; Helix asked once across failed retries; failed profile falls back to Helix header; schedule on demand and refreshed once shown; failed schedule keeps the page; late answer after dispose ignored; trailer and teams load with the profile; failed trailer/teams keep the page; DJ query failure keeps the flag off; DJ flag from its own query.
- `test/screens/channel_profile/team_screen_test.dart`: live members first by viewers then the rest; unloadable team offers retry; members still listed when live lookup fails.
- `test/screens/channel_profile/schedule_extras_test.dart`: Helix extras parse vacation and weekly streams; slot link `https://www.twitch.tv/<login>/schedule?segmentID=…`; vacation banner, weekly tag and slot sheet; French wording.
- `test/screens/channel_profile/profile_entry_points_test.dart`: an offline followed channel opens its profile; the info-bar avatar opens the profile only when asked; channel actions offer the profile.
- `test/screens/channel_profile/channel_preferences_screen_test.dart`: the bell mutes/unmutes only this channel ("Get a notification when xQc goes live."); without live notifications the bell explains; notices, pin and hide change only this channel.
- `test/screens/channel_profile/widgets/profile_header_test.dart`: banner decoded for its box (390x168 at dpr 2 -> 840 px; 1280x230 at 2560 physical -> 2560), offline followers/role then Chat, live ring + card with viewers and uptime + Watch, rerun label, large text fits 320 dp.
- `test/screens/channel_profile/widgets/channel_restricted_banner_test.dart`: restricted shows the banner; good standing shows nothing; failure hides it; another channel id re-asks and starts hidden.
- `test/screens/channel_profile/widgets/profile_header_subscribe_test.dart`: partner/affiliate offer Subscribe; not without subs, unknown role, own channel or unusable login; header shows it when offered.
- `test/screens/channel_profile/widgets/profile_tabs_test.dart`: About (bio, facts "1,234 followers", Affiliate, Discord icon, only web links open — `javascript:` ignored — Markdown images never fetched, hostile deeply nested panel renders in < 5 s, "No bio yet.", `socialIcon` fallbacks); Schedule (by day headings "Wednesday, October 14", "Next stream in 4 hours · …", cancelled marked, Remind me on the next stream and each segment, narrow phone fit, refused permission points to system settings, explanation dialog "Allow notifications?" before the first reminder, no bell without reminders, "No streams scheduled", `formatStartsIn` EN "starting now"/"in 1 minute"/"in 1 day" and FR "imminent"/"dans 1 minute"/"dans 3 heures"/"dans 1 jour" with no-break spaces); Home (offline last broadcast "Last live 2 days ago · Chess", 4 videos + 4 clips, See all callbacks; tablet stream beside COMING UP with two cards, 6 video tiles in three columns; watch progress on tiles).
- `test/screens/activity/activity_store_test.dart`: add/count/mark read; bell counts since last view; refresh shows background additions; failing log leaves the list.
- `test/screens/activity/activity_follow_test.dart`: reminder from an unfollowed channel offers Follow and follows; one lookup per channel; no Follow on go-live, followed channel, or signed out; without a web session Follow still shows.
- `test/screens/activity/activity_screen_test.dart`: empty "Hooray! You’re up to date"; phone tabs keep scroll (offset 900 kept); Most recent / Earlier with "1 hour ago • Live", "3 days ago • Chat mentions", device note; only older -> shown as Most recent; mark all read; opening clears the bell not the unread; tap opens and marks read; long press removes; whispers tabs with counts; logged out notifications only; kept while another section shows, cleared when shown again; in background arrivals stay new; removal immediate (fold only visual); reduce motion removes at once; unread dot only when unread; phone whisper opens its conversation alone; tablet notifications beside whispers, popup menu removal, logged-out notifications alone, empty state; layout at all sizes/themes; French sweep including English-posted notices re-rendered in French ("Streamer est en direct", "Échecs · Partie classée").
- `test/screens/notifications/notification_center_test.dart`: store refresh/paging without duplicates/mark all read; refused mark keeps unread, failure says so; screen lists and opens on tap; mark all shows "1 notification marked as read.", the mark-all icon (`markAllKey`) disappears once everything is read, tapping Undo restores the unread row and the icon and sends NOTHING (`marked == 0`), and a second mark-all closed by `hideCurrentSnackBar` (a non-action close) sends exactly once (`marked == 1`) and the icon goes; failure offers retry ("Couldn’t load your Twitch notifications."); entry hidden without web session; (also covers the Settings `TwitchNotificationSettingsGroup`: push/email per category, unreadable settings keep only the twitch.tv link — owned by the settings leaf).
- `test/screens/whispers/whispers_screen_test.dart`: empty list and status hints ("Log out and log in again", "Reconnecting" with spinner that disappears); last whisper + unread pill; viewer's whisper marked with the reply arrow; names sanitised ("Fr‮iend\nStaff" -> "Fr iend Staff"); phone slide and back; edge swipe follows the finger (80/390) and closes; closed on phone not reopened on tablet; unread pill grows with text (height 40 at x2); opening reads, sending adds a bubble, session note; refused whisper keeps text and says why; sending ring and no double send; leaving counts new as unread; arrivals in open conversation read; bubble state kept when whispers arrive below (all sizes); conversationOnly back leaves; logged out sign-in; account change closes; tablet auto-opens first, empty pane, opened on a target, resize keeps the draft; layout sizes/themes; reduce motion fades; status hints; French sweep.
- `test/screens/whispers/whisper_stop_replies_test.dart`: confirmation then Twitch's answer shown.
- `test/screens/whispers/whisper_notice_test.dart`: who + whisper + Open; 480 dp on tablet; Open inert after an account switch.
- `test/screens/whispers/whisper_actions_test.dart`: new whisper sheet searches and never offers the viewer; no-match and failure texts; long press mute/archive/hide after confirming; conversation menu hide goes back.

- Outside this area's folders (cross-area tests that also pin this area): `test/l10n/fr_lot5_test.dart` (French: `NewWhisperSheet`, `TeamScreen`, `ProfileTrailerCard`, `ProfileTeams`, `ProfileScheduleContent` with vacation + weekly extras, `ScheduleSlotSheet`); `test/l10n/fr_lot6b_test.dart` (French: `ProfileCollectionsTab`, `ChannelPreferencesScreen`); `test/l10n/fr_lot8a_test.dart` (French: `ChannelRestrictedBanner`); `test/l10n/fr_lot8c_test.dart` (French: `NotificationCenterScreen`); `test/l10n/fr_lot8d_test.dart` (French: `ProfileRecapsShelf`); `test/l10n/fr_lot9b_test.dart` (French: `ProfileAboutContent`); `test/screens/clips/recap_widgets_test.dart` (`ProfileRecapsShelf`); `test/screens/home/home_test.dart` (whisper notice account guard; Activity tabs with counts on phone / two columns on tablet; whispers in the header and in Activity); `test/services/notifications/mention_alerts_test.dart` (route names `ChannelProfile`, `/whispers`, `/whisper` in the "pages a mention may close" rule).

## Wide and tablet layout

- Large screen = `MediaQuery.size.shortestSide >= 600` (`kLargeScreenShortestSide`), overridable by `LargeScreenScope`.
- Profile: tablet layout requires large AND window width >= `ChannelProfileScreen.tabletMinWidth = 720`; rail 280, 330 at width >= 1100; banner `safeTop + 230`; rail top `safeTop + 150`, left 32; pane left = 32 + rail + 38, right 32, top `safeTop + 196`; avatar 120 (border 4, pulse 16); tabs 44 dp / 16 sp / 26 gap / 2.5 indicator; Home grids 3 columns when the pane >= 640 (else 2), tablet shows `columns * 2` tiles; stream card 480 wide beside "Coming up" when pane >= 778; recaps tiles 300 wide (240 phone), 80 % width if the pane is narrower than tile + 40; About panels 2 columns at >= 660; tile radius 14 (12 phone); section titles 19 sp.
- Team: gutter 28 (16 phone), content max 760, member grid 2 columns when large and >= 600.
- Collections: video tiles grid when large, list rows on phone.
- Activity: tablet when large: outer padding 28, list max 860 without whispers, whispers column 320 / 392 at width >= 1100 with a 24 gap, cards radius 20, rows 48 avatar / 22 badge / padding 18x14, popup menu min width 230 anchored 18 px from the row's right and 46 px down.
- Twitch notifications: max width 760 on large screens; rows 48 avatar.
- Whispers: tablet when large: padding 28 (top safeTop + 12), list 320 / 372 at width >= 1000, gap 20, pane radius 24; conversation column centred max 720 (bubbles), 760 (composer, error); pane header 72; bubble side padding 24; whisper notice 480 wide.
- Window crossing the threshold keeps state: profile tab, whisper conversation + draft (GlobalKey per user id); a conversation closed on phone is not reopened on tablet; one chosen on tablet appears over the list on phone.

## PC equivalent

Target: Rust + Slint on Windows first (macOS/Linux later). Nothing is dropped; each mobile mechanism maps to a desktop one.

- **Navigation**: Material routes become Slint pages in a navigation stack with the same route names (`ChannelProfile`, `/team`, `/channel-preferences`, `NotificationCenter`, `/whispers`, `/whisper`); back = toolbar back button, mouse back button (XButton1), Alt+Left and Esc (closing an open conversation or sheet first, mirroring `PopScope`).
- **Layouts**: use the same thresholds on the window's logical size (a desktop window is "large" when its shortest side >= 600; below, the phone layouts apply, so a narrow window behaves like the phone). Keep every dimension in logical px = dp.
- **Collapsing profile header**: a Slint `Flickable` with a header whose height is `max(minExtent, maxExtent - viewport_y)` and the same `t`, opacity and colour formulas; measured header height via the content's computed height.
- **Pull to refresh**: overscroll pull on touch/precision touchpads plus F5 / Ctrl+R and a refresh button in the toolbar for every list (profile tabs, team, Activity, Twitch notifications).
- **Long press**: right-click (and Shift+F10 / context-menu key) opens the same action menus (Activity remove, whisper thread actions, tile "enlarge image"); press-and-hold still works on touch screens.
- **Bottom sheets** (`showOnsetSheet`): anchored popovers or centred modal sheets with identical rows; dialogs (`OnsetDialog`) as modal Slint dialogs.
- **Snackbars**: in-window toasts with the same texts, durations (4 s default) and actions (Undo, Open); the whisper notice additionally raises a Windows toast (WinRT `ToastNotification`) when the window is unfocused.
- **Share**: no share sheet on Windows -> copy to clipboard + "Link copied" toast (exactly the existing fallback path); optional Windows Share UI via `DataTransferManager`.
- **Haptics**: no-op on desktop (keep call sites for touch devices).
- **System overlay style**: no status bar; with a custom title bar, the bar's foreground follows `profileOverlayStyle` (light over the banner, theme colour once folded).
- **Reminders and go-live bell**: local notifications become WinRT scheduled toasts (`ScheduledToastNotification`) or the app's background timer service; permission prompt becomes a check of Windows notification settings with the same explanation text.
- **Hover**: add hover highlights (raised colour) to every tappable row/card and show tooltips on hover (round buttons, social pills, follow button, send button).
- **Keyboard**: Enter sends a whisper (Shift+Enter newline), Ctrl+N new whisper, Tab order following the visual order; tab strips switchable with Ctrl+Tab / Ctrl+Shift+Tab; arrow keys in lists.
- **Accessibility**: map `Semantics` (header, button, liveRegion, selected, toggled, expanded, labels) to Slint accessible properties / AccessKit; reduce motion from Windows "Show animations in Windows" (`SPI_GETCLIENTAREAANIMATION`).
- **Networking**: `reqwest` + `serde_json` for the same GQL documents and Helix endpoints (same headers, validation regexes, caps and error mapping); the EventSub WebSocket client (`tokio-tungstenite`) for `user.whisper.message`; image cache with the same cache keys (5-minute live previews) and decode widths.
- **Persistence**: SharedPreferences keys become entries in the app's settings store (`%APPDATA%\ONSET\…`), same names (`activity_log`, `activity_viewed_at`, `go_live_enabled`, `go_live_muted`, settings lists).
- **State**: MobX stores become Rust structs with change notification into Slint models (`VecModel`), reactions as explicit observers; in-flight request de-duplication and disposal guards preserved.
- **Markdown panels**: `pulldown-cmark` with links restricted to http/https and images replaced by alt text.

### Known Android defects

Exact Android behaviour today, and what the PC port does instead (each is a deliberate, documented fix — nothing else changes silently):

1. **Stale Activity follow cache** (`activity_screen.dart` `_followStates`, lines 256–265, and `_EntryFollow.onChanged`, 832–834). Android: the follow state per login is fetched once per list lifetime and never invalidated; after following from one row, another row (or a re-created row) for the same channel still offers "Follow", and follows/unfollows made elsewhere are not reflected. PC FIX: the cache is updated on a successful follow (all rows for that login switch to "Following") and dropped on refresh, on viewer change and when the app regains focus.
2. **Hidden whisper still open on tablet** (`whispers_screen.dart` 712–714: long-press Hide in `WhispersList` passes no `onHidden`). Android: the thread disappears from the list but the tablet pane keeps showing it. PC FIX: hiding a thread from the list also clears the pane selection (empty pane / "Choose a conversation", no auto-open), exactly like Hide from the conversation's More menu.
3. **Notification inbox stuck loading** (`notification_center_store.dart` `refresh`/`loadMore`). Android: if the injected `fetch` throws, `loading` stays true forever (endless spinner, no more paging). PC FIX: errors are caught; `loading` is always reset; a throwing refresh sets `failed` (error view with Try again), a throwing `loadMore` stops paging like a null page.
4. **Recap tile label repeats the count** (`profile_home_tab.dart` `ProfileRecapTile`). Android: with no `postedAt` the screen-reader label is `recapOpen(title, details: "<count> · <count>")`. PC FIX: the details part is the count alone when there is no posted date ("<count> · <time ago>" otherwise).
5. **Reduce-motion durations ignored in the whispers slide** (`whispers_screen.dart` 122–126, 227, 234). Android: the controller is created at 340 ms whatever reduce motion says, and an edge-swipe release always animates `340 × remaining` ms. PC FIX: every slide (initial, select, back, drag release) uses `motionDuration` — 150 ms cross-fade under reduce motion, 340 ms (× remaining for a release) otherwise.
6. **Team page loading and reload feedback** (`team_screen.dart` 153). Android: no spinner while the full team loads over the partial one (may read "0 members"), and a failed reload with members shown is silent. PC FIX: a small inline progress indicator while loading, the member count hidden until the full team arrives, and a toast "`teamFailed`" text on a failed reload while keeping the list.
7. **Archived chevron ignores reduce motion** (`whispers_screen.dart` 805–807). Android: `AnimatedRotation` with a fixed 200 ms and the default linear curve, played even when the viewer reduces motion. PC FIX: the chevron rotates with `OnsetMotion.standard` in 200 ms, and under reduce motion it switches instantly (no rotation travel), consistent with every other motion in the app.

## Source files
### lib/screens/channel_profile/stores/channel_profile_store.dart

MobX store (`ChannelProfileStore = ChannelProfileStoreBase with _$ChannelProfileStore`, generated part `channel_profile_store.g.dart`, never hand-edited) that holds one channel's profile page data. Constructor: `login` (required String), `profileService` (required `TwitchChannelProfileService`), and optional injected loaders `helixUser: Future<UserTwitch> Function(String login)`, `teamsOf: Future<List<Team>> Function(String userId)`, `scheduleExtrasOf: Future<ScheduleExtras> Function(String userId)`, `collectionsOf: Future<List<VideoCollection>?> Function(String userId)`. The screen wires them to `twitchApi.getUser(userLogin:)`, `twitchApi.getChannelTeams(broadcasterId:)`, `twitchApi.getScheduleExtras(broadcasterId:)` and `twitchVodService.getChannelCollections`.

Observable state (all `@readonly`, i.e. private writable, public getter without underscore):
- `profile: ChannelProfile?` — the anonymous-GQL profile.
- `fallback: UserTwitch?` — the Helix `/users` header, ONLY set when the profile could not be read (profile null or error); cleared (`_fallback = null`) when a non-null profile arrives.
- `isLoading` (false), `loaded` (false; true once at least one load finished, success or failure), `notFound` (false), `error: Object?` (what made the profile fail; null otherwise).
- `trailer: ChannelTrailer?`, `teams: List<Team>` (const []), `collections: List<VideoCollection>` (const []), `isParticipatingDj` (false).
- `schedule: ChannelSchedule?`, `scheduleLoading` (false), `scheduleError: Object?`, `scheduleExtras: ScheduleExtras` (default `ScheduleExtras.none`).
- Computed `userId => profile?.id ?? fallback?.id`; computed `displayName => profile?.displayName ?? fallback?.displayName`.

Request de-duplication: `load()` returns `_profileInFlight ??= _load().whenComplete(() => _profileInFlight = null)`, so a call while loading joins the running Future rather than starting a second request. `loadSchedule()` does the same with `_scheduleInFlight`. `refresh()` = `Future.wait([load(), if (schedule != null || scheduleError != null) loadSchedule()])` — the schedule is reloaded on pull only if it was shown (loaded or failed) before.

`_load()` algorithm (action): set `isLoading = true`; `profile = await profileService.getProfile(login)`; if disposed, stop. In one action: `profile = profile; error = null; if (profile != null) fallback = null`. If profile is null (GQL says no such user) the page does NOT immediately say "not found": it first calls `_loadFallback()` (Helix confirmation) and sets `notFound = (fallback == null)`. If profile is non-null: `notFound = false`, then `await _loadExtras(profile.id)`. On any exception: `debugPrint('ChannelProfileStore($login) profile failed: $e')`, set `error = e`, then `_loadFallback()` (note: notFound is NOT changed on error). `finally`: unless disposed, `isLoading = false; loaded = true`.

`_loadExtras(userId)` runs four loads in parallel with a Dart record `.wait` and none can fail the page: (1) `profileService.getTrailer(login)` -> null on error (logs `trailer failed`); (2) `teamsOf(userId)` or const [] when no loader -> [] on error (logs `teams failed`); (3) `_loadCollections(userId)` -> `await collectionsOf(userId) ?? const []`, [] when no loader or on error (logs `collections failed`); (4) `profileService.isParticipatingDj(login)` -> false on error. Then (if not disposed) one action assigns trailer, teams, collections, isParticipatingDj together.

`_loadFallback()`: returns immediately if no `helixUser` loader, or a profile already exists, or a fallback already exists (so it is fetched at most once). Otherwise `fallback = await helixUser(login)`; errors are logged (`fallback failed`) and swallowed.

`_loadSchedule()` (action): `scheduleLoading = true`; `schedule = await profileService.getSchedule(login)`; on success one action sets schedule and clears `scheduleError`, then `_loadScheduleExtras()`; on error logs `schedule failed` and sets `scheduleError = e` (the previous schedule value is kept); finally `scheduleLoading = false`. `_loadScheduleExtras()` needs both a loader and a known `userId`; it assigns `scheduleExtras` on success and logs `schedule extras failed` on error (the schedule itself stays shown).

`dispose()` sets `_disposed = true`; every async continuation checks it before writing observables, so a closed page never gets late writes. There is no cancellation of the underlying HTTP requests.

PC equivalent: a Rust `ChannelProfileState` struct behind an `Arc<Mutex>`/Slint model with the same fields; in-flight dedup via `Shared<BoxFuture>` (futures `shared()`) or a tokio `OnceCell` per request; `tokio::join!` for the four extras with each mapped to its default on error; a `disposed: AtomicBool` (or a dropped `Weak`) checked before every write. Tested by `test/screens/channel_profile/stores/channel_profile_store_test.dart` and `test/screens/channel_profile/schedule_extras_test.dart`.

### lib/screens/channel_profile/channel_preferences_screen.dart

Per-channel preferences page ("Channel preferences"). `ChannelPreferencesScreen` (StatefulWidget) takes `channelId`, `name`, `settingsStore: SettingsStore`, `loggedIn: bool`, and `goLivePrefs: Future<GoLivePrefs> Function()` (default `GoLivePrefs.load`, injectable for tests). `routeName = '/channel-preferences'`. Static `open(context, channelId:, name:, settingsStore:, loggedIn:)` pushes a `MaterialPageRoute` (RouteSettings name `/channel-preferences`) whose page is a `SettingsScaffold(title: l10n.channelPrefsTitle, body: ChannelPreferencesScreen(...))` — the standard settings scaffold (shared look with the Settings screens).

State: `_goLive: GoLivePrefs?`. In `initState`, ONLY when `loggedIn`, it calls `goLivePrefs()` unawaited; on success `setState(() => _goLive = prefs)` if mounted; on error `debugPrint('Go-live prefs failed: $e')` (the switch then stays disabled).

Helper `_toggled(ids, include)` returns a new list: every id except this `channelId`, then `channelId` appended if `include`. Used to write the global id lists without duplicates (order: the channel moves to the end).

Layout (inside an `Observer`, so it updates live with SettingsStore): `SettingsGroupsView` with, in order:
1. `Padding(horizontal: 4)` + `SettingsNote(l.channelPrefsIntro(name: name))` — intro text.
2. Bell group: `SettingsGroup(title: l.channelPrefsNotifications)` containing one `SettingsListSwitch` key `ValueKey('channel-prefs-bell')`, title `l.channelPrefsBell`. Subtitle: if not logged in -> `l.channelPrefsBellLoggedOut`; else if go-live notifications enabled (`prefs != null && prefs.enabled`) -> `l.channelPrefsBellDetail(name: name)`; else -> `l.channelPrefsBellOff`. Value: `enabled && !prefs.muted.contains(channelId)` (bell on = channel not muted). `onChanged` is null (switch disabled) unless enabled. `_setBell(prefs, on)` awaits `prefs.setMuted(channelId, !on)`; on failure logs `Bell change failed: $e` and shows a SnackBar `l.goLiveBellFailed`; then `setState` either way to re-read the value.
3. Chat group `SettingsGroup(title: l.channelPrefsChat)`: switch key `channel-prefs-notices`, title `l.channelPrefsNotices`, subtitle `settings.showUserNotices ? l.channelPrefsNoticesDetail : l.channelPrefsNoticesOff`, value `settings.showsNoticesIn(channelId)`, enabled only when the global `showUserNotices` setting is on; toggling writes `settings.noticesHiddenChannelIds = _toggled(noticesHiddenChannelIds, !on)` (switch ON = channel NOT in hidden list).
4. Lists group `SettingsGroup(title: l.channelPrefsLists)`: switch `channel-prefs-pin` (title `l.channelPrefsPin`, subtitle `l.channelPrefsPinDetail`, value `pinnedChannelIds.contains(channelId)`, writes `pinnedChannelIds = _toggled(pinned, on)`); switch `channel-prefs-hide` (title `l.channelPrefsHide`, subtitle `l.channelPrefsHideDetail`, value `hiddenChannelIds.contains(channelId)`, writes `hiddenChannelIds = _toggled(hidden, on)`). Both always enabled (no login needed).

Settings touched (all persisted by SettingsStore): `showUserNotices` (read only), `noticesHiddenChannelIds`, `pinnedChannelIds`, `hiddenChannelIds`; plus the go-live per-channel mute list owned by `GoLivePrefs` (`enabled`, `muted`, `setMuted`). PC equivalent: a Slint settings page with the same four switches; GoLivePrefs maps to the desktop go-live notifier's per-channel mute list (Windows toast notifications); disabled state + subtitle wording identical. Tested by `test/screens/channel_profile/channel_preferences_screen_test.dart`. French rendering: `test/l10n/fr_lot6b_test.dart`.

### lib/screens/channel_profile/channel_profile_screen.dart

The channel profile page. Defines `enum ProfileTab { home, videos, clips, collections, schedule, about }` (this order is the tab order) with `label(AppLocalizations l)` -> `profileTabHome`, `profileTabVideos`, `profileTabClips`, `profileTabCollections`, `profileTabSchedule`, `profileTabAbout`.

`ChannelProfileScreen` (StatefulWidget): `routeName = 'ChannelProfile'`; params `login` (required), `userId?` (known by caller so Chat/More work before or without the profile), `displayName?` (shown until the profile loads), `initialTab` (default `ProfileTab.home`), `fromChannel` (default false: opened from this channel's own screen, so Watch/Chat go BACK instead of pushing a new player). Constant `tabletMinWidth = 720.0`. Static `open(...)` pushes a `MaterialPageRoute` named `ChannelProfile`.

**Tab list.** `_tabsFor(collections)` = all `ProfileTab.values` except `collections` when the channel has no collections. Initially collections are unknown so the Collections tab is hidden (5 tabs). `_askedTab` remembers an `initialTab` that is not yet shown (e.g. `collections`) so that when the tab appears it is selected. `_indexOf(tab) = max(indexOf, 0)` (missing tab -> index 0 = Home). `_syncTabs(collections)` runs via a MobX `reaction` on `store.collections`: if the new list differs (`listEquals`), it picks the current tab (the asked one if it is now present, else the currently selected tab), clears `_askedTab` when it is present, creates a NEW `TabController(length, vsync, initialIndex: indexOf(current))` with `_onTab` listener inside `setState`, removes the listener from the previous controller and disposes it in a post-frame callback. `_showTab(tab)` = `_tabs.animateTo(index)` (default TabController animation, kTabScrollDuration 300 ms, Curves.ease).

**Stores created by the state.** `_store = ChannelProfileStore(...)` (see store section). `_videoStores: Map<VodType, ChannelVideosStore>` created lazily by `_videosOf(type)` (`putIfAbsent`); `_videoType` starts at `VodType.archive` (past broadcasts are created at once because Home shows them). `_clips = ChannelClipsStore(login, clipService, featuredOnly: _featuredClipsOnly, clipsBetween: _clipsBetween)` for the Clips tab; `_clipsBetween(start, end)` errors with `StateError('Channel id unknown')` if no id, else `twitchApi.getClipsBetween(broadcasterId, broadcasterLogin, start, end)`. `_homeClips = ChannelClipsStore(login, clipService, featuredOnly)` = Home's "Popular clips" (this week's top regardless of the Clips tab filter). `_featuredClipsOnly()` reads the global featured-clips setting (`featuredClipsOnly(context)`). `_overlap = SliverOverlapAbsorberHandle()` for the phone nested scroll. `_headerHeight: double?` measured height of the phone header under the banner. `_scrollControllers` — one `ScrollController` each for Home, Schedule and About, used only on tablet (phone tabs share the NestedScrollView's). `_follow: ChannelInfoStore?` = follow state for the viewer.

**initState.** `unawaited(_store.load())`; `unawaited(_store.loadSchedule())` immediately (Home shows the next stream). Reactions: (1) `reaction(store.collections, _syncTabs)`; (2) `reaction(store.schedule, ...)` — when non-null, `ScheduleReminders.shared?.sync(login, schedule.segments)` so local reminders follow the schedule as read (a moved segment's reminder moves, a cancelled one's is removed); (3) `autorun`: `id = store.userId ?? widget.userId`; if non-null `_syncFollow(id, _viewerOf(auth))`. Adds `_onTab` listener, then `_started = true`.

**_syncFollow(id, viewer).** If viewer is the channel owner (case-insensitive login match): `_follow = null`, remember viewer id, dispose previous and rebuild if past init — nothing to follow on one's own channel. If a store already exists for the same channelId: if the viewer changed, call `previous.viewerChanged()`. Otherwise create `ChannelInfoStore(channelId: id, api: twitchApi, viewerId: () => _viewerOf(auth)?.id, startDelay: Duration.zero)..start()` (zero delay because there is no player competing for the network), dispose the previous, setState if started.

**_onTab.** When the selected tab is Schedule and schedule is null and not loading -> `loadSchedule()` (covers a failed first load).

**dispose.** Disposes reactions, tab controller (after removing listener), store, all video stores, both clips stores, follow store, overlap handle, the three scroll controllers.

**Derived values.** `_name = store.displayName ?? widget.displayName ?? widget.login`. `_userId = store.userId ?? widget.userId`. `_viewerOf(auth)` = `auth.user.details` only when `auth != null && auth.isLoggedIn`. `_ownChannel` = case-insensitive equality of viewer login and channel login. `_followFor` = null when logged out or own channel, else `_follow` (so Follow appears/disappears instantly on sign-in/out). `_showSubscribe(profile)` = `profileOffersSubscribe(profile:, login:, viewerLogin:)` (profile_parts). `_preload` = null when `fromChannel`, else `() => preloadChannel(context, login)` — called on finger-down on Watch/live card so the playback token request starts early.

**Actions.** `_say(message)` shows a SnackBar with `AlertMessage(message, centered: false)`. `_refresh()`: unawaited `_follow?.refreshFollowing()`, `await store.refresh()`, and if `store.error != null && store.profile != null` shows `profileRefreshFailed` (a failure over a displayed profile is said, never silent). `_refreshHome()` = `Future.wait([_refresh(), _videosOf(archive).refresh(), _homeClips.refresh()])`. `_openChannel()`: if fromChannel -> `Navigator.pop`; else if id unknown -> snackbar `profileOpenFailed`; else push `VideoChat(userId, userName: _name, userLogin: login)` with route name `VideoChat.routeName`. `_share()` -> `shareLink(context, 'https://www.twitch.tv/<login>')`. `_more()` (needs id) opens `showModalBottomSheetWithProperFocus` with `UserActionsModal(authStore, name, userLogin, userId, showPinOption: true, isPinned: settings.pinnedChannelIds.contains(id), showProfile: false)`. `_openLink(url)` -> `LinkRouter.open(url, launchExternal: settings.launchUrlExternal, confirm: true)`. `_back()` -> `Navigator.maybePop`. `_actions({onBar = 0, disc = 0.45})` -> `[ProfileRoundButton(glyph: share, tooltip: profileShare), if (userId != null) ProfileRoundButton(glyph: more, tooltip: profileMore)]`.

**Tab views (`_tabViews(nested, large, leading, edgeOffset = 0)`)**, in tab order:
- Home: `_scrollTab(home, onRefresh: _refreshHome, ProfileHomeContent(login, channelName, profile, videos: archive store, clips: _homeClips, schedule, reminders: ScheduleReminders.shared, trailer, onOpenTrailer: VodScreen.open(vodId: trailer.videoId), onOpenChannel, onPreload, onViewAllVideos: set _videoType = archive then show Videos tab, onViewAllClips: show Clips tab, recaps: ProfileRecapsShelf(key: 'recaps-<id>', load: clipService.getChannelRecaps(id), large) when id known else null, showStream: large, large, status: error view (profileLoadFailed + retry load) when error && profile == null && not (isLoading && profile == null))`.
- Videos: `KeyedSubtree(PageStorageKey('videos'), ProfileVideosTab(type: _videoType, onType: setState, storeFor: _videosOf, nested, leadingSlivers, refreshEdgeOffset))`.
- Clips: `KeyedSubtree(PageStorageKey('clips'), ChannelClipsTab(store: _clips, nested, leadingSlivers, refreshEdgeOffset))`.
- Collections (only when shown): `KeyedSubtree(PageStorageKey('collections'), ProfileCollectionsTab(collections, onOpen: VodScreen.open(vodId: collection.firstVideoId, collectionId: collection.id), onRefresh: _refresh, leadingSlivers, refreshEdgeOffset))`.
- Schedule: `_scrollTab(schedule, _scheduleContent(large))` — schedule present -> `ProfileScheduleContent(schedule, extras, now: DateTime.now(), reminders, login, channelName, large)`; error and not loading -> error view `profileScheduleFailed` + retry `loadSchedule()`; else `_ScheduleSkeleton`.
- About: `_scrollTab(about, ...)` — profile null: if `loaded && !retrying` -> error view with `profileLoadFailed` (when error) or `profileNoDetails` (else), retry `load()`; otherwise `_AboutSkeleton`. Profile present -> `ProfileAboutContent(profile, onOpenLink, teams, isParticipatingDj, onOpenTeam: TeamScreen.open(context, team))`.

`_scrollTab(tab, child, nested, leading, edgeOffset, onRefresh)`: `RefreshIndicator.adaptive(onRefresh: onRefresh ?? _refresh, edgeOffset)` around a `CustomScrollView(key: PageStorageKey(tab.name), controller: nested ? null : _scrollControllers[tab], physics: AlwaysScrollableScrollPhysics)` with slivers `[...leading, SliverPadding(padding, SliverToBoxAdapter(child))]`. Padding: nested (phone) `LTRB(16 + safeLeft, 14, 16 + safeRight, safeBottom + 24)`; tablet `LTRB(0, 20, 0, safeBottom + 24)`. `_status(msg, retry)` = `FeedStatusView.error(message, onRetry)`.

**Phone layout (`_phone`).** `bannerHeight = clamp(screenHeight * 0.2, 96, 168)`. `tabsHeight = ProfileTabBar.heightFor(large: false) - 15 + textScaler.scale(15)` (grows with text scale). Header height guess until measured: `58 + 58 + (97 if profile has stream facts) + (textScaler.scale(24) - 24)`. `NestedScrollView` with header `SliverOverlapAbsorber(handle: _overlap, sliver: SliverPersistentHeader(pinned: true, delegate: ProfilePhoneHeader(topPadding: safeTop, bannerHeight, contentHeight: _headerHeight ?? guess, tabsHeight, title: name, banner: ProfileBanner(profile), content: ProfileMeasured(onHeight: _onHeaderHeight, child: ProfileHeader(login, displayName, profile, loading: profile == null && !loaded, onOpenChannel, onPreload, follow: _followFor, showSubscribe)), tabs: ProfileTabBar(controller, labels, padding: start 16 + safeLeft), actions: (onBar) => _actions(onBar), onBack: _back)))`. Body `TabBarView(controller, children: _tabViews(nested: true, large: false, leading: [SliverOverlapInjector(_overlap)], edgeOffset: safeTop + ProfilePhoneHeader.barHeight + tabsHeight))`. `_onHeaderHeight` only setStates when the measured height actually changes.

**Tablet layout (`_tablet(width)`)** — a `Stack`: banner `Positioned(left 0, right 0, top 0, height: safeTop + 230, ProfileBanner(large: true))`; rail column `PositionedDirectional(start: 32 + safeLeft, top: safeTop + 150, bottom 0, width: railWidth)` where `railWidth = width >= 1100 ? 330 : 280`, inside a `SingleChildScrollView(padding bottom safeBottom + 24)` holding `ProfileRail(login, displayName, profile, loading, onOpenChannel, onPreload, onOpenLink, follow, showSubscribe)`; content pane `PositionedDirectional(start: start + railWidth + 38, end: 32 + safeRight, top: safeTop + 196, bottom 0)` with left/right padding removed, `Column(stretch)[ProfileTabBar(large: true), Expanded(TabBarView(_tabViews(nested: false, large: true, leading: [])))]`; Back button `ProfileRoundButton(chevronLeft, tooltip commonBack, disc 0.5)` at `start 20 + safeLeft, top safeTop + 16`; Share/More `Row(spacing 8, _actions(disc: 0.5))` at `end 20 + safeRight, top safeTop + 16`.

**Not found (`_notFound`).** Stack: full-size error view `profileNotFound` with retry `load()`, plus Back `ProfileRoundButton(chevronLeft, commonBack, onBar: 1)` at `start 8 + safeLeft, top safeTop + 6`. Wrapped in `AnnotatedRegion(profileOverlayStyle(collapsed: true))`.

**build.** `Scaffold(body: Observer(...))`: notFound -> not-found view; else `tablet = context.isLargeScreen && width >= 720`; phone -> `_phone` (the phone header sets its own system overlay style as it collapses); tablet -> `AnnotatedRegion(profileOverlayStyle(collapsed: false), _tablet)`.

Private skeletons: `_ScheduleSkeleton` = Column(stretch, spacing 12) of two `SkeletonLoader(height 80, radius 16)`; `_AboutSkeleton` = Column(start, spacing 10) of `SkeletonLoader` sizes 180x18, 220x12, full x12, full x12, 160x12.

PC equivalent: Slint window page with the same two layouts chosen by window width (phone layout below 720 logical px, or when the window is not "large" — on desktop treat the window as large so width alone decides); NestedScrollView + pinned collapsing header -> a Slint `Flickable` whose header height is computed from scroll offset (same collapse math as ProfilePhoneHeader); pull-to-refresh -> F5 / a refresh button plus overscroll pull; snackbars -> in-window toast; share -> copy link to clipboard + toast; long-press-free. Tested by `test/screens/channel_profile/channel_profile_screen_test.dart`, `test/screens/channel_profile/profile_entry_points_test.dart`, `test/screens/channel_profile/widgets/profile_tabs_test.dart`. Its route name is also pinned by `test/services/notifications/mention_alerts_test.dart` ('pages a mention may close: … profiles …', around line 157: a mention notification tap may close `ChannelProfileScreen.routeName`).

### lib/screens/channel_profile/team_screen.dart

A Twitch Team page (opened from About -> Teams). Typedefs `TeamLoader = Future<Team?> Function(String name)` and `TeamLiveLoader = Future<List<StreamTwitch>> Function(List<String> userIds)`. `TeamScreen` params: `name` (team slug), `loadTeam`, `loadLive`, optional `initial: Team?` (the partial team already known from the profile, shown at once). `routeName = '/team'`. Static `open(context, team)` reads `TwitchApi` from Provider and pushes a `MaterialPageRoute` (name `/team`) with `loadTeam: api.getTeam(name:)` (Helix `GET /teams?name=`) and `loadLive: (await api.getStreamsByIds(userIds: ids)).data` (Helix `GET /streams?user_id=...`).

State: `_team` (starts as `initial`), `_live: Map<String, StreamTwitch>` keyed by user id (const {}), `_loading = true`, `_failed = false`. `initState` calls `_load()` unawaited.

`_load()`: setState loading=true, failed=false. `team = await loadTeam(name)`; if unmounted stop; null team -> loading=false, failed=true. Else live lookup in its own try: ids of the FIRST 100 members (`team.members.take(100)` — the Helix streams cap), skipped when empty; result map `stream.userId -> stream`; a failure logs `Team <name> live members failed: $e` and leaves the live map empty (members still show, all as offline). Then setState team, live, loading=false. An exception from loadTeam logs `Team <name> failed: $e` and sets loading=false, failed=true (a previously shown team stays).

`_openMember(member)`: if the member is live -> push `streamRoute(stream)` (the player); else `ChannelProfileScreen.open(login: member.login, userId: member.id, displayName: member.displayName)`.

build: colors from `FeedColors.of(context)`; `large = context.isLargeScreen`; gutter `28` (tablet, `OnsetSpacing.gutterTablet`) or `16` (phone, `gutterPhone`). `live` = members present in `_live`, sorted by viewerCount DESCENDING; `offline` = the rest in team order. Body: if `team == null || (_failed && members.isEmpty)` -> centered `CircularProgressIndicator.adaptive()` while loading, else `FeedStatusView.error(message: l.teamFailed, onRetry: _load)`. Because `TeamScreen.open` always passes the profile's partial `initial` team, `team` is non-null from the first frame: the content shows at once with NO spinner while the full team loads (the header reads "0 members" if the partial team carries no members), and a failed reload over that team is silent (`_failed` is ignored as long as members exist; with an empty partial team the error view does replace it). Otherwise `RefreshIndicator.adaptive(onRefresh: _load)` around a `ListView(padding LTRB(gutter, 12, gutter, safeBottom + 24))` whose single child is `Center(ConstrainedBox(maxWidth 760, Column(stretch, spacing 16)))` containing:
- header `Row(spacing 14)`: `TeamLogo(team, size 64)` and a Column(spacing 4) with team displayName (22 px, w800, letterSpacing -0.5, colors.text) and `l.teamMembersCount(count: members.length)` (13 px, colors.secondary, tabular figures via `OnsetType.tabular`);
- `team.info` if non-empty (14 px, height 1.5, colors.body);
- if any live: `ProfileSectionTitle(l.teamLiveNow)` + `_MemberGrid(live)`;
- if any offline: `ProfileSectionTitle(l.teamMembers)` + `_MemberGrid(offline)`.
Scaffold `AppBar(title: team?.displayName ?? l.profileTeams)`.

`_MemberGrid`: LayoutBuilder; `columns = large && maxWidth >= 600 ? 2 : 1`; item width `(maxWidth - (columns-1)*10)/columns`; `Wrap(spacing 10, runSpacing 10)` of `_MemberRow`s.

`_MemberRow`: `PressScale` (sinks to 0.97 in 100 ms with Cubic(0.2,0,0,1), springs back with springMomentum 400 ms bounce 0.2; disabled under reduce motion) > transparent Material > `InkWell(key: ValueKey('team-member-<login>'), radius 16, onTap)` > `ProfileCard(padding h12 v10)` > `Row(spacing 12)`: `InitialAvatar(name: displayName, size 36)` (initial-letter disc — no avatar image request), Column(spacing 2) with display name (14 px w600, 1 line ellipsis) and, when live, `gameName` or `title` if the game is empty (12 px secondary, 1 line ellipsis); trailing viewer count `l.streamViewers(count)` in 12 px w600 tabular with `onsetColors.live` colour when live.

PC equivalent: same page as a Slint route; 2-column grid when the window is large and the content width >= 600; hover highlight replaces press-scale (keep press-scale on mouse down); refresh via F5/button. Tested by `test/screens/channel_profile/team_screen_test.dart`. French rendering: `test/l10n/fr_lot5_test.dart`.

### lib/screens/channel_profile/widgets/profile_videos_tab.dart

The profile's Videos tab. Top-level const `kProfileVideoTypes = [VodType.archive, VodType.highlight, VodType.upload]` (pill order; archive = past broadcasts is the default). Function `profileVideoTypeTexts(type, l)` returns a record `(label, empty)`: archive -> (`profilePastBroadcasts`, `profileNoPastBroadcasts`), highlight -> (`profileHighlights`, `profileNoHighlights`), upload -> (`profileUploads`, `profileNoUploads`).

`ProfileVideosTab` (StatelessWidget) params: `type`, `onType: ValueChanged<VodType>`, `storeFor: ChannelVideosStore Function(VodType)` (a store per type, created the first time it shows), `nested` (false), `leadingSlivers` (const []), `refreshEdgeOffset` (0). It renders the shared `ChannelVideosTab` (from `lib/screens/vod/widgets/`, which owns the list, progress bars, pull to refresh, loading/empty/error states, infinite paging) with `key: PageStorageKey('videos-<type.name>')` — each type keeps its own list AND scroll position — `store: storeFor(type)`, `emptyMessage` = the type's empty text, `nested`, `refreshEdgeOffset`, and `leadingSlivers: [...leadingSlivers, SliverToBoxAdapter(horizontal SingleChildScrollView(padding LTRB(16 + safeLeft, 12, 16 + safeRight, 4), Row(spacing 8, [SheetChoicePill(label, large: true, selected: value == type, onSelected: value == type ? null : () => onType(value))])))]` — the three type pills scroll horizontally above the list; the selected pill is non-tappable.

PC equivalent: a segmented pill row above a virtualised Slint `ListView`; each type a separate model with its own saved scroll offset. Tested only in `test/screens/channel_profile/channel_profile_screen_test.dart` ('the Videos tab offers highlights and uploads', around line 714: empty texts per type and switching pills).

### lib/screens/channel_profile/widgets/profile_collections_tab.dart

The profile's Collections tab (only present when the channel has at least one collection). `profileCollectionDetails(collection, l)` = `[l.profileCollectionVideos(count: itemCount), if (updatedAt != null) formatTimeAgo(updatedAt, l)].join(' · ')` (middle dot with spaces).

`ProfileCollectionsTab` params `collections`, `onOpen`, `onRefresh`, `leadingSlivers`, `refreshEdgeOffset`. `tiles = context.isLargeScreen` (grid of tiles on large screens, list rows on phones). `RefreshIndicator.adaptive(edgeOffset, onRefresh)` around `CustomScrollView(key: PageStorageKey('collections-list'), AlwaysScrollableScrollPhysics)` with slivers `[...leading, SliverPadding(top 12), AdaptiveSliverList.videos(tiles, itemCount, itemBuilder), SliverPadding(bottom safeBottom + 16)]`. Each item is a `VideoCardLayout(thumbnailUrl: collection.thumbnailUrl, fallback: (glyph: VideoGlyphKind.camera, label: null), lengthLabel: formatVodTime(Duration(seconds: lengthSeconds)), tile, title: trimmed title or l.videoUntitled when empty, details: profileCollectionDetails, onTap: onOpen(collection))`. Opening a collection plays its first video with the collection id (VodScreen.open(vodId: firstVideoId, collectionId)). No empty state: the tab does not exist without collections.

PC equivalent: same list/grid (grid when window large). Tested in `test/screens/channel_profile/channel_profile_screen_test.dart`, group 'collections' (around line 500: deep link lands on it, no tab when none/failed, tab after Clips listing "12 videos · 2 days ago" and "2:00:00"); French rendering in `test/l10n/fr_lot6b_test.dart`.

### lib/screens/channel_profile/widgets/profile_recaps_shelf.dart

Home's horizontal "Recaps" shelf. `ProfileRecapsShelf(load: Future<List<Recap>> Function(), large = false)`, `listKey = ValueKey('profile-recaps')`. State `_recaps = const []`; `initState` loads once (`load()`; error -> `debugPrint('ProfileRecapsShelf failed: $e')`, shelf stays hidden). The screen keys it `ValueKey('recaps-<userId>')` so a new channel id rebuilds/reloads it; the loader is `twitchClipService.getChannelRecaps(id)`.

build: empty -> `SizedBox.shrink()` (no title, no space). Else `Padding(bottom 18)` > `Column(stretch, spacing 6)`: `ProfileSectionTitle(l.recapsTitle, large)` then a LayoutBuilder: base `tileWidth = large ? 300 : 240`; actual width = `maxWidth * 0.8` when `maxWidth < tileWidth + 40`, else `tileWidth`; horizontal `SingleChildScrollView(key: listKey, clipBehavior: Clip.none)` of `Row(start, spacing: large ? 16 : 12)` of `SizedBox(width, ProfileRecapTile(recap, large))` (tile defined in profile_home_tab.dart).

PC equivalent: horizontal shelf with mouse-wheel horizontal scroll and arrow buttons on hover. Tested in `test/screens/clips/recap_widgets_test.dart` (group 'ProfileRecapsShelf', line 18) and in French by `test/l10n/fr_lot8d_test.dart` (both outside this area's test folders) — not by the profile tests.

### lib/screens/channel_profile/widgets/channel_restricted_banner.dart

A warning banner shown in the phone profile header (`ProfileHeader`) when Twitch marks the channel restricted. `ChannelRestrictedBanner(channelId, name, check?)`; `check` defaults to `context.read<TwitchChannelProfileService?>()?.isRestricted` (if no service, nothing). State `_restricted = false`; read in `initState`, and again in `didUpdateWidget` when `channelId` changes (reset to false first). `_read()`: awaits `check(channelId)`; exceptions are swallowed silently (no banner); sets `_restricted = true` only if still mounted, the channelId is unchanged (no stale answer), and the answer is true. It never goes back to false within the same channel id.

Service query (anonymous GQL, web Client-ID): `query ChannelProfileRestriction($channelID: ID!) { user(id: $channelID) { id channelSafetyStatus } }`; channel id must match `^[0-9]{1,20}$` else false; restricted when any status, trimmed and upper-cased, is in {`RESTRICTED`, `SUSPENDED`, `TEMPORARILY_RESTRICTED`}; any error -> false.

Visual: not restricted -> `SizedBox.shrink()`. Restricted -> `Semantics(container: true, liveRegion: true)` (screen readers announce it) > `DecoratedBox(color: danger #FF5A5F at alpha 0.12, radius 14, border danger alpha 0.45 width 0.5 hairline)` > `Padding(LTRB 14,12,14,12)` > `Row(start, spacing 10)`: `Icon(Icons.gpp_maybe_rounded, size 18, danger)` with top padding 1, and `Expanded(Text(l.channelRestrictedBanner(name), 13 px, height 1.4, colors.text))`. The same string is also injected as a local chat notice by the channel screen (`lib/screens/channel/channel.dart` `_noticeRestriction`), outside this area.

PC equivalent: same banner (shield-warning icon) in the phone-layout profile header only (Android never shows it in the tablet `ProfileRail`; keep that unless deliberately extended); announce via accessibility live region (AccessKit). Tested by `test/screens/channel_profile/widgets/channel_restricted_banner_test.dart` (and French wording by `test/l10n/fr_lot8a_test.dart`, outside this area).

### lib/screens/channel_profile/widgets/schedule_slot_sheet.dart

The bottom sheet for one schedule slot. `scheduleSlotUri(login, segment)` = `https://www.twitch.tv/<login lowercased>/schedule?segmentID=<segment.id>` (built with `Uri.https`, so the id is query-encoded). `showScheduleSlotSheet(context, segment:, login:, recurring:, reminder: ({bool set, VoidCallback toggle})?)` -> `showOnsetSheet<void>` with a `ScheduleSlotSheet`.

`ScheduleSlotSheet` build (colors `SheetColors.of`): times converted `toLocal()`; `day = DateFormat.yMMMMEEEEd()` (e.g. "Thursday, November 19, 2026" / locale form); `time = DateFormat.jm()`; `hours` = start time alone when there is no end, else `"<start> – <end>"` (en dash with spaces). `ListView(shrinkWrap, padding LTRB(0,4,0,12))`:
- title `Padding(LTRB 20,8,20,4)`: trimmed segment title, or `l.profileStreamUntitled` when null/empty, in `SheetText.title` colour text;
- `Padding(LTRB 20,4,20,12)` Column(start, spacing 4): day and hours (`SheetText.body`, colors.body); category name if any (secondary); `l.scheduleRepeatsWeekly` if `recurring` (secondary); `l.profileCancelled` if `segment.isCancelled` (secondary);
- if `reminder != null` (reminders available and slot remindable): `SheetRow(key 'slot-remind', glyph: set ? check : bell, label: set ? l.profileReminderSet : l.profileRemindMe, onTap: toggle() then Navigator.pop)` (no haptic on this row);
- `SheetRow(key 'slot-share', glyph share, label l.scheduleShareSlot, onTap: shareLink(context, scheduleSlotUri))` (sheet stays open after share).

PC equivalent: a popover/modal card anchored to the clicked slot with "Remind me"/"Reminder set" and "Copy link"/share actions; dates formatted with ICU (icu4x) in the app locale. Tested in `test/screens/channel_profile/schedule_extras_test.dart` (slot link, and the slot detail sheet with the weekly tag) and, in French, `test/l10n/fr_lot5_test.dart` (sheet built with `recurring: true`, reminder unset).

### lib/screens/channel_profile/widgets/profile_parts.dart

The shared visual pieces of the channel profile.

**ProfileRoundButton** (`glyph: SheetGlyphKind`, `tooltip`, `onPressed`, `disc = 0.45`, `onBar = 0`): a 44x44 round button over the banner (Back, Share, More). `t = onBar.clamp(0,1)`; glyph colour = `Color.lerp(textPrimaryDark #F5F5F5, FeedColors.text, t)`; disc = `Material(color: black at alpha disc*(1-t), CircleBorder, antiAlias)` — so over the banner it is a dark translucent disc (45 % on phone, 50 % on tablet) with a light glyph, and as the phone bar collapses (`t -> 1`) the disc fades out and the glyph takes the theme text colour. Structure: `Tooltip(message)` > `Semantics(button, label: tooltip, onTap, excludeSemantics)` > `PressScale` > Material > `InkWell(onTap)` > `SizedBox.square(44)` > centered `SheetGlyph(glyph, color, strokeWidth: 2 for chevronLeft, 1.8 otherwise)`.

**ProfileAvatar** (`login`, `size`, `imageUrl?`, `live = false`, `border = 3`, `pulse = 14`): the channel picture. Inner size `size - 2*border`. Picture: `OnsetCachedNetworkImage(imageUrl, inner x inner, BoxFit.cover, memCacheWidth: round(inner * devicePixelRatio))` clipped oval when an URL exists, else `ProfilePicture(userLogin: login, radius: inner/2)` (Helix lookup by login). Container `size x size`, circle, colour = scaffold background; when live: `Border.all(color: onsetColors.live, width: border)` (the border counts as padding); offline: `padding: all(border)` of the ground colour (same footprint, no ring). Live pulse: `AnimationController(duration 1600 ms)` repeating; `_PulsePainter` draws, behind the avatar, a stroked circle of radius `r + spread/2`, `strokeWidth = spread`, where `eased = Cubic(0.2,0,0,1).transform(t)`, `spread = pulse * eased` (0 -> 14 dp), colour = live colour at alpha `0.55 * (1 - eased)` (CSS box-shadow ring 55 % -> 0); nothing painted at t <= 0 or t >= 1. Two `RepaintBoundary`s so only the pulse layer repaints. `_sync()` stops the controller and resets to 0 when not live, reduce motion is on, the app is not resumed (WidgetsBindingObserver lifecycle; null state counts as in front), or `ProfileAvatarShown.of(context)` is false; otherwise `repeat()` if not already animating. Re-synced in `didChangeDependencies` (reads reduce motion and shown), `didUpdateWidget` when `live` changes, and on lifecycle changes. Also stops automatically off-screen through TickerMode.

**ProfileAvatarShown** (InheritedWidget, `shown`): lets the phone header tell avatars below it that they slid under the bar, stopping the pulse. `of(context)` defaults to true; notifies on change.

**ProfileSectionTitle** (`title`, `onSeeAll?`, `large = false`): Row: `Expanded(Semantics(header: true, Text(title, 1 line ellipsis, Inter, size 18 phone / 19 tablet, w700, letterSpacing -0.015*size phone / -0.02*size tablet, height 1.25, colors.text)))`; if `onSeeAll` given, an `InkWell(radius 8)` with min 44x44 target, start padding 8, end-aligned `Text(l.commonSeeAll, 13 px, colors.secondary)`.

**ProfileEyebrow(text)**: `Semantics(header: true)` upper-cased text, 11 px w600, letterSpacing 1.54 (0.14 em), height 1.3, secondary colour (the "COMING UP" label).

**ProfileDateTile** (`date` local, `highlighted = false`, `large = false`): `ExcludeSemantics` > Container `48x52` (phone) / `52x56` (tablet), `colors.raised`, radius 12 > `FittedBox(scaleDown)` > Column(min): weekday `DateFormat.E()` upper-cased, 10 px w700, letterSpacing 1.0, height 1.3, colour = secondary when not highlighted, the live colour (`context.onsetColors.live`: #C8FF3D dark / #6B9E00 light) when highlighted in DARK theme, text colour when highlighted in light theme; day of month `DateFormat.d()` tabular, 18 px (20 tablet) w800 height 1.2 text colour.

**ProfileRemindButton** (`set`, `onPressed`): `Semantics(button, toggled: set)` > PressScale > `GestureDetector(opaque, onTap: Haptics.light() then onPressed)` > `Padding(vertical 4)` (36 dp drawn, 44 dp target) > Container(minHeight 36, horizontal padding 12, `ShapeDecoration(color: set ? live at alpha 0.12 : none, StadiumBorder(side: set ? none : pillBorder hairline 0.5))`) > Row(min, spacing 6): `SheetGlyph(set ? check : bell, size 14, strokeWidth set 2.2 / 2)` + label `profileReminderSet` / `profileRemindMe` (Inter 12 px w600). Foreground = live colour only when set AND dark theme, else text colour.

**ProfileCard** (`child`, `padding = all(14)`): Container with `colors.surface`, radius 16, hairline border 0.5 in `colors.hairline`.

**profileOverlayStyle(context, collapsed:)** -> `SystemUiOverlayStyle`: transparent status bar; light status icons when dark theme OR not collapsed (over the banner picture), else dark; `statusBarBrightness` the inverse (iOS); nav bar colour = scaffold background; nav icons light in dark theme, dark in light.

**ProfileTabBar** (`controller`, `labels`, `large = false`, `padding = zero`): `heightFor(large) = 44 tablet / 40 phone` before text scaling; actual tab height `heightFor - size + scaler.scale(size)`. Font size 15 (phone) / 16 (tablet); gap between labels 22 / 26 (`labelPadding end: gap`). DecoratedBox with a bottom hairline (0.5, colors.hairline) under the row. `TabBar(isScrollable, tabAlignment.start, padding, dividerHeight 0, indicatorSize label, UnderlineTabIndicator(live colour, width 2 phone / 2.5 tablet, radius 2), labelColor text, unselected tertiary, selected Inter w700, unselected w600, no overlay/no splash, onTap: Haptics.selection())`. The indicator follows swipes (TabController animation).

PC equivalent: Slint components `RoundButton`, `ProfileAvatar` (pulse via a Slint `animation` loop paused when window hidden/minimised or reduce-motion on), `SectionTitle`, `Eyebrow`, `DateTile`, `RemindPill`, `Card`, `TabStrip` (hover colour change, no ripple); system overlay style has no Windows equivalent other than the custom title bar colour (title bar follows the collapsed state when the app draws its own chrome); haptics have no PC equivalent (no-op, keep the hook). Tested indirectly by `test/screens/channel_profile/widgets/profile_header_test.dart`, `test/screens/channel_profile/widgets/profile_tabs_test.dart` and `test/screens/channel_profile/channel_profile_screen_test.dart`.

### lib/screens/channel_profile/widgets/profile_header.dart

The profile's header pieces for both layouts.

**ProfileBanner** (`profile?`, `large = false`): wrapped in `ExcludeSemantics` > `ColoredBox(black)` > `Stack(fit: expand)`. If `profile.bannerUrl` exists: `Opacity(0.7 phone / 0.6 tablet)` over `OnsetCachedNetworkImage(url, BoxFit.cover, fill)` with `memCacheWidth = round(max(boxWidth, boxHeight * 2.5) * devicePixelRatio)` when the box is bounded (a banner is 2.5:1; decoded just wide enough to cover, never larger, the box keeps its size while the header folds), else null. Without a banner: a `LinearGradient(topLeft -> bottomRight, [Color(accentColor ?? 0xFF2A2A2A) at alpha 0.55, #000000])` (the channel's primary colour). On top, a fade into the scaffold ground: phone `LinearGradient(top->bottom, stops [0.3, 1], [ground alpha 0, ground])`; tablet `stops [0, 0.4, 1], [ground alpha 0.2, ground alpha 0, ground]` (darker at the top too, under the buttons).

**profileMeta(profile, l)**: `[if followers != null l.profileFollowersShort(count: followers, followers: formatViewers(followers)), if role == partner l.profilePartner, if role == affiliate l.profileAffiliate].join(' · ')` -> e.g. "48.2K followers · Partner" (formatViewers = compact number formatting).

**profileOffersSubscribe({profile, login, viewerLogin})**: true when the viewer is not the channel owner (case-insensitive; a null viewer i.e. signed out still qualifies — twitch.tv asks to log in), `twitchSubscribeUrl(login) != null` (login matches `^[a-z0-9_]{1,25}$` lower-cased -> `https://www.twitch.tv/subs/<login>`), and role is partner or affiliate.

**ProfileIdentity** (`name`, `profile`, `loading = false`, `large = false`): Column(start, min, spacing 2 phone / 4 tablet): name in `Semantics(header)`, max 2 lines ellipsis, Inter 24 (phone) / 30 (tablet) w800, letterSpacing -0.025*size / -0.03*size, height 1.2, text colour; then meta (1 line, tabular, 13 / 14 px, height 1.3, secondary) if non-empty, else while `loading` a `SkeletonLoader(width 130 / 160, height 12)` with top padding 4.

**ProfileActions** (`login`, `name`, `live`, `onOpenChannel`, `onPreload?`, `follow?: ChannelInfoStore`, `showSubscribe = false`, `large = false`): builds `_WatchButton(label: live ? (large ? l.profileWatchLive : l.streamWatch) : l.profileChat, live, height 48 tablet / 44 phone, fontSize 15 / 14, onPressed: onOpenChannel, onPreload only when live)`. Others: `FollowButton(info: follow, login, name, height 44, fontSize 14)` (from channel_info.dart: follow/unfollow with confirmation, shared with the channel screen) when follow != null; `SubscribeButton(login, name, height 44, fontSize 14)` (opens twitch.tv/subs/<login> in the in-app Twitch web page) when showSubscribe; each `Expanded`. Phone: `Row(spacing 8, [Expanded(watch), ...others])` (pills side by side). Tablet: `Column(stretch, spacing 10, [watch, if others Row(spacing 10, others)])` (Watch live full width, the other two under it).

**_WatchButton**: live -> `FilledButton` (foreground `backgroundDark #0A0A0A`, background = live colour (`context.onsetColors.live`: #C8FF3D dark / #6B9E00 light), minimum height `height`, horizontal padding 16, StadiumBorder, Inter w700) with Row(min, spacing 8): a `PlayerGlyph(play, #0A0A0A, size 16)` ONLY when `height > 44` (tablet), then `Flexible(OneLineLabel(label))`. Offline -> `OutlinedButton` (foreground text, background `colors.raised`, min height, padding 16, side pillBorder hairline 0.5, StadiumBorder, w600) with the label "Chat" (offline is not a live moment, so a raised pill instead of the signal colour). Wrapped in `PressScale` > `Listener(onPointerDown: onPreload)` — finger-down starts the playback token request before the tap completes.

**ProfileHeader** (phone header body under the banner): constants `avatarSize = 88`, `avatarOverhang = 44`. `showCard = profile != null && !ProfileStreamFacts(profile).isEmpty`. `Padding(LTRB(16 + safeLeft, 0, 16 + safeRight, 14))` > Column(stretch, spacing 14): (1) `Stack(clipBehavior: none)` with `ConstrainedBox(minHeight 44)` Row(end-aligned): spacer `88 + 14` then `Expanded(ProfileIdentity(name, profile, loading))`; and `PositionedDirectional(start 0, top -44)` `ProfileAvatar(login, imageUrl: profileImageUrl, size 88, live: profile.live != null)` — the avatar hangs 44 dp over the banner edge; (2) `ChannelRestrictedBanner(channelId: profile.id, name)` when the profile is known; (3) `ProfileLiveCard(profile, onOpen: onOpenChannel, onPreload)` when there are stream facts (live or last broadcast); (4) `ProfileActions(...)`.

**ProfilePhoneHeader** (SliverPersistentHeaderDelegate): `barHeight = 56`. `minExtent = topPadding + 56 + tabsHeight`; `maxExtent = topPadding + bannerHeight + contentHeight + tabsHeight`. In build: `range = bannerHeight - 56`; `t = range <= 0 ? 1 : clamp(shrinkOffset / range, 0, 1)` (fold progress); `titleOpacity = clamp((t - 0.7) / 0.3, 0, 1)` (the name fades in over the last 30 % of the fold). `AnnotatedRegion(profileOverlayStyle(collapsed: t > 0.6))`. Stack children:
1. banner `Positioned(top: -shrinkOffset, height: topPadding + bannerHeight)` in a RepaintBoundary (scrolls up with the finger);
2. content `Positioned(top: topPadding + bannerHeight - shrinkOffset)` wrapped in `ProfileAvatarShown(shown: shrinkOffset < bannerHeight + 44 - 56)` + RepaintBoundary (avatar pulse stops once it is under the bar);
3. bar background `Positioned(top 0, height topPadding + 56)` = `AbsorbPointer(DecoratedBox(color: ground at alpha t))` — the bar takes the taps so content slid under it is unreachable;
4. bar row `Positioned(left 8 + safeLeft, right 8 + safeRight, top topPadding + 6, height 44)` `Row(spacing 4)`: Back `ProfileRoundButton(chevronLeft, l.commonBack, onBar: t)`, `Expanded(IgnorePointer(ExcludeSemantics(excluding: titleOpacity == 0, Opacity(titleOpacity, Padding(h8, Text(title, 1 line ellipsis, 16 px w700, text colour))))))`, then `actions(t)` (Share, More);
5. tabs `Positioned(bottom 0, height tabsHeight)` on `ColoredBox(ground)`.
`shouldRebuild` always true.

**ProfileMeasured / RenderProfileMeasured**: a proxy render box that, after layout, if its height differs from the last reported, reports it via `onHeight` in a post-frame callback (only if still attached) — the pinned header needs the real content height; the extent changes on the next frame.

**ProfileRail** (tablet left column): Column(stretch, spacing 18): start-aligned `ProfileAvatar(size 120, border 4, pulse 16, live)`; `ProfileIdentity(large: true)`; `ProfileActions(large: true)`; trimmed bio (`profile.description`) if non-empty (14 px, height 1.55, body colour); `ProfileSocials` if the profile has social links.

**ProfileSocialPill** (`social: SocialLink`, `onOpenLink`): `Tooltip(message: social.url)` > `Semantics(link, button, label: social.title, onTap, excludeSemantics)` > PressScale > `GestureDetector(opaque)` > `Padding(vertical 6)` (32 dp drawn, 44 dp target) > Container(minHeight 32, horizontal padding 12, `ShapeDecoration(colors.surface, StadiumBorder(side pillBorder 0.5))`) > Row(min, spacing 6): `Icon(socialIcon(social.name), size 15, body colour)` and `Flexible(Text(social.title, 1 line ellipsis, 13 px w500, text colour))`. `socialIcon` comes from profile_about_tab.dart. **ProfileSocials**: `Wrap(spacing 8)` of pills (no runSpacing; the vertical padding separates rows).

PC equivalent: the collapsing header is reproduced in Slint with the same extents and the same `t`, `titleOpacity` and overlay thresholds, driven by the Flickable's viewport-y; tooltips show on hover (social URL); the Watch button preloads on mouse-down; the rail layout is identical. Tested by `test/screens/channel_profile/widgets/profile_header_test.dart`, `test/screens/channel_profile/widgets/profile_header_subscribe_test.dart` and `test/screens/channel_profile/channel_profile_screen_test.dart`.

### lib/screens/channel_profile/widgets/profile_live_card.dart

**ProfileStreamFacts(profile)** — what the profile's stream card shows:
- `live` = `profile.live` (a `LiveStatus?`: viewers, startedAt, isRerun, gameName).
- `title` = trimmed `profile.lastBroadcast.title`, null when empty (Twitch's last broadcast IS the live one while live — same id).
- `category` = `live?.gameName ?? lastBroadcast?.gameName`.
- `image(width, now)` -> `({url, cacheKey})?`: offline -> `profile.offlineImageUrl` (no cache key) or null; live -> `height = min(width * 9 ~/ 16, 1080)`, `url = https://static-cdn.jtvnw.net/previews-ttv/live_user_<login lowercased>-<width>x<height>.jpg`, `cacheKey = '<url>-<day>-<hour>-<minute ~/ 5>'` (new picture every five minutes, like the stream cards).
- `details(l, now, withCategory = false)`: offline -> `[if startedAt l.profileLastLive(when: timeAgoInText(startedAt, l, now: now)), lastBroadcast.gameName?].join(' · ')` ("Last live 2 days ago · Chess"); live -> `[if withCategory category?, if isRerun l.profileRerun, l.streamWatchingShort(count: viewers, viewers: formatViewers(viewers)), if startedAt shortUptime(now - startedAt, l)].join(' · ')` ("963 watching · 4 h 02").
- `isEmpty` = offline AND no offline image AND no title (no card at all then).

**ProfileLiveCard** (`profile`, `onOpen`, `onPreload?`, `large = false`): `PressScale` > `GestureDetector(opaque, onTapDown: onPreload only while live and provided, onTap: onOpen)`; child rebuilt every minute by `_MinuteClock` when live with a start time (uptime text), else a plain Builder. Semantics: `button`, `excludeSemantics`, label = `[streamOffline | profileRerun | profileLive, title?, details(withCategory: true)].join(', ')`, onTap.

`_picture(radius)`: `ClipRRect(radius)` > `ColoredBox(black on tablet, colors.well on phone)` > LayoutBuilder: `width = imagePixelWidth(maxWidth, devicePixelRatio)` (rounded pixel width bucket); no image -> centered `SheetGlyph(videos, size 32 tablet / 22 phone, colour OverImage.secondary tablet / colors.tertiary phone)`; else `GestureDetector(onLongPress: showDialog(OnsetPhotoViewDialog(imageUrl, cacheKey)))` (long press enlarges, pinch-zoom viewer; unlike the Home tiles there is NO haptic and no image Semantics/long-press hint here) > `OnsetCachedNetworkImage(url, cacheKey, memCacheWidth: width, cover, fill, useOldImageOnUrlChange: true (no flash when the 5-min key changes), placeholder: SkeletonLoader(borderRadius: radius))`.

`_badge(live, large)`: offline -> nothing. Live, not rerun: tablet -> shared `LiveBadge()` (with its ping animation); phone -> small badge Container(height 18, horizontal padding 6, live colour, radius 5) with `l.commonLiveBadge` in `OnsetType.badge` 10 px, letterSpacing 0.6, height 1, colour #0A0A0A (no ping). Rerun: `OverlayPill(height 24/18, radius 6/5, padding 8/6, color OverImage.pillStrong)` with `l.profileRerunBadge` (badge style 11/10 px, letterSpacing 0.6, OverImage.text).

`_row` (phone): title = `facts.title ?? (offline ? l.streamOffline : l.streamListLiveNow)`; details without category. Container(padding 10, colors.surface, radius 16, hairline border 0.5) > Row(spacing 12): `SizedBox(112 x 63)` Stack(picture radius 10, badge at start 6 top 6); Expanded Column(start, min, spacing 3): title (1 line, 14 px w600 height 1.3 text), details if non-empty (1 line, tabular 12 px height 1.3 secondary); trailing `SheetGlyph(chevronRight, size 18, strokeWidth 2, secondary)`.

`_large` (tablet): details WITH category; `AspectRatio(16/9)` Stack: picture radius 18; IgnorePointer gradient `top->bottom stops [0.45, 1] colors [#00000000, #E0000000]` with the same radius; badge at start 14 top 14; text block at start 16, end 16, bottom 14 (IgnorePointer, Column spacing 3): title max 2 lines 17 px w700 height 1.25 `OverImage.text`; details 1 line tabular 13 px height 1.3 `OverImage.body`.

**_MinuteClock**: listens to `SharedTimerService.instance` (app-wide 1 s ticker) and rebuilds only when `millisecondsSinceEpoch ~/ 60000` changes.

PC equivalent: same card; long press -> right-click or Ctrl+click "View image" opening an image viewer window; preview refresh every 5 minutes via the same cache key; mouse-down triggers preload. Tested by `test/screens/channel_profile/widgets/profile_header_test.dart`, `test/screens/channel_profile/widgets/profile_tabs_test.dart` and `test/screens/channel_profile/channel_profile_screen_test.dart`.

### lib/screens/channel_profile/widgets/profile_home_tab.dart

The profile's Home tab and its tiles. Constants: `kProfileHomePreviewCount = 4` (phone previews two rows of two); `profileGridColumns(width, large)` = 2 on phone; on tablet 3 when `width >= 640`, else 2.

**ProfileHomeContent** (StatefulWidget) params: `login`, `channelName` (''), `profile?`, `videos: ChannelVideosStore` (past broadcasts), `clips: ChannelClipsStore` (this week's top), `onOpenChannel`, `onPreload?`, `onViewAllVideos`, `onViewAllClips`, `schedule?` (null until read or when unreadable), `trailer?`, `onOpenTrailer?`, `reminders: ScheduleReminders?`, `now?` (test clock), `showStream` (false; tablet shows the stream card here, phone has it in the header), `large`, `status?` (error widget shown above everything), `recaps?` (the recaps shelf widget).

State mixes in `VodWatchProgressMixin` (per-VOD watch progress for the viewer; `watchProgressViewer = videos.vodService.viewerId?.call()`). `initState` loads the videos and clips stores if not yet loaded.

build: `now = widget.now ?? DateTime.now()`; `coming = comingUp(schedule, now).take(large ? 2 : 1)` (next non-cancelled future/ongoing segments, helper from profile_schedule_tab.dart); `time = DateFormat.jm()`. `scheduleCard(segment, index)` = `ProfileScheduleCard(segment, next: index == 0, meta: large ? '[<start time>, categoryName?].join(" · ")' : l.profileNextStreamAt(time: <start time>), reminders, login, channelName, large)`.
- `streamCard` = `ProfileLiveCard(profile, onOpen, onPreload, large)` only when `showStream` and the profile has stream facts.
- `trailerCard` = `ProfileTrailerCard(trailer, onOpen)` only when there is NO stream card, a trailer exists and `onOpenTrailer` is set (phone always qualifies since showStream is false there).
- Tablet `top` (when large and (stream card or coming)): `upNext` = Column(stretch, spacing 12, [ProfileEyebrow(l.profileComingUp), schedule cards]). LayoutBuilder: no stream card -> upNext; no coming -> stream card start-aligned at width 480; if `maxWidth >= 480 + 18 + 280` (= 778) -> Row(start, spacing 18, [SizedBox(480, streamCard), Expanded(upNext)]); else Column(stretch, spacing 20, [streamCard, upNext]).

Column(stretch) order: status (bottom padding 14) -> trailer card (bottom 14; on tablet start-aligned width 480) -> `top` (bottom 24) OR on phone: stream card (bottom 14) and each coming card (bottom 14) -> recaps widget -> a LayoutBuilder computing `columns` and `count = large ? columns * 2 : 4` with two Observers:
1. "Recent broadcasts" (`l.profileRecentBroadcasts`, See all -> onViewAllVideos): `loading = !loaded && isLoading`; hidden entirely (`SizedBox.shrink`) when not loading and empty; tiles are `count` `ProfileTileSkeleton`s while loading, else up to `count` `ProfileVideoTile(vod, progress: watchProgress.of(vod), large)`.
2. "Popular clips" (`l.profilePopularClips`, See all -> onViewAllClips): same logic with `ProfileClipTile`.

**_Section** (`title`, `onSeeAll`, `large`, `columns`, `tiles`): `Padding(bottom 18)` > Column(stretch, spacing 6): `ProfileSectionTitle(title, onSeeAll, large)` then a LayoutBuilder: tile width `(maxWidth - gap*(columns-1))/columns`, gap 16 tablet / 12 phone; `Wrap(spacing gap, runSpacing 18 tablet / 14 phone)`.

**_TilePicture** (`imageUrl?`, `fallback` glyph, `length` text, `large`, `chips`, `progress?`): `AspectRatio(16/9)` > `ClipRRect(radius 14 tablet / 12 phone)` > `ColoredBox(colors.well)` > Stack(expand): no URL -> centered `SheetGlyph(fallback, size 22, tertiary)`; else `Semantics(image, label: l.profileThumbnail, onLongPressHint: l.streamEnlargeHint)` > `GestureDetector(onLongPress: HapticFeedback.lightImpact() + showDialog(OnsetPhotoViewDialog(imageUrl)))` > `OnsetCachedNetworkImage(cover, memCacheWidth: ceil(maxWidth * dpr), placeholder SkeletonLoader(radius))`; chips Row(spacing 4) at start 6 / top 6; length chip at end 8/6, bottom 10/8 (tablet/phone); progress bar when non-null: bottom 3 dp track white at alpha 0.18 (tablet) / 0.16 (phone) with a start-aligned live-colour fill of `progress.clamp(0,1)` width.

**_TileChip** (`text?` or `child?`, `large`, `color?`): `OverlayPill(height 22/20, radius 6/5, padding 7/6, color: color ?? (large ? #BF0A0A0A : #A6000000))` with tabular 11 px w600 `OverImage.text`.

**_TileText** (`title`, `details?`, `large`): Column(start, spacing 2): title max 2 lines, 14/13 px w600 height 1.3; details 1 line tabular 12 px height 1.3 secondary.

**ProfileVideoTile** (`vod`, `progress: VodProgress = (progress: null, watched: false)`, `large`): title = trimmed or `l.videoUntitled`; details = `[formatTimeAgo(createdAt), l.videoViewsShort(count, views: formatViewers(viewCount))].join(' · ')`. `Semantics(button, label: '<title>, <formatVodTime(duration)>, <details>')` > PressScale > GestureDetector(tap -> `VodScreen.open(vodId, vod)`) > Column(stretch, spacing 8/6): `_TilePicture(imageUrl: vodThumbnailUrl(vod), fallback videos, length formatVodTime(duration), progress)` with chips: `l.profileRecording` chip in danger at alpha 0.9 when `vod.isRecording` (live archive still recording); `l.profileWatched` chip when watched; a lock glyph chip (size 12) when `vod.isRestricted`; then `ExcludeSemantics(_TileText(title, details: isRestricted ? '<l.profileSubscribersOnly> · <details>' : details))`.

**ProfileClipTile** (`clip`, `large`): title trimmed or `l.clipUntitled`; views chip `l.videoViewsShort`; details `[formatTimeAgo(createdAt), if curator l.clipClippedBy(curator)].join(' · ')`; Semantics label `'<title>, <views>, <details>'`; tap -> `ClipScreen.open(slug, clip)`; `_TilePicture(imageUrl: clip.thumbnailUrl, fallback: SheetGlyphKind.videos, length: formatVodTime(clip.duration), chips: [views chip])` (no progress bar).

**ProfileRecapTile** (`recap`, `large`): title = `recap.title` or `l.recapUntitled` when empty; `count = l.recapClipCount(count: clips.length)`; details = `formatTimeAgo(postedAt)` when posted, else count. (Android quirk: with no `postedAt` the semantics label reads the count twice, "<count> · <count>"; the PC port fixes it — see Known Android defects 4.) Semantics(button, excludeSemantics, label `l.recapOpen(title, details: '<count> · <details>')`, onTap); tap -> `RecapScreen.open(recap)`; `_TilePicture(imageUrl: recap.thumbnailUrl, fallback: SheetGlyphKind.videos, length: formatVodTime(recap.duration), chips: [_TileChip(l.recapLabel), _TileChip(count)])` (no progress bar); text NOT excluded from semantics (the Semantics node excludes children anyway).

**ProfileTileSkeleton** (`large`): Column(start, spacing 8): `AspectRatio(16/9, SkeletonLoader(radius 14/12))`, `SkeletonLoader(140 x 12)`, `SkeletonLoader(90 x 10)` (global shimmering sheen).

PC equivalent: Home as a scrollable Slint column with the same ordering, grid columns from pane width (2 below 640, 3 at/above on large), right-click "Enlarge" replacing long-press, hover states on tiles. Tested by `test/screens/channel_profile/widgets/profile_tabs_test.dart` and `test/screens/channel_profile/channel_profile_screen_test.dart`.

### lib/screens/channel_profile/widgets/profile_extras.dart

**ProfileTrailerCard** (`trailer: ChannelTrailer`, `onOpen`): Home's channel-trailer card (shown on phone always when a trailer exists; on tablet only when there is no stream card). `Semantics(button, label: l.profileTrailerOpen(title: trailer.title), onTap, excludeSemantics)` > PressScale > `GestureDetector(key: ValueKey('profile-trailer'), onTap)` > `ProfileCard(padding all 10)` > Row(spacing 12): `ClipRRect(radius 10)` 128 x 72 Stack(expand): thumbnail (`OnsetCachedNetworkImage(cover)`, only https URLs from the service, 640x360 preview) or `ColoredBox(colors.raised)`, plus centered `Icon(Icons.play_circle_fill_rounded, size 30, white)`; Expanded Column(start, spacing 4): `ProfileEyebrow(l.profileTrailer)` (upper-cased "TRAILER"), title (or `l.profileTrailer` when empty; max 2 lines, 14 px w600, text), and length `formatVodTime(length)` (tabular 12 px secondary) when the length is known (> 0 s). Tapping opens the trailer VOD in the in-app VOD player.

**ProfileTeams** (`teams`, `onOpen`): Column(stretch, spacing 8): `ProfileSectionTitle(l.profileTeams)` then for each team `PressScale` > transparent Material > `InkWell(key: ValueKey('profile-team-<team.name>'), radius 16, onTap: onOpen(team))` > `ProfileCard` (padding 14) > Row(spacing 12): `TeamLogo(team)` (40), Expanded team displayName (1 line ellipsis, 15 px w600 text), `Icon(Icons.chevron_right_rounded, secondary)`.

**TeamLogo** (`team`, `size = 40`): `ClipRRect(radius size/4)` square of `size`: `InitialAvatar(name: displayName, size)` when no `thumbnailUrl`, else `OnsetCachedNetworkImage(url, cover)`. Used by ProfileTeams (40) and TeamScreen header (64).

PC equivalent: identical cards; play glyph overlay; team rows with hover highlight. Tested by `test/screens/channel_profile/widgets/profile_tabs_test.dart`, `test/screens/channel_profile/team_screen_test.dart` and `test/screens/channel_profile/channel_profile_screen_test.dart`. French rendering of `ProfileTrailerCard` and `ProfileTeams`: `test/l10n/fr_lot5_test.dart`.

### lib/screens/channel_profile/widgets/profile_about_tab.dart

**socialIcon(name)** maps Twitch social keys to Simple Icons brand glyphs: `twitter`/`x` -> X, `discord`, `youtube`, `instagram`, `tiktok`, `reddit`, `facebook`, `kick`, `patreon`, `github`, `threads`, `bluesky`, `steam`, `spotify`, `linktree`; anything else -> `Icons.link_rounded`.

**ProfileAboutContent** (`profile`, `onOpenLink`, `teams = const []`, `onOpenTeam?`, `isParticipatingDj = false`): `facts = [if followers l.profileFollowers(count), if createdAt l.profileJoined(date: createdAt) (the ARB placeholder `date` is a DateTime formatted with intl skeleton `yMMMM` — month and year only: "Joined March 2019" / "Membre depuis mars 2019"), if partner l.profilePartner, if affiliate l.profileAffiliate, if isParticipatingDj l.profileDjBadge]`. Column(stretch, spacing 18):
1. Column(start, spacing 6): `ProfileSectionTitle(l.profileAboutTitle(name: profile.displayName))`; facts joined with ' · ' (tabular 13 px height 1.4 secondary) if any; `Padding(top 4)` bio text = trimmed description, or `l.profileNoBio` when empty (14 px height 1.55; body colour for a bio, secondary for the placeholder).
2. `ProfileTeams(teams, onOpen)` when teams exist and a handler is given.
3. `ProfileSocials` when the profile has socials.
4. Panels when present: LayoutBuilder; `columns = maxWidth >= 660 ? 2 : 1` (two columns of Twitch's 320 px panels when room); width `(maxWidth - (columns-1)*12)/columns`; `Wrap(spacing 12, runSpacing 12)` of `ProfileCard(ProfilePanel)`.

**ProfilePanel** (`panel: ChannelPanel`, `onOpenLink`): image (if any) = `ConstrainedBox(maxWidth 320)` > `ClipRRect(radius 12)` > `OnsetCachedNetworkImage(fitWidth, memCacheWidth 640)`, wrapped in (outermost first) `Semantics(image, label: altText ?? title ?? l.profilePanelImage, link: link != null)`; when the panel has a link the image is an `InkWell(radius 12, onTap: onOpenLink(link))`; inside it the picture is always wrapped in `ExcludeSemantics` (in both the plain branch and the InkWell branch), so the cached image's own semantics never surface and the InkWell adds no separate button node — the panel image is announced once, as an image (and link when it has one) with that label. Column(start, spacing 8): picture, title (15 px w700 height 1.3 text) if any, description as `MarkdownBody(data, softLineBreak: true, onTapLink: only http/https URIs (parsed with Uri.tryParse) are passed to onOpenLink — other schemes ignored, imageBuilder: images inside Markdown are NEVER loaded — replaced by their alt text, or nothing when alt is empty)`, and when there is a link but no image a `TextButton.icon(Icons.open_in_new_rounded size 18, label: Uri.parse(link).host)`.

All links go through the screen's `_openLink` -> `LinkRouter.open(url, launchExternal: settings.launchUrlExternal, confirm: true)` (confirmation dialog before leaving; in-app routing for Twitch links).

PC equivalent: Markdown via `pulldown-cmark` rendered into Slint text runs (links clickable, images replaced by alt text); brand icons via an embedded Simple Icons SVG subset; opening links in the default browser after the same confirmation dialog. Tested by `test/screens/channel_profile/widgets/profile_tabs_test.dart` (About group) and `test/screens/channel_profile/channel_profile_screen_test.dart`. French rendering of `ProfileAboutContent`: `test/l10n/fr_lot9b_test.dart`.

### lib/screens/channel_profile/widgets/profile_schedule_tab.dart

Schedule helpers and the Schedule tab.

**formatStartsIn(at, now, l)**: `left = at - now`; `<= 0` -> `l.startsNow`; `< 60 min` -> `l.startsInMinutes(count: clamp(inMinutes, 1, 59))`; `< 24 h` -> `l.startsInHours(count: inHours)`; else `l.startsInDays(count: inDays)` (truncating division).

**scheduleDayTitle(day)**: `DateFormat.MMMMEEEEd()` of the day ("Sunday, November 1"). When the Intl locale starts with `fr`: if day-of-month is 1, replace the standalone `1` (regex `(?<!\d)1(?!\d)`) with `1er`, then `toBeginningOfSentenceCase` -> « Dimanche 1er novembre » (intl gives « dimanche 1 novembre »).

**toggleScheduleReminder(context, reminders, segment, login:, channelName:, notificationPlatform = const GoLivePlatform())**: when setting (not already set), first `explainUnlessAllowed(context, notificationPlatform.allowed)` — the notification-permission explanation prompt (shared widget) — and returns if the viewer declines. Then `reminders.toggle(segment, login, channelName)` -> `ReminderResult { set, cleared, refused, failed }`. `refused` -> SnackBar `l.profileReminderRefused`; `failed` -> `l.profileReminderFailed`; set/cleared silent. Uses `clearSnackBars()` before showing. Context-mounted checks between awaits. (ScheduleReminders = local notification scheduler, outside this area: `canRemind` = not cancelled and starts after now; login must be valid; asks the OS permission; ids per segment; `sync(login, segments)` moves/drops reminders when the schedule changes.)

**comingUp(schedule, now)**: `schedule.upcoming(now)` (segments whose end — or start + 4 h when there is no end — is after now) filtered to not cancelled AND `startAt.isAfter(now)` (an ongoing segment is not "coming up").

**ProfileScheduleCard** (`segment`, `meta`, `next = false`, `reminders?`, `login = ''`, `channelName = ''`, `large = false`): rebuilt by `ListenableBuilder(reminders)` when reminders exist. `ProfileCard` > Row(spacing 12): `ProfileDateTile(date: startAt local, highlighted: next, large)`; Expanded Column(start, min, spacing 2): meta (1 line, tabular 12 px height 1.3 secondary) and title (trimmed, or `l.profileStreamUntitled`; max 2 lines, 15 tablet / 14 phone w600 height 1.3); `ProfileRemindButton(set: isSet(id), onPressed: toggleScheduleReminder)` when `reminders.canRemind(segment)`.

**ProfileScheduleContent** (`schedule`, `now`, `reminders?`, `login`, `channelName`, `large`, `extras = ScheduleExtras.none`): ListenableBuilder on reminders. `upcoming = schedule.upcoming(now)`. `vacation` banner (`ScheduleVacationBanner`, bottom padding 12) when `extras.onVacationAfter(now)` (vacation start and end set and end after now). Empty upcoming -> Column[vacation?, `Padding(vertical 48, FeedStatusView.empty(message: l.profileNoSchedule))`]. Otherwise:
- `next = schedule.nextStartAt` (GQL `nextSegment.startAt`); `nextSegment` = first upcoming not cancelled starting at exactly that instant.
- If `next` is after now: top block (bottom padding 8): when the segment is found, a `ProfileScheduleCard(next: true, meta: l.profileNextStreamIn(when: formatStartsIn(next, now), time: jm(next local)))`; else a `ProfileCard(Text(l.profileNextStreamIn(when, time: DateFormat.MMMEd().add_jm()(next local)), 14 px text))` (the next segment is beyond the two weeks loaded, so the date is included).
- Segments grouped by LOCAL calendar day (insertion order = start order). For each day: heading `Padding(LTRB 2,18,2,6)` `Semantics(header)` `scheduleDayTitle(day)` (15 px w700 letterSpacing -0.15 text); then a `_SegmentRow` per segment with `recurring: extras.isRecurring(segment)` (Helix `is_recurring` keyed by UTC start), `onOpen: showScheduleSlotSheet(segment, login, recurring, reminder)`, and `reminder` record `(set: isSet(id), toggle: toggleScheduleReminder(...))` when `canRemind`, else null.

**_SegmentRow** (`segment`, `time: DateFormat`, `onOpen`, `recurring`, `reminder?`): `InkWell(key: ValueKey('schedule-segment-<id>'), onTap: onOpen(reminder))` > Container(minHeight 60, vertical padding 8, bottom hairline 0.5) > Row(spacing 12): a 4 x 36 bar radius 2 (`colors.raised` when cancelled, `colors.pillBorder` otherwise); Expanded Column(start, min, spacing 2): title (or `l.profileStreamUntitled`; max 2 lines, 14 px w600 height 1.3, secondary colour if cancelled else text), meta line `[hours ('<start> – <end>' or start alone), categoryName?, if recurring l.scheduleWeekly, if cancelled l.profileCancelled].join(' · ')` (tabular 12 px height 1.3 secondary); both texts get `TextDecoration.lineThrough` when cancelled. Trailing `IconButton(tooltip: set ? l.profileReminderSet : l.profileRemindMe, isSelected: set, onPressed: toggle, icon: SheetGlyph(bell, secondary), selectedIcon: SheetGlyph(check, live colour in dark theme / text colour in light, strokeWidth 2.2))` when remindable. This bell calls `toggle` directly: no haptic (only the `ProfileRemindButton` pill plays `Haptics.light()`).

**ScheduleVacationBanner** (`extras`): `ProfileCard` > Row(spacing 12): `Icon(Icons.beach_access_outlined, secondary)` + `Text(l.scheduleVacation(start: MMMd(vacationStart local), end: MMMd(vacationEnd local)), 14 px height 1.4 text)`.

PC equivalent: same schedule list; reminders become Windows toast notifications scheduled by the desktop app's own timer service (persisted, re-armed at startup), the permission prompt replaced by an explanation only if OS notifications are disabled; French date heading rule kept exactly. Tested by `test/screens/channel_profile/widgets/profile_tabs_test.dart`, `test/screens/channel_profile/schedule_extras_test.dart` and `test/screens/channel_profile/channel_profile_screen_test.dart`. French rendering of `ProfileScheduleContent` with a vacation and weekly extras: `test/l10n/fr_lot5_test.dart`.

### lib/screens/activity/stores/activity_store.dart

MobX store (`ActivityStore = ActivityStoreBase with _$ActivityStore`; generated `activity_store.g.dart`) for the Activity screen's notification list: the notifications ONSET itself posted on this device (go-live, chat mentions, schedule reminders), plus the unread count shown on the Home bell / Activity nav item. Constructor `ActivityStore(log: ActivityLog)`; `ActivityLog` (lib/services/notifications/activity_log.dart, outside this area) persists entries in SharedPreferences under key `activity_log` (a string list of JSON entries, newest first, capped at `maxEntries = 100`) and the last-opened time under `activity_viewed_at`; it is also written by the background go-live task.

Observables: `entries: ObservableList<ActivityEntry>` (`@readonly`, newest first), `viewedAt: DateTime?` (`@readonly`, when the list was last opened). Computed `unreadCount` = entries where `!read`. Computed `newCount` = unread entries posted after `viewedAt` (all unread when viewedAt is null) — the bell's badge, cleared by opening the list (like Twitch's Activity tab), while the unread rows themselves stay bold until opened.

Methods (each through `_run`): `markViewed({at})` -> `log.setViewedAt(at ?? DateTime.now())`; `refresh()` -> `log.reload` (re-read the stored list; the background isolate may have added entries); `addAll(entries)`; `markRead(id)`; `markAllRead()`; `remove(id)`. `_run(change)`: awaits the change, then `_show(log.entries)`; on any error logs `Activity list unavailable: $e` and `Telemetry.recordError(e, stack, reason: 'activity list')`, leaving the shown list unchanged (the list is a bonus, never a crash). `_show` (action) replaces `entries` with `ObservableList.of(entries)` and copies `log.viewedAt`.

ActivityEntry (data model, for reference): `id` (unique per event), `kind: ActivityKind { live, mention, reminder }`, `title`, `body` (as posted), `at`, `login?` (channel opened on tap), `read`, `params: Map<String,String>?` (`name`, `title`, `category` for live/reminder; `sender`, `channel` for mention). `titleIn(l)` re-renders in the current language (`notifGoLiveTitle(name)`, `notifReminderTitle(name)`, `notifMentionTitle(sender, channel)`), falling back to the stored title for older entries; `bodyIn(l)` uses `streamNoticeBody(l, title, category)` (reminder with `none: l.notifReminderUntitled`), mention -> stored body.

PC equivalent: same store over a JSON file in the app data dir (`%APPDATA%/onset/activity_log.json`, 100-entry cap, viewedAt alongside), written by the desktop go-live poller and the mention detector; errors logged to the telemetry sink. Tested by `test/screens/activity/activity_store_test.dart`.

### lib/screens/activity/activity_screen.dart

Twitch-style "Activity" section of the navigation shell: notifications (those ONSET posted on this device) and, when logged in, whispers. On a phone the shell's header holds the two tabs (Notifications / Whispers) with counts from `activityTabBadge`; on a tablet the whispers are a column beside the notifications.

**ActivityScreen** params: `store: ActivityStore`, `onOpenChannel: void Function(String login)`, `whispers: WhisperStore?` (null when logged out -> no Whispers tab), `tab: ActivityTab` (default `notifications`; `ActivityTab { notifications, whispers }` from home_store), `active` (default true: Activity is the section on screen and nothing covers it), `now` (clock, default `DateTime.now`).

**activityTabBadge(tab, store, whispers)**: notifications -> `store.unreadCount`; whispers -> `whispers?.unreadCount ?? 0`.

**State.** `_seen` = `active && lifecycleState (null counts as resumed) == resumed`. `initState`: if seen -> `_opened()`; a MobX `reaction` on `store.newCount`: when seen and count > 0 -> `markViewed()` (what arrives while the list is open is not "new"); an `AppLifecycleListener(onResume: if active -> _opened())`. `didUpdateWidget`: becoming active -> `_opened()`. `_opened()` = `store.refresh().then(markViewed)` (bar count cleared; unread stay bold). Two ScrollControllers (`_notificationsScroll`, `_whispersScroll`) so each phone tab keeps its scroll. `_whispersBuilt` — once Whispers was shown it stays built (reset to false when logged out). dispose cleans the listener, reaction and controllers.

build: `notifications = _NotificationsList(store, onOpenChannel, now, tablet: isLargeScreen)`. Large screen -> `_TabletActivity(notifications, store, whispers)`. Phone -> `IndexedStack(index: showWhispers ? 1 : 0, sizing: expand)` with `[TickerMode(enabled: !showWhispers, PrimaryScrollController(_notificationsScroll, notifications)), if whispers && built TickerMode(enabled: showWhispers, PrimaryScrollController(_whispersScroll, WhispersList(store: whispers))) else SizedBox.shrink()]` — both kept alive, switching never resets either scroll; hidden tab's animations paused.

**_ActivityColors.of(context)**: reuses `WhisperColors` (one grey palette for both columns): ground = scaffold background, card = whisper card, cardRing = whisper paneRing, raised, ring = `hairlineStrongDark #29FFFFFF` in dark / `#1F000000` in light, text, body, secondary, tertiary, menu = raised (dark) / card (light).

**_NotificationsList** (state): `_folding: Map<id, ActivityEntry>` — rows currently folding away, kept visible while folding though already removed from storage (leaving mid-fold cannot bring them back). `_followStates`: cache by lower-cased login of `FollowFlow.actionsOf(context)?.channelFollowState(login)` (Helix `getUser` + `isFollowing`; null when logged out / on failure). The cache lives as long as the list state and is never invalidated: following from a row only updates that row's `_EntryFollow` local state (`onChanged`), so a row rebuilt from scratch for the same channel (another row naming it, or the same row re-created) shows the stale "Follow" again, and an unfollow made elsewhere is not reflected (see Known Android defects). `_open(entry)`: `markRead(id)` then `onOpenChannel(login)` if any. `_remove(entry)`: `store.remove(id)`; unless reduce motion, add to `_folding` (300 ms fold); `_folded(id)` removes from `_folding` (if storage refused the removal the row stays/comes back). `_menu(rowContext, entry)`: `Haptics.selection()`; tablet -> `_showPopover`; phone -> `showOnsetSheet<bool>(_RemoveSheet)`; true -> `_remove`.
`_showPopover`: anchor = row's local point `(width - 18, 46)` converted to overlay coordinates; `showMenu<bool>(position: RelativeRect.fromLTRB(x - 230, y, overlayW - x, overlayH - y), color: menu, elevation 12, minWidth 230, menuPadding all 6, RoundedRectangleBorder(radius 14, side ring hairline 0.5))` with one `PopupMenuItem(value true, height 44, horizontal padding 12)`: `StateGlyph(trash, 18)` + 10 gap + `l.activityRemove` (14 px w600).

build (Observer): `entries` = stored + folding entries not in storage, sorted by `at` descending. `at = now()`. Split: `recent` = age <= 1 day ("Most Recent"); `earlier` = age > 1 day. Each row = `_Folding(key: ValueKey(id), folding, onFolded)` > Builder > `_EntryRow(entry, now, tablet, colors, onTap: _open, onMenu: _menu(rowContext), followState: null for live entries, else _followState(login) when login exists)`.
- Empty -> `RefreshIndicator.adaptive(edgeOffset: safeTop, onRefresh: store.refresh)` + `ListView(AlwaysScrollable, padding top: safeTop + (72 tablet / 96 phone) - 24, bottom safeBottom)` of `[TwitchInboxEntry(onOpenChannel), FeedStatusView.empty(message: l.activityEmpty, detail: l.activityEmptyDetail, glyph: StateGlyphKind.bell)]`.
- `first = recent.isNotEmpty ? recent : earlier`; `second = recent.isNotEmpty ? earlier : []` (so when everything is older than a day it is shown under "Most Recent").
- Tablet children: `TwitchInboxEntry(tablet: true)`, card("Most Recent" `l.activityMostRecent`, first), card(`l.activityEarlier`, second) if any; a card = `Padding(bottom 16)` > Container(vertical padding 6, card colour, radius 20, cardRing hairline) > Column[_SectionTitle(tablet), rows].
- Phone children: `TwitchInboxEntry`, `_SectionTitle(l.activityMostRecent, onMarkAll: unread > 0 ? markAllRead : null)`, first rows, then `_SectionTitle(l.activityEarlier)` + second rows if any, then footer `Padding(LTRB 16,18,16,8)` centered `l.activityNote` (12 px tertiary).
- Wrapped in `RefreshIndicator.adaptive(edgeOffset: safeTop, onRefresh: store.refresh)` + `ListView(AlwaysScrollable, padding top safeTop, bottom safeBottom + (28 tablet / 0), left/right safe insets on phone only)`.

**_SectionTitle** (`title`, `tablet`, `colors`, `onMarkAll?`): Container(minHeight 44, padding tablet LTRB(18,6,14,6) / phone LTRB(16,14,8,4)) > Row: Expanded `Semantics(header)` title (16 tablet / 15 phone, w700, letterSpacing -0.225, text); when onMarkAll: `Flexible(flex 2, TextButton.icon(foreground body, minimumSize height 36, horizontal padding 12, StadiumBorder, 13 px w600, icon StateGlyph(checkAll, 16, stroke 2), label l.activityMarkAllRead max 2 lines ellipsis))` — at large text the button takes up to two thirds and wraps.

**_Folding** (`folding`, `onFolded`, `child`): `AnimationController(300 ms, value 1)`; size curve `OnsetMotion.standard` Cubic(0.2,0,0,1); fade curve `Interval(1/3, 1)` (fade finishes in the first two thirds of the reverse, i.e. opacity reaches 0 at 1/3 of the controller value); `_fold()` = `reverse()` then `onFolded()` if still folding. Un-folding (storage refused) snaps value back to 1. `SizeTransition(sizeFactor, axisAlignment: -1)` > `FadeTransition`.

**_EntryRow**: `Semantics(button, onLongPressHint: l.activityOptions)` > PressScale > transparent Material > `InkWell(onTap, onLongPress: onMenu, NoSplash)` > Padding (tablet h18 v14 / phone h16 v12) > Row(start): `_EntryAvatar(size 48/44, badge 22/20, rim: card on tablet / ground on phone)`, 14 gap, Expanded `Padding(top 1)` Column(start, spacing 3): title `entry.titleIn(l)` (max 2 lines; 15/14 px; height 1.35; letterSpacing -0.07; w700 + text colour when unread, w500 + secondary when read); body `entry.bodyIn(l)` if non-empty (max 2 lines; 14/13 px height 1.4; body colour unread / tertiary read); meta `'<formatTimeAgo(at, now)> • <kind.label(l)>'` (bullet U+2022; 12 px tertiary; kind labels `activityKindLive`, `activityKindMention`, `activityKindReminder`) with top padding 1; `_EntryFollow` when a followState future exists. Tablet only: trailing 8 gap + `StateGlyph(chevronRight, 18, stroke 2, tertiary)` with top padding 14.

`_channelName(entry)` = `params['name'] ?? params['channel'] ?? login ?? ''`.

**_EntryFollow** (`state` future, `login`, `name`, `colors`): reads the future; null/unmounted -> nothing. Following -> `Semantics(container)` Row(min, spacing 6): `Icon(check_rounded, 16, live colour)` + `l.channelFollowing` (13 px w600 secondary). Not following -> `Tooltip(l.channelFollowTooltip(name))` > PressScale > `FilledButton(onPressed: busy ? null : _follow, foreground #0A0A0A, background live colour, min height 36, horizontal padding 16, StadiumBorder, 13 px w700, child l.channelFollow)`. `_follow` sets busy, calls `FollowFlow.toggle(context, target: FollowTarget.channel, id, name, following: false, onChanged: (now) => _following = now)`, then clears busy. Top padding 6, start-aligned. Not shown for go-live entries (the viewer obviously follows them).

**_EntryAvatar** (`entry`, `size`, `badge`, `rim`, `colors`): kind glyph live -> `StateGlyphKind.live`, mention -> `mention`, reminder -> `calendar`; kind colour = live colour for go-live, body otherwise. Picture = `ProfilePicture(userLogin, radius size/2)` when there is a login, else a raised circle with the kind glyph at `size * 0.45`. Stack(clip none): picture (ExcludeSemantics); unread dot (key `activity-unread-dot`, `Semantics(label: l.activityUnread)`) 13 x 13 live colour with 2.5 rim border at left -2 top -2; kind badge `badge x badge` raised circle with 2 rim border at right -4 bottom -4 containing `StateGlyph(glyph, size badge/2, stroke 2.2)`.

**_RemoveSheet** (phone options sheet): `SafeArea(top: false)` > Padding(LTRB 8,0,8,20) > Column: header Container(padding LTRB 12,4,12,10, bottom hairline) Row: `ExcludeSemantics(ProfilePicture(login, radius 14))` + 10 gap when login, then entry title (1 line, 13 px secondary); 4 gap; `SheetRow(glyph trash, label l.activityRemove, onTap: pop(true))`.

**_TabletActivity** (`notifications`, `store`, `whispers`): `asideWidth = width >= 1100 ? 392 : 320`. Header `Padding(LTRB 4,4,4,14)` Row(end): Expanded Column(start, spacing 4): `Semantics(header)` `l.activityTitle` (30 px w800 letterSpacing -0.9) and `l.activityNote` (13 px tertiary); an Observer showing `_MarkAllPill(count: unreadCount, onPressed: markAllRead)` when unread > 0. The list gets `MediaQuery.removePadding(removeTop: true)`. Without whispers: `Align(topCenter, ConstrainedBox(maxWidth 860, Column[header, Expanded(list)]))`. With whispers: Column[Row[Expanded(header), SizedBox(24 + asideWidth)], Expanded(Row(stretch)[Expanded(list), 24 gap, SizedBox(asideWidth, Padding(bottom 28 + safeBottom, _WhispersColumn))])] — the whispers column starts where the first card does whatever the header's height. Outer `Padding(LTRB(28 + safeLeft, 12, 28 + safeRight, 0))`.

**_MarkAllPill**: PressScale > `OutlinedButton(min height 40, horizontal padding 16, background raised, foreground text, side ring hairline, StadiumBorder, 14 px w600)` Row(min, spacing 8): `StateGlyph(checkAll, 17, stroke 2)`, `l.activityMarkAllRead`, `WhisperCountPill(count)`.

**_WhispersColumn** (`store: WhisperStore`, `colors`): Container(antiAlias, card colour, radius 20, cardRing hairline) > Observer > Column: header `Padding(LTRB 18,16,12,8)` Row[Expanded Row[Flexible(Semantics(header, FittedBox(scaleDown, Text(l.whispersTitle, 1 line, 17 px w700 letterSpacing -0.25)))), if unread > 0 (8 gap, WhisperCountPill(unread, size 18))], TextButton(Row(min, spacing 4)["See all" `l.commonSeeAll`, StateGlyph(chevronRight, 16, stroke 2, body)], foreground body, min height 36, padding left 12 right 8, StadiumBorder, 13 px w600, onPressed: WhispersScreen.open(context, store))]; `WhisperStatusNote(store, margin LTRB 12,0,12,8)`; Expanded: no threads -> `Padding(LTRB 18,8,18,18, Text(l.activityNoWhispers, 13 px height 1.45 secondary))`; else `ListView.builder(padding LTRB 6,0,6,8)` of `WhisperThreadRow(key: userId, thread, compact: true, rounded: true, onTap: WhispersScreen.open(context, store, select: WhisperTarget.of(thread)))` with top/bottom media padding removed.

PC equivalent: Activity becomes a sidebar section; the tablet layout is the default on desktop (notifications list max 860 wide; whispers aside 320/392 by window width >= 1100); right-click on a row opens the context menu ("Remove notification") positioned like the popover; the fold animation kept (300 ms); "seen" logic driven by window focus/visibility instead of app lifecycle. Tested by `test/screens/activity/activity_screen_test.dart`, `test/screens/activity/activity_follow_test.dart` and `test/screens/activity/activity_store_test.dart`. Also `test/screens/home/home_test.dart` ('Activity: tabs with counts on a phone, two columns on a…' around line 1243, and 'Following first; whispers in the header and in Activity' around line 1276: the shell header tabs/badges and the tablet whispers column inside Home).

### lib/screens/notifications/stores/notification_center_store.dart

MobX store (`NotificationCenterStore = NotificationCenterStoreBase with _$NotificationCenterStore`; generated part `notification_center_store.g.dart`) for Twitch's own ON-SITE notification inbox (the twitch.tv bell), distinct from the local Activity list. Constructor injects `fetch: Future<OnsiteNotificationPage?> Function(String? cursor)` and `markRead: Future<ViewerActionOutcome> Function(List<String> ids)`. Constant `maxNotifications = 300`.

State: `notifications: ObservableList<OnsiteNotification>` (public final), `@readonly loading` (false), `failed` (false), `marking` (false), `cursor: String?`; private `_epoch` counter. Computed `unreadCount` = notifications with `!isRead`; `hasMore` = `cursor != null`.

`refresh()` (action): `epoch = ++_epoch`, loading = true, `page = await fetch(null)`; if a newer refresh started meanwhile (`epoch != _epoch`) the result is discarded (and loading stays true for the newer call). Else in one action: loading = false; `failed = page == null`; on a page: clear and add all notifications, set `cursor = page.cursor`. A failed refresh keeps the old list (only sets failed). `fetch` is not wrapped in try/catch: if it THROWS (rather than returning null) `loading` stays true forever and the exception escapes; with an empty list the screen then shows a spinner indefinitely and `loadMore` never runs again (see Known Android defects; the production fetch `TwitchSocialService.notifications` catches and returns null, so this needs a throwing injected fetch).

`loadMore()` (action): returns if no cursor or already loading. Captures the current epoch (a refresh during the load invalidates it), loading = true, `page = await fetch(cursor)`. On a stale epoch, discarded. Else loading = false; a null page sets `cursor = null` (stops paging, no error state); otherwise appends only notifications whose id is not already present (dedup), truncates the list to 300 (`removeRange(300, length)`), and sets `cursor = length >= 300 ? null : page.cursor`. Same unguarded `await fetch(cursor)`: a throw leaves `loading` true.

`markAllReadLocally()` (action): replaces every unread notification with `notification.read()` and returns their ids (optimistic). `restoreUnread(ids)` (action): replaces those with `.unread()`. `sendRead(ids)` (action): marking = true; `outcome = await markRead(ids)`; then marking = false and, unless `outcome == ViewerActionOutcome.done`, `restoreUnread(ids)` (rollback); returns the outcome. `ViewerActionOutcome { done, refused, integrityRefused, signedOut, failed }`.

PC equivalent: same store in Rust (generation counter instead of epoch; dedup by id; 300 cap). Tested by `test/screens/notifications/notification_center_test.dart`.

### lib/screens/notifications/notification_center_screen.dart

Twitch on-site notifications ("Twitch notifications" inbox), reached from a card at the top of the Activity notifications list.

**TwitchInbox** typedef `({TwitchSocialService service, String userId, String token})`. **twitchInboxOf(context)** reads `TwitchSocialService?` and `AuthStore?` from Provider; returns null unless there is a service, a non-empty `auth.twitchWebToken` (the twitch.tv first-party web session token, not the Helix app token) and a logged-in user id. **notificationCenterStoreFor(inbox, language:)** builds a `NotificationCenterStore` with `fetch: service.notifications(userId, authToken: token, language, cursor)` and `markRead: service.markNotificationsRead(ids, authToken: token)`.

**NotificationCenterScreen** (`store`, `onOpenChannel`, `now = DateTime.now`); `markAllKey = ValueKey('notification-center-mark-all')`; static `open(context, store, onOpenChannel)` pushes a `MaterialPageRoute` named `NotificationCenter`. State: a `ScrollController` with listener `_maybeLoadMore` (when `pixels > maxScrollExtent - 400` -> `store.loadMore()`); `initState` calls `store.refresh()`.

`_markAll()`: `ids = store.markAllReadLocally()` (rows turn read immediately); if no ids, stop; if there is no `ScaffoldMessenger`, also stop — but the optimistic change is LEFT in place: rows stay locally read, nothing is sent and nothing is restored (they read unread again on the next refresh). Hide the current snackbar, then show `SnackBar(content: l.notificationCenterMarkedRead(count: ids.length), action: SnackBarAction(label: l.commonUndo, onPressed: no-op))` and await `.closed`. If closed by the action (Undo) -> `restoreUnread(ids)`, nothing sent. Otherwise (timeout/dismiss/hidden) -> `outcome = await store.sendRead(ids)`; if not done show `SnackBar(l.viewerActionResult(status: outcome.name))` (the store already restored the unread state). This is an undo-window pattern: the mutation is only sent after the snackbar closes, for ANY close reason other than the action (timeout after the default 4 s, swipe, hide, replaced by another snackbar). Because the SnackBar has an action, it does not time out while accessible navigation is on (TalkBack/Switch Access): the mutation is then held until the user dismisses the snackbar or it is hidden.

`_open(notification)`: if `channelLogin` (extra `__typename == 'User'` with a valid login) -> `onOpenChannel(login)`; else if `link` (first `actions[].url` that is https on `twitch.tv` or `*.twitch.tv`) -> `TwitchWebPage.open(context, title: l.notificationCenterTitle, url: link)` (in-app Twitch web view with the session). Rows with neither are not tappable (`onTap: null`, `Semantics(button: false)`).

build: `colors = WhisperColors.of(context)`; `tablet = isLargeScreen`. `Scaffold(AppBar(title: l.notificationCenterTitle, actions: [Observer: unreadCount == 0 ? nothing : IconButton(key markAllKey, tooltip l.activityMarkAllRead, onPressed: marking ? null : _markAll, icon StateGlyph(checkAll, text colour, size 22))]))`. Body `Center(ConstrainedBox(maxWidth: 760 tablet / infinity phone, Observer))`:
- empty list + loading -> centered `CircularProgressIndicator.adaptive()`;
- empty, not loading -> `ListView(AlwaysScrollable, padding top 72)` with `FeedStatusView.error(message: l.notificationCenterFailed, onRetry: refresh)` when `failed`, else `FeedStatusView.empty(message: l.notificationCenterEmpty, glyph: bell)`;
- otherwise `RefreshIndicator.adaptive(onRefresh: refresh)` + `ListView.builder(controller, AlwaysScrollable, padding top 12 tablet / 4 phone, bottom safeBottom + 16, itemCount: n + (hasMore ? 1 : 0))`: the extra last item is a `Padding(all 16)` centered progress spinner; others `NotificationCenterRow(notification, when: formatTimeAgo(createdAt, l, now: now()), colors, tablet, onTap)`.

**NotificationCenterRow** (`notification`, `when`, `colors: WhisperColors`, `tablet`, `onTap?`): `Semantics(button: onTap != null)` > PressScale > transparent Material > `InkWell(onTap, NoSplash)` > Padding(horizontal 18/16, vertical 14/12) > Row(start): `ClipOval` square avatar 48 (tablet) / 44 (phone) = `OnsetCachedNetworkImage(avatarUrl ?? thumbnailUrl, cover, placeholder and errorWidget = _AvatarFallback)` or the fallback when neither URL (only https URLs on `*.jtvnw.net` / `*.twitch.tv` are accepted by the model); 14 gap; Expanded Column(start, spacing 3): `notification.body` (max 3 lines; 15/14 px; height 1.35; letterSpacing -0.07; unread w700 text colour, read w500 secondary) and `when` (12 px tertiary); when unread a trailing 8 x 8 dot in `OnsetTokens.accent #C8FF3D` with padding left 10 top 8.

**TwitchInboxEntry** (`onOpenChannel`, `tablet = false`); `tileKey = ValueKey('twitch-inbox-entry')`. State `_inbox`, `_unseen: int?`. `didChangeDependencies`: recompute `twitchInboxOf`; if token and user id unchanged, nothing; else store it, reset unseen, and if non-null `_count(inbox)` -> `service.unseenNotifications(userId, authToken)` (GQL summary `unseenCount`) applied only if still mounted and the same inbox instance. `_open(inbox)`: builds a store with `language = Localizations.localeOf(context).languageCode`, awaits `NotificationCenterScreen.open`, then re-counts on return. build: no inbox (logged out or no web session) -> nothing. Else `Padding(tablet: bottom 16 / phone: LTRB 16,8,16,4)` > PressScale > `Material(card colour, RoundedRectangleBorder(radius 20 tablet / 16 phone, side paneRing hairline), antiAlias)` > `InkWell(key tileKey, NoSplash)` > Padding(h16 v14) > Row(spacing 12): `StateGlyph(bell, text)`; Expanded Column(start, spacing 2): `l.notificationCenterTitle` (15 px w700) and `l.notificationCenterEntryDetail` (13 px secondary); when unseen > 0 a pill (padding h9 v3, accent #C8FF3D, radius 999) with `l.notificationCenterUnseen(count)` (12 px w700 black); trailing `StateGlyph(chevronRight, 18, stroke 2, tertiary)`.

**_AvatarFallback**: `ColoredBox(raised)` with centered `StateGlyph(bell, secondary)`.

PC equivalent: same inbox page (max width 760 centered); infinite scroll trigger at 400 px from the end; undo toast with a 4 s window before sending the read mutation; links open in the in-app Twitch web view (WebView2 on Windows) or the default browser as fallback. Tested by `test/screens/notifications/notification_center_test.dart`. French rendering: `test/l10n/fr_lot8c_test.dart`.

### lib/screens/whispers/whisper_kit.dart

Shared whisper visual kit (used by the whispers screens and by Activity / Notification Center for their palette).

**WhisperColors** (immutable palette, `of(context)` picks by theme brightness). Dark: text #F5F5F5, body #D6D6D6, secondary #A1A1A1, tertiary #8A8A8A, pane #111111 (tablet conversation pane), paneRing #14FFFFFF, card #141414 (surfaceDark), field #141414, fieldRing #1FFFFFFF (hairlineRaisedDark), raised #1E1E1E, hairline #12FFFFFF, selected #1A1A1A (conversation on screen in the tablet list), mineFill #F5F5F5, mineText #0A0A0A, mineTime #5E5E5E, theirFill #1E1E1E, theirText #F5F5F5, theirTime #A1A1A1, shadow #8C000000 (under the conversation sliding over the list). Light: text #0A0A0A, body #3A3A3A, secondary #6B6B6B, tertiary #6B6B6B, pane #FFFFFF, paneRing #14000000, card #FFFFFF, field #FFFFFF, fieldRing #1F000000, raised #F0F0F0, hairline #14000000, selected #EFEFEF, mineFill #0A0A0A, mineText #F5F5F5, mineTime #A1A1A1, theirFill #EDEDED, theirText #0A0A0A, theirTime #6B6B6B, shadow #29000000.

**whisperTime(at)** = `DateFormat.jm().format(at.toLocal())` ("9:41 PM" / "21:41").

**WhisperCountPill** (`count`, `size = 20`; 18 next to a title): `height = textScaler.scale(size)` (grows with text size); `Semantics(label: l.whispersUnreadCount(count), excludeSemantics)` > Container(minWidth = height, height, horizontal padding 6 when size > 18 else 5, centered, live colour (`context.onsetColors.live`: #C8FF3D dark / #6B9E00 light), radius height/2) > `Text('$count', 1 line, tabular 11 px height 1 w800, colour onFillColor(accent))` (readable foreground for the fill).

**WhisperThreadRow** (`thread: WhisperThread`, `onTap`, `onLongPress?`, `selected = false`, `compact = false` (Activity's tablet column: 64 dp row, 44 dp picture), `rounded = false` (tablet rows), `muted = false`): Observer (thread is observable). `last = thread.whispers.lastOrNull`; `unread = thread.unread`; bold when unread > 0; `preview = whisperPreview(last.text)` (strips invisible characters, stray joiners, replaces unsafe characters with spaces, collapses double spaces, trims); `time = whisperTime(last.sentAt)`. A thread with no whispers yet (`last == null`, e.g. a new conversation just opened from the picker) shows an empty preview, an empty time, no reply arrow, and only its name and unread pill if any. `Semantics(button, selected)` > PressScale > transparent Material > `InkWell(onTap, onLongPress, NoSplash, radius 14 when rounded)` > `_SelectedBar` > Container(minHeight 64 compact / 72, padding horizontal 12/16 vertical 8/10, colour `selected` when selected, radius 14 when rounded) > Row: `ProfilePicture(userLogin: thread.login, radius avatar/2)` (avatar 44 compact / 48) excluded from semantics; 12 gap; Expanded Column(start, min, spacing 4):
- Row(baseline alphabetic): Expanded `whisperPreview(displayName)` (1 line, 15 px, w700 bold / w600, letterSpacing -0.15, text); if muted: 6 gap + `Icon(Icons.notifications_off_outlined, 14, tertiary, semanticLabel l.whisperMuted)`; 8 gap; time (tabular 12 px, text when bold / tertiary).
- Row: if the last whisper is mine: `Semantics(label: l.whisperYou, StateGlyph(reply, tertiary, 15, stroke 2))` + 6 gap (an arrow, never a "You:" prefix a whisper could fake); Expanded preview (1 line, 13 px, text when bold / secondary); if unread: 6 gap + `WhisperCountPill(unread)`.

**_SelectedBar**: when selected, `ClipRRect(radius)` Stack with a `Positioned(key: ValueKey('whisper-selected-bar'), left 0, top 0, bottom 0, width 2.5)` accent bar.

**WhisperStatusNote** (`store: WhisperStore`, `margin = LTRB(16,8,16,8)`): `duration = motionDuration(context, 300 ms)` (150 ms cross-fade under reduce motion). Observer on `store.status`; `hint = whisperStatusHint(status, l)`. When there is a hint, a card `Padding(key: ValueKey(status), margin)` > `Semantics(liveRegion)` > Container(padding h12 v10, card colour, radius 12, paneRing hairline) > Row: mark (interrupted -> 14 x 14 `CircularProgressIndicator(strokeWidth 2, color body, background hairline)` — a turning ring while reconnecting; refused -> `StateGlyph(alert, danger #FF5A5F, 16)`; others -> `StateGlyph(offline, secondary, 16)`), 10 gap, Expanded hint (13 px height 1.4 body). Wrapped in `AnimatedSize(duration, curve OnsetMotion.standard Cubic(0.2,0,0,1), alignment topCenter)` > `AnimatedSwitcher(duration)` with the card or `SizedBox(width: infinity)` — the rows below follow the card in and out without a jump.

**whisperStatusHint(status, l)**: refused -> `l.whisperStatusRefused`; interrupted -> `l.whisperStatusInterrupted`; unavailable -> `l.whisperStatusUnavailable`; off -> `l.whisperStatusOff`; connecting / listening -> null (no card). `WhisperStatus` (global store, lib/stores/whisper_store.dart): off (logged out / not started), connecting, listening, interrupted (reconnecting, retries itself), refused (token lacks the whisper scope or revoked: log in again), unavailable.

PC equivalent: Slint palette struct with the identical hex values for dark/light; thread row component with hover highlight; status note with the same 300 ms size/fade (150 ms reduce-motion) — the desktop whisper transport (EventSub WebSocket `user.whisper.message`) drives the same statuses. Tested by `test/screens/whispers/whispers_screen_test.dart`.

### lib/screens/whispers/whisper_notice.dart

`whisperNotice(context, IncomingWhisper whisper, {required WhisperStore store, required VoidCallback onOpen}) -> SnackBar` — the in-app toast for a whisper received while the viewer is elsewhere in the app (shown by `lib/screens/home/home.dart`). It leaves by itself like any snackbar (default 4 s), except while accessible navigation is on (an action keeps a SnackBar up in that mode).

Captures `me = store.me` at creation: the "Open" action only calls `onOpen` if `store.me == me` still (after an account switch, the stale notice does nothing). Values: `large = isLargeScreen`; `fill = colors.raised (#1E1E1E) in dark / surfaceLight #FFFFFF in light`; avatar 38 (tablet) / 34 (phone); `name = whisperPreview(fromName)`, `text = whisperPreview(whisper.text)` (sanitised).

SnackBar: `behavior: floating`, `backgroundColor: fill`, `elevation 10`, `width: 480` on tablet (null on phone), `margin: LTRB(10,0,10,8)` on phone (null on tablet — width and margin are exclusive), `padding: LTRB(14 tablet / 12 phone, 10, 8, 10)`, `action: SnackBarAction(label: l.whisperOpen, textColor: live colour (`context.onsetColors.live`: #C8FF3D dark / #6B9E00 light))`, `shape: RoundedRectangleBorder(radius 18 tablet / 16 phone, side: dark ? hairlineStrongDark (#29FFFFFF) at alpha 0.14 : hairlineLight #14000000, width 0.5)`. Content Row: `ExcludeSemantics` square of `avatar + 3` with a Stack(clip none): `ProfilePicture(userLogin: fromLogin, radius avatar/2)` and at right 0 bottom 0 a 19 (tablet) / 18 (phone) circle filled #F5F5F5 (dark) / #0A0A0A (light) with a 2 px `fill`-coloured border holding `StateGlyph(whisper, size 10, strokeWidth 2.6, colour inverted #0A0A0A / #F5F5F5)`; gap 12 / 10; Expanded `Text.rich([TextSpan('<name> ', w700 text colour), TextSpan(text)], maxLines 2, ellipsis, 14 px height 1.4 body colour)`.

PC equivalent: an in-window toast (bottom-centred, 480 wide) with the same content and an "Open" button; additionally a Windows toast notification when the window is not focused (handled by the desktop notifier); same stale-account guard. Tested by `test/screens/whispers/whisper_notice_test.dart`. Also `test/screens/home/home_test.dart` ('a whisper notice goes with its account; Open never opens…', around line 1209: the notice shown by Home, account guard end to end).

### lib/screens/whispers/whisper_actions.dart

Thread actions, confirmation dialogs and the "new whisper" picker.

**showWhisperThreadActions(context, store, thread, onHidden?)** -> `showOnsetSheet<void>` with a shrink-wrapped ListView: `SheetSectionLabel(thread.displayName)`; then
1. `SheetRow(key 'whisper-action-mute', label: muted ? l.whisperUnmute : l.whisperMute, glyph bell)` -> `store.toggleMute(userId)`, pop. (Mute is local: no notice/sound for that conversation.)
2. `SheetRow(key 'whisper-action-archive', label: archived ? l.whisperUnarchive : l.whisperArchive, leading Icon(Icons.archive_outlined, 20))` -> `unarchive` / `archive`, pop.
3. Only when `whisperAllowanceRemover` returns a function: `SheetRow(key 'whisper-action-stop-replies', label: l.whisperStopReplies(name), glyph block)` -> pop, then `stopWhisperReplies(context, name, remove)`.
4. `SheetRow(key 'whisper-action-hide', label: l.whisperHide, glyph trash, danger: true)` -> pop, `confirmHideWhisperThread`; if confirmed `store.hide(userId)` then `onHidden?.call()` (the screen closes the open conversation).
`muted`/`archived` are read when the sheet builds.

**whisperAllowanceRemover(context, store, thread)**: needs `store.remoteThreadId(userId)` (the Twitch thread id `<id>_<id>` known from GQL history), a `TwitchSocialService` and a non-empty `AuthStore.twitchWebToken`; else null (row hidden). Returns `() => social.removeWhisperAllowance(threadId, authToken)` -> GQL `RemoveWhisperThreadWhitelistMutation` (`updateWhisperThread(input: {removeWhitelist: true, threadID})`), success when the payload thread id matches; thread id must match `^[0-9]{1,20}_[0-9]{1,20}$` else `failed`. Meaning: Twitch lets a person you whispered reply even when you block whispers from strangers; this withdraws that allowance.

**stopWhisperReplies(context, name, remove)**: `OnsetDialog(title: l.whisperStopRepliesTitle(name), message: l.whisperStopRepliesBody(name), actions: [SheetButton(l.commonCancel, tone text) -> false, SheetButton(key 'whisper-stop-replies-confirm', l.whisperStopRepliesConfirm, tone danger) -> true])`; on confirm awaits `remove()` and (messenger captured before the dialog) hides the current snackbar and shows `l.viewerActionResult(status: outcome.name)` (done/refused/integrityRefused/signedOut/failed wording, outside this area).

**confirmHideWhisperThread(context, name)** -> `OnsetDialog(title: l.whisperHideConfirmTitle, message: l.whisperHideConfirmMessage(name), actions: [cancel -> false, SheetButton(key 'whisper-hide-confirm', l.whisperHideConfirm, danger) -> true])`; returns `confirmed ?? false` (barrier dismiss = false).

**pickWhisperTarget(context, me)** -> `showOnsetSheet<WhisperTarget>(NewWhisperSheet(search: TwitchApi.searchChannels, me))`. `searchChannels` = Helix `GET /search/channels?first=8&query=<q>`.

**NewWhisperSheet** (`search`, `me?`), `debounce = 300 ms`. State: TextEditingController, debounce Timer, `_query`, `_results`, `_failed`, `_searching`. `_changed(text)`: cancel timer; empty trimmed text resets everything; else `_searching = true` and schedule `_run(query)` after 300 ms. `_run`: awaits search; drops the answer if unmounted or the field no longer holds this query; filters out the viewer (`c.id != me`); on error logs `Whisper search failed: $e`, sets failed with empty results. build: status text = `l.whispersNewFailed` if failed; else `l.whispersNewNoMatch(query)` when not searching, a query exists and no results; else none. `Padding(bottom: keyboard inset)` > Column(min, stretch): `SheetSectionLabel(l.whispersNew)`; `Padding(LTRB 16,0,16,8)` `SheetTextField(key 'new-whisper-search', autofocus, hint l.whispersNewSearch, onChanged)`; status `Padding(LTRB 16,8,16,16)` (`SheetText.body` secondary); `Flexible(ListView(shrinkWrap))` of `SheetRow(key 'new-whisper-<id>', label displayName, detail: broadcasterLogin unless it equals the lower-cased display name, leading InitialAvatar(name), onTap: pop(WhisperTarget(userId: id, login: broadcasterLogin, displayName)))`.

PC equivalent: actions as a context menu (right-click on a thread) and a kebab button in the conversation header; dialogs as modal Slint dialogs; new-whisper picker as a popup with an autofocused search field and the same 300 ms debounce. Tested by `test/screens/whispers/whisper_actions_test.dart`, `test/screens/whispers/whisper_stop_replies_test.dart` and `test/screens/whispers/whispers_screen_test.dart`. French rendering of `NewWhisperSheet`: `test/l10n/fr_lot5_test.dart`.

### lib/screens/whispers/whispers_screen.dart

The viewer's whispers: on a phone the conversation list with a conversation sliding over it; on a tablet the list beside the conversation pane. One widget tree for both, so the open conversation and its draft survive the window crossing the tablet size (GlobalKeys). Re-exports `whisperStatusHint` from whisper_kit.

**WhisperTarget** (immutable; `userId`, `login`, `displayName`; `WhisperTarget.of(thread)`): equality and hashCode by `userId` only.

**WhispersScreen** (`store: WhisperStore`, `initial: WhisperTarget?` (conversation open at first), `conversationOnly = false` (opened for `initial` alone from a chat or a notice: on a phone back leaves the page instead of showing the list)). `routeName = '/whispers'`. Static `open(context, store, select?)` pushes a `MaterialPageRoute` named `/whispers` with `initial: select`.

State fields: `_selected: WhisperTarget?`; `_open` (a conversation is open over the phone list); `_slide: AnimationController(duration 340 ms, value 1 if open else 0)` (0 = list, 1 = conversation over it); `_keys: Map<userId, GlobalKey>`; `_autoOpen = true` (the tablet opens the most recent conversation by itself until the viewer closes one; then the pane waits for a choice so a conversation is never marked read without being opened); `_dragging` (edge swipe in progress, slide linear under the finger).

initState: `_selected = initial`, `_open = initial != null`, `store.refreshHistory()` (GQL history, unawaited), create `_slide`, and a MobX `reaction` on `store.me`: on any account change reset selected = null, open = false, autoOpen = true, dragging = false, slide value 0 (the open conversation belonged to the previous account). `didChangeDependencies`: if now a phone, open, and not animating -> `_slide.value = 1` (chosen on a tablet, window became a phone: conversation over the list at once). dispose: reaction and controller.

`_select(target)`: slide duration = `motionDuration(340 ms)` (150 ms under reduce motion); setState selected + open; on phone `_slide.forward()`. `_back()`: if conversationOnly -> `Navigator.maybePop`; else duration as above, setState open = false, autoOpen = false, `await _slide.reverse()`, `_closed()` (if still not open: selected = null, dragging = false — a window then becoming a tablet does not reopen it).

Edge swipe (phone; the page's own back gesture would leave the whispers): `_dragStart` (only when open): stop the controller, dragging = true. `_dragUpdate`: `slide.value -= primaryDelta / screenWidth`. `_dragEnd(velocity px/s)`: `close = velocity > 700 || (velocity > -700 && value < 0.5)` (a flick decides; otherwise the release position). Close -> open = false, autoOpen = false, `animateTo(0, duration: round(340 * value) ms, curve OnsetMotion.standard)`, then `_closed()`. Else `animateTo(1, duration: round(340 * (1 - value)) ms, standard)` then dragging = false. Drag cancel = `_dragEnd(0)`.

`_conversation(target, pane)` = `WhisperConversation(key: _keyOf(target), store, userId, login, displayName, pane, onBack: _back, onHidden: _hidden)`. `_hidden()`: phone -> `_back()`; tablet -> selected = null, open = false, autoOpen = false (empty pane). `_startNew()`: `pickWhisperTarget(context, me: store.me)`; if a target -> `_select`.

build: `AnnotatedRegion(theme.systemOverlayStyle)` > `PopScope(canPop: large || !_open || conversationOnly, onPopInvokedWithResult: if not popped -> _back())` (system back closes the conversation first on a phone) > `Scaffold(backgroundColor: scaffold)` > Observer: `store.status == WhisperStatus.off` -> `_LoggedOut(onBack: maybePop)`; else tablet / phone layout.

**Phone (`_phone`).** `list = _ListPage(store, onOpen: _select, onNew: _startNew)`; `conversation` when selected. `AnimatedBuilder(_slide)`: `t = dragging ? value : OnsetMotion.standard.transform(value)` (Cubic(0.2,0,0,1)). `showList = (!conversationOnly || selected == null) && value < 1`; `showConversation = selected != null && (open || value > 0)`. Stack:
- list: `Positioned.fill(IgnorePointer(ignoring: open, Transform.translate(x: reduce ? 0 : -0.28 * screenWidth * t, Opacity(reduce ? 1 - t : 1 - 0.6 * t, ColoredBox(ground, list)))))` — parallax: the list slides 28 % left and dims to 40 %;
- conversation: `Positioned.fill(FractionalTranslation(x: reduce ? 0 : 1 - t, Opacity(reduce ? t : 1, DecoratedBox(color ground, boxShadow: while value < 1 and not reduce [BoxShadow(colors.shadow, offset (-18, 0), blurRadius 40)], conversation))))` — slides in from the right with a shadow on its left edge; under reduce motion both simply cross-fade;
- edge swipe zone (when conversation shown and not conversationOnly): `Positioned(key 'whisper-edge-swipe', left 0, top 0, bottom 0, width 20 + safeLeft)` `GestureDetector(translucent, dragStartBehavior: down, horizontal drag start/update/end/cancel)`.

**Tablet (`_tablet`).** `listWidth = width >= 1000 ? 372 : 320`. If nothing selected, threads exist and autoOpen -> select `threads.first` (kept; a whisper arriving elsewhere does not switch the pane). `Padding(LTRB(28 + safeLeft, safeTop + 12, 28 + safeRight, 28 + safeBottom))` > Row(stretch): list column `SizedBox(listWidth)` Column: header `Padding(bottom 6)` Row[`WhisperBackButton(text, maybePop)`, 4 gap, Expanded(Semantics(header, FittedBox(scaleDown, start, Text(l.whispersTitle, 26 px w800 letterSpacing -0.78)))), `NewWhisperButton`, Text(unread > 0 ? l.whispersUnreadCount(count) : l.whispersAllRead, tabular 13 px w500 secondary), 4 gap]; Expanded(all media padding removed, `WhispersList(store, onOpen: _select, selectedUserId, rounded: true, showEmpty: false, noteMargin LTRB(4,0,4,8))`). 20 gap. Pane: Expanded Container(antiAlias, colour `pane`, radius 24 (`radiusLarge`), paneRing hairline) with padding removed: selected -> `_conversation(pane: true)`; no threads -> `_NoWhispers`; else `FeedStatusView.empty(message: l.whispersChoose, glyph whisper)`.

**_ListPage** (phone list page): Column: header Container(padding top safeTop, left 4 + safeLeft, right 8 + safeRight, bottom hairline) height 56 Row[WhisperBackButton, 2 gap, Expanded(Semantics(header, FittedBox(scaleDown, Text(l.whispersTitle, 20 px w700 letterSpacing -0.4)))), NewWhisperButton]; Expanded(top padding removed, `WhispersList(store, onOpen)`).

**_NoWhispers**: `FeedStatusView.empty(message: l.whispersEmpty, detail: l.whispersEmptyDetail, glyph whisper)`.

**_LoggedOut**: SafeArea Stack: centered scrollable `FeedStatusView.signIn(message: whisperStatusHint(off), onConnect: openLogin(context))` and a `WhisperBackButton` at left 4 top 6.

**WhispersList** (`store`, `onOpen?` (null in Activity's tab: rows push the conversation route), `selectedUserId?`, `rounded = false`, `showEmpty = true`, `noteMargin = LTRB(16,8,16,8)`): state `_showArchived = false`; initState `store.refreshHistory()`. `_open`: onOpen given -> `onOpen(WhisperTarget.of(thread))`; else `WhisperConversation.open(...)`. Row = `Padding(bottom 2 when rounded)` > `WhisperThreadRow(key userId, selected, rounded, muted: store.isMuted(userId), onTap, onLongPress: showWhisperThreadActions)` — called WITHOUT `onHidden`, so hiding from a long press removes the row but, on a tablet, the pane keeps showing the hidden conversation (`_selected` is not cleared) until another is chosen. Observer: `threads` (active), `archived` (archivedThreads); `note = WhisperStatusNote(margin: noteMargin)`. Both empty -> `ListView(padding top safeTop, bottom safeBottom)[note, if showEmpty Padding(top 72, _NoWhispers)]`. Else `ListView(padding top safeTop + (rounded ? 0 : 6), bottom safeBottom + 24, left/right safe)` [note, thread rows, `_ArchivedToggle(count, expanded, toggle)` if any archived, archived rows when expanded].

**_ArchivedToggle**: `Semantics(button, expanded)` > `InkWell(key 'whispers-archived')` > minHeight 48, padding h16 v12, Row(spacing 8): `Icon(archive_outlined, 18, secondary)`, Expanded `l.whispersArchived(count)` (14 px w600 secondary), `AnimatedRotation(turns: expanded ? 0.5 : 0, duration 200 ms)` (linear, not shortened under reduce motion) chevronDown 18.

**NewWhisperButton** (`color`, `onPressed`): `IconButton(key 'whisper-new', tooltip l.whispersNew, 44 x 44, padding zero, SheetGlyph(addChat, size 22))`.

PC equivalent: desktop always uses the two-pane layout when the window is >= the large threshold (list 320, or 372 at >= 1000 px); below it the slide layout with a mouse "back" button and Alt+Left / Esc closing the conversation (edge swipe replaced, keep touch swipe on touch screens); new-whisper via Ctrl+N; archived toggle identical. Tested by `test/screens/whispers/whispers_screen_test.dart` and `test/screens/whispers/whisper_actions_test.dart`. `test/services/notifications/mention_alerts_test.dart` (around line 157) pins `WhispersScreen.routeName` among the pages a mention notification may or may not close.

### lib/screens/whispers/whisper_conversation.dart

The conversation with one person and the reply field; the phone page over the list, or the tablet pane (`pane`). While built, the conversation is "open" in the store: its whispers are marked read and arriving ones are read already.

**WhisperConversation** (`store`, `userId`, `login`, `displayName`, `pane = false` (tablet: 72 dp header with login, column centred, no back button), `onBack?` (phone back; null -> leave the page), `onHidden?`). `routeName = '/whisper'`. `open(context, store, userId, login, displayName)` pushes `route(...)`; `route(...)` (for callers whose context is going away, e.g. a closing sheet) = `MaterialPageRoute(name '/whisper', WhispersScreen(store, initial: WhisperTarget(...), conversationOnly: true))`.

State: `_thread = store.open(userId, login, displayName)` in initState (outside a build; marks read); `_known` = ids already present (those arriving later slide in); `_arrivals: Map<id, DateTime>`; `store.loadConversation(userId)` (GQL `WhisperMessageQuery`, 50 messages) unawaited. dispose -> `store.close(userId)`. `_text` controller, `_sending`, `_error: WhisperFailure?`.

`_send()`: ignore if trimmed text empty or already sending; `Haptics.light()`; sending = true, error = null; `error = await store.send(_thread, text)` (Helix `POST /whispers?from_user_id&to_user_id` with `{message}`; 1–10000 characters, `TwitchApi.maxWhisperLength = 10000`); then sending = false, error set; on success clear the field ONLY if it still holds exactly the sent text (a draft typed meanwhile is kept). Failures (`WhisperFailure.text(l)`): `WhisperLoggedOut` -> `l.chatLogInToWhisper`; `WhisperOtherAccount` -> `l.whisperOtherAccount`; `WhisperTooLong(max)` -> `l.whisperTooLong(max)`; `WhisperLogInAgain` -> `l.whisperLogInAgain`; `WhisperRefused(error)` -> `l.chatWhisperFailedBecause(reason: chatErrorText(l, error))`; `WhisperUnexpected` -> `l.whisperFailedUnexpected`.

`_showActions()` -> `showWhisperThreadActions(store, thread, onHidden: onHidden ?? onBack ?? maybePop)`.

build: Column[header (`_PaneHeader` when pane, else `_PageHeader(onBack: onBack ?? maybePop)`), names via `whisperPreview(displayName)`; Expanded `_Messages`; error line when set: `_Centered(enabled: pane, maxWidth 760, Padding(LTRB(pane ? 24 : 16, 0, 16, 8), Align(centerLeft, Semantics(liveRegion, Text(error, 12.5 px height 1.4 danger #FF5A5F)))))`; `_Composer`]. Wrapped in transparent Material; phone additionally `SafeArea(top: false, bottom: false)` (left/right insets).

**_Centered** (`enabled`, `maxWidth`, `child`): when enabled `Center(ConstrainedBox(maxWidth))`.

**_PageHeader** (phone): Container(padding top safeTop, left 4, right 12; bottom hairline) height 56 Row: `WhisperBackButton`, 10 gap, `ExcludeSemantics(ProfilePicture(login, radius 16))` (32 dp), 10 gap, Expanded `Semantics(header)` name (1 line, 16 px w700 letterSpacing -0.16), `_MoreButton`.

**_MoreButton**: `IconButton(key 'whisper-more', tooltip l.whisperMore, 44 x 44, SheetGlyph(more, 22))`.

**WhisperBackButton** (`color`, `onPressed`): `IconButton(tooltip: MaterialLocalizations.backButtonTooltip, 44 x 44, padding zero, StateGlyph(back, 22, stroke 2))`.

**_PaneHeader** (tablet): Container(minHeight 72, padding h20 v8, bottom hairline) Row: `ExcludeSemantics(ProfilePicture(login, radius 22))` (44 dp), 12 gap, Expanded `Semantics(header)` Column(start, min, spacing 2): name (1 line, 17 px w700 letterSpacing -0.25) and login (1 line, 13 px tertiary); `_MoreButton`.

**_Messages** (`thread`, `known`, `arrivals`, `pane`, `colors`): `_freshFor = 1 s`. Observer on `thread.whispers`: for each whisper whose id is new to `known`, record `arrivals[id] = clock.now()`. LayoutBuilder: `width = pane ? clamp(maxWidth, 0, 768) : maxWidth`; `side = 24 (pane) / 12`; `inner = width - 2*side`. `ListView.builder(reverse: true` (newest at the bottom, anchored), padding LTRB(side, 16/12, side, 12/10), itemCount count + 1, `findChildIndexCallback` maps a `ValueKey<String>` id to its reversed index (keeps state when items are inserted)). Item `i == count` (top of the list) = the session note `Padding(LTRB 24,4,24, 22 pane / 18)` centered `l.whisperSessionNote` (12 px height 1.5 tertiary). Others: `index = count - 1 - i`; neighbours older/newer; `fresh` = the whisper had an arrival time (removed when read) less than 1 s old; `_Bubble(whisper, first: older == null || older.mine != mine, last: newer == null || newer.mine != mine, spaced: older != null && older.mine != mine, maxWidth: inner * 0.75, fresh)`. Each item wrapped in `KeyedSubtree(ValueKey(id or '' for the note))` > `_Centered(enabled: pane, maxWidth 720)`.

**_Bubble**: if `fresh` and not reduce motion, an entrance `AnimationController(280 ms)..forward()` with `CurvedAnimation(OnsetMotion.standard)` driving `SizeTransition(axisAlignment -1)` + `FadeTransition` (the row opens instead of jumping). Radii: round 18, tight 6; mine: TL 18, TR first ? 18 : 6, BR last ? 18 : 6, BL 18; theirs: TL first ? 18 : 6, TR 18, BR 18, BL last ? 18 : 6. `Padding(top: spaced ? 11 : 1, bottom 1)` > Align(mine right / theirs left) > ConstrainedBox(maxWidth) > Container(padding LTRB 12,8,12,6, fill mineFill / theirFill, radius) > Column(end, min, spacing 2): `SelectableText(text, 15 px height 1.4, mineText / theirText)` and time `whisperTime(sentAt)` (tabular 11 px, mineTime / theirTime).

**_Composer** (`controller`, `name`, `sending`, `pane`, `colors`, `onSend`): Row(end, spacing 8): Expanded Container(minHeight 44, padding h16, centerLeft, field colour, radius 22, fieldRing hairline) > `TextField(minLines 1, maxLines 4, maxLength 10000 with the counter hidden (buildCounter returns null), textInputAction send, onSubmitted -> onSend, cursor accent, 15 px height 1.35 text, hint l.whisperHint(name) 15 px tertiary, collapsed, no border, vertical content padding 11)`; `ValueListenableBuilder(controller)` -> `_SendButton(ready: trimmed text non-empty, sending)`. Padding pane LTRB(20,10,20,18) centred max 760; phone LTRB(12,8,12,14) inside `DecoratedBox(top hairline)` > `SafeArea(top: false)`.

**_SendButton**: `lit = ready || sending`; fill accent when lit else raised; ink = `onFillColor(accent)` when lit else tertiary. `PressScale(enabled: ready && !sending)` > `AnimatedContainer(duration motionDuration(200 ms), curve standard, 44 x 44 circle)` > `IconButton(tooltip l.whisperSend, onPressed only when ready and not sending, no splash, icon: sending ? 18 x 18 CircularProgressIndicator(strokeWidth 2, ink, background ink at alpha 0.25) : StateGlyph(send, ink, 19))`.

PC equivalent: Enter sends, Shift+Enter inserts a newline (mobile uses the IME send action); bubbles with selectable text (mouse selection + Ctrl+C); the reversed list with arrival animation (280 ms) kept; session note kept. Tested by `test/screens/whispers/whispers_screen_test.dart`. `test/services/notifications/mention_alerts_test.dart` (around line 157) pins `WhisperConversation.routeName` in the same mention-closing rule.

