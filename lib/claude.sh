# shellcheck shell=sh
# Generate Claude Code wire-up artefacts (env file, optional settings).

# shellcheck source=./log.sh
. "$OC_LIB_DIR/log.sh"
# shellcheck source=./config.sh
. "$OC_LIB_DIR/config.sh"

# Render the claude-code.env file for the given base URL.
# Honours OC_ANTHROPIC_API_KEY_FORM=unset|empty to control the third line.
oc_render_claude_env() {
  base_url="$1"
  out="${2:-$(oc_config_home)/claude-code.env}"
  mkdir -p "$(dirname "$out")"
  template="$OC_PROJECT_ROOT/config/claude-code.env.template"
  [ -r "$template" ] || oc_die "missing template: $template"

  api_key_line='unset ANTHROPIC_API_KEY'
  if [ "${OC_ANTHROPIC_API_KEY_FORM:-unset}" = "empty" ]; then
    api_key_line='export ANTHROPIC_API_KEY=""'
  fi

  sed \
    -e "s|__BASE_URL__|$base_url|g" \
    -e "s|^unset ANTHROPIC_API_KEY\$|$api_key_line|g" \
    "$template" > "$out"
  chmod 0600 "$out"
  printf '%s' "$out"
}

# Determine current wire-up state by probing the active shell rc files.
# Returns one of: missing, sourced, wired
oc_claude_wireup_state() {
  env_file="$(oc_config_home)/claude-code.env"
  if [ ! -r "$env_file" ]; then
    printf 'missing'
    return 0
  fi
  for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
    [ -r "$rc" ] || continue
    if grep -qF "$env_file" "$rc" 2>/dev/null; then
      printf 'wired'
      return 0
    fi
  done
  printf 'sourced'
}

# Determine "switch state": local | cloud | unknown
oc_claude_switch_state() {
  # We can only inspect what's exported in the parent shell. Best effort:
  # if claude-code.env has been sourced and ANTHROPIC_BASE_URL is set to
  # our value, we're local. Otherwise unknown.
  if [ -n "${ANTHROPIC_BASE_URL:-}" ]; then
    case "$ANTHROPIC_BASE_URL" in
      *127.0.0.1*|*localhost*) printf 'local' ;;
      *) printf 'cloud' ;;
    esac
  else
    printf 'cloud'
  fi
}
