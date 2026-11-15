# Build context: repository root (needs the workspace manifests, bun.lock and packages/shared).
# Targets: `dev` (Nuxt dev server, source bind-mounted by compose.dev.yaml) and `runtime` (compose.yaml).

FROM oven/bun:1.4.2-alpine AS base
WORKDIR /app
# Manifests only: the dependency layer below is reused until a package.json or bun.lock changes.
COPY package.json bun.lock ./
COPY apps/frontend/package.json apps/frontend/
COPY apps/backend/package.json apps/backend/
COPY packages/shared/package.json packages/shared/

FROM base AS deps
# `nuxt prepare` (postinstall) needs the sources; dev and build run it themselves.
RUN bun install --frozen-lockfile --ignore-scripts --filter @maimoni/frontend

FROM deps AS dev
COPY packages/shared packages/shared
COPY apps/frontend apps/frontend
WORKDIR /app/apps/frontend
ENV NUXT_API_BASE=http://backend:3001
EXPOSE 3000
CMD ["bun", "run", "dev", "--host", "0.0.0.0"]

FROM deps AS build
COPY packages/shared packages/shared
COPY apps/frontend apps/frontend
WORKDIR /app/apps/frontend
RUN bun run build

FROM oven/bun:1.4.2-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production \
    HOST=0.0.0.0 \
    PORT=3000 \
    NUXT_API_BASE=http://backend:3001
COPY --from=build /app/apps/frontend/.output ./.output
EXPOSE 3000
CMD ["bun", ".output/server/index.mjs"]
