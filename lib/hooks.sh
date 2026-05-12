# shellcheck shell=sh
# Run user-defined lifecycle hooks. Hook scripts live in:
#   ~/.config/ollama-claude/hooks/<name>           (global)
#   <project-root>/.ollama-claude/hooks/<name>     (project)
# Both run if both exist (global first, then project). Hooks receive
# the OC_* environment passed by the caller.

# shellcheck source=./log.sh
. "$OC_LIB_DIR/log.sh"
# shellcheck source=./config.sh
. "$OC_LIB_DIR/config.sh"

oc_run_hook() {
  name="$1"
  shift
  global_dir="$(oc_config_home)/hooks"
  project_dir="${OC_PROJECT_TOML_DIR:-}/.ollama-claude/hooks"
  for dir in "$global_dir" "$project_dir"; do
    [ -d "$dir" ] || continue
    script="$dir/$name"
    if [ -x "$script" ]; then
      oc_log debug "hook: $script"
      OC_HOOK_NAME="$name" "$script" "$@" || oc_log warn "hook $name in $dir exited $?"
    fi
  done
}
