# shellcheck shell=sh
# oc status — show health and current state.

# shellcheck source=../../lib/log.sh
. "$OC_LIB_DIR/log.sh"
# shellcheck source=../../lib/detect.sh
. "$OC_LIB_DIR/detect.sh"
# shellcheck source=../../lib/config.sh
. "$OC_LIB_DIR/config.sh"
# shellcheck source=../../lib/ollama.sh
. "$OC_LIB_DIR/ollama.sh"
# shellcheck source=../../lib/claude.sh
. "$OC_LIB_DIR/claude.sh"

oc_cmd_status() {
  printf 'ollama-claude %s\n\n' "$OC_VERSION"

  printf 'Hardware\n'
  oc_detect
  oc_detect_report

  printf '\nOllama\n'
  if oc_ollama_installed; then
    v=$(oc_ollama_version || echo unknown)
    printf '  Version:           %s\n' "$v"
    if oc_ollama_ping "127.0.0.1:11434"; then
      printf '  Service:           reachable on 127.0.0.1:11434\n'
    else
      printf '  Service:           not reachable on 127.0.0.1:11434\n'
    fi
    n=$(ollama list 2> /dev/null | awk 'NR>1' | wc -l | tr -d ' ')
    printf '  Models present:    %s\n' "$n"
  else
    printf '  Not installed.\n'
  fi

  printf '\nConfiguration\n'
  topology_file="$(oc_config_home)/topology"
  profile_file="$(oc_config_home)/profile"
  if [ -r "$topology_file" ]; then
    printf '  Topology:          %s\n' "$(cat "$topology_file")"
  else
    printf '  Topology:          not configured\n'
  fi
  if [ -r "$profile_file" ]; then
    printf '  Profile:           %s\n' "$(cat "$profile_file")"
  fi

  printf '\nClaude Code\n'
  printf '  Wire-up state:     %s\n' "$(oc_claude_wireup_state)"
  printf '  Env file says:     %s\n' "$(oc_claude_file_state)"
  printf '  Current shell:     %s\n' "$(oc_claude_switch_state)"
}
