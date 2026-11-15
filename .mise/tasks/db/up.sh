#!/usr/bin/env bash
#MISE description="Start only the dev Postgres container and wait until it's healthy"
set -euo pipefail
mise run compose up -d --wait postgres
