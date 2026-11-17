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

`dev` runs the apps in Docker under [Compose Watch](https://docs.docker.com/compose/how-tos/file-watch/): saved files are synced into the containers, so the backend restarts and Nuxt hot-reloads, and a changed `package.json`, `bun.lock` or Dockerfile rebuilds the image. The individual `dev:backend` and `dev:frontend` tasks remain available for running either app directly on the host.

`mise.toml` holds the local defaults, so a `.env` file is optional; create one from `.env.example` only to override them.

## Running everything in Docker

There are two Compose files:

- **`compose.dev.yaml`** is used by the development, database and log tasks. It builds the `dev` targets, which copy `apps/*` and `packages/shared` into the image, and its watch rules keep them in sync with the host. A stack started without watch keeps running the code it was built with. The backend container also reads `apps/backend/.env` when the file exists (gitignored), which is where optional settings such as `RESEND_API_KEY` go; variables set on the host don't reach it. Postgres (`localhost:5434`, user and password `maimoni`), the backend (`3001`), the frontend (`3000`) and [Drizzle Gateway](https://gateway.drizzle.team) (`4984`, master password `maimoni`) are all published.
- **`compose.yaml`** is production. It uses the `runtime` images and runs migrations in a one-shot service before starting the backend. Nothing is published on the host: expose it through a reverse proxy pointed at the frontend's port `3000` on the stack's network (the frontend proxies `/api/**` to the backend), and at the backend's port `3001` for the mobile app. Every setting comes from the environment with a default (listed at the top of `compose.yaml`), so all of them can be replaced from Coolify's UI; `POSTGRES_PASSWORD`, `BETTER_AUTH_SECRET`, `BETTER_AUTH_URL` and `DRIZZLE_GATEWAY_MASTERPASS` are required. It has its own project name (`maimoni-prod`) and volumes, so it never touches the dev database.

Both stacks run Drizzle Gateway, which is Drizzle Studio in the browser. Database connections are added in its UI and kept in its volume: host `postgres`, port `5432`, and the Postgres user, password and database of that stack. In production it listens on port `4983` of the stack's network and has full access to any database connected to it, so only proxy it somewhere private.

```sh
mise run dev                       # build and run the dev stack in the foreground
mise run compose up -d --build     # build and run it in the background
mise run compose watch             # sync saved files into a stack running in the background
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
| `envs` | write `apps/backend/.env` (Resend, Google and Apple secrets) from 1Password; the references at the top of the task point at the maintainer's vault | |
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
| `GOOGLE_IOS_CLIENT_ID` | backend (iOS OAuth client ID, for native Google sign in on iOS) | none |
| `APPLE_CLIENT_ID` / `APPLE_TEAM_ID` / `APPLE_KEY_ID` / `APPLE_PRIVATE_KEY` | backend (Apple sign in, off without all four: the Services ID, the team ID, the Sign in with Apple key's ID and its `.p8` contents, where line breaks may be written as `\n`). The backend signs the client secret itself when it starts; it lasts 180 days | none |
| `APPLE_APP_BUNDLE_IDENTIFIER` | backend (iOS bundle ID, for native Apple sign in) | none |
| `PASSKEY_RP_ID` | backend (passkey relying party) | hostname of `BETTER_AUTH_URL` |
| `RESEND_API_KEY` | backend ([Resend](https://resend.com) key for password reset emails; none are sent without it) | none |
| `RESEND_FROM` | backend (sender of those emails, on a domain verified in Resend) | `maimoni <onboarding@resend.dev>`, which only reaches the Resend account's own address |
| `POSTGRES_PASSWORD` | `compose.yaml` (production) | required, no default |
| `DRIZZLE_GATEWAY_MASTERPASS` | `compose.yaml` (password asked by Drizzle Gateway's UI) | required, no default |
| `FRONTEND_PORT` / `BACKEND_PORT` / `POSTGRES_PORT` / `DRIZZLE_GATEWAY_PORT` | ports published by `compose.dev.yaml` | `3000` / `3001` / `5434` / `4984` |

See [`docs/decisions.md`](docs/decisions.md) for how the spreadsheet maps to the app and why, and [`docs/api.md`](docs/api.md) for the API.
