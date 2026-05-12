#!/bin/sh
# ollama-claude installer entrypoint for Linux and macOS.
#
# This script is safe to pipe from curl:
#     curl -fsSL https://raw.githubusercontent.com/gpamarthy/ollama-claude/main/install.sh | sh
#
# What it does:
#   1. Re-execs itself under bash if we landed in dash or another POSIX-only shell.
#   2. Picks an install method: from a tagged GitHub release tarball (preferred)
#      or a git clone if we're already inside a checkout.
#   3. Unpacks to ~/.local/share/ollama-claude/<version>/, symlinks ~/.local/bin/oc.
#   4. Runs `oc install` non-interactively with safe defaults.
#
# Honoured env vars:
#   OC_VERSION_PIN      Specific version to install (default: latest release)
#   OC_INSTALL_PREFIX   Override install root (default: ~/.local/share/ollama-claude)
#   OC_LINK_DIR         Override symlink dir   (default: ~/.local/bin)
#   OC_ASSUME_YES       Skip prompts (default: 1 when not on a TTY)
#   OC_SKIP_BOOTSTRAP   Don't run `oc install` at the end

set -eu

# ---- bash re-exec --------------------------------------------------------
# install.sh is POSIX-portable enough for sh, but several upgrades (arrays,
# `local`, process substitution) make bash strictly easier. If we are not
# already in bash and bash exists, re-exec there.
if [ -z "${BASH_VERSION:-}" ] && command -v bash > /dev/null 2>&1; then
  exec bash "$0" "$@"
fi

REPO_OWNER="${OC_REPO_OWNER:-gpamarthy}"
REPO_NAME="${OC_REPO_NAME:-ollama-claude}"
PREFIX="${OC_INSTALL_PREFIX:-$HOME/.local/share/ollama-claude}"
LINK_DIR="${OC_LINK_DIR:-$HOME/.local/bin}"
VERSION_PIN="${OC_VERSION_PIN:-}"

[ -t 0 ] || OC_ASSUME_YES="${OC_ASSUME_YES:-1}"

err() {
  printf '[err ] %s\n' "$*" >&2
  exit 1
}
log() { printf '[info] %s\n' "$*"; }
ok() { printf '[ ok ] %s\n' "$*"; }

# ---- prerequisites -------------------------------------------------------
for tool in curl tar; do
  command -v "$tool" > /dev/null 2>&1 || err "missing prerequisite: $tool"
done

# ---- pick a fetch strategy -----------------------------------------------
# If we're inside a repo checkout already (developer / contributor mode),
# just symlink the current dir. Otherwise pull a release tarball.
script_dir=""
case "$0" in
  /*) script_dir=$(dirname "$0") ;;
  *) case "$(pwd)" in *) script_dir="$(pwd)/$(dirname "$0")" ;; esac ;;
esac

if [ -d "$script_dir/bin" ] && [ -d "$script_dir/lib" ] && [ -r "$script_dir/bin/oc" ]; then
  log "running from checkout at $script_dir"
  install_from_checkout=1
  src_dir=$(cd "$script_dir" && pwd)
else
  install_from_checkout=0
fi

# ---- resolve latest version ---------------------------------------------
resolve_version() {
  if [ -n "$VERSION_PIN" ]; then
    printf '%s' "$VERSION_PIN"
    return 0
  fi
  api="https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest"
  resp=$(curl -fsSL "$api" 2> /dev/null || true)
  tag=$(printf '%s' "$resp" | awk -F'"' '/"tag_name":/ {print $4; exit}')
  if [ -z "$tag" ]; then
    err "no releases yet for $REPO_OWNER/$REPO_NAME and no OC_VERSION_PIN provided
            (this is expected before v0.1.0 is tagged - clone the repo and re-run for now)"
  fi
  printf '%s' "$tag"
}

# ---- install -------------------------------------------------------------
mkdir -p "$PREFIX" "$LINK_DIR"

if [ "$install_from_checkout" = "1" ]; then
  version="dev-$(date -u +%Y%m%d)"
  dest="$PREFIX/$version"
  log "linking checkout into $dest"
  mkdir -p "$(dirname "$dest")"
  rm -rf "$dest"
  ln -s "$src_dir" "$dest"
else
  version=$(resolve_version)
  log "installing version $version"
  tarball="ollama-claude-$version.tar.gz"
  url="https://github.com/$REPO_OWNER/$REPO_NAME/releases/download/$version/$tarball"
  sums_url="https://github.com/$REPO_OWNER/$REPO_NAME/releases/download/$version/SHA256SUMS"

  workdir=$(mktemp -d 2> /dev/null || echo "/tmp/oc-install.$$")
  trap 'rm -rf "$workdir"' EXIT INT TERM

  log "fetching $tarball"
  curl -fsSL -o "$workdir/$tarball" "$url" || err "download failed: $url"

  log "fetching SHA256SUMS"
  if curl -fsSL -o "$workdir/SHA256SUMS" "$sums_url"; then
    expected=$(awk -v t="$tarball" '$2 == t {print $1; exit}' "$workdir/SHA256SUMS")
    if [ -n "$expected" ]; then
      actual=$(sha256sum "$workdir/$tarball" 2> /dev/null | awk '{print $1}')
      if [ -z "$actual" ]; then
        actual=$(shasum -a 256 "$workdir/$tarball" | awk '{print $1}')
      fi
      [ "$expected" = "$actual" ] || err "checksum mismatch for $tarball"
      ok "checksum verified"
    fi
  else
    log "no SHA256SUMS published; continuing without verification (Phase 1 transitional)"
  fi

  dest="$PREFIX/$version"
  rm -rf "$dest"
  mkdir -p "$dest"
  tar -xzf "$workdir/$tarball" -C "$dest" --strip-components=1
fi

# ---- symlink dispatcher --------------------------------------------------
target="$dest/bin/oc"
[ -x "$target" ] || chmod +x "$target" 2> /dev/null || err "$target missing"
ln -sf "$target" "$LINK_DIR/oc"
ok "linked $LINK_DIR/oc -> $target"

case ":$PATH:" in
  *":$LINK_DIR:"*) ;;
  *)
    log ""
    log "NOTE: $LINK_DIR is not on PATH. Add it to your shell rc:"
    log "  export PATH=\"$LINK_DIR:\$PATH\""
    log ""
    ;;
esac

# ---- bootstrap -----------------------------------------------------------
if [ "${OC_SKIP_BOOTSTRAP:-0}" = "1" ]; then
  ok "skipping bootstrap (OC_SKIP_BOOTSTRAP=1)"
  exit 0
fi

log "running: oc install"
"$LINK_DIR/oc" install || err "oc install failed"

ok ""
ok "Setup complete."
printf '\nNext steps:\n'
printf '  source ~/.config/ollama-claude/claude-code.env\n'
printf '  claude     # Claude Code now talks to local Ollama\n\n'
printf 'To make sourcing permanent: oc wire-up\n'
