#!/usr/bin/env bash
#MISE description="Run semantic-release for the mobile app (the Mobile release workflow runs it on beta and stable)"
#MISE dir="{{config_root}}/apps/mobile"
#MISE depends=["install"]
set -euo pipefail
node ../../node_modules/semantic-release/bin/semantic-release.js "$@"
