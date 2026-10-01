const { createClient } = require('redis');
const { buildApp } = require('./app');

const PORT = process.env.PORT || 3000;
const redis = createClient({ url: process.env.REDIS_URL || 'redis://localhost:6379' });
redis.on('error', (err) => console.error('redis error', err.message));

(async () => {
  await redis.connect();
  const app = buildApp({
    redis,
    productUrl: process.env.PRODUCT_SERVICE_URL || 'http://localhost:8000',
  });
  const server = app.listen(PORT, () => console.log(`order-service listening on ${PORT}`));

  // Graceful shutdown so Kubernetes rolling updates don't drop requests
  process.on('SIGTERM', () => {
    server.close(async () => {
      await redis.quit();
      process.exit(0);
    });
  });
})();
