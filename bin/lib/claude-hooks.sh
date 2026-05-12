# shellcheck shell=sh
# oc claude-hooks — install/remove the session-backend audit hook.
# This writes a Claude Code settings.json fragment that runs our
# `config/claude-hooks/*.sh` scripts on SessionStart / Stop events.

# shellcheck source=../../lib/log.sh
. "$OC_LIB_DIR/log.sh"
# shellcheck source=../../lib/config.sh
. "$OC_LIB_DIR/config.sh"
# shellcheck source=../../lib/ui.sh
. "$OC_LIB_DIR/ui.sh"

_hooks_usage() {
  cat << 'EOF'
USAGE
  oc claude-hooks install         Install the session-backend audit hook
  oc claude-hooks remove          Remove it
  oc claude-hooks status          Show current install state
  oc claude-hooks tail            Tail the audit log
EOF
}

oc_cmd_claude_hooks() {
  case "${1:-status}" in
    install) _hooks_install ;;
    remove) _hooks_remove ;;
    status) _hooks_status ;;
    tail) _hooks_tail ;;
    -h | --help) _hooks_usage ;;
    *)
      _hooks_usage >&2
      return 2
      ;;
  esac
}

_settings_dir() {
  printf '%s/claude' "${XDG_CONFIG_HOME:-$HOME/.config}"
}

_hooks_install() {
  dst_dir="$(_settings_dir)/hooks"
  mkdir -p "$dst_dir"

  cp "$OC_PROJECT_ROOT/config/claude-hooks/session-start.sh" "$dst_dir/oc-session-start.sh"
  cp "$OC_PROJECT_ROOT/config/claude-hooks/stop.sh" "$dst_dir/oc-stop.sh"
  chmod +x "$dst_dir/oc-session-start.sh" "$dst_dir/oc-stop.sh"

  settings="$(_settings_dir)/settings.json"
  if [ -r "$settings" ]; then
    oc_log warn "$settings exists; refusing to overwrite. Merge hooks manually:"
    printf '  SessionStart -> %s/oc-session-start.sh\n' "$dst_dir"
    printf '  Stop         -> %s/oc-stop.sh\n' "$dst_dir"
    return 1
  fi
  cat > "$settings" << EOF
{
  "hooks": {
    "SessionStart": [
      { "command": "$dst_dir/oc-session-start.sh" }
    ],
    "Stop": [
      { "command": "$dst_dir/oc-stop.sh" }
    ]
  }
}
EOF
  oc_log ok "installed; audit log: $(oc_state_home)/sessions.jsonl"
}

_hooks_remove() {
  dst_dir="$(_settings_dir)/hooks"
  rm -f "$dst_dir/oc-session-start.sh" "$dst_dir/oc-stop.sh"
  oc_log ok "removed hook scripts (settings.json untouched)"
}

_hooks_status() {
  dst_dir="$(_settings_dir)/hooks"
  if [ -x "$dst_dir/oc-session-start.sh" ] && [ -x "$dst_dir/oc-stop.sh" ]; then
    printf 'installed: %s\n' "$dst_dir"
  else
    printf 'not installed\n'
  fi
}

_hooks_tail() {
  log="$(oc_state_home)/sessions.jsonl"
  [ -r "$log" ] || oc_die "no audit log at $log"
  tail -n 20 "$log"
}
