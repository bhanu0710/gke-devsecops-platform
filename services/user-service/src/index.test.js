'use strict';
const request = require('supertest');

// Stub tracing before requiring app to avoid gRPC connection errors in test
jest.mock('./tracing', () => {});

const app = require('./index');
const store = require('./store');

beforeEach(() => store.reset());

describe('GET /health', () => {
  it('returns 200 with service name', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.service).toBe('user-service');
    expect(res.body.status).toBe('ok');
  });
});

describe('POST /users', () => {
  it('creates a user and returns 201', async () => {
    const res = await request(app)
      .post('/users')
      .send({ name: 'Bhanu', email: 'bhanu@example.com', password: 'secret123' });
    expect(res.status).toBe(201);
    expect(res.body.id).toBeDefined();
    expect(res.body.email).toBe('bhanu@example.com');
    expect(res.body.passwordHash).toBeUndefined(); // must never be returned
  });

  it('returns 400 when required fields are missing', async () => {
    const res = await request(app).post('/users').send({ name: 'NoEmail' });
    expect(res.status).toBe(400);
  });

  it('returns 409 on duplicate email', async () => {
    const payload = { name: 'Bhanu', email: 'dup@example.com', password: 'pass' };
    await request(app).post('/users').send(payload);
    const res = await request(app).post('/users').send(payload);
    expect(res.status).toBe(409);
  });
});

describe('POST /auth/login', () => {
  it('returns JWT token on valid credentials', async () => {
    await request(app)
      .post('/users')
      .send({ name: 'Login User', email: 'login@example.com', password: 'mypassword' });

    const res = await request(app)
      .post('/auth/login')
      .send({ email: 'login@example.com', password: 'mypassword' });
    expect(res.status).toBe(200);
    expect(res.body.token).toBeDefined();
  });

  it('returns 401 on wrong password', async () => {
    await request(app)
      .post('/users')
      .send({ name: 'User', email: 'wrong@example.com', password: 'correct' });
    const res = await request(app)
      .post('/auth/login')
      .send({ email: 'wrong@example.com', password: 'incorrect' });
    expect(res.status).toBe(401);
  });
});

describe('GET /users/:id (authenticated)', () => {
  it('returns user when authenticated', async () => {
    // Create + login to get token
    await request(app)
      .post('/users')
      .send({ name: 'Auth Test', email: 'auth@example.com', password: 'pass123' });
    const loginRes = await request(app)
      .post('/auth/login')
      .send({ email: 'auth@example.com', password: 'pass123' });
    const { token, user } = loginRes.body;

    const res = await request(app)
      .get(`/users/${user.id}`)
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.body.id).toBe(user.id);
  });

  it('returns 401 without token', async () => {
    const res = await request(app).get('/users/some-id');
    expect(res.status).toBe(401);
  });
});

describe('GET /metrics', () => {
  it('returns prometheus format', async () => {
    const res = await request(app).get('/metrics');
    expect(res.status).toBe(200);
    expect(res.text).toContain('http_requests_total');
  });
});
