#!/usr/bin/env bash
#MISE description="Generate a Drizzle migration from schema changes (does not touch the database)"
#MISE dir="{{config_root}}/apps/backend"
#MISE depends=["install"]
set -euo pipefail
bunx drizzle-kit generate "$@"
