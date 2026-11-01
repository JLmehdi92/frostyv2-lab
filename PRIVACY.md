# ONSET privacy policy

**Effective date:** 1 November 2026

ONSET is a free, open-source (AGPL-3.0-or-later) Twitch client for Android
(package `app.onset`). It is an independent project, not affiliated with,
endorsed by, or sponsored by Twitch Interactive, Inc.

This policy describes what the ONSET app and its website do with data. It is
based on their source code, which anyone can read at
`https://github.com/JLmehdi92/onset`.

## In short

- ONSET has **no account system of its own**. It talks directly to Twitch and
  to several third-party services listed below. The app's only server is a
  small token service that gives logged-out viewers an anonymous Twitch token;
  it stores nothing about you (section 4).
- ONSET shows **no ads of its own**, and the developer **does not sell or
  rent any data**.
- Your Twitch credentials and your history stay **on your device**; none of it
  is sent anywhere except to Twitch.
- The builds published on GitHub include Google Firebase, but send **no crash
  reports, analytics, or performance data** unless you turn on **Share crash
  logs and analytics**, which is off by default (section 5).
- This policy also covers the website onsetapp.app, which measures its audience
  with Cloudflare Web Analytics (section 12).

## 1. Who is responsible

ONSET is developed by a private individual based in France, called "the
developer" in this policy
(contact: `contact@onsetapp.app`). The developer is responsible for the app,
for its token service (section 4), for the crash reports and analytics
collected through Google Firebase (section 5), and for the website (section
12). Unless you turn on **Share crash logs and analytics**, the published
builds send no crash reports, analytics, or performance data (the Firebase
libraries are still started and may contact Google's servers, but without any
of that data; see section 5). The token service sees your IP address only
briefly (section 4).

Twitch, the emote services, and the other services listed in section 4 decide
for themselves what they do with the data they receive. Their own privacy
policies apply to it.

## 2. Logging in

Logging in is optional: you can browse and watch without an account.

When you log in, ONSET opens Twitch's own login and authorization page
(id.twitch.tv) inside the app. You type your password into Twitch's page, not
into ONSET; ONSET never sees it. Twitch then gives ONSET an access token for
the permissions shown on that page (reading and sending chat, your followed
channels, blocked users, chat color, moderation actions if you are a
moderator, whispers, your emotes, and creating clips).

Because the login page signs you in to twitch.tv, it also leaves a twitch.tv
session cookie (`auth-token`) in the app's web view. On Android, ONSET reads
that cookie and keeps it as a "web token" (you can also paste or clear it in
**Settings › Video › Twitch web token (2K)**). It is sent only to Twitch, to
use features that Twitch's public API does not offer: higher-quality video
renditions, subscriber-only past broadcasts, your watch positions and
"Continue watching", followed categories, watch streaks, channel points and
predictions, and some real-time events. To keep it valid, ONSET occasionally
loads twitch.tv in a hidden web view while you are logged in.

When you are not logged in, ONSET uses an anonymous app token that Twitch
issues to the app itself; it is not linked to you. The app gets it from
ONSET's token service (section 4), so that the Twitch application secret
never has to be inside the app.

## 3. Data stored on your device

| What | Where | Details |
|---|---|---|
| Your Twitch access token, the twitch.tv web token, your Twitch user ID (the stored login), and the anonymous app token | Encrypted app storage (`flutter_secure_storage`, key kept in the Android Keystore) | Deleted when you log out, except the anonymous app token. |
| twitch.tv cookies, web cache, and site storage | The app's web view | The cookies are cleared when you log out; the web cache and site storage stay until you clear the app's data or uninstall it. |
| Your settings | App preferences | Theme, chat, video, and notification options, including the switches below. |
| Search history (up to 8 searches), recently used emotes (up to 48), and last chosen video quality | App preferences | |
| Where you stopped in past broadcasts (up to 300) and in live broadcasts (up to 300, IDs and times only) | App preferences | Stored separately for each account under its Twitch user ID, and used for "Continue watching" and resuming. Kept after you log out. |
| Notification history (Activity screen, up to 100 entries) | App preferences | Go-live notices, schedule reminders, and chat mentions, including the text of the mention. |
| Go-live notification state, schedule reminders, chat rules you accepted, and update checks | App preferences | Your Twitch user ID (for the go-live check and the chat rules you accepted), channels you muted, channels already announced, and reminder times. Kept after you log out. |
| Images (emotes, badges, avatars, thumbnails) | Cache | Removed after 30 days without use. Clear it in **Settings › Other › Clear image cache**. |
| Downloaded app updates | Cache | Deleted once that version is installed. |
| Crash reports waiting to be sent, and the random identifiers the Firebase libraries use | App storage (Firebase libraries) | Reports wait here until they are sent while **Share crash logs and analytics** is on; with the setting off, unsent reports are deleted at startup and when you turn it off (section 5). |

ONSET turns off Android backup for its data (`allowBackup="false"`, and the
data extraction rules exclude everything), so none of it is copied to a
cloud backup or to a new device.

## 4. Data sent over the network

Every connection uses HTTPS or secure WebSockets. Any service you connect to
also sees your IP address and basic technical details (such as the app's
user agent).

| Service | When | What is sent |
|---|---|---|
| **ONSET token service** (a Cloudflare Worker run by the developer, on workers.dev) | When you are not logged in and the app has no anonymous token that Twitch still accepts: at the first launch, and later when the stored token has expired or been revoked | A request with no account information. The service answers with the same shared anonymous Twitch token for every viewer. It uses your IP address only to limit how often a single address can ask (a short-lived counter); it does not log or store it, and stores nothing about you. Cloudflare, which hosts it, processes the connection under its own privacy policy. |
| **Twitch** (api.twitch.tv, id.twitch.tv, gql.twitch.tv, irc-ws.chat.twitch.tv, eventsub.wss.twitch.tv, hermes.twitch.tv, usher.ttvnw.net, static-cdn.jtvnw.net, twitch.tv, player.twitch.tv, and Twitch's video servers) | Whenever you use the app | Your access token or web token when logged in; when you open a channel's chat while logged in, a request for that chat's recent messages, sent with your twitch.tv web token; the channels, videos, categories, and searches you open; the chat messages, whispers, and moderation actions you send; follows, blocks, clips, and channel-point and prediction actions you take; when logged in, your position in past broadcasts (saved to your Twitch account). While go-live notifications are on, the app checks your followed channels about every 15 minutes in the background. When you log out, ONSET asks Twitch to revoke your access token. |
| **Amazon IVS player** (built into the app) | When a stream or video plays in the native player | The video comes from Twitch's servers. The IVS player library may also send playback quality statistics to Amazon's IVS service (player.stats.live-video.net). ONSET does not configure or receive this data. |
| **Twitch web player** (in a web view) | When you choose the web player in **Settings › Video**, or when the native player fails | Twitch's own player page runs as it would on twitch.tv, under Twitch's Privacy Notice, and may show Twitch's ads. |
| **7TV** (7tv.io, events.7tv.io, and its image servers) | When you open a channel, unless **Show 7TV emotes** is off | The channel's Twitch ID; a live connection for that channel's emote changes. |
| **BetterTTV** (api.betterttv.net, cdn.betterttv.net) | When you open a channel, unless **Show BTTV emotes** and **Show BTTV badges** are off | The channel's Twitch ID; requests for global emote and badge lists. |
| **FrankerFaceZ** (api.frankerfacez.com and its image servers) | When you open a channel, unless **Show FFZ emotes** and **Show FFZ badges** are off | The channel's Twitch ID; requests for global emote and badge lists. |
| **recent-messages.robotty.de** | Only if you turn on **Fallback chat history (third-party)** (off by default), and only when Twitch's own recent chat is unavailable, fails, or is empty (for example when you are not logged in) | The login name of the channel whose chat you open. |
| **GIPHY** (giphy.com and its subdomains) | When a chat message contains a GIF from Twitch's GIF keyboard, unless **Show GIFs in chat** is off | A request for that GIF image. Only GIPHY and Twitch image addresses are loaded. |
| **GitHub** (api.github.com, github.com, objects.githubusercontent.com, and release-assets.githubusercontent.com) | In builds that include the updater (the APKs published in the ONSET GitHub releases do; a build made without it never contacts GitHub): at launch and when the app returns to the foreground (at most every 6 hours once up to date), and when you tap **Update** or **Check for updates** | A request for the latest release of the ONSET repository; the download of the new APK when you tap Update. No account information. |
| **Google Firebase** (Crashlytics, Google Analytics for Firebase, and Performance Monitoring, run by Google) | Reports, analytics, and performance data: only while **Share crash logs and analytics** is on (off by default), both in the app and during the background go-live check; never in debug builds. The libraries may contact Google whenever the app starts, whatever the setting | Crash and error reports, the names of the app screens you open, request timings cut to the service's domain, and device and app details. No Twitch user ID, username, or channel name. See section 5. |
| **Google Play** (in-app review) | After several launches, if Google Play is installed | The app may ask Google Play to show its rating prompt, through Google Play's in-app review service. |

Twitch video and clip links you tap open inside ONSET; other web links open in
an in-app browser tab, or in your browser if **Open links in external
browser** is on. Links you share go through Android's share sheet. ONSET does
not fetch previews of other websites: chat previews are shown only for Twitch
clip and video links, from Twitch.

## 5. Crash reports and analytics (Firebase)

The builds published in the ONSET GitHub releases include Google Firebase:
Crashlytics (crash reports), Google Analytics for Firebase (usage statistics),
and Performance Monitoring (speed measurements). They collect only if you turn
on **Share crash logs and analytics**.

**Off by default.** The setting is off on a new install. You can turn it on
in the setup screens at first launch or in **Settings › Other › Privacy**,
and turn it off at any time in the same place. **Reset settings**
(**Settings › Other**) turns it off again. Debug builds never collect,
whatever the setting.

**While it is off, no crash reports, analytics, or performance data are
sent.** When the app opens, the Firebase libraries are still started and may
contact Google's servers (for example to register the installation), without
any of that data; the background go-live check does not start them at all. The
app hands no error, log line, or measurement to Crashlytics or Performance
Monitoring. All three collections are declared disabled until the app applies
your choice at startup, so Analytics records nothing either. Crashlytics
normally keeps crash reports on the device to send later. With the setting
off, the app hands it nothing, and any report Crashlytics stored on its own
(for a crash in the app's Android code, for example) is deleted unsent each
time the app starts and whenever you turn the setting off. Data sent while the
setting was on is not recalled (section 7 says how long it is kept).

**While it is on, the app sends** (and so does the background go-live check,
for its own errors)**:**

- **Crash reports (Crashlytics):** crashes and uncaught errors, and some
  unexpected errors the app recovers from (for example a server error, a chat
  or real-time connection error, or a video player failure). Each report holds
  the error's type and message, the stack trace, and a short label of where it
  happened; for a failed request, its method and the service's address cut to
  the domain (for example `https://api.twitch.tv`), never the path or the
  query. Short log lines are added on some failures (chat and login
  reconnection attempts; a Twitch directory or highlights query that stopped
  working, with its error message), and a yes/no value for whether you are
  logged in. Crashlytics adds technical details such as the device model,
  Android version, app version, orientation, free memory, and storage.
- **Analytics (Google Analytics for Firebase):** the name of each app screen
  you open. These are fixed names such as `VideoChat`, `VodScreen`,
  `Settings`, or `/search`, never the channel, video, or search behind them.
  ONSET logs no other events of its own. The Analytics library also records
  events by itself (such as first open, sessions, time spent in the app, and
  app updates) with device and app details (device model, Android version, app
  version, and language) and an approximate location (country or region) that
  Google derives from your IP address.
- **Performance (Performance Monitoring):** for each request the app makes
  through its own HTTP client, the service's domain only (no path or query),
  the method, the response code, and the duration. The Performance library
  also measures some things by itself, such as the app's startup time and
  screen rendering (slow or frozen frames). Google also receives your IP
  address, which it uses to find the country, and the Firebase installation
  ID.

**What is not included.** ONSET puts no Twitch user ID, username, or channel
name in these reports, and no tokens. Request addresses are cut to the domain.
The Firebase libraries tell installations apart with random identifiers they
generate (a Firebase installation ID and an Analytics app instance ID), which
are not linked to your Twitch account and are replaced when you clear the
app's data or reinstall it. The advertising ID is not collected: the app
removes the advertising ID permissions, turns off advertising ID collection in
Analytics and disables ad personalization signals.

**Legal basis.** Your consent (GDPR Article 6(1)(a)), given by turning the
setting on. You can withdraw it at any time by turning the setting off; this
does not affect what was collected before.

**Google as processor.** Google processes this data as the developer's
processor, under the Firebase data processing terms (Analytics data sharing
with Google is turned off in the project), and may process it outside the
European Union, including in the United States, with the safeguards those
terms provide.

## 6. Android permissions

| Permission | Why |
|---|---|
| Internet, network state | Connect to Twitch and the services above; know whether you are on mobile data (for options such as autoplay on Wi-Fi only). |
| Notifications | Go-live notices, chat mentions, schedule reminders, and the media notification. Android 13+ asks you first. |
| Foreground service (media playback) | Keep audio playing in the background. |
| Run at startup | Restore your schedule reminders after a restart. |
| Install unknown apps | Install an ONSET update you chose to download. Android asks you to allow it the first time. |

Libraries included in the app add a few more, such as vibration
(notifications), wake lock and short foreground service (background go-live
check), and Wi-Fi state (IVS player). The advertising ID and ad-services
permissions that the Firebase Analytics library would add are removed from the
app, and the advertising ID is not collected (section 5). ONSET does not
request camera, microphone, location, contacts, or storage permissions.

## 7. How long data is kept

- **On your device:** until you log out (tokens, stored login, and web
  cookies), clear the image cache, clear the app's data, or uninstall the app
  (everything else, including the Twitch user ID kept with local lists). Lists
  are capped as described in section 3.
- **Firebase** (only what was sent while **Share crash logs and analytics**
  was on): Crashlytics keeps crash data and its identifiers for 90 days.
  Performance Monitoring keeps events linked to an IP address for 30 days and
  other performance data for 60 days. Google Analytics keeps user- and
  event-level data for 2 months (the project's setting); aggregated,
  non-identifying reports are not affected by that limit. The Firebase
  installation ID is kept until the developer deletes it.
- **Twitch and other services:** according to their own policies.

## 8. Deleting your data

- **Log out** (Profile or Settings): ONSET asks Twitch to revoke your access
  token, deletes your tokens and the stored login (your Twitch user ID in the
  encrypted storage) from the device, and clears the web view's cookies. Your
  settings and local history stay on the device, and so does the Twitch user
  ID kept with those local lists (watch positions, accepted chat rules, and
  the go-live check) until you clear the app's data or uninstall it. ONSET
  does not ask Twitch to end the twitch.tv web session itself. To remove
  ONSET's access to your account, use your Twitch settings, under
  **Connections**.
- **Clear the app's data** (Android Settings › Apps › ONSET › Storage) or
  **uninstall** ONSET: everything ONSET stored on the device is deleted,
  including unsent crash reports and the Firebase identifiers.
- **Turn off** **Share crash logs and analytics** (**Settings › Other ›
  Privacy**): no more crash reports, analytics, or performance data are sent,
  and the crash reports kept on the device and not yet sent are deleted. What
  Firebase already received carries no account identifier (no Twitch user ID
  or username, only the random identifiers of section 5), so the developer may
  be unable to match an emailed deletion request to your data. You can still
  write to `contact@onsetapp.app`; in any case that data expires with the
  retention periods of section 7.
- Data held by Twitch and the other services is deleted through them.

## 9. Children

ONSET is a client for Twitch and is meant for people who are allowed to use
Twitch. Twitch's Terms of Service require users to be at least 13 years old
(or older where local law sets a higher minimum age), and users under the age
of majority may use Twitch only with a parent's or guardian's supervision and
agreement. You must meet Twitch's age requirements to use ONSET. ONSET is not
directed at children under 13.

## 10. Your rights

Under the GDPR you have the right to access, correct, and delete your personal
data, to object to or restrict its processing, and to data portability, and
you can withdraw your consent to crash reports and analytics at any time by
turning off **Share crash logs and analytics**. The developer holds no data
about you from the published builds unless you turned that setting on; that
data is linked to no account, so the developer may be unable to find yours
(sections 5 and 8). To exercise a right, or for any question, write to
`contact@onsetapp.app`. You can also lodge a complaint with the French data
protection authority, the CNIL (https://www.cnil.fr).

For data held by Twitch or the other services, contact them directly.

## 11. Third-party privacy policies

- Twitch: https://legal.twitch.com/legal/privacy-notice/
- 7TV: https://7tv.app/legal/privacy
- BetterTTV: https://betterttv.com/privacy
- FrankerFaceZ: https://www.frankerfacez.com/privacy
- recent-messages (robotty): https://recent-messages.robotty.de/ (the
  service's page describes what it stores)
- GIPHY: https://giphy.com/privacy
- Cloudflare (token service, website hosting, and Web Analytics):
  https://www.cloudflare.com/privacypolicy/
- GitHub:
  https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement
- Amazon Web Services (IVS player): https://aws.amazon.com/privacy/
- Google (Google Play, Firebase): https://policies.google.com/privacy
- Google Firebase (crash reports and analytics):
  https://firebase.google.com/support/privacy

## 12. The website

This policy also covers the website onsetapp.app, which the developer runs.

- **Hosting:** the site is hosted on Cloudflare Pages. To serve the pages and
  protect the site against abuse, Cloudflare processes technical data about
  each request, such as your IP address and your browser's user agent, under
  its own privacy policy (https://www.cloudflare.com/privacypolicy/). The site
  itself sets no cookies, but Cloudflare may set a strictly necessary security
  cookie, such as `__cf_bm` or `cf_clearance`, as part of its protection
  against bots.
- **Visit statistics:** the site uses Cloudflare Web Analytics. On each page,
  a small script from Cloudflare (static.cloudflareinsights.com) sends
  Cloudflare information about the visit, such as the page's address (without
  its query string or fragment), the address of the page you came from (if
  any), and performance measurements (load timings and Core Web Vitals, with
  the CSS selectors of the elements they concern, for example the largest
  element, and that element's image address). It also sends the transfer size
  and network protocol, an approximate figure for the page's memory use, your
  browser and operating system versions, and a random identifier for that page
  load. Cloudflare also receives your IP address with the request and derives
  your country from it. The developer sees only aggregated figures, such as
  page views, visits, top pages, referring sites, countries, browsers,
  operating systems, device types, and load times. According to Cloudflare,
  Web Analytics uses no cookies or local storage to collect these statistics,
  does not fingerprint visitors for them, and does not track visitors across
  the sites that use Cloudflare. Also according to Cloudflare, the detailed
  data is kept for 7 days, after which only a sample of about 10% is kept; the
  developer can view the figures for the past six months.
- **Language choice:** when you pick English or French in the language switch,
  the site stores that choice in your browser's local storage, under the key
  `onset.lang`. It only decides which version of the home page opens next
  time, and it never leaves your browser. When you open the English home page
  without having chosen English, the site redirects you to the French home
  page if you chose French, or if your browser's preferred language is French
  and you did not arrive from another page of the site.
- **Legal basis:** the developer's legitimate interest in serving and
  protecting the site and in measuring its audience with aggregated statistics
  (GDPR Article 6(1)(f)). We consider that this audience measurement falls
  within the consent exemption that the CNIL, the French data protection
  authority, allows for audience measurement tools: it sets no cookies, it
  only produces aggregated statistics, and, according to Cloudflare, it does
  not track visitors across sites. You can object at any time (section 10);
  most content blockers already block the statistics script. Cloudflare
  processes this data on the developer's behalf (for data it uses to protect
  its own network, it acts as a controller, under its own privacy policy) and
  may process it outside the European Union, including in the United States;
  according to Cloudflare, these transfers rely on the EU-U.S. Data Privacy
  Framework or, failing that, on standard contractual clauses.
- **Nothing else:** the site shows no ads and uses no other third-party
  service. The download link, the GitHub link, and the iPhone waitlist link
  all lead to GitHub, where GitHub's own privacy statement applies.

## 13. Changes

If ONSET starts handling data differently, this policy will be updated and its
effective date changed. The history of this policy is public in the ONSET
GitHub repository.

- 31 October 2026: the published builds include Firebase crash reports and
  analytics, off unless you turn them on. Installs that ran an older build,
  where the setting was on by default, had it turned off by this update:
  turn it on again if you want to share crash logs and analytics.
- 31 October 2026: wording clarified; no change to how data is handled.
- 1 November 2026: a section about the website was added.

## 14. Contact

`contact@onsetapp.app`
