# shellcheck shell=sh
# Minimal TOML reader for the small subset of TOML this project uses.
# Not a full parser: handles top-level key=value pairs and named tables
# like [tier.mid]. Sufficient for ollama-claude config; if a user wants
# advanced TOML they should override values via env vars or wait for
# Phase 2 (Go binary with a real parser).

# Read a scalar key from a (possibly tabled) TOML file.
# Usage: value=$(oc_toml_get path/to/file.toml table.key)
# Example: oc_toml_get models.toml tier.mid.heavy
oc_toml_get() {
  file="$1"
  path="$2"
  [ -r "$file" ] || return 1

  # Split the path into a section prefix and a leaf key.
  # tier.mid.heavy -> section=tier.mid, leaf=heavy
  case "$path" in
    *.*)
      section="${path%.*}"
      leaf="${path##*.}"
      ;;
    *)
      section=""
      leaf="$path"
      ;;
  esac

  awk -v sec="$section" -v key="$leaf" '
    BEGIN { in_sec = (sec == "") ? 1 : 0; found = 0 }
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*\[/ {
      header = $0
      gsub(/^[[:space:]]*\[\[?|]\]?[[:space:]]*$/, "", header)
      if (header == sec) { in_sec = 1 } else { in_sec = 0 }
      next
    }
    in_sec && $0 ~ ("^[[:space:]]*" key "[[:space:]]*=") {
      sub("^[[:space:]]*" key "[[:space:]]*=[[:space:]]*", "")
      sub(/[[:space:]]*#.*$/, "")
      sub(/^"/, ""); sub(/"$/, "")
      print
      found = 1
      exit
    }
    END { exit (found ? 0 : 1) }
  ' "$file"
}

# Resolve the role->tag for a tier from models.toml, walking one row
# down on miss. Empty string ("") is treated as "intentionally skipped"
# and returned as-is.
#
# Resolution order:
#   1. User override in ~/.config/ollama-claude/config.toml [overrides]
#   2. Tier-specific tag from models.toml
#   3. Walk down to lower tiers
#   4. Last-resort fallback.tag
oc_resolve_model() {
  models_file="$1"
  tier="$2"
  role="$3"

  # 1. User override wins
  user_cfg="$(oc_config_home)/config.toml"
  if [ -r "$user_cfg" ]; then
    override=$(oc_toml_get "$user_cfg" "overrides.$role" 2>/dev/null || true)
    if [ -n "${override:-}" ]; then
      printf '%s' "$override"
      return 0
    fi
  fi

  # 2-3. Tier-specific, walking down
  found_tier=0
  for t in workstation high mid low cpu; do
    if [ "$t" = "$tier" ]; then
      found_tier=1
    fi
    if [ "$found_tier" = "1" ]; then
      val=$(oc_toml_get "$models_file" "tier.$t.$role" 2>/dev/null || true)
      # If the key exists at all, the awk script either prints a value
      # or prints empty (for `key = ""`). Distinguish "key exists, empty"
      # from "key not found" by checking the awk exit code path.
      if oc_toml_get "$models_file" "tier.$t.$role" >/dev/null 2>&1; then
        printf '%s' "$val"
        return 0
      fi
    fi
  done

  # 4. Last-resort fallback
  oc_toml_get "$models_file" "fallback.tag"
}

# Check whether a tag supports tool-calling per models.toml [[tags]] table.
oc_tag_supports_tools() {
  models_file="$1"
  tag="$2"

  awk -v tag="$tag" '
    /^\[\[tags\]\]/ { current=""; ok=""; next }
    /^[[:space:]]*name[[:space:]]*=/ {
      sub(/^[[:space:]]*name[[:space:]]*=[[:space:]]*"/, "")
      sub(/"[[:space:]]*$/, "")
      current=$0
    }
    /^[[:space:]]*supports_tools[[:space:]]*=/ {
      sub(/^[[:space:]]*supports_tools[[:space:]]*=[[:space:]]*/, "")
      sub(/[[:space:]]*#.*$/, "")
      ok=$0
    }
    current == tag && ok != "" {
      print ok
      exit
    }
  ' "$models_file"
}

# Path helpers
oc_config_home() {
  printf '%s/ollama-claude' "${XDG_CONFIG_HOME:-$HOME/.config}"
}

oc_state_home() {
  printf '%s/ollama-claude' "${XDG_STATE_HOME:-$HOME/.local/state}"
}
