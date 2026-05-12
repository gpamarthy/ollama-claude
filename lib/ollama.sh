# shellcheck shell=sh
# Ollama install / start / pull wrappers. Idempotent, digest-verifying.

# shellcheck source=./log.sh
. "$OC_LIB_DIR/log.sh"

OLLAMA_INSTALL_URL="${OLLAMA_INSTALL_URL:-https://ollama.com/install.sh}"
OLLAMA_MIN_VERSION="${OC_OLLAMA_MIN_VERSION:-0.14.0}"

oc_ollama_installed() {
  command -v ollama >/dev/null 2>&1
}

oc_ollama_version() {
  oc_ollama_installed || return 1
  ollama --version 2>/dev/null | awk '{for(i=1;i<=NF;i++)if($i~/^[0-9]+\./){print $i;exit}}'
}

# Returns 0 if installed version >= OLLAMA_MIN_VERSION
oc_ollama_version_ok() {
  v=$(oc_ollama_version) || return 1
  awk -v a="$v" -v b="$OLLAMA_MIN_VERSION" '
    BEGIN {
      n = split(a, av, ".")
      m = split(b, bv, ".")
      max = (n > m) ? n : m
      for (i = 1; i <= max; i++) {
        ai = (i <= n) ? av[i] + 0 : 0
        bi = (i <= m) ? bv[i] + 0 : 0
        if (ai > bi) { exit 0 }
        if (ai < bi) { exit 1 }
      }
      exit 0
    }
  '
}

# Install Ollama via upstream installer (Linux/macOS).
oc_ollama_install_upstream() {
  case "$OC_OS" in
    linux|macos)
      oc_log step "installing Ollama from $OLLAMA_INSTALL_URL"
      tmp=$(mktemp 2>/dev/null || echo /tmp/ollama-install.sh)
      if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$OLLAMA_INSTALL_URL" -o "$tmp" || oc_die "failed to download Ollama installer"
      elif command -v wget >/dev/null 2>&1; then
        wget -qO "$tmp" "$OLLAMA_INSTALL_URL" || oc_die "failed to download Ollama installer"
      else
        oc_die "neither curl nor wget available; cannot install Ollama"
      fi

      # Pin the upstream installer when checksums.toml provides one.
      if [ -r "$OC_PROJECT_ROOT/config/checksums.toml" ]; then
        expected=$(awk -F'"' '/ollama_install_sh/ {print $2; exit}' \
          "$OC_PROJECT_ROOT/config/checksums.toml" 2>/dev/null)
        if [ -n "$expected" ]; then
          actual=$(sha256sum "$tmp" 2>/dev/null | awk '{print $1}')
          if [ "$expected" != "$actual" ]; then
            oc_log warn "Ollama installer checksum mismatch (expected $expected got $actual)"
            oc_log warn "this can mean an upstream update; verify and refresh config/checksums.toml"
            return 1
          fi
        fi
      fi

      sh "$tmp" || oc_die "Ollama installer failed"
      rm -f "$tmp"
      ;;
    *)
      oc_die "unsupported OS for upstream Ollama install: $OC_OS"
      ;;
  esac
}

# Check whether a tag exists in the local Ollama or registry.
oc_ollama_tag_present_locally() {
  ollama list 2>/dev/null | awk 'NR>1 {print $1}' | grep -Fxq "$1"
}

oc_ollama_tag_exists() {
  # `ollama show` returns non-zero for an unknown tag; pulls aren't triggered.
  ollama show "$1" >/dev/null 2>&1
}

# Pull a model with digest verification. Retries with exponential backoff.
oc_ollama_pull() {
  tag="$1"
  [ -n "$tag" ] || return 0
  if oc_ollama_tag_present_locally "$tag"; then
    oc_log ok "model already present: $tag"
    return 0
  fi

  attempt=1
  max=3
  delay=10
  while [ "$attempt" -le "$max" ]; do
    oc_log info "pulling $tag (attempt $attempt/$max)"
    if ollama pull "$tag"; then
      if oc_ollama_tag_exists "$tag"; then
        oc_log ok "pulled: $tag"
        return 0
      fi
      oc_log warn "$tag pulled but show failed; retrying"
    else
      oc_log warn "$tag pull failed; retrying in ${delay}s"
    fi
    sleep "$delay"
    attempt=$((attempt + 1))
    delay=$((delay * 2))
  done
  oc_log error "giving up on $tag after $max attempts"
  return 1
}

# Get a model's digest (sha256:...) from `ollama show --modelfile` output.
oc_ollama_digest() {
  tag="$1"
  ollama show "$tag" --modelfile 2>/dev/null | awk '/^FROM[[:space:]]+sha256:/ {print $2; exit}'
}

# Check that Ollama is serving on the configured host (or 127.0.0.1).
oc_ollama_ping() {
  host="${1:-127.0.0.1:11434}"
  if command -v curl >/dev/null 2>&1; then
    curl -fs "http://$host/api/tags" >/dev/null 2>&1
  else
    return 1
  fi
}
