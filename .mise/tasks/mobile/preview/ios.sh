#!/usr/bin/env bash
#MISE description="Run the app on the iOS Simulator signed in against fake data in memory, with no backend (macOS only)"
#MISE raw=true
set -euo pipefail
# The entrypoint is outside lib/, so only this task builds it. Extra arguments go to `flutter run`,
# e.g. `--dart-define=PREVIEW_SIGNED_OUT=true` to start on the login screen.
exec mise run mobile:run:ios -t preview/main.dart "$@"
