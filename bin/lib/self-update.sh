# shellcheck shell=sh
# oc self-update — fetch and verify a newer release tarball.

# shellcheck source=../../lib/log.sh
. "$OC_LIB_DIR/log.sh"

_self_update_usage() {
  cat << 'EOF'
USAGE
  oc self-update                Fetch latest release; activate it
  oc self-update --to <version> Pin to a specific version
  oc self-update --gc           Remove inactive prior versions
  oc self-update --check        Print latest available without changing anything
EOF
}

oc_cmd_self_update() {
  oc_log info "self-update: stub for Phase 1; will be filled in once releases exist on GitHub"
  oc_log info "today, update by re-running install.sh"
}
