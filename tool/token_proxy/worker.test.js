// Run with: node --test   (from tool/token_proxy/, Node 18 or newer)
// No dependencies: Twitch is a mocked fetch, KV and the rate limiter are
// in-memory fakes.
import { test, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';

const SECRET = 'very-secret-value-0123456789';
const TOKEN = 'abcdefghijklmnopqrstuvwxyz0123';
const TOKEN_2 = 'zyxwvutsrqponmlkjihgfedcba9876';

let fresh = 0;
// Each test gets its own copy of the module (its own memory cache).
const loadWorker = async () =>
  (await import(`./worker.js?case=${fresh++}`)).default;

const realFetch = globalThis.fetch;
const realNow = Date.now;
const realError = console.error;
const realLog = console.log;

let now;
let twitchCalls;
let twitchAnswer;
let logged;

beforeEach(() => {
  now = 1_800_000_000_000;
  Date.now = () => now;
  twitchCalls = [];
  twitchAnswer = () =>
    new Response(
      JSON.stringify({ access_token: TOKEN, expires_in: 5_000_000, token_type: 'bearer' }),
      { status: 200, headers: { 'Content-Type': 'application/json' } },
    );
  globalThis.fetch = async (url, init) => {
    twitchCalls.push({ url: String(url), init });
    return twitchAnswer();
  };
  logged = [];
  console.error = (...args) => logged.push(args.join(' '));
  console.log = (...args) => logged.push(args.join(' '));
});

afterEach(() => {
  globalThis.fetch = realFetch;
  Date.now = realNow;
  console.error = realError;
  console.log = realLog;
});

const env = (extra = {}) => ({
  TWITCH_CLIENT_ID: 'the_client_id',
  TWITCH_CLIENT_SECRET: SECRET,
  ...extra,
});

const get = (path = '/app-token', { method = 'GET', ip = '203.0.113.7' } = {}) =>
  new Request(`https://onset-token.example.workers.dev${path}`, {
    method,
    headers: { 'CF-Connecting-IP': ip },
  });

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
  };
}

test('GET /app-token hands out a token from Twitch', async () => {
  const worker = await loadWorker();
  const response = await worker.fetch(get(), env());

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { access_token: TOKEN, expires_in: 5_000_000 });
  assert.equal(response.headers.get('Cache-Control'), 'no-store');
  assert.equal(response.headers.get('Access-Control-Allow-Origin'), null);

  assert.equal(twitchCalls.length, 1);
  const call = twitchCalls[0];
  assert.equal(call.url, 'https://id.twitch.tv/oauth2/token');
  assert.equal(call.init.method, 'POST');
  const body = new URLSearchParams(call.init.body);
  assert.equal(body.get('grant_type'), 'client_credentials');
  assert.equal(body.get('client_id'), 'the_client_id');
  assert.equal(body.get('client_secret'), SECRET);
  // The secret goes in the body, never in a URL.
  assert.ok(!call.url.includes(SECRET));
});

test('the token is cached: Twitch is asked once', async () => {
  const worker = await loadWorker();
  for (let i = 0; i < 5; i++) {
    const response = await worker.fetch(get('/app-token', { ip: `198.51.100.${i}` }), env());
    assert.equal((await response.json()).access_token, TOKEN);
  }
  assert.equal(twitchCalls.length, 1);
});

test('a new token is asked for about 10 minutes before expiry', async () => {
  const worker = await loadWorker();
  await worker.fetch(get(), env());

  // 11 minutes before Twitch's expiry: still the cached one.
  now += 5_000_000 * 1000 - 11 * 60 * 1000;
  let response = await worker.fetch(get(), env());
  assert.equal((await response.json()).access_token, TOKEN);
  assert.equal(twitchCalls.length, 1);

  // 9 minutes before: a new one.
  now += 2 * 60 * 1000;
  twitchAnswer = () =>
    new Response(JSON.stringify({ access_token: TOKEN_2, expires_in: 5_000_000 }), { status: 200 });
  response = await worker.fetch(get(), env());
  assert.equal((await response.json()).access_token, TOKEN_2);
  assert.equal(twitchCalls.length, 2);
});

test('KV shares the token between isolates', async () => {
  const kv = fakeKv();
  const first = await loadWorker();
  await first.fetch(get(), env({ TOKEN_CACHE: kv }));
  assert.equal(twitchCalls.length, 1);
  const stored = kv.store.get('twitch_app_token');
  assert.ok(stored);
  // Kept until the refresh point, no longer.
  assert.equal(stored.options.expirationTtl, 5_000_000 - 600);
  assert.ok(!stored.value.includes(SECRET));

  const second = await loadWorker();
  const response = await second.fetch(get(), env({ TOKEN_CACHE: kv }));
  assert.equal((await response.json()).access_token, TOKEN);
  assert.equal(twitchCalls.length, 1);
});

test('a KV token made with another secret is not served', async () => {
  const kv = fakeKv();
  const first = await loadWorker();
  await first.fetch(get(), env({ TOKEN_CACHE: kv }));
  assert.equal(twitchCalls.length, 1);

  // The secret was replaced: new isolates must not reuse the old token.
  twitchAnswer = () =>
    new Response(JSON.stringify({ access_token: TOKEN_2, expires_in: 5_000_000 }), { status: 200 });
  const second = await loadWorker();
  const response = await second.fetch(
    get(),
    env({ TOKEN_CACHE: kv, TWITCH_CLIENT_SECRET: 'the-new-secret-0123456789' }),
  );
  assert.equal((await response.json()).access_token, TOKEN_2);
  assert.equal(twitchCalls.length, 2);
  assert.ok(!kv.store.get('twitch_app_token').value.includes('the-new-secret'));
});

test('a broken KV value is ignored', async () => {
  const kv = fakeKv();
  kv.store.set('twitch_app_token', { value: JSON.stringify({ token: 'x y', expiresAt: now * 2 }) });
  const worker = await loadWorker();
  const response = await worker.fetch(get(), env({ TOKEN_CACHE: kv }));
  assert.equal((await response.json()).access_token, TOKEN);
  assert.equal(twitchCalls.length, 1);
});

for (const [name, answer] of [
  ['an error status', () => new Response(JSON.stringify({ status: 403, message: `invalid client secret ${SECRET}` }), { status: 403 })],
  ['a page instead of JSON', () => new Response('<html>oops</html>', { status: 200 })],
  ['no token', () => new Response(JSON.stringify({ expires_in: 100 }), { status: 200 })],
  ['no expiry', () => new Response(JSON.stringify({ access_token: TOKEN }), { status: 200 })],
  ['an odd token', () => new Response(JSON.stringify({ access_token: 'a b\r\nc', expires_in: 5_000_000 }), { status: 200 })],
  ['a token about to expire', () => new Response(JSON.stringify({ access_token: TOKEN, expires_in: 60 }), { status: 200 })],
  ['a network failure', () => { throw new TypeError('network down'); }],
]) {
  test(`Twitch answering with ${name} is a generic 502`, async () => {
    twitchAnswer = answer;
    const worker = await loadWorker();
    const response = await worker.fetch(get(), env());

    assert.equal(response.status, 502);
    const text = await response.text();
    assert.deepEqual(JSON.parse(text), { error: 'unavailable' });
    assert.ok(!text.includes(SECRET));
    assert.ok(!text.includes('the_client_id'));
    assert.ok(logged.every((line) => !line.includes(SECRET)), logged.join('\n'));
  });
}

test('a Twitch that hangs is given up on', async () => {
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

test('missing secrets: 502, Twitch not asked, nothing leaked', async () => {
  const worker = await loadWorker();
  const response = await worker.fetch(get(), { TWITCH_CLIENT_ID: 'the_client_id' });
  assert.equal(response.status, 502);
  assert.equal(twitchCalls.length, 0);
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
  assert.equal(twitchCalls.length, 0);
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
  now += 60 * 1000;
  assert.equal((await worker.fetch(get(), env())).status, 200);
});

test('the rate limiting binding decides when there is one', async () => {
  const keys = [];
  const limiter = {
    async limit({ key }) {
      keys.push(key);
      return { success: keys.length <= 2 };
    },
  };
  const worker = await loadWorker();
  assert.equal((await worker.fetch(get(), env({ RATE_LIMITER: limiter }))).status, 200);
  assert.equal((await worker.fetch(get(), env({ RATE_LIMITER: limiter }))).status, 200);
  assert.equal((await worker.fetch(get(), env({ RATE_LIMITER: limiter }))).status, 429);
  assert.deepEqual(keys, ['203.0.113.7', '203.0.113.7', '203.0.113.7']);
});

test('a rate limited request never reaches Twitch', async () => {
  const limiter = { limit: async () => ({ success: false }) };
  const worker = await loadWorker();
  const response = await worker.fetch(get(), env({ RATE_LIMITER: limiter }));
  assert.equal(response.status, 429);
  assert.equal(twitchCalls.length, 0);
});
