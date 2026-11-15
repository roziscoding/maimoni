#!/usr/bin/env bash
#MISE description="Preview a frontend production build through a Cloudflare quick tunnel"
#MISE depends=["install", "build", "backend:image"]
#MISE raw=true
set -euo pipefail

metrics=127.0.0.1:20241
log=preview.log

mise run compose up -d backend "$@"

cleanup() {
  kill $(jobs -p) 2>/dev/null || true
  mise run compose stop backend
  rm -f "$log"
}
trap cleanup EXIT
cloudflared tunnel --no-autoupdate --url http://localhost:3000 --metrics "$metrics" >/dev/null 2>&1 &
echo "cloudflared tunnel started"
bun run --cwd apps/frontend preview -- -p 3000 >"$log" 2>&1 &
preview=$!
echo "nuxt preview started, logging to $log (tail -f $log)"

# The tunnel reports an empty hostname until it registers with Cloudflare.
hostname=
echo "waiting for tunnel url"
until [[ -n $hostname ]]; do
  sleep 1
  hostname=$(curl -fs "http://$metrics/quicktunnel" | sed -nE 's/.*"hostname":"([^"]*)".*/\1/p') || true
done
until curl -fso /dev/null http://localhost:3000/; do
  sleep 1
done

url="https://$hostname"
echo
if command -v qrencode >/dev/null; then
  qrencode -t ANSIUTF8 "$url"
else
  echo "qrencode not in PATH. skipping qrcode generation"
fi
echo "$url"
echo

wait "$preview"
