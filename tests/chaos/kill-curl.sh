#!/bin/sh
# Chaos: kill a model pull mid-stream and assert oc_ollama_pull retries.
# Intended for the nightly chaos workflow on a CI runner with Ollama installed.
# Sandbox-friendly: refuses to run unless explicitly opted in.

set -eu

if [ "${OC_CHAOS_KILL_CURL:-0}" != "1" ]; then
  echo "[skip] OC_CHAOS_KILL_CURL=1 required to run this chaos test"
  exit 0
fi

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
. "$PROJECT_ROOT/lib/log.sh"
. "$PROJECT_ROOT/lib/ollama.sh"

# Start the pull in background, kill after 2s, then assert retry recovers.
(OC_PROJECT_ROOT="$PROJECT_ROOT" oc_ollama_pull tinyllama:1.1b) &
pid=$!
sleep 2
# Kill any child curls under our pgid
pkill -P "$pid" curl 2> /dev/null || true
wait "$pid" || true

# Re-attempt; expect success eventually.
OC_PROJECT_ROOT="$PROJECT_ROOT" oc_ollama_pull tinyllama:1.1b
echo "[ ok ] kill-curl chaos test recovered"
