# ── Stage 1: Build venv with all dependencies ─────────────────────────────────
FROM python:3.12-slim AS builder
WORKDIR /app

# Create an isolated venv — guarantees setuptools/pkg_resources are present.
# pip install --target skips the pkg_resources bootstrap, so we use venv instead.
RUN python -m venv /app/venv
COPY requirements.txt .
RUN /app/venv/bin/pip install --no-cache-dir -r requirements.txt

# ── Stage 2: Lean runtime image ───────────────────────────────────────────────
FROM python:3.12-slim

WORKDIR /app

# Copy the fully-baked venv (includes pkg_resources, setuptools, all deps)
COPY --from=builder /app/venv /app/venv
COPY src/ ./src/

# UID 1001 — must be numeric for Kubernetes runAsNonRoot verification
RUN useradd -r -u 1001 -g root appuser && chown -R appuser /app /app/venv
USER appuser

EXPOSE 8000

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Use the venv's uvicorn directly — avoids PATH/symlink venv-detection issues
CMD ["/app/venv/bin/uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]
