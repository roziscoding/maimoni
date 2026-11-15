#!/usr/bin/env bash
#MISE description="Install all workspace dependencies"
#MISE sources=["bun.lock", "package.json", "apps/*/package.json", "packages/*/package.json"]
set -euo pipefail
bun install
