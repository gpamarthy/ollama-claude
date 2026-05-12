# shellcheck shell=sh
# oc sync - apply .ollama-claude.toml from cwd over the global config.

# shellcheck source=../../lib/log.sh
. "$OC_LIB_DIR/log.sh"
# shellcheck source=../../lib/config.sh
. "$OC_LIB_DIR/config.sh"

oc_cmd_sync() {
  proj=""
  for dir in . .. ../.. ../../..; do
    if [ -r "$dir/.ollama-claude.toml" ]; then
      proj="$dir/.ollama-claude.toml"
      break
    fi
  done
  [ -n "$proj" ] || oc_die "no .ollama-claude.toml found in cwd or parents"

  oc_log step "syncing from $proj"

  # MVP: read topology + profile + pinned models, run oc install accordingly.
  topology=$(oc_toml_get "$proj" topology.default 2> /dev/null || echo "")
  profile=$(oc_toml_get "$proj" active.profile 2> /dev/null || echo "")

  set -- install
  [ -n "$topology" ] && set -- "$@" --topology "$topology"
  [ -n "$profile" ] && set -- "$@" --profile "$profile"

  "$OC_BIN_DIR/oc" "$@"
}
