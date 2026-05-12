#!/bin/sh
# Claude Code SessionStart hook (opt-in via `oc claude-hooks install`).
# Records which backend the session is talking to in the ollama-claude
# audit log. Does not modify behaviour; pure observation.

set -e

LOG_DIR="${OC_LOG_DIR:-$HOME/.local/state/ollama-claude}"
LOG_FILE="$LOG_DIR/sessions.jsonl"
mkdir -p "$LOG_DIR"

# Determine backend from env. If ANTHROPIC_BASE_URL is set and points at
# localhost (or the user's configured local host), we're in local mode.
backend="cloud"
local_marker="${OC_LOCAL_HOST:-127.0.0.1}"
if [ -n "${ANTHROPIC_BASE_URL:-}" ]; then
  case "$ANTHROPIC_BASE_URL" in
    *"$local_marker"*|*localhost*|*127.0.0.1*|*0.0.0.0*)
      backend="local"
      ;;
    *)
      backend="custom"
      ;;
  esac
fi

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
session_id="${CLAUDE_SESSION_ID:-unknown}"

printf '{"ts":"%s","event":"session_start","backend":"%s","session_id":"%s","base_url":"%s"}\n' \
  "$ts" "$backend" "$session_id" "${ANTHROPIC_BASE_URL:-}" >> "$LOG_FILE"
