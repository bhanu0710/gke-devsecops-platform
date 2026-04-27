# ── Stage 1: Install dependencies ────────────────────────────────────────────
FROM python:3.12-slim AS builder
WORKDIR /app

COPY requirements.txt .
# Install to /app/packages so the non-root user can read them
RUN pip install --no-cache-dir --target /app/packages -r requirements.txt

# ── Stage 2: Lean runtime image ───────────────────────────────────────────────
FROM python:3.12-slim

WORKDIR /app

COPY --from=builder /app/packages /app/packages
COPY src/ ./src/

# UID 1001 — must be numeric for Kubernetes runAsNonRoot verification
RUN useradd -r -u 1001 -g root appuser && chown -R appuser /app
USER appuser

EXPOSE 8000

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONPATH=/app/packages

CMD ["python", "-m", "uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]
