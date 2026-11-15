#!/usr/bin/env bash
#MISE description="Install the Android SDK packages needed to build the mobile app"
set -euo pipefail

api=36
packages=(platform-tools "platforms;android-$api" "build-tools;$api.0.0")

# sdkmanager hits the network even for installed packages, so only call it for missing ones.
missing=()
for package in "${packages[@]}"; do
  [[ -d $ANDROID_HOME/${package//;//} ]] || missing+=("$package")
done
if ((${#missing[@]})); then
  yes | sdkmanager --licenses >/dev/null || true
  sdkmanager --install "${missing[@]}"
fi
