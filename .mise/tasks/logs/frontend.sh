#!/usr/bin/env bash
#MISE description="Follow frontend container logs formatted with pino-pretty"
#MISE tools={"npm:pino-pretty"="latest"}
set -euo pipefail
mise run compose logs --no-log-prefix --no-color -f frontend | pino-pretty -S
