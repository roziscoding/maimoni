#!/usr/bin/env bash
#MISE description="Run the app on the Android emulator signed in against fake data in memory, with no backend"
#MISE raw=true
set -euo pipefail
# The entrypoint is outside lib/, so only this task builds it. Extra arguments go to `flutter run`,
# e.g. `--dart-define=PREVIEW_SIGNED_OUT=true` to start on the login screen.
exec mise run mobile:run:android -t preview/main.dart "$@"
