#!/usr/bin/env bash
# shellcheck disable=SC2015
# Local smoke test. Run `docker compose build` first (CI does), or set WANDERER_RAILWAY_IMAGE.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"
mkdir -p "$REPO_ROOT/test-output"; METRICS="$REPO_ROOT/test-output/metrics.txt"
LOCAL_MEILI_KEY='local-test-only-meili-master-key-not-for-production'
LOCAL_PB_KEY='local-test-only-pocketbase-key32'
LOCAL_PROXY_SECRET='local-test-only-proxy-secret'
LOCAL_OWNER_PASSWORD='local-test-only-owner-password'
umask 077; printf '%s' "$LOCAL_OWNER_PASSWORD" > "$TEST_TMP/pw"

section "fresh stack (empty volumes)"
compose down -v --remove-orphans >/dev/null 2>&1 || true
t0=$(date +%s); compose up -d --no-build
wait_for_code "$BASE_URL/" 200 420 && pass "frontend served" || { compose logs --no-color web | tail -40; die "never became ready"; }
cold=$(( $(date +%s) - t0 )); echo "cold_start_seconds=$cold" | tee "$METRICS"

section "first-boot owner bootstrap"
logs=$(compose logs --no-color web)
assert_contains "waited for PocketBase" "PocketBase is healthy" "$logs"
assert_contains "owner created" "owner bootstrap complete" "$logs"
assert_contains "registration disabled at start" "registration disabled: true" "$logs"
for sec in "$LOCAL_MEILI_KEY" "$LOCAL_PB_KEY" "$LOCAL_PROXY_SECRET" "$LOCAL_OWNER_PASSWORD"; do
  assert_not_contains "secret not in logs (len ${#sec})" "$sec" "$logs"
done

section "registration is closed and the API is protected"
assert_eq "GET /register redirects away" "302" "$(http_code "$BASE_URL/register")"
# upstream throws its "signup disabled" error outside the handler's try/catch, so the refusal
# surfaces as 500 rather than 401; what matters is that no account is created
code=$(http_code -X PUT "$BASE_URL/api/v1/user" -H 'Content-Type: application/json' --data '{"username":"intruder","email":"a@b.invalid","password":"hunter2hunter2"}')
case "$code" in 2*) fail "signup API created an account (HTTP $code)" ;; *) pass "signup API refuses (HTTP $code)" ;; esac
code=$(login_code intruder hunter2hunter2)
[ "$code" != "200" ] && pass "the refused signup left no account behind (HTTP $code)" || fail "signup actually created an account"
assert_eq "trail API refuses anonymous" "401" "$(http_code "$BASE_URL/api/v1/trail")"
code=$(login_code owner wrong-password-entirely)
[ "$code" != "200" ] && pass "wrong password rejected (HTTP $code)" || fail "wrong password accepted"

section "sign in as the generated owner"
JAR="$TEST_TMP/jar"
login owner "$TEST_TMP/pw" "$JAR" && pass "owner login" || die "owner login failed"
assert_eq "trail list visible when signed in" "200" "$(api_code "$JAR" "$BASE_URL/api/v1/trail")"

section "core workflow: search-backed actor, trail, listing"
ACTOR=$(actor_id "$JAR" owner); [ ${#ACTOR} -eq 15 ] && pass "actor resolved through Meilisearch ($ACTOR)" || die "no actor id (search service wired up?)"
TID=$(create_trail "$JAR" "$ACTOR" "Test Ridge Loop"); [ -n "$TID" ] && pass "trail created ($TID)" || die "trail create failed"
t=$(trail_json "$JAR" "$TID")
assert_eq "name stored" "Test Ridge Loop" "$(jq -r .name <<<"$t")"
assert_eq "distance stored" "4200" "$(jq -r .distance <<<"$t")"
assert_eq "elevation gain stored" "310" "$(jq -r .elevation_gain <<<"$t")"
assert_eq "private by default" "false" "$(jq -r .public <<<"$t")"
assert_contains "trail listed for the owner" "$TID" "$(trails "$JAR")"
for _ in $(seq 1 20); do hits=$(req_json "$JAR" 60 -X POST "$BASE_URL/api/v1/search/trails" -H 'Content-Type: application/json' --data '{"q":"Ridge"}' 2>/dev/null || echo '{}'); [ "$(jq -r '[.hits // [] | .[] | select(.id=="'"$TID"'")] | length' <<<"$hits" 2>/dev/null || echo 0)" -ge 1 ] && break; sleep 3; done
assert_eq "trail indexed for search" "1" "$(jq -r '[.hits // [] | .[] | select(.id=="'"$TID"'")] | length' <<<"$hits" 2>/dev/null || echo 0)"

section "private instance hides content from anonymous visitors"
assert_eq "anonymous trail read refused" "401" "$(http_code "$BASE_URL/api/v1/trail/$TID")"

section "graceful shutdown (SIGTERM)"
t1=$(date +%s); compose stop -t 30 web; dur=$(( $(date +%s)-t1 ))
code=$(docker inspect --format '{{.State.ExitCode}}' "$(compose ps -a -q web)")
[ "$dur" -lt 30 ] && pass "stopped in ${dur}s without SIGKILL" || fail "stop took ${dur}s"
case "$code" in 0|143) pass "exit status after SIGTERM is $code" ;; *) fail "unexpected exit status $code" ;; esac
compose start web; wait_for_code "$BASE_URL/" 200 300 && pass "restarted" || die "did not restart"
assert_contains "bootstrap is idempotent" "owner bootstrap skipped" "$(compose logs --no-color web)"

section "fail-fast validation"
img=$(compose config --images | grep -viE 'meilisearch|wanderer-db' | head -1)
# shellcheck disable=SC2016  # Go template, not a shell expansion
net=$(compose ps -q db | xargs docker inspect --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}')
base=(-e "MEILI_URL=http://search:7700" -e "PUBLIC_POCKETBASE_URL=http://db:8090" -e "POCKETBASE_PROXY_SECRET=$LOCAL_PROXY_SECRET")
run_img() { docker run --rm --network "$net" "${base[@]}" "$@" "$img" >"$TEST_TMP/ff.log" 2>&1; }
if run_img -e "MEILI_MASTER_KEY=$LOCAL_MEILI_KEY"; then fail "should fail without ORIGIN"; else pass "exits without ORIGIN"; fi
assert_contains "names ORIGIN" "ORIGIN" "$(cat "$TEST_TMP/ff.log")"
if run_img -e ORIGIN=https://example.invalid -e "MEILI_MASTER_KEY=vODkljPcfFANYNepCHyDyGjzAMPcdHnrb6X5KyXQPWo"; then fail "should reject upstream's published key"; else pass "rejects upstream's published MEILI_MASTER_KEY"; fi
assert_contains "explains the published key" "published in their docker-compose" "$(cat "$TEST_TMP/ff.log")"
if run_img -e ORIGIN=https://example.invalid -e "MEILI_MASTER_KEY=$LOCAL_MEILI_KEY" -e PUBLIC_DISABLE_SIGNUP=true; then fail "should refuse a locked-out instance"; else pass "refuses signup-disabled with no owner account"; fi
assert_contains "explains the lockout" "nobody could ever sign in" "$(cat "$TEST_TMP/ff.log")"
assert_not_contains "no secret echoed" "$LOCAL_MEILI_KEY" "$(cat "$TEST_TMP/ff.log")"

section "image metadata"
assert_eq "architecture" "amd64" "$(docker image inspect "$img" --format '{{.Architecture}}')"
labels=$(docker image inspect "$img" --format '{{json .Config.Labels}}')
for l in org.opencontainers.image.source org.opencontainers.image.revision org.opencontainers.image.version io.wanderer-railway.upstream.version; do assert_contains "label $l" "\"$l\"" "$labels"; done
assert_contains "AGPL declared" "AGPL-3.0-only" "$labels"
assert_contains "upstream licence shipped" "GNU AFFERO GENERAL PUBLIC LICENSE" "$(compose exec -T web head -1 /usr/share/licenses/wanderer-railway/WANDERER-LICENSE | tr -d '\r')"

section "metrics"
{ echo "image_bytes=$(docker image inspect "$img" --format '{{.Size}}')"
  docker stats --no-stream --format '{{.Name}} mem={{.MemUsage}}' | grep wanderer-railway-test | sed 's/^/mem_/'; } | tee -a "$METRICS"
summary
