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

  it('returns 200 with order after creation', async () => {
    nock(USER_URL).get('/users/u1').reply(200, { id: 'u1' });
    nock(PRODUCT_URL).get('/products/p1').reply(200, { id: 'p1', price: 10.0 });

    const create = await request(app)
      .post('/orders')
      .send({ userId: 'u1', productId: 'p1', quantity: 1 });
    expect(create.status).toBe(201);

    const res = await request(app).get(`/orders/${create.body.id}`);
    expect(res.status).toBe(200);
    expect(res.body.id).toBe(create.body.id);
  });
});

describe('PATCH /orders/:id/status', () => {
  it('updates order status', async () => {
    nock(USER_URL).get('/users/u2').reply(200, { id: 'u2' });
    nock(PRODUCT_URL).get('/products/p2').reply(200, { id: 'p2', price: 20.0 });

    const create = await request(app)
      .post('/orders')
      .send({ userId: 'u2', productId: 'p2', quantity: 3 });
    expect(create.status).toBe(201);

    const res = await request(app)
      .patch(`/orders/${create.body.id}/status`)
      .send({ status: 'shipped' });
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('shipped');
  });

  it('returns 404 when patching missing order', async () => {
    const res = await request(app)
      .patch('/orders/ghost-order/status')
      .send({ status: 'shipped' });
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
