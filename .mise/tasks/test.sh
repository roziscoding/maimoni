#!/usr/bin/env bash
#MISE description="Run shared and backend tests (backend uses in-memory PGlite, no Postgres needed)"
#MISE depends=["install"]
set -euo pipefail
(cd packages/shared && bun test)
(cd apps/backend && NODE_ENV=test bun test)
