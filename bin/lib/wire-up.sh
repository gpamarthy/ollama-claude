# shellcheck shell=sh
# oc wire-up - inject `source ~/.config/ollama-claude/claude-code.env`
# into the user's shell rc. Opt-in. Never touches Claude Code's
# settings.json unless --claude-settings is passed.

# shellcheck source=../../lib/log.sh
. "$OC_LIB_DIR/log.sh"
# shellcheck source=../../lib/config.sh
. "$OC_LIB_DIR/config.sh"
# shellcheck source=../../lib/ui.sh
. "$OC_LIB_DIR/ui.sh"

_wireup_usage() {
  cat << 'EOF'
USAGE
  oc wire-up [--dry-run] [--shell <bash|zsh|fish|powershell>] [--claude-settings]

DEFAULT
  Detects your shell and appends a `source` line to the appropriate rc file.
  The line is idempotent: re-running does not duplicate.

  --dry-run            Print what would change; make no changes.
  --shell <name>       Override shell detection.
  --claude-settings    Also write Claude Code settings.json fragment
                       (~/.config/claude/settings.json). Off by default.
EOF
}

oc_cmd_wire_up() {
  dry=0
  shell_override=""
  do_settings=0

  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run)
        dry=1
        shift
        ;;
      --shell)
        shell_override="$2"
        shift 2
        ;;
      --claude-settings)
        do_settings=1
        shift
        ;;
      -h | --help)
        _wireup_usage
        return 0
        ;;
      *)
        oc_log error "unknown flag: $1"
        _wireup_usage >&2
        return 2
        ;;
    esac
  done

  env_file="$(oc_config_home)/claude-code.env"
  [ -r "$env_file" ] || oc_die "env file not found: $env_file (run oc install first)"

  shell="$shell_override"
  if [ -z "$shell" ]; then
    case "${SHELL:-}" in
      *zsh*) shell="zsh" ;;
      *bash*) shell="bash" ;;
      *fish*) shell="fish" ;;
      *) shell="bash" ;;
    esac
  fi

  case "$shell" in
    bash) rc="$HOME/.bashrc" ;;
    zsh) rc="$HOME/.zshrc" ;;
    fish) rc="$HOME/.config/fish/config.fish" ;;
    powershell)
      oc_log info "for PowerShell, run: oc.ps1 wire-up"
      return 0
      ;;
    *) oc_die "unsupported shell: $shell" ;;
  esac

  line="source $env_file"
  [ "$shell" = "fish" ] && line="source $env_file"

  if [ -r "$rc" ] && grep -qF "$env_file" "$rc"; then
    oc_log ok "$rc already sources $env_file (no change)"
    return 0
  fi

  if [ "$dry" = "1" ]; then
    oc_log info "would append to $rc:"
    printf '  %s\n' "$line"
    return 0
  fi

  oc_confirm "Append to $rc?" yes || {
    oc_log warn "skipped wire-up"
    return 0
  }
  mkdir -p "$(dirname "$rc")"
  {
    printf '\n# ollama-claude: route Claude Code to local Ollama\n'
    printf '%s\n' "$line"
  } >> "$rc"
  oc_log ok "appended to $rc; open a new shell or 'source $rc' to apply"

  if [ "$do_settings" = "1" ]; then
    _wire_claude_settings
  fi
}

_wire_claude_settings() {
  settings_dir="${XDG_CONFIG_HOME:-$HOME/.config}/claude"
  settings_file="$settings_dir/settings.json"
  src="$OC_PROJECT_ROOT/config/claude-code.settings.example.json"
  mkdir -p "$settings_dir"
  if [ ! -r "$settings_file" ]; then
    cp "$src" "$settings_file"
    oc_log ok "wrote $settings_file (from example)"
    return 0
  fi
  oc_log warn "$settings_file exists; refusing to overwrite. Merge manually with $src."
}
