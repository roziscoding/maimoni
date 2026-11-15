# Build context: repository root (see compose.yaml).
# Targets: `dev` (watch mode, source synced in by compose.dev.yaml's watch rules) and `runtime` (compose.yaml).

FROM oven/bun:1.4.2-alpine AS base
WORKDIR /app
# Manifests only: the dependency layers below are reused until a package.json or bun.lock changes.
COPY package.json bun.lock ./
COPY apps/backend/package.json apps/backend/
COPY apps/frontend/package.json apps/frontend/
COPY packages/shared/package.json packages/shared/

FROM base AS deps
RUN bun install --frozen-lockfile --filter @maimoni/backend

FROM deps AS dev
COPY packages/shared packages/shared
COPY apps/backend apps/backend
WORKDIR /app/apps/backend
EXPOSE 3001
CMD ["bun", "--watch", "src/index.ts"]

FROM base AS prod-deps
RUN bun install --frozen-lockfile --production --filter @maimoni/backend

FROM oven/bun:1.4.2-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production PORT=3001
COPY --from=prod-deps /app/node_modules ./node_modules
COPY --from=prod-deps /app/apps/backend/node_modules ./apps/backend/node_modules
COPY --from=prod-deps /app/packages/shared/node_modules ./packages/shared/node_modules
COPY package.json ./
COPY packages/shared ./packages/shared
COPY apps/backend ./apps/backend
WORKDIR /app/apps/backend
USER bun
EXPOSE 3001
CMD ["bun", "src/index.ts"]
