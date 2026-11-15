#!/usr/bin/env bash
#MISE description="Rebuild the dev backend image and restart it when dependencies or migrations change"
#MISE sources=["bun.lock", "package.json", "apps/backend/package.json", "packages/shared/package.json", "apps/backend/Dockerfile", "apps/backend/drizzle/**/*"]
# Sources are bind-mounted, so code changes don't need a new image. Recreating the containers
# refreshes the node_modules volumes and reruns the migrate service.
set -euo pipefail
mise run compose build backend
mise run compose up -d --renew-anon-volumes backend
