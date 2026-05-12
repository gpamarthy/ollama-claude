# shellcheck shell=sh
# Prompts and confirmation helpers. Designed to fail closed when stdin
# is not a TTY (e.g. curl|sh piped install) — caller must supply env vars
# or flags instead.

# Returns 0 if stdin is connected to a TTY.
oc_is_tty() {
  [ -t 0 ]
}

# Ask a yes/no question. Usage: oc_confirm "Continue?" yes|no
# Honours OC_ASSUME_YES=1 for non-interactive mode (defaults to second arg).
oc_confirm() {
  prompt="$1"
  default="${2:-no}"
  if [ "${OC_ASSUME_YES:-0}" = "1" ]; then
    [ "$default" = "yes" ] && return 0
    [ "$default" = "yes" ] || return 0   # assume yes always when flag set
  fi
  if ! oc_is_tty; then
    case "$default" in
      yes) return 0 ;;
      *)   return 1 ;;
    esac
  fi
  case "$default" in
    yes) hint='[Y/n]' ;;
    *)   hint='[y/N]' ;;
  esac
  printf '%s %s ' "$prompt" "$hint"
  read -r reply || reply=''
  case "$reply" in
    [Yy]|[Yy][Ee][Ss]) return 0 ;;
    [Nn]|[Nn][Oo])     return 1 ;;
    '')
      [ "$default" = "yes" ] && return 0 || return 1
      ;;
    *)
      [ "$default" = "yes" ] && return 0 || return 1
      ;;
  esac
}

# Prompt for a value with a default. Returns the value on stdout.
# Usage: choice=$(oc_ask "Topology" "same")
oc_ask() {
  prompt="$1"
  default="${2:-}"
  if ! oc_is_tty; then
    printf '%s' "$default"
    return 0
  fi
  if [ -n "$default" ]; then
    printf '%s [%s]: ' "$prompt" "$default" >&2
  else
    printf '%s: ' "$prompt" >&2
  fi
  read -r reply || reply=''
  if [ -z "$reply" ]; then
    printf '%s' "$default"
  else
    printf '%s' "$reply"
  fi
}

# Select from a fixed list. Usage: choice=$(oc_select "Pick" "same" "split-host" "split-client")
oc_select() {
  prompt="$1"
  shift
  default="$1"
  if ! oc_is_tty; then
    printf '%s' "$default"
    return 0
  fi
  printf '%s (default: %s)\n' "$prompt" "$default" >&2
  i=1
  for opt in "$@"; do
    printf '  %d) %s\n' "$i" "$opt" >&2
    i=$((i + 1))
  done
  printf 'Choice: ' >&2
  read -r reply || reply=''
  if [ -z "$reply" ]; then
    printf '%s' "$default"
    return 0
  fi
  case "$reply" in
    ''|*[!0-9]*)
      printf '%s' "$default"
      ;;
    *)
      i=1
      for opt in "$@"; do
        if [ "$i" = "$reply" ]; then
          printf '%s' "$opt"
          return 0
        fi
        i=$((i + 1))
      done
      printf '%s' "$default"
      ;;
  esac
}
