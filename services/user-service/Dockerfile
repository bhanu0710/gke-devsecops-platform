# Multi-stage build: stage 1 installs deps, stage 2 is distroless.
# Distroless has no shell, no package manager, no OS utilities — drastically
# reduces the attack surface vs. a full Alpine or Debian image.
# Trivy scan on distroless images typically returns 0 HIGH/CRITICAL CVEs.

# ── Stage 1: Install production dependencies ──────────────────────────────────
FROM node:20-alpine AS builder
WORKDIR /app

# Copy manifests first so Docker caches the npm install layer.
# Only invalidated when package.json changes, not on every source file edit.
COPY package*.json ./
RUN npm ci --only=production --ignore-scripts

# ── Stage 2: Distroless runtime ───────────────────────────────────────────────
FROM gcr.io/distroless/nodejs20-debian12

WORKDIR /app

# Copy only what's needed — no node_modules/.cache, no dev dependencies
COPY --from=builder /app/node_modules ./node_modules
COPY src/ ./src/
COPY package.json ./

# nonroot is UID 65532 in distroless — satisfies OPA 'no root containers' policy
USER nonroot

EXPOSE 3000

# NODE_ENV=production disables development-only error details in Express
ENV NODE_ENV=production

CMD ["src/index.js"]
