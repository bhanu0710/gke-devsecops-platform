'use strict';
const { v4: uuidv4 } = require('uuid');

const orders = new Map();

function createOrder({ userId, productId, quantity, price }) {
  if (!userId || !productId || !quantity) {
    throw Object.assign(new Error('userId, productId, and quantity are required'), { status: 400 });
  }
  const id = uuidv4();
  const order = {
    id,
    userId,
    productId,
    quantity,
    price: price || 0,
    total: (price || 0) * quantity,
    status: 'pending',
    createdAt: new Date().toISOString(),
  };
  orders.set(id, order);
  return order;
}

function getOrder(id) {
  const order = orders.get(id);
  if (!order) throw Object.assign(new Error('Order not found'), { status: 404 });
  return order;
}

function getOrdersByUser(userId) {
  return [...orders.values()].filter(o => o.userId === userId);
}

function updateOrderStatus(id, newStatus) {
  const order = orders.get(id);
  if (!order) throw Object.assign(new Error('Order not found'), { status: 404 });
  order.status = newStatus;
  order.updatedAt = new Date().toISOString();
  orders.set(id, order);
  return order;
}

function reset() { orders.clear(); }

module.exports = { createOrder, getOrder, getOrdersByUser, updateOrderStatus, reset };
