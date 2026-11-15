#!/usr/bin/env bash
#MISE description="Unlock the ios-build keychain (signing identities for builds over SSH), if it was set up (macOS only)"
set -euo pipefail

# Created by ~/setup-ios-build-keychain.sh on the Mac. Without it, signing falls back to the login
# keychain, which has to be unlocked by hand.
password_file="$HOME/.config/ios-build/keychain-password"
if [[ -f $password_file ]]; then
  security unlock-keychain -p "$(<"$password_file")" ios-build.keychain
fi
