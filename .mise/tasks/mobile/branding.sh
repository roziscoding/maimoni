#!/usr/bin/env bash
#MISE description="Regenerate the mobile app's launcher icons and splash screen from assets/branding"
#MISE dir="{{config_root}}/apps/mobile"
set -euo pipefail
dart run flutter_launcher_icons
dart run flutter_native_splash:create
