#!/bin/sh
# Property: generate random hardware × topology combinations and assert
# the rendered claude-code.env satisfies invariants. Lightweight; runs
# 50 iterations by default. OC_PROPERTY_ITER overrides.

set -eu

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OC_PROJECT_ROOT="$PROJECT_ROOT"
OC_LIB_DIR="$PROJECT_ROOT/lib"
export OC_PROJECT_ROOT OC_LIB_DIR
. "$PROJECT_ROOT/lib/log.sh"
. "$PROJECT_ROOT/lib/config.sh"
. "$PROJECT_ROOT/lib/claude.sh"

ITER="${OC_PROPERTY_ITER:-50}"
FAIL=0

rand_int() {
  awk -v min="$1" -v max="$2" 'BEGIN{srand(); printf "%d", min + int(rand() * (max - min + 1))}'
}

for i in $(seq 1 "$ITER"); do
  topology_idx=$(rand_int 0 2)
  case "$topology_idx" in
    0) base="http://127.0.0.1:11434" ;;
    1) base="http://0.0.0.0:11434" ;;
    2) base="http://192.168.$(rand_int 0 255).$(rand_int 1 254):11434" ;;
  esac
  out=$(mktemp 2> /dev/null || echo /tmp/oc-prop.tmp)
  OC_PROJECT_ROOT="$PROJECT_ROOT" oc_render_claude_env "$base" "$out" > /dev/null

  # Invariants:
  # 1. ANTHROPIC_BASE_URL exactly matches what we rendered
  expected="^export ANTHROPIC_BASE_URL=\"$(printf '%s' "$base" | sed 's|/|\\/|g')\"$"
  if ! grep -Eq "$expected" "$out"; then
    echo "[fail] iter $i: BASE_URL not rendered as expected ($base)" >&2
    FAIL=$((FAIL + 1))
  fi
  # 2. AUTH_TOKEN line is exactly the ollama sentinel
  if ! grep -q '^export ANTHROPIC_AUTH_TOKEN="ollama"$' "$out"; then
    echo "[fail] iter $i: AUTH_TOKEN line missing or wrong" >&2
    FAIL=$((FAIL + 1))
  fi
  # 3. ANTHROPIC_API_KEY is either unset or exported empty
  if ! grep -qE '^(unset ANTHROPIC_API_KEY|export ANTHROPIC_API_KEY="")$' "$out"; then
    echo "[fail] iter $i: API_KEY handling not present" >&2
    FAIL=$((FAIL + 1))
  fi
  # 4. OLLAMA_ORIGINS=* is never written (loose: the string * shouldn't appear)
  if grep -q 'OLLAMA_ORIGINS=' "$out"; then
    echo "[fail] iter $i: OLLAMA_ORIGINS leaked into claude env" >&2
    FAIL=$((FAIL + 1))
  fi

  rm -f "$out"
done

if [ "$FAIL" -eq 0 ]; then
  echo "[ ok ] $ITER property iterations all passed"
  exit 0
else
  echo "[err ] $FAIL property failures" >&2
  exit 1
fi
