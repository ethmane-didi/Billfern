#!/usr/bin/env bash
# Creates the synthetic live-suite users on the DISPOSABLE local Supabase stack
# started by `supabase start` in CI, and writes the live-suite configuration.
#
# Usage: tool/ci/setup_local_test_users.sh <supabase-status-env-file> <out-dir>
#
# - Refuses any API URL that is not the local loopback stack, so it can never
#   create users in a hosted project.
# - Passwords are random per run; nothing is reused or committed.
# - Every value is masked in GitHub Actions logs and never printed.
# - Writes <out-dir>/supabase.json and <out-dir>/users.json (mode 600). Keep
#   <out-dir> outside the repository workspace and never upload it.
set -euo pipefail

status_env="${1:?status env file required}"
out_dir="${2:?output directory required}"

mask() { if [[ -n "${GITHUB_ACTIONS:-}" && -n "$1" ]]; then echo "::add-mask::$1"; fi; }

# Read only the variables we need from `supabase status -o env`.
read_var() {
  local name="$1"
  sed -n "s/^${name}=\"\{0,1\}\([^\"]*\)\"\{0,1\}$/\1/p" "$status_env" | head -n 1
}

api_url="$(read_var API_URL)"
service_key="$(read_var SERVICE_ROLE_KEY)"
[[ -n "$service_key" ]] || service_key="$(read_var SECRET_KEY)"
client_key="$(read_var PUBLISHABLE_KEY)"
[[ -n "$client_key" ]] || client_key="$(read_var ANON_KEY)"

mask "$service_key"
mask "$client_key"

case "$api_url" in
  http://127.0.0.1:*|http://localhost:*) ;;
  *)
    echo "Refusing to create test users: API URL is not the local stack." >&2
    exit 1
    ;;
esac
if [[ -z "$service_key" || -z "$client_key" ]]; then
  echo "Local stack keys are missing from supabase status." >&2
  exit 1
fi

umask 077
mkdir -p "$out_dir"

create_user() {
  local email="$1" password="$2" code
  code="$(curl -sS -o /dev/null -w '%{http_code}' \
    -X POST "$api_url/auth/v1/admin/users" \
    -H "apikey: $service_key" \
    -H "Authorization: Bearer $service_key" \
    -H 'Content-Type: application/json' \
    --data "$(jq -cn --arg e "$email" --arg p "$password" \
      '{email: $e, password: $p, email_confirm: true}')")"
  if [[ "$code" != "200" && "$code" != "201" ]]; then
    echo "Creating a synthetic test user failed (HTTP $code)." >&2
    exit 1
  fi
}

declare -A emails=(
  [userA]="billfern-test-a@example.com"
  [userB]="billfern-test-b@example.com"
  [deleteMe]="billfern-test-delete@example.com"
)
declare -A passwords
for key in userA userB deleteMe; do
  passwords[$key]="ci-$(openssl rand -hex 24)"
  mask "${passwords[$key]}"
  create_user "${emails[$key]}" "${passwords[$key]}"
done

jq -n --arg url "$api_url" --arg key "$client_key" \
  '{SUPABASE_URL: $url, SUPABASE_PUBLISHABLE_KEY: $key}' >"$out_dir/supabase.json"
jq -n \
  --arg ae "${emails[userA]}" --arg ap "${passwords[userA]}" \
  --arg be "${emails[userB]}" --arg bp "${passwords[userB]}" \
  --arg de "${emails[deleteMe]}" --arg dp "${passwords[deleteMe]}" \
  '{userA: {email: $ae, password: $ap},
    userB: {email: $be, password: $bp},
    deleteMe: {email: $de, password: $dp}}' >"$out_dir/users.json"
chmod 600 "$out_dir/supabase.json" "$out_dir/users.json"

echo "Created 3 synthetic users on the local stack."
