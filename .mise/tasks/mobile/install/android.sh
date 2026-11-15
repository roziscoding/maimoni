#!/usr/bin/env bash
#MISE description="Install the Android release build on the connected device or emulator"
#MISE dir="{{config_root}}/apps/mobile"
#MISE depends=["mobile:build:android"]
set -euo pipefail
# Same command as mobile:install:ios: flutter installs the build matching the device's platform.
# Pass `-d <device>` when more than one device is connected.
flutter install --release "$@"
