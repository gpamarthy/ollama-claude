#!/bin/sh
# Claude Code Stop hook (opt-in via `oc claude-hooks install`).
# Closes the session entry in the audit log.

set -e

LOG_DIR="${OC_LOG_DIR:-$HOME/.local/state/ollama-claude}"
LOG_FILE="$LOG_DIR/sessions.jsonl"
mkdir -p "$LOG_DIR"

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
session_id="${CLAUDE_SESSION_ID:-unknown}"

printf '{"ts":"%s","event":"session_stop","session_id":"%s"}\n' \
  "$ts" "$session_id" >> "$LOG_FILE"
