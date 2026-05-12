# shellcheck shell=sh
# oc doctor — end-to-end probe with per-role inference smoke.

# shellcheck source=../../lib/log.sh
. "$OC_LIB_DIR/log.sh"
# shellcheck source=../../lib/detect.sh
. "$OC_LIB_DIR/detect.sh"
# shellcheck source=../../lib/config.sh
. "$OC_LIB_DIR/config.sh"
# shellcheck source=../../lib/ollama.sh
. "$OC_LIB_DIR/ollama.sh"
# shellcheck source=../../lib/claude.sh
. "$OC_LIB_DIR/claude.sh"
# shellcheck source=../../lib/hooks.sh
. "$OC_LIB_DIR/hooks.sh"

oc_cmd_doctor() {
  fail=0
  warn=0
  oc_run_hook pre-doctor

  oc_log step "Hardware detection"
  oc_detect
  oc_detect_report
  [ -n "$OC_TIER" ] || {
    oc_log error "could not determine tier"
    fail=$((fail + 1))
  }

  oc_log step "Ollama health"
  if ! oc_ollama_installed; then
    oc_log error "Ollama not found in PATH"
    fail=$((fail + 1))
  else
    v=$(oc_ollama_version || echo unknown)
    oc_log ok "ollama $v installed"
    if oc_ollama_version_ok; then
      oc_log ok "version >= $OLLAMA_MIN_VERSION (Anthropic-compatible endpoint supported)"
    else
      oc_log warn "version below $OLLAMA_MIN_VERSION; upgrade for Anthropic-compatible endpoint"
      warn=$((warn + 1))
    fi
    if oc_ollama_ping "127.0.0.1:11434"; then
      oc_log ok "service reachable on 127.0.0.1:11434"
    else
      oc_log error "service not reachable on 127.0.0.1:11434"
      fail=$((fail + 1))
    fi
  fi

  oc_log step "Per-role inference probe"
  models_file="$OC_PROJECT_ROOT/config/models.toml"
  for role in fast tools heavy; do
    tag=$(oc_resolve_model "$models_file" "$OC_TIER" "$role")
    if [ -z "$tag" ]; then
      oc_log ok "role '$role' intentionally skipped on tier '$OC_TIER'"
      continue
    fi
    if ! oc_ollama_tag_present_locally "$tag"; then
      # Not pulled yet is a remediation suggestion, not a failure.
      oc_log warn "role '$role': $tag not pulled (run: ollama pull $tag — or: oc install)"
      warn=$((warn + 1))
      continue
    fi
    if _probe_inference "$tag"; then
      oc_log ok "role '$role' ($tag): probe succeeded"
    else
      oc_log error "role '$role' ($tag): probe failed"
      fail=$((fail + 1))
    fi
  done

  oc_log step "Claude Code wire-up"
  printf '  state: %s\n' "$(oc_claude_wireup_state)"
  printf '  switch: %s\n' "$(oc_claude_switch_state)"

  OC_DOCTOR_FAIL="$fail" OC_DOCTOR_WARN="$warn" oc_run_hook post-doctor

  printf '\n'
  if [ "$fail" -eq 0 ] && [ "$warn" -eq 0 ]; then
    oc_log ok "doctor: all checks passed"
    return 0
  elif [ "$fail" -eq 0 ]; then
    oc_log ok "doctor: $warn warning(s), no failures"
    return 0
  else
    oc_log error "doctor: $fail failure(s), $warn warning(s)"
    return 1
  fi
}

# Minimal canonical inference probe. We send a tiny prompt via the
# Ollama API and accept any non-empty response.
_probe_inference() {
  tag="$1"
  body=$(printf '{"model":"%s","prompt":"Say OK.","stream":false}' "$tag")
  resp=$(curl -fsS -X POST -H 'content-type: application/json' \
    -d "$body" "http://127.0.0.1:11434/api/generate" 2> /dev/null || echo '')
  case "$resp" in
    *response*) return 0 ;;
    *) return 1 ;;
  esac
}
