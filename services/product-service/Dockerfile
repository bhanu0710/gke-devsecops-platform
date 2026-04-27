# Multi-stage build for product-service.
# Installing with --user in the builder stage lets us copy only the installed
# packages to the final image without pip or the build toolchain.

# ── Stage 1: Install dependencies ────────────────────────────────────────────
FROM python:3.12-slim AS builder
WORKDIR /app

COPY requirements.txt .
# --user installs to /root/.local so we can COPY just that dir to the final stage
RUN pip install --user --no-cache-dir -r requirements.txt

# ── Stage 2: Lean runtime image ───────────────────────────────────────────────
FROM python:3.12-slim

WORKDIR /app

# Copy only installed packages — not pip, setuptools, or build tools
COPY --from=builder /root/.local /root/.local
COPY src/ ./src/

# Create a non-root user — required by OPA K8sNoRootContainers policy
RUN useradd -r -u 1001 -g root appuser
USER appuser

EXPOSE 8000

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH=/root/.local/bin:$PATH \
    NODE_ENV=production

CMD ["python", "-m", "uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]
