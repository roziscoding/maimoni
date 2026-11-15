#!/usr/bin/env bash
#MISE description="Run Docker Compose commands against the development stack"
#MISE raw=true
#MISE raw_args=true
set -euo pipefail
docker compose -f compose.dev.yaml "$@"
