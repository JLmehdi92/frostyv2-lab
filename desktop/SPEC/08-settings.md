# 08 — Settings, profile and account

> Cross-spec decisions in [00-index.md](00-index.md) (section "Decisions") override any conflicting PC suggestion in this file.

Leaf of the ONSET memoir. Source of truth: `lib/screens/settings/**` and `test/screens/settings/**` of the Flutter app (repo `frostyv2-lab`). Everything below must survive the native Rust/Slint rewrite for Windows (macOS/Linux later). Generated `.g.dart` files (`auth_store.g.dart`, `settings_store.g.dart`, `twitch_tv_session_store.g.dart`, `user_store.g.dart`) are MobX/json_serializable output of the stores described here; their behaviour (observable getters/setters, action wrappers, JSON field names and enum maps) is captured in the store sections and the Settings table.

## Purpose

The settings area is where the viewer controls everything ONSET does that is not a one-off action: the look of the app (language, theme, accent), what browsing shows (start tab, stream language, hidden content labels, clip discovery, viewer counts, "not interested" channels), the low-latency player (engine, auto latency, live catch-up, buffer profile, the twitch.tv web token that unlocks 1440p/AV1), playback (video on/off, quality, rendering, wakelock, background audio, PiP), the player overlay (including the latency readout that ONSET's whole mission depends on), VOD autoplay and previews, captions, every chat preference (sizing, appearance, delay sync, layout, alerts, bubbles, channel-points intro, autocomplete, landscape, chat-mode cycle, AutoMod filters, muted keywords, emote/badge providers 7TV/BTTV/FFZ, recent messages), notifications (go-live, mentions, Twitch's own categories), updates and release notes, storage (image cache, reset), privacy (crash/analytics consent), and "about" links/licences.

It is also the account hub: the Profile tab (phone) shows who is logged in, their channel, blocked users, "My clips", Twitch-only account pages and Log out; logged out it shows the login card (OAuth WebView login; long-press logs in with a copied token). Settings › Account adds edit-profile (display name, username with availability check, bio, social links, avatar/banner upload through Twitch's web GQL), gifted-sub preferences, whisper privacy, the device-code "twitch.tv session", and all twitch.tv account pages. The stores here (`AuthStore`, `UserStore`, `SettingsStore`, `TwitchTvSessionStore`) are global: the whole app reads the token, headers, user and every preference from them. No feature may be lost in the PC port.

## Screens and layouts

Entry points:
- **Profile tab** of the navigation shell (`ProfileTab`). Phone: a scrolling list of cards — profile header (avatar 76 with ring, name 26/800, @login, "Joined …", buttons "My channel" + "Settings"), the "ACCOUNT" group (Blocked users with count, My clips, Security and Connections on twitch.tv), the "SETTINGS" group (General, Video, Chat, Notifications, Other — each with icon tile, bold title and live summary), a lone red "Log out" card, and "ONSET vX.Y.Z (build)". Logged out: the login card (Anonymous, pitch, primary "Connect with Twitch", disclaimer, token tip) instead of header/account/log-out. Twitch unreachable: an error card with "Reconnect". Tablet: the Profile tab IS the master-detail settings.
- **Settings page** (`Settings.open`, route `Settings`): pushed from Profile's "Settings" button and the chat menu. Phone: `SettingsScaffold` (56 dp near-opaque header with back chevron and title) over `SettingsHome` = account card (avatar or anonymous/error disc), "CUSTOMIZE" group (General, Video, Chat, Notifications), then the Other page's groups inline (Updates, Storage, Privacy, About) and the version footer. Tablet: master-detail.
- **Section pages** (pushed on a phone with route `Settings/<id>`; shown in the pane on a tablet): General (Language · Theme · Stream card · Browse · Links), Video (Low-latency player [Android] · Playback · Overlay · Videos and content · Captions [Android]), Chat (Message sizing with preview · Message appearance · Account sync · Delay and latency · Layout · Alerts · Channel Points · Autocomplete · Landscape · Chat switching · Filters · Emotes and badges · Recent messages), Notifications (Channels you follow · Chat · Twitch notification settings), Other (Updates · Storage · Privacy · About).
- **Sub pages**: Edit chat filters (under Chat), Not interested (under General), Edit profile, Account, Blocked users. On a tablet sub pages slide over their section with a "‹ Section" back button; Account and Blocked are side-column entries.
- **Sheets/dialogs**: language/stream-language/labels/bubbles/muted keywords use `showSettingsSheet` (bottom sheet ≤ 82 % height on a phone, 460×640 dialog on a tablet); accent picker (sheet without drag / 460 dialog); confirmation dialogs (`SettingsDialog`, 360 / 420 wide); web-token dialog; edit-profile dialogs (text, username, link); block dialog with reason pills; twitch.tv connect sheet (code card); update prompt; release notes page (phone card + expandable earlier versions; tablet version list + detail).
- **Release notes**: from Other › Updates or by itself after an update to a new major.minor ("Updated to x.y.z", "You were on …", "Got it").

Common row anatomy (`SettingsRow`): optional 32 dp icon tile (radius 10), title 15/500 (600 for section rows), optional detail line 12.5/1.45 secondary, optional right value (≤ 46 % width, 2 lines), trailing widget, end glyph (chevron or external), min height 56, padding 16/10/14/10, 0.42 opacity when disabled. Groups: uppercase 11/600 label (letter-spacing 1.54) above a #141414 card (radius 16, 0.5 dp white-8 % ring) with hairline dividers; groups 22 dp apart.

## Behaviour and state

- **Single store per concern.** `SettingsStore` (≈123 persisted fields) is loaded once at launch from SharedPreferences key `settings` (JSON), migrated (chat sync default, telemetry consent, deleted-messages key, legacy start tab, portrait height), observed everywhere through MobX, saved debounced 300 ms (immediately for consent/language, and when the app is hidden/paused). Every control writes the store directly; there is no "Save" button anywhere in settings.
- **Resets.** Other › Reset settings (confirmation, heavy haptic) runs `resetAllSettings` = general + video + chat + other + global configs; the app language, its prompt version, link confirmation, whisper lists, not-interested channels, seen NEW pills and counters are kept.
- **Dependent controls.** Auto latency / Live catch-up / Buffer profile / Web token only with the IVS engine on Android; "Only with headphones" only when Background audio is on; "Mute previews" only when previews are on; "Celebrations on video" only when celebrations are on; "Alerts over landscape video" only when on and Full; the manual message-delay slider only when "Sync chat delay" is off; readable name colours locked on while contrast is increased; chat filter categories disabled while the master is off; chat-switching switches disabled when only two modes remain; whisper switch disabled under a parental lock; gift/whisper switches disabled while saving; go-live/mention switches disabled when logged out (go-live also off-Android).
- **NEW pills.** Rows for clip discovery, hide viewer count, not interested, stream previews, data saver and landscape alerts show a NEW pill until interacted with (ids stored in `seenNewFeatures`).
- **Account state.** `hasAccount = error == null && isLoggedIn && details != null`. Account pages need it; on a tablet an account page without an account shows General. The account card / login card / error card switch live. Log out always confirms (danger dialog); on a phone the Account page pops after logging out.
- **Auth lifecycle** (full detail in the auth_store section): launch validates the stored user token (`/oauth2/validate`), accepts tokens of other client ids with a one-time notice, logs out with "session ended" notice on 401, starts a 10 s reconnect loop (max 5) on network errors, and otherwise runs logged out with an app token from the token proxy (`GET <TOKEN_PROXY_URL>/app-token`), retried at most once a minute after a logged-out Helix 401. Interactive login = OAuth implicit grant in a WebView with a 32-byte `state`, strict redirect matching, single-use state, multiple concurrent login pages, `force_verify=true`. Logins and logouts are serialised; the newest login wins; a logout overtakes any login in flight. Logout revokes the token (5 s timeout, best effort), clears all WebView cookies, the web token, the user id, runs session-end listeners (e.g. the twitch.tv session store's `endAccountSession`), and reinstalls the app token. The twitch.tv `auth-token` cookie is harvested from the login WebView's jar (Android channel `onset/cookies`, or the page's `document.cookie` elsewhere), verified to belong to the logged-in account, kept fresh by a hidden twitch.tv page load at each launch, renewed at most every 5 minutes after a refusal, and flagged expired when it cannot be renewed.
- **No user-token refresh.** The login is an implicit grant: the user token has no refresh token and is never refreshed. It lives until Twitch refuses it; then the next launch's `init` logs out and raises `TokenNotice.sessionEnded` ("log in again"). The reconnect loop, when it finds the token invalid or gives up after 5 attempts, only runs `_endSession()` (plus `Telemetry.log('Auth reconnection exhausted after 5 attempts')` on exhaustion) and raises NO notice — the viewer is silently logged out (see Known Android defects), while a Helix 401 during a session shows the app's login prompt (UnauthorizedInterceptor). Only the twitch.tv device session (below) and the `auth-token` cookie are renewed.
- **Twitch.tv device session** (`TwitchTvSessionStore`): optional second session for actions Twitch only accepts from its own clients; offered once after an interactive login (`TwitchTvLoginOffer`), connectable/disconnectable in Settings › Account, refreshed automatically (30 s retries when offline), revoked on forget/logout.
- **Remote account settings** (gift settings, whisper privacy, chat UI sync, Twitch notification categories, edit profile) load on page open with a 22–24 dp spinner, show a note when unreadable, ask for confirmation before changing anything on the account, show the outcome in a snackbar (`done`, `refused`, `integrityRefused`, `signedOut`, `failed`), and offer Undo after success.
- **Haptics**: selection click on every switch, segment, checkbox, slider step, release-notes version pick and expand; light impact on clear cache, accent "Random", pull-to-refresh of blocked users, twitch.tv connect success; heavy impact on reset settings.

## Animations and motion

All durations collapse to a 150 ms cross-fade (`OnsetMotion.reducedFade`) when reduce motion is on (`MediaQuery.disableAnimations` or the OS accessibility flag) unless noted. Curve `OnsetMotion.standard = Cubic(0.2, 0, 0, 1)` unless noted.
- **Switch** (`SettingsSwitch`): track colour/ring fade 220 ms; knob slides 300 ms (left 3 → 21) — 0 ms under reduce motion; knob colour 220 ms.
- **Segmented select / stacked select**: selected pill tint/ring `AnimatedContainer` 220 ms.
- **Checkbox row**: 22 dp box fill/border 180 ms.
- **Tablet aside row** (`_AsideRow`) and **release version row**: tint (accent 10 %) and ring (accent 45 %) 220 ms.
- **Press feedback** (`PressScale` on aside rows, logout row, jump chips, segment options, release buttons/rows, step buttons): scale to 0.97 in 100 ms (standard curve) on pointer down; release with spring `withDurationAndBounce(400 ms, bounce 0.2)` carrying velocity; cancelled if the pointer moves more than the touch slop; disabled under reduce motion.
- **Tablet pane page switch**: `AnimatedSwitcher` 300 ms, fade in + slide up from 0.8 % of height (Offset(0, 0.008)); old page removed from layout at once; reduce motion = 150 ms fade only.
- **Tablet sub page**: slides in from the right (Offset(1,0)→0) 360 ms with `standard`, out 260 ms with `Cubic(0.4, 0, 1, 1)`; kept drawn while sliding out; reduce motion = 150 ms fades.
- **Jump chips**: `Scrollable.ensureVisible` 360 ms standard (0 ms under reduce motion).
- **Profile phone list**: `StaggeredEntrance` per card — first appearance only: rise 16 px + fade, 40 ms stagger per index (capped at 8), each 350 ms on `emphasizedDecelerate Cubic(0.05, 0.7, 0.1, 1)`.
- **Chat preview**: chevron rotates half a turn 300 ms; body `AnimatedSize` 300 ms (top-anchored).
- **Muted keywords add button**: fill colour 160 ms.
- **Twitch.tv connect sheet**: status `AnimatedSwitcher` 220 ms; code dims to 0.4 opacity in 200 ms when finished.
- **Release notes**: entrance per block rises 6 px, stagger 40 ms (from Settings) or 60 ms (just updated), 350 ms emphasized-decelerate, plays once when the notes arrive; earlier-version rows open/close with a critically damped 300 ms spring continuing from the current value (chevron rotates 0→π, body clipped by height factor, opacity = value/0.8), instant under reduce motion; tablet detail switch 300 ms fade + 0.8 % slide (old detail removed at once).
- **Sheets/dialogs**: Material defaults for the route transitions; dialogs use `insetAnimationDuration: Duration.zero` so they jump to the keyboard's room immediately.
- **Accent picker**: no animation; colour applied live, throttled to one store write per 100 ms.

## Settings

Storage: one JSON object in SharedPreferences under key `settings` (PC: `settings.json`, same keys). "Reset group" says which reset restores it (`general`, `video`, `chat`, `other`, `global configs`; Other › Reset settings runs all five). "Readers" are the source files (basenames, outside the store) that read the value. Two fields are not persisted (`chatOnlyForPage`, `syncedChatDelay`); `chatSyncDefaultApplied` is persisted but not observable. Enum values are persisted by their Dart name.

| Persisted JSON key | Dart field | Type | Default | Allowed values / decoding | UI location | Reset group | Effect | Readers |
|---|---|---|---|---|---|---|---|---|
| `themeType` | `themeType` | enum ThemeType | system | system, light, dark (unknown -> system) | General › Theme (segmented) | general | MaterialApp.themeMode; switches dark/light SettingsColors and theme | main, theme_selection_setting, onboarding_setup |
| `accentColor` | `accentColor` | int (ARGB) | 0xffc8ff3d (electric lime) | any 32-bit ARGB; picker writes opaque colours | General › Theme › Accent color | general | Seeds Material ColorScheme.fromSeed; used by profile header, onboarding, login WebView chrome, clips/VOD screens, notice rows | main, channel_profile, channel, user_notice_row, clips_feed_screen, accent_color_setting, vod_screen, profile_header, onboarding_setup, onboarding_flow, login_webview |
| `showThumbnails` | `showThumbnails` | bool | true | true/false | General › Stream card › Show thumbnail | general | Stream cards and live feed show preview thumbnails | general_settings, live_feed, streams_list, onboarding_flow |
| `largeStreamCard` | `largeStreamCard` | bool | false | true/false | General › Stream card › Large stream card | general | Stream lists use the large card layout | general_settings, streams_list |
| `startTab` | `startTab` | enum HomeTab | following | following, live, clips, browse; legacy 'top'->live, 'search'->browse; unknown -> following | General › Browse › Open the app on | general | Tab the app opens on (Following falls back to Live when logged out) | general_settings, home_store, home |
| `followedSort` | `followedSort` | enum FollowedSort | viewers | viewers, recent, name, category, recommended (unknown -> viewers) | Following tab's sort button (not in Settings) | general | Order of live followed channels | stream_list_store, stream_sort_button |
| `streamLanguage` | `streamLanguage` | String | '' (all) | '', en, fr, es, de, pt, it, ru, ja, ko, zh, ar, tr, pl, nl, sv, other; decode keeps ANY string as-is (no normalisation in the store — readers get the raw code); only the Settings row displays an unknown code as "All languages" via `streamLanguageOrAll` | General › Browse › Stream language | general | Helix `language` for Top, categories, tags, live feed, clips feed | clips_feed_screen, stream_language_setting, live_feed_store, stream_list_store, stream_filter_chips, home |
| `hiddenContentLabels` | `hiddenContentLabels` | List<String> | [] | ids DrugsIntoxication, SexualThemes, ViolentGraphic, Gambling, ProfanityVulgarity, MatureGame, DebatedSocialIssuesAndPolitics | General › Browse › Hide labeled streams | general | Streams with any of these CCL labels left out of browsing (followed always shown) | hidden_content_labels_setting, stream_list_store |
| `confirmExternalLinks` | `confirmExternalLinks` | bool | true | true/false | General › Links › Confirm links | not reset | Ask before opening a link that leaves the app | main, external_browser_setting |
| `launchUrlExternal` | `launchUrlExternal` | bool | false | true/false | General › Links › Open links in external browser | general | externalApplication vs inAppBrowserView for every link | chat, emote_menu_section, chat_bottom_bar, chat_message, pinned_chat_text, channel_top_overlays, other_settings, chat_settings, release_notes_parts, external_browser_setting, vod_chat_replay, vod_chat_message, channel_profile_screen, home, onboarding_setup |
| `mentionNotifications` | `mentionNotifications` | bool | true | true/false | Notifications › Chat › Chat mentions | general | Background/PiP notice when mentioned | chat_store, profile_tab, mention_notification_setting |
| `mutedWhisperUserIds` | `mutedWhisperUserIds` | List<String> | [] | user ids | Whispers (elsewhere) | not reset | Whisper threads muted (no notices) | main |
| `archivedWhisperUserIds` | `archivedWhisperUserIds` | List<String> | [] | user ids | Whispers (elsewhere) | not reset | Whisper threads archived | main |
| `clipDiscovery` | `clipDiscovery` | enum ClipDiscovery | all | all, featured (unknown -> all) | General › Browse › Clip discovery (NEW pill) | general | Clips feed shows all clips or featured only | settings_lookup, general_settings |
| `dataSaver` | `dataSaver` | bool | false | true/false | Video › Videos and content › Data saver (NEW) | video | Lower quality / no autoplay previews on cellular (IVS store, live feed) | ivs_video_store, video_settings, live_feed |
| `followedVideosSeenAt` | `followedVideosSeenAt` | String | '' | ISO timestamp | internal | not reset | Last time new followed videos were seen (badge) | new_followed_videos |
| `pointsIntroSeen` | `pointsIntroSeen` | bool | false | true/false | Chat › Channel Points › Replay intro (sets false) | not reset | Channel points intro sheet shown once | channel_points_sheet, chat_settings |
| `appOpens` | `appOpens` | int | 0 | >= 0 | internal | not reset | Launch counter for the feedback prompt | feedback_prompt |
| `feedbackPromptAtOpen` | `feedbackPromptAtOpen` | int | 0 | >= 0 | internal | not reset | Open count at which the feedback prompt shows | feedback_prompt |
| `feedbackPromptDone` | `feedbackPromptDone` | bool | false | true/false | internal | not reset | Feedback prompt answered | feedback_prompt |
| `seenNewFeatures` | `seenNewFeatures` | List<String> | [] | NewFeature names: dataSaver, streamPreviews, clipDiscovery, hideViewerCount, notInterested, landscapeAlerts, cast, floatingPlayer | implicit (interacting marks seen) | not reset | Hides the NEW pill once seen | isNewFeature()/markFeatureSeen(): general_settings, video_settings, chat_settings, video_overlay (floatingPlayer NEW state), widgets/coach_mark (cast / floatingPlayer coach marks) |
| `hideViewerCount` | `hideViewerCount` | bool | false | true/false | General › Browse › Hide viewer count (NEW) | general | Viewer counts hidden on cards and channel | settings_lookup, general_settings |
| `streamPreviews` | `streamPreviews` | bool | true | true/false | Video › Videos and content › Stream previews (NEW) | video | Live feed plays previews | video_settings, live_feed |
| `mutePreviews` | `mutePreviews` | bool | true | true/false | Video › Videos and content › Mute previews (only when previews on) | video | Previews start muted | video_settings, live_feed |
| `alertsOverLandscapeVideo` | `alertsOverLandscapeVideo` | bool | true | true/false | Chat › Alerts › Alerts over landscape video (only when celebrations on and full; NEW) | video (reset by resetVideoSettings) | When false, celebrations are subtle in landscape | chat_settings |
| `notInterestedChannels` | `notInterestedChannels` | Map<String,String> | {} | userId -> display name | General › Browse › Not interested (page) | not reset | Channels removed from recommendations/live feed | general_settings, not_interested_channels, live_feed_store, recommended_channels |
| `appLanguage` | `appLanguage` | enum AppLanguage | system | system, en, fr (unknown -> system) | General › Language | never reset | MaterialApp.locale; Android 13+ per-app language sync; saved immediately | settings_persistence, locale_bridge, main, language_setting, language_prompt, onboarding_flow |
| `languagePromptVersion` | `languagePromptVersion` | int | 0 when missing — INCLUDING a first launch (main.dart always decodes `prefs.getString('settings') ?? '{}'`); the field initializer 1 is only used by the bare `SettingsStore()` constructor, never at launch | 0 or 1 (kLanguagePromptVersion = 1); becomes 1 only through `chooseLanguage` (onboarding Intro or Home's one-time question) | set by chooseLanguage | never reset | 0 makes Home ask the language once; saved immediately | settings_persistence, home |
| `showVideo` | `savedShowVideo` | bool | true | true/false | Video › Playback › Enable video | video | Video shown on the channel page (chat-only when false); effective `showVideo = savedShowVideo && !chatOnlyForPage` | channel, chat_store, emote_menu_section, chat_details, chat_bottom_bar, native_video_store, ivs_video_store, video_store, video, channel_top_overlays, video_settings |
| `—` | `chatOnlyForPage` | bool (not persisted) | false | true/false | channel page action | — | Temporary chat-only for the current page; cleared by the showVideo setter | channel |
| `warnMatureContent` | `warnMatureContent` | bool | true | true/false | Video › Videos and content › Warn before mature content | video | Content-warning gate before labelled channels/VODs | video_store, content_warning_gate, video_settings, vod_screen, live_feed_store, live_feed |
| `showCaptions` | `showCaptions` | bool | false | true/false | Video › Captions (Android) › Closed captions | video | IVS caption track shown | caption_store, caption_style_setting |
| `captionSize` | `captionSize` | enum CaptionSize | medium | small(13), medium(15), large(19), extraLarge(24) (unknown -> medium) | Video › Captions › Caption size | video | Caption font size | ivs_video, caption_style_setting, vod_video |
| `captionBackground` | `captionBackground` | enum CaptionBackground | black | black, translucent (black 60 %), none (outlined text) (unknown -> black) | Video › Captions › Caption background | video | Caption box style | ivs_video, caption_style_setting, vod_video |
| `captionLanguage` | `captionLanguage` | String | '' | language code or '' (first track) | caption track menu (player) | video | Preferred caption track re-picked when offered | caption_store |
| `portraitVideoScale` | `portraitVideoScale` | double | 1.0 | > 0 (width share) | channel page drag | video | Portrait video width share | channel |
| `portraitChatHeight` | `portraitChatHeight` | enum PortraitChatHeight | low | low, medium, high, custom (missing + portraitVideoScale != 1.0 reads custom; unknown -> low) | Chat › Layout › Portrait chat height (presets only) | video | Portrait chat/video split | channel, chat_settings |
| `defaultToHighestQuality` | `defaultToHighestQuality` | bool | false | true/false | Video › Playback › Default to highest quality (hidden on iPhone) | video | Start at the highest rendition | native_video_store, ivs_video_store, video_store, clip_player_store, video_settings, ivs_vod_store |
| `useTextureRendering` | `useTextureRendering` | bool | true | true/false | Video › Playback › Fast rendering (Android) | video | Texture vs platform-view rendering of the player | video, video_settings |
| `keepScreenAwake` | `keepScreenAwake` | bool | true | true/false | Video › Playback › Keep screen awake | video | Wakelock on channel, clips, VOD, chat tabs | channel, chat_tabs_store, clips_feed_screen, clip_screen, video_settings, vod_screen |
| `backgroundAudio` | `backgroundAudio` | bool | false | true/false | Video › Playback › Background audio (Android) | video | Keep live audio playing in background with media notification | ivs_video_store, video_overlay, video_settings |
| `backgroundAudioHeadphonesOnly` | `backgroundAudioHeadphonesOnly` | bool | false | true/false | Video › Playback › Only with headphones (when background audio on) | video | Background audio only with headphones connected | ivs_video_store, video_settings |
| `autoPictureInPicture` | `autoPictureInPicture` | bool | true | true/false | Video › Playback › Auto picture-in-picture (Android) | video | Enter PiP when leaving the app while playing | ivs_video_store, video_store, video, video_overlay, clip_player_store, clip_screen, video_settings, ivs_vod_store, vod_screen |
| `playerEngine` | `playerEngine` | enum PlayerEngine | ivs | ivs, nativeLowLatency, twitchWeb (unknown -> ivs) | Video › Low-latency player switch (Android): on=ivs, off=twitchWeb | video | Which engine plays live (WebView fallback always available) | channel, video_settings, vod_screen, stream_card_parts |
| `liveCatchUpMode` | `liveCatchUpMode` | enum LiveCatchUpMode | speedUp | speedUp, jumpToLive (unknown -> speedUp) | Video › Low-latency player › Live catch-up (IVS only) | video | How the player returns to the live edge | ivs_player_config, video_settings |
| `bufferProfile` | `bufferProfile` | enum BufferProfile | ultra | standard, ultra (unknown -> standard) | Video › Low-latency player › Buffer profile (IVS only) | video | IVS low-latency buffer targets | ivs_player_config, video_settings |
| `autoLatency` | `autoLatency` | bool | true | true/false | Video › Low-latency player › Auto latency (IVS only) | video | Slight speed-up to stay near live; Ultra falls back to Standard after repeated stalls | ivs_video_store, ivs_player_config, video_settings |
| `vodAutoplay` | `vodAutoplay` | enum VodAutoplay | always | always, wifiOnly, never (unknown -> always) | Video › Videos and content › Video autoplaying (stacked) | video | Next video autoplay at the end of a VOD | video_settings, vod_screen, vod_details_panel, live_feed |
| `showOverlay` | `showOverlay` | bool | true | true/false | Video › Overlay › Custom overlay | video | ONSET overlay over the player (vs engine's own) | channel, video_store, clip_player_store.g, video_settings, web_vod_store.g, ivs_vod_store.g, vod_overlay, vod_details_panel |
| `toggleableOverlay` | `toggleableOverlay` | bool | false | true/false | Video › Overlay › Toggle overlay | video | Tap toggles overlay visibility | video_store, video_settings |
| `showLatency` | `showLatency` | bool | true | true/false | Video › Overlay › Show latency | video | Latency readout in the overlay | channel, video_store, video_overlay, video_settings |
| `badgeScale` | `badgeScale` | double | 1.0 | 0.25–3.0 step 0.25 | Chat › Message sizing › Badge scale | chat | Badge size = 18 × scale | chat, chat_details, chat_bottom_bar, chat_message, pinned_chat_text, chat_settings, vod_chat_replay, vod_chat_message |
| `emoteScale` | `emoteScale` | double | 1.0 | 0.25–3.0 step 0.25 | Chat › Message sizing › Emote scale | chat | Emote size = 28 × scale | chat, chat_details, chat_bottom_bar, chat_message, pinned_chat_text, chat_settings, vod_chat_replay, vod_chat_message |
| `messageScale` | `messageScale` | double | 1.0 | 0.5–2.0 step 0.25 | Chat › Message sizing › Message scale | chat | Linear text scaler for chat | chat, reply_thread, chat_user_modal, chat_settings, vod_chat_replay |
| `messageSpacing` | `messageSpacing` | double | 8.0 | 0–30 step 2 | Chat › Message sizing › Message spacing | chat | Vertical gap between messages (px) | chat_message, chat_settings, vod_chat_replay, vod_chat_message |
| `fontSize` | `fontSize` | double | 12.0 | 5–20 step 1 | Chat › Message sizing › Font size | chat | Chat font size | celebration_view, channel_info, chat, reply_thread, chat_user_modal, user_notice_row, chat_bottom_bar, painted_name, hype_train_banner, captions, chat_settings, release_notes_parts, vod_info_strip, vod_chat_replay, profile_header, category_card, shell_tabs, expandable_section_header, stream_card_parts, large_stream_card, onboarding_parts |
| `revealDeletedMessages` | `showDeletedMessages` | bool | true | true/false (old key showDeletedMessages ignored) | Chat › Message appearance › Show deleted messages | chat | Deleted messages stay readable (struck) | chat, chat_message, chat_settings |
| `animateEmotes` | `animateEmotes` | bool | true | true/false | Chat › Message appearance › Animate emotes (account-synced) | chat | Animated emotes move; else first frame | chat_store, chat, chat_details, chat_bottom_bar, chat_message, pinned_chat_text, chat_settings, vod_chat_replay, vod_chat_message |
| `showGifs` | `showGifs` | bool | true | true/false | Chat › Message appearance › Show GIFs (synced) | chat | GIF keyboard GIFs drawn; else title | chat, chat_details, chat_message, pinned_chat_text, chat_settings, vod_chat_replay, vod_chat_message |
| `animateGifs` | `animateGifs` | bool | true | true/false | Chat › Message appearance › Animated GIFs (synced) | chat | GIFs play; else first frame | chat, chat_details, chat_message, pinned_chat_text, chat_settings, vod_chat_replay, vod_chat_message |
| `showLinkPreviews` | `showLinkPreviews` | bool | true | true/false | Chat › Message appearance › Link previews | chat | Card under clip/video links | chat_message, chat_settings |
| `showModerationNotices` | `showModerationNotices` | bool | true | true/false | Chat › Message appearance › Moderation notices | chat | Line when someone is timed out/banned | chat_store, chat_settings |
| `showChatMessageDividers` | `showChatMessageDividers` | bool | false | true/false | Chat › Message appearance › Message dividers | chat | Hairline between messages | chat_message, chat_settings, vod_chat_replay, vod_chat_message |
| `timestampType` | `timestampType` | enum TimestampType | disabled | disabled, twelve, twentyFour (unknown -> disabled) | Chat › Message appearance › Timestamps | chat | Timestamp before messages | chat, chat_bottom_bar, chat_message, chat_settings, vod_chat_replay, vod_chat_message |
| `readableNameColors` | `readableNameColors` | bool | true | true/false (locked on while increaseChatContrast) | Chat › Message appearance › Readable name colors (synced) | chat | nameColorContrast 4.5 | chat_details, chat_settings |
| `increaseChatContrast` | `increaseChatContrast` | bool | false | true/false | Chat › Message appearance › Increase chat contrast | chat | nameColorContrast 7.0 | chat_details, chat_settings |
| `autoSyncChatDelay` | `autoSyncChatDelay` | bool | true (forced on once by chatSyncDefaultApplied) | true/false | Chat › Delay and latency › Sync chat delay | chat | effectiveChatDelay = syncedChatDelay (measured latency) | channel_info, chat_store, native_video_store, ivs_video_store, video_store, chat_settings |
| `chatDelay` | `chatDelay` | double | 0.0 | 0–30 s step 1 | Chat › Delay and latency › Message delay (when sync off) | chat | Manual chat delay | channel_info, chat_settings |
| `—` | `syncedChatDelay` | double (not persisted) | 0.0 | >= 0 | set by video stores | chat | Measured stream latency used when syncing | native_video_store, ivs_video_store, video_store |
| `chatSyncDefaultApplied` | `chatSyncDefaultApplied` | bool (not observable) | false | true/false | migration flag | not reset | First load sets it and turns autoSync on when chatDelay == 0 | settings_store (fromJson migration) |
| `highlightFirstTimeChatter` | `highlightFirstTimeChatter` | bool | true | true/false | Chat › Alerts › First-time chatters | chat | Highlight first messages | chat_message, chat_settings |
| `showUserNotices` | `showUserNotices` | bool | true | true/false | Chat › Alerts › User notices | chat | Sub/raid/announcement notices in chat (per-channel opt-out via noticesHiddenChannelIds) | chat_settings, channel_preferences_screen |
| `collapseGiftBombs` | `collapseGiftBombs` | bool | true | true/false | Chat › Alerts › Collapse gift bombs | chat | Bomb of >= 5 gifts is one row with recipients inside | chat_store, chat_settings |
| `hideGiftSubNotices` | `hideGiftSubNotices` | bool | false | true/false | Chat › Alerts › Hide gift sub notices | chat | Individual gifted-sub lines hidden | chat_store, chat_settings |
| `hideGiftCount` | `hideGiftCount` | bool | false | true/false | Chat › Alerts › Hide gift count | chat | Gifter's total count hidden | chat_message, chat_settings |
| `chatBubbleEvents` | `chatBubbleEvents` | List<String> | [] | subs, gifts, raids, announcements, other (enum order) | Chat › Alerts › Chat bubbles (sheet) | chat | Notice kinds drawn as compact bubbles | chat_message, chat_bubbles_setting |
| `noticesHiddenChannelIds` | `noticesHiddenChannelIds` | List<String> | [] | channel ids | Channel preferences screen | chat | Notices hidden for those channels | channel_preferences_screen |
| `hiddenChannelIds` | `hiddenChannelIds` | List<String> | [] | channel ids | Channel preferences screen | global configs | Channels hidden from stream lists | channel_preferences_screen, stream_list_store |
| `showHypeTrain` | `showHypeTrain` | bool | true | true/false | Chat › Alerts › Show hype trains | chat | Hype train banner | channel, chat_settings, stream_list_store |
| `showCommunityHighlights` | `showCommunityHighlights` | bool | true | true/false | Chat › Alerts › Community highlights | chat | Pinned/highlight stack over chat | channel, chat_settings |
| `showCelebrations` | `showCelebrations` | bool | true | true/false | Chat › Alerts › Celebrations | chat | Twitch celebration animations | celebration_overlay, channel, chat_settings |
| `celebrationsOnVideo` | `celebrationsOnVideo` | enum CelebrationsOnVideo | full | full, subtle (unknown -> full) | Chat › Alerts › Celebrations on video (when celebrations on) | chat | Over the video vs compact chat line | chat_settings |
| `emoteMenuButtonOnLeft` | `emoteMenuButtonOnLeft` | bool | false | true/false | Chat › Layout › Emote button on left | chat | Emote menu button side in the chat bar | chat, chat_bottom_bar, chat_settings |
| `landscapeChatLeftSide` | `landscapeChatLeftSide` | bool | false | true/false | Chat › Landscape › Chat on left | chat | Landscape chat column side | celebration_overlay, channel, channel_top_overlays, chat_settings, vod_screen |
| `landscapeForceVerticalChat` | `landscapeForceVerticalChat` | bool | false | true/false | Chat › Landscape › Vertical chat | chat | Keep portrait-style chat in landscape | channel, chat, chat_bottom_bar, channel_top_overlays, chat_settings, vod_screen |
| `landscapeCutout` | `landscapeCutout` | enum LandscapeCutoutType | none | none, left, right, both (missing -> none; an UNKNOWN string throws in the generated decoder — no unknownEnumValue — so the PC port must fall back to none) | Chat › Landscape › Notch side | chat | Padding for display cutouts | channel, chat_settings, vod_screen |
| `chatWidth` | `chatWidth` | double | 0.2 | fraction of width | channel page divider drag | chat | Landscape chat column width | channel, chat_bottom_bar, vod_screen |
| `overlayChatTop` | `overlayChatTop` | double | 0.0 | 0–1 | overlay chat drag | chat | Overlay chat top offset fraction | channel |
| `overlayChatHeight` | `overlayChatHeight` | double | 1.0 | 0–1 | overlay chat drag | chat | Overlay chat height fraction | channel |
| `fullScreenChatOverlayOpacity` | `fullScreenChatOverlayOpacity` | double | 0.5 | 0–1 step 0.1 | Chat › Landscape › Overlay opacity | chat | Overlay chat background opacity | channel, chat_settings, vod_screen |
| `tapToCloseOverlayChat` | `tapToCloseOverlayChat` | bool | false | true/false | Chat › Landscape › Tap to close overlay | chat | Tapping the overlay chat closes it | chat, chat_settings |
| `showModActionsInChat` | `showModActionsInChat` | bool | true | true/false | mod tools sheet | chat | Mod action lines in chat | chat_store, mod_tools_sheet |
| `landscapeChatModes` | `landscapeChatModes` | List<LandscapeChatMode> | [overlay, column, hidden] | decode: null/missing -> defaults; otherwise the known names in enum order, even 0 or 1 of them (kept and written back raw; no JsonKey defaultValue); only the computed `switchableLandscapeChatModes` substitutes the defaults when fewer than 2 | Chat › Chat switching (switches, min 2) | chat | Modes the landscape chat button cycles through | via switchableLandscapeChatModes: landscape_chat_cycle, chat_settings |
| `autocomplete` | `autocomplete` | bool | true | true/false | Chat › Autocomplete › Autocomplete bar | chat | Emote/user suggestions bar | chat_store, chat_bottom_bar, chat_settings |
| `showTwitchEmotes` | `showTwitchEmotes` | bool | true | true/false | Chat › Emotes and badges | chat | Twitch emotes rendered/offered | chat_store, emote_menu, chat_bottom_bar, chat_settings, vod_chat_replay_store |
| `showTwitchBadges` | `showTwitchBadges` | bool | true | true/false | Chat › Emotes and badges | chat | Twitch badges | chat_store, chat_settings, vod_chat_replay_store |
| `show7TVEmotes` | `show7TVEmotes` | bool | true | true/false | Chat › Emotes and badges | chat | 7TV emotes | chat_store, emote_menu, chat_bottom_bar, chat_settings, vod_chat_replay_store |
| `showBTTVEmotes` | `showBTTVEmotes` | bool | true | true/false | Chat › Emotes and badges | chat | BTTV emotes | chat_store, emote_menu, chat_bottom_bar, chat_settings, vod_chat_replay_store |
| `showBTTVBadges` | `showBTTVBadges` | bool | true | true/false | Chat › Emotes and badges | chat | BTTV badges | chat_store, chat_settings, vod_chat_replay_store |
| `showFFZEmotes` | `showFFZEmotes` | bool | true | true/false | Chat › Emotes and badges | chat | FFZ emotes | chat_store, emote_menu, chat_bottom_bar, chat_settings, vod_chat_replay_store |
| `showFFZBadges` | `showFFZBadges` | bool | true | true/false | Chat › Emotes and badges | chat | FFZ badges | chat_store, chat_settings, vod_chat_replay_store |
| `show7TVBadges` | `show7TVBadges` | bool | true | true/false | Chat › Emotes and badges | chat | 7TV badges | chat_store, chat_settings |
| `show7TVPaints` | `show7TVPaints` | bool | true | true/false | Chat › Emotes and badges | chat | 7TV name paints | chat_store, chat_settings |
| `show7TVPersonalEmotes` | `show7TVPersonalEmotes` | bool | true | true/false | Chat › Emotes and badges | chat | 7TV personal emotes | chat_store, chat_settings |
| `showBTTVPersonalEmotes` | `showBTTVPersonalEmotes` | bool | true | true/false | Chat › Emotes and badges | chat | BTTV personal emotes | chat_store, chat_settings |
| `showFFZRoomBadges` | `showFFZRoomBadges` | bool | true | true/false | Chat › Emotes and badges | chat | FFZ room (mod/vip) badges | chat_store, chat_settings |
| `showEmoteChangeNotices` | `showEmoteChangeNotices` | bool | true | true/false | Chat › Emotes and badges › Emote change notices | chat | Line when channel emotes are added/removed (7TV) | chat_store, chat_settings |
| `showRecentMessages` | `showRecentMessages` | bool | false | true/false | Chat › Recent messages | chat | Load history from recent-messages.robotty.de | chat_store, chat_settings, onboarding_setup |
| `persistChatTabs` | `persistChatTabs` | bool | true | true/false (off clears secondaryTabs) | Chat › Layout › Persist chat tabs | chat | Secondary chat tabs restored next time | chat_tabs_store, chat_settings |
| `secondaryTabs` | `secondaryTabs` | List<PersistedChatTab> | [] | {channelId, channelLogin, displayName} | chat tabs | chat | Saved secondary chat tabs | chat_tabs_store, chat_settings |
| `mutedWords` | `mutedWords` | List<String> | [] | any strings (duplicates allowed) | Chat › Filters › Muted keywords (sheet) | chat | Messages containing them hidden (chat and VOD replay) | chat_store, settings_muted_words, vod_chat_replay_store |
| `matchWholeWord` | `matchWholeWord` | bool | true | true/false | Chat › Filters › Match whole words | chat | Muted words match whole words only | chat_store, chat_settings, vod_chat_replay_store |
| `chatFiltersEnabled` | `chatFiltersEnabled` | bool | false | true/false | Chat › Filters › Edit chat filters (master) | chat | AutoMod-rated words (>= 3) hidden | chat, chat_filters, chat_details, chat_message, chat_settings, chat_filters_setting |
| `chatFilterDiscrimination` | `chatFilterDiscrimination` | bool | true | true/false | Edit chat filters | chat | Category on | chat_filters, chat_filters_setting |
| `chatFilterSexual` | `chatFilterSexual` | bool | true | true/false | Edit chat filters | chat | Category on | chat_filters, chat_filters_setting |
| `chatFilterHarassment` | `chatFilterHarassment` | bool | true | true/false | Edit chat filters | chat | Category on | chat_filters, chat_filters_setting |
| `chatFilterProfanity` | `chatFilterProfanity` | bool | true | true/false | Edit chat filters | chat | Category on | chat_filters, chat_filters_setting |
| `shareCrashLogsAndAnalytics` | `shareCrashLogsAndAnalytics` | bool | false | true/false | Other › Privacy (and onboarding) | other | Firebase Crashlytics/Analytics/Performance collection (never in debug); saved immediately | settings_persistence, telemetry_consent, other_settings, onboarding_setup |
| `telemetryConsentVersion` | `telemetryConsentVersion` | int | 0 when missing (first launch too), then the load migration sets it to 1 and forces consent off; initializer 1 unused at launch | kTelemetryConsentVersion = 1 | internal | other (set to 1) | Below 1 at load: consent turned off once; saved immediately | settings_persistence, go_live_worker |
| `fullScreen` | `fullScreen` | bool | false | true/false | channel landscape controls | global configs | Landscape full-screen (chat hidden/overlay) | channel, landscape_chat_cycle, chat_bottom_bar, video_overlay, channel_top_overlays, vod_screen |
| `fullScreenChatOverlay` | `fullScreenChatOverlay` | bool | false | true/false | channel landscape controls | global configs | Overlay chat in full screen | channel, chat, video_overlay, channel_top_overlays, vod_overlay, vod_screen |
| `pinnedChannelIds` | `pinnedChannelIds` | List<String> | [] | channel ids | user actions / channel preferences | global configs | Pinned channels first in Following | channel_preferences_screen, channel_profile_screen, stream_list_store, streams_list, user_actions_modal |
| `animatedEmotesCalloutShown` | `animatedEmotesCalloutShown` | bool | false | true/false | internal | not reset | One-time callout about animated emotes | chat_store |
| `hiddenPinnedChatIds` | `hiddenPinnedChatIds` | List<String> | [] | pin ids, max 50 (oldest dropped) | dismissing a pinned chat | global configs | Pinned chat messages hidden | channel |

Settings outside `SettingsStore` but controlled from these pages:
- **Go-live notices** — SharedPreferences keys `go_live_enabled` (bool, default false), `go_live_muted` (string list of channel ids), `go_live_user_id`, `go_live_seen`, `go_live_problem` (only "Twitch refused the login" is kept), `go_live_checked_at`, `go_live_announced`; Notifications › Channels you follow, and the per-channel bell (`GoLiveBellTile`, All / None). Android only; WorkManager every 15 min.
- **Twitch.tv web token** — secure storage `twitch_web_token` (Video › Low-latency player › web token row; also harvested automatically).
- **Twitch.tv device session** — secure storage `twitch_tv_session` (JSON), `twitch_tv_prompted` ('true' once offered).
- **Extra login scopes** — secure storage `extra_login_scopes`.
- **Updater** — SharedPreferences `onset_update_last_check`, `onset_update_postponed_build`, `onset_update_postponed_at` (check every 6 h, postpone 24 h).
- **Remote (Twitch account) settings** shown here: gifted subs (`giftsToFollowedChannelsOnly`, `isGiftCountHidden`), whisper privacy (`isBlockingWhispersFromStrangers`, read-only `isWhisperBanned`, `isWhispersDisabledByParent`), chat UI settings (`isEmoteAnimationsEnabled`, `isGifsEnabled`, `isGifAnimationsEnabled`, `isReadableChatColorsEnabled`, mirrored to the four local settings), notification categories (read-only), profile fields (display name ≤ 25, login 3–25 `^[A-Za-z0-9][A-Za-z0-9_]{2,24}$`, bio ≤ 300, ≤ 5 social links with title ≤ 25 and http(s) URL, avatar/banner PNG/JPG/GIF ≤ 10 MiB).

## Strings

All user-visible text comes from `lib/l10n/app_en.arb` (English, reference) and `lib/l10n/app_fr.arb` (French), read through `context.l10n` (AppLocalizations); names of enum values go through `lib/l10n/enum_labels.dart`. Placeholders use ICU (`{count, plural, …}`, `{status, select, …}`); `l10nMark(0)`/`l10nSpans` splice a styled span (a link, a version) into a translated sentence. Literal, untranslated texts: `'ONSET v<version> (<build>)'`, `'••••••'`, `'auth-token'` (web-token field label), `'https://'` (link URL hint), `'@<login>'`, the stream-language endonyms (English, Français, Español, Deutsch, Português, Italiano, Русский, 日本語, 한국어, 中文, العربية, Türkçe, Polski, Nederlands, Svenska), and `'ONSET'` as licence application name. The PC port must ship both languages with identical keys (e.g. Fluent or a generated Rust table from the ARB files) and the same plural/select behaviour.

Every key used by the files of this leaf, with its English and French text (`\n` = line break):

| Key | English | French |
|---|---|---|
| `accentColorRandom` | Random | Aléatoire |
| `accentColorTitle` | Accent color | Couleur d’accent |
| `appLanguageSystem` | System | Système |
| `authForeignTokenNotice` | This token was created for another app — some features may not work. | Ce jeton a été créé pour une autre application – certaines fonctionnalités risquent d’être indisponibles. |
| `authSessionEndedNotice` | Your Twitch session has ended. Log in again from Settings. | Votre session Twitch a pris fin. Reconnectez-vous depuis les paramètres. |
| `blockReasonHarassment` | Harassment | Harcèlement |
| `blockReasonOther` | Other | Autre |
| `blockReasonSpam` | Spam | Spam |
| `blockReasonTitle` | Reason (optional) | Motif (facultatif) |
| `bufferProfileStandard` | Standard | Standard |
| `bufferProfileUltra` | Ultra | Ultra |
| `captionBackgroundBlack` | Black | Noir |
| `captionBackgroundNone` | None | Aucun |
| `captionBackgroundTranslucent` | Translucent | Translucide |
| `captionSizeExtraLarge` | Extra large | Très grande |
| `captionSizeLarge` | Large | Grande |
| `captionSizeMedium` | Medium | Moyenne |
| `captionSizeSmall` | Small | Petite |
| `celebrationsFull` | Full | Complètes |
| `celebrationsSubtle` | Subtle | Discrètes |
| `chatBubblesAnnouncements` | Announcements | Annonces |
| `chatBubblesCount` | {count, plural, one{{count} type} other{{count} types}} | {count, plural, one{{count} type} other{{count} types}} |
| `chatBubblesDetail` | Draws the chat events you choose as rounded bubbles. | Affiche les événements du chat que vous choisissez dans des bulles arrondies. |
| `chatBubblesGifts` | Gifted subs | Abonnements offerts |
| `chatBubblesOff` | Off | Désactivées |
| `chatBubblesOther` | Other events | Autres événements |
| `chatBubblesRaids` | Raids | Raids |
| `chatBubblesSubs` | Subs | Abonnements |
| `chatBubblesTitle` | Event bubbles | Bulles d’événements |
| `chatFilterDiscrimination` | Discrimination | Discrimination |
| `chatFilterDiscriminationDetail` | Negative language about race, gender, sexual orientation, or similar | Propos négatifs sur l’origine, le genre, l’orientation sexuelle ou d’autres caractéristiques |
| `chatFilterHarassment` | Harassment | Harcèlement |
| `chatFilterHarassmentDetail` | Aggressive or sexually harassing language toward other people | Propos agressifs ou de harcèlement sexuel envers d’autres personnes |
| `chatFilterProfanity` | Profanity | Grossièretés |
| `chatFilterProfanityDetail` | Curse words, expletives, or other obscenities | Jurons, injures ou autres obscénités |
| `chatFilterSexual` | Sexually explicit language | Langage sexuellement explicite |
| `chatFilterSexualDetail` | References to sexual acts, sexual content, and body parts | Allusions à des actes sexuels, à du contenu sexuel ou à des parties du corps |
| `chatFiltersEnable` | Enable filtering in chat | Activer le filtrage du chat |
| `chatFiltersExplanation` | Choose what to filter out of chat in every channel. In channels you moderate, you’ll still see every message. | Choisissez ce que vous souhaitez filtrer dans le chat, sur toutes les chaînes. Sur les chaînes que vous modérez, vous verrez toujours tous les messages. |
| `chatFiltersGroup` | Filters | Filtres |
| `chatFiltersNote` | Twitch’s AutoMod checks the words of each live chat message and hides only the ones it flags, so a message with no flagged words always shows. Hidden words show as stars: tap them to see the message. Chat replays of past broadcasts aren’t filtered. | L’AutoMod de Twitch analyse chaque message du chat en direct et classe certains mots dans une catégorie ; seuls ces mots sont masqués, donc un message sans mot classé s’affiche toujours. Les mots masqués apparaissent sous forme d’étoiles : appuyez dessus pour voir le message. Le chat des anciennes diffusions n’est pas filtré. |
| `chatSyncApplied` | Your Twitch chat settings are now in use. | Vos réglages du chat Twitch sont maintenant appliqués. |
| `chatSyncDiffers` | {count, plural, =1{1 chat setting differs from your Twitch account.} other{{count} chat settings differ from your Twitch account.}} | {count, plural, one{{count} réglage du chat diffère de votre compte Twitch.} other{{count} réglages du chat diffèrent de votre compte Twitch.}} |
| `chatSyncInSync` | Animated emotes, GIFs, and readable colors match your Twitch account. | Les emotes animées, les GIF et les couleurs lisibles correspondent à votre compte Twitch. |
| `chatSyncSave` | Save to my Twitch account | Enregistrer sur mon compte Twitch |
| `chatSyncSaveAction` | Save | Enregistrer |
| `chatSyncSaveConfirmBody` | {count, plural, =1{1 chat setting changes on your Twitch account, not only in ONSET.} other{{count} chat settings change on your Twitch account, not only in ONSET.}} | {count, plural, one{{count} réglage du chat change sur votre compte Twitch, pas seulement dans ONSET.} other{{count} réglages du chat changent sur votre compte Twitch, pas seulement dans ONSET.}} |
| `chatSyncSaveConfirmTitle` | Change your Twitch account? | Modifier votre compte Twitch ? |
| `chatSyncSaveDetail` | Twitch then uses these chat settings on your other devices. | Twitch utilisera alors ces réglages du chat sur vos autres appareils. |
| `chatSyncTitle` | Twitch account | Compte Twitch |
| `chatSyncUnavailable` | Couldn’t load the chat settings of your Twitch account. Log in again, or try again later. | Impossible de charger les réglages du chat de votre compte Twitch. Reconnectez-vous ou réessayez plus tard. |
| `chatSyncUseAccount` | Use my Twitch settings | Utiliser mes réglages Twitch |
| `chatSyncUseAccountDetail` | Takes animated emotes, GIFs, and readable colors from your account. | Reprend les emotes animées, les GIF et les couleurs lisibles de votre compte. |
| `clipDiscoveryAll` | All clips | Tous les clips |
| `clipDiscoveryFeatured` | Featured only | Mis en avant uniquement |
| `commonBack` | Back | Retour |
| `commonCancel` | Cancel | Annuler |
| `commonClose` | Close | Fermer |
| `commonConnectWithTwitch` | Log in with Twitch | Se connecter avec Twitch |
| `commonDone` | Done | Terminé |
| `commonUndo` | Undo | Annuler |
| `commonYes` | Yes | Oui |
| `contentLabelDrugs` | Drugs, intoxication, or excessive tobacco use | Drogues, intoxication ou consommation excessive de tabac |
| `contentLabelGambling` | Gambling | Jeux d’argent |
| `contentLabelMatureGame` | Mature-rated game | Jeu classé pour adultes |
| `contentLabelPolitics` | Politics and sensitive social issues | Politique et questions sociales sensibles |
| `contentLabelProfanity` | Significant profanity or vulgarity | Grossièretés ou vulgarité marquées |
| `contentLabelSexualThemes` | Sexual themes | Thèmes sexuels |
| `contentLabelViolentGraphic` | Violent and graphic depictions | Représentations violentes et explicites |
| `editProfileAbout` | Profile | Profil |
| `editProfileAvatarChange` | Change profile picture | Changer la photo de profil |
| `editProfileBannerChange` | Change banner | Changer la bannière |
| `editProfileBio` | Bio | Bio |
| `editProfileBioEmpty` | No bio yet | Aucune bio pour l’instant |
| `editProfileBioSaved` | Bio updated | Bio modifiée |
| `editProfileContinue` | Continue | Continuer |
| `editProfileDisplayName` | Display name | Nom affiché |
| `editProfileDisplayNameHelp` | Your display name can differ from {login} in capitalization. Some names in non-Latin characters can’t be changed again for 60 days. | Votre nom affiché peut différer de {login} par les majuscules et minuscules. Certains noms en caractères non latins ne peuvent plus être changés pendant 60 jours. |
| `editProfileDisplayNameSaved` | Display name updated | Nom affiché modifié |
| `editProfileFailed` | Couldn’t save this change. | Impossible d’enregistrer cette modification. |
| `editProfileImageHelp` | PNG, JPG, or GIF, up to 10 MB | PNG, JPG ou GIF, 10 Mo au plus |
| `editProfileImageInvalid` | Pick a PNG, JPG, or GIF image of up to 10 MB. | Choisissez une image PNG, JPG ou GIF de 10 Mo au plus. |
| `editProfileImageSaved` | Saved. Twitch may take a minute to show it. | Enregistré. Twitch peut mettre une minute à l’afficher. |
| `editProfileImageUploading` | Uploading… | Envoi… |
| `editProfileIntegrity` | Twitch refused this change from the app. Make it on twitch.tv instead. | Twitch a refusé cette modification depuis l’application. Faites-la plutôt sur twitch.tv. |
| `editProfileLinkAdd` | Add a social link | Ajouter un lien social |
| `editProfileLinkDelete` | Delete | Supprimer |
| `editProfileLinkDeleteBody` | It will no longer show on your channel. | Il ne s’affichera plus sur votre chaîne. |
| `editProfileLinkDeleteTitle` | Delete {title}? | Supprimer {title} ? |
| `editProfileLinkDeleted` | Social link deleted | Lien social supprimé |
| `editProfileLinkEdit` | Edit the social link | Modifier le lien social |
| `editProfileLinkSaved` | Social links updated | Liens sociaux modifiés |
| `editProfileLinkTitle` | Title | Titre |
| `editProfileLinkUrl` | Link | Lien |
| `editProfileLinks` | Social links | Liens vers les réseaux sociaux |
| `editProfileLinksFull` | You have 5 social links, the most Twitch allows. | Vous avez 5 liens sociaux, le maximum autorisé par Twitch. |
| `editProfileLinksUnavailable` | Couldn’t load your social links. | Impossible de charger vos liens sociaux. |
| `editProfileOnTwitch` | Edit on twitch.tv | Modifier sur twitch.tv |
| `editProfileRefused` | {code, select, DISPLAY_NAME_CHANGE_AGAIN{You can’t change your display name again yet.} DISPLAY_NAME_NOT_AVAILABLE{This display name is unavailable.} DISPLAY_NAME_ONLY_CAP{Your display name can only differ from your username in capitalization.} DISPLAY_NAME_TOO_LONG{This display name is too long.} DISPLAY_NAME_TOO_SHORT{This display name is too short.} INVALID_CHARS_IN_DISPLAY_NAME{This display name has characters Twitch doesn’t allow.} DESCRIPTION_FAILED_MODERATION{This bio didn’t pass moderation.} DESCRIPTION_TOO_LONG{This bio is too long.} LOGIN_CHANGE_COOLDOWN{You can’t change your username again yet.} LOGIN_CHANGE_EMAIL_VERIFIED{Verify your email on twitch.tv to change your username.} LOGIN_CONTAINS_INVALID_CHARACTERS{This username has characters Twitch doesn’t allow.} LOGIN_TOO_LONG{This username is too long.} LOGIN_TOO_SHORT{This username is too short.} LOGIN_UNAVAILABLE{This username is unavailable.} FAILED_TITLE_MODERATION{This title didn’t pass moderation.} INVALID_URL{Twitch doesn’t accept this link.} TITLE_TOO_LONG{This title is too long.} TOO_MANY{You already have the most social links Twitch allows.} NOT_FOUND{This social link no longer exists.} REAUTH_NEEDED{Log in again on twitch.tv to make this change.} REQUESTS_THROTTLED{Too many changes. Try again later.} TOO_MANY_REQUESTS{Too many changes. Try again later.} other{Twitch refused this change.}} | {code, select, DISPLAY_NAME_CHANGE_AGAIN{Vous ne pouvez pas encore changer à nouveau votre nom affiché.} DISPLAY_NAME_NOT_AVAILABLE{Ce nom affiché n’est pas disponible.} DISPLAY_NAME_ONLY_CAP{Votre nom affiché ne peut différer de votre nom d’utilisateur que par les majuscules et minuscules.} DISPLAY_NAME_TOO_LONG{Ce nom affiché est trop long.} DISPLAY_NAME_TOO_SHORT{Ce nom affiché est trop court.} INVALID_CHARS_IN_DISPLAY_NAME{Ce nom affiché contient des caractères refusés par Twitch.} DESCRIPTION_FAILED_MODERATION{Cette bio n’a pas passé la modération.} DESCRIPTION_TOO_LONG{Cette bio est trop longue.} LOGIN_CHANGE_COOLDOWN{Vous ne pouvez pas encore changer à nouveau votre nom d’utilisateur.} LOGIN_CHANGE_EMAIL_VERIFIED{Vérifiez votre adresse e-mail sur twitch.tv pour changer de nom d’utilisateur.} LOGIN_CONTAINS_INVALID_CHARACTERS{Ce nom d’utilisateur contient des caractères refusés par Twitch.} LOGIN_TOO_LONG{Ce nom d’utilisateur est trop long.} LOGIN_TOO_SHORT{Ce nom d’utilisateur est trop court.} LOGIN_UNAVAILABLE{Ce nom d’utilisateur n’est pas disponible.} FAILED_TITLE_MODERATION{Ce titre n’a pas passé la modération.} INVALID_URL{Twitch n’accepte pas ce lien.} TITLE_TOO_LONG{Ce titre est trop long.} TOO_MANY{Vous avez déjà le maximum de liens sociaux autorisé par Twitch.} NOT_FOUND{Ce lien social n’existe plus.} REAUTH_NEEDED{Reconnectez-vous sur twitch.tv pour faire cette modification.} REQUESTS_THROTTLED{Trop de modifications. Réessayez plus tard.} TOO_MANY_REQUESTS{Trop de modifications. Réessayez plus tard.} other{Twitch a refusé cette modification.}} |
| `editProfileSave` | Save | Enregistrer |
| `editProfileSignedOut` | Log in again to edit your profile. | Reconnectez-vous pour modifier votre profil. |
| `editProfileTitle` | Edit profile | Modifier le profil |
| `editProfileUnavailable` | Couldn’t load your profile from Twitch. You can still edit it on twitch.tv. | Impossible de charger votre profil depuis Twitch. Vous pouvez toujours le modifier sur twitch.tv. |
| `editProfileUsername` | Username | Nom d’utilisateur |
| `editProfileUsernameAvailable` | This username is available. | Ce nom d’utilisateur est disponible. |
| `editProfileUsernameChange` | Change username | Changer de nom d’utilisateur |
| `editProfileUsernameCheck` | Check availability | Vérifier la disponibilité |
| `editProfileUsernameConfirmBody` | Your channel’s address changes at once, and you can’t change your username again for 60 days. | L’adresse de votre chaîne change aussitôt, et vous ne pourrez plus changer votre nom d’utilisateur pendant 60 jours. |
| `editProfileUsernameConfirmTitle` | Change your username to {login}? | Changer votre nom d’utilisateur en {login} ? |
| `editProfileUsernameHelp` | Your username is your channel’s address. You can change it once every 60 days. | Votre nom d’utilisateur est l’adresse de votre chaîne. Vous pouvez le changer une fois tous les 60 jours. |
| `editProfileUsernameNotUntil` | You changed your username recently. You can change it again on {date}. | Vous avez changé de nom d’utilisateur récemment. Vous pourrez le changer à nouveau le {date}. |
| `editProfileUsernameNotYet` | You changed your username recently. You can’t change it again yet. | Vous avez changé de nom d’utilisateur récemment. Vous ne pouvez pas encore le changer à nouveau. |
| `editProfileUsernameRules` | Use 3 to 25 letters, numbers or underscores, not starting with an underscore. | Utilisez de 3 à 25 lettres, chiffres ou tirets bas, sans commencer par un tiret bas. |
| `editProfileUsernameSaved` | You’re now {login}. | Vous êtes maintenant {login}. |
| `editProfileUsernameTaken` | This username is unavailable. | Ce nom d’utilisateur n’est pas disponible. |
| `editProfileUsernameUnknown` | Couldn’t check this username. Twitch will check it when you change it. | Impossible de vérifier ce nom d’utilisateur. Twitch le vérifiera lors du changement. |
| `followedSortCategory` | Category | Catégorie |
| `followedSortName` | Name (A–Z) | Nom (A-Z) |
| `followedSortRecent` | Recently started | Lancés récemment |
| `followedSortRecommended` | Recommended | Recommandées |
| `followedSortViewers` | Viewers (high to low) | Spectateurs (décroissant) |
| `giftFollowedOnly` | Block gifted subs in channels you don’t follow | Bloquer les abonnements offerts sur les chaînes que vous ne suivez pas |
| `giftFollowedOnlyDetail` | Nobody can gift you a sub in a channel you don’t follow. | Personne ne peut vous offrir d’abonnement sur une chaîne que vous ne suivez pas. |
| `giftHideCount` | Hide your gift count | Masquer le nombre d’abonnements que vous avez offerts |
| `giftHideCountDetail` | Others won’t see how many subs you’ve gifted. | Les autres ne verront pas combien d’abonnements vous avez offerts. |
| `giftSettingsChange` | Change | Modifier |
| `giftSettingsConfirmBody` | It changes on your Twitch account, not only in ONSET. | Il change sur votre compte Twitch, pas seulement dans ONSET. |
| `giftSettingsConfirmTitle` | Change this Twitch setting? | Modifier ce réglage Twitch ? |
| `giftSettingsTitle` | Gifted subs | Abonnements offerts |
| `giftSettingsUnavailable` | Couldn’t load your gifted sub settings. Log in again, or try again later. | Impossible de charger vos réglages d’abonnements offerts. Reconnectez-vous ou réessayez plus tard. |
| `goLiveAndroidOnly` | Android only. | Android uniquement. |
| `goLiveBellAll` | All streams | Tous les lives |
| `goLiveBellFailed` | Couldn’t change the bell. | Impossible de modifier la cloche. |
| `goLiveBellLevelTitle` | Live notifications for {name} | Notifications de live pour {name} |
| `goLiveBellNone` | None | Aucune |
| `goLiveBlocked` | Notifications are blocked for this app. Allow them in the system settings. | Les notifications sont bloquées pour cette application. Autorisez-les dans les paramètres du système. |
| `goLiveLogInAgain` | Log in again to get go-live notifications. | Reconnectez-vous pour recevoir les notifications de live. |
| `goLiveLoggedOut` | Log in to be told when channels you follow go live. | Connectez-vous pour recevoir une notification quand une chaîne que vous suivez lance un live. |
| `goLiveOffDetail` | Be told when channels you follow go live. | Recevez une notification quand une chaîne que vous suivez lance un live. |
| `goLiveOnDetail` | Checked every 90 seconds while ONSET is open or playing, and about every 15 minutes otherwise, when the system allows. Turn a channel’s bell off from its menu. | Vérification toutes les 90 secondes quand ONSET est ouvert ou en lecture, et environ toutes les 15 minutes sinon, si le système le permet. Désactivez la cloche d’une chaîne depuis son menu. |
| `goLiveReadFailed` | Couldn’t read the go-live setting. | Impossible de lire le réglage des notifications de live. |
| `goLiveTitle` | Go-live notifications | Notifications de live |
| `goLiveTurnOffFailed` | Couldn’t turn off go-live notifications. | Impossible de désactiver les notifications de live. |
| `goLiveTurnOnFailed` | Couldn’t turn on go-live notifications. | Impossible d’activer les notifications de live. |
| `languageInTextEnglish` | English | anglais |
| `languageInTextFrench` | French | français |
| `languageNameEnglish` | English | English |
| `languageNameFrench` | Français | Français |
| `liveCatchUpJumpToLive` | Jump to live | Revenir au direct |
| `liveCatchUpSpeedUp` | Speed up | Accélérer |
| `mentionAllow` | Allow | Autoriser |
| `mentionBlocked` | Notifications are blocked for this app. | Les notifications sont bloquées pour cette application. |
| `mentionDetail` | When someone mentions you in a chat you’re watching while ONSET is in the background or in picture-in-picture. | Vous prévient quand quelqu’un vous mentionne dans le chat d’une chaîne que vous regardez, pendant qu’ONSET est en arrière-plan ou en Picture-in-picture. |
| `mentionLoggedOut` | Log in to be told when someone mentions you in chat. | Connectez-vous pour recevoir une notification quand quelqu’un vous mentionne dans le chat. |
| `mentionTitle` | Chat mention notifications | Notifications de mention dans le chat |
| `mutedKeywordsAdd` | Add keyword | Ajouter le mot-clé |
| `mutedKeywordsCount` | {count, plural, =0{None} one{{count} keyword} other{{count} keywords}} | {count, plural, =0{Aucun} one{{count} mot-clé} other{{count} mots-clés}} |
| `mutedKeywordsEmpty` | No muted keywords | Aucun mot-clé masqué |
| `mutedKeywordsHint` | Enter keywords to mute | Mots-clés à masquer |
| `mutedKeywordsRemove` | Remove {word} | Retirer « {word} » |
| `mutedKeywordsRemoved` | Removed “{word}” | Mot-clé « {word} » retiré |
| `mutedKeywordsTitle` | Muted keywords | Mots-clés masqués |
| `myClipsSubtitle` | Your channel’s clips and the ones you made | Les clips de votre chaîne et ceux que vous avez créés |
| `myClipsTitle` | My clips | Mes clips |
| `notInterestedCount` | {count, plural, one{{count} hidden channel} other{{count} hidden channels}} | {count, plural, one{{count} chaîne masquée} other{{count} chaînes masquées}} |
| `notInterestedEmpty` | No hidden channels | Aucune chaîne masquée |
| `notInterestedNote` | Channels you mark “Not interested” in Live stay out of it until you show them again here. | Les chaînes marquées « Ça ne m’intéresse pas » dans l’onglet En direct n’y apparaissent plus tant que vous ne les réaffichez pas ici. |
| `notInterestedRestore` | Show again | Réafficher |
| `notInterestedRestoreName` | Show {name} again | Réafficher {name} |
| `notchSideBoth` | Both | Les deux |
| `notchSideLeft` | Left | Gauche |
| `notchSideNone` | None | Aucun |
| `notchSideRight` | Right | Droite |
| `notificationCategoryChat` | Chat mentions | Mentions dans le chat |
| `notificationCategoryClips` | Clips | Clips |
| `notificationCategoryCreator` | For creators | Pour les créateurs |
| `notificationCategoryDevelopers` | Developer updates | Actualités pour les développeurs |
| `notificationCategoryEvents` | Events | Événements |
| `notificationCategoryFollowers` | New followers | Nouveaux followers |
| `notificationCategoryGifts` | Gifts and rewards | Cadeaux et récompenses |
| `notificationCategoryLive` | Live channels | Chaînes en direct |
| `notificationCategoryMarketing` | News and offers | Actualités et offres |
| `notificationCategoryModeration` | Moderation | Modération |
| `notificationCategoryOther` | Other notifications | Autres notifications |
| `notificationCategoryRecommendedLive` | Recommended live channels | Chaînes en direct recommandées |
| `notificationCategorySocial` | Social activity | Activité sociale |
| `notificationCategorySubscriptions` | Subscriptions | Abonnements |
| `notificationCategoryVideos` | Past broadcasts | Anciennes diffusions |
| `notificationsAllowInSystem` | Allow notifications for this app in the system settings. | Autorisez les notifications de cette application dans les paramètres du système. |
| `onboardingSetupCrashDetail` | Help improve ONSET by sending crash logs and analytics through Firebase. Neither your Twitch account nor your channels are sent. | Aidez-nous à améliorer ONSET en envoyant les rapports de plantage et les statistiques d’utilisation via Firebase. Ni votre compte Twitch ni vos chaînes ne sont transmis. |
| `onboardingSetupCrashTitle` | Share crash logs and analytics | Partager les rapports de plantage et statistiques |
| `onboardingSetupHistoryDetail` | When Twitch’s own chat history is unavailable, fails, or is empty, ONSET loads recent messages from {link}, which then receives the channel name. | Si l’historique du chat de Twitch est indisponible, ne se charge pas ou est vide, ONSET récupère les messages récents depuis {link}, qui reçoit alors le nom de la chaîne. |
| `onboardingSetupHistoryTitle` | Fallback chat history (third-party) | Historique de secours du chat (tiers) |
| `pointsChannelPoints` | Channel points | Points de chaîne |
| `portraitChatHeightCustom` | Custom | Personnalisée |
| `portraitChatHeightHigh` | High | Haute |
| `portraitChatHeightLow` | Low | Basse |
| `portraitChatHeightMedium` | Medium | Moyenne |
| `releaseKindAdded` | {count, plural, one{{count} new} other{{count} new}} | {count, plural, one{{count} nouveauté} other{{count} nouveautés}} |
| `releaseKindFixed` | {count, plural, one{{count} fix} other{{count} fixes}} | {count, plural, one{{count} correction} other{{count} corrections}} |
| `releaseKindImproved` | {count, plural, one{{count} improvement} other{{count} improvements}} | {count, plural, one{{count} amélioration} other{{count} améliorations}} |
| `releaseKindOther` | {count, plural, one{{count} change} other{{count} changes}} | {count, plural, one{{count} modification} other{{count} modifications}} |
| `releaseNotesEarlierVersions` | Earlier versions | Versions précédentes |
| `releaseNotesEmpty` | No release notes yet | Aucune note de version pour l’instant |
| `releaseNotesEmptyDetail` | Changes in each ONSET version appear here and open automatically after an update. | Les nouveautés de chaque version d’ONSET s’affichent ici, et cette page s’ouvre d’elle-même après une mise à jour. |
| `releaseNotesFootnote` | Release notes open automatically after an update. | Les notes de version s’ouvrent d’elles-mêmes après une mise à jour vers une nouvelle version. |
| `releaseNotesGotIt` | Got it | J’ai compris |
| `releaseNotesLatest` | Latest | Dernière |
| `releaseNotesLatestBadge` | LATEST | DERNIÈRE |
| `releaseNotesNewer` | Newer | Plus récente |
| `releaseNotesOlder` | Older | Plus ancienne |
| `releaseNotesOtherVersions` | Other versions | Autres versions |
| `releaseNotesPoints` | {count, plural, one{{count} point} other{{count} points}} | {count, plural, one{{count} point} other{{count} points}} |
| `releaseNotesUpdatedTo` | Updated to {version} | Version {version} installée |
| `releaseNotesVersions` | Versions | Versions |
| `releaseNotesWasOn` | You were on {version} | Vous utilisiez la {version} |
| `releaseNotesWasOnSince` | You were on {version}. Here’s what’s changed since. | Vous utilisiez la {version}. Voici ce qui a changé depuis. |
| `releaseNotesWhatsNew` | WHAT’S NEW | QUOI DE NEUF |
| `releaseNotesWhatsNewIn` | WHAT’S NEW IN {version} | QUOI DE NEUF DANS LA {version} |
| `settingsAbout` | About | À propos |
| `settingsAccentColorChange` | Change accent color | Changer la couleur d’accent |
| `settingsAccentColorLive` | Applies everywhere as you pick | S’applique partout dès que vous la choisissez |
| `settingsAccountCardDetail` | Twitch session, blocked users, twitch.tv, log out | Session Twitch, utilisateurs bloqués, twitch.tv, déconnexion |
| `settingsAlerts` | Alerts | Alertes |
| `settingsAlertsOverLandscapeVideo` | Alerts over the video in landscape | Alertes sur la vidéo en paysage |
| `settingsAlertsOverLandscapeVideoDetail` | When off, landscape shows a line in chat instead, so nothing covers the stream. | Désactivé, le mode paysage affiche une ligne dans le chat à la place, et rien ne couvre le live. |
| `settingsAnimateEmotes` | Animate emotes | Animer les emotes |
| `settingsAnimateEmotesDetail` | When off, shows only the first frame of animated emotes in chat. | Si l’option est désactivée, seule la première image des emotes animées s’affiche dans le chat. |
| `settingsAnimatedGifs` | Animated GIFs | GIF animés |
| `settingsAnimatedGifsDetail` | When off, shows only the first frame of GIFs sent in chat. | Si l’option est désactivée, seule la première image des GIF envoyés dans le chat s’affiche. |
| `settingsAnonymous` | Anonymous | Anonyme |
| `settingsAutoLatency` | Auto latency | Latence automatique |
| `settingsAutoLatencyDetail` | Keeps the stream close to live by playing very slightly faster when it falls behind, without reloading it. If Ultra keeps stalling, the next few streams use Standard. Applies the next time you open a stream. | Garde le live au plus près du direct en le lisant très légèrement plus vite quand il prend du retard, sans le recharger. Si la lecture se bloque trop souvent en « Ultra », les lives suivants passent en « Standard » pendant un moment. S’applique à la prochaine ouverture d’un live. |
| `settingsAutoPip` | Automatic picture-in-picture | Picture-in-picture automatique |
| `settingsAutoPipDetail` | Keeps a playing video in a floating window when you leave the app. | Garde une vidéo en cours de lecture dans une fenêtre flottante quand vous quittez l’application. |
| `settingsAutocomplete` | Autocomplete | Saisie automatique |
| `settingsAutocompleteBar` | Show autocomplete bar | Afficher la barre de saisie automatique |
| `settingsAutocompleteBarDetail` | Shows a bar containing matching emotes and mentions while typing. | Affiche une barre d’emotes et de mentions correspondantes pendant la saisie. |
| `settingsBackgroundAudio` | Background audio | Audio en arrière-plan |
| `settingsBackgroundAudioDetail` | Keeps a live stream playing when you leave the app or turn off the screen, with media controls in a notification. | Poursuit la lecture d’un live quand vous quittez l’application ou éteignez l’écran, avec les commandes de lecture dans une notification. |
| `settingsBackgroundAudioHeadphonesOnly` | Only with headphones | Uniquement avec un casque ou des écouteurs |
| `settingsBackgroundAudioHeadphonesOnlyDetail` | Pauses the live stream when you leave the app with no headphones connected. | Met le live en pause quand vous quittez l’application sans casque ni écouteurs connectés. |
| `settingsBadgeScale` | Badge scale | Échelle des badges |
| `settingsBlock` | Block | Bloquer |
| `settingsBlockMessage` | Are you sure you want to block {name}? This removes them from channel lists, search results, and chat messages. | Voulez-vous vraiment bloquer « {name} » ? Cette personne n’apparaîtra plus dans les listes de chaînes, les résultats de recherche et les messages du chat. |
| `settingsBlockedCount` | {count, plural, one{{count} blocked} other{{count} blocked}} | {count, plural, one{{count} utilisateur bloqué} other{{count} utilisateurs bloqués}} |
| `settingsBlockedNote` | Blocked users are removed from channel lists, search results, and chat messages. Pull down to refresh. | Les utilisateurs bloqués n’apparaissent plus dans les listes de chaînes, les résultats de recherche et les messages du chat. Tirez vers le bas pour actualiser. |
| `settingsBrowse` | Browse | Parcourir |
| `settingsBufferProfile` | Buffer profile | Profil de mémoire tampon |
| `settingsBufferProfileDetail` | Ultra keeps a smaller buffer than Standard for lower latency, but may rebuffer more on weak connections. Applies the next time you open a stream. | « Ultra » garde une mémoire tampon encore plus réduite pour baisser la latence, mais la lecture risque de s’interrompre plus souvent sur une connexion Internet faible. S’applique à la prochaine ouverture d’un live. |
| `settingsCacheCleared` | Image cache cleared | Cache des images vidé |
| `settingsCaptionBackground` | Caption background | Fond des sous-titres |
| `settingsCaptionSample` | This is how captions look. | Voici l’apparence des sous-titres. |
| `settingsCaptionSize` | Caption size | Taille des sous-titres |
| `settingsCaptions` | Captions | Sous-titres |
| `settingsCelebrations` | Show celebrations | Afficher les célébrations |
| `settingsCelebrationsDetail` | Plays an animation over the channel when someone gifts subs. | Lance une animation sur la chaîne quand quelqu’un offre des abonnements. |
| `settingsCelebrationsOnVideo` | Celebrations on video | Célébrations sur la vidéo |
| `settingsCelebrationsOnVideoDetail` | “Full” plays the animation over the video. “Subtle” keeps the video clear and posts a line in chat instead. | « Complètes » : l’animation s’affiche par-dessus la vidéo. « Discrètes » : la vidéo reste dégagée et une ligne l’annonce dans le chat. |
| `settingsChannelsYouFollow` | Channels you follow | Chaînes suivies |
| `settingsChatLeft` | Move chat left | Placer le chat à gauche |
| `settingsChatPreview` | Preview | Aperçu |
| `settingsChatPreviewBadgeEmote` | Badge and emote preview. | Aperçu des badges et des emotes. |
| `settingsChatPreviewSpacing` | And another for spacing without an emote! | Et un autre, sans emote, pour l’espacement ! |
| `settingsChatPreviewText` | Hello! Here’s a text preview. | Bonjour ! Voici un aperçu du texte. |
| `settingsChatSwitching` | Double-tap the video in landscape | Appuyer deux fois sur la vidéo en paysage |
| `settingsChatSwitchingColumn` | Chat beside the video | Chat à côté de la vidéo |
| `settingsChatSwitchingDetail` | Double-tapping the video moves to the next layout turned on here. Keep at least two on. | Un double appui sur la vidéo passe à la disposition suivante parmi celles activées ici. Gardez-en au moins deux. |
| `settingsChatSwitchingHidden` | No chat | Sans chat |
| `settingsChatSwitchingOverlay` | Chat over the video | Chat superposé à la vidéo |
| `settingsCheckConnection` | Check your connection, then try again. | Vérifiez votre connexion Internet, puis réessayez |
| `settingsClearCache` | Clear image cache | Vider le cache des images |
| `settingsClipDiscovery` | Channel clips | Clips des chaînes |
| `settingsClosedCaptions` | Closed captions | Afficher les sous-titres |
| `settingsClosedCaptionsDetail` | Shows captions over live streams and videos that have them. When there are several, pick one in the player menu. | Affiche les sous-titres sur les lives et les vidéos qui en proposent. S’il y a plusieurs pistes, choisissez-en une dans le menu du lecteur. |
| `settingsCollapseGiftBombs` | Collapse gift bombs | Regrouper les abonnements offerts |
| `settingsCollapseGiftBombsDetail` | Folds a gift bomb of five subs or more into its first line; tap “recipients” to see who got one. | Réduit à sa première ligne tout envoi d’au moins cinq abonnements offerts à la communauté ; appuyez sur « destinataires » pour voir qui en a reçu un. |
| `settingsCommunityHighlights` | Show community highlights | Afficher les temps forts de la communauté |
| `settingsCommunityHighlightsDetail` | Shows polls, predictions, pinned messages, gift bombs, and raids above chat. | Affiche les sondages, les prédictions, les messages épinglés, les abonnements offerts à la communauté et les raids au-dessus du chat. |
| `settingsConfirmLinks` | Ask before opening links | Demander avant d’ouvrir un lien |
| `settingsConfirmLinksDetail` | Shows where a link from chat or a channel’s profile leads before opening it. | Indique où mène un lien du chat ou du profil d’une chaîne avant de l’ouvrir. |
| `settingsCustomOverlay` | Use custom video overlay | Utiliser l’interface de lecteur personnalisée |
| `settingsCustomOverlayDetail` | Replaces Twitch’s default web overlay with a mobile-friendly version. | Remplace l’interface web par défaut de Twitch par une version adaptée aux mobiles. |
| `settingsCustomize` | Customize | Personnaliser |
| `settingsDataSaver` | Data saver | Économiseur de données |
| `settingsDataSaverDetail` | On mobile data, live streams start at 480p at most and previews don’t play. You can still pick another quality. | Sur les données mobiles, les lives démarrent en 480p au maximum et les aperçus ne sont pas lus. Vous pouvez toujours choisir une autre qualité. |
| `settingsDelayAndLatency` | Delay and latency | Délai et latence |
| `settingsEmoteButtonLeft` | Move emote menu button left | Placer le bouton des emotes à gauche |
| `settingsEmoteButtonLeftDetail` | Places the emote menu button on the left side to avoid accidental presses. | Place le bouton du menu des emotes à gauche pour éviter les appuis accidentels. |
| `settingsEmoteScale` | Emote scale | Échelle des emotes |
| `settingsEmotesAndBadges` | Emotes and badges | Emotes et badges |
| `settingsEnableVideo` | Enable video | Activer la vidéo |
| `settingsExternalBrowser` | Open links in external browser | Ouvrir les liens dans un navigateur externe |
| `settingsFastRendering` | Use fast video rendering | Utiliser le rendu vidéo rapide |
| `settingsFastRenderingDetail` | Uses a faster WebView rendering method. Turn it off if streams crash while you watch. | Utilise une méthode de rendu WebView plus rapide. Désactivez cette option si l’application plante pendant que vous regardez un live. |
| `settingsFiltersGroup` | Chat filters and muted keywords | Filtres du chat et mots-clés masqués |
| `settingsFiltersOff` | Off | Désactivés |
| `settingsFiltersOn` | On | Activés |
| `settingsFirstTimeChatters` | Highlight first-time chatters | Mettre en avant les premiers messages |
| `settingsFontSize` | Font size | Taille de police |
| `settingsHideGiftCount` | Hide gift totals | Masquer le total des cadeaux |
| `settingsHideGiftCountDetail` | Leaves out how many subs a viewer has gifted in the channel. | N’affiche plus le nombre d’abonnements offerts par un spectateur sur la chaîne. |
| `settingsHideGiftSubNotices` | Hide gift subs | Masquer les abonnements offerts |
| `settingsHideGiftSubNoticesDetail` | Gift subs, community gifts, and sponsored bonus subs no longer show in chat. | Les abonnements offerts, les cadeaux à la communauté et les abonnements bonus des sponsors ne s’affichent plus dans le chat. |
| `settingsHideLabeled` | Hide labeled streams | Masquer les lives selon leur classification |
| `settingsHideLabeledNote` | Streams with these labels are left out of Live, Live channels, categories, and tags. Followed channels always show. | Les lives qui portent ces classifications sont exclus des onglets En direct et Chaînes en direct, des catégories et des tags. Les chaînes suivies s’affichent toujours. |
| `settingsHideLabeledValue` | {count, plural, =0{None} one{{count} label} other{{count} labels}} | {count, plural, =0{Aucune} one{{count} classification} other{{count} classifications}} |
| `settingsHideViewerCount` | Hide viewer counts | Masquer le nombre de spectateurs |
| `settingsHighestQuality` | Default to highest quality | Qualité maximale par défaut |
| `settingsIncreaseChatContrast` | Increase chat contrast | Augmenter le contraste du chat |
| `settingsIncreaseChatContrastDetail` | Gives name colors a stronger contrast with the background. | Renforce le contraste entre les couleurs de pseudo et le fond. |
| `settingsJoined` | Joined {date} | Membre depuis {date} |
| `settingsJumpToGroup` | Jump to a group | Aller à un groupe |
| `settingsKeepAwake` | Keep screen awake | Garder l’écran allumé |
| `settingsKeepAwakeDetail` | Prevents the screen from sleeping while a channel is open. | Empêche la mise en veille de l’écran tant qu’une chaîne est ouverte. |
| `settingsLandscape` | Landscape mode | Mode paysage |
| `settingsLanguageSystemSubtitle` | “System” follows your device’s language (currently {language}). | « Système » suit la langue de votre appareil (actuellement : {language}). |
| `settingsLanguageTitle` | Language | Langue |
| `settingsLargeStreamCard` | Use large stream cards | Utiliser les grandes cartes de live |
| `settingsLayout` | Layout | Disposition |
| `settingsLegalese` | ONSET is free software under the GNU AGPL-3.0-or-later, with NO WARRANTY. Source code: {url} | ONSET est un logiciel libre distribué sous licence GNU AGPL-3.0-or-later, SANS AUCUNE GARANTIE. Code source : {url} |
| `settingsLicenses` | Licenses | Licences |
| `settingsLinkPreviews` | Preview clips and videos | Aperçu des clips et des vidéos |
| `settingsLinkPreviewsDetail` | Shows a card under messages that link to a Twitch clip or video. | Affiche une carte sous les messages qui contiennent un lien vers un clip ou une vidéo Twitch. |
| `settingsLinks` | Links | Liens |
| `settingsLiveCatchUp` | Live catch-up | Rattrapage du direct |
| `settingsLiveCatchUpDetail` | “Speed up” plays slightly faster until the stream is back to live (Auto latency already does this when it’s on). “Jump to live” skips ahead after a stall. Applies the next time you open a stream. | « Accélérer » lit un peu plus vite jusqu’à rattraper le direct (la latence automatique le fait quand elle est activée). « Revenir au direct » rejoint le direct d’un coup après un blocage. S’applique à la prochaine ouverture d’un live. |
| `settingsLogOut` | Log out | Se déconnecter |
| `settingsLogOutMessage` | Are you sure you want to log out? | Voulez-vous vraiment vous déconnecter ? |
| `settingsLogOutTitle` | Log out | Déconnexion |
| `settingsLoginDisclaimer` | ONSET asks only for the permissions it needs, through the official Twitch API. You’ll be able to review them before authorizing. | ONSET ne demande que les autorisations nécessaires, via l’API officielle de Twitch. Vous pourrez les consulter avant de les accorder. |
| `settingsLoginPitch` | Log in to chat, see followed streams, and more. | Connectez-vous pour discuter dans le chat, voir les lives des chaînes que vous suivez, et plus encore. |
| `settingsLowLatencyPlayer` | Low-latency player | Lecteur à faible latence |
| `settingsLowLatencyPlayerDetail` | Plays the stream with the Amazon IVS player, built on the same video technology as Twitch, for low latency. Turn off to use the original Twitch web player. | Lit le live avec le lecteur Amazon IVS, qui repose sur la même technologie vidéo que Twitch, pour une faible latence. Désactivez cette option pour utiliser le lecteur web d’origine de Twitch. |
| `settingsLowLatencyPlayerSwitch` | Low-latency player (Amazon IVS) | Lecteur à faible latence (Amazon IVS) |
| `settingsMessageAppearance` | Message appearance | Apparence des messages |
| `settingsMessageDelay` | Message delay | Délai des messages |
| `settingsMessageDelayDetail` | Adds a delay before each message appears in chat. | Ajoute un délai avant l’affichage de chaque message dans le chat. |
| `settingsMessageDelayDetailIos` | Adds a delay before each message appears in chat. 15 seconds is recommended on iOS. | Ajoute un délai avant l’affichage de chaque message dans le chat. Un délai de 15 secondes est recommandé sur iOS. |
| `settingsMessageDelayValue` | {seconds, plural, one{{seconds} second} other{{seconds} seconds}} | {seconds, plural, one{{seconds} seconde} other{{seconds} secondes}} |
| `settingsMessageDividers` | Show message dividers | Afficher les séparateurs de messages |
| `settingsMessageScale` | Message scale | Échelle des messages |
| `settingsMessageSizing` | Message sizing | Taille des messages |
| `settingsMessageSpacing` | Message spacing | Espacement des messages |
| `settingsModerationNotices` | Show timeouts and bans | Afficher les exclusions temporaires et les bannissements |
| `settingsModerationNoticesDetail` | Adds a line when a moderator times out or bans someone. | Ajoute une ligne quand un modérateur exclut temporairement ou bannit quelqu’un. |
| `settingsMutePreviews` | Start previews muted | Lancer les aperçus sans le son |
| `settingsMyChannel` | My channel | Ma chaîne |
| `settingsNoBlockedUsers` | No blocked users | Aucun utilisateur bloqué |
| `settingsNotchSide` | Fill notch side | Occuper le côté de l’encoche |
| `settingsNotchSideDetail` | Fills the space beside the display notch on devices that have one. | Occupe l’espace disponible autour de l’encoche sur les appareils qui en ont une. |
| `settingsOnTwitch` | On twitch.tv | Sur twitch.tv |
| `settingsOverlay` | Overlay | Interface du lecteur |
| `settingsOverlayOpacity` | Chat overlay opacity | Opacité du chat superposé |
| `settingsOverlayOpacityDetail` | Sets the opacity of the chat overlay in full-screen mode. | Règle l’opacité (la transparence) du chat superposé à la vidéo en plein écran. |
| `settingsOverlayOpacityValue` | {percent}% | {percent} % |
| `settingsPageAccount` | Account | Compte |
| `settingsPageAccountDescription` | Your Twitch account in ONSET | Votre compte Twitch dans ONSET |
| `settingsPageBlocked` | Blocked users | Utilisateurs bloqués |
| `settingsPageBlockedDescription` | People you blocked on Twitch | Les personnes que vous avez bloquées sur Twitch |
| `settingsPageChat` | Chat | Chat |
| `settingsPageChatDescription` | Appearance, delay, alerts, and filters | L’apparence, le délai, les alertes et les filtres du chat |
| `settingsPageChatFilters` | Edit chat filters | Modifier les filtres du chat |
| `settingsPageGeneral` | General | Général |
| `settingsPageGeneralDescription` | Theme, stream cards, browsing, and links | Le thème, les cartes de live, la navigation et les liens |
| `settingsPageNotInterested` | Not interested | Chaînes masquées |
| `settingsPageNotifications` | Notifications | Notifications |
| `settingsPageNotificationsDescription` | Go-live and chat mention notifications | Les notifications de live et de mention dans le chat |
| `settingsPageOther` | Other | Autres |
| `settingsPageOtherDescription` | Updates, storage, privacy, and about | Les mises à jour, le stockage, la confidentialité et la rubrique À propos |
| `settingsPageVideo` | Video | Vidéo |
| `settingsPageVideoDescription` | Low-latency player, playback, overlay, videos, and captions | Le lecteur à faible latence, la lecture, l’interface du lecteur, les vidéos et les sous-titres |
| `settingsPersistTabs` | Persist chat tabs | Conserver les onglets du chat |
| `settingsPersistTabsDetail` | Secondary chat tabs are remembered when switching channels. | Les onglets de chat secondaires sont conservés quand vous changez de chaîne. |
| `settingsPlayback` | Playback | Lecture |
| `settingsPointsIntroReset` | The intro will show again. | La présentation s’affichera de nouveau. |
| `settingsPortraitChatHeight` | Chat height in portrait | Hauteur du chat en portrait |
| `settingsPortraitChatHeightDetail` | You can also drag the bar under the video. | Vous pouvez aussi faire glisser la barre sous la vidéo. |
| `settingsPrivacy` | Privacy | Confidentialité |
| `settingsReadableNameColors` | Readable name colors | Couleurs de pseudo lisibles |
| `settingsReadableNameColorsDetail` | Lightens or darkens name colors that would be hard to read on the background. | Éclaircit ou assombrit les couleurs de pseudo difficiles à lire sur le fond. |
| `settingsReadableNameColorsLocked` | Always on while chat contrast is increased. | Toujours activé tant que le contraste du chat est augmenté. |
| `settingsRecentMessages` | Recent messages | Messages récents |
| `settingsReconnect` | Reconnect | Réessayer |
| `settingsReleaseNotes` | Release notes | Notes de version |
| `settingsReplayPointsIntro` | Show the channel points intro again | Revoir la présentation des points de chaîne |
| `settingsReplayPointsIntroDetail` | It shows the next time you open a channel’s points. | Elle s’affichera la prochaine fois que vous ouvrirez les points d’une chaîne. |
| `settingsReset` | Reset settings | Réinitialiser les paramètres |
| `settingsResetConfirm` | Reset | Réinitialiser |
| `settingsResetDone` | All settings reset | Tous les paramètres ont été réinitialisés |
| `settingsResetMessage` | Are you sure you want to reset all settings? | Voulez-vous vraiment réinitialiser tous les paramètres ? |
| `settingsResetTitle` | Reset all settings | Réinitialiser tous les paramètres |
| `settingsScaleValue` | {scale}× | {scale} × |
| `settingsSectionsSemantics` | Settings sections | Rubriques des paramètres |
| `settingsSendFeedback` | Send feedback | Envoyer un avis |
| `settingsShow7tvBadges` | Show 7TV badges | Afficher les badges 7TV |
| `settingsShow7tvEmotes` | Show 7TV emotes | Afficher les emotes 7TV |
| `settingsShow7tvPaints` | Show 7TV name paints | Afficher les peintures de pseudo 7TV |
| `settingsShow7tvPersonalEmotes` | Show 7TV personal emotes | Afficher les emotes personnelles 7TV |
| `settingsShowBttvBadges` | Show BTTV badges | Afficher les badges BTTV |
| `settingsShowBttvEmotes` | Show BTTV emotes | Afficher les emotes BTTV |
| `settingsShowBttvPersonalEmotes` | Show BTTV personal emotes | Afficher les emotes personnelles BTTV |
| `settingsShowDeleted` | Show deleted messages | Afficher les messages supprimés |
| `settingsShowDeletedDetail` | Shows the original text of deleted messages. | Rétablit le texte d’origine des messages supprimés. |
| `settingsShowEmoteChangeNotices` | Announce emote changes in chat | Annoncer les changements d’emotes dans le chat |
| `settingsShowEmoteChangeNoticesSubtitle` | When the channel adds, removes, or renames a 7TV or BTTV emote. | Quand la chaîne ajoute, retire ou renomme une emote 7TV ou BTTV. |
| `settingsShowFfzBadges` | Show FFZ badges | Afficher les badges FFZ |
| `settingsShowFfzEmotes` | Show FFZ emotes | Afficher les emotes FFZ |
| `settingsShowFfzRoomBadges` | Show the channel’s FFZ moderator and VIP badges | Afficher les badges FFZ de modérateur et de VIP de la chaîne |
| `settingsShowGifs` | Show GIFs in chat | Afficher les GIF dans le chat |
| `settingsShowGifsDetail` | When off, shows the GIF’s title instead. | Si l’option est désactivée, le titre du GIF s’affiche à la place du GIF. |
| `settingsShowHypeTrains` | Show Hype Trains | Afficher les Hype Trains |
| `settingsShowHypeTrainsDetail` | Shows Hype Train progress, levels, and rewards above chat. | Affiche la progression, les niveaux et les récompenses du Hype Train au-dessus du chat. |
| `settingsShowLatency` | Show latency | Afficher la latence |
| `settingsShowLatencyDetail` | Displays the stream latency in the video overlay. With the low-latency player, tap it to show live video stats. | Affiche la latence du live dans l’interface du lecteur. Avec le lecteur à faible latence, appuyez dessus pour afficher les statistiques vidéo en direct. |
| `settingsShowThumbnail` | Show thumbnail | Afficher la miniature |
| `settingsShowTwitchBadges` | Show Twitch badges | Afficher les badges Twitch |
| `settingsShowTwitchEmotes` | Show Twitch emotes | Afficher les emotes Twitch |
| `settingsSourceCode` | Source code | Code source |
| `settingsSpacingValue` | {pixels}px | {pixels} px |
| `settingsStartTab` | Open the app on | Ouvrir l’application sur |
| `settingsStorage` | Storage and reset | Stockage et réinitialisation |
| `settingsStreamCard` | Stream card | Carte de live |
| `settingsStreamLanguage` | Stream language | Langue des lives |
| `settingsStreamPreviews` | Stream previews | Aperçus des lives |
| `settingsStreamPreviewsDetail` | Plays the channel on screen in Live before you open it. | Lit la chaîne affichée dans l’onglet En direct avant que vous ne l’ouvriez. |
| `settingsSummaryChat` | Sizing, alerts, filters, emotes | Taille, alertes, filtres, emotes |
| `settingsSummaryGeneral` | Theme, accent color, browsing, links | Thème, couleur d’accent, navigation, liens |
| `settingsSummaryGoLiveMentions` | {goLive, select, on{Go-live on} other{Go-live off}} · {mentions, select, on{mentions on} other{mentions off}} | {goLive, select, on{Notifications de live activées} other{Notifications de live désactivées}} · {mentions, select, on{mentions activées} other{mentions désactivées}} |
| `settingsSummaryMentions` | {mentions, select, on{Mentions on} other{Mentions off}} | {mentions, select, on{Mentions activées} other{Mentions désactivées}} |
| `settingsSummaryNotifications` | Go-live and chat mentions | Lives et mentions dans le chat |
| `settingsSummaryNotificationsLoggedOut` | Log in to get go-live and mention notifications | Connectez-vous pour recevoir les notifications de live et de mention |
| `settingsSummaryOther` | Updates, storage, privacy, about | Mises à jour, cache, confidentialité, à propos |
| `settingsSummaryVideo` | Low-latency player, captions, overlay | Lecteur à faible latence, sous-titres, interface |
| `settingsSyncDelay` | Sync message delay and stream latency | Synchroniser le délai des messages avec la latence |
| `settingsSyncDelayDetail` | Holds each message for as long as the video is behind live, so chat matches what you see. Your own messages show right away. | Retient chaque message le temps du retard de la vidéo sur le direct, pour que le chat corresponde à ce que vous voyez. Vos propres messages s’affichent immédiatement. |
| `settingsTapToCloseOverlay` | Tap to close chat overlay | Appuyer pour fermer le chat superposé |
| `settingsTapToCloseOverlayDetail` | Tapping an empty part of the chat over the video hides the chat. | Un appui sur une zone vide du chat superposé à la vidéo le masque. |
| `settingsTheme` | Theme | Thème |
| `settingsTimestamps` | Message timestamps | Horodatage des messages |
| `settingsTitle` | Settings | Paramètres |
| `settingsToggleOverlay` | Long-press the player to toggle the overlay | Changer d’interface par un appui prolongé |
| `settingsToggleOverlayDetail` | Lets you switch between Twitch’s overlay and the custom overlay. | Un appui prolongé sur le lecteur fait passer de l’interface de Twitch à l’interface personnalisée, et inversement. |
| `settingsTokenLoginHint` | log in with a copied token | se connecter avec un jeton copié |
| `settingsTokenLoginTip` | Have a token copied? Long-press this card to log in with it. | Vous avez copié un jeton ? Appuyez de manière prolongée sur cette carte pour vous connecter avec ce jeton. |
| `settingsTwitchConnections` | Connections | Connexions |
| `settingsTwitchConnectionsDetail` | Linked accounts — on twitch.tv | Comptes associés – sur twitch.tv |
| `settingsTwitchDeleteAccount` | Disable or delete account | Désactiver ou supprimer le compte |
| `settingsTwitchDeleteAccountDetail` | Close your Twitch account — on twitch.tv | Fermer votre compte Twitch – sur twitch.tv |
| `settingsTwitchDrops` | Drops inventory | Inventaire des drops |
| `settingsTwitchDropsDetail` | Rewards earned by watching — on twitch.tv | Récompenses gagnées en regardant – sur twitch.tv |
| `settingsTwitchFamilyCenter` | Family Center | Espace famille |
| `settingsTwitchFamilyCenterDetail` | Parental supervision tools — on twitch.tv | Outils de supervision parentale – sur twitch.tv |
| `settingsTwitchHelp` | Twitch help and support | Aide et assistance Twitch |
| `settingsTwitchNotifications` | Email and notifications | E-mails et notifications |
| `settingsTwitchNotificationsDetail` | What Twitch emails and notifies you about — on twitch.tv | Ce que Twitch vous envoie par e-mail ou en notification – sur twitch.tv |
| `settingsTwitchPrime` | Prime Gaming | Prime Gaming |
| `settingsTwitchPrimeDetail` | Your free monthly subscription — on twitch.tv | Votre abonnement mensuel gratuit – sur twitch.tv |
| `settingsTwitchProfile` | Edit profile | Modifier le profil |
| `settingsTwitchProfileDetail` | Display name, bio, picture — on twitch.tv | Nom affiché, bio, photo – sur twitch.tv |
| `settingsTwitchRecap` | Year recap | Bilan de l’année |
| `settingsTwitchRecapDetail` | Your year on Twitch — on twitch.tv | Votre année sur Twitch – sur twitch.tv |
| `settingsTwitchSecurity` | Security and privacy | Sécurité et confidentialité |
| `settingsTwitchSecurityDetail` | Password, email, phone, two-factor authentication — on twitch.tv | Mot de passe, e-mail, téléphone, double authentification – sur twitch.tv |
| `settingsTwitchSignup` | Create another account | Créer un autre compte |
| `settingsTwitchSignupDetail` | A new Twitch account — on twitch.tv | Un nouveau compte Twitch – sur twitch.tv |
| `settingsTwitchSubscriptions` | My subscriptions | Mes abonnements |
| `settingsTwitchSubscriptionsDetail` | Manage your subscriptions — on twitch.tv | Gérer vos abonnements – sur twitch.tv |
| `settingsTwitchTurbo` | Twitch Turbo | Twitch Turbo |
| `settingsTwitchTurboDetail` | Ad-free viewing — on twitch.tv | Visionnage sans publicité – sur twitch.tv |
| `settingsUnableToReachTwitch` | Couldn’t connect to Twitch. | Impossible de joindre Twitch |
| `settingsUnblock` | Unblock | Débloquer |
| `settingsUnblockMessage` | Are you sure you want to unblock {name}? | Voulez-vous vraiment débloquer « {name} » ? |
| `settingsUnblockName` | Unblock {name} | Débloquer {name} |
| `settingsUpdates` | Updates | Mises à jour |
| `settingsUpdatesNote` | ONSET looks for a newer build when it starts and when it comes back to the foreground. Release notes open automatically after an update. | ONSET recherche un build plus récent au démarrage et à chaque retour au premier plan. Les notes de version s’ouvrent d’elles-mêmes après une mise à jour vers une nouvelle version. |
| `settingsUserNotices` | Show notices | Afficher les événements |
| `settingsUserNoticesDetail` | Shows notices such as subs, resubs, announcements, and raids. | Affiche les événements comme les abonnements et les réabonnements, les annonces et les raids. |
| `settingsVerticalChat` | Force vertical chat | Forcer le chat vertical |
| `settingsVerticalChatDetail` | Intended for tablets and other larger displays. | Conçu pour les tablettes et les autres grands écrans. |
| `settingsVideosAndContent` | Videos and content | Vidéos et contenu |
| `settingsVodAutoplay` | Autoplay videos | Lecture automatique des vidéos |
| `settingsVodAutoplayDetail` | Choose when videos play automatically. | Choisissez quand les vidéos se lancent automatiquement |
| `settingsWarnMature` | Warn about mature content | Prévenir avant un contenu pour public averti |
| `settingsWarnMatureDetail` | Shows a warning before opening a channel labeled for mature content. | Affiche un avertissement avant une chaîne classée pour un public averti. |
| `settingsWatchingWithoutAccount` | Watching without an account | Visionnage sans compte |
| `settingsWholeWords` | Match whole words | Mots entiers uniquement |
| `settingsWholeWordsDetail` | Matches whole words only, not parts of words. | Ne masque que les mots entiers, pas les parties de mots. |
| `settingsYourAccount` | Your account | Votre compte |
| `settingsYourProfile` | Your profile | Votre profil |
| `shellFeedClips` | Clips | Clips |
| `shellFeedFollowing` | Following | Suivis |
| `shellFeedLive` | Live | En direct |
| `shellSectionBrowse` | Browse | Parcourir |
| `streamLanguageAll` | All languages | Toutes les langues |
| `streamLanguageOther` | Other | Autre |
| `themeDark` | Dark | Sombre |
| `themeLight` | Light | Clair |
| `themeSystem` | System | Système |
| `timestampDisabled` | Disabled | Désactivé |
| `timestampTwelve` | 12-hour | 12 heures |
| `timestampTwentyFour` | 24-hour | 24 heures |
| `twitchNotificationPlatforms` | {push, select, on{Push on} off{Push off} other{No push}} · {email, select, on{email on} off{email off} other{no email}} | {push, select, on{Notifications push activées} off{Notifications push désactivées} other{Pas de notifications push}} · {email, select, on{e-mail activé} off{e-mail désactivé} other{pas d’e-mail}} |
| `twitchNotificationSettingsEdit` | Change them on twitch.tv | Les modifier sur twitch.tv |
| `twitchNotificationSettingsTitle` | Push and email on Twitch | Push et e-mail sur Twitch |
| `twitchNotificationSettingsUnavailable` | Couldn’t load your Twitch notification settings. Log in again, or try again later. | Impossible de charger vos réglages de notifications Twitch. Reconnectez-vous ou réessayez plus tard. |
| `twitchTvConnectAction` | Connect | Connecter |
| `twitchTvConnectBody` | Open the activation page, check that it shows the code below, then approve with the Twitch account you use in ONSET. | Ouvrez la page d’activation, vérifiez qu’elle affiche le code ci-dessous, puis autorisez l’accès avec le compte Twitch que vous utilisez dans ONSET. |
| `twitchTvConnectCodeLabel` | Your code | Votre code |
| `twitchTvConnectCopied` | Code copied. | Code copié. |
| `twitchTvConnectCopy` | Copy code | Copier le code |
| `twitchTvConnectNewCode` | Get a new code | Obtenir un nouveau code |
| `twitchTvConnectOpen` | Open activation page | Ouvrir la page d’activation |
| `twitchTvConnectRequesting` | Getting a code from Twitch… | Obtention d’un code auprès de Twitch… |
| `twitchTvConnectResult` | {status, select, connected{Twitch session connected. Account actions now go through it.} expired{This code expired. Get a new one to try again.} denied{The request was declined on Twitch.} wrongAccount{You approved with another Twitch account. Use the account you’re logged in to in ONSET.} other{Couldn’t reach Twitch. Try again.}} | {status, select, connected{Session Twitch connectée. Les actions sur le compte passent désormais par elle.} expired{Ce code a expiré. Demandez-en un nouveau pour réessayer.} denied{La demande a été refusée sur Twitch.} wrongAccount{Vous avez autorisé un autre compte Twitch. Utilisez le compte connecté à ONSET.} other{Impossible de joindre Twitch. Réessayez.}} |
| `twitchTvConnectTitle` | Connect your Twitch session | Connecter votre session Twitch |
| `twitchTvConnectWaiting` | Waiting for your approval on Twitch… | En attente de votre autorisation sur Twitch… |
| `twitchTvDisconnect` | Disconnect | Déconnecter |
| `twitchTvDisconnectBody` | Follows, point claims, predictions and other account actions may stop working until you connect it again. | Les suivis, la récupération de points, les prédictions et les autres actions sur le compte risquent de ne plus fonctionner tant que vous ne la reconnectez pas. |
| `twitchTvDisconnectTitle` | Disconnect the Twitch session? | Déconnecter la session Twitch ? |
| `twitchTvLoginOfferBody` | With a Twitch session, ONSET can follow, claim points, open chests, and make predictions without going through Twitch’s anti-bot check. It only takes a code from Twitch. | Avec une session Twitch, ONSET peut suivre, récupérer des points, ouvrir des coffres et faire des prédictions sans passer par le contrôle anti-robot de Twitch. Il suffit d’un code fourni par Twitch. |
| `twitchTvSessionDetail` | Follow, claim points and make predictions without Twitch’s anti-bot check. | Suivre, récupérer des points et faire des prédictions sans contrôle anti-robot. |
| `twitchTvSessionState` | {state, select, connected{Connected} expired{Expired} other{Not connected}} | {state, select, connected{Connectée} expired{Expirée} other{Non connectée}} |
| `twitchTvSessionTitle` | Twitch session | Session Twitch |
| `updateAllowMessage` | Android asks you to let ONSET install apps. Turn on “Allow from this source” on the next screen, then come back. | Android vous demande d’autoriser ONSET à installer des applications. Activez « Autoriser cette source » sur l’écran suivant, puis revenez. |
| `updateAllowTitle` | Allow updates | Autoriser les mises à jour |
| `updateAvailable` | Update available | Mise à jour disponible |
| `updateChecked` | Verified with SHA-256 before installing | Empreinte SHA-256 vérifiée avant l’installation |
| `updateCorrupted` | The download was corrupted. Try again. | Le fichier téléchargé est corrompu – réessayez |
| `updateDownloadFailed` | Couldn’t download the update. | Échec du téléchargement |
| `updateDownloading` | Downloading update… | Téléchargement de la mise à jour |
| `updateInstallFailed` | Android couldn’t install the update. | Android n’a pas pu installer la mise à jour |
| `updateInstalledBuild` | Installed: build {build} | Installé : build {build} |
| `updateInstalling` | Installing update… | Installation de la mise à jour |
| `updateLater` | Later | Plus tard |
| `updateNewBuild` | NEW BUILD | NOUVEAU BUILD |
| `updateNotAllowed` | ONSET isn’t allowed to install updates. | ONSET n’est pas autorisé à installer des mises à jour |
| `updateNow` | Update | Mettre à jour |
| `updateOpenSettings` | Open settings | Ouvrir les paramètres |
| `updateProgress` | {received} / {total} MB | {received} / {total} Mo |
| `updateReady` | ONSET build {build} is ready. | Le build {build} d’ONSET est prêt. |
| `updateSize` | {megabytes} MB | {megabytes} Mo |
| `updatesBuild` | Build {build} | Build {build} |
| `updatesCheck` | Check for updates | Rechercher des mises à jour |
| `updatesCheckFailed` | Couldn’t check for updates. | Impossible de rechercher les mises à jour |
| `updatesChecking` | Checking… | Recherche en cours |
| `updatesUpToDate` | You’re up to date | ONSET est à jour |
| `viewerActionResult` | {status, select, done{Done.} refused{Twitch declined this.} integrityRefused{Twitch’s anti-bot check refused this. Connect a Twitch session in Settings › Account, then try again.} signedOut{Log in again to do this from ONSET.} other{Couldn’t reach Twitch. Try again.}} | {status, select, done{C’est fait.} refused{Twitch a refusé.} integrityRefused{Le contrôle anti-robot de Twitch a refusé cette action. Connectez une session Twitch dans Paramètres › Compte, puis réessayez.} signedOut{Reconnectez-vous pour le faire depuis ONSET.} other{Impossible de joindre Twitch. Réessayez.}} |
| `vodAutoplayAlways` | Wi-Fi and mobile data | Données mobiles et Wi-Fi |
| `vodAutoplayNever` | Never | Jamais |
| `vodAutoplayWifiOnly` | Wi-Fi only | Wi-Fi uniquement |
| `webTokenActive` | Active — picked up automatically, 2K requested | Actif – récupéré automatiquement, 2K demandée |
| `webTokenClear` | Clear | Effacer |
| `webTokenExpired` | Twitch session expired — log in again to restore 2K | Session Twitch expirée – reconnectez-vous pour retrouver la 2K |
| `webTokenExplanation` | Some streams offer 2K (1440p HEVC) only to logged-in viewers. ONSET normally picks up this token by itself when you log in and refreshes it on each launch, so you should never need to touch it. Fill it in by hand only if that fails: paste the value of the “auth-token” cookie from twitch.tv in a browser. | Certains lives ne proposent leur qualité 2K (1440p HEVC) qu’aux spectateurs connectés. Ce jeton est normalement récupéré tout seul quand vous vous connectez, puis actualisé à chaque lancement : vous ne devriez jamais avoir à y toucher. Ne le saisissez à la main qu’en cas d’échec : collez la valeur du cookie « auth-token » de twitch.tv, copiée depuis un navigateur. |
| `webTokenFieldHint` | Paste to replace — never shown | Collez pour remplacer – jamais affiché |
| `webTokenIsSet` | A token is set. | Un jeton est défini. |
| `webTokenNewField` | New auth-token | Nouvel auth-token |
| `webTokenNoneSet` | No token set. | Aucun jeton défini. |
| `webTokenNotSet` | Not set | Non défini |
| `webTokenReplace` | Replace | Remplacer |
| `webTokenSave` | Save | Enregistrer |
| `webTokenTitle` | Twitch web token (2K) | Jeton web Twitch (2K) |
| `webTokenUnset` | Not set — log in to pick it up automatically | Non défini – connectez-vous pour le récupérer automatiquement |
| `whisperBlockStrangers` | Block whispers from strangers | Bloquer les chuchotements d’inconnus |
| `whisperBlockStrangersDetail` | Strangers can’t start a conversation with you. Someone you whisper can reply for 48 hours. | Les inconnus ne peuvent pas commencer de conversation avec vous. Une personne à qui vous chuchotez peut vous répondre pendant 48 heures. |
| `whisperPrivacyBanned` | Twitch has restricted whispers on your account. | Twitch a restreint les chuchotements sur votre compte. |
| `whisperPrivacyParent` | A parent turned off whispers through Twitch’s parental tools. | Un parent a désactivé les chuchotements avec les outils de contrôle parental de Twitch. |
| `whisperPrivacyTitle` | Whisper privacy | Confidentialité des chuchotements |
| `whisperPrivacyUnavailable` | Couldn’t load your whisper settings. Log in again, or try again later. | Impossible de charger vos réglages de chuchotements. Reconnectez-vous ou réessayez plus tard. |

## Network and data

Constants: `CLIENT_ID` (`--dart-define`, ONSET's login application, no secret), `TOKEN_PROXY_URL` (`--dart-define`, Cloudflare Worker; must match `^https://[A-Za-z0-9.-]+(:[0-9]+)?(/[A-Za-z0-9._~/-]*)?$`), `kTwitchWebClientId = 'kimne78kx3ncx6brgo4mv6wki5h1ko'` (Twitch web), `kTwitchTvClientId = 'ue6666qo983tsx6so1t0vnawi233wa'` (Twitch TV app), `kTwitchGqlUrl = 'https://gql.twitch.tv/gql'`.

**OAuth (id.twitch.tv)**
- Authorize (implicit grant, in a WebView): `GET https://id.twitch.tv/oauth2/authorize?client_id=<CLIENT_ID>&redirect_uri=https://twitch.tv/login&response_type=token&scope=<scopes>&force_verify=true&state=<base64url(32 random bytes), no padding>`. Redirect captured only when the main frame navigates to exactly `https://twitch.tv:443/login#access_token=…&state=…` (no user-info, path `/login`); state compared in constant time and consumed. After it, Twitch navigates to `https://www.twitch.tv/?no-reload=true` (= WebView signed in; harvest the `auth-token` cookie, then close/continue).
- Scopes: `chat:read chat:edit user:read:follows user:read:blocked_users user:manage:blocked_users user:manage:chat_color moderator:manage:banned_users moderator:manage:chat_messages moderator:manage:chat_settings moderator:manage:warnings moderator:read:followers user:manage:whispers user:read:emotes user:read:chat clips:edit moderator:manage:announcements moderator:manage:shoutouts moderator:manage:shield_mode moderator:manage:automod moderator:manage:blocked_terms moderator:manage:unban_requests moderator:manage:suspicious_users moderator:read:moderators moderator:read:vips user:write:chat` plus, once a broadcaster enables channel tools, any of `channel:manage:moderators channel:manage:vips channel:manage:broadcast channel:edit:commercial channel:manage:raids channel:manage:polls channel:manage:predictions channel:manage:redemptions` (persisted in `extra_login_scopes`).
- Validate: `GET https://id.twitch.tv/oauth2/validate` with `Authorization: Bearer <token>` and NO session Client-Id (checkToken: 401 → invalid; `client_id == CLIENT_ID` → valid; otherwise foreign with that client id and whether a `user_id` exists; network/5xx → throws "indeterminate"). With `Authorization: OAuth <token>` for `tokenUserId` (owner of the twitch.tv cookie) and for the TV session. `getTokenScopes()` reads `scopes` (quiet).
- Revoke: `POST https://id.twitch.tv/oauth2/revoke` form `client_id=<token's app or CLIENT_ID>&token=<t>` (5 s timeout at logout, errors ignored).
- Device flow (TV client): `POST https://id.twitch.tv/oauth2/device` form `client_id=<tv>&scopes=channel_read chat:read user_blocks_edit user_blocks_read user_follows_edit user_read` → `{device_code, user_code, expires_in, interval}`; user opens `https://www.twitch.tv/activate?device-code=<user_code>`; poll `POST https://id.twitch.tv/oauth2/token` form `client_id`, `device_code`, `grant_type=urn:ietf:params:oauth:grant-type:device_code` every `interval`, waiting before each poll including the first (`slow_down`: +5 s and the failure count reset; stop on expired, denied, or 3 consecutive failures); refresh `POST /oauth2/token` form `grant_type=refresh_token&refresh_token=…&client_id=<tv>`.

**Token proxy**: `GET <TOKEN_PROXY_URL>/app-token` (6 s total deadline, redirects not followed, no session headers, never a login prompt) → `{"access_token": "^[A-Za-z0-9]{16,128}$", "client_id": "^[A-Za-z0-9_-]{1,64}$"}`; the token must validate as a user-less app token of exactly that client id (not CLIENT_ID). Stored in secure storage `default_token` + `default_token_client_id`. Logged-out Helix requests use `Authorization: Bearer <app token>` and `Client-Id: <proxy app id>`; no Authorization header at all when there is no token.

**Helix** (`https://api.twitch.tv/helix`, headers `Authorization: Bearer <user token>`, `Client-Id: <token's app or CLIENT_ID>` from `AuthStore.headersTwitch`): `GET /users` (current user; with an explicit token + its client id when a login checks its token), `GET /users/blocks?broadcaster_id=<id>&first=100[&after=]`, `PUT /users/blocks?target_user_id=<id>[&source_context=chat|whisper][&reason=harassment|spam|other]`, `DELETE /users/blocks?target_user_id=<id>`.

**GQL** (`POST https://gql.twitch.tv/gql`, body `{operationName, query, variables}`, headers `Client-ID: kimne78kx3ncx6brgo4mv6wki5h1ko`, `Authorization: OAuth <twitch.tv web token>`; user mutations may be re-signed with the TV session headers `Client-Id: <tv>`, `Authorization: OAuth <tv token>`, `X-Device-Id`, `Client-Session-Id` by `TwitchTvSessionInterceptor`): `ChatUISettingsQuery`; `SyncedSettingsSetEmoteAnimations` / `SyncedSettingsSetGifsEnabled` / `SyncedSettingsSetGifAnimationsEnabled` / `SetReadableChatColorsPreference`; `UserGiftedSubSettingsQuery` / `UserGiftedSubSettingsMutation`; `WhisperSettingsGetterQuery` / `UpdateWhisperSettings`; `UserNotificationSettingsQuery($user)`; `EditableProfile`, `UserLoginRenameStatusQuery`, `SocialLinks`, `IsUsernameAvailableQuery`, `UpdateUserDisplayNameMutation`, `UpdateUserDescriptionMutation`, `ChangeUsernameMutation`, `CreateSocialLink`, `UpdateSocialLink`, `DeleteSocialLink`, `CreateProfileImageUploadURL`, `CreateProfileBannerImageUploadURL` (+ `PUT` of the image bytes to the returned https `uploadURL`). Exact documents are quoted in the file sections. Outcome mapping: GraphQL `errors` containing "integrity" → integrityRefused, other errors → failed, payload `error` object → refused, success predicate false → failed, 401 → signedOut, empty token → signedOut.

**twitch.tv pages in a signed-in WebView** (`TwitchWebPage`): `https://www.twitch.tv` + `/settings/profile`, `/settings/security`, `/settings/notifications`, `/settings/connections`, `/settings/family-center`, `/subscriptions`, `/drops/inventory`, `/turbo`, `/prime`, `/annual-recap`, `/signup`, `/user/delete-account`; `/activate?device-code=…`. Hidden session refresh loads `https://www.twitch.tv/` (navigation restricted to `about:blank` and https `twitch.tv`/`*.twitch.tv`, 20 s timeout, then `about:blank`).

**Other endpoints**: recent messages `https://recent-messages.robotty.de/` (linked from Chat › Recent messages; the API is `https://recent-messages.robotty.de/api/v2`), Twitch help `https://link.twitch.tv/help`, source `https://github.com/JLmehdi92/onset`, feedback `https://github.com/JLmehdi92/onset/issues/new/choose`, chat-preview images `https://static-cdn.jtvnw.net/badges/v1/bbbe0db0-a598-423e-86d0-f9fb98ca1933/3` and `https://static-cdn.jtvnw.net/emoticons/v2/425618/default/dark/3.0`, updater `https://api.github.com/repos/<repo>/releases/latest` and `/releases/assets/<id>` (`Accept: application/vnd.github+json` / `application/octet-stream`, `Authorization: Bearer <build token>` only to api.github.com, SHA-256 verified).

**Local data**: SharedPreferences `settings` (JSON of SettingsStore), go-live keys, updater keys; FlutterSecureStorage keys `default_token`, `default_token_client_id`, `user_token`, `user_token_client_id`, `user_id`, `extra_login_scopes`, `twitch_web_token`, `foreign_token_notice_user`, `twitch_tv_session`, `twitch_tv_prompted` (all secure storage is wiped on first run after install — the main.dart edge case). Image cache `libCachedImageData` (30 days, 10 000 objects). Assets `assets/release-notes.md` and `assets/release-notes.fr.md`.

## Tested behaviour

Shared harness: `test/screens/settings/settings_harness.dart` — `MockTwitchApi`, `MockUserStore`, `testViewer = UserTwitch('7', 'jltomy', 'JLTomy', '', createdAt: 2019-03-14 12:00)`, `FakeAuthStore({loggedIn, error})` with observable login/error, blocked list, mocked logout/init/login; `mockSettingsPlatform()` (empty SharedPreferences, PackageInfo `ONSET 5.0.5 (68)`); `useWindow(size)`; `pumpSettings(tester, child, settings, auth, size = 390×844, mode = dark, reduceMotion)` with English localizations; `tapVisible` scrolls lazily-built lists until the target is visible. Sizes used across tests: phone 390×844, phone landscape 844×390, tablet landscape 1280×854, tablet portrait 854×1280.

- `test/screens/settings/account/block_reason_picker_test.dart` — a reason is picked, tapping it again clears it; French labels.
- `test/screens/settings/account/gift_settings_test.dart` — two switches shown; a change asks first, saves, shows the result and can be undone; a refused change leaves the switch as it was; unreadable settings show the note and no switch.
- `test/screens/settings/account/twitch_tv_connect_sheet_test.dart` — shows the code, copies it, opens the activation page; approval connects; expired code offers a new one; no code says so; closing the sheet stops polling and stores nothing; the settings row shows the state, opens the sheet, and a connected session can be disconnected after confirmation. Plus a readability sweep: for each of `sweepLocales` = [fr, en] × `frenchScreenSizes` = 360x640, 390x844, 1280x854, 854x1280, 844x390 × `frenchTextScales` = [1.0, 1.3], the sheet, its denied state and the settings row "read whole" (`expectFrenchThroughout` from test/helpers/l10n.dart: no clipped/ellipsised/overflowing text, no English leaks in French).
- `test/screens/settings/account/twitch_tv_login_offer_test.dart` — no offer for an account restored at launch; a fresh login is offered once and Connect opens the sheet; Later consumes the one-time prompt; no offer when a valid session exists; re-login after Later not re-offered; logout clears the flag; switching to another account without a session offers again (with a session: no); logout detaches; no navigator → no offer; a reconnect after a logged-out launch is not a login; fast logout+login never stack two offers; logout or another account closes the open offer; Connect does nothing once the store has no account. Plus the same readability sweep (fr/en × the five frenchScreenSizes × text scales 1.0/1.3) of the offer dialog via `expectFrenchThroughout`.
- `test/screens/settings/account/whisper_privacy_settings_test.dart` — asks, saves, undo; refused keeps the switch; unreadable → note, no switch; a parent's lock is said and the switch is disabled.
- `test/screens/settings/caption_style_setting_test.dart` — captions switch then size and background; video reset restores the style; the style survives a restart (JSON round trip).
- `test/screens/settings/chat_bubbles_setting_test.dart` — row value counts the enabled types; the sheet toggles each.
- `test/screens/settings/chat_filters_settings_test.dart` — "Edit chat filters" lives in Chat; master switch then the four categories it enables; chat reset turns filters off.
- `test/screens/settings/chat_settings_celebrations_test.dart` — celebrations play over the video by default, also for old saves; the on-video choice.
- `test/screens/settings/chat_settings_gifs_test.dart` — two switches under animated emotes control chat GIFs.
- `test/screens/settings/chat_settings_gift_bombs_test.dart` — a switch under the notices collapses gift bombs of five or more; community-highlights text mentions gift bombs.
- `test/screens/settings/chat_settings_layout_test.dart` — portrait chat height picks a preset; a dragged (custom) height selects none; the landscape cycle keeps at least two modes on; readable colours locked while contrast is increased; a slider step rebuilds only its own row.
- `test/screens/settings/edit_profile_test.dart` — shows profile and links; display name saved only on Save; Cancel changes nothing; refusal shows the code and keeps the old value; username changes only after the availability check and a confirmation; a taken name cannot continue; no rename before Twitch allows (date shown); link add, and delete after confirmation; unreadable profile points to twitch.tv; unreadable links hide only the links group; avatar upload from ONSET; unusable image uploads nothing with a message; a cancelled pick does nothing.
- `test/screens/settings/language_setting_test.dart` — first group lists System (selected), English, Français; System's line names the device language; on a French device the page is in French; Français applies at once and System returns to the device language; English picked on a French device sticks; a device-language change updates the line even with an explicit choice; phone and tablet layouts; Android 13+ with a per-app language asks the system and names the device; where the system does not answer, Flutter's locales are used.
- `test/screens/settings/lot5_settings_test.dart` — the new settings (data saver, previews, clip discovery, hide viewer count, landscape alerts…) default, survive a restart and reset; landscape alerts off makes celebrations subtle in landscape only; data saver picks the best quality at 480p or less (`1080p60, 720p60, 480p30, 360p30, audio_only` → `480p30`); featured-only keeps featured clips, and shows all when Twitch could not say; hidden viewer count hides the viewer pill; the new switches write their settings.
- `test/screens/settings/not_interested_channels_test.dart` — General opens the list and each channel can be restored; French texts.
- `test/screens/settings/profile_tab_test.dart` — phone: logged in shows viewer, account, sections, log out; log out confirms and Cancel keeps the session; logged out shows the login card and no account; connection problem offers Reconnect; each section opens its page with a way back; light/dark × reduce motion render without errors. Tablet (1280×854): side column + page; jump chips hug their labels and share a row; a sub page opens over its section and back returns; the page survives a phone-size change and back; portrait (854×1280) is one column and nothing overflows; blocked users unblock after confirmation; logged out on an account page shows General; Twitch unreachable hides account rows and shows General; every page renders in both themes with reduce motion.
- `test/screens/settings/release_notes_fr_test.dart` — the French notes translate the English ones version for version, read as French (dates, section kinds), are declared in pubspec and bundled; the translation check passes a faithful translation and catches a missing/reordered version, a section of another kind, a point too many/few, a lost or moved platform tag, a sub-point flattened, a lost date; the parser reads French dates (1er, no-break spaces, decomposed accents), `releaseDay` in both languages, French headings → kinds, a date-looking line that isn't stays a paragraph, section names in any case, summaries count in French; reading by language (French → French; English/none/unknown → English; French falls back to English when missing or empty); the bundled notes by language; whether notes open after an update still reads English.
- `test/screens/settings/release_notes_page_test.dart` — every state (from settings, just updated, empty) fits every size in light and dark; a phone in landscape keeps the phone layout; bundled notes fit; the phone page starts under its header; every button has a screen-reader tap; just updated features the installed version's card; two entries with the same version stay two; tapping the shown version does nothing; a preamble keeps its points and tags; a platform tag hugs its name; unreadable notes show the empty state; just updated without the old version omits "You were on"; Got it and back close the page; earlier versions expand/collapse, open at once under reduce motion, absent with one version; the entrance plays once; reduce motion settles after a short fade; tablet version list + chosen version, short dates never cut, choice survives rotation/resizing, just-updated header shows the old version and Got it; http(s) links open through the app, other schemes are plain text; sections are headings.
- `test/screens/settings/release_notes_test.dart` — parsing into versions/sections/points; no date, wrapped and nested points, bold; `shouldShowReleaseNotes` (never on first launch; after an update with an entry for the new major.minor; not without one; not for the same version or a patch; a same-major.minor entry counts; with or without `v`); bundled notes hold 1.1.0 and 1.0.0 and load through the asset bundle; HTML comment lines skipped; unreadable notes → `read` null / `load` empty, even on a synchronous throw; `parseReleaseEntries` versions/notes/sections/counts, kind by name in any case, one/many counts, nothing → no entries.
- `test/screens/settings/settings_inventory_test.dart` — General: every switch writes its setting; theme, accent, start tab, language, labels. Video (Android): every switch writes its setting; catch-up, buffer and web token follow the IVS engine; headphones-only appears under background audio when on; off Android no Android-only setting. Chat: every switch writes; timestamps, notch, manual delay, sizing; muted keywords added/removed/restored. Notifications logged out: both explain and stay off. Other: reset confirms, cache, privacy, about; no source row without a repository; Licenses opens the licence page with the AGPL notice; source link is ONSET's. Account: twitch.tv pages and log out leaving the page. The phone settings page shows account, sections, Other, version. A settings dialog fits phone and tablet.
- `test/screens/settings/settings_keyboard_test.dart` — on 844×390 (keyboard 200) and 390×844 (keyboard 300) the muted-keywords field and the web-token field stay above the keyboard; the muted-keywords sheet outlives its page across a fold (1280×854 → 390×844).
- `test/screens/settings/settings_semantics_test.dart` — a tablet section opens from its semantics node; Log out and the muted-keywords button answer a screen reader; every settings button has a tap action, page by page.
- `test/screens/settings/stores/auth_store_app_token_test.dart` — launch with the proxy down: logged out, no error, no token, no `Bearer null`; proxy tokens refused when Twitch refuses them, when of the login application (Worker misconfigured), of a user, or of another app than named; a stored token with its app is used without asking the proxy; a stored token without its app is replaced (offline: no error, no token); a refused stored token is replaced or dropped; nothing sent names a client secret; logged-out Helix without a token shows no dialog and asks the proxy again; a revoked app token is dropped and replaced; a 401 the token is not to blame for keeps it; logged in, a Helix 401 still asks to log in; only interactive logins are counted; a proxy token arriving during a login never overwrites it; a login committing while the proxy is asked wins; the token never appears in the store's text; logout with the proxy down or offline still logs out (keeping the stored app token).
- `test/screens/settings/stores/auth_store_client_id_change_test.dart` — after ONSET's application changes, a user token of the old application keeps working (foreign) with its own client id.
- `test/screens/settings/stores/auth_store_foreign_token_test.dart` — a stored token of another app survives launch with a one-time notice; a pasted token of another app logs in with the notice; the login page still refuses another app's token.
- `test/screens/settings/stores/auth_store_interceptor_test.dart` — three tests: (1) after `init` with a stored token of another app, the user is read with that app and `headersTwitch['Client-Id'] == 'other_app'`; (2) from another app's session, `login(token: 'ours')` switches to this app: token 'ours', user '2', `headersTwitch['Client-Id'] == CLIENT_ID`, and the `/helix/users` request carrying `Bearer ours` sends `Client-Id: CLIENT_ID`; (3) pasting a third app's token (`acceptAnyApp`) logs in user '3' with `Client-Id: third_app`.
- `test/screens/settings/stores/auth_store_login_page_test.dart` — the redirect with token and its state logs in and reports the outcome; already logged in, a new login's outcome reflects that token only; no token (user said no) logs nobody in; injected tokens never taken (no state, other state, from a frame, other address, reused state, earlier state of a reopened page, state of a closed page); two login pages at once each take their own; signed in on twitch.tv after its token: told once; without a token: onNotSignedIn then moves on; a closed page forgets its token; channel-tool scopes only once requested; the authorization URL is the implicit grant with every scope, `force_verify`, a fresh state.
- `test/screens/settings/stores/auth_store_logout_test.dart` — logout revokes and forgets the user token; a failing revoke does not stop it; an unreadable user token still clears the twitch.tv session.
- `test/screens/settings/stores/auth_store_scopes_test.dart` — the login asks for `clips:edit` along with the other scopes.
- `test/screens/settings/stores/auth_store_token_app_storage_test.dart` — a login stores the token's app next to the token (and removes it for this app's tokens), consistently on failures.
- `test/screens/settings/stores/auth_store_web_token_test.dart` — `setTwitchWebToken` trims/stores, blank deletes; init restores; failed logins never touch account A's web token or jar; a real switch to B harvests B; logged out a failed login never clears the jar; harvests racing a slow logout store nothing; a jar whose owner can't be told is kept but not stored; signed out nothing is stored; login races (logout wins, newest login wins, stale reconnect ticks ignored, the loop waits for logins); keystore write refusals keep the previous session; switching accounts drops the previous web token; same account keeps it; account id best-effort; reconnect restore keeps it; logout clears token and jar; Android harvest (new cookie stored, same cookie no-op, fresh cookie clears expired); off Android a miss keeps a pasted token, ensure/renew never expire it or load pages; ensure loads twitch.tv once only when the jar is empty and reports failures; renew returns a changed token, flags expiry on same/none, runs at most every 5 minutes, waits during the launch refresh; a logout drops in-flight harvests/refreshes; signed out loads no page; the hidden WebView only navigates within twitch.tv; off Android the login page's cookies give the session but another account's are not kept.
- `test/screens/settings/stores/chat_preferences_settings_test.dart` — name colours readable by default (4.5:1), off keeps colours, increased contrast asks 7:1, chat reset restores; landscape chat modes default all three in cycle order, one can go but two stay, turning off the current one moves to the next, unknown/short saved lists read as all three; portrait height low for new installs, a pre-preset drag is kept as custom, a preset survives restart and video reset; tap-to-close overlay off by default and saved.
- `test/screens/settings/stores/settings_language_test.dart` — settings saved before the language question read the device language and prompt once; a new store starts at the current version; a choice survives relaunch and answers the question; both are saved; unknown saved language reads as system; no reset changes the language or asks again; each language forces its locale, system none.
- `test/screens/settings/stores/settings_store_test.dart` — JSON: old saves keep new defaults; celebrations and gift-bomb collapse round-trip; catch-up/buffer defaults; a buffer profile saved before Ultra became default is kept; consent off until opt-in, consent-version migration (new install at current version and off; an old "on" turned off; a choice at the current version kept; an opt-in after migration survives; reset turns off and keeps version); auto latency default/round-trip; catch-up/buffer round-trip, unknown values fall back to safe ones (speedUp / standard), video reset restores them, names match enums; a saved showLatency kept; empty map → all defaults; non-default round-trip; unknown ThemeType → system, TimestampType → disabled; mentionNotifications/showHypeTrain/showCommunityHighlights on by default (also old saves), round-trip, reset; collapseGiftBombs on for new installs, saved value kept, reset to default; showDeletedMessages on, ignores the old-key false, keeps a new-key false, reset; showModerationNotices; link previews; animated emotes; GIFs; warnMature, hiddenContentLabels, backgroundAudio, autoPictureInPicture, headphones-only defaults/kept/reset groups. Also: stream language is every language ('') by default and for older settings, round-trips, and `resetGeneralSettings` returns to ''; reset isolation (general does not touch video settings, video does not touch chat); the chat-sync-default migration (`fromJson({})` → `autoSyncChatDelay` true and `chatSyncDefaultApplied` true; turned on once when `chatDelay == 0`; a manual delay is kept; turning it off after the migration sticks); `effectiveChatDelay` follows sync vs manual; enum value lists and persisted names; chat-only-for-one-page (`chatOnlyForPage` hides the video without touching the saved `showVideo`, is not serialised, and the `showVideo` setter clears it).
- `test/screens/settings/stores/twitch_tv_session_store_test.dart` — attach adopts the same account's stored session, deletes+revokes another account's, forgets+revokes a token Twitch says is someone else's, keeps it when Twitch is unreachable, refreshes an invalid token or marks expired; credentials only for the live viewer; detach drops memory not disk; refresh rejection → expired, rejection of an older token ignored; device flow: slow_down resets failures, unknown checks retried, stops on expiry/denial/3 failures, refuses+revokes another account's approval, a grant after cancel is revoked and not stored; forget deletes+revokes; switching account drops the previous session; a failing delete at logout never brings the session back.
- `test/screens/settings/vod_autoplay_setting_test.dart` — Video Autoplaying offers Twitch's three options, one per line.
- `test/screens/settings/widgets/chat_account_sync_test.dart` — matching settings say so and offer nothing; use-account applies with undo; save asks first and sends only changes; a refusal stops the save and says so; an unreadable account hides the sync rows (note).
- `test/screens/settings/widgets/go_live_setting_test.dart` — says how often channels are checked; turning on asks for the permission then starts; explains before asking without the permission; refusal says where to allow; a failed schedule leaves it off; blocked notices and a paused check are shown; logged out or non-Android cannot be turned on; the channel bell.
- `test/screens/settings/widgets/hidden_content_labels_setting_test.dart` — picks labels; several are counted.
- `test/screens/settings/widgets/mention_notification_setting_test.dart` — on by default with its explanation; off then on asks for the permission; explains before asking; refusal says where; blocked notifications offer Allow; logged out: off with why.
- `test/screens/settings/widgets/settings_list_select_test.dart` — subtitle under the options; reports the value, not its label; two options with the same label stay two; tapping the selected option reports nothing.
- `test/screens/settings/widgets/settings_twitch_web_token_test.dart` — a stored token is never shown; the input is obscured; replace stores trimmed; empty field cannot replace; clear forgets; the tile says whether one is set; an expired session asks for a new login.
- `test/screens/settings/widgets/stream_language_setting_test.dart` — shows and picks a language; an unknown saved code reads as all languages.
- `test/screens/settings/widgets/update_check_tile_test.dart` — shows the installed build; hidden when updates are off or without an updater; says up to date; says when GitHub cannot be read; a throwing check says so and can be retried; offers a newer build.

## Wide and tablet layout

- Breakpoint: large screen when `MediaQuery.size.shortestSide >= 600` (or a `LargeScreenScope` override). Both the Profile tab and the pushed Settings page then render `SettingsMasterDetail`; the selection (`SettingsSelection`) lives in the owning state so rotation, folding, or a window crossing 600 dp keeps the chosen page (and the phone layout comes back on the same state).
- Master-detail geometry: usable width `w = maxWidth − horizontal insets − 56`; aside 330 dp when `w ≥ 1000`, else 280; pane `= w − aside − 32.5`; outer padding 28 (+insets) left/right, 12 (+top inset) top; 16 dp gap, 0.5 dp hairline (ending 28 above the bottom), 16 dp gap. The pane shows its groups in two balanced columns (20 dp apart) when the pane is ≥ 640 dp and the page has ≥ 2 groups; otherwise one column. Pane header: uppercase "SETTINGS" eyebrow, 30/800 title, description line; jump chips (36 dp pills) when more than two groups are titled.
- Aside: profile card (avatar 60, name 20/800, account line, "My channel" button) or the login card; "SETTINGS" label and five section rows (48 dp, selected = accent 10 % fill + 45 % ring, bold); when logged in "ACCOUNT" with Account and Blocked users (count) and a red Log out row; version footer. Semantics container "settings sections".
- Sub pages (chat filters, not interested, edit profile) slide over the pane, max width 560, top-left aligned, with "‹ <section>" back; account pages without an account fall back to General.
- Sheets become dialogs: `showSettingsSheet` → 460×640 dialog (inset 40); accent picker → 460-wide dialog; update prompt → 420-wide non-dismissible dialog; `SettingsDialog` max width 420 (360 on phones).
- Release notes tablet layout: 84 dp header with round back button, eyebrow and 28/800 title (and "You were on …" + Got it after an update); aside version list 340 dp (window ≥ 1100) or 280, 32 + hairline + 32, detail with sections as cards in two columns from 560 dp, Newer/Older step buttons. Phone layout keeps a 720 max-width column even in landscape.
- PC: the Windows window is always "large" when ≥ 600 dp in both dimensions; at smaller window sizes the phone layout must still work (single column, pushed pages with a back button). Keep the same breakpoints in logical pixels (DPI-scaled).

## PC equivalent

- **UI**: Slint components mirroring the kit (`SettingsCard`, `SettingsGroup`, `SettingsRow`, `SettingsSwitch`, `SettingsListSelect` with fit-measurement, `SettingsListSlider`, `SettingsDialog`, sheet-as-dialog) with the exact colour tables (dark/light), Inter font, 0.5 dp hairlines, motion durations and reduce-motion (Windows "Show animations" off → 150 ms fades). Master-detail is the default on desktop; keyboard: Tab/Shift-Tab between controls, Space/Enter toggles, arrows within segmented/radio groups, Esc closes dialogs/sheets and sub pages, Ctrl+F could map to jump chips. Hover states replace press scale where appropriate (keep press scale on click). Accessibility via Slint's accessible properties (roles: switch/checkbox/radio/button, labels identical to the Flutter semantics labels).
- **Persistence**: `settings.json` in `%APPDATA%\ONSET\` (macOS `~/Library/Application Support/ONSET`, Linux `$XDG_CONFIG_HOME/onset`), serde with identical keys and the JSON-decode defaults (not the Dart initializers: `languagePromptVersion` 0, `telemetryConsentVersion` 0 then migrated to 1), tolerant per-field decoding (wrong type / unknown value → that field's default; corrupt file → all defaults, old file kept as a backup), migrations (chat sync default, consent version, `revealDeletedMessages`, legacy start tab, portrait height inference, lenient enums incl. `landscapeCutout`), debounced 300 ms writes plus immediate writes for consent/language and on close; atomic write (temp file + rename). Optional import of an Android `settings` JSON.
- **Secrets**: every FlutterSecureStorage key goes to the OS keyring (`keyring` crate → Windows Credential Manager / macOS Keychain / Secret Service), service name `ONSET`, same key names; never in the JSON file. First-run wipe equivalent: on a fresh install (no settings file) clear stale keyring entries.
- **Login**: an embedded WebView2 window (`webview2-com`/`wry`) loads the same authorize URL (implicit grant, `force_verify`, 32-byte state) and intercepts navigation (`NavigationStarting`) to `https://twitch.tv/login#access_token=…&state=…` with the identical strict checks; the user agent string can stay the Chrome UA (Google sign-in works in WebView2 anyway). After `https://www.twitch.tv/?no-reload=true`, read the `auth-token` cookie with `ICoreWebView2CookieManager::GetCookies("https://www.twitch.tv")`, verify its owner via `/oauth2/validate`, store it in the keyring. The hidden refresh = an off-screen WebView2 controller loading twitch.tv (same navigation whitelist, 20 s timeout). A persistent WebView2 user-data folder plays the role of the Android cookie jar; logout deletes all its cookies (`DeleteAllCookies`). Alternative for paste-token login: context menu "Log in with copied token" (clipboard via `arboard`).
- **Device-code session**: same HTTP flow with `reqwest`; the activation page opens in WebView2 or the default browser; code copy to clipboard.
- **Token proxy / Helix / GQL**: `reqwest` client with the same headers, timeouts (6 s proxy, 5 s revoke, 10 s reconnect ticks ×5, 1 min app-token retry, 5 min web-token renewal cooldown, 30 s TV refresh retry), the same serialisation of session changes (a tokio `Mutex` queue, epoch/generation counters).
- **Notifications**: go-live polling as a background tokio task (15 min) while the app runs, plus an optional Windows Task Scheduler entry / startup item for when it is closed; mentions and go-live as Windows toast notifications (`windows` crate `ToastNotificationManager`; on macOS `UNUserNotificationCenter`, Linux `notify-rust`); "permission" maps to the OS notification settings (open `ms-settings:notifications` instead of Android's settings).
- **Android-only settings**: map rather than drop — Low-latency player (the PC native low-latency engine vs the WebView2 Twitch player fallback), Fast rendering (GPU path toggle), Background audio (keep playing when minimised; headphones-only via the default audio endpoint form factor), Auto PiP (auto mini-player window on minimise/focus loss), Captions (if the PC engine exposes CEA-608 tracks), Keep awake (`SetThreadExecutionState`).
- **Updater**: Other › Updates keeps "Check for updates" and the prompt; the Windows build checks GitHub releases (6 h throttle, 24 h postpone, forced check from the tile), downloads the signed installer/zip with the token only sent to api.github.com, verifies SHA-256 (and Authenticode), shows progress, then launches the installer and quits. Release notes read the same two Markdown assets embedded in the binary.
- **Links**: "Open links in external browser" → default browser (`open` crate) vs an in-app WebView2 window; "Confirm links" dialog kept. Licences page: a Slint page listing ONSET's AGPL notice then every crate licence (`cargo-about` output).
- **Image cache clear**: delete the on-disk image cache directory (same semantics, snackbar "cache cleared").


**Known Android defects** (reproduce the intended behaviour, not the bug):
1. **Settings decode can crash startup.** `SettingsStore.fromJson` hard-casts every non-enum field (`as bool?`, `as num?`, `as String?`, list elements `as String`, `notInterestedChannels` values `as String`, `secondaryTabs` items `as Map<String, dynamic>`, `landscapeChatModes as List?`) and `jsonDecode` throws on a corrupt file; main.dart has no try/catch, so one wrong-typed value or a truncated `settings` string makes the app fail at launch, forever. PC fix: tolerant per-field decode — each field falls back to its JSON default on a type error; an unparsable file loads all defaults and is kept as `settings.json.bak`.
2. **`landscapeCutout` has no unknown-value fallback.** Its `@JsonKey` has a `defaultValue` but no `unknownEnumValue`, so an unknown string (e.g. a value written by a future version) throws `ArgumentError` in `$enumDecodeNullable` → startup crash (same path as 1). PC fix: unknown → `none`.
3. **Logout can stop half-way.** In `_endSession`, after clearing the web session and running the listeners, one try/catch wraps the rest: if reading `user_token` throws (keystore) or `_useAppToken()` throws a non-`ApiException`, the revoke, deletion of `user_token`/`user_token_client_id`/`user_id`, nulling the token, `user.dispose()`, `_isLoggedIn = false` and the telemetry key are skipped — the UI still shows the account. PC fix: run every logout step independently (each in its own guarded block), always ending in the logged-out state.
4. **UserStore keeps the previous account's blocked list.** `init()` never clears `_blockedUsers`; the blocked-list fetch is fire-and-forget without `catchError`; an account switch calls `init(details:)` without `dispose()`. Account B therefore shows A's blocked users and count until B's fetch succeeds, or indefinitely if it fails (and the failure is an unhandled async error). `refreshBlockedUsers` throws when logged out (`_details!`). PC fix: clear the list on every init/switch, handle fetch errors (keep empty + retry on refresh), no-op refresh when logged out.
5. **The reconnect loop logs out silently.** When the loop finds the stored token invalid, or gives up after 5 attempts, `_logoutFromReconnect` runs `_endSession()` only; `TokenNotice.sessionEnded` is raised only by `init`'s invalid-token path. The viewer is logged out with no explanation (exhaustion only writes `Telemetry.log`). PC fix: raise the "session ended, log in again" notice on the invalid-token path of the loop too (and on exhaustion, say Twitch could not be reached).
6. **TwitchTvSession: a superseded grant stays on disk.** `_store` writes `twitch_tv_session` before re-checking the generation; if a detach/forget/attach happened during the write it returns `cancelled` but leaves the new session stored (it will be adopted, or deleted as another account's, at the next attach). PC fix: re-check after the write and delete (and revoke) the written session when superseded, or write under the same lock as the generation bump.
7. **AccentThrottle late write.** The trailing 100 ms timer always re-applies the latest colour and the picker never flushes/cancels on close, so a write can land up to 100 ms after the picker closed. Harmless (it is the last colour) but racy with a Reset in that window. PC fix: flush on close, keep "last colour picked is saved".
8. **`loginFromClipboard` is untrimmed and silent.** It passes the raw clipboard text (only null filtered) to `login(acceptAnyApp: true)` without awaiting it: whitespace around a token or an empty clipboard fails with no feedback. PC fix: trim, ignore empty, await and show success/failure.
9. **Gift / whisper Undo throws after the page closes.** The result snackbar goes to the root messenger and survives popping Settings › Account; its Undo calls `_apply` on the disposed State (`ScaffoldMessenger.maybeOf(context)` / `setState` throw), unawaited, so the revert is never sent and the error is unhandled. PC fix: run the undo through a service/store that outlives the page (re-send the previous value with its own result toast), or remove the action when the page closes.
10. **Connect sheet says "Couldn't reach Twitch" for a cancel.** `twitchTvConnectResult` has no `cancelled`/`failed` branches; a `cancelled` outcome reaching a mounted sheet (account switched or generation superseded during `_store`) shows the network-error `other` text. PC fix: close the sheet silently on cancel (or a dedicated "cancelled, try again" text); keep "Couldn't reach Twitch" for real failures.
11. **Unknown hidden-content-label ids are stuck.** They count in the row but have no checkbox in the sheet and survive every toggle; only a General reset removes them. PC fix: list unknown stored ids as extra checkable rows (named by CamelCase split), or drop them on load.
12. **Chat bubbles: unknown/duplicate names.** Unknown or duplicated stored names inflate the row's count until the first toggle, which silently rebuilds the list from the enum and drops them. PC fix: normalise on load (known names, canonical order, deduplicated) so the count is always right.
13. **Remote settings loaders: empty = unavailable, and no error guard.** The Twitch notification settings show "unavailable" for an empty list too; gift, whisper and notification groups' `_reload` have no try/catch, so a throwing loader leaves an endless spinner. PC fix: loaders never throw (map every error to `None`), distinguish "empty" (show nothing/a neutral note) from "unavailable", and always clear the spinner.

## Source files

One section per non-generated source file of `lib/screens/settings/`.

### lib/screens/settings/settings.dart

The pushed settings page (338 lines). Entry points: Profile's "Settings" and the chat's menu call the static `Settings.open(context, {initialPage = SettingsPageId.general})`, which pushes a `MaterialPageRoute` with `RouteSettings(name: 'Settings')` (`Settings.routeName`) and builds `Settings(settingsStore: context.read<SettingsStore>(), initialPage: initialPage)`. `Settings` is a `StatefulWidget`; its state owns `late final _selection = SettingsSelection(page: widget.initialPage)` (disposed in `dispose`) so that the tablet's chosen page survives a rotation or a fold to phone size and back. `build` reads `AuthStore` from Provider and returns `SettingsScaffold(title: l10n.settingsTitle, body: …)`: when `context.isLargeScreen` (a `LargeScreenScope` override, else `MediaQuery.size.shortestSide >= 600`) the body is `SettingsMasterDetail(selection, settingsStore, authStore)`, otherwise `SettingsHome(settingsStore, authStore)`.

`SettingsHome` (phone first page) = `SettingsGroupsView(footer: const SettingsFooter(), children: [SettingsAccountCard(authStore), SettingsGroup(title: l10n.settingsCustomize, children: [for page in SettingsPageId.customize -> SettingsSectionRow(page, settingsStore, authStore)]), ...otherSettingsGroups(context, settingsStore)])` — i.e. the account card, a "Customize" group of section rows, then the groups of the Other page inlined (see other_settings.dart), then the version footer.

`settingsSectionSummary(AppLocalizations l, SettingsPageId page, {required bool loggedIn})` returns the subtitle under a section: general -> `settingsSummaryGeneral`, video -> `settingsSummaryVideo`, chat -> `settingsSummaryChat`, notifications -> `settingsSummaryNotifications` when logged in else `settingsSummaryNotificationsLoggedOut`, other -> `settingsSummaryOther`, any other id -> `''`.

`SettingsSectionRow({page, settingsStore, authStore, String? summary})` renders a `SettingsRow(glyph: page.glyph, title: page.title(l10n), strong: true, minHeight: 60, subtitle: Text(summary), end: SettingsRowEnd.chevron, onTap: openSettingsPage(context, id: page, builder: buildSettingsPage(page, …)))`. If `summary` is given it is used as-is (the owner observes it); otherwise the row is wrapped in an `Observer` so the notifications summary switches when `authStore.isLoggedIn` changes.

`buildSettingsPage(id, {settingsStore, authStore})` maps every `SettingsPageId`: general -> `GeneralSettings`, video -> `VideoSettings`, chat -> `ChatSettings`, notifications -> `NotificationsSettings(settingsStore, authStore)`, other -> `OtherSettings`, account -> `AccountSettings(authStore)`, blocked -> `BlockedUsers(authStore)`, chatFilters -> `SizedBox.shrink()` (the filter page is only ever opened as a sub page with its own builder), notInterested -> `NotInterestedChannels(settingsStore)`, editProfile -> `EditProfileHost(authStore)`.

`SettingsAccountCard(authStore)` — an `Observer` building a `SettingsCard` whose child is an `InkWell` (`splashFactory: NoSplash.splashFactory`, `highlightColor: colors.pressed`) with padding `fromLTRB(16, 14, 14, 14)` and a `Row(spacing: 14)` of [leading, Expanded(Column(spacing: 3, title, detail)), trailing]. Title style: body family, 16 sp, w700, `colors.text`; detail: body family, 13 sp, `colors.secondary`. Three states, checked in this order:
1. `authStore.error != null` — leading `_Disc(glyph: error, color: colors.danger, fill: colors.dangerTint)`, title `settingsUnableToReachTwitch`, detail `settingsCheckConnection`, tap = `authStore.init`, trailing `SettingsButton(label: settingsReconnect, onPressed: authStore.init)`.
2. logged in and `authStore.user.details != null` — leading `SettingsAvatar(user: details, size: 48)`, title `details.displayName`, detail `settingsAccountCardDetail`, tap opens the account page via `openSettingsPage(id: SettingsPageId.account, builder: AccountSettings(authStore))`.
3. otherwise (anonymous) — leading `_Disc(glyph: anonymous, color: colors.secondary, fill: colors.tile)`, title `settingsAnonymous`, detail `settingsLoginPitch`, tap `openLogin(context)`, long-press `loginFromClipboard(authStore)` (hidden power-user path: paste a token copied to the clipboard).
Trailing defaults to `SettingsGlyph(chevronRight, strokeWidth: 2, color: colors.tertiary)`.

`_Disc` is a 48x48 circle filled with `fill`, centring `SettingsGlyph(glyph, size: 22, strokeWidth: 1.8, color: color)`.

Desktop port: same three-state card; long-press -> right-click/context menu "Log in with a copied token"; the route name "Settings" is used by navigation observers and tests.

### lib/screens/settings/settings_master_detail.dart

Tablet / wide settings (627 lines): a side column ("aside") of sections next to the chosen page ("pane").

`SettingsSubPage({id, parent, builder})` (immutable) is a page opened inside a section on a tablet (e.g. Edit Chat Filters under Chat); its title is read from `id` when the pane builds so it follows the language.

`SettingsSelection extends ChangeNotifier` — state `_page` (default `SettingsPageId.general`), `_sub` (nullable), `_turn` (int counter, incremented on each page change so the page "enters anew"). `select(page)`: no-op if `page == _page && _sub == null`; else sets page, clears sub, `_turn++`, notifies. `open(sub)`: sets `_sub`, notifies (turn unchanged). `closeSub()`: no-op when no sub; else clears and notifies. Owned by Profile's tab state or the pushed `Settings` state so it survives rotation and phone<->tablet changes.

`SettingsMasterDetail({selection, settingsStore, authStore})` — `LayoutBuilder`: `width = maxWidth - padding.horizontal - 56`; `aside = width >= 1000 ? 330 : 280`; `pane = width - aside - 32.5`. Outer padding `fromLTRB(28 + padding.left, 12 + padding.top, 28 + padding.right, 0)`. Row (stretch): `SizedBox(width: aside, _Aside)`, 16 gap, a vertical hairline (`OnsetTokens.hairlineWidth` wide, `SettingsColors.hairline`, bottom inset 28), 16 gap, `Expanded(_Pane(columns: pane >= 640 ? 2 : 1, bottom: padding.bottom))`.

`_shown(page, authStore)`: if `page.needsAccount && !hasAccount(authStore)` (logged out or Twitch unreachable) the pane shows `SettingsPageId.general` instead.

`_Aside` — `Semantics(label: settingsSectionsSemantics, container: true, explicitChildNodes: true)` around `ListenableBuilder(selection)` + `Observer`. A `ListView` with padding `fromLTRB(0, 4, 0, 28 + bottomInset)`: `_ProfileCard`, 18 gap, `SettingsSectionLabel(settingsTitle, horizontal padding 12)`, 6 gap, one `_AsideRow` per `SettingsPageId.sections`; if `hasAccount(authStore)` (no error, logged in AND details loaded — so these rows are hidden while Twitch is unreachable or the user is still loading, even when `isLoggedIn` is true): 18 gap, label `settingsPageAccount`, 6 gap, row(account), row(blocked, value: `'${authStore.user.blockedUsers.length}'`), 18 gap, `_LogoutRow`; then 18 gap and `SettingsFooter`. Tapping a row calls `selection.select(id)`; a row is selected when it equals the shown page.

`_AsideRow({page, selected, onTap, value})` — 2 dp bottom padding; `Semantics(button: true, selected, label: page.title, value, onTap, excludeSemantics: true)` (onTap repeated because excluding semantics drops the detector's tap); `PressScale` -> `GestureDetector(opaque)` -> `AnimatedContainer(duration: settingsMotion(context, 220), curve: OnsetMotion.standard = Cubic(0.2,0,0,1), height: 48, horizontal padding 12)`, decoration: fill `accent @ 0.10` when selected else `accent @ 0`, radius 14, border hairline `accent @ 0.45` when selected else transparent. Row(spacing 12): `SettingsGlyph(page.glyph, color: selected ? accent : colors.secondary)`, Expanded title (1 line, ellipsis, body family 15 sp, w700 selected / w500 otherwise, `colors.text` selected / `colors.body`), optional value text in `SettingsText.value` coloured `colors.secondary`.

`_LogoutRow` — Semantics button labelled `settingsLogOut` (onTap repeated, exclude semantics), PressScale + opaque GestureDetector, 48 high, horizontal padding 12, Row(spacing 12): `SettingsGlyph(logout, color: colors.danger)`, text `settingsLogOut` (15 sp, w600, danger). Tap -> `confirmLogout(context, authStore)` (dialog from account_settings.dart).

`_ProfileCard` — Observer; if `!hasAccount || details == null` it returns `ProfileLoginCard(authStore)` (from profile_tab.dart). Otherwise `SettingsCard(radius: OnsetTokens.radiusLarge, padding: all 18)` with Column(stretch, spacing 16): Row(spacing 14) [SettingsAvatar size 60, Column(spacing 3): display name (1 line ellipsis, 20 sp w800, letterSpacing -0.5, text), `accountLine(l10n, details)` (2 lines ellipsis, 13 sp secondary)], then `SettingsButton(label: settingsMyChannel, expand: true, icon: SettingsGlyph(play, size 13, text colour), onPressed: openMyChannel(context, authStore))`.

`_Pane({selection, settingsStore, authStore, columns, bottom})` — `MediaQuery.removePadding(top/left/right)`; `_open(id, builder)`: if `id.isSection` -> `selection.select(id)` else `selection.open(SettingsSubPage(id, parent: selection.page, builder))`. Builds (ListenableBuilder + Observer) `page = _shown(selection.page)`, `sub = page == selection.page ? selection.sub : null`, then a `Stack` of:
- `Positioned.fill(AnimatedSwitcher(duration: reduce ? 150 ms : 300 ms, switchIn/OutCurve: OnsetMotion.standard, layoutBuilder: Stack of only the current child (old child is dropped from layout immediately), transitionBuilder: FadeTransition + (unless reduce) SlideTransition from Offset(0, 0.008) to zero, child: KeyedSubtree(key: ValueKey((page, turn)), SettingsPaneScope(key: ValueKey(('page', page, turn)), onOpen: _open, columns, title: page.title, description: page.description, child: buildSettingsPage(page)))))`.
- `Positioned.fill(_SubPageHost(sub, builder: ColoredBox(scaffoldBackgroundColor, Align(topLeft, ConstrainedBox(maxWidth 560, SettingsPaneScope(onOpen: _open, columns: 1, title: sub.id.title, backLabel: sub.parent.title, onBack: selection.closeSub, child: sub.builder))))))`.

`_SubPageHost` (SingleTickerProvider) — `AnimationController(duration 360 ms, reverseDuration 260 ms, value: sub == null ? 0 : 1)`, `CurvedAnimation(curve: OnsetMotion.standard, reverseCurve: Cubic(0.4, 0, 1, 1))`. `_shown` keeps the page drawn while it slides out. `didUpdateWidget`: durations become 150/150 ms under reduce motion; a new sub -> `_shown = sub; forward()`; sub cleared -> `reverse().whenCompleteOrCancel(() => if mounted && still null setState(_shown = null))`. Build: nothing when `_shown == null`; else `IgnorePointer(ignoring: widget.sub == null, child: reduce ? FadeTransition(curved) : SlideTransition(Offset(1,0) -> zero))`, child keyed `ValueKey(('sub', shown.id))`.

### lib/screens/settings/profile_tab.dart

The navigation shell's Profile tab (426 lines). `ProfileTab({settingsStore, authStore, goLivePlatform = const GoLivePlatform()})` — `goLivePlatform.supported` says whether go-live notices exist on this platform (Android only).

State `_ProfileTabState`: owns `_selection = SettingsSelection()` (kept across phone<->tablet transitions; disposed), `bool? _goLive` (whether go-live notices are on, for the Notifications summary), `_goLiveRead` counter. `initState` subscribes `OnsetShell.routeObserver.addListener(_onRoutes)` and starts `_readGoLive()`; every route change over the shell (e.g. returning from the settings) re-reads. `_readGoLive`: `read = ++_goLiveRead; enabled = (await GoLivePrefs.load()).enabled;` drops the result if unmounted or a newer read started; `setState` only when it changed; exceptions are logged as `'Profile: go-live state unavailable: ${e.runtimeType}'` and ignored. `dispose` removes the listener and disposes the selection.

`build`: on a large screen returns `SettingsMasterDetail(selection: _selection, …)` (the tablet's Profile IS the settings); else `_PhoneProfile(notificationsSummary: _notificationsSummary)`.

`_notificationsSummary(l, loggedIn)`: logged out -> `settingsSummaryNotificationsLoggedOut`; `mentions = OnOff.of(settingsStore.mentionNotifications).name` ("on"/"off", consumed by an ICU select); when go-live is unsupported or not read yet -> `settingsSummaryMentions(mentions:)`; else `settingsSummaryGoLiveMentions(goLive: OnOff.of(_goLive).name, mentions:)`.

`_PhoneProfile` — `StaggerScope` + `Observer`. `loggedIn = hasAccount(authStore)` (no error, logged in, details loaded). Sections list in order: `_ProfileHeader(onSettings: Settings.open(context))` when logged in, else `ProfileLoginCard(authStore)`; `_AccountCard` (logged in only); `_SettingsCard(notificationsSummary: notificationsSummary(l10n, authStore.isLoggedIn))`; when logged in a title-less `SettingsGroup` with one `SettingsRow(glyph: logout, title: settingsLogOut, danger: true, strong: true, onTap: confirmLogout)`; `_Version`. `ListView` padding `fromLTRB(16 + padL, padTop + 18, 16 + padR, padBottom + 24)`; each section has 22 dp bottom padding (none after the last) and is wrapped in `StaggeredEntrance(index)` — first appearance only: rises 16 px and fades in, delay `40 ms * min(index, 8)`, then 350 ms on `emphasizedDecelerate` Cubic(0.05, 0.7, 0.1, 1); under reduce motion a 150 ms fade without travel.

`_ProfileHeader` — `Semantics(container, label: settingsYourProfile, explicitChildNodes)`, Column(stretch, spacing 16):
- Row(spacing 16): the avatar `SettingsAvatar(size 76)` inside a circular `DecoratedBox` with two shadows forming a ring: `BoxShadow(colors.buttonRing, spreadRadius 3.5)` then `BoxShadow(scaffold background, spreadRadius 2)` (a 1.5 dp ring with a 2 dp gap); then a Column(spacing 4): display name (semantics header, 1 line ellipsis, 26 sp w800 letterSpacing -0.78 height 1.1 text), `'@login'` (14 sp body colour, 1 line ellipsis), and — if `joinedText` is not null — Row(spacing 6)[calendar glyph size 14 secondary, Flexible text 12.5 sp secondary].
- Row(spacing 8) of two expanded quiet buttons: `settingsMyChannel` with play glyph (size 13) -> `openMyChannel`; `settingsTitle` ("Settings") with general glyph (size 16) -> `onSettings` (pushes `Settings`).

`_AccountCard` — Observer, `SettingsGroup(title: settingsPageAccount)`: row Blocked (`ban` glyph, `settingsPageBlocked`, strong, value = blocked user count, chevron, `openBlockedUsers`); when details exist a row keyed `'my-clips'` (`play` glyph, `myClipsTitle`, strong, subtitle `myClipsSubtitle`, chevron, `MyClipsScreen.open(context, login: details.login, userId: details.id)`); then one external row per `TwitchAccountPage.profileTab` = [security, connections] (glyph, title, strong, subtitle `page.detail`, `openTwitchAccountPage`).

`_SettingsCard` — `SettingsGroup(title: settingsTitle)` of `SettingsSectionRow` for each of `SettingsPageId.sections` (all five, Other included), passing the precomputed summary only for notifications (others observe their own).

`_Version` — Stateful caching `PackageInfo.fromPlatform()`, centred `'ONSET v${version} (${buildNumber})'`, tabular Inter 12 sp tertiary (empty until loaded).

### lib/screens/settings/general_settings.dart

Settings › General (134 lines). `GeneralSettings({settingsStore})` = `Observer` -> `SettingsGroupsView` with five groups, in order:
1. `settingsLanguageTitle` ("Language"): `LanguageSetting` (System / English / Français, stacked).
2. `settingsTheme`: `ThemeSelectionSetting` (segmented System / Light / Dark) and `AccentColorSetting` (hex + swatch row opening the picker).
3. `settingsStreamCard`: switch `settingsLargeStreamCard` -> `largeStreamCard`; switch `settingsShowThumbnail` -> `showThumbnails`.
4. `settingsBrowse`:
   - `SettingsListSelect(title: settingsStartTab, value: startTab, values: HomeTab.values = [following, live, clips, browse], labels shellFeedFollowing / shellFeedLive / shellFeedClips / shellSectionBrowse)` -> `startTab`. (The segment pill falls back to a stack when the four labels don't fit.)
   - `StreamLanguageSetting` (row + sheet).
   - `HiddenContentLabelsSetting` (row + checkbox sheet).
   - `SettingsListSelect(title: settingsClipDiscovery, isNew: isNewFeature('clipDiscovery'), value: clipDiscovery, values: [all, featured], labels clipDiscoveryAll / clipDiscoveryFeatured)`; on change sets `clipDiscovery` and `markFeatureSeen('clipDiscovery')`.
   - `SettingsListSwitch(title: settingsHideViewerCount, isNew: isNewFeature('hideViewerCount'), value: hideViewerCount)`; on change sets it and marks `'hideViewerCount'` seen.
   - `SettingsRow(glyph: list, title: settingsPageNotInterested, isNew: isNewFeature('notInterested'), value: '${notInterestedChannels.length}', end: chevron)`; tap marks `'notInterested'` seen then `openSettingsPage(id: notInterested, builder: NotInterestedChannels)` (sub page over General on a tablet, pushed on a phone).
5. `settingsLinks`: `ExternalBrowserSetting` (switch `settingsExternalBrowser` -> `launchUrlExternal`) and `ConfirmLinksSetting` (switch `settingsConfirmLinks` with subtitle `settingsConfirmLinksDetail` -> `confirmExternalLinks`).

"NEW" pills: `isNewFeature(id)` is true until `id` is in `seenNewFeatures`; the ids are `NewFeature` enum names (`dataSaver, streamPreviews, clipDiscovery, hideViewerCount, notInterested, landscapeAlerts, cast, floatingPlayer`). Interacting with the control marks it seen (persisted list `seenNewFeatures`).

### lib/screens/settings/video_settings.dart

Settings › Video (233 lines). `VideoSettings({settingsStore, bool? isAndroid, bool? isIOS})` — the two booleans override `Platform.isAndroid`/`Platform.isIOS` for tests. `Observer` -> `ivs = android && playerEngine == PlayerEngine.ivs` -> `SettingsGroupsView` with groups:

1. **Android only** — `settingsLowLatencyPlayer`:
   - `SettingsListSwitch(title: settingsLowLatencyPlayerSwitch, subtitle: settingsLowLatencyPlayerDetail, value: playerEngine == ivs, onChanged: enabled ? PlayerEngine.ivs : PlayerEngine.twitchWeb)` — off falls back to the Twitch web player in a WebView (note: the switch never selects `nativeLowLatency`; that enum value is only reachable from saved data/elsewhere).
   - Only when `ivs`: switch `settingsAutoLatency` (+ detail) -> `autoLatency`; `SettingsListSelect(settingsLiveCatchUp, subtitle settingsLiveCatchUpDetail, values [speedUp, jumpToLive], labels liveCatchUpSpeedUp / liveCatchUpJumpToLive)` -> `liveCatchUpMode`; `SettingsListSelect(settingsBufferProfile, subtitle settingsBufferProfileDetail, values [standard, ultra], labels bufferProfileStandard / bufferProfileUltra)` -> `bufferProfile`; `SettingsTwitchWebToken(authStore: context.authStore)` (the 2K/enhanced-broadcast cookie row).
2. `settingsPlayback`: switch `settingsEnableVideo` -> `showVideo` (setter also clears `chatOnlyForPage`); switch `settingsHighestQuality` -> `defaultToHighestQuality` shown unless iOS on an iPhone (`!ios || isIPad()`); Android: switch `settingsFastRendering` (+ detail) -> `useTextureRendering`; switch `settingsKeepAwake` (+ detail) -> `keepScreenAwake`; Android: switch `settingsBackgroundAudio` (+ detail) -> `backgroundAudio`; Android and `backgroundAudio` on: switch `settingsBackgroundAudioHeadphonesOnly` (+ detail) -> `backgroundAudioHeadphonesOnly`; Android: switch `settingsAutoPip` (+ detail) -> `autoPictureInPicture`.
3. `settingsOverlay`: switch `settingsCustomOverlay` (+ detail) -> `showOverlay`; switch `settingsToggleOverlay` (+ detail) -> `toggleableOverlay`; switch `settingsShowLatency` (+ detail) -> `showLatency` (the latency readout in the player overlay; Definition-of-done requires latency to be visible).
4. `settingsVideosAndContent`: `SettingsListSelect(settingsVodAutoplay, subtitle settingsVodAutoplayDetail, stacked: true, values [always, wifiOnly, never], labels vodAutoplayAlways / vodAutoplayWifiOnly / vodAutoplayNever)` -> `vodAutoplay`; switch `settingsStreamPreviews` (isNew 'streamPreviews', + detail; marks seen) -> `streamPreviews`; when previews on: switch `settingsMutePreviews` -> `mutePreviews`; switch `settingsDataSaver` (isNew 'dataSaver', + detail; marks seen) -> `dataSaver`; switch `settingsWarnMature` (+ detail) -> `warnMatureContent`.
5. **Android only** — `settingsCaptions`: `captionStyleRows(settingsStore)` (captions come from the IVS player).

PC mapping: the IVS engine does not exist on Windows; the PC's low-latency engine (libmpv / native HLS) takes the "Low-latency player" switch with the same catch-up and buffer choices; background audio = keep playing when minimised; auto PiP = auto mini-player when the window loses focus / is minimised; fast rendering = GPU texture path toggle; keep awake = `SetThreadExecutionState(ES_DISPLAY_REQUIRED)`.

### lib/screens/settings/not_interested_channels.dart

`NotInterestedChannels({settingsStore})` (42 lines) — the page "Not interested" (opened from General's Browse group; a sub page on tablets). Observer over `settingsStore.notInterestedChannels` (`Map<userId, displayName>`, persisted as `notInterestedChannels`, filled by "Not interested" on recommended/live-feed cards), entries sorted by display name case-insensitively. Renders `SettingsNameList(names: display names, rowKeys: ValueKey('not-interested-<userId>'), emptyGlyph: list, emptyText: notInterestedEmpty (centred), emptyNote: notInterestedNote, countText: notInterestedCount(count), note: notInterestedNote, actionLabel: notInterestedRestore, actionSemantics: notInterestedRestoreName(name), onAction: settingsStore.clearNotInterested(userId))`. No pull to refresh (local data). Restoring removes the entry immediately; the channel shows again in recommendations/live feed.

### lib/screens/settings/chat_settings.dart

Settings › Chat (750 lines). `ChatSettings({settingsStore})` is Stateful only to own a `TapGestureRecognizer _recentLink` (disposed). `_accountSyncService(context)` returns the provided `TwitchViewerActionsService?` only when logged in (catches `ProviderNotFoundException` -> null). Build = `Observer` -> `SettingsGroupsView` of these groups, in order:

1. **`settingsMessageSizing`**: `_ChatPreview`; then five Observer-wrapped `SettingsListSlider`s:
   - `settingsBadgeScale`, trailing `settingsScaleValue(scale)` (`"{scale}×"`, `scale` a double formatted with `decimalPatternDigits` and exactly 2 decimals in the locale — "1.00×", "1.25×"; French writes "{scale} ×" with a no-break space and a decimal comma, "1,25 ×"), min 0.25, max 3.0, divisions 11 (steps of 0.25) -> `badgeScale`;
   - `settingsEmoteScale`, same range/steps -> `emoteScale`;
   - `settingsMessageScale`, min 0.5, max 2.0, divisions 6 (0.25 steps) -> `messageScale`;
   - `settingsMessageSpacing`, trailing `settingsSpacingValue(pixels: round)`, min 0, max 30, divisions 15 (2 px steps) -> `messageSpacing`;
   - `settingsFontSize`, trailing the integer value, min 5, max 20, divisions 15 (1 pt) -> `fontSize`.
2. **`settingsMessageAppearance`**: switches `settingsShowDeleted` (+detail) -> `showDeletedMessages` (persisted as `revealDeletedMessages`); `settingsAnimateEmotes` (+detail) -> `animateEmotes`; `settingsAnimatedGifs` (+detail) -> `animateGifs`; `settingsShowGifs` (+detail) -> `showGifs`; `settingsLinkPreviews` (+detail) -> `showLinkPreviews`; `settingsModerationNotices` (+detail) -> `showModerationNotices`; `settingsMessageDividers` -> `showChatMessageDividers`; `SettingsListSelect(settingsTimestamps, values [disabled, twelve, twentyFour], labels timestampDisabled / timestampTwelve / timestampTwentyFour)` -> `timestampType`; switch `settingsReadableNameColors` whose value is `readableNameColors || increaseChatContrast`, subtitle `settingsReadableNameColorsLocked` while contrast is increased (then `onChanged: null` -> dimmed/locked) else `settingsReadableNameColorsDetail`; switch `settingsIncreaseChatContrast` (+detail) -> `increaseChatContrast`. Effect: `nameColorContrast` = 7.0 (high) when increased, 4.5 when readable, null otherwise — the minimum WCAG contrast user name colours are adjusted to.
3. **Account sync** (only when logged in and the service exists): `ChatAccountSyncGroup(settingsStore, load: service.chatUiSettings(authToken: twitchWebToken ?? ''), save: (setting, enabled) => service.updateChatUiSetting(setting, enabled, authToken))`.
4. **`settingsDelayAndLatency`**: switch `settingsSyncDelay` (+detail) -> `autoSyncChatDelay`; when OFF an Observer slider `settingsMessageDelay`, trailing `settingsMessageDelayValue(seconds: chatDelay.toInt())`, subtitle `settingsMessageDelayDetailIos` on iOS else `settingsMessageDelayDetail`, min 0, max 30, divisions 30 (1 s) -> `chatDelay`. Effect: `effectiveChatDelay = autoSyncChatDelay ? syncedChatDelay (measured player latency, set by the video stores) : chatDelay` — messages are held that long so chat matches the video.
5. **`settingsLayout`**: switch `settingsEmoteButtonLeft` (+detail) -> `emoteMenuButtonOnLeft`; switch `settingsPersistTabs` (+detail) -> `persistChatTabs`, and turning it off also clears `secondaryTabs = []`; `SettingsListSelect<PortraitChatHeight>(settingsPortraitChatHeight, subtitle settingsPortraitChatHeightDetail, values PortraitChatHeight.presets = [low, medium, high], labels portraitChatHeightLow / Medium / High)` -> `portraitChatHeight` (`custom` is never offered; it is set by dragging the divider on the channel page; when custom no segment is selected).
6. **`settingsAlerts`**: switches `settingsFirstTimeChatters` -> `highlightFirstTimeChatter`; `settingsUserNotices` (+detail) -> `showUserNotices`; `settingsCollapseGiftBombs` (+detail) -> `collapseGiftBombs`; `settingsHideGiftSubNotices` (+detail) -> `hideGiftSubNotices`; `settingsHideGiftCount` (+detail) -> `hideGiftCount`; `ChatBubblesSetting`; switches `settingsShowHypeTrains` (+detail) -> `showHypeTrain`; `settingsCommunityHighlights` (+detail) -> `showCommunityHighlights`; `settingsCelebrations` (+detail) -> `showCelebrations`; when celebrations on: `SettingsListSelect(settingsCelebrationsOnVideo, subtitle settingsCelebrationsOnVideoDetail, values [full, subtle], labels celebrationsFull / celebrationsSubtle)` -> `celebrationsOnVideo`; when on AND full: switch `settingsAlertsOverLandscapeVideo` (isNew 'landscapeAlerts', +detail; marks seen) -> `alertsOverLandscapeVideo`. `celebrationsSubtle(landscape)` = subtle mode OR (landscape AND alerts over landscape video off).
7. **`pointsChannelPoints`** ("Channel Points"): `SettingsRow(settingsReplayPointsIntro, subtitle settingsReplayPointsIntroDetail)` — tap sets `pointsIntroSeen = false` and shows (after clearing others) a SnackBar `settingsPointsIntroReset`.
8. **`settingsAutocomplete`**: switch `settingsAutocompleteBar` (+detail) -> `autocomplete`.
9. **`settingsLandscape`**: switch `settingsChatLeft` -> `landscapeChatLeftSide`; switch `settingsVerticalChat` (+detail) -> `landscapeForceVerticalChat`; `SettingsListSelect(settingsNotchSide, subtitle settingsNotchSideDetail, values [none, left, right, both], labels notchSideNone / Left / Right / Both)` -> `landscapeCutout`; slider `settingsOverlayOpacity`, trailing `settingsOverlayOpacityValue(percent: round(opacity*100))`, subtitle `settingsOverlayOpacityDetail`, min 0, max 1, divisions 10 -> `fullScreenChatOverlayOpacity`; switch `settingsTapToCloseOverlay` (+detail) -> `tapToCloseOverlayChat`.
10. **`settingsChatSwitching`**: `SettingsNote(settingsChatSwitchingDetail)` then one Observer switch per `LandscapeChatMode` [overlay, column, hidden] labelled `settingsChatSwitchingOverlay / Column / Hidden`. `_chatSwitchingRow`: `on = switchableLandscapeChatModes.contains(mode)`; when on and only `minLandscapeChatModes = 2` remain the switch is disabled (null onChanged) — at least two modes must stay in the landscape cycle; else `setLandscapeChatMode(mode, on: value)` (which, if the current mode is removed, moves to the next mode in the cycle).
11. **`settingsFiltersGroup`**: `SettingsRow(glyph filter, settingsPageChatFilters, value settingsFiltersOn / settingsFiltersOff by chatFiltersEnabled, chevron)` -> `openSettingsPage(id: chatFilters, builder: ChatFiltersSetting)`; `SettingsMutedWords`; switch `settingsWholeWords` (+detail) -> `matchWholeWord`.
12. **`settingsEmotesAndBadges`**: switches, in order: `settingsShowTwitchEmotes` -> `showTwitchEmotes`, `settingsShowTwitchBadges` -> `showTwitchBadges`, `settingsShow7tvEmotes` -> `show7TVEmotes`, `settingsShow7tvBadges` -> `show7TVBadges`, `settingsShow7tvPaints` -> `show7TVPaints`, `settingsShow7tvPersonalEmotes` -> `show7TVPersonalEmotes`, `settingsShowBttvEmotes` -> `showBTTVEmotes`, `settingsShowBttvBadges` -> `showBTTVBadges`, `settingsShowBttvPersonalEmotes` -> `showBTTVPersonalEmotes`, `settingsShowFfzEmotes` -> `showFFZEmotes`, `settingsShowFfzBadges` -> `showFFZBadges`, `settingsShowFfzRoomBadges` -> `showFFZRoomBadges`, `settingsShowEmoteChangeNotices` (subtitle `settingsShowEmoteChangeNoticesSubtitle`) -> `showEmoteChangeNotices`.
13. **`settingsRecentMessages`**: switch titled `onboardingSetupHistoryTitle` with a rich subtitle built from `onboardingSetupHistoryDetail(link: l10nMark(0))` where the mark is replaced (`l10nSpans`) by a tappable span `https://recent-messages.robotty.de/` (accent colour, underlined with accent decoration) opening via `launchSettingsLink(url, external: launchUrlExternal)` -> `showRecentMessages` (third-party history service; off by default).

`_ChatPreview` (Stateful, `_open = false`): a `SettingsRow(settingsChatPreview, minHeight 52, onTap toggles)` wrapped in `Semantics(expanded: _open)`, trailing `AnimatedRotation(turns: open ? 0.5 : 0, duration settingsMotion(300), curve standard)` of a chevronDown (strokeWidth 2, secondary). Below, `AnimatedSize(300 ms, standard, alignment topCenter)`: closed = zero-height full-width box; open = Observer `Container(margin fromLTRB(12, 0, 12, 12), padding 14, colour well, radius 12, cardRing 0.5 border)` with `DefaultTextStyle(fontSize: fontSize, height 1.4, colour body)` and a Column: a rich line [badge image `https://static-cdn.jtvnw.net/badges/v1/bbbe0db0-a598-423e-86d0-f9fb98ca1933/3` sized `18 * badgeScale`, text `' ${settingsChatPreviewBadgeEmote} '`, emote image `https://static-cdn.jtvnw.net/emoticons/v2/425618/default/dark/3.0` sized `28 * emoteScale`] scaled by `TextScaler.linear(messageScale)`, `SizedBox(height: messageSpacing)`, `settingsChatPreviewText`, spacing, `settingsChatPreviewSpacing` (both scaled). Images load only once opened.

### lib/screens/settings/notifications_settings.dart

Settings › Notifications (66 lines). `NotificationsSettings({settingsStore, authStore})` — Observer, `loggedIn = authStore.isLoggedIn`. `SettingsGroupsView` with:
1. `settingsChannelsYouFollow`: `GoLiveSetting(userId: loggedIn ? authStore.user.details?.id : null)`.
2. `settingsPageChat` ("Chat"): `MentionNotificationSetting(settingsStore, loggedIn)`.
3. When `twitchInboxOf(context)` returns an inbox (a `TwitchSocialService` is provided, logged in with a user id, and a non-empty twitch.tv web token): `TwitchNotificationSettingsGroup(load: inbox.service.notificationSettings(userId, authToken: web token), onEdit: openTwitchAccountPage(TwitchAccountPage.notifications))` — Twitch's own per-category notification settings, read-only, with an "edit on twitch.tv" row.
Both notification kinds were under General in earlier versions.

### lib/screens/settings/other_settings.dart

Settings › Other (203 lines). `OtherSettings({settingsStore, sourceUrl = onsetRepoUrl ('https://github.com/JLmehdi92/onset')})` = `SettingsGroupsView(footer: SettingsFooter() only when NOT in a tablet pane (the aside already shows the version), children: otherSettingsGroups(context, settingsStore, sourceUrl))`. On a phone these same groups are appended to the first settings page (`SettingsHome`).

`otherSettingsGroups(context, settingsStore, {sourceUrl})` — `updater = context.read<OnsetUpdater?>()`, `updates = updater != null && updater.enabled` (Android and an update repo configured). Groups:
1. `settingsUpdates`: `UpdateCheckTile(updater)` when updates; `SettingsRow(glyph notes, settingsReleaseNotes, chevron)` pushing `MaterialPageRoute(settings: RouteSettings(name: ReleaseNotes.routeName), ReleaseNotes())`; `SettingsNote(settingsUpdatesNote)` when updates.
2. `settingsStorage`: `SettingsRow(glyph cache, settingsClearCache)` -> `clearImageCache`; `SettingsRow(glyph reset, settingsReset)` -> `confirmResetSettings`.
3. `settingsPrivacy`: Observer switch `onboardingSetupCrashTitle` / `onboardingSetupCrashDetail` -> `shareCrashLogsAndAnalytics` (the app follows it through `syncFirebaseCollection`; written to disk immediately; never collects in debug builds).
4. `settingsAbout`: when `sourceUrl` non-empty `SettingsRow(glyph code, settingsSourceCode, external)` -> `launchSettingsLink(sourceUrl, external: launchUrlExternal)`; `SettingsRow(glyph notes, settingsSendFeedback, external)` -> `onsetFeedbackUrl` = `'https://github.com/JLmehdi92/onset/issues/new/choose'`; `SettingsRow(glyph link, settingsTwitchHelp, external)` -> `twitchHelpUrl` = `'https://link.twitch.tv/help'`; `SettingsRow(glyph list, settingsLicenses, chevron)` -> `showOnsetLicenses`.

`onsetLegalese(l)` = `l.settingsLegalese(url: onsetRepoUrl)` (AGPL section 5 notice: licence, no warranty, source location). `showOnsetLicenses(context)` = Flutter `showLicensePage(applicationName: 'ONSET', applicationLegalese: onsetLegalese)` — ONSET's notice first then every package licence.

`clearImageCache(context)`: `HapticFeedback.lightImpact()`, `CustomCacheManager.instance.emptyCache()` (image cache key `libCachedImageData`, 30-day stale period, 10000 objects max), `CustomCacheManager.removeOrphanedCacheFiles()`, then a SnackBar with `AlertMessage(settingsCacheCleared, centered: false)`.

`confirmResetSettings(context, settingsStore)`: `confirmSettingsAction(title settingsResetTitle, message settingsResetMessage, confirm settingsResetConfirm)` (danger); on confirm `HapticFeedback.heavyImpact()`, `settingsStore.resetAllSettings()` (everything except the app language and its prompt version), SnackBar `AlertMessage(settingsResetDone)`.

### lib/screens/settings/stores/auth_store.dart

The session store (1574 lines; MobX `class AuthStore = AuthBase with _$AuthStore`, generated part `auth_store.g.dart` — never hand-edited). Constructor: `AuthBase({required TwitchApi twitchApi, FlutterSecureStorage storage = const FlutterSecureStorage(), TwitchWebTokenService webTokenService = const TwitchWebTokenService(), Future<void> Function()? loadTwitchPage, bool? isAndroid})`; it creates `user = UserStore(twitchApi)`, `_isAndroid = isAndroid ?? Platform.isAndroid`, `_loadTwitchPage = loadTwitchPage ?? _loadTwitchPageInWebView`.

**`enum TokenNotice { foreignToken, sessionEnded }`** — one-time notices (labels `authForeignTokenNotice`, `authSessionEndedNotice`, shown as a snackbar by the app shell, which then calls `clearTokenNotice()`): `foreignToken` = the session token was issued to another client id (stored by an older version or pasted) so some features may not work; `sessionEnded` = Twitch refused the stored login at launch (expired/revoked/its app deleted) — logged out and told to log in again.

**`LoginAttempt`** — one open login page: private `_state` (the OAuth `state` it expects), `_captured` (redirect brought its token), `_outcome` (`Future<bool>` of the login that token started). Public getter `captured`. Several may be open at once (a login over the onboarding's); each only takes its own token.

**Secure-storage keys** (all in `FlutterSecureStorage`; PC: OS keyring, see PC equivalent): `default_token` (logged-out app token), `default_token_client_id` (the proxy application's client id that token belongs to), `user_token` (exposed as `AuthBase.userTokenKey` for the go-live background isolate), `user_token_client_id` (exposed as `userTokenClientIdKey`; only when the user token is another app's), `extra_login_scopes` (space-separated extra channel-tool scopes), `twitch_web_token` (the twitch.tv `auth-token` cookie), `user_id` (last logged-in account id), `foreign_token_notice_user` (account already told about its foreign token).

**Scopes.** `loginScopes` (exact, space-separated): `chat:read chat:edit user:read:follows user:read:blocked_users user:manage:blocked_users user:manage:chat_color moderator:manage:banned_users moderator:manage:chat_messages moderator:manage:chat_settings moderator:manage:warnings moderator:read:followers user:manage:whispers user:read:emotes user:read:chat clips:edit moderator:manage:announcements moderator:manage:shoutouts moderator:manage:shield_mode moderator:manage:automod moderator:manage:blocked_terms moderator:manage:unban_requests moderator:manage:suspicious_users moderator:read:moderators moderator:read:vips user:write:chat`. `channelToolScopes` = {`channel:manage:moderators`, `channel:manage:vips`, `channel:manage:broadcast`, `channel:edit:commercial`, `channel:manage:raids`, `channel:manage:polls`, `channel:manage:predictions`, `channel:manage:redemptions`}. `requestedScopes` = union of login scopes and `_extraScopes`, joined by spaces. `requestScopes(set)` adds only members of `channelToolScopes` and persists them (errors logged `'Extra scopes not saved: …'`). An older token keeps its scopes; features needing newer ones check `getTokenScopes()` and offer to reconnect instead of logging everyone out.

**Observable state** (`@readonly`): `_token`, `_tokenClientId` (null for this app's tokens), `_isLoggedIn`, `_twitchWebToken`, `_webSessionExpired`, `_error` (string or null), `_tokenNotice`. Private: `_tokenIsValid`, `_reconnectTimer`, `_reconnectAttempts` (max `_maxReconnectAttempts = 5`), `_authEpoch` (bumped on every logout/account switch), `_webSessionEpoch` (bumped at logout start and end), `_signedInWith`, `_openLogins` set, `_loginOf` (`Expando<LoginAttempt>` per WebView controller), `_loginGeneration`, `_loginsInFlight`, `_sessionChange` (a promise chain serialising session changes via `_exclusive`), `_appToken`, `_appTokenAskedAt`, `_lastWebTokenRenewal`, `_webSessionRefresh`, `_hiddenWebView`, `_interactiveLogins` (public getter `interactiveLogins`), `_sessionEndListeners`.

**`headersTwitch`** (plain getter so the token never appears in MobX `toString`): `{'Authorization': 'Bearer $_token'` only when a token exists, `'Client-Id': _tokenClientId ?? clientId}` — never sends `Bearer null`.

**`isAnonymous`** = `!_isLoggedIn && (_token == null || _token == _appToken)` (false while a user session reconnects).

**`init()`** (@action): reads `user_token`, `extra_login_scopes` (filtered to channel tool scopes), `twitch_web_token`. No user token -> `_useAppToken()`. Else `twitchApi.checkToken(token)` -> `_tokenIsValid = !isInvalid`, `_tokenClientId = check.clientId`, saves the client id when valid; an `ApiException` (network, timeout, 5xx — indeterminate) sets logged-out, clears `_signedInWith`, starts the reconnect loop and returns. Invalid -> `logout()` then `_tokenNotice = sessionEnded`. Valid -> `user.init()`; when details load: `_isLoggedIn = true`, stop reconnect, `_rememberUser(id)`, foreign-token notice if `check.isForeign`, and `unawaited(ensureTwitchWebToken())` (keep the 2K credential fresh without delaying startup). Then `Telemetry.setCustomKey('is_logged_in', …)` and `_error = null`. Any other exception -> `_error = e.toString()` (drives the "Unable to reach Twitch / Reconnect" UI).

**Logged-out app token.** `_useAppToken()`: reads `default_token` and `default_token_client_id`; a token stored WITHOUT its client id (older builds minted it for the login application, whose app tokens could reach users' private events) is discarded. A candidate is kept only if `_appTokenIsGood` = `checkToken` says foreign, no user, and same client id. Otherwise `_fetchAppToken()`: `twitchApi.getDefaultToken()` = `GET <TOKEN_PROXY_URL>/app-token` (6 s deadline, no redirects followed, no session headers, never a login prompt; response JSON `{access_token: ^[A-Za-z0-9]{16,128}$, client_id: ^[A-Za-z0-9_-]{1,64}$}`), then `checkToken`. Refused when: invalid ("Twitch refuses it"), valid for THIS app ("it is the login application's (check the Worker's credentials)"), has a user ("it is a user's token"), or client id differs from what the proxy named. Accepted tokens are written to `default_token` / `default_token_client_id`. Failure returns null: the app runs without a token (Helix-dependent logged-out features fail quietly; not an `error`). `appTokenRetryInterval = 1 minute`. `retryAppToken({refused})` (called by `UnauthorizedInterceptor` on a logged-out 401): only when anonymous and at most once per minute; if a token is in use and the refused `Authorization` equals `'Bearer $current'`, re-check it; if still good keep it (the call needed a login), else drop it (memory + both keys) inside `_exclusive` and fetch a new one, installed only if still undecided (`!_isLoggedIn`, same epoch, same login generation, no login in flight, no token).

**Interactive login (OAuth implicit grant).** `beginLogin()` creates and registers a `LoginAttempt`; `endLogin(attempt)` clears its state/captured/outcome and unregisters it. `authorizationUri(attempt)`: `state` = base64url of 32 `Random.secure()` bytes with `=` stripped; registers the attempt with that state (any earlier state for it is no longer accepted — "Try again" makes a new one) and returns `https://id.twitch.tv/oauth2/authorize?client_id=<CLIENT_ID>&redirect_uri=https://twitch.tv/login&response_type=token&scope=<requestedScopes>&force_verify=true&state=<state>`. `startAuthorization()` (visible for testing) = `authorizationUri(beginLogin())`. `retryLogin(controller)` reloads the controller with a new authorization URI (reusing its attempt or making one). `closeLogin(controller)` ends its attempt.

`_redirectToken(request, attempt)`: only a main-frame navigation whose URL parses to scheme `https`, host exactly `twitch.tv`, port 443, no user-info, path exactly `/login`; the fragment is split as a query string (`FormatException` -> ignore); requires non-empty `access_token` and a `state`; candidates are the given attempt (if still open) or all open logins; the state is compared in constant time (`_sameText`: length check then XOR-accumulate over code units); on match the state is consumed (`_state = null`) and `_captured = true`. Anything else (frames, other host/path, injected redirect with someone else's token) is ignored.

`handleNavigation({request, routeAfter, onTokenCaptured, onSignedIn, onNotSignedIn, attempt, pageCookies})` — always returns `NavigationDecision.navigate`. If a token is captured: `owner._outcome = _loginWith(token)` and `onTokenCaptured(outcome)` (the page can show "Signing you in…"; it never receives the token). If the main frame navigates to exactly `https://www.twitch.tv/?no-reload=true` (Twitch signed the WebView in after the redirect): take the outcome of this attempt (or the first open login's) and, not awaited, when it resolves true call `harvestTwitchWebToken(pageCookies: off-Android the page's document.cookie)`, when false `_clearJarIfForeign()`; then if not signed in (`attempt.captured` false) call `onNotSignedIn`; then `onSignedIn()` if given, else if `routeAfter` pop the navigator and push `routeAfter`, else pop. `_loginWith(token)` = `login(token)` then true only if logged in with exactly that token (`_signedInWith == token`).

`createAuthWebViewController({routeAfter, onTokenCaptured, onSignedIn, onNotSignedIn, onPage, onError})` — new attempt; `WebViewController` with unrestricted JavaScript and a desktop-browser-like user agent so Google sign-in is not blocked (`disallowed_useragent`): iOS `Mozilla/5.0 (iPhone; CPU iPhone OS 18_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1`, otherwise `Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Mobile Safari/537.36`. Navigation delegate: `onNavigationRequest` -> `handleNavigation(..., pageCookies: runJavaScriptReturningResult('document.cookie'))`; `onPageStarted`, `onUrlChange`, `onPageFinished` report the page URI via `onPage` (the UI shows only the host — the URL carries the token); `onWebResourceError` logs `'Auth WebView error: …'` and calls `onError`; `onPageFinished` also injects JS that observes DOM mutations and, when `.fAVISI` (Twitch's scope list) appears, sets `maxHeight = '20vh'` and `overflow = 'auto'` then disconnects. Finally loads `authorizationUri(attempt)`.

**`login({required String token, bool acceptAnyApp = false})`** (@action): `generation = ++_loginGeneration`, captures `_authEpoch`, `_loginsInFlight++` (decremented in finally). `previousId = user.details?.id ?? stored user_id`. Validation: with `acceptAnyApp` (pasted/clipboard token) `checkToken` must not be invalid (foreign allowed); otherwise `validateToken` must be true (issued to THIS client id — an injected redirect can't sign you into someone else's account). Reads the user with that token (`getUserInfo(token, clientId: foreign client if any)`, quiet, no session headers). Then inside `_exclusive`: abort if a newer login or a logout happened; `switching = previousId != null && details.id != previousId`; disk first — remember previous `user_token`/`user_token_client_id`, write the client id (delete when null) then the token (restore the client id and rethrow on failure); when switching delete `twitch_web_token` (restore both on failure); `_rememberUser(id)`. Then memory — when switching `_authEpoch++` and `_twitchWebToken = null`; set token, client id, `_tokenIsValid = true`, `await user.init(details: details)`, `_interactiveLogins++`, `_isLoggedIn = true`, `_signedInWith = token`, `_error = null`, telemetry key, stop reconnect; if switching on Android harvest the jar at once; foreign notice if foreign. Any failure logs `'Login failed: <runtimeType>'` and leaves the previous session intact in memory and on disk.

**`logout()`** (@action): first `_authEpoch++`, `_webSessionEpoch++`, stop reconnect, then `_exclusive(_endSession)`. `_endSession`: `_forgetWebSession()` (release hidden WebView, clear web token + expired flag, `WebViewCookieManager().clearCookies()`, the native jar `clearCookies()`, delete `twitch_web_token`; never throws); run every session-end listener (`addSessionEndListener`; errors logged `'A session end step failed'`); read `user_token` and its client id and fire-and-forget `_revoke` (`POST https://id.twitch.tv/oauth2/revoke` form-encoded `client_id=<token's app or CLIENT_ID>&token=…`, 5 s timeout, never throws); delete `user_token`, the client id key, `user_id`; null token/client id; `user.dispose()`; `_useAppToken()` (an offline `ApiException` keeps the stored app token and the logout continues); `_isLoggedIn = false`, `_signedInWith = null`, telemetry; finally `_webSessionEpoch++` again. NOT unconditional: everything after `_forgetWebSession()` and the listeners sits in ONE `try/catch(debugPrint)`; if reading `user_token` throws (keystore error) or `_useAppToken()` throws anything other than `ApiException`, the revoke, the key deletions, nulling the token, `user.dispose()`, `_isLoggedIn = false` and the telemetry key are all skipped — the session stays logged in in memory (only the final epoch bump runs). See Known Android defects.

`_clearJarIfForeign()`: only when no login in flight, logged in, details loaded; reads the jar's cookie, asks `tokenUserId`; clears every cookie (`_clearJar`) only when the cookie belongs to a different account than the session's.

**Reconnect loop** `_startReconnectLoop()`: `Timer.periodic(10 s)`; skips ticks while a login is in flight; increments attempts; reads `user_token`; after more than 5 attempts logs telemetry `'Auth reconnection exhausted after 5 attempts'` and `_logoutFromReconnect`; no stored token -> stop; `checkToken` invalid -> `_logoutFromReconnect`; valid -> inside `_exclusive` (unless a login/logout intervened) restore token + client id, `user.init()`, and when details load set logged in, clear error, stop the loop, remember the user, foreign notice. `ApiException`s keep trying. `_logoutFromReconnect(generation, epoch, checked)` logs out only if nothing changed and the saved token is still the one checked.

**twitch.tv web session token** (the `auth-token` cookie; unlocks 1440p HEVC/AV1 "enhanced broadcast" renditions through GQL, which only accepts the web client's tokens). `harvestTwitchWebToken({pageCookies})`: reads via the Android `MethodChannel('onset/cookies')` `getCookie(url: 'https://www.twitch.tv')` (or, off Android, from the page's `document.cookie` result — JSON-quoted string accepted) and parses the `auth-token` pair. Abort if the epoch changed. Miss: on Android `_webSessionExpired = (_twitchWebToken != null)`; never clears a stored token. Same token -> not expired, true. New token: accepted only if `_isSessionAccounts` (`GET https://id.twitch.tv/oauth2/validate` with `Authorization: OAuth <cookie>` returns the logged-in account's `user_id`) and the web epoch is unchanged; then stored via `setTwitchWebToken`; if a logout raced the write, the value is wiped from memory and storage. `refreshTwitchWebSession()` (Android only; shared in-flight future): when logged in, loads twitch.tv in a detached, never-mounted WebView (`_loadTwitchPageInWebView`: unrestricted JS, the Android Chrome UA, navigation allowed only to `about:blank` or https `twitch.tv`/`*.twitch.tv` (`TwitchWebTokenService.isTwitchPageUrl`), completes on page finished or resource error, 20 s timeout) then harvests; finally points the hidden WebView at `about:blank`. `renewTwitchWebToken()` (after Twitch refused the stored token; Android only): waits for a running refresh instead of starting one (returns the new token only if it changed); otherwise throttled by `_webTokenRenewalCooldown = 5 minutes`; refreshes; if the token is missing or unchanged sets `_webSessionExpired = true` (UI asks the viewer to reconnect twitch.tv) and returns null. `ensureTwitchWebToken()` = harvest, else refresh. `setTwitchWebToken(token)` trims; blank -> null (deletes the key), else writes the key and clears the expired flag.

**`showBlockDialog(context, {targetUser, targetUserId, BlockSource? source})`** — `isBlocked` from `user.blockedUsers`; `OnsetAlertDialog(title: settingsUnblock/settingsBlock, message: settingsUnblockMessage(name)/settingsBlockMessage(name), content: when blocking a `BlockReasonPicker` held in a `StatefulBuilder`, actions [TextButton `commonCancel` pop, FilledButton `commonYes` -> `user.unblock(targetId)` or `user.block(targetId, displayName, reason, source)`, then pop])`.

### lib/screens/settings/stores/user_store.dart

`UserStore = UserStoreBase with _$UserStore` (80 lines; MobX, generated `user_store.g.dart`). Holds `twitchApi`, `@readonly UserTwitch? _details` (the logged-in user) and `@readonly _blockedUsers = ObservableList<UserBlockedTwitch>()`, plus a `ReactionDisposer? _disposeReaction`.

- `init({UserTwitch? details})` (@action): `_details = details ?? await twitchApi.getUserInfo()` (Helix `GET https://api.twitch.tv/helix/users` with the session headers; a login passes the already-read details so the switch is atomic); disposes the previous reaction; when an id exists starts — NOT awaited, a huge list must not block the UI — `twitchApi.getUserBlockedList(id)` (Helix `GET /users/blocks?broadcaster_id=<id>&first=100[&after=<cursor>]`, all pages) and replaces `_blockedUsers` with the result; installs an `autorun` that keeps `_blockedUsers` sorted by `userLogin` (plain `compareTo`, case-sensitive ordinal). Failure/switch behaviour: `init()` does NOT clear `_blockedUsers` before the fetch, the fetch has no `catchError` (a failure is an unhandled async error), and a login account switch calls `user.init(details:)` without `dispose()` — so the previous account's blocked list and count stay on screen until the fetch succeeds, or forever if it fails. `refreshBlockedUsers` dereferences `_details!.id` and throws when logged out.
- `block({targetId, displayName, BlockReason? reason, BlockSource? source})` (@action): `twitchApi.blockUser(userId, reason, source)` = Helix `PUT /users/blocks?target_user_id=<id>[&source_context=chat|whisper][&reason=harassment|spam|other]`; on success appends `UserBlockedTwitch(targetId, displayName, displayName)` (login set to the display name until the next refresh).
- `unblock({targetId})`: Helix `DELETE /users/blocks?target_user_id=<id>`; on success `refreshBlockedUsers()`.
- `refreshBlockedUsers()`: re-reads the whole list (uses `_details!.id`).
- `dispose()` (@action, at logout): `_details = null`, clears the list, disposes the sort reaction.

`BlockReason { harassment, spam, other }` and `BlockSource { chat, whisper }` live in lib/apis/twitch_api.dart. Scopes needed: `user:read:blocked_users`, `user:manage:blocked_users`.

### lib/screens/settings/stores/twitch_tv_session_store.dart

`TwitchTvSessionStore = TwitchTvSessionBase with _$TwitchTvSessionStore` (340 lines; MobX, generated `.g.dart`). A second Twitch session obtained with the OAuth **device authorization grant** for Twitch's own TV app client id `kTwitchTvClientId = 'ue6666qo983tsx6so1t0vnawi233wa'`; `TwitchTvSessionInterceptor` attaches it to GQL user mutations that Twitch refuses from third-party clients (headers `Client-Id: ue6666qo983tsx6so1t0vnawi233wa`, `Authorization: OAuth <access token>`, `X-Device-Id: <deviceId>`, `Client-Session-Id: <clientSessionId>`) and reports a 401 back via `markRejected(token)`.

Enums: `TwitchTvSessionStatus { disconnected, connected, expired }`; `TwitchTvConnectOutcome { connected, expired, denied, wrongAccount, cancelled, failed }`. `typedef TwitchTvWait = Future<void> Function(Duration)` (injectable delay). Constructor `({required TwitchTvAuthService auth, required String? Function() viewerId, storage = const FlutterSecureStorage(), Random? random (default Random.secure()), TwitchTvWait? wait (default Future.delayed)})`; `clientSessionId = _hex(16)` (32 hex chars, new each launch). Constants: `sessionKey = 'twitch_tv_session'` (secure storage JSON `{"access", "refresh"?, "user", "device"}`), `promptedKey = 'twitch_tv_prompted'`, `refreshRetry = 30 s`, `_checkAttempts = 3`.

State: `@readonly _session`, `@readonly _status = disconnected`, `_accountId`, `_generation` (bumped to cancel), `_refreshing` (shared future), `_forgottenTokens` (never re-adopted). Getters: `hasAccount`, `isConnected`, `accessToken`, `credentials` (null unless connected AND session user == attached account == current viewer id).

`attach(accountId)` (@action): no-op when already attached with a session; else bump generation, set account, clear session, disconnected; decode the stored session; drop it if its token was forgotten; if it belongs to another user revoke + delete; else `_adopt`. `_adopt`: set connected optimistically, `auth.validate(token)` (`GET https://id.twitch.tv/oauth2/validate` with `Authorization: OAuth <t>`; 401 -> invalid; non-200 -> unknown; valid only when `client_id` is the TV client id); valid for the same user or unknown -> keep; valid for another user -> `forget()`; invalid -> `_refreshOnce`. (A stored session whose token is in `_forgottenTokens` is DELETED from storage, not merely ignored.) `markRejected(token)` acts only when `isConnected` and `token == _session.accessToken`, then `_refreshOnce(_generation)`. `detach()`: bump generation, clear account/session, disconnected.

Refresh (`_refreshOnce` shares one in-flight refresh): loop — no refresh token -> expired; `auth.refresh(refreshToken)` (`POST https://id.twitch.tv/oauth2/token` form `client_id=<tv>&grant_type=refresh_token&refresh_token=…`; 200 with a grant -> granted, 4xx -> rejected, otherwise unreachable); rejected -> expired; unreachable -> wait 30 s and retry; granted -> `_renew`: validate the new token (invalid or another user -> expired), `session.withGrant` (keeps the old refresh token if none returned), write, connected.

Device flow: `requestCode()` = `auth.requestDeviceCode()` (`POST https://id.twitch.tv/oauth2/device` form `client_id=<tv>&scopes=channel_read chat:read user_blocks_edit user_blocks_read user_follows_edit user_read`; parses `device_code`, `user_code` matching `^[A-Za-z0-9-]{4,16}$`, `expires_in` > 0, `interval` (default 5 s, minimum 1 s)). `approve(code, {isCancelled})`: needs an attached account (else failed); loop: wait `interval`, check cancel, `auth.pollToken(code)` (`POST /oauth2/token` form `client_id`, `device_code`, `grant_type=urn:ietf:params:oauth:grant-type:device_code`; expired locally -> Expired; 200 -> Granted; else by the error `message`: authorization_pending -> Pending, slow_down -> SlowDown, denied -> Denied, expired / invalid device -> Expired, other -> Failed); if cancelled after a grant, revoke it. Pending -> reset failures; SlowDown -> +5 s interval; Expired -> expired; Denied -> denied; Failed -> after 3 consecutive -> failed; Granted -> `_store`. `_store`: `_checkGrant` (validate, retrying up to 3 attempts 2 s apart while unknown); cancelled or account changed -> revoke, cancelled; not valid -> revoke, failed; another user -> revoke, `wrongAccount`; else new `TwitchTvSession(access, refresh, userId: account, deviceId: existing or _hex(16))`, bump generation, write, connected. Note the write happens BEFORE the generation re-check: if superseded during the write (detach/forget/another attach), it returns `cancelled` but the new session stays written on disk (Known Android defects). In `approve`, the interval starts at `code.interval` and the wait precedes every poll, including the first; SlowDown both resets `failures = 0` and adds 5 s. `_renew` accepts an `unknown` validation (only `invalid`, or a non-null different user id, marks expired).

`forget()`: bump generation, clear, disconnected, remember + revoke the token (`POST /oauth2/revoke` form `client_id=<tv>&token=…`, errors ignored), delete `sessionKey`. `endAccountSession()` (logout): clear account, forget, delete `promptedKey`. `shouldPrompt()` = stored prompted flag != 'true'; `markPrompted()` writes 'true'. Storage errors are logged (`'Reading/Saving/Forgetting the Twitch session failed'`) and swallowed.

### lib/screens/settings/stores/settings_store.dart

The global preferences store (1243 lines): `@JsonSerializable() class SettingsStore extends _SettingsStoreBase with _$SettingsStore` (MobX observables + json_serializable; generated `settings_store.g.dart`, never edited). Every field, its persisted JSON name, default, allowed values, UI and readers are in the **## Settings** table above; this section records the store's mechanics.

**Constants.** `kTelemetryConsentVersion = 1`, `kLanguagePromptVersion = 1`, `readableNameColorContrast = 4.5`, `highNameColorContrast = 7.0`, `minLandscapeChatModes = 2`, `maxHiddenPinnedChats = 50`; every `default*` static (e.g. `defaultAccentColor = 0xffc8ff3d`, `defaultBufferProfile = BufferProfile.ultra`, `defaultCollapseGiftBombs = true`, `defaultShareCrashLogsAndAnalytics = false`, `defaultLandscapeChatModes = [overlay, column, hidden]`).

**Load** (`SettingsStore.fromJson(json)`, called in main.dart with `jsonDecode(prefs.getString('settings') ?? '{}')` from SharedPreferences): generated decoding with `defaultValue`s for missing keys and `unknownEnumValue` fallbacks where declared (themeType→system, startTab→following, followedSort→viewers, clipDiscovery→all, appLanguage→system, captionSize→medium, captionBackground→black, portraitChatHeight→low, playerEngine→ivs, liveCatchUpMode→speedUp, bufferProfile→**standard**, vodAutoplay→always, timestampType→disabled, celebrationsOnVideo→full; `landscapeCutout` has none). Custom readers: `startTab` via `HomeTab.readStored` (legacy `'top'`→`live`, `'search'`→`browse`); `portraitChatHeight` via `readPortraitChatHeight` (stored value, else `custom` when `portraitVideoScale` is a number ≠ 1.0, else default); `landscapeChatModes` via `landscapeChatModesFromJson` (null→defaults; else the known names in enum order). Then two one-time migrations run: `_applyChatSyncDefault()` — if `chatSyncDefaultApplied` is false, set it true and, when `chatDelay == 0`, force `autoSyncChatDelay = true` (a manual delay is kept; later "off" sticks); `_applyTelemetryConsentVersion()` — if `telemetryConsentVersion < 1`, set it to 1 and force `shareCrashLogsAndAnalytics = false` (old builds defaulted it on; that was not consent). `languagePromptVersion` decodes to 0 whenever the key is missing — an old install AND a first launch (main.dart always goes through `fromJson`, with `'{}'` on a fresh install); it becomes 1 only via `chooseLanguage` (a new install answers on the onboarding's Intro, an old one through Home's one-time question). Likewise `telemetryConsentVersion` decodes to 0 and is migrated to 1 at once. The field initializers (1/1) only apply to the bare `SettingsStore()` constructor, which the app never uses at launch. Decoding is lenient ONLY for enums: every other field is a hard cast in the generated decoder (`as bool?`, `(as num?)?.toInt()/toDouble()`, `as String?`, list elements `e as String`, `notInterestedChannels as Map<String, dynamic>?` with `e as String` values, `secondaryTabs` via `PersistedChatTab.fromJson(e as Map<String, dynamic>)`, `landscapeChatModes as List?`), and `jsonDecode` of a corrupt file throws too; main.dart has no try/catch, so a wrong-typed value or a corrupt file crashes startup (see Known Android defects). `showDeletedMessages` is stored under the new key `revealDeletedMessages` (the old `showDeletedMessages` key, mostly a `false` nobody chose, is ignored, so everyone sees deleted messages once).

**Save** (`toJson`, via lib/services/settings_persistence.dart `persistSettings`): an `autorun` with `delay: 300 ms` (`kSettingsSaveDelay`) encodes the whole store and writes it to SharedPreferences key `settings` only when the JSON changed; a separate reaction writes IMMEDIATELY when `shareCrashLogsAndAnalytics`, `telemetryConsentVersion`, `appLanguage` or `languagePromptVersion` change (other isolates — the go-live worker — read them from disk); an `AppLifecycleListener(onHide, onPause)` flushes at once. Not persisted: `chatOnlyForPage`, `syncedChatDelay` (`includeFromJson/ToJson: false`).

**Derived state and helpers.**
- `showVideo` getter = `savedShowVideo && !chatOnlyForPage`; setter (in `runInAction`) clears `chatOnlyForPage` and sets `savedShowVideo`.
- `isNewFeature(id)` = `!seenNewFeatures.contains(id)`; `markFeatureSeen(id)` appends once (new list).
- `celebrationsSubtle({landscape})` = `celebrationsOnVideo == subtle || (landscape && !alertsOverLandscapeVideo)`.
- `markNotInterested(userId, name)` / `clearNotInterested(userId)` — copy-on-write map updates.
- `chooseLanguage(lang)` sets `appLanguage` and `languagePromptVersion = 1`.
- `nameColorContrast` (@computed) = 7.0 if `increaseChatContrast`, else 4.5 if `readableNameColors`, else null.
- `effectiveChatDelay` (@computed) = `autoSyncChatDelay ? syncedChatDelay : chatDelay`.
- `showsNoticesIn(channelId)` = `showUserNotices && !noticesHiddenChannelIds.contains(channelId)`.
- `switchableLandscapeChatModes` (@computed) = chosen modes in enum order, or the defaults when fewer than 2.
- `setLandscapeChatMode(mode, {on})`: edits a set of the switchable modes; refuses to go below 2; stores in enum order; if the mode turned off is the current one, `showLandscapeChatMode(nextLandscapeChatMode(current, modes))`.
- `landscapeChatMode` getter: `!fullScreen` → column; `fullScreenChatOverlay` → overlay; else hidden. `showLandscapeChatMode(mode)`: `fullScreen = mode != column`; when not column `fullScreenChatOverlay = mode == overlay`.
- `nextLandscapeChatMode(current, switchable)`: walks `[overlay, column, hidden]` cyclically from the current one and returns the first switchable mode (current if none).
- `hidePinnedChat(pinId)`: appends once, keeping only the last 50.

**Resets** (all `@action`): `resetGeneralSettings` (theme, accent, large card, thumbnails, stream language, hidden labels, start tab, followed sort, launchUrlExternal, mentionNotifications, clipDiscovery→all, hideViewerCount→false — NOT confirmExternalLinks, NOT the language); `resetVideoSettings` (all video fields incl. showVideo via its setter, captions, engine, catch-up, buffer, autoLatency, vodAutoplay, overlay trio, plus dataSaver→false, streamPreviews→true, mutePreviews→true, alertsOverLandscapeVideo→true); `resetChatSettings` (every chat field incl. syncedChatDelay→0, chatBubbleEvents, noticesHiddenChannelIds, landscape fields, landscapeChatModes, muted words, filters, providers, recent messages, persistChatTabs, secondaryTabs, showModActionsInChat→true); `resetOtherSettings` (consent→false, consent version→1); `resetGlobalConfigs` (fullScreen, fullScreenChatOverlay, pinnedChannelIds, hiddenChannelIds, hiddenPinnedChatIds); `resetAllSettings` = all five. Never reset by any of them: `appLanguage`, `languagePromptVersion`, `confirmExternalLinks`, whisper mute/archive lists, `followedVideosSeenAt`, `pointsIntroSeen`, `appOpens`, feedback prompt fields, `seenNewFeatures`, `notInterestedChannels`, `animatedEmotesCalloutShown`, `chatSyncDefaultApplied` (and the transient `chatOnlyForPage`, cleared only through the showVideo setter).

**Enums declared here**: `AppLanguage { system, en, fr }` with `locale` (null / `Locale('en')` / `Locale('fr')`); `ThemeType { system, light, dark }`; `HomeTab { following, live, clips, browse }` + `readStored`; `FollowedSort { viewers, recent, name, category, recommended }` (recommended = Twitch's server ranking, not available in Helix); `ClipDiscovery { all, featured }`; `TimestampType { disabled, twelve, twentyFour }`; `LandscapeCutoutType { none, left, right, both }`; `LandscapeChatMode { overlay, column, hidden }`; `PortraitChatHeight { low, medium, high, custom }` with `presets = [low, medium, high]`; `LiveCatchUpMode { speedUp, jumpToLive }`; `BufferProfile { standard, ultra }`; `VodAutoplay { always, wifiOnly, never }`; `CelebrationsOnVideo { full, subtle }`; `PlayerEngine { ivs, nativeLowLatency, twitchWeb }`. Imported: `CaptionSize`, `CaptionBackground` (captions.dart), `PersistedChatTab` (chat_tabs_store.dart).

PC: one `Settings` struct with `serde` (`#[serde(default)]` per field with the JSON-decode defaults — NOT the Dart field initializers: `languagePromptVersion` defaults to 0 and `telemetryConsentVersion` to 0 (then migrated to 1 with consent off); every other field's decode default equals its initializer —, tolerant per-field decoding (a wrong-typed or unknown value falls back to that field's default instead of failing the whole file; a corrupt file loads all defaults and is backed up), `rename` for `showVideo`/`revealDeletedMessages`, lenient enum decoding with the listed fallbacks, including `landscapeCutout` → none), stored as JSON in `%APPDATA%\ONSET\settings.json` (same key names so a migrated file reads), written debounced 300 ms plus immediately for consent/language and on window hide/close.

### lib/screens/settings/widgets/settings_page.dart

The settings navigation and page chrome (935 lines).

**`enum SettingsPageId`** (each carries a `SettingsGlyphKind glyph`): `general(general)`, `video(video)`, `chat(chat)`, `notifications(bell)`, `other(other)`, `account(user)`, `blocked(ban)`, `chatFilters(filter)`, `notInterested(list)`, `editProfile(user)`. Static lists: `customize = [general, video, chat, notifications]` (phone's "Customize" group and Profile's "Settings" group — Other is not a row there because its groups are inlined) and `sections = [general, video, chat, notifications, other]` (tablet side column). `isSection` = not chatFilters / notInterested / editProfile (those open as sub pages over their parent section on a tablet). `needsAccount` = account, blocked, editProfile. Titles/descriptions come from `lib/l10n/enum_labels.dart` (`SettingsPageIdLabel.title/description`): titles `settingsPageGeneral, settingsPageVideo, settingsPageChat, settingsPageNotifications, settingsPageOther, settingsPageAccount, settingsPageBlocked, settingsPageChatFilters, settingsPageNotInterested, editProfileTitle`; descriptions `settingsPage{General,Video,Chat,Notifications,Other,Account,Blocked}Description`, `null` for chatFilters/notInterested/editProfile.

**`typedef SettingsOpener = void Function(SettingsPageId id, WidgetBuilder builder)`.**

**`SettingsPaneScope extends InheritedWidget`** — `onOpen`, `columns = 2`, `title`, `description`, `backLabel`, `onBack`. Present only inside the tablet pane. `updateShouldNotify` compares all six fields.

**`openSettingsPage(context, {id, builder})`** — if a `SettingsPaneScope` is above, calls `pane.onOpen(id, builder)` and returns a completed future; otherwise pushes `MaterialPageRoute(settings: RouteSettings(name: settingsRouteName(id)), builder: SettingsScaffold(title: id.title(l10n), body: builder(ctx)))`, completing when popped. The title is re-read at each build so a language switch on General renames the open page instantly. `settingsRouteName(id) = 'Settings/${id.name}'` (language independent for analytics).

**`launchSettingsLink(url, {required bool external})`** — `launchUrl(Uri.parse(url), mode: external ? LaunchMode.externalApplication : LaunchMode.inAppBrowserView)`.

**`SettingsGroupsView({children, footer, onRefresh})`** (Stateful; owns a `ScrollController` and a map of `GlobalKey` anchors `'group $index'`). Phone (no pane scope): `ListView` with padding `fromLTRB(16 + padL, padTop + 16, 16 + padR, padBottom + 32)` (padTop already includes the 56 dp header from `SettingsScaffold`), each child wrapped in bottom padding 22, then the footer. `physics: AlwaysScrollableScrollPhysics()` only when `onRefresh` is set; then the whole thing is wrapped in `RefreshIndicator.adaptive(onRefresh)` — this applies to the tablet pane's ListView as well (pull to refresh works in both layouts). Tablet pane: `ListView(padding: fromLTRB(4, 4, 8, 40))` with, in order:
1. if `pane.title` — a Column(spacing 6, bottom padding 16): either a back button (when `onBack`: `TextButton.icon` shifted `Offset(-6, 0)`, foreground `colors.body`, min size `0x44`, padding left 6 right 14, StadiumBorder, text 14 sp w600, icon `chevronLeft` strokeWidth 2, label `backLabel ?? commonBack`) or the eyebrow `settingsTitle.toUpperCase()` in `SettingsText.section` secondary colour; then the title as a semantics header (30 sp, w800, letterSpacing -0.9, height 1.1, text colour); then the description if non-empty (`SettingsText.body`, height 1.4, secondary).
2. Jump chips (the Wrap sits in `Padding(bottom: 20)`; `_jump` is a no-op when the anchor has no built context) when more than 2 groups have titles: `Semantics(label: settingsJumpToGroup, container)`, `Wrap(spacing 8, runSpacing 8)` of `_JumpChip(label: group title, onTap: _jump(index))`. `_jump` = `Scrollable.ensureVisible(anchor, duration: reduce ? 0 : 360 ms, curve: OnsetMotion.standard)`.
3. The groups (in the pane every group is wrapped in `Padding(bottom: 22)` keyed with its `GlobalKey` anchor): one stretched Column when `columns < 2` or fewer than 2 groups; else a `Row(start, spacing 20)` of two `Expanded` Columns split by `_balancedSplit`.
4. The footer.
`_balancedSplit(groups)` — weight of a `SettingsGroup` is its `weight` (row count, see kit), any other widget 1; walks split points 1..n-1 keeping the order and picks the one minimising `|total - 2*left|` (first minimum wins; default 1) — like CSS columns.

**`_JumpChip`** — Semantics button (label, onTap, excludeSemantics), PressScale, opaque GestureDetector, `Container(height 36, horizontal padding 14, ShapeDecoration(color: colors.card, StadiumBorder(side: colors.buttonRing hairline)))`, child `Align(widthFactor: 1)` so the pill hugs its label, text 13 sp w600 `colors.body`.

**`SettingsScaffold({title, body, onBack})`** — `headerHeight = 56`. `AnnotatedRegion<SystemUiOverlayStyle>(theme.systemOverlayStyle)` -> `Scaffold(backgroundColor: scaffoldBackground)` -> Stack: the body fills, receiving a `MediaQuery` whose top padding is `padding.top + 56`; over it a top header `DecoratedBox(color: ground @ 0.96, bottom border hairline colors.hairline)` — deliberately no blur because the page can be pushed over the playing video and a blur would sample it mid-transition. Header padding: top = status bar, left = padL + 4, right = padR + 16; `SizedBox(height 56, Row(spacing 2, [SettingsBackButton(onPressed: onBack ?? Navigator.maybePop), Expanded(Semantics(header, Text(title, 1 line ellipsis, SettingsText.pageTitle, text colour)))]))`.

**`SettingsBackButton`** — `IconButton(tooltip: commonBack, tight 44x44, padding 0, NoSplash, icon SettingsGlyph(chevronLeft, size 22, strokeWidth 2, text colour))`.

**`SettingsFooter`** — Stateful, caches `PackageInfo.fromPlatform()`; `FutureBuilder` rendering centred `'ONSET v${version} (${buildNumber})'` (empty string until loaded), tabular figures, body family 12 sp `colors.tertiary`, padding top 6 bottom 8.

**`showSettingsSheet<T>({context, builder})`** — tablet (`isLargeScreen`): `showDialog(barrierColor: kSheetScrim = 0x9E000000, Dialog(background colors.dialog, surfaceTint transparent, elevation 0, insetPadding 40, insetAnimationDuration zero, RoundedRectangleBorder(radius OnsetTokens.radiusLarge = 24, side colors.cardRing hairline 0.5), antiAlias, ConstrainedBox(maxWidth 460, maxHeight 640, Padding(bottom 12, _SheetChrome(handle: false, background: colors.dialog, child: builder)))))`. Phone: captures the status-bar height first (the sheet route drops it), then `showModalBottomSheet(isScrollControlled: true, showDragHandle: false, backgroundColor: colors.sheet, barrierColor: kSheetScrim, elevation 0, antiAlias, top radius 24)`; its builder computes `height = keyboard > 0 ? screenHeight - statusBar - 8 - keyboard : screenHeight * 0.82`, pads the bottom by the keyboard inset, constrains `maxHeight: max(0, height)`, removes the bottom view inset, `SafeArea(top: false)`, `_SheetChrome(handle: true, background: colors.sheet)`. The keyboard never covers the sheet: title and pinned field stay, list scrolls.

**`_SheetChrome`** — private InheritedWidget carrying `handle` and `background`.

**`SettingsSheetContent({title, pinned, slivers})`** — top block padding `fromLTRB(20, 8, 8, 4)`: optional drag handle (36x4, `colors.handle`, radius 2, bottom 8) then Row[Expanded(Semantics header Text(title, SettingsText.pageTitle with letterSpacing -0.27)), TextButton "Done" (`commonDone`, foreground accent, min height 44, horizontal padding 14, Stadium, 14 sp w700) -> `Navigator.pop`]. Wrapped in `Semantics(scopesRoute, namesRoute, explicitChildNodes, label: title)` and a `CustomScrollView(shrinkWrap: true)` whose first sliver is a `PinnedHeaderSliver` coloured with the chrome background holding [top, pinned?], then the given slivers.

**`SettingsChoiceRow({label, selected, onTap})`** — `Semantics(inMutuallyExclusiveGroup, checked: selected, selected, button)`; `Material(color: selected ? accent @ 0.08 : transparent, radius 12, antiAlias)` -> `InkWell(highlight colors.pressed, NoSplash)` -> 48 high, horizontal padding 12: label (1 line ellipsis, 15 sp, w700/accent when selected, w500/text otherwise) and a check glyph (strokeWidth 2.4, accent) when selected.

**`SettingsCheckRow({label, value, onChanged})`** — `Semantics(checked, button)`; `InkWell(radius 12, NoSplash)` whose tap plays `HapticFeedback.selectionClick()` then `onChanged(!value)`; min height 52, padding h12 v8, Row(spacing 14): a 22x22 box `AnimatedContainer(settingsMotion(180 ms))` radius 7, filled accent with a check (size 16, strokeWidth 3, `onAccent` colour) when on, else transparent with a 1.5 px `colors.tertiary` border; label 14.5 sp w500 text colour.

### lib/screens/settings/widgets/settings_kit.dart

The design kit of the profile and settings screens (823 lines). All values are exact and must be reproduced.

**`SettingsColors`** (immutable, 28 colours). `SettingsColors.of(context)` returns `dark` when `Theme.brightness == dark`, else `light`.

| field | dark | light |
|---|---|---|
| card | `OnsetTokens.surfaceDark` #141414 | `surfaceLight` #FFFFFF |
| cardRing | #14FFFFFF (white 8 %) | #14000000 |
| tile | `raisedDark` #1E1E1E | #F0F0F0 |
| tileIcon | `textBodyDark` #D6D6D6 | #3A3A3A |
| hairline | #14FFFFFF | #14000000 |
| text | `textPrimaryDark` #F5F5F5 | #0A0A0A |
| body | #D6D6D6 | #3A3A3A |
| secondary | `textSecondaryDark` #A1A1A1 | #6B6B6B |
| tertiary | `textTertiaryDark` #8A8A8A | #6B6B6B |
| track | #0E0E0E | #F0F0F0 |
| trackRing | #1AFFFFFF | #14000000 |
| stackIdle | #1A1A1A | #F5F5F5 |
| stackRing | #14FFFFFF | #14000000 |
| switchOff | #2A2A2A | #D6D6D6 |
| switchRing | #29FFFFFF (16 %) | #14000000 |
| knobOff | #D6D6D6 | #FFFFFF |
| sliderTrack | #2A2A2A | #DADADA |
| thumb | #F5F5F5 | #FFFFFF |
| danger | #FF6B6F | #C62828 |
| dangerTint | #1FFF5A5F | #1FE5484D |
| dangerFill | `OnsetTokens.danger` #FF5A5F | #E5484D |
| well | #0E0E0E | #F5F5F5 |
| sheet | #161616 | #FFFFFF |
| dialog | #1A1A1A | #FFFFFF |
| button | #1E1E1E | #EFEFEF |
| buttonRing | #1FFFFFFF | #1A000000 |
| handle | #38FFFFFF | #D4D4D4 |
| pressed | #0DFFFFFF | #0D000000 |

`accentOf(context)` = `context.onsetColors.live` — the signal colour (fixed electric lime `#C8FF3D` in dark, `#6B9E00` in light; it is NOT the user accent colour, which only seeds the Material `ColorScheme`). `onAccentOf(context)`: luminance L of the accent; `onBlack = (L + 0.05) / 0.05`, `onWhite = 1.05 / (L + 0.05)`; returns `OnsetTokens.backgroundDark` #0A0A0A when `onBlack >= onWhite`, else white.

**`SettingsText`** (Inter for every style): `section` 11 sp w600 letterSpacing 1.54 (0.14 em) height 1.3 (always upper-cased by callers); `row` 15 w500 h1.3; `detail` 12.5 w400 h1.45; `value` 13 w400 h1.3 with tabular figures (`OnsetType.tabular`); `pageTitle` 18 w700 letterSpacing -0.36 h1.2; `dialogTitle` 19 w700 letterSpacing -0.285 h1.25; `body` 14 w400 h1.55.

**`settingsMotion(context, ms)`** = `motionDuration(context, Duration(ms))` -> the given duration, or `OnsetMotion.reducedFade` (150 ms) under reduce motion (`MediaQuery.disableAnimations` or the platform's reduce-motion accessibility flag).

**`SettingsSectionLabel(text, {padding = symmetric(horizontal: 4)})`** — `Semantics(header: true)` text `text.toUpperCase()` in `SettingsText.section` coloured `secondary`.

**`SettingsCard({child, radius = 16, padding, ring})`** — `Material(color: card, RoundedRectangleBorder(radius, side: (ring ?? cardRing) at 0.5 dp), clip antiAlias)` with optional padding.

**`SettingsGroup({title, children})`** — `weight = children.length + (title == null ? 0 : 1)` (used by the pane's column balancing). Column(min, stretch, spacing 8): optional `SettingsSectionLabel(title)`, then a `SettingsCard` of the children separated by `Divider(height 0.5, thickness 0.5, hairline)` (no divider before the first). A group without a title is a lone card ("Log out").

**`SettingsIconTile(glyph, {danger = false})`** — 32x32, radius 10, fill `dangerTint` or `tile`, glyph coloured `danger` or `tileIcon` (glyph default size, see settings_glyph.dart).

**`enum SettingsRowEnd { none, chevron, external }`** — chevron opens a page or sheet; external leaves the app.

**`SettingsRow({title, glyph, subtitle, value, trailing, end = none, onTap, onLongPress, danger = false, strong = false, enabled = true, minHeight = 56, semanticsLabel, isNew = false})`** — title style `SettingsText.row` with colour `danger ? colors.danger : colors.text` and weight w600 when `strong` else w500. End glyph: chevron -> `chevronRight` strokeWidth 2 tertiary; external -> `external` size 17 tertiary. `active = enabled && (onTap || onLongPress)`. `Semantics(button: onTap != null, enabled: active, label: semanticsLabel)` -> `InkWell(onTap/onLongPress only when enabled, NoSplash, highlight pressed)` -> `Opacity(enabled ? 1 : 0.42)` -> min height `minHeight` -> padding `fromLTRB(16, 10, 14, 10)` -> `LayoutBuilder` -> `Row(spacing 12)`: icon tile if glyph; Expanded Column(min, start, spacing 3) of the title (when `isNew`, a `Wrap(spacing 8, centre)` of title + `NewFeaturePill`) and the subtitle merged into `SettingsText.detail` secondary; the value (if non-empty) constrained to `maxWidth = rowWidth * 0.46`, 2 lines max, ellipsis, right-aligned, `SettingsText.value` secondary (e.g. "Toutes les langues" wraps at large text); then `trailing`, then the end glyph.

**`NewFeaturePill`** (lib/widgets/new_feature_pill.dart, used here) — padding h6 v2, fill `onsetColors.live`, radius 6, text `newFeaturePill.toUpperCase()` 10 sp w800 letterSpacing 0.6 colour #0A0A0A height 1.2.

**`SettingsSwitch({value})`** — `ExcludeSemantics` (the row carries the semantics). `AnimatedContainer(duration: settingsMotion(220), curve: OnsetMotion.standard, 46x28, ShapeDecoration(color: value ? accent : switchOff, StadiumBorder(side: none when on, switchRing 0.5 dp when off)))` -> Stack -> `AnimatedPositioned(duration: reduce ? 0 : 300 ms, curve standard, top 3, left: value ? 21 : 3)` -> knob `AnimatedContainer(fade, 22x22 circle, colour value ? #0A0A0A : knobOff, BoxShadow(#66000000, blur 3, offset (0,1)))`.

**`enum SettingsButtonTone { primary, danger, quiet }`** and **`SettingsButton({label, onPressed, tone = quiet, large = false, icon, expand = false})`** — fill/foreground: primary = accent / onAccent; danger = dangerFill / #0A0A0A; quiet = button / text. Text 15 sp when large else 14, w600 for quiet, w700 otherwise; label `maxLines: 2, ellipsis, centred` (a button never loses its words). `FilledButton.styleFrom(disabledBackground: switchOff, disabledForeground: tertiary, minimumSize: (expand ? infinity : 0, large ? 48 : 44), padding h18, StadiumBorder(side: buttonRing 0.5 dp for quiet, none otherwise), elevation 0, tapTargetSize shrinkWrap)`. With an icon: Row(min, spacing 8, [icon, Flexible(label)]). `onPressed == null` disables.

**`SettingsDialog({title, message, content, actions})`** — `Dialog(background dialog, surfaceTint transparent, elevation 0, insetPadding 20, insetAnimationDuration zero (takes the keyboard's room at once so a focused field is never left under the keyboard), RoundedRectangleBorder(radius 24, side cardRing 0.5))` -> `Semantics(scopesRoute, namesRoute, explicitChildNodes, label: title)` -> maxWidth 420 on a large screen, 360 otherwise -> `SingleChildScrollView(padding 22)` -> Column(min, stretch, spacing 14): title (`dialogTitle`, text), message (`body`, body colour), content, `Padding(top 4, Wrap(alignment end, spacing 8, runSpacing 8, actions))`.

**`confirmSettingsAction(context, {title, message, confirm, danger = true})`** -> `Future<bool>` — `showDialog(barrierColor: kSheetScrim #9E000000)` of a `SettingsDialog` with actions [quiet `commonCancel` -> pop(false), `confirm` with tone danger (or primary when `danger: false`) -> pop(true)]; a dismissed dialog returns false.

**`SettingsNote(text, {padding})`** — padding default `symmetric(h16, v12)`, `SettingsText.detail` with height 1.5, secondary colour.

### lib/screens/settings/widgets/settings_glyph.dart

ONSET's own 24x24 stroke icons for the profile and settings screens (210 lines). Shapes are described with a mini-language parsed by `glyphPathOf` (lib/widgets/sheet/svg_path.dart): SVG path data, `c:cx,cy,r` circles, `r:x,y,w,h,rx` rounded rectangles. Every path is parsed once and cached (`_cache`, `settingsGlyphPath(kind)`).

`enum SettingsGlyphKind` (35 values, in order): general, video, chat, bell, other, user, ban, shield, link, logout, update, notes, cache, reset, code, filter, mute, chevronRight, chevronLeft, chevronDown, external, lock, check, dice, calendar, play, search, anonymous, error, reconnect, trash, sparkle, trendUp, wrench, list.

Exact shapes (copy verbatim into the PC icon set, e.g. as SVG strings rendered by Slint `Path` with `stroke-linecap/linejoin: round`):
- general: `c:12,12,3` + the cog path `M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z`
- video: `r:3,5,18,12,2`, `M8 21h8M12 17v4`
- chat: `M4 5h16v11H9l-5 4z`
- bell: `M6 16V11a6 6 0 0 1 12 0v5l1.5 2h-15z`, `M10 20a2 2 0 0 0 4 0`
- other: `c:12,12,9`, `M12 11v5M12 8h.01`
- user: `c:12,8,4`, `M4 21a8 8 0 0 1 16 0`
- ban: `c:12,12,9`, `M5.6 5.6l12.8 12.8`
- shield: `M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z`
- link: `M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1`, `M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1`
- logout: `M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4`, `M16 17l5-5-5-5M21 12H9`
- update: `M12 4v11M7 10l5 5 5-5M5 20h14`
- notes: `M6 3h8l4 4v14H6z`, `M14 3v4h4M9 12h6M9 16h6`
- cache: `r:3,4,18,16,2`, `c:9,10,2`, `M21 16l-5-5-9 9`
- reset: `M3 12a9 9 0 1 0 3-6.7L3 8`, `M3 3v5h5`
- code: `M8 8l-4 4 4 4M16 8l4 4-4 4M14 5l-4 14`
- filter: `M4 5h16l-6 7v6l-4 2v-8z`
- mute: `M4 5h16v11H9l-5 4z`, `M9 9l6 4M15 9l-6 4`
- chevronRight `M9 6l6 6-6 6`; chevronLeft `M15 6l-6 6 6 6`; chevronDown `M6 9l6 6 6-6`
- external: `M14 4h6v6M20 4l-9 9`, `M18 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h5`
- lock: `r:5,11,14,9,2`, `M8 11V8a4 4 0 0 1 8 0v3`
- check: `M5 12.5l4.5 4.5L19 7.5`
- sparkle (release notes "New"): `M12 3l1.9 5.1L19 10l-5.1 1.9L12 17l-1.9-5.1L5 10l5.1-1.9z`, `M19 15.5l.7 1.8 1.8.7-1.8.7-.7 1.8-.7-1.8-1.8-.7 1.8-.7z`
- trendUp (Improvements): `M3 17l6-6 4 4 8-8`, `M15 7h6v6`
- wrench (Fixes): `M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.8-3.8a6 6 0 0 1-7.9 7.9l-6.9 6.9a2.1 2.1 0 0 1-3-3l6.9-6.9a6 6 0 0 1 7.9-7.9z`
- list: `M9 6h11M9 12h11M9 18h11`, `M4.5 6h.01M4.5 12h.01M4.5 18h.01`
- dice: `r:4,4,16,16,3.5`, `c:9,9,1.3`, `c:15,15,1.3`, `c:15,9,1.3`, `c:9,15,1.3`
- calendar: `r:4,5,16,15,2`, `M4 10h16M9 3v4M15 3v4`
- play: `M7 4v16l13-8z` — the only glyph drawn FILLED (`_filled = {play}`)
- search: `c:11,11,7`, `M20 20l-3.5-3.5`
- anonymous: `c:10,8,4`, `M3 21a7 7 0 0 1 13-3.6`, `M17 15l4 4M21 15l-4 4`
- error: `c:12,12,9`, `M12 7.5v5.5M12 16.5h.01`
- trash: `M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3`
- reconnect: `M20 11a8 8 0 0 0-14.6-4.5L3 9`, `M3 4v5h5`, `M4 13a8 8 0 0 0 14.6 4.5L21 15`, `M21 20v-5h-5`

`SettingsGlyph(kind, {color, size = 18, strokeWidth = 1.9})` — colour falls back to `IconTheme.color`, then `DefaultTextStyle.color`, then #F5F5F5. `ExcludeSemantics` (icons are decorative) -> `SizedBox.square(size)` -> `CustomPaint(_SettingsGlyphPainter)`. The painter scales the canvas by `size / 24` and draws the path with stroke width `strokeWidth` (in 24-unit space, so it scales with the icon), round caps and joins, antialiased; fill style for `play`. `shouldRepaint` when kind, colour or stroke width changes.

### lib/screens/settings/widgets/settings_list_select.dart

`SettingsListSelect<T>` (307 lines) — a setting with a few options shown as a segmented pill, or one option per line (`stacked`). Fields: `title?`, `subtitle?`, `value: T`, `values: List<T>`, `labelOf: String Function(T)`, `onChanged: ValueChanged<T>`, `stacked = false`, `groupLabel?` (screen-reader name when there is no title), `isNew = false`. The selection is the value itself, never resolved back from its label (labels differ per language).

`_pick(option)`: ignores the already selected option; otherwise `HapticFeedback.selectionClick()` then `onChanged(option)`.

Layout: padding `fromLTRB(16, 12, 16, 14)`, Column(min, stretch, spacing 10): title row (`Wrap(spacing 8, centre)` of title in `SettingsText.row`/text colour + `NewFeaturePill` when `isNew`), then `Semantics(label: title ?? groupLabel, container, explicitChildNodes)` holding either the stack (when `stacked`) or a `LayoutBuilder` that chooses segments when `_segmentsFit(width)` else the stack, then the subtitle (`SettingsText.detail`, secondary).

`_segmentStyle(selected)` = Inter 12.5 sp, w700 when selected else w500. `_segmentsFit(context, width)`: true if width is infinite or no values; `room = width / values.length - 2 * (4 + 8)` (4 dp ring + 8 dp padding each side); for every option lays out a one-line `TextPainter` of its label in the bold (selected) style with the current `MediaQuery.textScaler` and text direction; if any is wider than `room` the pill falls back to one option per line — no option ever loses words.

Segments: `DecoratedBox(ShapeDecoration(color: track, StadiumBorder(side: trackRing 0.5 dp)))` -> Row of `Expanded(_Option(child: SizedBox(height 44, Stack[Positioned.fill(Padding(all 4, AnimatedContainer(settingsMotion 220 ms, curve OnsetMotion.standard, ShapeDecoration(color: selected ? accent @ 0.14 : accent @ 0, StadiumBorder(side: selected ? BorderSide(accent @ 0.85, width 1) : none))))), Center(Padding(h8, Text(label, 1 line, ellipsis, segment style, colour selected ? accent : body)))])))`.

Stack (one per line): Column(min, stretch, spacing 6) of `_Option(child: AnimatedContainer(220 ms standard, height 44, padding left 14 right 12, BoxDecoration(color: selected ? accent @ 0.08 : stackIdle, radius 12, border: selected ? accent @ 0.7 width 1 : stackRing 0.5)))` with a Row of the label (Inter 14, w700 selected / w500, text colour, 1 line ellipsis) and a check glyph (strokeWidth 2.4, accent) when selected.

`_Option` — `Semantics(inMutuallyExclusiveGroup, checked: selected, selected, button, label, excludeSemantics, onTap)` (a radio button to a screen reader), `PressScale` (0.97 over 100 ms, spring back) around an opaque `GestureDetector(onTap)`.

PC: render the same pill/stack; measure label widths with the Slint font metrics (or a Rust text-shaping crate) to decide fit, honour the OS text scale; keyboard arrows move within the radio group.

### lib/screens/settings/widgets/settings_list_slider.dart

`SettingsListSlider` (133 lines, Stateful) — a value on a scale. Fields: `title`, `trailing` (the formatted value shown at the end of the title line), `subtitle?`, `value`, `onChanged?` (null disables), `min = 0.0`, `max = 1.0`, `divisions?`.

State keeps `_previousStep`. `_handleChanged(v)`: when `divisions` is set, `step = round((v - min) / (max - min) * divisions)`; a haptic `selectionClick` fires each time the step differs from the previous one (not on the first event); then `onChanged(v)`.

Layout: `Opacity(onChanged == null ? 0.42 : 1)` -> padding `fromLTRB(16, 12, 16, 12)` -> Column(min, stretch, spacing 6): a baseline-aligned Row(spacing 12) [Expanded title (`SettingsText.row`, text colour), trailing value (Inter 13 sp w600, `body` colour, tabular figures)], then `SizedBox(height 32, SliderTheme(trackHeight 4, activeTrack accent, inactiveTrack sliderTrack, disabledActive accent, disabledInactive sliderTrack, thumb colour `thumb` (also disabled), overlay accent @ 0.12, overlayShape RoundSliderOverlayShape(radius 18), thumbShape RoundSliderThumbShape(elevation 2, pressedElevation 3) — default 10 dp radius (20 dp thumb), RoundedRectSliderTrackShape, no tick marks, value indicator never shown, horizontal padding 10, child Slider(value clamped to [min, max], min, max, divisions, onChanged)))`, then the subtitle (`SettingsText.detail`, secondary).

Persistence note: dragging changes the store on every frame; the app-level `persistSettings` gathers writes for 300 ms (see Network and data).

### lib/screens/settings/widgets/settings_list_switch.dart

`SettingsListSwitch({title, subtitle (Widget?), value, onChanged?, isNew = false})` (48 lines) — an on/off setting where the whole row toggles. `toggle()` plays `HapticFeedback.selectionClick()` and calls `onChanged!(!value)`. Rendered as `MergeSemantics(Semantics(toggled: value, enabled: onChanged != null, child: SettingsRow(title, isNew, subtitle, enabled: onChanged != null, onTap: onChanged == null ? null : toggle, trailing: SettingsSwitch(value))))`. Without `onChanged` the row is dimmed to 0.42 opacity and does nothing (used for dependent switches, e.g. "Only with headphones" when background audio is off). The 46x28 switch itself is described in settings_kit.dart (knob slides 300 ms, colours fade 220 ms, 150 ms fade under reduce motion). PC: a Slint `Switch`-like custom component, Space/Enter toggles when the row is focused.

### lib/screens/settings/widgets/settings_name_list.dart

`SettingsNameList` (187 lines) — the shared list of people/channels with one action each, used by Blocked users ("Unblock") and Not interested ("Restore"). Fields: `names`, `rowKeys?` (one Key per row), `emptyGlyph`, `emptyText`, `emptyTextAlign?`, `emptyNote?`, `countText`, `note`, `onRefresh?` (pull to refresh), `actionLabel`, `actionSemantics(name)`, `onAction(index, name)`.

Empty: `SettingsGroupsView(onRefresh, children: [Padding(vertical 80, Column(spacing 12): a 56 dp circle (fill `card`, `trackRing` hairline border) with the empty glyph (size 24, secondary), emptyText (Inter 15 w600 body colour, `emptyTextAlign`), and, if given, emptyNote (padding h24, centred, `SettingsText.detail` height 1.5 tertiary))])`.

Non-empty: `SettingsGroupsView(onRefresh, children: [Column(stretch, spacing 8): SettingsSectionLabel(countText) (upper-cased), SettingsCard of `_NameRow`s separated by 0.5 dp hairline dividers (row key from `rowKeys[index]`), then the note (padding `fromLTRB(4, 4, 4, 0)`, detail style height 1.5 tertiary)])`.

`_NameRow` — min height 60, padding `fromLTRB(16, 8, 8, 8)`, Row(spacing 12): `InitialAvatar(name, size 34)` (circle coloured from an 8-colour palette #7CB7FF, #FF9ECF, #7CF0FF, #FFD27A, #B6F27A, #FFB38A, #C9A7FF, #9EE6C2 indexed by `(firstCodeUnit + length) % 8`, first character upper-cased, Inter `size * 0.43` w800 height 1, colour #0A0A0A, '?' when empty), Expanded name (`SettingsText.row`, 1 line ellipsis), and `Semantics(label: actionSemantics(name), button, onTap, excludeSemantics)` around a quiet `SettingsButton(actionLabel)` calling `onAction`.

### lib/screens/settings/account/account_settings.dart

Settings › Account and shared account helpers (500 lines).

`twitchHelpUrl = 'https://link.twitch.tv/help'`.

`enum TwitchAccountPage(glyph, path)` — pages only twitch.tv can change, opened signed in through `TwitchWebPage` (no API): `profile(user, '/settings/profile')`, `security(shield, '/settings/security')`, `notifications(bell, '/settings/notifications')`, `connections(link, '/settings/connections')`, `familyCenter(lock, '/settings/family-center')`, `subscriptions(sparkle, '/subscriptions')`, `drops(dice, '/drops/inventory')`, `turbo(play, '/turbo')`, `prime(sparkle, '/prime')`, `recap(calendar, '/annual-recap')`, `signup(user, '/signup')`, `deleteAccount(trash, '/user/delete-account')`. `profileTab = [security, connections]`. Titles (enum_labels.dart): `settingsTwitchProfile, …Security, …Notifications, …Connections, …FamilyCenter, …Subscriptions, …Drops, …Turbo, …Prime, …Recap, …Signup, …DeleteAccount`; details `settingsTwitch<Name>Detail`.

**`AccountSettings(authStore)`** — Observer; if logged out or no details returns `SizedBox.shrink()` (the page is being popped). Otherwise `SettingsGroupsView` with groups:
1. Untitled identity card: padding h16 v14, Row(spacing 14) [SettingsAvatar 56, Column(spacing 3): display name (18 sp w700 letterSpacing -0.27, 1 line ellipsis), `accountLine` (13 sp secondary, 1 line ellipsis)].
2. `settingsYourAccount`: rows `settingsMyChannel` (user glyph, chevron, `openMyChannel`); `editProfileTitle` keyed `'settings-edit-profile'` (notes glyph, chevron, `openEditProfile`); `settingsPageBlocked` (ban, value = blocked count, chevron, `openBlockedUsers`).
3. If a `TwitchTvSessionStore` is provided: `TwitchTvSessionGroup(store)` (twitch_tv_connect_sheet.dart).
4. If a `TwitchViewerActionsService` is provided: `GiftSettingsGroup(load: service.giftSettings(authToken: authStore.twitchWebToken ?? ''), save: service.updateGiftSettings(settings, authToken))`.
5. If a `TwitchSocialService` is provided: `WhisperPrivacyGroup(load: social.whisperPrivacy(authToken), save: social.setBlockStrangers(block, authToken))`.
6. `settingsOnTwitch`: one external row per `TwitchAccountPage.values` (all 12, glyph + title, no subtitle) -> `openTwitchAccountPage`.
7. Untitled: danger row `settingsLogOut` (logout glyph) -> `confirmLogout`; if confirmed, still mounted and not inside a tablet pane, `Navigator.maybePop` (on a phone the page goes with the account).

**`hasAccount(authStore)`** = `error == null && isLoggedIn && user.details != null`.

**`accountLine(l, user)`** = `'@login · ${joinedText}'` or `'@login'` when no creation date. **`joinedText(l, user)`** = `l.settingsJoined(date: createdAt.toLocal())` or null.

**`SettingsAvatar({user, size})`** — `ExcludeSemantics(ClipOval(SizedBox.square(size)))`: if `profileImageUrl` is empty, a placeholder (`colors.tile` square with the first character of the display name upper-cased, or `'?'` when empty; Inter `size * 0.4` w800 secondary); else `OnsetCachedNetworkImage(url, size, BoxFit.cover)` with the placeholder for loading and errors. No request of its own beyond the cached image.

**`openMyChannel(context, authStore)`** — no-op without details; pushes `MaterialPageRoute(settings: RouteSettings(name: 'My channel'), VideoChat(userId, userName: displayName, userLogin: login))` — the viewer's own channel page.

**`openBlockedUsers`** = `openSettingsPage(id: blocked, builder: BlockedUsers(authStore))`.

**`openTwitchAccountPage(context, page)`** = `TwitchWebPage.open(context, title: page.title, url: Uri.https('www.twitch.tv', page.path))`.

**`confirmLogout(context, authStore)`** -> `Future<bool>` — `confirmSettingsAction(title: settingsLogOutTitle, message: settingsLogOutMessage, confirm: settingsLogOut)` (danger tone); on confirm calls `authStore.logout()` (fire and forget) and returns true.

**`openLogin(context)`** pushes `LoginWebView()` (lib/screens/onboarding/login_webview.dart — the OAuth WebView).

**`loginFromClipboard(authStore)`** — reads `Clipboard.getData('text/plain')`; if text exists calls `authStore.login(token: text, acceptAnyApp: true)` — a token minted for any client id is accepted (the viewer's own token from another app). The text is NOT trimmed and only `null` is filtered: an empty or whitespace clipboard is passed to `login` and fails silently; `login()` is not awaited and nothing tells the viewer whether it worked (Known Android defects).

**`ProfileLoginCard(authStore)`** — Observer. `error = authStore.error != null`. A 60 dp disc (fill `dangerTint` on error else `tile`; a `buttonRing` hairline border when not error) with glyph `error`/`anonymous` (size 26, stroke 1.9 / 1.8, colour danger / secondary). Heading Row(spacing 14)[disc, Column(spacing 3): title (semantics header) `settingsUnableToReachTwitch` (20 sp, letterSpacing -0.4) or `settingsAnonymous` (24 sp, letterSpacing -0.72), w800 height 1.15 text colour; line `settingsCheckConnection` or `settingsWatchingWithoutAccount` (13 sp secondary)]. Body on error: [heading, `SettingsButton(settingsReconnect, large, expand, reconnect glyph strokeWidth 2, onPressed: authStore.init)`]. Body otherwise: [heading, `settingsLoginPitch` (SettingsText.body, body colour), primary large expanded button `commonConnectWithTwitch` with user glyph (strokeWidth 2.1, onAccent colour) -> `openLogin`, `settingsLoginDisclaimer` (12 sp height 1.5 tertiary), a "well" box (padding h12 v10, colour `well`, radius 12, cardRing hairline) with `settingsTokenLoginTip` (12 sp height 1.5 secondary)]. Wrapped in `Semantics(onLongPressHint: settingsTokenLoginHint unless error)` + translucent `GestureDetector(onLongPress: loginFromClipboard unless error)` + `SettingsCard(radius 24, padding 20, ring: error ? dangerFill @ 0.35 : default)` holding a Column(stretch, spacing 16).

PC equivalent: identical structure; `TwitchWebPage` becomes a WebView2 window sharing the twitch.tv cookie session; clipboard login via the OS clipboard (`arboard` crate) from a context-menu entry or Ctrl+V on the card.

### lib/screens/settings/account/block_reason_picker.dart

`BlockReasonPicker({selected: BlockReason?, onSelected: ValueChanged<BlockReason?>})` (54 lines) — the optional reason shown inside the block confirmation dialog (`AuthStore.showBlockDialog`). `static label(l, reason)`: harassment -> `blockReasonHarassment`, spam -> `blockReasonSpam`, other -> `blockReasonOther`. Layout: padding top 12, Column(start, spacing 8): title `blockReasonTitle` in `textTheme.labelLarge`, then `Wrap(spacing 8, runSpacing 8)` of one `SheetChoicePill` per `BlockReason.values` (keys `ValueKey('block-reason-harassment' | '-spam' | '-other')`, label, `selected: selected == reason`). Tapping the selected pill deselects it (`onSelected(null)`), tapping another selects it — the reason is optional and sent as Helix `reason` only when chosen. `SheetChoicePill` (lib/widgets/sheet/onset_sheet.dart): Stadium, height 30 (36 large), padding h12 (h14 large), 12 sp w600 label, selected = accent text, accent tint fill and accent 0.5 dp ring; haptic selection click on tap; radio semantics.

### lib/screens/settings/account/blocked_users.dart

`BlockedUsers({authStore})` (62 lines) — Settings › Blocked users. An `Observer` over `authStore.user.blockedUsers` rendering `SettingsNameList(names: [getReadableName(displayName, userLogin) for each], emptyGlyph: SettingsGlyphKind.ban, emptyText: settingsNoBlockedUsers, countText: settingsBlockedCount(count), note: settingsBlockedNote, onRefresh: _refresh, actionLabel: settingsUnblock, actionSemantics: (name) => settingsUnblockName(name), onAction: (index, name) => _unblock(name, id: blocked[index].userId))`. `getReadableName` returns the display name alone when it equals the login or is only digits, otherwise `"DisplayName (login)"` (localised names show the login). `_refresh`: `HapticFeedback.lightImpact()` then `user.refreshBlockedUsers()` (pull to refresh). `_unblock`: `confirmSettingsAction(title: settingsUnblock, message: settingsUnblockMessage(name), confirm: commonYes, danger: false)` (primary tone, not destructive); if confirmed `user.unblock(targetId)` (Helix DELETE /users/blocks) which refreshes the list. The list layout (count line, rows with an Unblock pill, empty state, note) is in settings_name_list.dart.

### lib/screens/settings/account/edit_profile.dart

Edit profile (921 lines) — edits the viewer's Twitch profile in-app through Twitch's web GQL (needs the twitch.tv web token).

**`EditProfileActions`** — a bundle of async callbacks: `profile()`, `renameStatus()`, `socialLinks()`, `availability(login)`, `setDisplayName(name)`, `setDescription(text)`, `changeUsername(login)`, `addLink(title, url)`, `updateLink(id, title, url)`, `deleteLink(id)`, optional `uploadImage(kind, file)`, `pickImage()`, `onAccountChanged()`. `EditProfileActions.of(TwitchAccountGqlService service, {token, onAccountChanged, pickImage})` wires them to the service, capturing `userId` from the loaded profile (used by every mutation). `EditProfileActions.unavailable()` returns nulls / `UsernameAvailability.unknown` / `AccountEditResult.failed()` for everything (no service provided).

GQL documents (TwitchAccountGqlService, `POST https://gql.twitch.tv/gql`, `Client-ID: kimne78kx3ncx6brgo4mv6wki5h1ko`, `Authorization: OAuth <web token>`): `EditableProfile` = `query EditableProfile { currentUser { id login displayName description profileImageURL(width: 300) bannerImageURL } }`; `UserLoginRenameStatusQuery` = `{ currentUser { loginRenameStatus { isEligible eligibleAt } } }`; `SocialLinks` = `{ currentUser { id channel { socialMedias { id name title url } } } }`; `IsUsernameAvailableQuery($login)` = `isUsernameAvailable(username: $login)`; `UpdateUserDisplayNameMutation($userID, $newDisplayName)` and `UpdateUserDescriptionMutation($userID, $newDescription)` (`updateUser(input: {...}) { error { code } user {...CurrentUserModelFragment} }`); `ChangeUsernameMutation($userID, $newLogin)` (`changeUsername`); `CreateSocialLink` / `UpdateSocialLink` / `DeleteSocialLink` (`createSocialMedia` / `updateSocialMedia` / `deleteSocialMedia(input)` returning `channel { socialMedias { id name title url } }`); image upload = `CreateProfileImageUploadURL` (avatar) or `CreateProfileBannerImageUploadURL` (banner) with input `{userID, format: PNG|JPG|GIF}` returning `uploadURL uploadID error { code }`, then an HTTP `PUT` of the bytes to the https `uploadURL`. Outcomes `AccountEditOutcome { done, refused (with an error code), integrityRefused, signedOut, failed }`.

`twitchProfileSettingsUrl = https://www.twitch.tv/settings/profile`.

**`EditProfile({actions})`** keys: `displayNameKey 'edit-profile-display-name'`, `bioKey 'edit-profile-bio'`, `usernameKey 'edit-profile-username'`, `addLinkKey 'edit-profile-add-link'`, `avatarKey 'edit-profile-avatar'`, `bannerKey 'edit-profile-banner'`, `fieldKey 'edit-profile-field'`, `secondFieldKey 'edit-profile-field-2'`, `saveKey 'edit-profile-save'`, `deleteKey 'edit-profile-delete'`, `checkKey 'edit-profile-check'`, `linkKey(id) = 'edit-profile-<id>'`.

State: `_profile`, `_links`, `_renameStatus`, `_loading = true`, `_uploading` (kind). `_load()`: profile; setState(profile, loading = profile != null); if present load social links and rename status in parallel, then loading false. `_say(text)` hides the current snackbar and shows a new one. `_failure(result)`: refused -> `editProfileRefused(code: code ?? 'UNKNOWN')`, integrityRefused -> `editProfileIntegrity`, signedOut -> `editProfileSignedOut`, else `editProfileFailed`. `_applyProfile(change, done)`: on success with a value replaces the profile, says `done`, fires `onAccountChanged` (re-inits the user store so the avatar/name update app-wide); else the failure text. `_applyLinks` same for the link list (no account refresh).

Edits:
- Display name: `_TextDialog(title editProfileDisplayName, message editProfileDisplayNameHelp(login), initial displayName, maxLength 25, valid: trimmed non-empty and different)` -> `setDisplayName` -> `editProfileDisplayNameSaved`.
- Bio: `_TextDialog(title editProfileBio, initial description, maxLength 300 (`EditableProfile.maxDescriptionLength`), maxLines 5, counter, valid: trimmed differs)` -> `setDescription` -> `editProfileBioSaved`.
- Username: if rename status says not eligible, an info `SettingsDialog(title editProfileUsername, message editProfileUsernameNotYet or editProfileUsernameNotUntil(date: DateFormat.yMMMMd(locale) of eligibleAt local), action commonClose)`. Else `_UsernameDialog` -> login; then `confirmSettingsAction(title editProfileUsernameConfirmTitle(login), message editProfileUsernameConfirmBody, confirm editProfileUsernameChange)` (danger) -> `changeUsername` -> `editProfileUsernameSaved(login)`; then re-reads the rename status.
- Links: `_LinkDialog(link?)` -> `_LinkEdit`; delete -> `confirmSettingsAction(editProfileLinkDeleteTitle(title), editProfileLinkDeleteBody, confirm editProfileLinkDelete)` (danger tone, the default) -> `deleteLink` -> `editProfileLinkDeleted`; else add or update -> `editProfileLinkSaved`.
- Images (`_changeImage(kind)`, only when both upload and pick exist and nothing is uploading): `pickProfileImage()` (gallery via image_picker, no full metadata; a file larger than 10 MiB or a pick error returns a pick with no file); no file -> `editProfileImageInvalid`; else uploading state, upload, success -> `editProfileImageSaved`, then `onAccountChanged()` (not awaited) and `_load()` again (not awaited); failure -> failure text. Note `EditProfileActions.of` holds a `late String userId` set only by a successful `profile()`: any mutation before that throws `LateInitializationError` (the UI never offers one without a profile).

Build when no profile: `SettingsGroupsView[loading ? centred 24 dp spinner (padding 24) : SettingsNote(editProfileUnavailable), SettingsGroup[SettingsRow(glyph user, editProfileOnTwitch, external) -> TwitchWebPage.open(title editProfileTitle, url twitchProfileSettingsUrl)]]`. With a profile:
1. Untitled group: `_ProfileImages`, then for avatar and banner a `SettingsRow(key avatarKey/bannerKey, glyph user, title editProfileAvatarChange / editProfileBannerChange, subtitle editProfileImageUploading while that kind uploads else editProfileImageHelp, chevron, disabled while any upload runs or images can't change)`.
2. `editProfileAbout`: rows display name (value = display name), username (value `'@login'`), bio (subtitle = description or `editProfileBioEmpty`, 3 lines ellipsis).
3. Links: `SettingsNote(editProfileLinksUnavailable)` when the list failed; else group `editProfileLinks` with a row per link (glyph link, title, url subtitle 1 line ellipsis) and, below 5 links (`maxSocialLinks`), an add row (`editProfileLinkAdd`), otherwise `SettingsNote(editProfileLinksFull)`.

`_ProfileImages` (ExcludeSemantics, height 132, Stack): banner image (or `tile` fill) filling all but the bottom 36 dp; at left 16 bottom 8 a 64 dp avatar in a 3 dp `card`-coloured ring (initial placeholder: `displayName.characters.first.toUpperCase()` with NO '?' fallback — it throws on an empty display name; row style 24 sp secondary on `tile`). The banner/avatar placeholders show only when the URL is null, not when it is an empty string.

`_TextDialog` — `SettingsDialog(title, message, content: SheetTextField(key fieldKey, controller with initial text, autofocus, maxLength, maxLines, counter, onChanged setState), actions [Cancel, primary editProfileSave (key saveKey) enabled when valid -> pop(trimmed text)])`.

`_UsernameDialog({current, availability})` — `SettingsDialog(title editProfileUsername, message editProfileUsernameHelp, content: Column(min, stretch, spacing 8)[field, optional status Text(SettingsText.detail in the status colour), Align(AlignmentDirectional.centerStart, Check button)])`. `_login` = trimmed text; `_wellFormed` = `^[A-Za-z0-9][A-Za-z0-9_]{2,24}$`, length <= 25, and different from the current login case-insensitively. Status line (detail style): not well formed and non-empty -> `editProfileUsernameRules` (danger); else by the result for the SAME login: available -> `editProfileUsernameAvailable` (text), taken -> `editProfileUsernameTaken` (danger), unknown -> `editProfileUsernameUnknown` (secondary). Field: `SheetTextField(key fieldKey, autofocus, maxLength 25, hint current, input filter [A-Za-z0-9_])`; quiet button `editProfileUsernameCheck` (key checkKey) enabled when well formed and not checking; actions [Cancel, primary `editProfileContinue` (key saveKey) enabled when well formed, checked and not taken -> pop(login lower-cased)].

`_LinkDialog({link})` — title `editProfileLinkAdd` / `editProfileLinkEdit`; fields title (`editProfileLinkTitle`, maxLength 25) and URL (key secondFieldKey, `editProfileLinkUrl`, hint `'https://'`, URL keyboard); Content is `Column(min, stretch, spacing 12)`; the title field is `SheetTextField(label: editProfileLinkTitle, maxLength: SocialLink.maxTitleLength = 25)`, the URL field `SheetTextField(label: editProfileLinkUrl, hint 'https://', keyboardType url)`. valid = trimmed title non-empty and `SocialLink.isValidUrl(untrimmed url)` (it trims internally: http/https, host containing a dot, no user-info); the result is popped with both values trimmed. Actions: when editing a quiet `editProfileLinkDelete` (key deleteKey) -> pop(delete), Cancel, primary Save (key saveKey).

`EditProfileHost({authStore})` — uses the provided `TwitchAccountGqlService` or `unavailable()`; token = `authStore.twitchWebToken ?? ''`; `pickImage: pickProfileImage`; `onAccountChanged` = `authStore.user.init()` (errors logged `'Account refresh after a profile edit failed'`). `openEditProfile(context, authStore)` = `openSettingsPage(id: editProfile, builder: EditProfileHost)`.

PC: native file dialog (`rfd`) instead of the gallery, same 10 MiB and PNG/JPG/GIF limits.

### lib/screens/settings/account/gift_settings.dart

`GiftSettingsGroup({load, save})` (129 lines) — Twitch's gifted-sub preferences in Settings › Account. Keys `followedOnlyKey = ValueKey('gift-followed-only')`, `hideCountKey = ValueKey('gift-hide-count')`. `load` / `save` are injected by AccountSettings: GQL `UserGiftedSubSettingsQuery` = `query UserGiftedSubSettingsQuery { currentUser { id subscriptionSettings { giftsToFollowedChannelsOnly isGiftCountHidden } } }` and `UserGiftedSubSettingsMutation($input: UpdateUserSubscriptionSettingsInput!)` -> `updateUserSubscriptionSettings(input) { subscriptionSettings { giftsToFollowedChannelsOnly isGiftCountHidden } }` with input `{giftsToFollowedChannelsOnly, isGiftCountHidden}` (web client id + `OAuth <web token>`).

State `_settings` (GiftSettings {followedChannelsOnly, countHidden}), `_loading = true`, `_busy`. `initState` -> `_reload()`. `_change(wanted)`: ignored without settings, while busy, or when unchanged; asks `confirmSettingsAction(title: giftSettingsConfirmTitle, message: giftSettingsConfirmBody, confirm: giftSettingsChange, danger: false)`; then `_apply(wanted, undo: previous)`. `_apply(wanted, {undo})`: busy; `save(wanted)`; when `done` replaces the settings; hides the current snackbar and shows `viewerActionResult(status: outcome.name)` with an Undo action (`commonUndo`, re-applies `undo` WITHOUT confirmation and without its own undo) only when done and an undo exists. The snackbar lands on the ROOT `ScaffoldMessenger` (SettingsScaffold has none of its own), so it outlives the Account page; tapping Undo after the page was popped calls `_apply` on the disposed State, whose `context` access throws (unawaited, unhandled) — the undo is never saved (Known Android defects).

Build: `SettingsGroup(title: giftSettingsTitle)`: loading -> centred 22 dp spinner (stroke 2, padding 16); null -> `SettingsNote(giftSettingsUnavailable)`; else two switches: `giftFollowedOnly` / `giftFollowedOnlyDetail` (value followedChannelsOnly) and `giftHideCount` / `giftHideCountDetail` (value countHidden), both disabled while busy. The switch shows the confirmed server value (it does not flip until saved).

### lib/screens/settings/account/whisper_privacy_settings.dart

`WhisperPrivacyGroup({load, save})` (129 lines) — "Block whispers from strangers". Key `blockStrangersKey = ValueKey('whisper-block-strangers')`. Injected: `TwitchSocialService.whisperPrivacy` = GQL `WhisperSettingsGetterQuery` (`query WhisperSettingsGetterQuery { currentUser { login whisperSettings { isWhisperBanned isBlockingWhispersFromStrangers isWhispersDisabledByParent } } }`) and `setBlockStrangers(block)` = `UpdateWhisperSettings($input: UpdateWhisperSettingsInput!)` -> `updateWhisperSettings(input) { user { login whisperSettings { isWhisperBanned isBlockingWhispersFromStrangers } } }` with input `{isBlockingWhispersFromStrangers: block}`. `WhisperPrivacy { blockStrangers, banned, disabledByParent }`.

State `_privacy`, `_loading = true`, `_busy`. `_change(block)`: ignored without data, while busy, or when equal; confirmation REUSES the gift strings (`giftSettingsConfirmTitle`, `giftSettingsConfirmBody`, `giftSettingsChange`, danger false) — reproduce as-is; then `_apply(block, undo: previous.blockStrangers)`. `_apply`: busy, save, on done rebuild `WhisperPrivacy(blockStrangers: block, banned, disabledByParent)` keeping the other flags; snackbar `viewerActionResult(status)` with Undo when done (same root-messenger snackbar: an Undo tapped after the page closed throws on the disposed State and is lost).

Build: `SettingsGroup(title: whisperPrivacyTitle)`: loading spinner (22 dp) / `SettingsNote(whisperPrivacyUnavailable)` / else [`SettingsNote(whisperPrivacyBanned)` if banned, `SettingsNote(whisperPrivacyParent)` if disabled by a parent (Family Center), switch `whisperBlockStrangers` / `whisperBlockStrangersDetail` disabled while busy or when disabled by parent].

### lib/screens/settings/account/twitch_tv_login_offer.dart

`TwitchTvLoginOffer({store: TwitchTvSessionStore, context: BuildContext? Function(), logins: int Function()})` (67 lines) — offers, once, to connect the "twitch.tv session" (device-code session used for actions Twitch only accepts from its own clients) right after an interactive login. Wired in main.dart: `context = navigatorKey.currentContext`, `logins = authStore.interactiveLogins`, and a MobX reaction on `isLoggedIn ? user.details.id : null` (fireImmediately) calls `accountChanged(id)`.

State: `_seq` (cancellation counter), `_answeredLogins` (login count already handled; initialised to the count at the first call so a launch with a stored session never prompts), `_lastAccount`, `_openOffer` (dialog context). `accountChanged(id)`: `seq = ++_seq`; init `_answeredLogins`; `_closeOffer()` (removes an open offer dialog's route if still active); `id == null` -> `store.detach()` and return. `switched = _lastAccount != null && _lastAccount != id`; remember id; `await store.attach(id)`; abort if superseded; `newLogin = logins() > _answeredLogins`; update the count; stop unless a new interactive login happened; stop unless the store is `disconnected`; unless switched, stop if `store.shouldPrompt()` is false (secure-storage flag `twitch_tv_prompted` already 'true'); get a mounted context; `store.markPrompted()`; then (not awaited) `FollowFlow.offerTvSession(context, store, message: twitchTvLoginOfferBody, onShown: (dialog) => _openOffer = dialog)` clearing `_openOffer` on completion if still current.

### lib/screens/settings/account/twitch_tv_connect_sheet.dart

Connect the twitch.tv session with Twitch's device-code flow (399 lines).

`showTwitchTvConnectSheet(context, store)` -> `Future<bool>` — `showOnsetSheet<bool>(constraints: maxWidth 560, TwitchTvConnectSheet(store))`, true only when connected. `twitchTvConnectSnackAction(context)` — a `SnackBarAction(label: twitchTvConnectAction)` that opens the sheet from the root navigator (or `navigatorKey`), or null when no store is provided (used by features that fail without the session).

`TwitchTvConnectSheet({store})` keys `codeKey 'twitch-tv-code'`, `openKey 'twitch-tv-open'`, `copyKey 'twitch-tv-copy'`, `newCodeKey 'twitch-tv-new-code'`, `doneKey 'twitch-tv-done'`. Private `_Phase { requesting, waiting, finished }`. State `_phase`, `_code`, `_outcome`, `_attempt` (incremented on start and dispose to cancel). `_start()`: phase requesting, clear code/outcome; `store.requestCode()`; null -> finished with `failed`; else waiting with the code; `store.approve(code, isCancelled: () => !mounted || attempt != _attempt)`; connected -> `HapticFeedback.lightImpact()`; finished with the outcome. `_copy(code)`: `Clipboard.setData`, selection haptic, then via `ScaffoldMessenger.maybeOf` it HIDES the current snackbar first and shows `twitchTvConnectCopied` (unlike the update prompt's snackbars, which do not hide the current one). `_openActivation(code)`: `TwitchWebPage.open(title: twitchTvConnectTitle, url: https://www.twitch.tv/activate?device-code=<userCode>)` (signed-in WebView; the viewer approves there).

Layout: `SingleChildScrollView(padding fromLTRB(20, 8, 20, 20))` Column(stretch): title (semantics header, `SheetText.title`), 6, body `twitchTvConnectBody` (secondary), 18, `_CodeCard(code: userCode, dimmed: finished)`, 4, `AnimatedSwitcher(motionDuration 220 ms, keyed '<phase>-<outcome>')` of the status, 12, actions.
Status: finished -> `SheetStatusLine(busy false, ok: connected, okGlyphColor OnsetTokens.accent, message: twitchTvConnectResult(status: outcome.name))` — the ICU select has only `connected`, `expired`, `denied`, `wrongAccount` and `other` branches: `cancelled` and `failed` BOTH render the `other` text "Couldn’t reach Twitch. Try again." / « Impossible de joindre Twitch. Réessayez. » (so a `cancelled` reaching a still-mounted sheet — account changed or generation superseded mid-approval — shows a network-error message; see Known Android defects); otherwise min height 30, Row(spacing 10)[14 dp spinner stroke 2 accent, live-region text `twitchTvConnectRequesting` / `twitchTvConnectWaiting` in `SheetText.status` secondary].
Actions: finished & connected -> large expanded `SheetButton(doneKey, commonDone)` -> pop(true). Finished otherwise -> large `SheetButton(newCodeKey, twitchTvConnectNewCode)` -> `_start()`, 8, text-tone `commonCancel` -> pop(false). Requesting/waiting -> large `SheetButton(openKey, twitchTvConnectOpen, icon external glyph)` (disabled until a code exists), 8, Row(spacing 8)[text-tone `SheetButton(copyKey, twitchTvConnectCopy)` (disabled without code), text-tone `commonCancel` -> pop(false)].

`_CodeCard({code, dimmed})` — padding h16 v18, fill `well`, radius 18, a 1 dp border (default width 1.0, not the 0.5 hairline width) in the `hairline` colour; Column(spacing 8): label `twitchTvConnectCodeLabel.toUpperCase()` (`SheetText.section` tertiary), `AnimatedOpacity(dimmed ? 0.4 : 1, motionDuration 200 ms)` of a 44-high centred `FittedBox(scaleDown, SelectableText(code, key codeKey, 1 line, tabular Inter 34 w800 letterSpacing 6 height 1.1 text))`.

`TwitchTvSessionGroup({store})` (in Settings › Account) — `rowKey = ValueKey('settings-twitch-tv-session')`; Observer -> untitled group with `SettingsRow(glyph link, title twitchTvSessionTitle, subtitle twitchTvSessionDetail, value twitchTvSessionState(state: status.name) (disconnected/connected/expired), chevron)`. Tap: not connected -> the sheet; connected -> `confirmSettingsAction(twitchTvDisconnectTitle, twitchTvDisconnectBody, confirm twitchTvDisconnect)` (danger) then `store.forget()`.

PC: same sheet; "Open twitch.tv/activate" opens a WebView2 window (or the default browser), the code is selectable/copyable; the flow is identical OAuth device grant.

### lib/screens/settings/widgets/theme_selection_setting.dart

`ThemeSelectionSetting({settingsStore})` (25 lines) — `Observer` -> `SettingsListSelect<ThemeType>(groupLabel: settingsTheme (no visible title — the group label names it), value: themeType, values: [system, light, dark], labelOf: themeSystem / themeLight / themeDark, onChanged: settingsStore.themeType = theme)`. Effect: `MaterialApp.themeMode` = system -> `ThemeMode.system`, light -> light, dark -> dark (main.dart), switching all `SettingsColors` between their dark and light tables instantly. PC: follow the Windows "app mode" (registry `AppsUseLightTheme`) for System.

### lib/screens/settings/widgets/external_browser_setting.dart

Two switch widgets (40 lines). `ExternalBrowserSetting({settingsStore})` — `Observer` -> `SettingsListSwitch(title: settingsExternalBrowser, value: launchUrlExternal, onChanged: launchUrlExternal = v)`. When on, links (chat links, release notes, help pages) open in the external browser app (`LaunchMode.externalApplication`) instead of an in-app browser view (`inAppBrowserView`). `ConfirmLinksSetting({settingsStore})` — `SettingsListSwitch(title: settingsConfirmLinks, subtitle: Text(settingsConfirmLinksDetail), value: confirmExternalLinks, onChanged: …)`; when on (default) the app asks before opening a link that leaves it (read in main.dart's link handling). PC: external = default browser via `open`/`ShellExecute`; in-app = an embedded WebView2 window.

### lib/screens/settings/widgets/language_setting.dart

`LanguageSetting({settingsStore, LocaleBridge? bridge})` (96 lines; `bridge` defaults to `LocaleBridge.shared`) — Settings › General › Language. Stateful with `WidgetsBindingObserver`. `_system` = the device's own languages as the system last reported them (`bridge.lastSystemLocales`, null where the platform does not say — on Android 13+ once a per-app language is set Flutter's own locale list is that language, so the system is asked directly). `initState` registers the observer and calls `_askSystem()` (`await bridge.systemLocales()`, setState when non-null). `didChangeLocales` rebuilds and re-asks; `didChangeAppLifecycleState(resumed)` re-asks (back from system settings).

Build (Observer): `device = resolveAppLanguage(AppLanguage.system, _system ?? platformDispatcher.locales)` — first device locale whose language code is supported (en, fr; fr-CA -> fr), English otherwise. Renders `SettingsListSelect<AppLanguage>(groupLabel: settingsLanguageTitle, stacked: true, value: appLanguage, values: [system, en, fr], labelOf: system -> appLanguageSystem, en -> languageNameEnglish ("English"), fr -> languageNameFrench ("Français") — endonyms, the same in every UI language, subtitle: settingsLanguageSystemSubtitle(language: device.nameInText(l)) (e.g. "System uses English here"; `nameInText` gives `languageInTextEnglish`/`languageInTextFrench`, the language named inside a sentence), onChanged: settingsStore.chooseLanguage)`. `chooseLanguage` sets `appLanguage` and `languagePromptVersion = 1`; the change applies at once (`MaterialApp.locale = appLanguage.locale`), is written to disk immediately (not debounced) and, on Android 13+, pushed to the system per-app language (`LocaleBridge.push`). PC: System = Windows display language (`GetUserPreferredUILanguages`); no per-app OS bridge needed.

### lib/screens/settings/widgets/accent_color_setting.dart

Accent colour row and picker (308 lines).

`AccentColorSetting({settingsStore})` — Observer -> `SettingsRow(title: accentColorTitle, semanticsLabel: settingsAccentColorChange, onTap: showAccentColorPicker, trailing: Row(min, spacing 12, [hex text accentHex(color) (`'#RRGGBB'` upper-case, alpha dropped; Inter 12 w600 letterSpacing 0.48 secondary, tabular), Padding(right 4, a 30 dp circle filled with the colour and ringed by two shadows: BoxShadow(colors.text, spread 3.5) under BoxShadow(colors.card, spread 2) — a 1.5 dp text-coloured ring with a 2 dp card-coloured gap)]))`.

`showAccentColorPicker(context, settingsStore)`: tablet -> `showDialog(barrierColor: kSheetScrim, Dialog(background dialog, no tint, elevation 0, insetPadding 40, radius 24 + cardRing hairline, SizedBox(width 460, SingleChildScrollView(padding fromLTRB(0, 8, 0, 12), picker))))`; phone -> `showModalBottomSheet(isScrollControlled, enableDrag: false (dragging down the colour square must not drag the sheet), no drag handle widget, background sheet, scrim, elevation 0, antiAlias, top radius 24)` whose content is `SafeArea(top: false, SingleChildScrollView(Column[drag-handle look-alike 36x4 handle colour radius 2 with 8/8 padding, picker]))`.

`_AccentPicker` (Stateful): `_hsv = HSVColor.fromColor(Color(accentColor))`; `_apply = AccentThrottle((c) => settingsStore.accentColor = c.toARGB32())` — applies the first change at once then at most every 100 ms with the latest colour (lib/widgets/accent_picker_controls.dart). `_set(hsv)`: setState + `_apply(hsv.toColor())`. `_randomize()`: `HapticFeedback.lightImpact()`, then a random opaque RGB (each channel `nextInt(256)`) via `_set`. Layout inside `Semantics(scopesRoute, namesRoute, explicitChildNodes, label: accentColorTitle)`: header Row (padding left 20, right 8, bottom 4) [Expanded title `accentColorTitle` (pageTitle, letterSpacing -0.27), TextButton `commonDone` (accent, min height 44, padding h14, Stadium, 14 w700) -> pop]; body padding `fromLTRB(20, 8, 20, 22)` Column(spacing 16): `AccentSaturationValue(hsv, onChanged: _set, radius 12)` (the saturation/value square, default height 168), `AccentHueSlider(hue, trackHeight 14, onChanged: hue clamped to [0, 359.999])`, Row(spacing 12) [44x44 swatch radius 12 with #33FFFFFF hairline border, Expanded Column(spacing 2)[hex (Inter 15 w700 letterSpacing 0.6 text, tabular), `settingsAccentColorLive` (12 sp secondary)], quiet `SettingsButton(accentColorRandom, icon: dice glyph size 17)` -> `_randomize`]. Every change is live; Done or the scrim closes. `AccentThrottle` detail: the first call applies at once and starts a 100 ms timer; the timer ALWAYS re-applies `_latest` when it fires, even if no newer colour came; `_AccentPicker` has no `dispose()`, so it never calls `flush()`/`cancel()` and a pending write can land up to 100 ms after the picker closed (harmless: it is the last colour). The PC must keep "the last colour picked is always the one saved". Effect of `accentColor`: seeds `ColorScheme.fromSeed` in `OnsetThemes` (Material component tints), the channel profile header, onboarding, login WebView chrome, clips feed, VOD screen, user notices (see readers list).

### lib/screens/settings/widgets/stream_language_setting.dart

Stream-language filter (88 lines). `StreamLanguageSetting({settingsStore})` — Observer; `selected = streamLanguageOrAll(streamLanguage)` (an unknown saved code reads as `''`); `SettingsRow(title: settingsStreamLanguage, value: streamLanguageName(selected), end: chevron, onTap: showSettingsSheet(builder: StreamLanguageList(selected, onSelected: (code) { streamLanguage = code; pop })))`.

`StreamLanguageList({selected: String?, onSelected, followSetting: ({String label, VoidCallback onTap})?})` (also reused by Browse's per-screen filter, where `followSetting` adds a first row "Follow the setting" selected when `selected == null`). `SettingsSheetContent(title: settingsStreamLanguage, slivers: [SliverPadding(fromLTRB(12, 4, 12, 20), Semantics(label, container, explicitChildNodes, Column[optional follow row, one SettingsChoiceRow per kStreamLanguageCodes]))])`.

`kStreamLanguageCodes` (lib/utils/stream_languages.dart) in order: `''` (`streamLanguageAll`, "All languages"), `en` English, `fr` Français, `es` Español, `de` Deutsch, `pt` Português, `it` Italiano, `ru` Русский, `ja` 日本語, `ko` 한국어, `zh` 中文, `ar` العربية, `tr` Türkçe, `pl` Polski, `nl` Nederlands, `sv` Svenska, `other` (`streamLanguageOther`). Endonyms are identical in every UI language. The value is Helix's `language` query parameter for Top streams, category and tag lists, the live feed and clips feed.

### lib/screens/settings/widgets/hidden_content_labels_setting.dart

Hide labelled streams (87 lines). `HiddenContentLabelsSetting({settingsStore})` — Observer; row `SettingsRow(title: settingsHideLabeled, value: exactly one hidden -> contentLabelName(that id) else settingsHideLabeledValue(count) (ICU plural: "None"/"1"/"N labels" style), end: chevron, onTap: showSettingsSheet(_LabelsList))`.

`_LabelsList` — Observer -> `SettingsSheetContent(title: settingsHideLabeled, slivers: [SliverPadding(fromLTRB(12, 0, 12, 20), Column[note `settingsHideLabeledNote` (padding fromLTRB(8, 4, 8, 12), SettingsText.body at 13 sp height 1.5 secondary), one SettingsCheckRow per knownContentLabelIds])])`. `_toggle(id, hide)`: copies the list, removes the id, appends it when hiding, assigns a NEW list (so observers see the change). Known ids, in order: `DrugsIntoxication, SexualThemes, ViolentGraphic, Gambling, ProfanityVulgarity, MatureGame, DebatedSocialIssuesAndPolitics`, named by `contentLabelName` (localised names; an unknown id is split at camel-case boundaries). Unknown ids: `hiddenContentLabels` keeps any stored string; the row counts `hidden.length` including unknown ids (with exactly one it names it via `contentLabelName`, CamelCase split), but the sheet lists only the known ids, so an unknown id has no checkbox and survives every toggle — only `resetGeneralSettings` clears it (Known Android defects). Effect: streams carrying any hidden label are left out of browsing lists (Top, categories, tags; `stream_list_store`), followed channels always show.

### lib/screens/settings/widgets/caption_style_setting.dart

`captionStyleRows(SettingsStore store)` (59 lines) returns four Observer-wrapped rows for Settings › Video › Captions:
1. `SettingsListSwitch(title: settingsClosedCaptions, subtitle: settingsClosedCaptionsDetail, value: showCaptions)` -> `showCaptions` (Twitch's switch; IVS caption tracks).
2. `SettingsListSelect(title: settingsCaptionSize, values: CaptionSize.values = small(13 sp), medium(15), large(19), extraLarge(24), labels captionSizeSmall/Medium/Large/ExtraLarge)` -> `captionSize`.
3. `SettingsListSelect(title: settingsCaptionBackground, values: [black, translucent, none], labels captionBackgroundBlack/Translucent/None)` -> `captionBackground`.
4. A live sample: `Container(height 76, margin fromLTRB(16, 4, 16, 14), bottom-centre aligned, padding bottom 10, radius 8, LinearGradient(#6B7A8F -> #C9B79C, left to right))` holding `CaptionText(text: settingsCaptionSample, size, background)`.

`CaptionText` (lib/screens/channel/video/captions.dart): `Semantics(liveRegion)`, box colour black / black @ 0.6 / none, radius 2, padding h4 v2, white centred text, max 3 lines ellipsis, font size from `CaptionSize`, and when background is none a two-shadow outline (`Shadow(blurRadius 3)`, `Shadow(offset (1,1), blurRadius 2)`). Size and background are ONSET additions (Twitch's line is Medium on Black); `captionLanguage` is remembered by the caption store, not shown here.

### lib/screens/settings/widgets/settings_twitch_web_token.dart

The twitch.tv web-session token row and dialog (237 lines). The token (`auth-token` cookie) lets the player ask GQL for 1440p HEVC / AV1 enhanced-broadcast renditions (GQL refuses tokens of the app's own client id). Empty keeps the anonymous behaviour.

`SettingsTwitchWebToken({authStore})` — Observer -> `SettingsRow(title: webTokenTitle, subtitle: Text(status), end: chevron, onTap: _edit, trailing: ExcludeSemantics(pill))`. `_status(l)`: `webSessionExpired` -> `webTokenExpired`; else token null -> `webTokenUnset`, set -> `webTokenActive`. The pill: height 28, padding h10, Stadium fill `tile` with `buttonRing` hairline, Row(min, spacing 6)[lock glyph size 13 strokeWidth 2.2 secondary, text `'••••••'` when set else `webTokenNotSet` (Inter 12 w700 letterSpacing 0.96 secondary)] — the token itself is never drawn. `_edit` opens `showDialog(barrierColor: kSheetScrim, _WebTokenDialog)`.

`_WebTokenDialog` (Stateful, owns a `TextEditingController`): `isSet = twitchWebToken != null`, `canSave = controller.text.trim().isNotEmpty`. `SettingsDialog(title: webTokenTitle, message: webTokenExplanation, content: Column(stretch, spacing 14)[status box (min height 44, padding left 12 right 4, fill card, radius 12, trackRing hairline; Row(spacing 10)[lock glyph 16/2 secondary, Expanded text webTokenIsSet / webTokenNoneSet (Inter 14 w600 text), when set a danger TextButton webTokenClear (min height 40, Stadium, 13 w700) -> _save(null)]], TextField(obscureText: true, autocorrect: false, enableSuggestions: false, cursor accent, style Inter 15 w500 letterSpacing 1.5 text, decoration: labelText webTokenNewField when set else the literal 'auth-token' (same in every language), hintText webTokenFieldHint, hintMaxLines 3, floatingLabelBehavior always, filled with `well`, outline radius 12 in buttonRing, focused accent @ 0.7, onChanged setState)], actions [quiet commonCancel -> pop, primary webTokenReplace (set) / webTokenSave (unset), enabled only when canSave -> _save(text)])`. `_save(token)` awaits `authStore.setTwitchWebToken(token)` (trimmed; blank clears; written to secure storage `twitch_web_token`) then pops if mounted. The field starts empty and obscured so the live session is never shown on screen (screenshots/screen share).

PC: identical dialog; storage in the OS keyring; the cookie can also be harvested from the WebView2 login profile (`ICoreWebView2CookieManager.GetCookiesAsync("https://www.twitch.tv")`).

### lib/screens/settings/widgets/chat_bubbles_setting.dart

Chat bubbles (91 lines) — which user-notice kinds render as compact bubbles in chat (instead of full notice rows). `chatBubbleEventLabel(event, l)`: subs -> `chatBubblesSubs`, gifts -> `chatBubblesGifts`, raids -> `chatBubblesRaids`, announcements -> `chatBubblesAnnouncements`, other -> `chatBubblesOther`. `ChatBubbleEvent { subs, gifts, raids, announcements, other }` (lib/models/user_notice_presentation.dart; `chatBubbleEventOf(notice)` maps sub/resub/extendSub/giftPaidUpgrade/anonGiftPaidUpgrade/primePaidUpgrade -> subs, subGift/communityGift/anonSubGift/anonCommunityGift… -> gifts, etc.).

`ChatBubblesSetting({settingsStore})` — Observer -> `SettingsRow(key: ValueKey('chat-bubbles'), title: chatBubblesTitle, subtitle: chatBubblesDetail, value: count == 0 ? chatBubblesOff : chatBubblesCount(count), end: chevron, onTap: showSettingsSheet(ChatBubblesSheet))`.

`ChatBubblesSheet({settingsStore})` — `SettingsSheetContent(title: chatBubblesTitle, slivers: [SliverPadding(fromLTRB(4, 4, 4, 20), Observer(Column of one SettingsListSwitch per ChatBubbleEvent, value = chatBubbleEvents.contains(event.name))))])`. `_toggle(event, on)` rebuilds the list in enum order: `[for e in values if (e == event ? on : current.contains(e.name)) e.name]` — always canonical order, never duplicates. Before the first toggle, though, the row's count is the raw `chatBubbleEvents.length`, so unknown/legacy names and duplicates inflate "N types"; the first toggle silently drops every unknown name and duplicate (Known Android defects). Persisted `chatBubbleEvents` (list of names, default empty = bubbles off); read by chat_message.dart. Reset with the chat settings.

### lib/screens/settings/widgets/chat_filters_setting.dart

`ChatFiltersSetting({settingsStore})` (83 lines) — the official app's "Edit Chat Filters", opened from Chat › Filters (`SettingsPageId.chatFilters`; a sub page on a tablet with "‹ Chat" back). Observer; `on = chatFiltersEnabled`. `SettingsGroupsView` with three groups:
1. Untitled: master switch `chatFiltersEnable` -> `chatFiltersEnabled`; `SettingsNote(chatFiltersExplanation)`.
2. `chatFiltersGroup`: four category switches (title + description subtitle), each enabled only when the master is on (`onChanged: on ? … : null`, dimmed 0.42 otherwise): `chatFilterDiscrimination` / `chatFilterDiscriminationDetail` -> `chatFilterDiscrimination`; `chatFilterSexual` / `…Detail` -> `chatFilterSexual`; `chatFilterHarassment` / `…Detail` -> `chatFilterHarassment`; `chatFilterProfanity` / `…Detail` -> `chatFilterProfanity`.
3. Untitled: `SettingsNote(chatFiltersNote)`.
Effect (lib/screens/channel/chat/chat_filters.dart): when enabled, words AutoMod rates 3 or more in an enabled category are hidden in chat messages. Defaults: master off, all four categories on.

### lib/screens/settings/widgets/settings_muted_words.dart

Muted keywords (316 lines). `SettingsMutedWords({settingsStore})` — Observer -> `SettingsRow(glyph: mute, title: mutedKeywordsTitle, value: mutedKeywordsCount(count), end: chevron, onTap: showSettingsSheet(MutedWordsSheet))`.

`MutedWordsSheet({settingsStore})` (Stateful; owns `TextEditingController` and `FocusNode` so it survives a fold that swaps the tablet pane for the phone profile while open). `addMutedWord(text)`: blank (after trim) -> clear the field and unfocus; else `mutedWords = [...mutedWords, text]` (the untrimmed text, duplicates allowed), clear, unfocus. `removeMutedWord(index)`: `mutedWords = [...mutedWords..removeAt(index)]` (note: mutates the current list in place before copying). Build: its own `ScaffoldMessenger` + transparent `Scaffold(resizeToAvoidBottomInset: false)` so the Undo snackbar shows on the sheet.

Content: `SettingsSheetContent(title: mutedKeywordsTitle, pinned: field, slivers: [list])`. Pinned field: padding `fromLTRB(16, 4, 16, 0)` + bottom 10; `ListenableBuilder(textController)`; `Container(height 48, padding left 16 right 4, ShapeDecoration(well, StadiumBorder(buttonRing hairline)))` Row(spacing 8)[Expanded TextField(onSubmitted: addMutedWord, autocorrect false, cursor accent, Inter 15 text, hint `mutedKeywordsHint` in tertiary, no borders, dense), a 40 dp circular button `AnimatedContainer(settingsMotion 160 ms)` filled `tile` when the field is empty / accent otherwise, with a check glyph (stroke 2.4, secondary / onAccent), tooltip and semantics label `commonCancel` when empty / `mutedKeywordsAdd` otherwise; `submit()` unfocuses when empty, else adds].

List (Observer): empty -> padding v36, Column(spacing 10)[48 dp `tile` circle with mute glyph size 22 secondary, `mutedKeywordsEmpty` (Inter 14 w600 body)]; else `SliverPadding(fromLTRB(16, 0, 16, 20))` a box (fill `stackIdle`, radius 16, cardRing hairline) of rows separated by hairlines: padding `fromLTRB(16, 4, 4, 4)`, Row[Expanded word (Inter 15 text, 1 line ellipsis), `IconButton(tooltip: mutedKeywordsRemove(word), 44x44, trash glyph secondary)` -> `_remove`]. `_remove(context, index)`: removes, then shows `SnackBar(mutedKeywordsRemoved(word), action: commonUndo)`; Undo appends the word back at the END (`[...mutedWords, word]`), not its old index. Matching (chat_store / vod_chat_replay_store) honours `matchWholeWord` (default true).

### lib/screens/settings/widgets/chat_account_sync.dart

Twitch-account chat settings sync (172 lines). Four local settings mirror Twitch's synced chat UI settings: extension `ChatUiSettingsLocal on SettingsStore` — getter `chatUiSettings` = `ChatUiSettings({emoteAnimations: animateEmotes, gifs: showGifs, gifAnimations: animateGifs, readableColors: readableNameColors})`; `applyChatUiSettings(s)` writes those four back.

`ChatUiSetting` (lib/models/chat_ui_settings.dart) with GQL field / operation / mutation / input type: `emoteAnimations` (`isEmoteAnimationsEnabled`, `SyncedSettingsSetEmoteAnimations`, `setEmoteAnimationsEnabled`, `SetEmoteAnimationsEnabledInput`); `gifs` (`isGifsEnabled`, `SyncedSettingsSetGifsEnabled`, `setGifsEnabled`, `SetGifsEnabledInput`); `gifAnimations` (`isGifAnimationsEnabled`, `SyncedSettingsSetGifAnimationsEnabled`, `setGifAnimationsEnabled`, `SetGifAnimationsEnabledInput`); `readableColors` (`isReadableChatColorsEnabled`, `SetReadableChatColorsPreference`, `setReadableChatColorsEnabled`, `SetReadableChatColorsEnabledInput`). Mutation document: `mutation <operation>($input: <inputType>!) { <mutation>(input: $input) { <field> } }`. `ChatUiSettings.fromSettings` returns null unless all four fields are booleans; `differencesFrom(other)` lists the settings that differ, in enum order.

Network (TwitchViewerActionsService, `POST https://gql.twitch.tv/gql`, headers `Client-ID: kimne78kx3ncx6brgo4mv6wki5h1ko` (Twitch web client) and `Authorization: OAuth <twitch.tv web token>`): load = operation `ChatUISettingsQuery`, query `query ChatUISettingsQuery { currentUser { id chatUISettings { isReadableChatColorsEnabled isEmoteAnimationsEnabled isGifsEnabled isGifAnimationsEnabled } } }`, empty variables; empty token or any error -> null. Save = `_send(operation, document, field: mutation, input: {<field>: enabled}, succeeded: payload[field] == enabled)` -> `ViewerActionOutcome { done, refused (payload.error), integrityRefused (an error message containing "integrity"), signedOut (empty token or 401), failed }`.

`ChatAccountSyncGroup({settingsStore, load, save})` — keys `useAccountKey = ValueKey('chat-sync-use-account')`, `saveKey = ValueKey('chat-sync-save')`. State: `_account`, `_loading = true`, `_busy = false`; `initState` -> `_reload()` (load, then setState account + loading false if mounted). Build: Observer -> `SettingsGroup(title: chatSyncTitle)` with: loading -> a centred 22 dp `CircularProgressIndicator(strokeWidth 2)` with padding 16; account null -> `SettingsNote(chatSyncUnavailable)`; else rows:
- `SettingsNote(inSync ? chatSyncInSync : chatSyncDiffers(count: differences))`;
- `SettingsRow(key useAccountKey, glyph reconnect, title chatSyncUseAccount, subtitle chatSyncUseAccountDetail, enabled/tappable only when idle = !inSync && !busy)` -> `_useAccount`: remembers the local values, applies the account's, snackbar `chatSyncApplied` with action `commonUndo` restoring the previous values;
- `SettingsRow(key saveKey, glyph user, title chatSyncSave, subtitle chatSyncSaveDetail, idle only)` -> `_saveToAccount`: computes changes (no-op if none or busy), `confirmSettingsAction(title chatSyncSaveConfirmTitle, message chatSyncSaveConfirmBody(count), confirm chatSyncSaveAction, danger false)`; then busy, sends each differing setting in order and stops at the first non-`done` outcome; reloads (keeps the old account on a null reload); snackbar `viewerActionResult(status: outcome.name)` (ICU select on done/refused/integrityRefused/signedOut/failed).
Snackbars hide the current one first. Shown in Chat settings only when logged in and the service is provided.

### lib/screens/settings/widgets/mention_notification_setting.dart

`MentionNotificationSetting({settingsStore, loggedIn, platform = const GoLivePlatform()})` (104 lines) — Twitch's "Chat Mentions": a notice when someone mentions the viewer in a connected chat while the app is in the background or in PiP. Shares the notification permission with go-live notices (`platform.allowed()` / `requestPermission()`).

State: `_blocked` (notifications not allowed by the system), `_refused` (the viewer just refused the permission). `initState` -> `_check()`: `allowed()` (errors read as allowed) -> `_blocked = !allowed`. `_ask()`: `requestPermission()` (errors = false) -> `_refused = !granted`, clears `_blocked` when granted. `_set(on)`: off -> `mentionNotifications = false`, `_refused = false`; on -> `explainUnlessAllowed(context, allowed)` (shows the app's explanation sheet first unless already allowed; returns false if dismissed), then `_ask()`, and only if not refused sets `mentionNotifications = true`.

Build (Observer): `on = loggedIn && mentionNotifications`. Subtitle: logged out -> `mentionLoggedOut`; refused -> `notificationsAllowInSystem` in `colorScheme.error`; on and blocked -> Column[`mentionBlocked` (error colour), `TextButton(mentionAllow)` -> `_ask`]; else `mentionDetail`. `SettingsListSwitch(title: mentionTitle, subtitle, value: on, onChanged: loggedIn ? _set : null)`. Read by chat_store to post the notice; also summarised in Profile's Notifications row (on/off). PC: Windows toast notifications (no runtime permission; respect Focus Assist), same logged-out/blocked texts where applicable.

### lib/screens/settings/widgets/twitch_notification_settings.dart

`TwitchNotificationSettingsGroup({load, onEdit})` (115 lines) — Twitch's own notification preferences, read-only. `editKey = ValueKey('twitch-notification-settings-edit')`. State `_settings` / `_loading = true`; `initState` -> `_reload()`. Build: `SettingsGroup(title: twitchNotificationSettingsTitle)` with: loading -> centred 22 dp `CircularProgressIndicator(strokeWidth 2)` (padding 16); null -> `SettingsNote(twitchNotificationSettingsUnavailable)` — the loader (`TwitchSocialService.notificationSettings`) returns null for a non-numeric user id, any GQL error or exception (swallowed by `_query`), a missing list, AND an empty parsed list (`parsed.isEmpty ? null : parsed`), so an empty list also reads "unavailable"; `_reload` has no try/catch (like the gift and whisper groups), so a loader that throws leaves the spinner forever — the injected loaders must never throw, only return null; else one `SettingsRow(glyph bell, title: notificationCategoryLabel(category), subtitle: twitchNotificationPlatforms(push: state, email: state))` per category, where state is `'on'`, `'off'` or `'none'` (platform missing) — consumed by ICU selects; always last `SettingsRow(key editKey, glyph link, twitchNotificationSettingsEdit, end external, onTap: onEdit)` (opens twitch.tv `/settings/notifications` signed in).

`notificationCategoryLabel(l, category)`: `'3pdevelopers'` -> `notificationCategoryDevelopers`, `'chat'` -> `…Chat`, `'clips'` -> `…Clips`, `'creator'` -> `…Creator`, `'events'` -> `…Events`, `'giftsandrewards'` -> `…Gifts`, `'live'` -> `…Live`, `'marketing'` -> `…Marketing`, `'moderator'` -> `…Moderation`, `'recommendedlive'` -> `…RecommendedLive`, `'social'` -> `…Social`, `'subscriptions'` -> `…Subscriptions`, `'followeradd'` -> `…Followers`, `'videos'` -> `…Videos`, anything else -> `notificationCategoryOther`.

Data: `TwitchSocialService.notificationSettings` = GQL `UserNotificationSettingsQuery` with document `query UserNotificationSettingsQuery($user: ID) { user(id: $user) { notificationSettings { category platforms { platformName settingState isEnabled } } } }`, variables `{user: <id>}`, web-client headers with the twitch.tv web token. Each category keeps `push`/`email` booleans from `platformName`/`isEnabled`; a category with neither is dropped.

### lib/screens/settings/widgets/go_live_setting.dart

Go-live notices (252 lines). `GoLivePlatform` (const, swappable in tests): `supported` = `GoLiveScheduler.supported` (`Platform.isAndroid`), `requestPermission()` / `allowed()` = `GoLiveNotifications`, `start()` / `stop()` = `GoLiveScheduler` (WorkManager periodic task every `kGoLiveInterval = 15 minutes` that checks followed channels in a background isolate using the stored `user_token`).

`GoLiveSetting({userId (null when logged out), platform})`. Private `enum _GoLiveProblem { readFailed, refused, turnOnFailed, turnOffFailed }`. State: `_prefs` (GoLivePrefs from shared preferences: keys `go_live_enabled`, `go_live_muted`, `go_live_user_id`, `go_live_seen`, `go_live_problem`, `go_live_checked_at`, `go_live_announced`), `_busy`, `_problem`, `_blocked`. `_load()`: loads prefs; `blocked = enabled && supported && !allowed()`; errors -> `_report` (debugPrint + `Telemetry.recordError(reason: 'go-live setting')`) and `readFailed`. `_set(on)` (no-op without prefs): busy, clears problem; ON -> `askNotificationPermission(allowed, request)`: dismissed -> stop, refused -> `refused`; granted -> `platform.start()` FIRST (the switch says on only once scheduled), `setUserId(userId)`, `setEnabled(true)`, `setProblem(null)`, `_blocked = false`. OFF -> `setEnabled(false)` then `platform.stop()`. Exceptions: report; if turning on, `setEnabled(false)` (errors swallowed); problem `turnOnFailed`/`turnOffFailed`. Finally clear busy.

Build: `on = prefs.enabled && loggedIn`. Subtitle priority: unsupported -> `goLiveAndroidOnly`; logged out -> `goLiveLoggedOut`; problem -> `goLiveReadFailed` / `notificationsAllowInSystem` / `goLiveTurnOnFailed` / `goLiveTurnOffFailed`; on and blocked -> `goLiveBlocked`; on and the background check stored a problem (Twitch refused its login) -> `goLiveLogInAgain`; on -> `goLiveOnDetail`; else `goLiveOffDetail`. The subtitle is in `colorScheme.error` when there is a problem, or on and blocked / stored problem. `SettingsListSwitch(title: goLiveTitle, value: on, onChanged: supported && loggedIn && prefs != null && !busy ? _set : null)`.

`GoLiveBellTile({channelId, name})` — used in a channel's preferences sheet; hidden unless go-live notices are on. `on = !prefs.muted.contains(channelId)`. Padding `fromLTRB(16, 10, 16, 10)`, Column(start, spacing 8): Row(spacing 14)[`SheetGlyph(bell)`, Expanded `goLiveBellLevelTitle(name)` in `SheetText.body`], `Wrap(spacing 8, runSpacing 8)` of `SheetChoicePill(key 'bell-all', goLiveBellAll, selected on)` and `SheetChoicePill(key 'bell-none', goLiveBellNone, selected !on)`; choosing the unselected one calls `prefs.setMuted(channelId, !value)`; failure -> report + SnackBar `goLiveBellFailed`; always setState.

PC equivalent: a background poller in the Rust app (tokio task every 15 minutes while running, optionally a Windows Scheduled Task / startup entry for when closed) using the keyring's user token; Windows toast notifications; the muted set stored with the app's preferences.

### lib/screens/settings/widgets/update_check_tile.dart

`UpdateCheckTile({updater: OnsetUpdater})` (82 lines) — "Check for updates" in Other › Updates (only when `updater.enabled`: Android with an update repository configured). State: `_currentBuild = updater.currentBuild()` (installed build number from PackageInfo), `_checking`. `_check()`: `_checking = true`; `updater.check(force: true)` (ignores the 6 h throttle and a 24 h postponement); exceptions log `'Update check failed: <type>'` and become `UpdateCheckFailed`; then `_checking = false` and: `UpdateAvailable` -> `offerUpdate(context, updater, result)`; `UpToDate` -> SnackBar `updatesUpToDate`; `UpdateCheckFailed` -> SnackBar `updatesCheckFailed`; `UpdateCheckSkipped` -> nothing. Snackbars use `AlertMessage(centered: false)`.

Row: `SettingsRow(glyph update, title updatesCheck, subtitle FutureBuilder -> updatesBuild(build) (tabular) or '' while loading, trailing while checking an 18 dp CircularProgressIndicator(strokeWidth 2, colour accent, background buttonRing, semanticsLabel updatesChecking), onTap: null while checking)`.

**Update prompt** (lib/widgets/onset_update_prompt.dart, `offerUpdate`): asks with `UpdateAvailableDialog` (ONSET tile, build, installed build, download size, start of the release notes, "Update" / "Later") — a non-dismissible bottom sheet on a phone (no drag, back = Later, drag-handle look-alike 36x4, padding `fromLTRB(20, 8, 20, 24)`) or a non-dismissible dialog 420 wide on a tablet; Later -> `updater.postpone(release)` (prefs `onset_update_postponed_build` / `onset_update_postponed_at`, quiet 24 h). Accepted -> if Android may not install unknown apps, `confirmSettingsAction(updateAllowTitle, updateAllowMessage, confirm updateOpenSettings, danger false)` then open the system page and wait for the next resume; still not allowed -> snackbar `updateNotAllowed`. Then a non-dismissible `UpdateProgressDialog` downloads (GitHub `GET https://api.github.com/repos/<repo>/releases/latest`, asset `…/releases/assets/<id>` with `Accept: application/octet-stream`, redirect followed by hand so the token stays on api.github.com; file `onset-<build>.apk`; SHA-256 verified) and installs; errors -> `updateCorrupted` (integrity), `updateInstallFailed`, cancel -> nothing, other -> `updateDownloadFailed`. Automatic checks: at most every 6 h (`onset_update_last_check`).

Update prompt details (lib/widgets/onset_update_prompt.dart, exact values):
- `UpdateAvailableDialog({release, currentBuild})` — `Semantics(scopesRoute, namesRoute, explicitChildNodes, label: updateAvailable)`, Column(min, stretch, spacing 16): header Row(spacing 14)[52x52 Stack: `OnsetMarkTile(size 52, radius 15)` (excluded from semantics) with, at right -5 / bottom -5, a 24 dp circle filled `OnsetTokens.backgroundDark` with a 2 dp `colors.sheet` border holding the `update` glyph (size 14, stroke 2.6, accent); Expanded Column[eyebrow `updateNewBuild` (Inter 10.5 w800 letterSpacing 1.26 accent), semantics-header `updateAvailable` (Inter 22 w800 letterSpacing -0.55 height 1.15 text)]]; `updateReady(build)` (Inter 15 w600 text); installed line = [`updateInstalledBuild(build)` when known, `updateSize(megabytes: apkSize / 1048576)` (one decimal) when apkSize > 0, `updateChecked`] joined `' · '` (Inter 12.5 tabular secondary); a notes box only when the trimmed notes are non-empty (maxHeight 123, fill well, radius 14, cardRing hairline; padding 14 Text maxLines 6 clipped, Inter 13 height 1.6 body; a 34 dp bottom fade well@0 -> well); buttons Column(spacing 8)[primary large expanded `updateNow` -> pop(true), quiet large expanded `updateLater` -> pop(false)]. Tablet dialog: SingleChildScrollView padding 24; phone: handle bottom margin 16.
- Any answer other than true (null included) postpones. Declining the install-permission confirmation returns with neither a postponement nor a snackbar. `_tell` snackbars use `ScaffoldMessenger.of` and do NOT hide the current one.
- `UpdateProgressDialog({updater, release})` — owns a dio `CancelToken`, `_installing`, `_received`, `_total = release.apkSize`; `initState` runs `downloadAndInstall(cancelToken, onInstall -> installing, onProgress -> received/total)` and pops with the caught error, or null once installed; `dispose()` cancels the token if not already. `PopScope(canPop: false)` around `SettingsDialog(title: installing ? updateInstalling : updateDownloading, content Column(stretch, spacing 14)[LinearProgressIndicator(value: null (indeterminate) while installing or when total <= 0 else clamp(received/total), minHeight 6, radius 3, accent on switchOff), text updateProgress(received MiB, total MiB) when total > 0 else updateSize(received MiB) (Inter 13 tabular secondary)], actions [Opacity(0.4 while installing, quiet commonCancel disabled while installing or once cancelled; cancels the token -> UpdateCancelledException -> silent)])`.
- `mixin OnsetUpdateChecks<T> on State<T>` (used by Home): `initState` reads the optional `OnsetUpdater`; always `removeInstalledDownloads()` (even when disabled); when enabled registers `AppLifecycleListener(onResume: _checkForUpdate)` and checks after the first frame. `_checkForUpdate`: guarded by `_updateBusy` and `mounted`; `updater.check()` (throttled 6 h / postpone 24 h); on `UpdateAvailable` awaits the `beforeUpdateOffer()` hook (Home completes it once its one-time language sheet closed, so sheets never stack) then `offerUpdate`; errors swallowed with `'Update check failed: <type>'`; `dispose` disposes the listener.

PC equivalent: same tile and prompt; the Windows updater downloads the release's `.msi`/`.exe` (or a signed zip) from GitHub releases, verifies SHA-256 (and Authenticode), then runs the installer and exits (e.g. `self_update`/`velopack`-style); "install unknown apps" step does not exist.

### lib/screens/settings/widgets/release_notes.dart

The release-notes page and its Markdown parser (1058 lines).

**`ReleaseNotes({updatedTo, updatedFrom})`** — `routeName = 'ReleaseNotes'`; assets `englishAsset = 'assets/release-notes.md'` (reference) and `frenchAsset = 'assets/release-notes.fr.md'` (version-for-version translation). Test hooks `debugSource` / `debugFrenchSource`. `read([locale])`: for French reads the French asset (or `debugFrenchSource`; while only `debugSource` is set, French reads as missing so test notes never mix with bundled ones) and returns it when non-blank; otherwise reads English; unreadable -> null (logs `'Release notes unreadable: <type>'`); never throws. `load([locale])` = `read ?? ''`. `updatedTo` = installed version when the page opens by itself after an update ("Just updated"); null from Settings. `updatedFrom` = previous version when known.

State: `_data` (null while loading), `_open` (phone: indexes of expanded earlier versions — by position, two entries may share a version), `_selected` (tablet: picked index, survives rotation), three ScrollControllers (phone, aside, detail), `_locale`, `_reading` counter. `didChangeDependencies`: when the locale changes re-`_load(locale)` (drops stale reads; a defensive catch sets empty data). `_close()` = `Navigator.maybePop`. `_toggle(i)` flips membership. `_featured(entries)`: 0, or after an update the first entry whose `releaseMajorMinor` equals the installed one's (notes may already contain a newer version). `_shown` = valid `_selected` else featured. `_pick(i)`: ignore if already shown; `Haptics.selection()` (selection click); select; jump the detail scroll to 0.

`build`: `StaggerScope(key: ValueKey(data != null))` so the entrance plays once when the notes arrive; tablet when `isLargeScreen`. `_enter(index, child)` = `StaggeredEntrance(index, offset: 6, step: fresh ? 60 ms (launchStaggerStep) : 40 ms)` (350 ms emphasized-decelerate each).

**Phone** — `SettingsScaffold(title: settingsReleaseNotes, onBack: _close)`; loading -> nothing; empty -> padding `fromLTRB(32+L, top, 32+R, 96+bottom)` centring `ReleaseEmptyState(tablet: false)`; else `_phoneNotes`: children (each entering in order, `spacing 22`): `ReleaseFreshHero(to, from)` when updated; the preamble as an untitled `ReleaseSectionView` (h-padding 4) when present; a Column(spacing 14)[eyebrow `releaseNotesWhatsNew` (only from Settings), `ReleaseLatestCard(entries[featured], latest: featured == 0)`]; `ReleaseEarlierVersions(title: featured == 0 ? releaseNotesEarlierVersions : releaseNotesOtherVersions, entries, indexes: all but featured, open, onToggle)` when others exist; `ReleaseFootnote` (h-padding 4, not animated). Inside `Align(topCenter, ConstrainedBox(maxWidth 720, SingleChildScrollView(padding fromLTRB(16+L, top+18, 16+R, bottom + (updated ? 120 : 36)))))` — everything built so it can be searched and keeps state. After an update a bottom overlay: gradient (never blur — the page can open over video) from ground @0 -> @0.92 (stop 0.34) -> ground, padding `fromLTRB(16+L, 28, 16+R, 24+bottom)`, centred max 688 wide `ReleasePrimaryButton(releaseNotesGotIt, onPressed: _close)`.

**Tablet** — own `Scaffold` (system overlay from theme). Header: padding `fromLTRB(18+L, top, 28+R, 0)`, height 84, Row(spacing 8)[`ReleaseRoundBack(_close)`, Expanded Column(centre, spacing 4)(left padding 8)[eyebrow `releaseNotesWhatsNew` or `releaseNotesWhatsNewIn(version: to)`, semantics-header title `settingsReleaseNotes` or `releaseNotesUpdatedTo(version: to)` (Inter 28 w800 letterSpacing -0.84 height 1.1, 1 line ellipsis)], when updated and entries exist a Flexible entering Row(end, spacing 16)[`ReleaseWasOn(from, fontSize 13.5, maxLines 1)` if known, `ReleasePrimaryButton(releaseNotesGotIt, height 44, fontSize 14, expand false)`]]. Body (top padding removed): loading nothing; empty -> padding `fromLTRB(28+L, 0, 28+R, 28+bottom)` a `well` box radius 24 with cardRing hairline holding `ReleaseEmptyState(tablet: true)` (padding 32/0/32/40); else `_tabletPanes`: aside width 340 when window width >= 1100 else 280 (enter 0), 32 gap, 0.5 hairline (bottom 28), 32 gap, Expanded detail (enter 1), side padding 28 (+insets). Aside ListView (padding top 4, bottom 28+inset): preamble (padding `fromLTRB(12, 0, 12, 14)`), `ReleaseListLabel(releaseNotesVersions)` (h12), 10, one `ReleaseVersionRow(entry, latest: i == 0, selected: i == shown, onTap: _pick(i))` per entry (bottom 2), `ReleaseFootnote` (padding 12/8/12/0). Detail ListView (padding `fromLTRB(4, 4, 4, 40+bottom)`) with an `AnimatedSwitcher(300 ms or 150 ms reduced, switchIn OnsetMotion.standard, layout = only the current child (the old one disappears at once), fade + (unless reduced) slide from Offset(0, 0.008))` of `ReleaseDetail(key: ValueKey(index), entry, latest, newer: entries[index-1]?, older: entries[index+1]?, onNewer, onOlder)`.

**Parser.** Blocks (sealed `ReleaseNotesBlock`): `ReleaseVersion(version, date?)` ("## v1.0.0" + date line), `ReleaseSection(title)` ("### …"), `ReleasePoint(text, {platform, level 0|1})` with `extended(more)`, `ReleaseRule` ("---"/"***"), `ReleaseParagraph(text)`. `_platformTag = ^\[(iOS|Android)\]\s*`. Date line regex: `^(?:[A-Z][a-z]+ \d{1,2}, \d{4}|(?:1er|\d{1,2})[   ](?:janvier|février|mars|avril|mai|juin|juillet|août|septembre|octobre|novembre|décembre)[   ]\d{4})$`. `releaseDay(date)` parses English (`Month D, YYYY`) or French (`1er|D month YYYY`, NBSP / narrow NBSP allowed, decomposed accents composed first) and rejects impossible days (e.g. February 31). `_composed(text)` maps decomposed French letters (base + U+0300/0301/0302/0308/0327) to precomposed (à â è é ê ë î ï ô ù û ü ÿ ç and capitals).

`parseReleaseNotes(markdown)`: composes, splits on `\r?\n`; skips blank lines and one-line `<!-- … -->` comments; an indented non-bullet line after a point extends it; `## ` -> version, taking the next non-blank line as date when it matches; `### ` -> section; `---`/`***` -> rule; `- `/`* ` -> point (indented = level 1; platform tag stripped into `platform`); anything else -> paragraph with leading `#`s stripped.

`ReleaseSectionKind { added, improved, fixed, other }.of(title)` (case-insensitive, fix checked first): fixed = whole word `(bug|hot)?fix(es|ed|ing|ups?)?` or `corrections?` (not "prefixes") or French `corrections?|correctifs?|corrigé(e|s|es)?`; added = `\b(new|features?|added)\b` or French `nouveautés?|nouveaux?|nouvelles?|fonctionnalités?|ajouts?|ajouté(e|s|es)?`; improved = `\b(improvements?|improved|changed)\b` or French `améliorations?|amélioré(e|s|es)?|changements?|modifications?|modifié(e|s|es)?`; French words matched as whole words (no letter/digit around). Labels for counts: `releaseKindAdded/Improved/Fixed/Other(count)`.

`ReleaseEntrySection({title?, items})` — `kind`, `count` = level-0 points. `ReleaseEntry({version (without leading v), date, notes, sections})` — lazy `day`, `label` = `'v$version'` when it starts with a digit else as written, `name` = `'ONSET $version'` (or as written), `counts` per kind (zero kinds removed), `summary(l)` = kinds in enum order joined by `' · '` (e.g. "2 new · 3 improvements · 1 fix"). `ReleaseNotesData({preamble, entries})`. `releaseMajorMinor('v1.1.3') = '1.1'`.

`parseReleaseEntries(markdown)`: before the first version, sections become paragraphs and points/paragraphs go to the preamble; after it, a section closes the previous one; points open an (untitled) section implicitly; paragraphs go to the current section or, before any section, to the entry's notes; rules are ignored; a `v` before a digit is stripped from versions.

`shouldShowReleaseNotes({lastShown, current, notes})`: false on first launch (`lastShown == null`) or same major.minor; true only if the notes contain a version with the current major.minor.

### lib/screens/settings/widgets/release_notes_parts.dart

The visual pieces of the release-notes page (1542 lines), shared by phone and tablet. `_inter(size, {weight = w400, spacing, height, color, tabular = false})` builds an Inter TextStyle (tabular figures when asked). `OnsetTokens.radiusPill = 100`.

- **`ReleaseEyebrow(text)`** — Inter 10.5 w800, letterSpacing 1.26 (0.12 em), accent colour, text used as given (the ARB strings are already upper-case, e.g. `releaseNotesWhatsNew` = "WHAT’S NEW", `releaseNotesWhatsNewIn` = "WHAT’S NEW IN {version}").
- **`ReleaseListLabel(text)`** — semantics header, `text.toUpperCase()`, Inter 11 w600 letterSpacing 1.54 secondary.
- **`ReleaseFootnote`** — `releaseNotesFootnote` ("Release notes open by themselves after an update to a new version."), Inter 12.5 height 1.5 tertiary.
- **`ReleaseVersionPill(label, {latest})`** — height 24, padding h10, centred, radius 100; latest: fill accent, text onAccent w800; else fill `tile` with `switchRing` hairline, text colour w700; Inter 12 letterSpacing -0.12 tabular, 1 line.
- **`ReleasePrimaryButton({label, onPressed, height = 48, fontSize = 15, expand = true})`** — `Semantics(container, button, label, onTap, excludeSemantics)`, PressScale, opaque GestureDetector, Container(height, width infinite when expand, padding h24, centred, accent fill, radius 100) with the label Inter fontSize w700 onAccent.
- **`ReleaseWasOn(version, {sinceThen = false, fontSize = 14, maxLines})`** — rich text from `releaseNotesWasOnSince(version: mark)` or `releaseNotesWasOn(version: mark)` where the l10n mark is replaced by the version in tabular figures coloured `body`; base Inter fontSize height 1.5 secondary; ellipsis when maxLines given.
- **`ReleaseFreshHero({to, from})`** — padding `fromLTRB(4, 6, 4, 2)`, Column(start, spacing 14): Row(spacing 14)[52x52 Stack: `OnsetMarkTile(size 52, radius 15)` (excluded from semantics) with, at right -5 bottom -5, a 24 dp circle of the scaffold ground (2 dp ground border) holding a check glyph (size 14, stroke 2.8, accent); Expanded Column(spacing 3)[`ReleaseEyebrow(releaseNotesWhatsNewIn(version: to))`, semantics header `releaseNotesUpdatedTo(version: to)` Inter 24 w800 letterSpacing -0.72 height 1.1 text]], then `ReleaseWasOn(from, sinceThen: true)` when known.
- **`ReleaseSectionView(section, {gap = 10})`** — Column(stretch, spacing gap): when titled, Row(spacing 10)[26x26 box (tile, radius 8, cardRing hairline) with `section.kind.glyph` size 15 tileIcon; Flexible semantics-header title upper-cased (2 lines ellipsis, Inter 13 w700 letterSpacing 0.78 body); the count `'${section.count}'` (Inter 12 w600 tabular tertiary, semanticsLabel `releaseNotesPoints(count)`)]; then Column(spacing 8) of items: `ReleasePointView` for points, `ReleaseRichText(paragraph, Inter 14 height 1.55 secondary)` for paragraphs.
- **`ReleasePointView(point)`** — any `level > 0` gets one 16 dp left indent (there is no deeper nesting); Row(start, spacing 10)[5x5 dot with top margin 9: filled tertiary (level 0) or, for `level > 0`, unfilled with a default 1 dp `tertiary` border ring; Expanded `ReleaseRichText(text, platform, Inter 14 height 1.5 body)`].
- **Inline Markdown** `_inlinePattern = \[([^\]]+)\]\(([^)\s]+)\)|\*\*([^*]+)\*\*|`([^`]+)``. `releaseLinkOf(href)` -> Uri only for http/https with a host (anything else renders its label as plain text). **`ReleaseRichText(text, {style, platform})`** (Stateful, one `TapGestureRecognizer` per link URL, disposed when the text changes or on dispose): optional platform tag WidgetSpan first (min height 18, right margin 6, padding h6, tile fill radius 5 buttonRing hairline, `Align(widthFactor 1)`, Inter 10 w600 letterSpacing 0.2 secondary); links = accent underlined (accent decoration) opening `LinkRouter.open(url, launchExternal: SettingsStore.launchUrlExternal)` (errors logged); `**bold**` = w700 text colour; `` `code` `` = WidgetSpan box (padding h6 v1, tile, radius 6, trackRing hairline) with Inter 13 w500 tabular text colour, 1 line, no wrap, ellipsis.
- **`ReleaseNotesParagraphs(paragraphs)`** — Column(spacing 8) of rich texts Inter 14 height 1.55 secondary.
- **`ReleaseLatestCard(entry, {latest = true})`** — padding `fromLTRB(16, 18, 16, 20)`, card fill, radius 16, cardRing hairline; Column(stretch, spacing 18): [Column(start, spacing 8): Row(spacing 8)[`ReleaseVersionPill(entry.label, latest)`, when latest `releaseNotesLatest` (Inter 12 w600 body), Expanded date (1 line, end-aligned, Inter 12.5 secondary)], Column(spacing 4)[semantics header `entry.name` (Inter 20 w700 letterSpacing -0.4 text), summary when non-empty (Inter 12.5 tabular tertiary)]], notes paragraphs, every section view].
- **`_VersionLines({entry, latest, selected?})`** — version label Inter 16 (w800 when selected else w700) letterSpacing -0.16 tabular, colour text (phone or selected) / body. Tablet (`selected != null`, spacing 4): Row(spacing 8)[Flexible version, when latest a 20-high pill (padding h8, accent, radius 100) with `releaseNotesLatestBadge` Inter 10.5 w800 letterSpacing 0.42 onAccent], then the date on its own line in SHORT form `DateFormat.yMMMd(localeName)` of `entry.day` (falls back to the written date if no day or no date data), Inter 12.5 secondary. Phone (spacing 3): baseline Row(spacing 10)[Flexible version, Flexible written date]. Then the summary (Inter 12.5 tabular tertiary) when non-empty.
- `_rowLabel(l, entry, {latest})` — screen-reader label `[label, latest ? releaseNotesLatest, date, summary].join(', ')`.
- **`ReleaseEarlierVersions({title, entries, indexes, open, onToggle})`** — Column(spacing 8): `ReleaseListLabel(title ?? releaseNotesEarlierVersions)` (h4), then a card (fill card, radius 16, cardRing hairline, clipped, transparent Material) of `_EarlierRow`s (key = index) with a hairline top border on all but the first.
- **`_EarlierRow`** — `AnimationController.unbounded(value: open ? 1 : 0)`; open/close with a critically damped spring `SpringDescription.withDurationAndBounce(duration: 300 ms)` continuing from the current value and velocity, snapped exactly to the target afterwards; under reduce motion it jumps. `_toggle`: `Haptics.selection()` then `onToggle`. Header: `Semantics(container, button, expanded, label: _rowLabel, onTap, excludeSemantics)` `InkWell(NoSplash, highlight pressed)` min height 64, padding `fromLTRB(16, 12, 14, 12)`, Row(spacing 12)[Expanded `_VersionLines(entry)`, chevronDown (stroke 2, secondary) rotated by `progress.clamp(0,1) * pi`]. Body: not built when fully closed; full child when 1; otherwise `ClipRect(Align(topCenter, heightFactor: value, Opacity(clamp(value / 0.8))))`; body padding `fromLTRB(16, 2, 16, 20)` Column(spacing 18)[notes, sections].
- **`ReleaseVersionRow({entry, latest, selected, onTap})`** (tablet list) — semantics button/selected with `_rowLabel(latest)`, PressScale, `AnimatedContainer(settingsMotion 220 ms, standard, min height 68, padding fromLTRB(14, 12, 12, 12), fill accent @ 0.10 selected / 0, radius 14, border accent @ 0.45 selected / 0 hairline)`, Row(spacing 12)[Expanded `_VersionLines(latest, selected)`, chevronRight stroke 2 (accent when selected else tertiary)].
- **`ReleaseDetail({entry, latest, newer, older, onNewer, onOlder})`** — `twoColumnsFrom = 560`. Column(stretch, spacing 22): header Column(start, spacing 10)[Row(spacing 10)[pill, Flexible date Inter 13 secondary], semantics header `entry.name` Inter 34 w800 letterSpacing -1.19 height 1.05 text, summary Inter 13 tabular tertiary, notes]; sections as `_SectionCard`s (padding `fromLTRB(18, 18, 18, 16)`, card, radius 16, cardRing hairline, `ReleaseSectionView(gap 12)`) in one column (spacing 20) when narrower than 560 or fewer than 2, else two Expanded columns (spacing 20) split by `balancedSplit` of `_weight(section)` = (titled ? 3 : 1) + Σ(1 + text.length / 48); then when a neighbour exists a top-hairline row (padding top 18) with `_StepButton(releaseNotesNewer, newer.label, back chevron)` left, Spacer, `_StepButton(releaseNotesOlder, older.label, forward chevron)` right.
- **`balancedSplit(weights)`** — fewer than 2 -> length; picks the cut minimising `|left - right| + (left < right ? 0.001 : 0)` (first column may be longer, never shorter, on ties), at least one per column.
- **`_StepButton({label, version, forward, onTap})`** — semantics `'$label, $version'`, PressScale, height 44, padding left 16/right 10 (forward) or left 10/right 16, card fill radius 100 buttonRing hairline, Row(min, spacing 6)[chevron (back first / forward last, stroke 2 body), label Inter 13.5 w600 body, version Inter 13.5 tabular tertiary].
- **`ReleaseEmptyState({tablet})`** — disc 96 (tablet) / 88 (phone), bottom margin 20, card fill, buttonRing hairline, notes glyph size 38 / 34 secondary; semantics-header `releaseNotesEmpty` centred (Inter 22 / 20 w700, letterSpacing -0.44 / -0.3, text); 14 gap; `releaseNotesEmptyDetail` centred, max width 380 / 280, Inter 14 height 1.55 secondary.
- **`ReleaseRoundBack({onPressed})`** — `IconButton(tooltip commonBack, 44x44, background card, NoSplash, CircleBorder(buttonRing hairline), chevronLeft size 22 stroke 2 text)`.
- **`ReleaseSectionGlyph`** extension: added -> sparkle, improved -> trendUp, fixed -> wrench, other -> list.

