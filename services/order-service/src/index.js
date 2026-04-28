'use strict';
require('./tracing');

const express = require('express');
const { register, metricsMiddleware } = require('./metrics');
const store = require('./store');

const app = express();
const PORT = process.env.PORT || 3001;
const VERSION = process.env.VERSION || '1.0.0';

// Service URLs — in Kubernetes these resolve via CoreDNS to ClusterIP services.
// Istio intercepts the outbound connections and enforces AuthorizationPolicy.
const USER_SERVICE_URL = process.env.USER_SERVICE_URL || 'http://user-service.staging.svc.cluster.local:3000';
const PRODUCT_SERVICE_URL = process.env.PRODUCT_SERVICE_URL || 'http://product-service.staging.svc.cluster.local:8000';

app.use(express.json());
app.use(metricsMiddleware);

// ── Downstream service client ─────────────────────────────────────────────────
// node-fetch is used instead of axios to keep dependencies minimal.
// The fetch call propagates the traceparent header (injected by OTel auto-instrumentation)
// so the entire request chain appears as one trace in Grafana Tempo.
// node-fetch v2 (CommonJS) is used so Jest/nock work without --experimental-vm-modules.
const fetch = require('node-fetch');

async function fetchService(url, options = {}) {
  const res = await fetch(url, { timeout: 5000, ...options });
  if (!res.ok) {
    const body = await res.text();
    throw Object.assign(new Error(`Upstream error: ${body}`), { status: res.status });
  }
  return res.json();
}

// ── Health ────────────────────────────────────────────────────────────────────
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'order-service', version: VERSION });
});

app.get('/ready', (req, res) => res.json({ status: 'ready' }));

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// ── Orders ────────────────────────────────────────────────────────────────────
app.post('/orders', async (req, res, next) => {
  try {
    const { userId, productId, quantity } = req.body;

    // Validate required fields before making any upstream calls
    if (!userId || !productId || !quantity) {
      return res.status(400).json({ error: 'userId, productId, and quantity are required' });
    }

    // Validate user exists — demonstrates cross-service call through Istio mesh
    await fetchService(`${USER_SERVICE_URL}/users/${userId}`, {
      headers: { Authorization: req.headers.authorization || '' },
    });

    // Validate product exists and get current price
    const product = await fetchService(`${PRODUCT_SERVICE_URL}/products/${productId}`);

    const order = store.createOrder({
      userId,
      productId,
      quantity,
      price: product.price,
    });
    res.status(201).json(order);
  } catch (err) { next(err); }
});

app.get('/orders/:id', (req, res, next) => {
  try {
    res.json(store.getOrder(req.params.id));
  } catch (err) { next(err); }
});

app.get('/orders/user/:userId', (req, res) => {
  res.json(store.getOrdersByUser(req.params.userId));
});

app.patch('/orders/:id/status', (req, res, next) => {
  try {
    res.json(store.updateOrderStatus(req.params.id, req.body.status));
  } catch (err) { next(err); }
});

app.use((err, req, res, _next) => {
  const status = err.status || 500;
  if (status >= 500) console.error(err);
  res.status(status).json({ error: err.message });
});

const server = app.listen(PORT, () => {
  console.log(`order-service v${VERSION} listening on :${PORT}`);
});

process.on('SIGTERM', () => {
  server.close(() => process.exit(0));
});

module.exports = app;
