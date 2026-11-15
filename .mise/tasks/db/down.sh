#!/usr/bin/env bash
#MISE description="Stop the dev Postgres container (data is kept in the volume)"
set -euo pipefail
mise run compose stop postgres
