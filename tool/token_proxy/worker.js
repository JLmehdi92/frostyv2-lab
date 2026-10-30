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
//                         last minted. Written only when a mint is tried:
//                         one write per attempt (backing off to every 15
//                         minutes while Twitch refuses), one per token
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

// While a new token cannot be minted (Twitch refuses, or the backoff holds
// it back), the old one is still handed out until this close to its real
// expiry, as long as Twitch takes it: better than no token at all.
const SERVE_FLOOR_MS = 60 * 60 * 1000;

// A request waits this long for the shared check-and-mint before giving up
// (502); a check-and-mint running longer than REFRESH_ABANDON_MS is taken
// for dead and the next request starts another. Each Twitch call has
// TWITCH_TIMEOUT_MS, and one refresh makes at most two.
const WAIT_DEADLINE_MS = 12 * 1000;
const REFRESH_ABANDON_MS = 15 * 1000;

// How often each running copy of the Worker checks the shared token with
// Twitch (it may have been revoked). The time is kept in that copy's memory:
// a check never writes KV, however many copies run.
const VALIDATE_EVERY_MS = 10 * 60 * 1000;

// When Twitch cannot be asked whether the token is still good, it is served
// as it is and asked again this much later.
const VALIDATE_RETRY_MS = 60 * 1000;

// At most one mint a minute for the whole world (a KV mark). Mints that keep
// failing (a secret replaced at Twitch but not here) back off: 1, 2, 4, 8,
// then every 15 minutes, so they cost about 100 KV writes a day, not 1,440.
// A successful mint resets it. A failure is also remembered this long in
// each isolate before Twitch is tried again.
const MINT_EVERY_MS = 60 * 1000;
const MINT_BACKOFF_MAX_MS = 15 * 60 * 1000;
const FAILURE_BACKOFF_MS = 30 * 1000;

// The mark outlives the longest wait, so the failure count is not lost.
const KV_MINT_TTL_S = 24 * 60 * 60;

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

// Until when this isolate does not try to mint again after a failure, and
// with which credentials (fixing the secret ends the wait at once).
let failedUntil = { until: 0, key: null };

// The check (and, if needed, mint) this isolate is doing right now, and when
// it started: requests that arrive meanwhile wait for it instead of
// checking and minting again.
let refreshing = null;

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

// Whether [entry] can be handed out with at least [minLeft] before Twitch
// expires it: REFRESH_MARGIN_MS normally, SERVE_FLOOR_MS while no new token
// can be minted.
function usable(entry, now, key, minLeft = REFRESH_MARGIN_MS) {
  return (
    entry !== null &&
    typeof entry === 'object' &&
    entry.key === key &&
    typeof entry.token === 'string' &&
    TOKEN_PATTERN.test(entry.token) &&
    typeof entry.expiresAt === 'number' &&
    typeof entry.validatedAt === 'number' &&
    entry.expiresAt - minLeft > now
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
  // Kept until shortly before its real expiry, so that it can still be
  // served from KV if minting its successor fails.
  const ttl = Math.floor((entry.expiresAt - SERVE_FLOOR_MS - now) / 1000);
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
async function storedToken(env, key, now, minLeft = REFRESH_MARGIN_MS) {
  const stored = await readKv(env, KV_KEY);
  if (!usable(stored, now, key, minLeft) || deadTokens.has(stored.token)) return null;
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

// How long after a mint attempt the next may start, [failures] attempts in
// a row having failed (0: the last one worked).
function mintWait(failures) {
  if (failures <= 1) return MINT_EVERY_MS;
  return Math.min(MINT_EVERY_MS * 2 ** (failures - 1), MINT_BACKOFF_MAX_MS);
}

async function writeMintMark(env, at, failures, key) {
  try {
    await env.TOKEN_CACHE.put(KV_MINT_KEY, JSON.stringify({ at, failures, key }), {
      expirationTtl: KV_MINT_TTL_S,
    });
  } catch {
    // Without the mark, the isolate's own backoff still applies.
  }
}

async function mint(env, key, now) {
  const isolateWait = failedUntil.key === key && now < failedUntil.until;
  let mark = isolateWait ? null : await readKv(env, KV_MINT_KEY);
  // A mark of other credentials says nothing about these: the secret was
  // just fixed, so no waiting.
  if (mark && mark.key !== key) mark = null;
  let failures =
    mark && Number.isInteger(mark.failures) && mark.failures > 0 ? mark.failures : 0;
  if (failures > 0) {
    // The attempt the mark counts as failed may have worked: the token it
    // minted is in KV, minted after the mark (no extra write to reset it).
    const latest = await readKv(env, KV_KEY);
    if (latest && typeof latest.validatedAt === 'number' && latest.validatedAt >= mark.at) {
      failures = 0;
    }
  }
  if (
    isolateWait ||
    (mark && typeof mark.at === 'number' && now - mark.at < mintWait(failures))
  ) {
    // Not this isolate's turn: another may just have minted one.
    const other = await storedToken(env, key, now);
    if (other) memoryToken = other;
    return other;
  }
  // An isolate holding an old or dead token never read KV: another may
  // have minted the next one already. One read, rather than a token per
  // isolate.
  const minted = await storedToken(env, key, now);
  if (minted) {
    memoryToken = minted;
    return minted;
  }
  // Claimed as if it fails: one write per attempt. A success is told by the
  // token it writes (see above).
  await writeMintMark(env, now, failures + 1, key);

  const fresh = await askTwitch(env, key);
  if (!usable(fresh, Date.now(), key)) {
    if (fresh) console.error('token proxy: Twitch gave a token that expires too soon');
    failedUntil = { until: now + FAILURE_BACKOFF_MS, key };
    return null;
  }
  memoryToken = fresh;
  await writeToken(env, fresh, Date.now());
  return fresh;
}

async function currentToken(env, now, ctx) {
  if (!env.TOKEN_CACHE || typeof env.TOKEN_CACHE.get !== 'function') {
    console.error('token proxy: the TOKEN_CACHE KV binding is missing (see README)');
    return null;
  }
  if (!env.TWITCH_CLIENT_ID || !env.TWITCH_CLIENT_SECRET) {
    console.error('token proxy: TWITCH_CLIENT_ID or TWITCH_CLIENT_SECRET is not set');
    return null;
  }

  const key = await credentialsKey(env);
  if (
    usable(memoryToken, now, key) &&
    now - memoryToken.validatedAt < VALIDATE_EVERY_MS &&
    !deadTokens.has(memoryToken.token)
  ) {
    return memoryToken;
  }
  // One check-and-mint at a time in this isolate; cleared whatever happens,
  // so a failure never wedges it. One that runs too long is taken for dead
  // and replaced: if the request that started it was cancelled, the
  // runtime may have cancelled its fetches and timers too, and it would
  // never settle.
  if (!refreshing || now - refreshing.startedAt > REFRESH_ABANDON_MS) {
    const promise = refresh(env, key, now).finally(() => {
      if (refreshing && refreshing.promise === promise) refreshing = null;
    });
    refreshing = { promise, startedAt: now };
    // Other requests wait on it: it must outlive the request that started
    // it, which the runtime would otherwise cancel along with its fetches
    // as soon as that client hangs up (the app gives up after 6 s).
    if (ctx && typeof ctx.waitUntil === 'function') {
      ctx.waitUntil(promise.catch(() => {}));
    }
  }
  return waitFor(refreshing.promise);
}

// The shared refresh, or null (a 502) if it is not done by this request's
// own deadline.
async function waitFor(promise) {
  let timer;
  const deadline = new Promise((resolve) => {
    timer = setTimeout(() => resolve(null), WAIT_DEADLINE_MS);
  });
  try {
    return await Promise.race([promise, deadline]);
  } finally {
    clearTimeout(timer);
  }
}

async function refresh(env, key, now) {
  // Any token still worth handing out, even in its last 7 days.
  let entry =
    usable(memoryToken, now, key, SERVE_FLOOR_MS) && !deadTokens.has(memoryToken.token)
      ? memoryToken
      : null;
  if (!entry) entry = await storedToken(env, key, now, SERVE_FLOOR_MS);

  if (entry && now - entry.validatedAt >= VALIDATE_EVERY_MS) {
    const verdict = await checkWithTwitch(env, entry.token);
    if (verdict === 'good') {
      // In memory only: a check never writes KV.
      entry = { ...entry, validatedAt: now };
    } else if (verdict === 'unknown') {
      // Served as it is; asked again in a minute, by this isolate.
      entry = { ...entry, validatedAt: now - VALIDATE_EVERY_MS + VALIDATE_RETRY_MS };
    } else {
      console.error('token proxy: the cached token was refused by Twitch, minting another');
      markDead(entry.token);
      entry = null;
    }
  }
  // A refresh abandoned while it waited on Twitch can end after a newer one
  // found this token dead: it must not bring it back.
  if (entry && deadTokens.has(entry.token)) entry = null;
  if (entry) memoryToken = entry;
  if (entry && usable(entry, now, key)) return entry;

  // None, or one in its last 7 days: mint. If that fails or must wait, the
  // old one is still better than nothing.
  const minted = await mint(env, key, now);
  return minted || entry;
}

export default {
  async fetch(request, env, ctx) {
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
      entry = await currentToken(env, now, ctx);
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
