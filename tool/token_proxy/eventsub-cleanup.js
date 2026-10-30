// Lists, and on confirmation deletes, the EventSub webhook subscriptions and
// conduits of ONSET's LOGIN Twitch application.
//
// Why: anyone holding a client secret of the login application can mint app
// tokens of that application and create webhook subscriptions or conduits
// for the users who logged in with it (for example to receive their
// whispers). Replacing the secret stops new ones; it does not delete those
// already created. ONSET itself only uses websocket subscriptions, which
// this script never sees: everything it lists was made by someone else.
//
// Optional: only needed if a client secret of the login application may
// have been exposed (see README.md, "cleaning up EventSub subscriptions of
// the login application").
//
// Run it on your own computer (Node 18 or newer, nothing to install):
//
//   cd tool/token_proxy
//   node eventsub-cleanup.js
//
// It asks for the login application's client id and its NEW client secret
// (typed, not shown). The secret only goes to id.twitch.tv, to get a
// temporary token that the script revokes when it finishes. Nothing is
// saved, nothing is sent anywhere else, and nothing is deleted until you
// type DELETE.

import { createInterface } from 'node:readline';
import { pathToFileURL } from 'node:url';

const TOKEN_URL = 'https://id.twitch.tv/oauth2/token';
const REVOKE_URL = 'https://id.twitch.tv/oauth2/revoke';
const HELIX = 'https://api.twitch.tv/helix';
const CLIENT_ID_PATTERN = /^[A-Za-z0-9_-]{1,64}$/;

async function helix(fetchImpl, clientId, token, method, path) {
  const response = await fetchImpl(`${HELIX}${path}`, {
    method,
    headers: { Authorization: `Bearer ${token}`, 'Client-Id': clientId },
  });
  if (!response.ok) {
    throw new Error(`Twitch answered ${response.status} to ${method} ${path.split('?')[0]}`);
  }
  return response.status === 204 ? null : response.json();
}

function describe(sub) {
  const transport = sub.transport || {};
  const where =
    transport.method === 'webhook'
      ? `webhook to ${transport.callback}`
      : transport.method === 'conduit'
        ? `conduit ${transport.conduit_id}`
        : String(transport.method);
  return `  subscription ${sub.id}: ${sub.type} (${sub.status}), ${where}, condition ${JSON.stringify(sub.condition || {})}`;
}

/**
 * Lists the login application's EventSub subscriptions and conduits that an
 * app token can see, and deletes them all if `confirm(count)` says yes.
 * Returns { subscriptions, conduits, deleted }.
 */
export async function cleanup({ clientId, clientSecret, confirm, log, fetch: fetchImpl = globalThis.fetch }) {
  if (typeof clientId !== 'string' || !CLIENT_ID_PATTERN.test(clientId)) {
    throw new Error('That does not look like a Twitch client id.');
  }
  if (typeof clientSecret !== 'string' || clientSecret.length === 0) {
    throw new Error('The client secret is empty.');
  }

  const minted = await fetchImpl(TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      grant_type: 'client_credentials',
    }).toString(),
  });
  if (!minted.ok) {
    throw new Error(
      `Twitch refused the client id or secret (${minted.status}). Check you used the login application's id and its new secret.`,
    );
  }
  const token = (await minted.json()).access_token;
  if (typeof token !== 'string' || token.length === 0) {
    throw new Error('Twitch did not give a token.');
  }

  try {
    const subscriptions = [];
    let after = null;
    do {
      const page = await helix(
        fetchImpl,
        clientId,
        token,
        'GET',
        `/eventsub/subscriptions${after ? `?after=${encodeURIComponent(after)}` : ''}`,
      );
      subscriptions.push(...(page.data || []));
      after = page.pagination && page.pagination.cursor ? page.pagination.cursor : null;
    } while (after);
    const conduits = (await helix(fetchImpl, clientId, token, 'GET', '/eventsub/conduits')).data || [];

    const count = subscriptions.length + conduits.length;
    if (count === 0) {
      log('Nothing found: no webhook subscription and no conduit. Nothing to do.');
      return { subscriptions, conduits, deleted: 0 };
    }

    log(`Found ${subscriptions.length} subscription(s) and ${conduits.length} conduit(s). ONSET makes none of these:`);
    for (const sub of subscriptions) log(describe(sub));
    for (const conduit of conduits) log(`  conduit ${conduit.id} (${conduit.shard_count} shard(s))`);

    if (!(await confirm(count))) {
      log('Nothing deleted.');
      return { subscriptions, conduits, deleted: 0 };
    }

    let deleted = 0;
    for (const sub of subscriptions) {
      await helix(fetchImpl, clientId, token, 'DELETE', `/eventsub/subscriptions?id=${encodeURIComponent(sub.id)}`);
      deleted += 1;
    }
    for (const conduit of conduits) {
      await helix(fetchImpl, clientId, token, 'DELETE', `/eventsub/conduits?id=${encodeURIComponent(conduit.id)}`);
      deleted += 1;
    }
    log(`Deleted ${deleted}.`);
    return { subscriptions, conduits, deleted };
  } finally {
    // The temporary token is not needed any more.
    try {
      await fetchImpl(REVOKE_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ client_id: clientId, token }).toString(),
      });
    } catch {
      log('Could not revoke the temporary token; it expires on its own.');
    }
  }
}

// Input that ends (Ctrl+D, a closed pipe) answers "".
function ask(rl, question) {
  return new Promise((resolve) => {
    rl.once('close', () => resolve(''));
    rl.question(question, (answer) => resolve(answer.trim()));
  });
}

// Asks without showing what is typed.
function askHidden(rl, question) {
  return new Promise((resolve) => {
    rl.once('close', () => resolve(''));
    rl.output.write(question);
    // Readline echoes (and redraws) the line through this: nothing of it
    // reaches the screen until the answer is in.
    const write = rl._writeToOutput;
    rl._writeToOutput = () => {};
    rl.question('', (answer) => {
      rl._writeToOutput = write;
      rl.output.write('\n');
      resolve(answer.trim());
    });
  });
}

async function main() {
  const rl = createInterface({ input: process.stdin, output: process.stdout, terminal: Boolean(process.stdin.isTTY) });
  try {
    console.log('ONSET EventSub cleanup, for the LOGIN Twitch application (not "ONSET public").');
    const clientId = await ask(rl, 'Client ID of the login application: ');
    const clientSecret = await askHidden(rl, 'Its NEW client secret (not shown as you type): ');
    await cleanup({
      clientId,
      clientSecret,
      log: (line) => console.log(line),
      confirm: async (count) =>
        (await ask(rl, `Type DELETE to delete these ${count}, anything else to stop: `)) === 'DELETE',
    });
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  } finally {
    rl.close();
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main();
}
