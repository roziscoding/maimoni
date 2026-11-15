# maimoni

Monthly BRL → EUR budget, replacing the `Financeiro.xlsx` workbook.
Each month is a copy of a template: fixed values carry over, variable ones (credit-card bills, energy…) are flagged for review, BRL net is converted through Wise (live EUR→BRL rate + Wise fee) and whatever EUR is left becomes a daily allowance for the rest of the month.

```
apps/frontend     Nuxt 4 + Nuxt UI 4 (client-rendered SPA, proxies /api/** to the backend)
apps/backend      Hono on Bun, Drizzle ORM + Postgres, Zod 4 validation
packages/shared   Zod schemas, API types and the month calculations used by both sides
docs/             API contract and design decisions
.mise/tasks       All project tasks (mise run <task>)
```

## Requirements

[mise](https://mise.jdx.dev) (installs Bun 1.4.2 from `mise.toml`), Docker with Compose.

## Getting started

```sh
mise install          # tools
mise run dev          # builds and runs the dev stack on http://localhost:3000
```

`dev` runs the apps in Docker with their source directories bind-mounted, so the backend restarts and Nuxt hot-reloads on save. The individual `dev:backend` and `dev:frontend` tasks remain available for running either app directly on the host.

`mise.toml` holds the local defaults, so a `.env` file is optional; create one from `.env.example` only to override them.

## Running everything in Docker

There are two Compose files:

- **`compose.dev.yaml`** is used by the development, database and log tasks. It builds the `dev` targets and bind-mounts `apps/*` and `packages/shared`. The containers keep their own `node_modules` (Linux binaries). Postgres (`localhost:5434`, user and password `maimoni`), the backend (`3001`) and the frontend (`3000`) are all published.
- **`compose.yaml`** is production. It uses the `runtime` images and runs migrations in a one-shot service before starting the backend. Nothing is published on the host: expose it through a reverse proxy pointed at the frontend's port `3000` on the stack's network (the frontend proxies `/api/**` to the backend), and at the backend's port `3001` for the mobile app. Every setting comes from the environment with a default (listed at the top of `compose.yaml`), so all of them can be replaced from Coolify's UI; `POSTGRES_PASSWORD`, `BETTER_AUTH_SECRET` and `BETTER_AUTH_URL` are required. It has its own project name (`maimoni-prod`) and volume, so it never touches the dev database.

```sh
mise run dev                       # build and run the dev stack in the foreground
mise run compose up -d --build     # build and run it in the background
mise run logs:backend              # formatted backend logs
mise run logs:frontend             # formatted frontend logs
mise run compose down              # stop the dev stack

POSTGRES_PASSWORD=... docker compose up -d --build   # production (compose.yaml)
```

Both Dockerfiles install dependencies in a layer built only from the `package.json` files and `bun.lock`, so code changes don't reinstall them.

## Tasks

| Task | What it does | Runs first |
| --- | --- | --- |
| `install` | `bun install` for every workspace | |
| `dev` | dev stack in Docker, in the foreground and watch mode | |
| `dev:backend` / `dev:frontend` | one side only | `db:migrate` / `install` |
| `db:up` / `db:down` | start (and wait for) / stop the dev Postgres container | |
| `db:migrate` | apply pending migrations to `DATABASE_URL` | `install`, `db:up` |
| `db:studio` | Drizzle Studio | `db:migrate` |
| `db:generate` | generate a Drizzle migration from `apps/backend/src/db/schema.ts` (no database needed) | `install` |
| `test` | shared + backend tests (backend runs on in-memory PGlite, no Docker needed) | `install` |
| `build` | production build of the frontend | `install` |
| `compose` | run arbitrary Docker Compose commands against `compose.dev.yaml` | |
| `logs:backend` / `logs:frontend` | follow one service's structured logs with `pino-pretty` | |

## Environment

| Variable | Used by | Default |
| --- | --- | --- |
| `DATABASE_URL` | backend, drizzle-kit | `postgres://maimoni:maimoni@localhost:5434/maimoni` |
| `PORT` | backend | `3001` |
| `NUXT_API_BASE` | frontend server (proxy target) | `http://localhost:3001` |
| `BETTER_AUTH_SECRET` | backend (signs sessions) | dev value in `mise.toml`; required in `compose.yaml` |
| `BETTER_AUTH_URL` | backend (public URL of the frontend) | `http://localhost:3000`; required in `compose.yaml` |
| `BETTER_AUTH_TRUSTED_ORIGINS` | backend (extra comma-separated origins for `/api/auth`) | none |
| `AUTH_SIGNUP_ENABLED` | backend (`true` allows sign up with email, Google or Apple) | `false` |
| `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` | backend (Google sign in, off without both) | none |
| `APPLE_CLIENT_ID` / `APPLE_TEAM_ID` / `APPLE_KEY_ID` / `APPLE_PRIVATE_KEY` | backend (Apple sign in, off without all four: the Services ID, the team ID, the Sign in with Apple key's ID and its `.p8` contents, where line breaks may be written as `\n`). The backend signs the client secret itself when it starts; it lasts 180 days | none |
| `APPLE_APP_BUNDLE_IDENTIFIER` | backend (iOS bundle ID, for native Apple sign in) | none |
| `PASSKEY_RP_ID` | backend (passkey relying party) | hostname of `BETTER_AUTH_URL` |
| `RESEND_API_KEY` | backend ([Resend](https://resend.com) key for password reset emails; none are sent without it) | none |
| `RESEND_FROM` | backend (sender of those emails, on a domain verified in Resend) | `maimoni <onboarding@resend.dev>`, which only reaches the Resend account's own address |
| `POSTGRES_PASSWORD` | `compose.yaml` (production) | required, no default |
| `FRONTEND_PORT` / `BACKEND_PORT` / `POSTGRES_PORT` | ports published by `compose.dev.yaml` | `3000` / `3001` / `5434` |

See [`docs/decisions.md`](docs/decisions.md) for how the spreadsheet maps to the app and why, and [`docs/api.md`](docs/api.md) for the API.
