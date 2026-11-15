#!/usr/bin/env bash
#MISE description="Run the Nuxt frontend in dev mode (http://localhost:3000)"
#MISE dir="{{config_root}}/apps/frontend"
#MISE depends=["install"]
set -euo pipefail
bun run dev
