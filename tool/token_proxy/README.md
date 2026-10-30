# ONSET token proxy

A tiny Cloudflare Worker that keeps ONSET's **Twitch client secret** out of the
app.

ONSET needs a Twitch "app access token" so that people who are **not logged
in** still get Twitch emotes and badges in chat, the Browse and Search tabs,
categories, and channel info in the players. Getting that token needs the
Twitch client secret. Anything inside an APK can be read back out of it, so the
secret now lives here, in your Cloudflare account, and the app only knows this
Worker's address.

- `GET /app-token` returns `{ "access_token": "...", "expires_in": 5011271 }`.
- Every other address returns 404, every other method 405.
- The token is the same for everyone and is kept until about 10 minutes before
  it expires (roughly two months), so Twitch is asked very rarely.
- The secret is only ever sent to Twitch. It is never shown, returned or
  logged.

Logged-in users never use this Worker: they have their own token.

## What you need

- A free Cloudflare account.
- Your Twitch application's **Client ID** and **Client Secret**, from
  <https://dev.twitch.tv/console/apps> → your application → **Manage**.
- About 15 minutes. No command line, nothing to install.

Cloudflare renames buttons from time to time: if a name below is slightly
different on your screen, pick the closest one.

## Step 1. Create the Worker

1. Sign up or log in at <https://dash.cloudflare.com>.
2. In the left menu, open **Compute (Workers)** → **Workers & Pages**.
3. Click **Create application**.
4. Choose **Start with Hello World!** (a template). If you are asked to connect
   GitHub or GitLab, go back and pick the Hello World template instead: this
   guide does not need Git.
5. Name it `onset-token` and click **Deploy**.
6. Cloudflare shows the Worker's address, something like
   `https://onset-token.your-name.workers.dev`. Write it down.

## Step 2. Put ONSET's code in it

1. On the Worker's page, click **Edit code**.
2. In the editor, select everything in the file on the left (`worker.js`) and
   delete it.
3. Open [`worker.js`](worker.js) from this folder (on GitHub: open the file,
   then click **Raw**), copy all of it, and paste it into the editor.
4. Click **Deploy** (top right), then go back to the Worker's page.

## Step 3. Add the two secrets

1. On the Worker's page, open **Settings** → **Variables and Secrets** → **Add**.
2. **Type:** Secret. **Variable name:** `TWITCH_CLIENT_ID`. **Value:** your
   Twitch Client ID. Save.
3. **Add** again. **Type:** Secret. **Variable name:** `TWITCH_CLIENT_SECRET`.
   **Value:** your Twitch Client Secret. Save.
4. Click **Deploy** if Cloudflare asks for it.

The names must be exactly `TWITCH_CLIENT_ID` and `TWITCH_CLIENT_SECRET`, in
capitals. Choose **Secret**, not **Text**: a secret can never be read back,
even by you.

## Step 4 (recommended). Share one token across Cloudflare

Without this step the Worker still works, but each of Cloudflare's machines
asks Twitch for its own token. With it, they all share one.

1. In the left menu, open **Storage & Databases** → **Workers KV** →
   **Create** (or **Create namespace**). Name it `onset-token-cache` and
   create it.
2. Go back to the Worker → **Settings** → **Bindings** → **Add** →
   **KV namespace**.
3. **Variable name:** `TOKEN_CACHE`. **KV namespace:** `onset-token-cache`.
   Save / **Deploy**.

## Step 5. Check it works

Open `https://onset-token.your-name.workers.dev/app-token` (your address from
step 1, followed by `/app-token`) in a browser. You should see:

```json
{"access_token":"abc123...","expires_in":5011271}
```

That token is not a secret: it only reads public Twitch data, and it is what
every logged-out ONSET app receives anyway.

If you see `{"error":"unavailable"}` instead, see **Troubleshooting** below.
Opening the address **without** `/app-token` shows `{"error":"not_found"}`:
that is normal.

## Step 6. Give the address to the build

1. On GitHub, open the ONSET repository → **Settings** → **Secrets and
   variables** → **Actions** → the **Variables** tab (not Secrets) →
   **New repository variable**.
2. **Name:** `TOKEN_PROXY_URL`. **Value:** the Worker's address **without**
   `/app-token`, for example `https://onset-token.your-name.workers.dev`.
   It must start with `https://`.

It is a variable rather than a secret because the address is inside every APK
anyway. The build stops with a clear error if it is missing.

For a build on your own computer, put the same address in `.env`
(`TOKEN_PROXY_URL=https://...`) or pass
`--dart-define=TOKEN_PROXY_URL=https://...`.

The rest (testing logged out on the phone, then replacing the Twitch secret)
is in `docs/MISES_A_JOUR.md`.

## Changing the Twitch secret later

Twitch console → your application → **New Secret**, then Cloudflare → the
Worker → **Settings** → **Variables and Secrets** → edit
`TWITCH_CLIENT_SECRET` → paste the new one → Deploy. Nothing to rebuild: the
app never had the secret. The Worker notices the secret changed and fetches a
new token with it instead of serving the cached one; an app whose stored token
Twitch no longer accepts asks the Worker for a new one at its next launch.

## Limits, honestly

- **The address is public.** Anyone who unpacks the APK can call it and get an
  app token. That token can only read public Twitch data, the same token every
  logged-out ONSET app gets. The secret itself stays here.
- **Rate limiting.** The Worker lets each IP address ask 10 times a minute;
  more gets `429`. Set up from the dashboard, this count is kept separately by
  each running copy of the Worker, so it is **best effort**: it slows down one
  noisy client, it does not stop a determined one. Cloudflare's own rate
  limiter (enabled through `wrangler.toml`) is stronger, but it can only be
  added with Wrangler, not from the dashboard, and is itself approximate.
  A normal app asks once on its first launch and then about every two months,
  so legitimate use never comes near the limit.
- **Free plan quota.** Cloudflare's free plan allows 100,000 Worker requests
  a day (it then answers with error 1027 until midnight UTC). Someone hammering
  the address could use that up. ONSET would then keep working; only
  logged-out viewers who need a new token that day would go without Twitch
  emotes, badges and browsing until the quota resets. Logged-in users are not
  affected.
- **If the Worker is down**, the app still starts, logging in still works, and
  logged-out features that need the token fail quietly (no login pop-ups). The
  app asks again at most once a minute.

## Troubleshooting

`{"error":"unavailable"}` means Twitch did not give a token. Open the Worker
→ **Logs** (enable them if asked) and reload `/app-token`:

- `TWITCH_CLIENT_ID or TWITCH_CLIENT_SECRET is not set`: step 3, check the
  names (capitals, underscores).
- `Twitch answered 400` or `403`: the Client ID or Secret is wrong, or the
  secret was replaced in the Twitch console and not here.
- `Twitch could not be reached`: Twitch had a hiccup; try again later.

The logs never contain the secret.

## For developers

- `worker.js` is the whole Worker: one file, no dependencies, so it can be
  pasted into the dashboard.
- Tests: `node --test` in this folder (Node 18 or newer, nothing to install).
  Twitch is a mocked `fetch`; KV and the rate limiter are in-memory fakes.
- Caching uses KV plus a copy in memory, not the Cache API: the Cache API does
  nothing on `*.workers.dev` addresses (it only works on custom domains), and
  this Worker is meant to run on one.
- `wrangler.toml` is only for a Wrangler or Git-integration deploy. It holds no
  secrets. A Wrangler deploy replaces dashboard bindings with the file's, so
  fill in the KV id there first if you use KV.
