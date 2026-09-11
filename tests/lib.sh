#!/usr/bin/env bash
# shellcheck disable=SC2015  # `cond && pass || fail` is intentional; pass/fail always succeed
# Shared helpers for wanderer-railway tests. Source this file; do not execute it.
# Secrets are never echoed. Only names, lengths, and pass/fail results are printed.

: "${BASE_URL:=http://localhost:3000}"
: "${TEST_TIMEOUT:=300}"

TEST_TMP="${TEST_TMP:-$(mktemp -d)}"
export TEST_TMP
_PASS=0; _FAIL=0

pass() { _PASS=$((_PASS+1)); printf '  PASS  %s\n' "$*"; }
fail() { _FAIL=$((_FAIL+1)); printf '  FAIL  %s\n' "$*" >&2; }
die()  { printf 'FATAL: %s\n' "$*" >&2; exit 1; }
section() { printf '\n== %s ==\n' "$*"; }
summary() { printf '\n%d passed, %d failed\n' "$_PASS" "$_FAIL"; [ "$_FAIL" -eq 0 ]; }

# here-strings, not pipes: `grep -q` exits on the first match and a pipe writer would get SIGPIPE,
# which `pipefail` reports as failure when the haystack is larger than the pipe buffer
assert_eq() { if [ "$2" = "$3" ]; then pass "$1 ($3)"; else fail "$1: expected [$2] got [$3]"; fi; }
assert_contains() { if grep -q -- "$2" <<<"$3"; then pass "$1"; else fail "$1: missing [$2]"; fi; }
assert_not_contains() { if grep -q -- "$2" <<<"$3"; then fail "$1: found forbidden [$2]"; else pass "$1"; fi; }
logs_match() { local l; l=$(compose logs --no-color web 2>/dev/null); grep -qiE -- "$1" <<<"$l"; }

http_code() { curl -s -o /dev/null -w '%{http_code}' --max-time 30 "$@"; }
wait_for_code() {
  local url=$1 want=$2 timeout=${3:-$TEST_TIMEOUT} start code
  start=$(date +%s)
  while :; do
    code=$(http_code "$url" || true)
    [ "$code" = "$want" ] && return 0
    if [ $(( $(date +%s) - start )) -ge "$timeout" ]; then printf 'timed out waiting for %s -> %s (last %s)\n' "$url" "$want" "$code" >&2; return 1; fi
    sleep 3
  done
}

# req_json JAR TIMEOUT curl-args... -> body, retried while the response is not JSON
req_json() {
  local jar=$1 timeout=$2; shift 2
  local start body code
  start=$(date +%s)
  while :; do
    body=$(curl -s -b "$jar" -c "$jar" -w '\n%{http_code}' --max-time 60 "$@" || true)
    code=${body##*$'\n'}; body=${body%$'\n'*}
    if jq -e . >/dev/null 2>&1 <<<"$body"; then printf '%s' "$body"; return 0; fi
    if [ $(( $(date +%s) - start )) -ge "$timeout" ]; then
      printf 'non-JSON response after %ss (HTTP %s) from: %s\n  body: %s\n' "$timeout" "$code" "$*" "$(head -c 200 <<<"$body")" >&2
      return 1
    fi
    sleep 3
  done
}

# login USERNAME PASSWORD_FILE JAR -> 0 on success
login() {
  local u=$1 pf=$2 jar=$3 code
  : > "$jar"
  code=$(curl -s -o /dev/null -w '%{http_code}' -c "$jar" -X POST "$BASE_URL/api/v1/auth/login" \
    -H 'Content-Type: application/json' \
    --data "$(jq -nc --arg u "$u" --rawfile p "$pf" '{username:$u,password:($p|rtrimstr("\n"))}')" || true)
  [ "$code" = "200" ]
}
login_code() { http_code -X POST "$BASE_URL/api/v1/auth/login" -H 'Content-Type: application/json' --data "$(jq -nc --arg u "$1" --arg p "$2" '{username:$u,password:$p}')"; }
api() { local jar=$1; shift; curl -s -b "$jar" "$@"; }
api_code() { local jar=$1; shift; curl -s -o /dev/null -w '%{http_code}' -b "$jar" --max-time 60 "$@"; }

# actor_id JAR USERNAME -> the 15-character ActivityPub actor id, via the Meilisearch-backed search
# (this also proves the search service is wired up, which the app needs for every listing page)
actor_id() {
  local body
  body=$(req_json "$1" 120 -X POST "$BASE_URL/api/v1/search/actors" -H 'Content-Type: application/json' \
    --data "$(jq -nc --arg q "$2" '{q:$q}')") || return 1
  jq -r --arg u "$2" '(.hits // [])[] | select(.username==$u) | .id' <<<"$body" | head -1
}
# create_trail JAR ACTOR NAME -> prints the trail id
create_trail() {
  local body
  body=$(req_json "$1" 120 -X PUT "$BASE_URL/api/v1/trail" -H 'Content-Type: application/json' \
    --data "$(jq -nc --arg a "$2" --arg n "$3" '{name:$n, description:"synthetic test trail", public:false,
      completed:false, difficulty:"easy", lat:47.1, lon:11.2, distance:4200, elevation_gain:310,
      elevation_loss:295, duration:5400, photos:[], author:$a}')") || return 1
  jq -r '.id // empty' <<<"$body"
}
trail_json() { req_json "$1" 120 "$BASE_URL/api/v1/trail/$2"; }
trails() { req_json "$1" 120 "$BASE_URL/api/v1/trail"; }
compose() { docker compose -f "$REPO_ROOT/compose.yaml" "$@"; }
