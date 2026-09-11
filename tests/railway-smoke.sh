#!/usr/bin/env bash
# shellcheck disable=SC2015
# Public smoke test against a deployed instance.
#   tests/railway-smoke.sh https://your-app.up.railway.app
# Optional: OWNER_USERNAME=owner OWNER_PASSWORD_FILE=/path/to/file
#   STATE_OUT=/path/state.json (create a trail) / STATE_IN=/path/state.json (verify after redeploy)
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
BASE_URL=${1:?usage: railway-smoke.sh https://domain}; BASE_URL=${BASE_URL%/}; export BASE_URL
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"
host=${BASE_URL#https://}

section "TLS and routing"
assert_eq "https frontend" "200" "$(http_code "$BASE_URL/")"
assert_contains "valid certificate" "SSL certificate verify ok" "$(curl -sv -o /dev/null "$BASE_URL/" 2>&1 || true)"
assert_contains "http -> https" "https://$host" "$(curl -s -o /dev/null -w '%{http_code} %{redirect_url}' --max-time 20 "http://$host/")"
assert_contains "frontend is wanderer" "wanderer" "$(curl -s "$BASE_URL/" | tr '[:upper:]' '[:lower:]')"

section "first-run safety"
assert_eq "registration closed" "302" "$(http_code "$BASE_URL/register")"
# upstream throws its "signup disabled" error outside the handler's try/catch, so the refusal
# surfaces as 500 rather than 401; what matters is that no account is created
code=$(http_code -X PUT "$BASE_URL/api/v1/user" -H 'Content-Type: application/json' --data '{"username":"intruder","email":"a@b.invalid","password":"hunter2hunter2"}')
case "$code" in 2*) fail "signup API created an account (HTTP $code)" ;; *) pass "signup API refuses (HTTP $code)" ;; esac
code=$(login_code intruder hunter2hunter2)
[ "$code" != "200" ] && pass "the refused signup left no account behind (HTTP $code)" || fail "signup actually created an account"
assert_eq "trail API refuses anonymous" "401" "$(http_code "$BASE_URL/api/v1/trail")"
code=$(login_code owner wrong-password-entirely)
[ "$code" != "200" ] && pass "wrong password rejected (HTTP $code)" || fail "wrong password accepted"

if [ -n "${OWNER_PASSWORD_FILE:-}" ]; then
  section "owner login through the public domain"
  JAR="$TEST_TMP/jar"
  login "${OWNER_USERNAME:-owner}" "$OWNER_PASSWORD_FILE" "$JAR" && pass "login with the generated password" || die "login failed"
  ACTOR=$(actor_id "$JAR" "${OWNER_USERNAME:-owner}")
  [ ${#ACTOR} -eq 15 ] && pass "search service reachable (actor $ACTOR)" || fail "actor not resolved: is the search service up?"
  if [ -n "${STATE_OUT:-}" ]; then
    section "create a trail"
    TID=$(create_trail "$JAR" "$ACTOR" "Railway Ridge Loop"); [ -n "$TID" ] && pass "trail created ($TID)" || die "trail create failed"
    jq -n --arg t "$TID" --arg a "$ACTOR" '{trail:$t, actor:$a, name:"Railway Ridge Loop"}' > "$STATE_OUT"; pass "state written"
  fi
  if [ -n "${STATE_IN:-}" ]; then
    section "verify state after redeploy"
    T=$(jq -r .trail "$STATE_IN")
    t=$(trail_json "$JAR" "$T")
    assert_eq "trail still present" "$(jq -r .name "$STATE_IN")" "$(jq -r .name <<<"$t")"
    assert_eq "distance retained" "4200" "$(jq -r .distance <<<"$t")"
    assert_eq "actor unchanged" "$(jq -r .actor "$STATE_IN")" "$(jq -r .author <<<"$t")"
    assert_eq "search index retained" "$(jq -r .actor "$STATE_IN")" "$(actor_id "$JAR" "${OWNER_USERNAME:-owner}")"
  fi
fi
summary
