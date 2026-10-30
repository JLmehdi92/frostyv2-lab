// Run with: node --test   (from tool/token_proxy/)
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { cleanup } from './eventsub-cleanup.js';

const CLIENT = 'loginappclientid0123456789abc';
const SECRET = 'the-new-main-secret-0123456789';
const TOKEN = 'cleanuptoken0123456789abcdefgh';

function fakeTwitch({ pages = [[]], conduits = [], mintStatus = 200 } = {}) {
  const calls = [];
  const fetch = async (url, init = {}) => {
    const u = new URL(String(url));
    calls.push({ url: u, init, method: init.method || 'GET' });
    const reply = (status, body) =>
      new Response(body === undefined ? null : JSON.stringify(body), { status });
    if (u.href === 'https://id.twitch.tv/oauth2/token') {
      return mintStatus === 200
        ? reply(200, { access_token: TOKEN, expires_in: 5000000, token_type: 'bearer' })
        : reply(mintStatus, { message: 'invalid client secret' });
    }
    if (u.href === 'https://id.twitch.tv/oauth2/revoke') return reply(200);
    if (u.pathname === '/helix/eventsub/subscriptions') {
      if ((init.method || 'GET') === 'DELETE') return reply(204);
      const page = Number(u.searchParams.get('after') || 0);
      return reply(200, {
        data: pages[page],
        pagination: page + 1 < pages.length ? { cursor: String(page + 1) } : {},
        total: pages.flat().length,
      });
    }
    if (u.pathname === '/helix/eventsub/conduits') {
      if ((init.method || 'GET') === 'DELETE') return reply(204);
      return reply(200, { data: conduits });
    }
    return reply(404, { message: 'not found' });
  };
  return { fetch, calls };
}

const sub = (id, type = 'user.whisper.message') => ({
  id,
  status: 'enabled',
  type,
  version: '1',
  condition: { user_id: '12345' },
  transport: { method: 'webhook', callback: `https://attacker.example/hook/${id}` },
});

const run = async (twitch, answer) => {
  const lines = [];
  const asked = [];
  const result = await cleanup({
    clientId: CLIENT,
    clientSecret: SECRET,
    fetch: twitch.fetch,
    log: (line) => lines.push(line),
    confirm: async (count) => {
      asked.push(count);
      return answer;
    },
  });
  return { result, lines, asked };
};

test('lists every page of subscriptions and the conduits, then deletes them when confirmed', async () => {
  const twitch = fakeTwitch({
    pages: [[sub('a'), sub('b')], [sub('c', 'channel.chat.message')]],
    conduits: [{ id: 'conduit-1', shard_count: 1 }],
  });
  const { result, lines, asked } = await run(twitch, true);

  assert.deepEqual(asked, [4]);
  assert.equal(result.deleted, 4);
  const deletes = twitch.calls.filter((c) => c.method === 'DELETE');
  assert.deepEqual(
    deletes.map((c) => `${c.url.pathname}?${c.url.searchParams}`),
    [
      '/helix/eventsub/subscriptions?id=a',
      '/helix/eventsub/subscriptions?id=b',
      '/helix/eventsub/subscriptions?id=c',
      '/helix/eventsub/conduits?id=conduit-1',
    ],
  );
  // Each Helix call carries the token and the client id.
  for (const call of twitch.calls.filter((c) => c.url.host === 'api.twitch.tv')) {
    const headers = new Headers(call.init.headers);
    assert.equal(headers.get('Authorization'), `Bearer ${TOKEN}`);
    assert.equal(headers.get('Client-Id'), CLIENT);
  }
  assert.ok(lines.some((l) => l.includes('user.whisper.message') && l.includes('attacker.example')));
});

test('deletes nothing unless confirmed', async () => {
  const twitch = fakeTwitch({ pages: [[sub('a')]] });
  const { result } = await run(twitch, false);

  assert.equal(result.deleted, 0);
  assert.equal(twitch.calls.filter((c) => c.method === 'DELETE').length, 0);
});

test('with nothing to delete, does not ask', async () => {
  const twitch = fakeTwitch();
  const { result, asked, lines } = await run(twitch, true);

  assert.deepEqual(asked, []);
  assert.equal(result.deleted, 0);
  assert.ok(lines.some((l) => /nothing/i.test(l)));
});

test('the token it made is revoked at the end, whatever happened', async () => {
  for (const answer of [true, false]) {
    const twitch = fakeTwitch({ pages: [[sub('a')]] });
    await run(twitch, answer);
    const revoke = twitch.calls.at(-1);
    assert.equal(revoke.url.href, 'https://id.twitch.tv/oauth2/revoke');
    const body = new URLSearchParams(revoke.init.body);
    assert.equal(body.get('token'), TOKEN);
    assert.equal(body.get('client_id'), CLIENT);
  }
});

test('the secret only goes to the token endpoint, in the body, and is never printed', async () => {
  const twitch = fakeTwitch({ pages: [[sub('a')]] });
  const { lines } = await run(twitch, true);

  for (const call of twitch.calls) {
    const sent = `${call.url} ${JSON.stringify(call.init.headers || {})}`;
    assert.ok(!sent.includes(SECRET), sent);
    if (call.url.href !== 'https://id.twitch.tv/oauth2/token') {
      assert.ok(!String(call.init.body || '').includes(SECRET));
    }
  }
  assert.ok(lines.every((l) => !l.includes(SECRET) && !l.includes(TOKEN)), lines.join('\n'));
});

test('a refused secret stops with a plain message and calls nothing else', async () => {
  const twitch = fakeTwitch({ mintStatus: 403 });
  await assert.rejects(
    run(twitch, true),
    (error) => /client id or secret/i.test(error.message) && !error.message.includes(SECRET),
  );
  assert.equal(twitch.calls.length, 1);
});

test('refuses a client id that does not look like one, before any call', async () => {
  const twitch = fakeTwitch();
  await assert.rejects(
    cleanup({ clientId: 'not a client id', clientSecret: SECRET, fetch: twitch.fetch, log() {}, confirm: async () => true }),
  );
  assert.equal(twitch.calls.length, 0);
});
