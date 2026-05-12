# shellcheck shell=sh
# oc topology — read or set the active topology.

# shellcheck source=../../lib/log.sh
. "$OC_LIB_DIR/log.sh"
# shellcheck source=../../lib/config.sh
. "$OC_LIB_DIR/config.sh"

_topology_usage() {
  cat <<'EOF'
USAGE
  oc topology                                 Show active topology
  oc topology same                            Switch to same-machine
  oc topology split-host --allow-from CIDR    Switch to split-host (Ollama serves LAN)
  oc topology split-client --host HOST:PORT   Switch to split-client (no Ollama install)
EOF
}

oc_cmd_topology() {
  topology_file="$(oc_config_home)/topology"

  if [ $# -eq 0 ]; then
    if [ -r "$topology_file" ]; then
      cat "$topology_file"
    else
      printf 'not configured\n'
    fi
    return 0
  fi

  mode="$1"; shift || true
  case "$mode" in
    same|split-host|split-client) ;;
    -h|--help) _topology_usage; return 0 ;;
    *) oc_log error "invalid topology: $mode"; _topology_usage >&2; return 2 ;;
  esac

  # Re-run install with the new topology
  set -- install --topology "$mode" "$@"
  exec "$OC_BIN_DIR/oc" "$@"
}
