#!/usr/bin/env bash
#MISE description="Rebuild the dev backend image and restart it when its code, dependencies or migrations change"
#MISE sources=["bun.lock", "package.json", "apps/backend/package.json", "packages/shared/package.json", "apps/backend/Dockerfile", "apps/backend/src/**/*", "packages/shared/src/**/*", "apps/backend/drizzle/**/*"]
# The image holds the sources, and nothing syncs them into a container started without watch.
# Recreating the containers also reruns the migrate service.
set -euo pipefail
mise run compose build backend
mise run compose up -d backend
