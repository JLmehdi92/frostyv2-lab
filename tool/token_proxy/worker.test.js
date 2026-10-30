// Run with: node --test   (from tool/token_proxy/, Node 18 or newer)
// No dependencies: Twitch is a mocked fetch, KV and the rate limiter are
// in-memory fakes.
import { test, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';

const SECRET = 'very-secret-value-0123456789';
const CLIENT = 'publicappclientid0123456789ab';
const TOKEN = 'abcdefghijklmnopqrstuvwxyz0123';
const TOKEN_2 = 'zyxwvutsrqponmlkjihgfedcba9876';
const MINUTE = 60 * 1000;
const DAY = 24 * 60 * MINUTE;
const LIFETIME_S = 5_000_000; // about 58 days, what Twitch gives

let fresh = 0;
// Each test gets its own copy of the module (its own memory), as a new
// Cloudflare isolate would.
const loadWorker = async () =>
  (await import(`./worker.js?case=${fresh++}`)).default;

const realFetch = globalThis.fetch;
const realNow = Date.now;
const realError = console.error;
const realLog = console.log;

let now;
let calls;
let mintAnswer;
let validateAnswer;
let logged;
let kv;

const tokenAnswer = (token, expiresIn = LIFETIME_S) => () =>
  new Response(
    JSON.stringify({ access_token: token, expires_in: expiresIn, token_type: 'bearer' }),
    { status: 200, headers: { 'Content-Type': 'application/json' } },
  );

const validAnswer = (client = CLIENT) => () =>
  new Response(JSON.stringify({ client_id: client, scopes: [], expires_in: 4_000_000 }), {
    status: 200,
  });

const mints = () => calls.filter((c) => c.url.endsWith('/oauth2/token'));
const validations = () => calls.filter((c) => c.url.endsWith('/oauth2/validate'));

function fakeKv() {
  const store = new Map();
  return {
    store,
    async get(key, type) {
      const value = store.get(key);
      if (value === undefined) return null;
      return type === 'json' ? JSON.parse(value.value) : value.value;
    },
    async put(key, value, options) {
      store.set(key, { value, options });
    },
    async delete(key) {
      store.delete(key);
    },
  };
}

beforeEach(() => {
  now = 1_800_000_000_000;
  Date.now = () => now;
  calls = [];
  mintAnswer = tokenAnswer(TOKEN);
  validateAnswer = validAnswer();
  globalThis.fetch = async (url, init) => {
    calls.push({ url: String(url), init });
    if (String(url).endsWith('/oauth2/validate')) return validateAnswer(init);
    return mintAnswer(init);
  };
  logged = [];
  console.error = (...args) => logged.push(args.join(' '));
  console.log = (...args) => logged.push(args.join(' '));
  kv = fakeKv();
});

afterEach(() => {
  globalThis.fetch = realFetch;
  Date.now = realNow;
  console.error = realError;
  console.log = realLog;
});

const env = (extra = {}) => ({
  TWITCH_CLIENT_ID: CLIENT,
  TWITCH_CLIENT_SECRET: SECRET,
  TOKEN_CACHE: kv,
  ...extra,
});

const get = (path = '/app-token', { method = 'GET', ip = '203.0.113.7' } = {}) =>
  new Request(`https://onset-token.example.workers.dev${path}`, {
    method,
    headers: { 'CF-Connecting-IP': ip },
  });

const tokenOf = async (response) => (await response.json()).access_token;

test('GET /app-token hands out a token from Twitch, with its app', async () => {
  const worker = await loadWorker();
  const response = await worker.fetch(get(), env());

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    access_token: TOKEN,
    expires_in: LIFETIME_S,
    client_id: CLIENT,
  });
  assert.equal(response.headers.get('Cache-Control'), 'no-store');
  assert.equal(response.headers.get('Access-Control-Allow-Origin'), null);

  assert.equal(mints().length, 1);
  const call = mints()[0];
  assert.equal(call.url, 'https://id.twitch.tv/oauth2/token');
  assert.equal(call.init.method, 'POST');
  const body = new URLSearchParams(call.init.body);
  assert.equal(body.get('grant_type'), 'client_credentials');
  assert.equal(body.get('client_id'), CLIENT);
  assert.equal(body.get('client_secret'), SECRET);
  // The secret goes in the body, never in a URL.
  assert.ok(!call.url.includes(SECRET));
});

test('without the TOKEN_CACHE KV binding: 502, Twitch not asked, said in the log', async () => {
  const worker = await loadWorker();
  const response = await worker.fetch(get(), env({ TOKEN_CACHE: undefined }));

  assert.equal(response.status, 502);
  assert.deepEqual(await response.json(), { error: 'unavailable' });
  assert.equal(calls.length, 0);
  assert.ok(logged.some((line) => line.includes('TOKEN_CACHE')), logged.join('\n'));
});

test('the token is cached: Twitch is asked once', async () => {
  const worker = await loadWorker();
  for (let i = 0; i < 5; i++) {
    const response = await worker.fetch(get('/app-token', { ip: `198.51.100.${i}` }), env());
    assert.equal(await tokenOf(response), TOKEN);
  }
  assert.equal(mints().length, 1);
  assert.equal(validations().length, 0);
});

test('a token is only handed out while it has 7 days left', async () => {
  const worker = await loadWorker();
  await worker.fetch(get(), env());

  // 7 days and an hour before Twitch's expiry: still the cached one.
  now += LIFETIME_S * 1000 - 7 * DAY - 60 * MINUTE;
  let response = await worker.fetch(get(), env());
  assert.equal(await tokenOf(response), TOKEN);
  assert.equal(mints().length, 1);

  // Under 7 days left: a new one.
  now += 2 * 60 * MINUTE;
  mintAnswer = tokenAnswer(TOKEN_2);
  response = await worker.fetch(get(), env());
  assert.equal(await tokenOf(response), TOKEN_2);
  assert.equal(mints().length, 2);
});

test('KV shares the token between isolates, until the 7-day mark', async () => {
  const first = await loadWorker();
  await first.fetch(get(), env());
  assert.equal(mints().length, 1);
  const stored = kv.store.get('twitch_app_token');
  assert.ok(stored);
  assert.equal(stored.options.expirationTtl, LIFETIME_S - 7 * 24 * 60 * 60);
  assert.ok(!stored.value.includes(SECRET));

  const second = await loadWorker();
  const response = await second.fetch(get(), env());
  assert.equal(await tokenOf(response), TOKEN);
  assert.equal(mints().length, 1);
});

test('the cached token is checked with Twitch at most every 10 minutes', async () => {
  const worker = await loadWorker();
  await worker.fetch(get(), env());

  now += 9 * MINUTE;
  await worker.fetch(get(), env());
  assert.equal(validations().length, 0);

  now += 2 * MINUTE;
  const response = await worker.fetch(get(), env());
  assert.equal(await tokenOf(response), TOKEN);
  assert.equal(validations().length, 1);
  const check = validations()[0];
  assert.equal(check.url, 'https://id.twitch.tv/oauth2/validate');
  assert.equal(new Headers(check.init.headers).get('Authorization'), `OAuth ${TOKEN}`);
  // Recorded in KV, so other isolates do not check again at once.
  assert.equal(JSON.parse(kv.store.get('twitch_app_token').value).validatedAt, now);

  const other = await loadWorker();
  await other.fetch(get(), env());
  assert.equal(validations().length, 1);
});

test('a revoked token is dropped everywhere and a new one minted', async () => {
  const worker = await loadWorker();
  await worker.fetch(get(), env());

  now += 11 * MINUTE;
  validateAnswer = () => new Response(JSON.stringify({ status: 401, message: 'invalid access token' }), { status: 401 });
  mintAnswer = tokenAnswer(TOKEN_2);
  const response = await worker.fetch(get(), env());

  assert.equal(await tokenOf(response), TOKEN_2);
  assert.equal(mints().length, 2);
  assert.equal(JSON.parse(kv.store.get('twitch_app_token').value).token, TOKEN_2);
});

test("a token Twitch says is another app's is dropped too", async () => {
  const worker = await loadWorker();
  await worker.fetch(get(), env());

  now += 11 * MINUTE;
  validateAnswer = validAnswer('someotherclient0123456789abc');
  mintAnswer = tokenAnswer(TOKEN_2);
  const response = await worker.fetch(get(), env());
  assert.equal(await tokenOf(response), TOKEN_2);
});

test('when Twitch cannot be asked, the cached token is still served', async () => {
  const worker = await loadWorker();
  await worker.fetch(get(), env());

  now += 11 * MINUTE;
  validateAnswer = () => {
    throw new TypeError('network down');
  };
  let response = await worker.fetch(get(), env());
  assert.equal(await tokenOf(response), TOKEN);
  assert.equal(mints().length, 1);

  // Not asked again on every request: a minute later at the earliest.
  response = await worker.fetch(get(), env());
  assert.equal(validations().length, 1);
  now += 61 * 1000;
  validateAnswer = validAnswer();
  await worker.fetch(get(), env());
  assert.equal(validations().length, 2);
});

test('mints are throttled to one a minute for every isolate', async () => {
  mintAnswer = () => new Response('{}', { status: 500 });
  const first = await loadWorker();
  assert.equal((await first.fetch(get(), env())).status, 502);
  assert.equal(mints().length, 1);

  // The same isolate: a failure is remembered.
  assert.equal((await first.fetch(get(), env())).status, 502);
  // Another isolate, within the minute: the KV mark holds it back.
  mintAnswer = tokenAnswer(TOKEN);
  const second = await loadWorker();
  assert.equal((await second.fetch(get(), env())).status, 502);
  assert.equal(mints().length, 1);

  now += 61 * 1000;
  const response = await second.fetch(get(), env());
  assert.equal(await tokenOf(response), TOKEN);
  assert.equal(mints().length, 2);
});

test('an isolate remembers a failed mint for 30 s, even without the KV mark', async () => {
  mintAnswer = () => new Response('{}', { status: 500 });
  const worker = await loadWorker();
  assert.equal((await worker.fetch(get(), env())).status, 502);
  // The mark is lost (a KV write that failed, or not yet seen here).
  kv.store.delete('twitch_app_token_mint');

  now += 20 * 1000;
  mintAnswer = tokenAnswer(TOKEN);
  assert.equal((await worker.fetch(get(), env())).status, 502);
  assert.equal(mints().length, 1);

  now += 11 * 1000;
  kv.store.delete('twitch_app_token_mint');
  assert.equal(await tokenOf(await worker.fetch(get(), env())), TOKEN);
  assert.equal(mints().length, 2);
});

test('a revoked token cannot make the Worker mint more than once a minute', async () => {
  const worker = await loadWorker();
  await worker.fetch(get(), env());
  validateAnswer = () => new Response('{}', { status: 401 });

  // Revoked right after it was minted: no second mint within the minute.
  now += 11 * MINUTE;
  kv.store.set('twitch_app_token_mint', { value: JSON.stringify({ at: now - 30 * 1000 }) });
  const response = await worker.fetch(get(), env());
  assert.equal(response.status, 502);
  assert.equal(mints().length, 1);
});

test('a broken KV value is ignored', async () => {
  kv.store.set('twitch_app_token', { value: JSON.stringify({ token: 'x y', expiresAt: now * 2 }) });
  const worker = await loadWorker();
  const response = await worker.fetch(get(), env());
  assert.equal(await tokenOf(response), TOKEN);
  assert.equal(mints().length, 1);
});

test('a KV token made with another secret is not served', async () => {
  const first = await loadWorker();
  await first.fetch(get(), env());
  assert.equal(mints().length, 1);

  // The secret was replaced: new isolates must not reuse the old token.
  mintAnswer = tokenAnswer(TOKEN_2);
  now += 2 * MINUTE;
  const second = await loadWorker();
  const response = await second.fetch(
    get(),
    env({ TWITCH_CLIENT_SECRET: 'the-new-secret-0123456789' }),
  );
  assert.equal(await tokenOf(response), TOKEN_2);
  assert.equal(mints().length, 2);
  assert.ok(!kv.store.get('twitch_app_token').value.includes('the-new-secret'));
});

for (const [name, answer] of [
  ['an error status', () => new Response(JSON.stringify({ status: 403, message: `invalid client secret ${SECRET}` }), { status: 403 })],
  ['a page instead of JSON', () => new Response('<html>oops</html>', { status: 200 })],
  ['no token', () => new Response(JSON.stringify({ expires_in: 100 }), { status: 200 })],
  ['no expiry', () => new Response(JSON.stringify({ access_token: TOKEN }), { status: 200 })],
  ['an odd token', () => new Response(JSON.stringify({ access_token: 'a b\r\nc', expires_in: LIFETIME_S }), { status: 200 })],
  ['a token about to expire', () => new Response(JSON.stringify({ access_token: TOKEN, expires_in: 6 * 24 * 60 * 60 }), { status: 200 })],
  ['a network failure', () => { throw new TypeError('network down'); }],
]) {
  test(`Twitch answering with ${name} is a generic 502`, async () => {
    mintAnswer = answer;
    const worker = await loadWorker();
    const response = await worker.fetch(get(), env());

    assert.equal(response.status, 502);
    const text = await response.text();
    assert.deepEqual(JSON.parse(text), { error: 'unavailable' });
    assert.ok(!text.includes(SECRET));
    assert.ok(!text.includes(CLIENT));
    assert.ok(logged.every((line) => !line.includes(SECRET)), logged.join('\n'));
  });
}

test('a Twitch that hangs is given up on', { timeout: 5000 }, async () => {
  globalThis.fetch = (url, init) =>
    new Promise((_, reject) => {
      init.signal.addEventListener('abort', () => reject(new Error('aborted')));
    });
  const realSetTimeout = globalThis.setTimeout;
  // Run the 5 s deadline at once.
  globalThis.setTimeout = (fn) => realSetTimeout(fn, 0);
  try {
    const worker = await loadWorker();
    const response = await worker.fetch(get(), env());
    assert.equal(response.status, 502);
  } finally {
    globalThis.setTimeout = realSetTimeout;
  }
});

test('a Twitch that sends headers and then stalls is given up on too', { timeout: 5000 }, async () => {
  globalThis.fetch = async (url, init) =>
    new Response(
      new ReadableStream({
        start(controller) {
          controller.enqueue(new TextEncoder().encode('{"access_token":'));
          init.signal.addEventListener('abort', () => controller.error(new Error('aborted')));
        },
      }),
      { status: 200 },
    );
  const realSetTimeout = globalThis.setTimeout;
  globalThis.setTimeout = (fn) => realSetTimeout(fn, 10);
  try {
    const worker = await loadWorker();
    const response = await worker.fetch(get(), env());
    assert.equal(response.status, 502);
  } finally {
    globalThis.setTimeout = realSetTimeout;
  }
});

test('missing secrets: 502, Twitch not asked, nothing leaked', async () => {
  const worker = await loadWorker();
  const response = await worker.fetch(get(), { TWITCH_CLIENT_ID: CLIENT, TOKEN_CACHE: kv });
  assert.equal(response.status, 502);
  assert.equal(calls.length, 0);
  assert.deepEqual(await response.json(), { error: 'unavailable' });
});

test('other paths are 404, other methods 405, without asking Twitch', async () => {
  const worker = await loadWorker();
  for (const path of ['/', '/app-token/', '/token', '/app-token.json', '/APP-TOKEN']) {
    assert.equal((await worker.fetch(get(path), env())).status, 404, path);
  }
  for (const method of ['POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH', 'HEAD']) {
    const response = await worker.fetch(get('/app-token', { method }), env());
    assert.equal(response.status, 405, method);
    assert.equal(response.headers.get('Allow'), 'GET');
    assert.equal(response.headers.get('Access-Control-Allow-Origin'), null);
  }
  assert.equal(calls.length, 0);
});

test('without a rate limiting binding, 10 a minute per IP (this isolate)', async () => {
  const worker = await loadWorker();
  for (let i = 0; i < 10; i++) {
    assert.equal((await worker.fetch(get(), env())).status, 200);
  }
  const limited = await worker.fetch(get(), env());
  assert.equal(limited.status, 429);
  assert.equal(limited.headers.get('Retry-After'), '60');
  assert.deepEqual(await limited.json(), { error: 'rate_limited' });

  // Another IP is not affected; the same one is let in again a minute later.
  assert.equal((await worker.fetch(get('/app-token', { ip: '192.0.2.1' }), env())).status, 200);
  now += MINUTE;
  assert.equal((await worker.fetch(get(), env())).status, 200);
});

test('IPv6 addresses are counted by their /64', async () => {
  const worker = await loadWorker();
  for (let i = 1; i <= 10; i++) {
    const ip = `2001:db8:1:2:${i.toString(16)}::1`;
    assert.equal((await worker.fetch(get('/app-token', { ip }), env())).status, 200, ip);
  }
  // The same /64, written differently: still the same client.
  const same = await worker.fetch(get('/app-token', { ip: '2001:0DB8:0001:0002:ffff:ffff:ffff:ffff' }), env());
  assert.equal(same.status, 429);
  // The next /64 is another client.
  const next = await worker.fetch(get('/app-token', { ip: '2001:db8:1:3::1' }), env());
  assert.equal(next.status, 200);
});

test('the rate limiting binding decides when there is one, by IP or /64', async () => {
  const keys = [];
  const limiter = {
    async limit({ key }) {
      keys.push(key);
      return { success: keys.length <= 2 };
    },
  };
  const worker = await loadWorker();
  assert.equal((await worker.fetch(get(), env({ RATE_LIMITER: limiter }))).status, 200);
  assert.equal(
    (await worker.fetch(get('/app-token', { ip: '2001:db8::5' }), env({ RATE_LIMITER: limiter }))).status,
    200,
  );
  assert.equal((await worker.fetch(get(), env({ RATE_LIMITER: limiter }))).status, 429);
  assert.deepEqual(keys, ['203.0.113.7', '2001:db8:0:0::/64', '203.0.113.7']);
});

test('a rate limited request never reaches Twitch', async () => {
  const limiter = { limit: async () => ({ success: false }) };
  const worker = await loadWorker();
  const response = await worker.fetch(get(), env({ RATE_LIMITER: limiter }));
  assert.equal(response.status, 429);
  assert.equal(calls.length, 0);
});
