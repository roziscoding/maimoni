#!/usr/bin/env bash
#MISE description="Build the mobile app for iOS, without code signing (macOS only)"
#MISE dir="{{config_root}}/apps/mobile"
#MISE sources=["lib/**/*", "ios/**/*", "pubspec.yaml", "pubspec.lock"]
#MISE outputs=["build/ios/iphoneos/Runner.app/Info.plist"]
set -euo pipefail
flutter build ios --release --no-codesign "$@"
