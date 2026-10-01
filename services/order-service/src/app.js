// Order service: places orders, reserves stock via product-service, stores orders in Redis.
const express = require('express');
const client = require('prom-client');

function buildApp({ redis, productUrl, fetchImpl = fetch }) {
  const app = express();
  app.use(express.json());

  const register = new client.Registry();
  client.collectDefaultMetrics({ register });
  const requests = new client.Counter({
    name: 'http_requests_total',
    help: 'Total HTTP requests',
    labelNames: ['service', 'method', 'path', 'status'],
    registers: [register],
  });
  const latency = new client.Histogram({
    name: 'http_request_duration_seconds',
    help: 'Request latency',
    labelNames: ['service', 'method', 'path'],
    registers: [register],
  });
  const ordersPlaced = new client.Counter({
    name: 'orders_placed_total',
    help: 'Orders successfully placed',
    registers: [register],
  });

  app.use((req, res, next) => {
    const end = latency.startTimer();
    res.on('finish', () => {
      const path = req.route ? req.baseUrl + req.route.path : 'unmatched';
      if (path === '/metrics') return;
      end({ service: 'order-service', method: req.method, path });
      requests.inc({ service: 'order-service', method: req.method, path, status: res.statusCode });
    });
    next();
  });

  app.get('/healthz', (_req, res) => res.json({ status: 'ok' }));

  app.get('/readyz', async (_req, res) => {
    try {
      await redis.ping();
      res.json({ status: 'ready' });
    } catch {
      res.status(503).json({ error: 'redis unavailable' });
    }
  });

  app.get('/metrics', async (_req, res) => {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
  });

  app.get('/api/orders', async (_req, res) => {
    const raw = await redis.lRange('orders', 0, 49);
    res.json(raw.map((o) => JSON.parse(o)));
  });

  app.post('/api/orders', async (req, res) => {
    const { productId, qty = 1 } = req.body || {};
    if (!Number.isInteger(productId) || !Number.isInteger(qty) || qty < 1) {
      return res.status(400).json({ error: 'productId and qty must be positive integers' });
    }
    let r;
    try {
      r = await fetchImpl(`${productUrl}/api/products/${productId}/reserve?qty=${qty}`, { method: 'POST' });
    } catch {
      return res.status(502).json({ error: 'product-service unreachable' });
    }
    if (r.status === 404) return res.status(404).json({ error: 'product not found' });
    if (r.status === 409) return res.status(409).json({ error: 'insufficient stock' });
    if (!r.ok) return res.status(502).json({ error: 'product-service error' });

    const product = await r.json();
    const id = await redis.incr('order:id');
    const order = {
      id,
      productId,
      productName: product.name,
      qty,
      total: +(product.price * qty).toFixed(2),
      createdAt: new Date().toISOString(),
    };
    await redis.lPush('orders', JSON.stringify(order));
    ordersPlaced.inc();
    res.status(201).json(order);
  });

  return app;
}

module.exports = { buildApp };
