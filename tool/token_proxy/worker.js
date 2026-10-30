// ONSET token proxy: a Cloudflare Worker that hands logged-out ONSET apps a
// Twitch app access token, so no Twitch client secret ships in an APK.
//
// GET /app-token -> 200 { "access_token": "...", "expires_in": N, "client_id": "..." }
// Anything else  -> 404 (other paths) or 405 (other methods on /app-token).
//
// The token belongs to a SECOND Twitch application ("ONSET public"), not the
// one people log in with. No user ever authorizes that second application,
// so its tokens can reach nobody's private data (an app token of the login
// application could, for example, subscribe to the whispers of everyone who
// logged in to ONSET). The app sends client_id along with the token.
//
// Settings (Cloudflare dashboard -> the Worker -> Settings):
//   TWITCH_CLIENT_ID      secret   the SECOND application's client id
//   TWITCH_CLIENT_SECRET  secret   the SECOND application's client secret
//   TOKEN_CACHE           KV namespace binding (required): one token shared
//                         by all of Cloudflare's machines, and when one was
//                         last minted. Written only when a token is minted:
//                         two writes per mint, a few a day at most
//   RATE_LIMITER          optional rate limiting binding (wrangler.toml);
//                         without it a best-effort counter per isolate is used
//
// The token is public by design (every logged-out app gets it), so anyone
// can revoke it with Twitch. Each running copy of the Worker therefore
// checks it with Twitch at most every 10 minutes (keeping the time in its
// own memory, so checks never write KV) and mints a new one when it is
// dead, at most once a minute for the whole world, so a revoked token cannot
// stick around and revoking cannot make the Worker hammer Twitch. A dead
// token is never deleted from KV (a copy with a stale read could delete one
// another copy just minted): the next mint overwrites it, and each copy
// remembers the dead tokens it found so it does not serve them again.
//
// The secret is only ever sent to id.twitch.tv. It is never returned, never
// logged, and never part of an error.
//
// Kept to one file with no imports, so it can be pasted into the dashboard.

const TWITCH_TOKEN_URL = 'https://id.twitch.tv/oauth2/token';
const TWITCH_VALIDATE_URL = 'https://id.twitch.tv/oauth2/validate';

// A token is handed out while it has at least this long left (Twitch's
// last about 58 days), then a new one is minted: an app that keeps the one
// it got has a week before it expires.
const REFRESH_MARGIN_MS = 7 * 24 * 60 * 60 * 1000;

// How often each running copy of the Worker checks the shared token with
// Twitch (it may have been revoked). The time is kept in that copy's memory:
// a check never writes KV, however many copies run.
const VALIDATE_EVERY_MS = 10 * 60 * 1000;

// When Twitch cannot be asked whether the token is still good, it is served
// as it is and asked again this much later.
const VALIDATE_RETRY_MS = 60 * 1000;

// At most one mint a minute for the whole world (a KV mark), and a failure
// is remembered this long in each isolate before Twitch is tried again.
const MINT_EVERY_MS = 60 * 1000;
const FAILURE_BACKOFF_MS = 30 * 1000;

// Twitch's answer gets this long, body included, after which the proxy
// gives up (502).
const TWITCH_TIMEOUT_MS = 5000;

const KV_KEY = 'twitch_app_token';
const KV_MINT_KEY = 'twitch_app_token_mint';

// KV refuses expirations closer than 60 s.
const KV_MIN_TTL_S = 60;

// Best-effort fallback limit (when there is no RATE_LIMITER binding): this
// many requests per IP (per /64 for IPv6) per window, counted in this
// isolate only.
const FALLBACK_LIMIT = 10;
const FALLBACK_WINDOW_MS = 60 * 1000;
const FALLBACK_MAX_IPS = 10000;

// What Twitch's app tokens look like: nothing else is passed on.
const TOKEN_PATTERN = /^[A-Za-z0-9]{16,128}$/;

// This isolate's copy of the token: { token, expiresAt, validatedAt, key },
// times in ms since epoch, key the credentials' fingerprint.
let memoryToken = null;

// Until when this isolate does not try to mint again after a failure.
let failedUntil = 0;

// Tokens this isolate found dead: never served again, even if KV still
// holds one until the next mint overwrites it.
const deadTokens = new Set();
const DEAD_TOKENS_MAX = 100;

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
// replaced, the KV copy would otherwise be served for weeks.
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
    typeof entry.validatedAt === 'number' &&
    entry.expiresAt - REFRESH_MARGIN_MS > now
  );
}

// The rate limit key: the IPv4 address, or the /64 of an IPv6 address (one
// subscriber usually has a whole /64, so counting single addresses would
// let one client use billions of them).
function rateKey(ip) {
  if (!ip || !ip.includes(':')) return ip || 'unknown';
  const [head, tail = null] = ip.toLowerCase().split('::');
  const headParts = head ? head.split(':') : [];
  const tailParts = tail === null ? [] : tail ? tail.split(':') : [];
  // An embedded IPv4 (::ffff:1.2.3.4) takes two groups.
  const groupsOf = (parts) =>
    parts.reduce((n, part) => n + (part.includes('.') ? 2 : 1), 0);
  const missing = 8 - groupsOf(headParts) - groupsOf(tailParts);
  const groups = [
    ...headParts,
    ...(tail === null ? [] : Array(Math.max(0, missing)).fill('0')),
    ...tailParts,
  ];
  const prefix = groups
    .slice(0, 4)
    .map((group) => (/^[0-9a-f]{1,4}$/.test(group) ? parseInt(group, 16).toString(16) : '?'));
  return `${prefix.join(':')}::/64`;
}

async function allowed(request, env, now) {
  const key = rateKey(request.headers.get('CF-Connecting-IP'));

  if (env.RATE_LIMITER && typeof env.RATE_LIMITER.limit === 'function') {
    try {
      const { success } = await env.RATE_LIMITER.limit({ key });
      return success;
    } catch {
      // The limiter is down: fall through to the local counter.
    }
  }

  // Best effort: each Cloudflare isolate counts on its own, and isolates
  // come and go, so this only slows down a single noisy client.
  let counter = fallbackCounters.get(key);
  if (!counter || now - counter.windowStart >= FALLBACK_WINDOW_MS) {
    if (!counter && fallbackCounters.size >= FALLBACK_MAX_IPS) {
      for (const [k, value] of fallbackCounters) {
        if (now - value.windowStart >= FALLBACK_WINDOW_MS) {
          fallbackCounters.delete(k);
        }
      }
      if (fallbackCounters.size >= FALLBACK_MAX_IPS) fallbackCounters.clear();
    }
    counter = { count: 0, windowStart: now };
    fallbackCounters.set(key, counter);
  }
  counter.count += 1;
  return counter.count <= FALLBACK_LIMIT;
}

async function readKv(env, key) {
  try {
    return await env.TOKEN_CACHE.get(key, 'json');
  } catch {
    return null;
  }
}

async function writeToken(env, entry, now) {
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

// The token KV holds, when it is usable and not one this isolate found
// dead; its check time is the mint's, until this isolate checks it.
async function storedToken(env, key, now) {
  const stored = await readKv(env, KV_KEY);
  if (!usable(stored, now, key) || deadTokens.has(stored.token)) return null;
  return {
    token: stored.token,
    expiresAt: stored.expiresAt,
    validatedAt: stored.validatedAt,
    key,
  };
}

function markDead(token) {
  if (deadTokens.size >= DEAD_TOKENS_MAX) deadTokens.clear();
  deadTokens.add(token);
  memoryToken = null;
}

// fetch() with one deadline for the whole exchange, body included: the
// timer is cleared only once read() has the body.
async function fetchWithin(url, init, read) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TWITCH_TIMEOUT_MS);
  try {
    const response = await fetch(url, { ...init, signal: controller.signal });
    return await read(response);
  } finally {
    clearTimeout(timer);
  }
}

// Whether Twitch still takes the token as this application's:
// 'good', 'dead' (refused, or another application's) or 'unknown'.
async function checkWithTwitch(env, token) {
  try {
    return await fetchWithin(
      TWITCH_VALIDATE_URL,
      { headers: { Authorization: `OAuth ${token}` } },
      async (response) => {
        if (response.status === 401) return 'dead';
        if (!response.ok) return 'unknown';
        const body = await response.json();
        return body && body.client_id === env.TWITCH_CLIENT_ID ? 'good' : 'dead';
      },
    );
  } catch {
    return 'unknown';
  }
}

async function askTwitch(env, key) {
  let body;
  try {
    body = await fetchWithin(
      TWITCH_TOKEN_URL,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        // In the body, not the URL: URLs end up in logs.
        body: new URLSearchParams({
          client_id: env.TWITCH_CLIENT_ID,
          client_secret: env.TWITCH_CLIENT_SECRET,
          grant_type: 'client_credentials',
        }).toString(),
      },
      async (response) => {
        if (!response.ok) {
          // The status only: Twitch's error text is not needed to act on it.
          console.error(`token proxy: Twitch answered ${response.status}`);
          return null;
        }
        try {
          return await response.json();
        } catch {
          console.error('token proxy: Twitch answered something that is not JSON');
          return null;
        }
      },
    );
  } catch {
    console.error('token proxy: Twitch could not be reached');
    return null;
  }
  if (body === null) return null;

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

  const now = Date.now();
  return { token, expiresAt: now + expiresIn * 1000, validatedAt: now, key };
}

async function mint(env, key, now) {
  const mark = now < failedUntil ? null : await readKv(env, KV_MINT_KEY);
  if (
    now < failedUntil ||
    (mark && typeof mark.at === 'number' && now - mark.at < MINT_EVERY_MS)
  ) {
    // Not this isolate's turn: another may just have minted one.
    const other = await storedToken(env, key, now);
    if (other) memoryToken = other;
    return other;
  }
  try {
    await env.TOKEN_CACHE.put(KV_MINT_KEY, JSON.stringify({ at: now }), {
      expirationTtl: KV_MIN_TTL_S,
    });
  } catch {
    // Without the mark, the isolate's own backoff still applies.
  }

  const fresh = await askTwitch(env, key);
  if (!usable(fresh, Date.now(), key)) {
    if (fresh) console.error('token proxy: Twitch gave a token that expires too soon');
    failedUntil = now + FAILURE_BACKOFF_MS;
    return null;
  }
  memoryToken = fresh;
  await writeToken(env, fresh, Date.now());
  return fresh;
}

async function currentToken(env, now) {
  if (!env.TOKEN_CACHE || typeof env.TOKEN_CACHE.get !== 'function') {
    console.error('token proxy: the TOKEN_CACHE KV binding is missing (see README)');
    return null;
  }
  if (!env.TWITCH_CLIENT_ID || !env.TWITCH_CLIENT_SECRET) {
    console.error('token proxy: TWITCH_CLIENT_ID or TWITCH_CLIENT_SECRET is not set');
    return null;
  }

  const key = await credentialsKey(env);
  let entry = usable(memoryToken, now, key) ? memoryToken : null;
  if (!entry) entry = await storedToken(env, key, now);

  if (entry) {
    if (now - entry.validatedAt < VALIDATE_EVERY_MS) {
      memoryToken = entry;
      return entry;
    }
    const verdict = await checkWithTwitch(env, entry.token);
    if (verdict === 'good') {
      // In memory only: a check never writes KV.
      memoryToken = { ...entry, validatedAt: now };
      return memoryToken;
    }
    if (verdict === 'unknown') {
      // Served as it is; asked again in a minute, by this isolate.
      memoryToken = {
        ...entry,
        validatedAt: now - VALIDATE_EVERY_MS + VALIDATE_RETRY_MS,
      };
      return memoryToken;
    }
    console.error('token proxy: the cached token was refused by Twitch, minting another');
    markDead(entry.token);
  }

  return mint(env, key, now);
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
      client_id: env.TWITCH_CLIENT_ID,
    });
  },
};
