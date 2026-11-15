#!/usr/bin/env bash
#MISE description="Run the dev stack in Docker in the foreground, in watch mode (sources bind-mounted)"
#MISE raw=true
set -euo pipefail
mise run compose up --build --renew-anon-volumes "$@"
