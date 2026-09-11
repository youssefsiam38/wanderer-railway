#!/usr/bin/env bash
# shellcheck disable=SC2015
# Persistence: the owner account, a trail and the search index survive recreating all containers.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"
umask 077; printf '%s' 'local-test-only-owner-password' > "$TEST_TMP/pw"

section "fresh stack"
compose down -v --remove-orphans >/dev/null 2>&1 || true
compose up -d --no-build; wait_for_code "$BASE_URL/" 200 420 || die "not ready"

section "write state"
JAR="$TEST_TMP/jar"; login owner "$TEST_TMP/pw" "$JAR" || die "login failed"
ACTOR=$(actor_id "$JAR" owner); [ -n "$ACTOR" ] || die "no actor"
TID=$(create_trail "$JAR" "$ACTOR" "Persist Ridge Loop"); [ -n "$TID" ] || die "trail create failed"
pass "state written: trail $TID by actor $ACTOR"

section "recreate all containers on the same volumes"
compose down >/dev/null; compose up -d --no-build
wait_for_code "$BASE_URL/" 200 420 || die "not ready after recreate"
assert_contains "owner bootstrap skipped" "owner bootstrap skipped" "$(compose logs --no-color web)"

section "verify"
JAR2="$TEST_TMP/jar2"
login owner "$TEST_TMP/pw" "$JAR2" && pass "owner password unchanged" || die "login failed after recreate"
t=$(trail_json "$JAR2" "$TID")
assert_eq "trail still present" "Persist Ridge Loop" "$(jq -r .name <<<"$t")"
assert_eq "distance retained" "4200" "$(jq -r .distance <<<"$t")"
assert_eq "same actor still owns it" "$ACTOR" "$(jq -r .author <<<"$t")"
assert_eq "search index retained" "$ACTOR" "$(actor_id "$JAR2" owner)"
summary
