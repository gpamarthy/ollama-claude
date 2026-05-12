# shellcheck shell=sh
# Consistent, TTY-aware logging. Sourced by every script.
# Honours NO_COLOR (https://no-color.org) and OC_QUIET.

# Reset and color codes only if stdout is a TTY and NO_COLOR is unset.
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  _OC_C_RESET=$(printf '\033[0m')
  _OC_C_DIM=$(printf '\033[2m')
  _OC_C_RED=$(printf '\033[31m')
  _OC_C_YEL=$(printf '\033[33m')
  _OC_C_GRN=$(printf '\033[32m')
  _OC_C_BLU=$(printf '\033[34m')
else
  _OC_C_RESET=''
  _OC_C_DIM=''
  _OC_C_RED=''
  _OC_C_YEL=''
  _OC_C_GRN=''
  _OC_C_BLU=''
fi

oc_log() {
  level="$1"
  shift
  case "$level" in
    debug)
      [ "${OC_VERBOSE:-0}" = "1" ] || return 0
      printf '%s[debug]%s %s\n' "$_OC_C_DIM" "$_OC_C_RESET" "$*" >&2
      ;;
    info)
      [ "${OC_QUIET:-0}" = "1" ] && return 0
      printf '%s[info]%s %s\n' "$_OC_C_BLU" "$_OC_C_RESET" "$*"
      ;;
    ok)
      [ "${OC_QUIET:-0}" = "1" ] && return 0
      printf '%s[ ok ]%s %s\n' "$_OC_C_GRN" "$_OC_C_RESET" "$*"
      ;;
    warn)
      printf '%s[warn]%s %s\n' "$_OC_C_YEL" "$_OC_C_RESET" "$*" >&2
      ;;
    error)
      printf '%s[err ]%s %s\n' "$_OC_C_RED" "$_OC_C_RESET" "$*" >&2
      ;;
    step)
      [ "${OC_QUIET:-0}" = "1" ] && return 0
      printf '\n%s==>%s %s\n' "$_OC_C_BLU" "$_OC_C_RESET" "$*"
      ;;
    *)
      printf '%s\n' "$*"
      ;;
  esac
}

oc_die() {
  oc_log error "$*"
  exit 1
}
