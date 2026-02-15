# ------------------------------------------------------------
# Stage 1: Builder (Poetry + build deps)
# ------------------------------------------------------------
FROM python:3.11-bullseye AS builder

ENV POETRY_VERSION=1.8.3 \
    POETRY_NO_INTERACTION=1 \
    POETRY_VIRTUALENVS_IN_PROJECT=1 \
    POETRY_VIRTUALENVS_CREATE=1 \
    PIP_NO_CACHE_DIR=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git \
    libmagic1 \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Install Poetry
RUN curl -sSL https://install.python-poetry.org | python3 -
ENV PATH="/root/.local/bin:$PATH"

WORKDIR /app

# ---- GitHub token for private repo (rag-scraping) ----
ARG GITHUB_TOKEN
RUN if [ -n "$GITHUB_TOKEN" ]; then \
      git config --global url."https://x-access-token:${GITHUB_TOKEN}@github.com/".insteadOf "https://github.com/"; \
    fi

# Copy dependency files
COPY pyproject.toml poetry.lock ./

# Install dependencies only
RUN poetry install --no-root --without dev

# 🔐 Remove GitHub token from git config
RUN git config --global --unset-all url."https://x-access-token:${GITHUB_TOKEN}@github.com/".insteadOf || true

# ------------------------------------------------------------
# Stage 2: Runtime
# ------------------------------------------------------------
FROM python:3.11-slim AS runtime

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    # ---- Chrome runtime ----
    chromium \
    chromium-driver \
    \
    # ---- Chrome dependencies ----
    libnss3 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libx11-xcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    libpangocairo-1.0-0 \
    libpango-1.0-0 \
    libgtk-3-0 \
    fonts-liberation \
    \
    # ---- existing deps ----
    libmagic1 \
    curl \
    ca-certificates \
    \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Tell Selenium explicitly where Chromium is
ENV CHROME_BIN=/usr/bin/chromium
ENV PATH="/app/.venv/bin:$PATH"

# Copy virtualenv
COPY --from=builder /app/.venv /app/.venv

# Copy application code
COPY app ./app
COPY start.py ./start.py

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s \
  CMD curl -f http://localhost:8000/health || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
