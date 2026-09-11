#!/bin/sh
# wanderer-railway entrypoint.
#
#   1. validate variables (names only; values are never printed)
#   2. wait for PocketBase, then create the deployer's account if the instance has none, so the
#      template can ship with PUBLIC_DISABLE_SIGNUP=true and still be usable on first visit
#   3. exec the upstream start command
set -u

log()  { printf '[wanderer-railway] %s\n' "$*" >&2; }
fail() { log "FATAL: $*"; exit 1; }

: "${APP_READY_TIMEOUT:=300}"
: "${PORT:=3000}"
: "${HOST:=0.0.0.0}"
export PORT HOST
BOOTSTRAP=/usr/local/lib/wanderer-railway/bootstrap-owner.mjs

missing=""
for v in ORIGIN MEILI_URL MEILI_MASTER_KEY PUBLIC_POCKETBASE_URL POCKETBASE_PROXY_SECRET; do
  eval "val=\${$v:-}"
  [ -n "$val" ] || missing="$missing $v"
done
[ -z "$missing" ] || fail "missing required variable(s):$missing"

case "$ORIGIN" in
  http://?*|https://?*) ;;
  *) fail "ORIGIN must be the full public URL of this instance, starting with http:// or https:// (wanderer rejects cross-origin requests otherwise)" ;;
esac

# Upstream's compose ships a well-known MEILI_MASTER_KEY; refuse to run with it.
if [ "$MEILI_MASTER_KEY" = "vODkljPcfFANYNepCHyDyGjzAMPcdHnrb6X5KyXQPWo" ]; then
  fail "MEILI_MASTER_KEY is still upstream's example value, which is published in their docker-compose.yml. Generate a new one."
fi
[ "${#MEILI_MASTER_KEY}" -ge 16 ] || fail "MEILI_MASTER_KEY must be at least 16 characters"

owner_mode=0
if [ -n "${WANDERER_OWNER_USERNAME:-}" ] || [ -n "${WANDERER_OWNER_EMAIL:-}" ] || [ -n "${WANDERER_OWNER_PASSWORD:-}" ]; then
  if [ -z "${WANDERER_OWNER_USERNAME:-}" ] || [ -z "${WANDERER_OWNER_EMAIL:-}" ] || [ -z "${WANDERER_OWNER_PASSWORD:-}" ]; then
    fail "set all of WANDERER_OWNER_USERNAME, WANDERER_OWNER_EMAIL and WANDERER_OWNER_PASSWORD (or none)"
  fi
  owner_mode=1
elif [ "${PUBLIC_DISABLE_SIGNUP:-false}" = "true" ]; then
  fail "registration is disabled (PUBLIC_DISABLE_SIGNUP=true) and no owner account is configured, so nobody could ever sign in. Set WANDERER_OWNER_USERNAME, WANDERER_OWNER_EMAIL and WANDERER_OWNER_PASSWORD, or allow registration."
fi

if [ "$owner_mode" = 1 ]; then
  log "waiting up to ${APP_READY_TIMEOUT}s for PocketBase at the configured URL"
  deadline=$(( $(date +%s) + APP_READY_TIMEOUT ))
  until curl -fsS -m 5 -o /dev/null "${PUBLIC_POCKETBASE_URL%/}/health" 2>/dev/null; do
    [ "$(date +%s)" -lt "$deadline" ] || fail "PocketBase did not become healthy within ${APP_READY_TIMEOUT}s"
    sleep 2
  done
  log "PocketBase is healthy; ensuring the owner account exists"
  node "$BOOTSTRAP" || fail "owner bootstrap failed"
fi

log "starting wanderer on ${HOST}:${PORT} (registration disabled: ${PUBLIC_DISABLE_SIGNUP:-false})"
exec docker-entrypoint.sh "$@"
