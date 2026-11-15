#!/usr/bin/env bash
#MISE description="Start Postgres and apply pending migrations to DATABASE_URL (already applied ones are skipped)"
#MISE dir="{{config_root}}/apps/backend"
#MISE depends=["install", "db:up"]
#MISE sources=["{{config_root}}/apps/backend/drizzle"]
set -euo pipefail
bun run db:migrate
