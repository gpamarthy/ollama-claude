# shellcheck shell=sh
# oc install — detect hardware, ensure Ollama is present, pull tier
# models, render the Claude Code wire-up file.

# shellcheck source=../../lib/log.sh
. "$OC_LIB_DIR/log.sh"
# shellcheck source=../../lib/ui.sh
. "$OC_LIB_DIR/ui.sh"
# shellcheck source=../../lib/detect.sh
. "$OC_LIB_DIR/detect.sh"
# shellcheck source=../../lib/config.sh
. "$OC_LIB_DIR/config.sh"
# shellcheck source=../../lib/ollama.sh
. "$OC_LIB_DIR/ollama.sh"
# shellcheck source=../../lib/hooks.sh
. "$OC_LIB_DIR/hooks.sh"
# shellcheck source=../../lib/claude.sh
. "$OC_LIB_DIR/claude.sh"

_install_usage() {
  cat <<'EOF'
USAGE
  oc install [--topology same|split-host|split-client]
             [--allow-from CIDR]     (split-host only)
             [--host HOST:PORT]      (split-client only)
             [--profile NAME]        (default | security-research | data-science | web-dev | minimalist | team)
             [--skip-pull]           (set up config but don't pull models)
             [--yes]                 (assume yes for all prompts)

ENV VAR OVERRIDES
  OC_TOPOLOGY, OC_ALLOW_FROM, OC_HOST, OC_PROFILE, OC_SKIP_PULL=1, OC_ASSUME_YES=1
EOF
}

oc_cmd_install() {
  topology="${OC_TOPOLOGY:-}"
  allow_from="${OC_ALLOW_FROM:-}"
  remote_host="${OC_HOST:-}"
  profile="${OC_PROFILE:-default}"
  skip_pull="${OC_SKIP_PULL:-0}"

  while [ $# -gt 0 ]; do
    case "$1" in
      --topology)      topology="$2"; shift 2 ;;
      --allow-from)    allow_from="$2"; shift 2 ;;
      --host)          remote_host="$2"; shift 2 ;;
      --profile)       profile="$2"; shift 2 ;;
      --skip-pull)     skip_pull=1; shift ;;
      --yes|-y)        export OC_ASSUME_YES=1; shift ;;
      -h|--help)       _install_usage; return 0 ;;
      *)               oc_log error "unknown flag: $1"; _install_usage >&2; return 2 ;;
    esac
  done

  oc_log step "Detecting hardware"
  oc_detect
  oc_detect_report

  # Existing-install detection (plan §8.5)
  if _existing_install_present; then
    oc_log info "pre-existing Ollama install detected — keeping & supplementing (no overwrite)"
    if ! oc_confirm "Continue?" yes; then
      oc_log warn "aborting per user choice"
      return 1
    fi
  fi

  # Topology resolution: flag > env > TTY prompt > error
  if [ -z "$topology" ]; then
    if oc_is_tty; then
      topology=$(oc_select "Select topology" "same" "same" "split-host" "split-client")
    else
      topology="same"
      oc_log info "no topology specified, defaulting to 'same' (non-interactive)"
    fi
  fi

  case "$topology" in
    same|split-host|split-client) ;;
    *) oc_die "invalid topology: $topology" ;;
  esac

  oc_log step "Profile: $profile"
  oc_log step "Topology: $topology"

  oc_run_hook pre-install

  # Topology-specific install path
  case "$topology" in
    same)         _install_same ;;
    split-host)   _install_split_host "$allow_from" ;;
    split-client) _install_split_client "$remote_host" ;;
  esac

  if [ "$skip_pull" != "1" ] && [ "$topology" != "split-client" ]; then
    _pull_tier_models "$profile"
  fi

  _persist_state "$topology" "$profile"
  _write_claude_env "$topology" "$remote_host"

  oc_run_hook post-install

  oc_log step "Setup complete"
  printf '\nNext steps:\n'
  printf '  source %s/claude-code.env\n' "$(oc_config_home)"
  printf '  claude     # Claude Code now talks to local Ollama\n\n'
  printf 'To make sourcing permanent: oc wire-up (review with --dry-run first)\n'
}

_existing_install_present() {
  command -v ollama >/dev/null 2>&1 && return 0
  [ -e /etc/systemd/system/ollama.service ] && return 0
  [ -d /etc/ollama ] && return 0
  [ -d "$HOME/.ollama" ] && return 0
  [ -d "/c/ProgramData/Ollama" ] && return 0
  return 1
}

_install_same() {
  if ! oc_ollama_installed; then
    oc_ollama_install_upstream || oc_die "Ollama install failed"
  else
    oc_log ok "Ollama already installed ($(oc_ollama_version || echo unknown))"
  fi
  if ! oc_ollama_version_ok; then
    oc_log warn "Ollama < $OLLAMA_MIN_VERSION; Anthropic-compatible endpoint may not be present"
    oc_log warn "consider: ollama --version; upgrade via your package manager"
  fi
}

_install_split_host() {
  cidr="$1"
  if [ -z "$cidr" ]; then
    if oc_is_tty; then
      cidr=$(oc_ask "Allowed CIDR (e.g. 192.168.56.0/24)" "")
    fi
  fi
  [ -n "$cidr" ] || oc_die "split-host requires --allow-from CIDR (or OC_ALLOW_FROM env)"
  _install_same
  oc_log info "split-host: would bind 0.0.0.0:11434 and scope firewall to $cidr"
  oc_log info "firewall provisioning runs in platform/linux/ufw-allow.sh or platform/windows/firewall.ps1"
}

_install_split_client() {
  host="$1"
  [ -n "$host" ] || oc_die "split-client requires --host HOST:PORT (or OC_HOST env)"
  oc_log info "split-client: no Ollama install; wire-up will point at $host"
}

_pull_tier_models() {
  profile="$1"
  models_file="$OC_PROJECT_ROOT/config/models.toml"
  oc_log step "Resolving models for tier '$OC_TIER'"

  for role in fast tools heavy; do
    tag=$(oc_resolve_model "$models_file" "$OC_TIER" "$role")
    if [ -z "$tag" ]; then
      oc_log info "role '$role' is skipped on tier '$OC_TIER'"
      continue
    fi
    if [ "$profile" = "minimalist" ] && { [ "$role" = "tools" ] || [ "$role" = "heavy" ]; }; then
      oc_log info "minimalist profile: skipping role '$role'"
      continue
    fi
    OC_MODEL="$tag" OC_ROLE="$role" oc_run_hook pre-pull
    if oc_ollama_pull "$tag"; then
      digest=$(oc_ollama_digest "$tag")
      OC_MODEL="$tag" OC_ROLE="$role" OC_DIGEST="$digest" oc_run_hook post-pull
    else
      oc_log warn "could not pull $tag; continuing"
    fi
  done
}

_persist_state() {
  topology="$1"
  profile="$2"
  state_dir="$(oc_config_home)"
  mkdir -p "$state_dir"
  printf '%s\n' "$topology" > "$state_dir/topology"
  printf '%s\n' "$profile"  > "$state_dir/profile"
}

_write_claude_env() {
  topology="$1"
  remote_host="$2"
  case "$topology" in
    same)         base_url="http://127.0.0.1:11434" ;;
    split-host)   base_url="http://127.0.0.1:11434" ;;   # served locally; client points elsewhere
    split-client) base_url="http://$remote_host"   ;;
  esac
  out=$(oc_render_claude_env "$base_url")
  oc_log ok "wrote $out"
}
