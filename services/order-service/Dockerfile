# Same distroless pattern as user-service for consistency.
# All 3 Node.js services use identical Dockerfile structure so Trivy scans
# and Binary Authorization attestations apply to the same base image.

FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production --ignore-scripts

FROM gcr.io/distroless/nodejs20-debian12
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY src/ ./src/
COPY package.json ./
USER nonroot
EXPOSE 3001
ENV NODE_ENV=production
CMD ["src/index.js"]
