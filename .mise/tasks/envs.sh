#!/usr/bin/env bash
#MISE description="Write apps/backend/.env with the backend's Resend, Google and Apple secrets, read from 1Password"
set -euo pipefail

out=apps/backend/.env

# Where each secret lives in 1Password.
google_client_id="op://maimoni/Google Cloud/client id"
google_client_secret="op://maimoni/Google Cloud/credential"
resend_api_key="op://maimoni/Resend/credential"
# A key created with the Sign in with Apple capability (an EC P-256 .p8), not the mobile signing ones.
apple_team_id="op://maimoni/Sign In With Apple/Team ID"
apple_key_id="op://maimoni/Sign In With Apple/Key ID"
apple_private_key="op://maimoni/Sign In With Apple/AuthKey_BC48L9FAZJ.p8"

# Single quotes keep Compose and Bun from expanding `$` or escapes in a value.
emit() {
  if [[ $2 == *"'"* || $2 == *$'\n'* ]]; then
    echo "envs: $1 has a quote or a line break and can't be written to an env file" >&2
    exit 1
  fi
  printf "%s='%s'\n" "$1" "$2"
}

is_p256_key() {
  openssl pkey -noout -text 2>/dev/null <<<"$1" | grep -q 'prime256v1'
}

umask 077
tmp=$(mktemp "$out.XXXXXX")
trap 'rm -f "$tmp"' EXIT

{
  echo "# Written by \`mise run envs\` from 1Password. Edits are lost the next time it runs."
  emit RESEND_API_KEY "$(op read "$resend_api_key")"
  emit GOOGLE_CLIENT_ID "$(op read "$google_client_id")"
  emit GOOGLE_CLIENT_SECRET "$(op read "$google_client_secret")"

  key=$(op read "$apple_private_key")
  if is_p256_key "$key"; then
    emit APPLE_TEAM_ID "$(op read "$apple_team_id")"
    emit APPLE_KEY_ID "$(op read "$apple_key_id")"
    # One line, with \n for the line breaks; the backend turns them back.
    emit APPLE_PRIVATE_KEY "${key//$'\n'/\\n}"
  else
    echo "envs: $apple_private_key is not a Sign in with Apple key (EC P-256), leaving Apple sign in out" >&2
  fi
} >"$tmp"

mv "$tmp" "$out"
trap - EXIT
echo "wrote $out"
