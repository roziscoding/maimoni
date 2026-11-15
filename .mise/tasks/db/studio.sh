#!/usr/bin/env bash
#MISE description="Start Postgres, migrate and open Drizzle Studio against DATABASE_URL"
#MISE dir="{{config_root}}/apps/backend"
#MISE depends=["db:migrate"]
set -euo pipefail
bunx drizzle-kit studio
