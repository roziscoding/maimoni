#!/usr/bin/env bash
#MISE description="Run the dev stack in Docker in the foreground, in watch mode (saved files are synced into the containers)"
#MISE raw=true
set -euo pipefail
mise run compose up --build --watch "$@"
