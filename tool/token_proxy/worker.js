// ONSET token proxy: a Cloudflare Worker that hands logged-out ONSET apps a
// Twitch app access token, so the Twitch client secret never ships in an APK.
//
// GET /app-token -> 200 { "access_token": "...", "expires_in": N }
// Anything else  -> 404 (other paths) or 405 (other methods on /app-token).
//
// Settings (Cloudflare dashboard -> the Worker -> Settings):
//   TWITCH_CLIENT_ID      secret   the Twitch application's client id
//   TWITCH_CLIENT_SECRET  secret   the Twitch application's client secret
//   TOKEN_CACHE           optional KV namespace binding, shares one token
//                         between all of Cloudflare's machines
//   RATE_LIMITER          optional rate limiting binding (wrangler.toml);
//                         without it a best-effort counter per isolate is used
//
// The secret is only ever sent to id.twitch.tv. It is never returned, never
// logged, and never part of an error.
//
// Kept to one file with no imports, so it can be pasted into the dashboard.

const TWITCH_TOKEN_URL = 'https://id.twitch.tv/oauth2/token';

// A token is handed out until this long before Twitch expires it, then a new
// one is asked for: every app gets one that lasts at least this long.
const REFRESH_MARGIN_MS = 10 * 60 * 1000;

// Twitch's answer gets this long, after which the proxy gives up (502).
const TWITCH_TIMEOUT_MS = 5000;

const KV_KEY = 'twitch_app_token';

// KV refuses expirations closer than 60 s.
const KV_MIN_TTL_S = 60;

// Best-effort fallback limit (when there is no RATE_LIMITER binding): this
// many requests per IP per window, counted in this isolate only.
const FALLBACK_LIMIT = 10;
const FALLBACK_WINDOW_MS = 60 * 1000;
const FALLBACK_MAX_IPS = 10000;

// What Twitch's app tokens look like: nothing else is passed on.
const TOKEN_PATTERN = /^[A-Za-z0-9]{16,128}$/;

// This isolate's copy of the token: { token, expiresAt, key }, expiresAt in
// ms since epoch, key the credentials' fingerprint (see credentialsKey).
let memoryToken = null;

// Fallback rate limit counters: ip -> { count, windowStart }.
const fallbackCounters = new Map();

const JSON_HEADERS = {
  'Content-Type': 'application/json; charset=utf-8',
  // The token is a credential: no browser, proxy or CDN keeps a copy.
  'Cache-Control': 'no-store',
  'X-Content-Type-Options': 'nosniff',
};

function json(status, body, extraHeaders = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...JSON_HEADERS, ...extraHeaders },
  });
}

const unavailable = () => json(502, { error: 'unavailable' });

// A short fingerprint of the Twitch credentials (not reversible). A cached
// token made with other credentials is not used: after the secret is
// replaced, the KV copy would otherwise be served for up to two months.
async function credentialsKey(env) {
  const data = new TextEncoder().encode(
    `${env.TWITCH_CLIENT_ID || ''}\n${env.TWITCH_CLIENT_SECRET || ''}`,
  );
  const digest = new Uint8Array(await crypto.subtle.digest('SHA-256', data));
  return [...digest.slice(0, 8)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

function usable(entry, now, key) {
  return (
    entry !== null &&
    typeof entry === 'object' &&
    entry.key === key &&
    typeof entry.token === 'string' &&
    TOKEN_PATTERN.test(entry.token) &&
    typeof entry.expiresAt === 'number' &&
    entry.expiresAt - REFRESH_MARGIN_MS > now
  );
}

async function allowed(request, env, now) {
  const ip = request.headers.get('CF-Connecting-IP') || 'unknown';

  if (env.RATE_LIMITER && typeof env.RATE_LIMITER.limit === 'function') {
    try {
      const { success } = await env.RATE_LIMITER.limit({ key: ip });
      return success;
    } catch {
      // The limiter is down: fall through to the local counter.
    }
  }

  // Best effort: each Cloudflare isolate counts on its own, and isolates
  // come and go, so this only slows down a single noisy client.
  let counter = fallbackCounters.get(ip);
  if (!counter || now - counter.windowStart >= FALLBACK_WINDOW_MS) {
    if (!counter && fallbackCounters.size >= FALLBACK_MAX_IPS) {
      for (const [key, value] of fallbackCounters) {
        if (now - value.windowStart >= FALLBACK_WINDOW_MS) {
          fallbackCounters.delete(key);
        }
      }
      if (fallbackCounters.size >= FALLBACK_MAX_IPS) fallbackCounters.clear();
    }
    counter = { count: 0, windowStart: now };
    fallbackCounters.set(ip, counter);
  }
  counter.count += 1;
  return counter.count <= FALLBACK_LIMIT;
}

async function readKv(env) {
  if (!env.TOKEN_CACHE) return null;
  try {
    return await env.TOKEN_CACHE.get(KV_KEY, 'json');
  } catch {
    return null;
  }
}

async function writeKv(env, entry, now) {
  if (!env.TOKEN_CACHE) return;
  const ttl = Math.floor((entry.expiresAt - REFRESH_MARGIN_MS - now) / 1000);
  if (ttl < KV_MIN_TTL_S) return;
  try {
    await env.TOKEN_CACHE.put(KV_KEY, JSON.stringify(entry), {
      expirationTtl: ttl,
    });
  } catch {
    // The memory copy still serves this isolate.
  }
}

async function askTwitch(env, key) {
  const clientId = env.TWITCH_CLIENT_ID;
  const clientSecret = env.TWITCH_CLIENT_SECRET;
  if (!clientId || !clientSecret) {
    console.error('token proxy: TWITCH_CLIENT_ID or TWITCH_CLIENT_SECRET is not set');
    return null;
  }

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TWITCH_TIMEOUT_MS);
  let response;
  try {
    response = await fetch(TWITCH_TOKEN_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      // In the body, not the URL: URLs end up in logs.
      body: new URLSearchParams({
        client_id: clientId,
        client_secret: clientSecret,
        grant_type: 'client_credentials',
      }).toString(),
      signal: controller.signal,
    });
  } catch {
    console.error('token proxy: Twitch could not be reached');
    return null;
  } finally {
    clearTimeout(timer);
  }

  if (!response.ok) {
    // The status only: Twitch's error text is not needed to act on it.
    console.error(`token proxy: Twitch answered ${response.status}`);
    return null;
  }

  let body;
  try {
    body = await response.json();
  } catch {
    console.error('token proxy: Twitch answered something that is not JSON');
    return null;
  }

  const token = body && body.access_token;
  const expiresIn = body && body.expires_in;
  if (
    typeof token !== 'string' ||
    !TOKEN_PATTERN.test(token) ||
    typeof expiresIn !== 'number' ||
    !Number.isFinite(expiresIn) ||
    expiresIn <= 0
  ) {
    console.error('token proxy: Twitch answered without a usable token');
    return null;
  }

  return { token, expiresAt: Date.now() + expiresIn * 1000, key };
}

async function currentToken(env, now) {
  const key = await credentialsKey(env);
  if (usable(memoryToken, now, key)) return memoryToken;

  const stored = await readKv(env);
  if (usable(stored, now, key)) {
    memoryToken = { token: stored.token, expiresAt: stored.expiresAt, key };
    return memoryToken;
  }

  // Not shared with other requests waiting at the same moment: Workers do
  // not let one request wait on another's I/O. A refresh happens about once
  // every two months, so a few simultaneous ones cost Twitch a few calls.
  const fresh = await askTwitch(env, key);
  if (!usable(fresh, Date.now(), key)) return null;
  memoryToken = fresh;
  await writeKv(env, fresh, Date.now());
  return fresh;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname !== '/app-token') {
      return json(404, { error: 'not_found' });
    }
    if (request.method !== 'GET') {
      return json(405, { error: 'method_not_allowed' }, { Allow: 'GET' });
    }

    const now = Date.now();
    if (!(await allowed(request, env, now))) {
      return json(429, { error: 'rate_limited' }, { 'Retry-After': '60' });
    }

    let entry;
    try {
      entry = await currentToken(env, now);
    } catch {
      console.error('token proxy: unexpected failure');
      return unavailable();
    }
    if (!entry) return unavailable();

    return json(200, {
      access_token: entry.token,
      expires_in: Math.max(0, Math.floor((entry.expiresAt - Date.now()) / 1000)),
    });
  },
};
