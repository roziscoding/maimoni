#!/usr/bin/env bash
#MISE description="Boot the iOS Simulator (if none is running) and run the app on it with hot reload (macOS only)"
#MISE dir="{{config_root}}/apps/mobile"
#MISE raw=true
set -euo pipefail

booted() {
  xcrun simctl list devices booted | sed -nE 's/.*\(([0-9A-F-]{36})\) \(Booted\).*/\1/p' | head -n 1
}

device=$(booted)
if [[ -z $device ]]; then
  echo "booting simulator"
  open -a Simulator
  until device=$(booted) && [[ -n $device ]]; do
    sleep 1
  done
fi

flutter run -d "$device" "$@"
