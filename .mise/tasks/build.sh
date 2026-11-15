#!/usr/bin/env bash
#MISE description="Build the Nuxt frontend for production"
#MISE depends=["install"]
#MISE sources=["bun.lock", "package.json", "apps/frontend/**/*", "packages/shared/**/*"]
set -euo pipefail
bun run --cwd apps/frontend build
