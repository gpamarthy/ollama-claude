# shellcheck shell=sh
# oc models - list, override, or pin the role->tag map.

# shellcheck source=../../lib/log.sh
. "$OC_LIB_DIR/log.sh"
# shellcheck source=../../lib/detect.sh
. "$OC_LIB_DIR/detect.sh"
# shellcheck source=../../lib/config.sh
. "$OC_LIB_DIR/config.sh"
# shellcheck source=../../lib/ollama.sh
. "$OC_LIB_DIR/ollama.sh"

_models_usage() {
  cat << 'EOF'
USAGE
  oc models                      List current role->tag map for detected tier
  oc models set <role> <tag>     Override the tag for a role in the global config
  oc models reset <role>         Remove an override
  oc models pin                  Write digest pins to .ollama-claude.toml in cwd
EOF
}

oc_cmd_models() {
  oc_detect
  models_file="$OC_PROJECT_ROOT/config/models.toml"

  case "${1:-list}" in
    list)
      printf 'Tier: %s\n' "$OC_TIER"
      for role in fast tools heavy; do
        tag=$(oc_resolve_model "$models_file" "$OC_TIER" "$role")
        if [ -z "$tag" ]; then
          printf '  %-7s (skipped)\n' "$role"
        else
          printf '  %-7s %s\n' "$role" "$tag"
        fi
      done
      ;;
    set)
      role="${2:-}"
      tag="${3:-}"
      [ -n "$role" ] && [ -n "$tag" ] || {
        _models_usage
        return 2
      }
      cfg="$(oc_config_home)/config.toml"
      mkdir -p "$(dirname "$cfg")"
      if [ ! -r "$cfg" ]; then
        printf '[overrides]\n' > "$cfg"
      fi
      # Append (idempotent: remove any existing override for this role first)
      tmp=$(mktemp 2> /dev/null || echo /tmp/oc-models.tmp)
      grep -v "^${role}[[:space:]]*=" "$cfg" > "$tmp" || true
      mv "$tmp" "$cfg"
      printf '%s = "%s"\n' "$role" "$tag" >> "$cfg"
      oc_log ok "set $role = $tag in $cfg"
      ;;
    reset)
      role="${2:-}"
      [ -n "$role" ] || {
        _models_usage
        return 2
      }
      cfg="$(oc_config_home)/config.toml"
      [ -r "$cfg" ] || return 0
      tmp=$(mktemp 2> /dev/null || echo /tmp/oc-models.tmp)
      grep -v "^${role}[[:space:]]*=" "$cfg" > "$tmp" || true
      mv "$tmp" "$cfg"
      oc_log ok "removed override for $role"
      ;;
    pin)
      proj="$PWD/.ollama-claude.toml"
      [ -r "$proj" ] || oc_die "no .ollama-claude.toml in $PWD"
      tmp=$(mktemp 2> /dev/null || echo /tmp/oc-pin.tmp)
      cp "$proj" "$tmp"
      for role in fast tools heavy; do
        tag=$(oc_resolve_model "$models_file" "$OC_TIER" "$role")
        [ -n "$tag" ] || continue
        digest=$(oc_ollama_digest "$tag" 2> /dev/null || echo "")
        [ -n "$digest" ] || {
          oc_log warn "no local digest for $tag (run ollama pull first)"
          continue
        }
        {
          printf '\n[[models]]\n'
          printf 'name     = "%s"\n' "$tag"
          printf 'provider = "ollama"\n'
          printf 'roles    = ["%s"]\n' "$role"
          printf 'digest   = "%s"\n' "$digest"
        } >> "$tmp"
      done
      mv "$tmp" "$proj"
      oc_log ok "pinned digests in $proj"
      ;;
    -h | --help)
      _models_usage
      ;;
    *)
      _models_usage >&2
      return 2
      ;;
  esac
}
