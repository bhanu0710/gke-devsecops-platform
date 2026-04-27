'use strict';
// In-memory store backed by a Map — avoids a DB dependency for the demo while
// still providing realistic create/read/update/delete semantics.
// In production this would be replaced by a Cloud SQL or Firestore client.
const { v4: uuidv4 } = require('uuid');
const bcrypt = require('bcryptjs');

const users = new Map();

function createUser({ name, email, password }) {
  if (!name || !email || !password) {
    throw Object.assign(new Error('name, email, and password are required'), { status: 400 });
  }
  // Check duplicate email
  for (const u of users.values()) {
    if (u.email === email) {
      throw Object.assign(new Error('Email already registered'), { status: 409 });
    }
  }
  const id = uuidv4();
  const passwordHash = bcrypt.hashSync(password, 10);
  const user = { id, name, email, passwordHash, createdAt: new Date().toISOString() };
  users.set(id, user);
  return sanitize(user);
}

function getUser(id) {
  const user = users.get(id);
  if (!user) throw Object.assign(new Error('User not found'), { status: 404 });
  return sanitize(user);
}

function updateUser(id, { name, email }) {
  const user = users.get(id);
  if (!user) throw Object.assign(new Error('User not found'), { status: 404 });
  if (name) user.name = name;
  if (email) user.email = email;
  user.updatedAt = new Date().toISOString();
  users.set(id, user);
  return sanitize(user);
}

function deleteUser(id) {
  if (!users.has(id)) throw Object.assign(new Error('User not found'), { status: 404 });
  users.delete(id);
}

function authenticateUser(email, password) {
  for (const user of users.values()) {
    if (user.email === email && bcrypt.compareSync(password, user.passwordHash)) {
      return sanitize(user);
    }
  }
  throw Object.assign(new Error('Invalid credentials'), { status: 401 });
}

// Never return passwordHash to callers
function sanitize({ passwordHash: _, ...rest }) {
  return rest;
}

// Expose for tests
function reset() { users.clear(); }

module.exports = { createUser, getUser, updateUser, deleteUser, authenticateUser, reset };
