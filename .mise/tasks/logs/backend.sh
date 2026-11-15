#!/usr/bin/env bash
#MISE description="Follow backend container logs formatted with pino-pretty"
#MISE tools={"npm:pino-pretty"="latest"}
set -euo pipefail
mise run compose logs --no-log-prefix --no-color -f backend | pino-pretty -S
