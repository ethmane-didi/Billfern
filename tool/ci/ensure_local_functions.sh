#!/usr/bin/env bash
# Makes sure the local stack serves the `delete-account` Edge Function before
# the live suite runs, and proves the function itself answers (not just the
# gateway).
#
# Usage: tool/ci/ensure_local_functions.sh <live-config-dir> <log-dir>
#
# Probe: sign in as the synthetic userA and call delete-account WITHOUT the
# confirmation phrase. Only the function returns 400 for that; it never
# deletes anything. If the stack does not serve functions automatically,
# `supabase functions serve` is started in the background and probed again.
set -euo pipefail

config_dir="${1:?live config directory required}"
log_dir="${2:?log directory required}"

mask() { if [[ -n "${GITHUB_ACTIONS:-}" && -n "$1" ]]; then echo "::add-mask::$1"; fi; }

api_url="$(jq -r .SUPABASE_URL "$config_dir/supabase.json")"
client_key="$(jq -r .SUPABASE_PUBLISHABLE_KEY "$config_dir/supabase.json")"
email="$(jq -r .userA.email "$config_dir/users.json")"
password="$(jq -r .userA.password "$config_dir/users.json")"

case "$api_url" in
  http://127.0.0.1:*|http://localhost:*) ;;
  *) echo "Refusing to probe: not the local stack." >&2; exit 1 ;;
esac

token="$(curl -sS -X POST "$api_url/auth/v1/token?grant_type=password" \
  -H "apikey: $client_key" -H 'Content-Type: application/json' \
  --data "$(jq -cn --arg e "$email" --arg p "$password" '{email: $e, password: $p}')" \
  | jq -r '.access_token // empty')"
if [[ -z "$token" ]]; then
  echo "Synthetic userA could not sign in to the local stack." >&2
  exit 1
fi
mask "$token"

probe() {
  curl -sS -o /dev/null -w '%{http_code}' --max-time 30 \
    -X POST "$api_url/functions/v1/delete-account" \
    -H "apikey: $client_key" -H "Authorization: Bearer $token" \
    -H 'Content-Type: application/json' \
    --data '{"confirm":"probe-not-a-confirmation"}' || true
}

wait_for_function() {
  local deadline=$((SECONDS + $1)) code
  while ((SECONDS < deadline)); do
    code="$(probe)"
    if [[ "$code" == "400" ]]; then return 0; fi
    sleep 3
  done
  echo "Last probe status: ${code:-none}" >&2
  return 1
}

if wait_for_function 60; then
  echo "delete-account is served by the local stack."
  exit 0
fi

echo "Starting 'supabase functions serve' in the background."
nohup supabase functions serve >"$log_dir/functions-serve.log" 2>&1 &
if wait_for_function 150; then
  echo "delete-account is served by 'supabase functions serve'."
  exit 0
fi
echo "delete-account never answered as expected." >&2
exit 1
