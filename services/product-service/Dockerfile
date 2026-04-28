# ── Stage 1: Build venv with all dependencies ─────────────────────────────────
FROM python:3.12-slim AS builder
WORKDIR /app

# Create an isolated venv — guarantees pkg_resources, setuptools, etc. are
# fully installed (pip install --target skips pkg_resources bootstrap).
RUN python -m venv /app/venv
COPY requirements.txt .
RUN /app/venv/bin/pip install --no-cache-dir -r requirements.txt

# ── Stage 2: Lean runtime image ───────────────────────────────────────────────
FROM python:3.12-slim

WORKDIR /app

# Copy the fully-baked venv, not bare package files
COPY --from=builder /app/venv /app/venv
COPY src/ ./src/

# UID 1001 — must be numeric for Kubernetes runAsNonRoot verification
RUN useradd -r -u 1001 -g root appuser && chown -R appuser /app /app/venv
USER appuser

EXPOSE 8000

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/app/venv/bin:$PATH"

CMD ["python", "-m", "uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]
