# ONSET Privacy Policy

**Effective date:** 30 October 2026

ONSET is a free, open-source (AGPL-3.0-or-later) Twitch client for Android
(package `app.onset`). It is an independent project, not affiliated with,
endorsed by or sponsored by Twitch Interactive, Inc.

This policy describes what the ONSET app does with data. It is based on the
app's source code, which anyone can read at
`https://github.com/JLmehdi92/onset`.

## In short

- ONSET has **no account system of its own**. It talks directly to Twitch and
  to a few third-party services listed below. Its only server is a small token
  service that gives logged-out viewers an anonymous Twitch token; it stores
  nothing about you (section 4).
- ONSET shows **no ads of its own**, and the developer **does not sell or
  rent any data**.
- Your Twitch credentials and your history stay **on your device** and go
  only to Twitch.
- The builds published on GitHub send **no crash reports, analytics or
  performance data** (section 5).

## 1. Who is responsible

The app is developed by a private individual based in France, who is
responsible for the app and for its token service (section 4): Mehdi SEDDIKI,
contact: `onsetapp.contact@gmail.com`. The published builds send the developer
no personal data; the token service only sees your IP address for a moment
(sections 4 and 5).

Twitch, the emote services and the other services listed in section 4 decide
for themselves what they do with the data they receive. Their own privacy
policies apply to it.

## 2. Logging in

Logging in is optional: you can browse and watch without an account.

When you log in, ONSET opens Twitch's own login and authorization page
(id.twitch.tv) inside the app. You type your password into Twitch's page, not
into ONSET; ONSET never sees it. Twitch then gives ONSET an access token for
the permissions shown on that page (read and send chat, followed channels,
blocked users, chat colour, moderation actions if you are a moderator,
whispers, your emotes, creating clips).

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
| Your Twitch access token, the twitch.tv web token, your Twitch user ID, the anonymous app token | Encrypted app storage (`flutter_secure_storage`, key kept in the Android Keystore) | Deleted when you log out, except the anonymous app token. |
| twitch.tv cookies and web cache | The app's web view | Cleared when you log out. |
| Your settings | App preferences | Theme, chat, video and notification options, including the switches below. |
| Search history (up to 8 searches), recently used emotes (up to 48), last chosen video quality | App preferences | |
| Where you stopped in past broadcasts (up to 300) and in live broadcasts (up to 300, IDs and times only) | App preferences | Kept apart for each account, used for "Continue watching" and resuming. |
| Notification history (Activity screen, up to 100 entries) | App preferences | Go-live notices, schedule reminders, and chat mentions, including the text of the mention. |
| Go-live notification state, schedule reminders, chat rules you accepted, update checks | App preferences | Your Twitch user ID, channels you muted, channels already announced, reminder times. |
| Images (emotes, badges, avatars, thumbnails) | Cache | Removed after 30 days without use. Clear it in **Settings › Other › Clear image cache**. |
| Downloaded app updates | Cache | Deleted once that version is installed. |

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
| **Twitch** (api.twitch.tv, id.twitch.tv, gql.twitch.tv, irc-ws.chat.twitch.tv, eventsub.wss.twitch.tv, hermes.twitch.tv, usher.ttvnw.net, static-cdn.jtvnw.net, twitch.tv, player.twitch.tv and Twitch's video servers) | Whenever you use the app | Your access token or web token when logged in; when you open a channel's chat while logged in (with a twitch.tv web token), a request for that chat's recent messages, sent with your web token, as the official Twitch app does; the channels, videos, categories and searches you open; the chat messages, whispers and moderation actions you send; follows, blocks, clips, channel-point and prediction actions you take; when logged in, your position in past broadcasts (saved to your Twitch account). While go-live notifications are on, the app checks your followed channels about every 15 minutes in the background. When you log out, ONSET asks Twitch to revoke your access token. |
| **Amazon IVS player** (built into the app) | When a stream or video plays in the native player | The video comes from Twitch's servers. The IVS player library may also send playback quality statistics to Amazon's IVS service (player.stats.live-video.net). ONSET does not configure or receive this data. |
| **Twitch web player** (in a web view) | When you choose the web player in **Settings › Video**, or when the native player fails | Twitch's own player page runs as it would on twitch.tv, under Twitch's privacy notice, and may show Twitch's ads. |
| **7TV** (7tv.io, events.7tv.io and its image servers) | When you open a channel, unless **Show 7TV emotes** is off | The channel's Twitch ID; a live connection for that channel's emote changes. |
| **BetterTTV** (api.betterttv.net, cdn.betterttv.net) | When you open a channel, unless **Show BTTV emotes** and **Show BTTV badges** are off | The channel's Twitch ID; requests for global emote and badge lists. |
| **FrankerFaceZ** (api.frankerfacez.com and its image servers) | When you open a channel, unless **Show FFZ emotes** and **Show FFZ badges** are off | The channel's Twitch ID; requests for global emote and badge lists. |
| **recent-messages.robotty.de** | Only if you turn on **Fallback chat history (third-party)** (off by default), and only when Twitch's own recent chat is unavailable, fails or is empty (for example when you are not logged in) | The login name of the channel whose chat you open. |
| **GIPHY** (giphy.com and its subdomains) | When a chat message contains a GIF from Twitch's GIF keyboard, unless **Show GIFs in Chat** is off | A request for that GIF image. Only GIPHY and Twitch image addresses are loaded. |
| **GitHub** (api.github.com, github.com, objects.githubusercontent.com, release-assets.githubusercontent.com) | In builds that include the updater (the APKs published in this repository's releases do; a build made without it never contacts GitHub): at launch and when the app returns to the foreground (at most every 6 hours once up to date), and when you tap **Update** or **Check for updates** | A request for the latest release of the ONSET repository; the download of the new APK when you tap Update. No account information. |
| **Google Play** (in-app review) | After several launches, if Google Play is installed | The app may ask Google Play to show its rating prompt, through Google Play's in-app review service. |

Links you tap in chat or in the app open in your browser or in the app; links
you share go through Android's share sheet. ONSET does not fetch previews of
other websites: chat previews are shown only for Twitch clip and video links,
from Twitch.

## 5. Crash reports and analytics (Firebase)

The builds published in this repository's releases include no Firebase
configuration: they send no crash reports, analytics or performance data to
anyone, and the **Share crash logs and analytics** setting has no effect in
them. If that ever changes, this policy will be updated first.

As the code is public: it contains the Google Firebase Crashlytics, Analytics
and Performance Monitoring libraries, which only start in a build made with a
Firebase configuration.

## 6. Android permissions

| Permission | Why |
|---|---|
| Internet, network state | Connect to Twitch and the services above; know whether you are on mobile data (for options such as autoplay on Wi-Fi only). |
| Notifications | Go-live notices, chat mentions, schedule reminders, the media notification. Android 13+ asks you first. |
| Foreground service (media playback) | Keep audio playing in the background. |
| Run at startup | Restore your schedule reminders after a restart. |
| Install unknown apps | Install an ONSET update you chose to download. Android asks you to allow it the first time. |

Libraries included in the app add a few more, such as vibration
(notifications), wake lock and short foreground service (background go-live
check), and Wi-Fi state (IVS player). The advertising ID and ad-services
permissions that the Firebase Analytics library would add are removed from
the app. ONSET does not request camera, microphone, location, contacts or
storage permissions.

## 7. How long data is kept

- **On your device:** until you log out (credentials and web session), clear
  the image cache, clear the app's data, or uninstall the app. Lists are capped
  as described in section 3.
- **Twitch and other services:** according to their own policies.

## 8. Deleting your data

- **Log out** (Profile or Settings): ONSET asks Twitch to revoke your access
  token, deletes your tokens and Twitch user ID from the device, and clears the
  web view's cookies. Your settings and local history stay on the device.
  ONSET does not ask Twitch to end the twitch.tv web session itself; you can
  also remove ONSET's access in your Twitch settings, under **Connections**.
- **Clear the app's data** (Android Settings › Apps › ONSET › Storage) or
  **uninstall** ONSET: everything ONSET stored on the device is deleted.
- Data held by Twitch and the other services is deleted through them.

## 9. Children

ONSET is a client for Twitch and is meant for people who may use Twitch.
Twitch's Terms of Service require users to be at least 13 years old (or older
where local law sets a higher minimum age), and users under the age of
majority may use Twitch only with a parent or guardian's supervision and
agreement. You must meet Twitch's age requirements to use ONSET. ONSET is not
directed at children under 13.

## 10. Your rights

Under the GDPR you have the right to access, correct and delete your personal
data, to object to or restrict its processing, and to data portability. The
developer holds no data about you from the published builds (sections 4 and
5). To exercise a right, or for any question, write to
`onsetapp.contact@gmail.com`. You can also lodge a complaint with the French
data protection authority, the CNIL (https://www.cnil.fr).

For data held by Twitch or the other services, contact them directly.

## 11. Third-party privacy policies

- Twitch: https://legal.twitch.com/legal/privacy-notice/
- 7TV: https://7tv.app/legal/privacy
- BetterTTV: https://betterttv.com/privacy
- FrankerFaceZ: https://www.frankerfacez.com/privacy
- recent-messages (robotty): https://recent-messages.robotty.de/ (the service's page describes what it stores)
- GIPHY: https://giphy.com/privacy
- Cloudflare (token service): https://www.cloudflare.com/privacypolicy/
- GitHub: https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement
- Amazon Web Services (IVS player): https://aws.amazon.com/privacy/
- Google (Google Play): https://policies.google.com/privacy

## 12. Changes

If ONSET starts handling data differently, this policy will be updated and its
effective date changed. The history of this file is public in the repository.

## 13. Contact

`onsetapp.contact@gmail.com`
