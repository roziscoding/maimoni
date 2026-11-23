#!/usr/bin/env bash
#MISE description="Analyze and test the mobile app"
#MISE dir="{{config_root}}/apps/mobile"
#MISE sources=["lib/**/*", "test/**/*", "preview/**/*", "pubspec.yaml", "pubspec.lock", "analysis_options.yaml"]
set -euo pipefail
flutter analyze
flutter test
