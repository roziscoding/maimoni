#!/usr/bin/env bash
#MISE description="Install the Android emulator and system image, and create the maimoni AVD"
#MISE depends=["mobile:setup:android"]
set -euo pipefail

image="system-images;android-36;google_apis;x86_64"
avd=maimoni

missing=()
for package in emulator "$image"; do
  [[ -d $ANDROID_HOME/${package//;//} ]] || missing+=("$package")
done
if ((${#missing[@]})); then
  yes | sdkmanager --licenses >/dev/null || true
  sdkmanager --install "${missing[@]}"
fi

if ! avdmanager list avd -c | grep -qx "$avd"; then
  echo no | avdmanager create avd --name "$avd" --package "$image" --device pixel_7
fi
