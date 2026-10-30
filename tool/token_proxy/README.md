# ONSET token proxy

A tiny Cloudflare Worker that keeps every **Twitch client secret** out of the
ONSET app.

ONSET needs a Twitch "app access token" so that people who are **not logged
in** still get Twitch emotes and badges in chat, the Browse and Search tabs,
categories, and channel info in the players. Getting that token needs a
Twitch client secret, and anything inside an APK can be read back out of it.
So the token now comes from this Worker, which runs in your Cloudflare
account; the app only knows the Worker's address.

The token is minted for a **second Twitch application**, "ONSET public", that
nobody ever logs in to. That matters: an app token of the application people
log in with could be used to subscribe to their private events (for example
their whispers). A token of an application nobody has authorized reaches
nobody's private data.

- `GET /app-token` returns
  `{ "access_token": "...", "expires_in": 4300000, "client_id": "..." }`.
- Every other address returns 404, every other method 405.
- Everyone gets the same token. It is handed out while it has at least
  **7 days** left (Twitch's last about 58 days), so Twitch is asked for a new
  one only every seven weeks or so.
- Every 10 minutes at most, the Worker asks Twitch whether the token still
  works. Anyone can revoke a token they have, so if it was revoked the Worker
  throws it away and mints another, **at most once a minute** for the whole
  world (a revoke cannot make it hammer Twitch).
- The secret is only ever sent to Twitch. It is never shown, returned or
  logged.

Logged-in users never use this Worker: they have their own token, from the
login application ("ONSET"), exactly as before.

## The plan, in short

ONSET gets its **own Twitch account**, used only for development, with two
applications:

| Application | Used for | Client secret |
|---|---|---|
| **ONSET** | logging in to ONSET. Its Client ID goes into the app (GitHub secret `CLIENT_ID`) | **none, ever**: logging in does not need one |
| **ONSET public** | the logged-out token, minted by this Worker | in the Worker only |

The old login application, on your personal Twitch account, is then
**deleted**. Its secret leaked inside old APKs; deleting the application
kills that secret, every token made with it, and every EventSub subscription
anyone created with it.

**The one rule for secrets:** the only place a client secret is ever pasted
is Cloudflare's secret fields (step 4). Never put one in GitHub, in the app,
in a file, a website, a chat or a message, and never send one to anyone,
including someone helping you: nobody else needs it. (The optional cleanup
script at the end is the single exception: it runs on your own computer.)

## What you need

- About 30 minutes. No command line, nothing to install.
- An e-mail address for the new Twitch account, and a phone with an
  authenticator app (or a phone number) for its two-factor authentication.
- A free Cloudflare account.

Cloudflare and Twitch rename buttons from time to time: if a name below is
slightly different on your screen, pick the closest one.

## Step 1. Create the ONSET Twitch account and turn on 2FA

1. Log out of Twitch (or use a private browser window) and sign up at
   <https://www.twitch.tv/signup> with a new account, used only for ONSET.
2. Turn on two-factor authentication: profile picture → **Settings** →
   **Security and Privacy** → **Two-Factor Authentication** → follow the
   steps. (Twitch requires it before an account can register applications.)

## Step 2. Register the two applications

Logged in as the ONSET account, open <https://dev.twitch.tv/console/apps>.

**ONSET** (logging in):

1. **Register Your Application**. **Name:** `ONSET` (or another name Twitch
   accepts).
2. **OAuth Redirect URLs:** `https://twitch.tv/login`, exactly (ONSET's login
   comes back to that address).
3. **Category:** Application Integration (or anything close).
   **Client Type:** Confidential. Create it.
4. **Manage** → copy its **Client ID** (for step 7). Do **not** click
   **New Secret**: this application never needs one.

**ONSET public** (the logged-out token):

1. **Register Your Application** again. **Name:** `ONSET public`.
2. **OAuth Redirect URLs:** `http://localhost`. Nobody ever logs in through
   it; Twitch just requires one.
3. **Category:** Application Integration. **Client Type:** Confidential.
   Create it.
4. **Manage** → copy its **Client ID**, then click **New Secret** and copy the
   **Client Secret**. Keep both open for step 4, and nowhere else.

## Step 3. Create the Worker and its storage

1. Sign up or log in at <https://dash.cloudflare.com>.
2. In the left menu, open **Compute (Workers)** → **Workers & Pages** →
   **Create application**.
3. Choose **Start with Hello World!** (a template). If you are asked to connect
   GitHub or GitLab, go back and pick the Hello World template instead: this
   guide does not need Git.
4. Name it `onset-token` and click **Deploy**. Cloudflare shows the Worker's
   address, something like `https://onset-token.your-name.workers.dev`.
   Write it down.
5. On the Worker's page, click **Edit code**. In the editor, select everything
   in the file on the left (`worker.js`) and delete it.
6. Open [`worker.js`](worker.js) from this folder (on GitHub: open the file,
   then click **Raw**), copy all of it, paste it into the editor, and click
   **Deploy** (top right).
7. Storage (**required**: without it the Worker answers
   `{"error":"unavailable"}` to everything, because a revoked token could not
   be noticed everywhere and each of Cloudflare's machines would mint its
   own). In the left menu, open **Storage & Databases** → **Workers KV** →
   **Create** (or **Create namespace**), name it `onset-token-cache`, create
   it.
8. Back on the Worker → **Settings** → **Bindings** → **Add** →
   **KV namespace**. **Variable name:** `TOKEN_CACHE` (exactly).
   **KV namespace:** `onset-token-cache`. Save / **Deploy**.

## Step 4. Add the Worker's two secrets ("ONSET public")

1. On the Worker's page, open **Settings** → **Variables and Secrets** → **Add**.
2. **Type:** Secret. **Variable name:** `TWITCH_CLIENT_ID`. **Value:** the
   Client ID of **ONSET public** (step 2). Save.
3. **Add** again. **Type:** Secret. **Variable name:** `TWITCH_CLIENT_SECRET`.
   **Value:** the Client Secret of **ONSET public**. Save.
4. Click **Deploy** if Cloudflare asks for it.

The names must be exactly `TWITCH_CLIENT_ID` and `TWITCH_CLIENT_SECRET`, in
capitals. Choose **Secret**, not **Text**: a secret can never be read back,
even by you. You can now close the Twitch page that shows it.

## Step 5. Check it works

Open `https://onset-token.your-name.workers.dev/app-token` (your address from
step 3, followed by `/app-token`) in a browser. You should see:

```json
{"access_token":"abc123...","expires_in":4300000,"client_id":"..."}
```

The `client_id` must be the one of **ONSET public**, not of ONSET. If you see
`{"error":"unavailable"}` instead, see **Troubleshooting** below. Opening the
address **without** `/app-token` shows `{"error":"not_found"}`: that is
normal.

## Step 6. Give the Worker's address to the build

1. On GitHub, open the ONSET repository → **Settings** → **Secrets and
   variables** → **Actions** → the **Variables** tab (not Secrets) →
   **New repository variable**.
2. **Name:** `TOKEN_PROXY_URL`. **Value:** the Worker's address **without**
   `/app-token`, for example `https://onset-token.your-name.workers.dev`.
   It must start with `https://`, and contain nothing but the address (no
   `?`, `#`, spaces or `user:password@`): the build refuses anything else,
   as the app would.

It is a variable rather than a secret because the address is inside every APK
anyway. The build stops with a clear error if it is missing.

For a build on your own computer, put the same address in `.env`
(`TOKEN_PROXY_URL=https://...`) or pass
`--dart-define=TOKEN_PROXY_URL=https://...`.

## Step 7. Give the build the new ONSET Client ID

Same page, the **Secrets** tab → `CLIENT_ID` → edit (pencil) → paste the
Client ID of **ONSET** (step 2, not ONSET public) → **Update secret**. A
client ID is not secret, but this one stays a repository secret as before.

## Step 8. Build and install

**Actions** → **ONSET update** → **Run workflow** on `main`, then install the
update when the app offers it (or by hand from the release page).

## Step 9. Log in again, once

The login application changed, so Twitch refuses logins made with the old
one once it is deleted (step 11); until then they keep working but the app
shows "This token was created for another app". Every user logs in again
once: **Settings** → log out if needed → **Connect with Twitch**. A user who
has not done it by step 11 is logged out cleanly at their next launch after
it, and sees "Your Twitch session has ended. Log in again from Settings."

## Step 10. Test logged out

Log out (or use a device that never logged in). Open **Browse**, a category,
**Search**, then a channel's chat: Twitch emotes and badges must show, and no
"Session expired" pop-up may appear. If nothing shows, open the
`/app-token` address of step 5 to see whether the Worker answers.

## Step 11. Delete the old login application

Log in to Twitch with your **personal** account (the one that held the old
application), open <https://dev.twitch.tv/console/apps>, then the old ONSET
application → **Manage** → **Delete** (at the bottom), and confirm.

This is the step that closes the old leak: old APKs (releases, artifacts,
phones where the app is installed) still contain the old secret, and they
cannot be recalled. Deleting the application makes that secret, its tokens
and its EventSub subscriptions worthless.

## Step 12. Delete the old GitHub secret

GitHub → the repository → **Settings** → **Secrets and variables** →
**Actions** → `SECRET` → **Remove**. The build no longer reads it.

## Changing the "ONSET public" secret later

Twitch console (ONSET account) → **ONSET public** → **Manage** →
**New Secret**, then Cloudflare → the Worker → **Settings** → **Variables and
Secrets** → edit `TWITCH_CLIENT_SECRET` → paste the new one → Deploy. Nothing
to rebuild: the app never has the secret. The Worker notices the secret
changed and mints a new token with it instead of serving the cached one; an
app whose stored token Twitch no longer accepts gets the new one on its next
launch, or within a minute of its next refused request.

## Optional: cleaning up a login application you keep

Not needed with the plan above: deleting the old application (step 11)
removes its EventSub subscriptions. This is only for someone who keeps a
login application whose secret leaked.

While a login application's secret is out, anyone who has it can mint tokens
of that application and create EventSub **webhook subscriptions** or
**conduits** for the people who logged in with it, for example to receive
their whispers. Replacing the secret stops new ones; it does not delete those
that exist. ONSET itself only uses another kind (websocket), so any webhook
subscription or conduit of the login application was made by someone else.

`eventsub-cleanup.js` lists them and, if you type `DELETE`, deletes them.
Run it on your own computer, after replacing that application's secret:

1. Install Node.js (the "LTS" version) from <https://nodejs.org> if you do not
   have it.
2. Open a terminal (on Windows: **PowerShell**) in this folder,
   `tool/token_proxy`, and run `node eventsub-cleanup.js`.
3. It asks for that login application's Client ID, then its **new** Client
   Secret. The secret is not shown as you type. This terminal, on your own
   computer, is the only other place that secret may be typed.
4. It prints what it found. Type `DELETE` to delete it all, or anything else
   to stop.

The secret goes only to Twitch (`id.twitch.tv`), to get a temporary token that
the script revokes before it ends. Nothing is saved or sent anywhere else.

## Limits, honestly

- **The address is public**, and so is the token. Anyone who unpacks the APK
  can call the Worker and use the token. With "ONSET public", that token can
  read public Twitch data and nothing of any ONSET user. What someone could
  still do with it:
  - **Revoke it.** The Worker notices within 10 minutes and mints another, at
    most once a minute; an attacker revoking every new token would leave
    logged-out viewers without Twitch emotes, badges and browsing while they
    keep at it. Logged-in users are not affected.
  - **Use up its Twitch rate limit**, which every logged-out ONSET app shares.
  - **Get "ONSET public" suspended by Twitch** through abuse. Only logged-out
    viewing would suffer; the login application, "ONSET", is a different
    one.
- **Rate limiting.** The Worker lets each IP address (each `/64` for IPv6,
  which is what one home or phone usually has) ask 10 times a minute; more
  gets `429`. Set up from the dashboard, this count is kept separately by each
  running copy of the Worker, so it is **best effort**: it slows down one
  noisy client, it does not stop a determined one. Cloudflare's own rate
  limiter (enabled through `wrangler.toml`) is stronger, but it can only be
  added with Wrangler, not from the dashboard, and is itself approximate.
  A normal app asks on its first launch and then rarely (when its token
  expires or is refused), so legitimate use never comes near the limit.
- **Daily quota.** The free plan allows 100,000 Worker requests a day, and a
  request answered `429` **still counts**. Someone hammering the address
  could use the day's quota up; Cloudflare then answers with error 1027 until
  midnight UTC. ONSET keeps working; only logged-out viewers who need a new
  token that day go without Twitch emotes, badges and browsing. **Stay on the
  free plan**: it is a hard cap, so abuse can never cost you money. If you
  ever move to a paid plan, set a billing alert in Cloudflare first.
  Optional upgrade: with your own domain on Cloudflare, a **WAF rate limiting
  rule** on the Worker's route blocks floods before they reach the Worker and
  before they count as requests.
- **KV writes.** The free plan allows 1,000 KV writes a day. The Worker
  writes about once every 10 minutes at most (each check of the token), plus
  one per mint: well under it.
- **If the Worker is down**, the app still starts, logging in still works, and
  logged-out features that need the token fail quietly (no login pop-ups).
  The app asks again at most once a minute, when a request is refused.

## Troubleshooting

`{"error":"unavailable"}` means the Worker has no token to give. Open the
Worker → **Logs** (enable them if asked) and reload `/app-token`:

- `the TOKEN_CACHE KV binding is missing`: step 3, points 7 and 8.
- `TWITCH_CLIENT_ID or TWITCH_CLIENT_SECRET is not set`: step 4, check the
  names (capitals, underscores).
- `Twitch answered 400` or `403`: the Client ID or Secret is wrong, or the
  secret was replaced in the Twitch console and not here.
- `Twitch could not be reached`: Twitch had a hiccup; try again later.
- `the cached token was refused by Twitch, minting another`: someone revoked
  the token, or it expired; the Worker is already replacing it. If a new one
  was minted less than a minute ago, wait a minute.

The logs never contain the secret.

## For developers

- `worker.js` is the whole Worker: one file, no dependencies, so it can be
  pasted into the dashboard.
- `eventsub-cleanup.js` is the owner's cleanup script (above); it exports
  `cleanup()` for its tests.
- Tests: `node --test` in this folder (Node 18 or newer, nothing to install).
  Twitch is a mocked `fetch`; KV and the rate limiter are in-memory fakes.
- Caching uses KV plus a copy in memory, not the Cache API: the Cache API does
  nothing on `*.workers.dev` addresses (it only works on custom domains), and
  this Worker is meant to run on one. KV is eventually consistent (changes
  can take up to a minute to reach every location), so "once a minute" and
  "every 10 minutes" are approximate across locations.
- `wrangler.toml` is only for a Wrangler or Git-integration deploy. It holds no
  secrets. A Wrangler deploy replaces dashboard bindings with the file's, so
  fill in the KV id there first.
