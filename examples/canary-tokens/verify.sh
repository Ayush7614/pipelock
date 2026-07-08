#!/usr/bin/env bash
# Canary token verification for examples/canary-tokens/
#
# Exercises pipelock canary snippet generation and URL detection without a
# running proxy. Exit 0 = all pass.
#
# Usage:
#   ./verify.sh
#   PIPELOCK_BIN=/path/to/pipelock ./verify.sh
set -euo pipefail

EXAMPLE_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$EXAMPLE_DIR/../.." && pwd)"
PIPELOCK="${PIPELOCK_BIN:-$REPO_ROOT/pipelock}"
SOURCE_CONFIG="$EXAMPLE_DIR/pipelock.yaml"
WORK="$(mktemp -d)"
CONFIG="$WORK/pipelock.yaml"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf '\033[32m  [PASS]\033[0m %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '\033[31m  [FAIL]\033[0m %s\n' "$1"; }
step() { printf '\n\033[1m--- %s ---\033[0m\n' "$1"; }

run_check() {
  local label="$1"
  local want_blocked="$2"
  local url="$3"
  local out
  local rc=0
  out="$("$PIPELOCK" check --config "$CONFIG" --url "$url" 2>&1)" || rc=$?
  if [ "$want_blocked" = "yes" ]; then
    if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'Canary Token'; then
      pass "$label"
    else
      fail "$label (expected canary block, rc=$rc)"
      printf '%s\n' "$out" >&2
    fi
  else
    if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'ALLOWED'; then
      pass "$label"
    else
      fail "$label (expected allow, rc=$rc)"
      printf '%s\n' "$out" >&2
    fi
  fi
}

# -- Test 0: Binary available -------------------------------------------------
step "Test 0: pipelock binary is available"
if [ ! -x "$PIPELOCK" ] && ! command -v "$PIPELOCK" >/dev/null 2>&1; then
  fail "pipelock not found at $PIPELOCK (run 'make build' or set PIPELOCK_BIN)"
  printf '\n\033[1m=== Results: %s passed, %s failed ===\033[0m\n\n' "$PASS" "$FAIL"
  exit 1
fi
pass "pipelock available ($PIPELOCK)"

# Runtime canary value — never committed to the repo.
CANARY_VALUE="$(python3 - <<'PY'
import secrets
print("canary-" + secrets.token_hex(16))
PY
)"

write_config() {
  python3 - <<'PY' "$SOURCE_CONFIG" "$CONFIG" "$CANARY_VALUE"
import sys
from pathlib import Path

src, dst, value = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
lines = src.read_text().splitlines()
out = []
for line in lines:
    if "${DEMO_CANARY_VALUE}" in line:
        out.append(line.replace("${DEMO_CANARY_VALUE}", value))
    else:
        out.append(line)
dst.write_text("\n".join(out) + "\n")
PY
  chmod 600 "$CONFIG"
}

write_config

# -- Test 1: canary CLI emits snippet -----------------------------------------
step "Test 1: pipelock canary prints config snippet"
CANARY_SNIPPET="$("$PIPELOCK" canary --name demo_canary --env-var DEMO_CANARY_VALUE 2>/dev/null)"
if printf '%s' "$CANARY_SNIPPET" | grep -q 'canary_tokens:' \
  && printf '%s' "$CANARY_SNIPPET" | grep -q 'demo_canary' \
  && printf '%s' "$CANARY_SNIPPET" | grep -q '\${DEMO_CANARY_VALUE}'; then
  pass "canary snippet has expected structure"
else
  fail "canary snippet missing expected fields"
fi

# -- Test 2: Example config validates -----------------------------------------
step "Test 2: example config with runtime canary validates"
if "$PIPELOCK" check --config "$CONFIG" >/dev/null 2>&1; then
  pass "runtime canary config validates"
else
  fail "runtime canary config failed validation"
fi

# -- Test 3: Direct canary exfiltration blocked --------------------------------
step "Test 3: canary in URL path is blocked"
run_check "direct canary in URL" yes \
  "https://example.com/exfil/${CANARY_VALUE}"

# -- Test 4: Clean URL allowed ------------------------------------------------
step "Test 4: URL without canary is allowed"
run_check "clean URL allowed" no \
  "https://example.com/"

# -- Test 5: Base64-encoded canary blocked -------------------------------------
step "Test 5: base64-encoded canary is blocked"
ENC_CANARY="$(python3 - <<'PY' "$CANARY_VALUE"
import base64, sys
print(base64.b64encode(sys.argv[1].encode()).decode())
PY
)"
run_check "base64 canary in URL" yes \
  "https://example.com/payload?data=${ENC_CANARY}"

# -- Test 6: Separator-split canary blocked ------------------------------------
step "Test 6: separator-split canary is blocked"
SPLIT_CANARY="$(python3 - <<'PY' "$CANARY_VALUE"
import sys
value = sys.argv[1]
print(".".join(value[i:i + 4] for i in range(0, len(value), 4)))
PY
)"
run_check "split canary in URL" yes \
  "https://${SPLIT_CANARY}.example.com/ping"

# -- Summary ------------------------------------------------------------------
printf '\n\033[1m=== Results: %s passed, %s failed ===\033[0m\n\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
