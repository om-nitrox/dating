# Stage 1: Dependencies
FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci --omit=dev

# Stage 2: Production image
FROM node:22-alpine AS runner
WORKDIR /app

# Security: run as non-root
RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -u 1001 -G appgroup

# Create logs directory
RUN mkdir -p /app/logs && chown appuser:appgroup /app/logs

COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Remove dev files
RUN rm -rf .env .env.* tests/ *.test.js nodemon.json

USER appuser

# Informational only. On Zoho Catalyst AppSail the actual listen port is
# injected at runtime via X_ZOHO_CATALYST_LISTEN_PORT (src/config maps it to
# PORT); 5000 is the local/docker-compose default.
EXPOSE 5000

# Probe the runtime port (AppSail-injected, else 5000). Runs under /bin/sh so
# the env var is interpolated.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider "http://localhost:${X_ZOHO_CATALYST_LISTEN_PORT:-5000}/health" || exit 1

CMD ["node", "server.js"]
