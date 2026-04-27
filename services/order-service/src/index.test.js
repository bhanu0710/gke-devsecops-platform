'use strict';
jest.mock('./tracing', () => {});

const request = require('supertest');
const nock = require('nock');
const app = require('./index');
const store = require('./store');

const USER_URL = 'http://user-service.staging.svc.cluster.local:3000';
const PRODUCT_URL = 'http://product-service.staging.svc.cluster.local:8000';

beforeEach(() => {
  store.reset();
  nock.cleanAll();
});

afterAll(() => nock.restore());

describe('GET /health', () => {
  it('returns 200', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.service).toBe('order-service');
  });
});

describe('POST /orders', () => {
  it('creates order when user and product exist', async () => {
    nock(USER_URL).get('/users/user-1').reply(200, { id: 'user-1', name: 'Bhanu' });
    nock(PRODUCT_URL).get('/products/prod-1').reply(200, { id: 'prod-1', price: 50.0 });

    const res = await request(app)
      .post('/orders')
      .send({ userId: 'user-1', productId: 'prod-1', quantity: 2 });

    expect(res.status).toBe(201);
    expect(res.body.total).toBe(100.0);
    expect(res.body.status).toBe('pending');
  });

  it('returns 404 when user not found', async () => {
    nock(USER_URL).get('/users/bad-user').reply(404, { error: 'Not found' });

    const res = await request(app)
      .post('/orders')
      .send({ userId: 'bad-user', productId: 'prod-1', quantity: 1 });

    expect(res.status).toBe(404);
  });

  it('returns 400 when required fields missing', async () => {
    const res = await request(app).post('/orders').send({ userId: 'u1' });
    expect(res.status).toBe(400);
  });
});

describe('GET /orders/:id', () => {
  it('returns 404 for missing order', async () => {
    const res = await request(app).get('/orders/no-such-order');
    expect(res.status).toBe(404);
  });
});

describe('GET /orders/user/:userId', () => {
  it('returns empty array when user has no orders', async () => {
    const res = await request(app).get('/orders/user/nobody');
    expect(res.status).toBe(200);
    expect(res.body).toEqual([]);
  });
});

describe('GET /metrics', () => {
  it('exposes prometheus metrics', async () => {
    const res = await request(app).get('/metrics');
    expect(res.status).toBe(200);
    expect(res.text).toContain('http_requests_total');
  });
});
