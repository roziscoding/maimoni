#!/usr/bin/env bash
#MISE description="Build the mobile app's release APK (apps/mobile/build/app/outputs/flutter-apk/app-release.apk)"
#MISE dir="{{config_root}}/apps/mobile"
#MISE depends=["mobile:setup:android"]
set -euo pipefail
# CI passes --build-name and --build-number; otherwise they come from pubspec.yaml's version.
flutter build apk --release "$@"
