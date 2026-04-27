'use strict';
// Entry point — load tracing before any other require so all HTTP spans are captured
require('./tracing');

const express = require('express');
const jwt = require('jsonwebtoken');
const { register, metricsMiddleware } = require('./metrics');
const store = require('./store');

const app = express();
const PORT = process.env.PORT || 3000;
const VERSION = process.env.VERSION || '1.0.0';
const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret-change-in-prod';

app.use(express.json());
app.use(metricsMiddleware);

// ── Health / readiness ────────────────────────────────────────────────────────
// Liveness probe: Kubernetes kills and restarts the pod if this returns non-200.
// Readiness probe: Kubernetes removes the pod from Service endpoints until ready.
// Keeping them separate lets us drain traffic without killing the process.
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'user-service', version: VERSION });
});

app.get('/ready', (req, res) => {
  res.json({ status: 'ready' });
});

// ── Prometheus metrics ────────────────────────────────────────────────────────
// Scraped by Prometheus via ServiceMonitor; path must match prometheus.io/path annotation
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// ── Auth ──────────────────────────────────────────────────────────────────────
app.post('/auth/login', (req, res, next) => {
  try {
    const { email, password } = req.body;
    const user = store.authenticateUser(email, password);
    // Token expires in 24h — balance between security and UX for demo purposes
    const token = jwt.sign({ sub: user.id, email: user.email }, JWT_SECRET, { expiresIn: '24h' });
    res.json({ token, user });
  } catch (err) {
    next(err);
  }
});

// ── JWT middleware ────────────────────────────────────────────────────────────
function authenticate(req, res, next) {
  const auth = req.headers.authorization;
  if (!auth || !auth.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing or invalid Authorization header' });
  }
  try {
    req.user = jwt.verify(auth.slice(7), JWT_SECRET);
    next();
  } catch {
    res.status(401).json({ error: 'Token invalid or expired' });
  }
}

// ── User CRUD ─────────────────────────────────────────────────────────────────
app.post('/users', (req, res, next) => {
  try {
    const user = store.createUser(req.body);
    res.status(201).json(user);
  } catch (err) { next(err); }
});

app.get('/users/:id', authenticate, (req, res, next) => {
  try {
    res.json(store.getUser(req.params.id));
  } catch (err) { next(err); }
});

app.put('/users/:id', authenticate, (req, res, next) => {
  try {
    res.json(store.updateUser(req.params.id, req.body));
  } catch (err) { next(err); }
});

app.delete('/users/:id', authenticate, (req, res, next) => {
  try {
    store.deleteUser(req.params.id);
    res.status(204).send();
  } catch (err) { next(err); }
});

// ── Global error handler ──────────────────────────────────────────────────────
// Centralised error handling prevents accidental stack-trace leakage to clients
app.use((err, req, res, _next) => {
  const status = err.status || 500;
  if (status >= 500) console.error(err);
  res.status(status).json({ error: err.message });
});

const server = app.listen(PORT, () => {
  console.log(`user-service v${VERSION} listening on :${PORT}`);
});

// Graceful shutdown — gives in-flight requests up to 10s to complete before exiting.
// Required for zero-downtime rolling updates in Kubernetes.
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully...');
  server.close(() => process.exit(0));
});

module.exports = app; // exported for supertest
