#!/usr/bin/env bash
#MISE description="Build the signed iOS release build and install it on the connected device"
#MISE dir="{{config_root}}/apps/mobile"
#MISE depends=["mobile:setup:ios-keychain"]
set -euo pipefail
# Signed, unlike mobile:build:ios: a device refuses an unsigned app, and flutter install doesn't build.
flutter build ios --release
# Same command as mobile:install:android: flutter installs the build matching the device's platform.
# Pass `-d <device>` when more than one device is connected.
flutter install --release "$@"
