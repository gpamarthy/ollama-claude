# shellcheck shell=sh
# oc version — print version info.

oc_cmd_version() {
  printf 'ollama-claude %s\n' "$OC_VERSION"
  if command -v ollama > /dev/null 2>&1; then
    ov=$(ollama --version 2> /dev/null | head -n1)
    printf 'ollama        %s\n' "$ov"
  else
    printf 'ollama        not installed\n'
  fi
  printf 'release notes https://github.com/gpamarthy/ollama-claude/releases\n'
}
