#!/usr/bin/env bash
#MISE description="Run the Hono backend in watch mode (http://localhost:3001)"
#MISE dir="{{config_root}}/apps/backend"
#MISE depends=["db:migrate"]
#MISE env={ NODE_ENV="development" }
#MISE interactive=true
set -euo pipefail
bun run dev
