#!/usr/bin/env bash
#MISE description="Build a signed IPA for TestFlight (macOS only; pass --export-options-plist)"
#MISE dir="{{config_root}}/apps/mobile"
#MISE depends=["mobile:setup:ios-keychain"]
set -euo pipefail
# CI passes --build-name, --build-number and the export options written by .github/actions/ios-signing.
flutter build ipa --release "$@"
