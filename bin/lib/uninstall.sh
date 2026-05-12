# shellcheck shell=sh
# oc uninstall — remove configs (and optionally models / Ollama binary).

# shellcheck source=../../lib/log.sh
. "$OC_LIB_DIR/log.sh"
# shellcheck source=../../lib/config.sh
. "$OC_LIB_DIR/config.sh"
# shellcheck source=../../lib/ui.sh
. "$OC_LIB_DIR/ui.sh"

_uninstall_usage() {
  cat << 'EOF'
USAGE
  oc uninstall              Remove ollama-claude configs only
  oc uninstall --purge      ... and remove pulled Ollama models
  oc uninstall --all        ... and remove the Ollama binary itself

The user's shell rc is NOT modified; remove the `source ~/.config/ollama-claude/claude-code.env`
line manually if you wired up. (We never auto-edit dotfiles.)
EOF
}

oc_cmd_uninstall() {
  purge=0
  all=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --purge)
        purge=1
        shift
        ;;
      --all)
        all=1
        purge=1
        shift
        ;;
      -h | --help)
        _uninstall_usage
        return 0
        ;;
      *)
        _uninstall_usage >&2
        return 2
        ;;
    esac
  done

  oc_confirm "Remove ollama-claude configs at $(oc_config_home)?" yes || return 0
  rm -rf "$(oc_config_home)"
  rm -rf "$(oc_state_home)"
  oc_log ok "configs and state removed"

  if [ "$purge" = "1" ]; then
    if command -v ollama > /dev/null 2>&1; then
      oc_confirm "Remove all pulled Ollama models?" no || return 0
      ollama list 2> /dev/null | awk 'NR>1 {print $1}' | while IFS= read -r tag; do
        [ -n "$tag" ] && ollama rm "$tag" 2> /dev/null || true
      done
      oc_log ok "models removed"
    fi
  fi

  if [ "$all" = "1" ]; then
    oc_log warn "removal of the Ollama binary itself depends on how it was installed"
    oc_log info "  systemd: sudo systemctl stop ollama; sudo systemctl disable ollama"
    oc_log info "  Linux:   sudo rm -f /usr/local/bin/ollama /etc/systemd/system/ollama.service"
    oc_log info "  macOS:   brew uninstall ollama (or remove /usr/local/bin/ollama)"
    oc_log info "  Windows: winget uninstall Ollama.Ollama (or use Settings > Apps)"
  fi
}
