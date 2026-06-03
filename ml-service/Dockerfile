FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    HF_HOME=/app/data/hf-cache \
    TRANSFORMERS_CACHE=/app/data/hf-cache \
    SENTENCE_TRANSFORMERS_HOME=/app/data/hf-cache

WORKDIR /app

# System deps for faiss-cpu + torch wheels (libgomp).
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        curl \
        libgomp1 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt /app/requirements.txt
RUN pip install --upgrade pip \
    && pip install -r requirements.txt

COPY app /app/app
COPY scripts /app/scripts

RUN mkdir -p /app/data

# Informational only. On Zoho Catalyst AppSail the real port is injected at
# runtime via X_ZOHO_CATALYST_LISTEN_PORT (see CMD below).
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -fsS "http://localhost:${X_ZOHO_CATALYST_LISTEN_PORT:-8000}/health" || exit 1

# Bind uvicorn to the AppSail-provided port when present, else default to 8000
# for local docker-compose. Shell form so the env var is interpolated.
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${X_ZOHO_CATALYST_LISTEN_PORT:-8000} --workers 1"]
