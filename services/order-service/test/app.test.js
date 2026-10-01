const { test } = require('node:test');
const assert = require('node:assert');
const { buildApp } = require('../src/app');

// In-memory fake of the few Redis commands we use
function fakeRedis() {
  const lists = {};
  const counters = {};
  return {
    ping: async () => 'PONG',
    incr: async (k) => (counters[k] = (counters[k] || 0) + 1),
    lPush: async (k, v) => (lists[k] = [v, ...(lists[k] || [])]).length,
    lRange: async (k, s, e) => (lists[k] || []).slice(s, e + 1),
  };
}

function fakeFetch(status, body) {
  return async () => ({ status, ok: status < 400, json: async () => body });
}

async function withServer(app, fn) {
  const server = app.listen(0);
  const base = `http://127.0.0.1:${server.address().port}`;
  try {
    await fn(base);
  } finally {
    server.close();
  }
}

test('places an order and lists it', async () => {
  const app = buildApp({
    redis: fakeRedis(),
    productUrl: 'http://x',
    fetchImpl: fakeFetch(200, { id: 1, name: 'Sensor', price: 10.5 }),
  });
  await withServer(app, async (base) => {
    const r = await fetch(`${base}/api/orders`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ productId: 1, qty: 2 }),
    });
    assert.strictEqual(r.status, 201);
    assert.strictEqual((await r.json()).total, 21);
    const list = await (await fetch(`${base}/api/orders`)).json();
    assert.strictEqual(list.length, 1);
  });
});

test('rejects bad input and propagates out-of-stock', async () => {
  const app = buildApp({ redis: fakeRedis(), productUrl: 'http://x', fetchImpl: fakeFetch(409, {}) });
  await withServer(app, async (base) => {
    const post = (b) =>
      fetch(`${base}/api/orders`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(b) });
    assert.strictEqual((await post({ productId: 'a' })).status, 400);
    assert.strictEqual((await post({ productId: 1 })).status, 409);
  });
});

test('exposes metrics and health', async () => {
  const app = buildApp({ redis: fakeRedis(), productUrl: 'http://x' });
  await withServer(app, async (base) => {
    assert.strictEqual((await fetch(`${base}/readyz`)).status, 200);
    const m = await (await fetch(`${base}/metrics`)).text();
    assert.match(m, /orders_placed_total/);
  });
});
