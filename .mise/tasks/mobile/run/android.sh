#!/usr/bin/env bash
#MISE description="Boot the Android emulator (if none is running) and run the app on it with hot reload"
#MISE dir="{{config_root}}/apps/mobile"
#MISE depends=["mobile:setup:emulator"]
#MISE raw=true
set -euo pipefail

avd=maimoni
# Extra emulator flags for this machine, e.g. ANDROID_EMULATOR_ARGS="-dns-server 1.1.1.1" in an
# (uncommitted) mise.local.toml.
read -r -a extra_args <<<"${ANDROID_EMULATOR_ARGS:-}"

serial() {
  adb devices | awk '$1 ~ /^emulator-/ && $2 == "device" { print $1; exit }'
}

device=$(serial)
if [[ -z $device ]]; then
  echo "booting emulator $avd"
  # Guarded expansion: with set -u, bash before 4.4 (macOS's /bin/bash) rejects an empty "${extra_args[@]}".
  emulator -avd "$avd" -no-snapshot-save -no-boot-anim ${extra_args[@]+"${extra_args[@]}"} >/dev/null 2>&1 &
  until device=$(serial) && [[ -n $device ]]; do
    sleep 1
  done
  until [[ $(adb -s "$device" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r') == 1 ]]; do
    sleep 1
  done
fi

flutter run -d "$device" "$@"
