# shellcheck shell=sh
# oc benchmark - calibrate tier with tinyllama prompts. Pulls
# tinyllama:1.1b if not present, runs 5 prompts of varying length,
# measures tokens/sec, suggests retier if below/above expected band.

# shellcheck source=../../lib/log.sh
. "$OC_LIB_DIR/log.sh"
# shellcheck source=../../lib/detect.sh
. "$OC_LIB_DIR/detect.sh"
# shellcheck source=../../lib/config.sh
. "$OC_LIB_DIR/config.sh"
# shellcheck source=../../lib/ollama.sh
. "$OC_LIB_DIR/ollama.sh"

oc_cmd_benchmark() {
  oc_detect
  oc_log step "Benchmarking on tier '$OC_TIER'"

  if ! oc_ollama_installed; then
    oc_die "Ollama not installed"
  fi
  oc_ollama_pull "tinyllama:1.1b" || oc_die "cannot pull tinyllama:1.1b"

  total_tps=0
  runs=0
  for prompt in \
    "Say hello." \
    "List five primary colours." \
    "Briefly describe a sorting algorithm." \
    "Translate 'good morning' into three languages." \
    "Write a haiku about a quiet morning."; do
    tps=$(_benchmark_one "$prompt")
    [ -n "$tps" ] || continue
    printf '  %s tok/s - %s\n' "$tps" "$(printf '%s' "$prompt" | cut -c1-50)"
    total_tps=$(awk -v t="$total_tps" -v r="$tps" 'BEGIN{printf "%d", t + r}')
    runs=$((runs + 1))
  done

  [ "$runs" -gt 0 ] || oc_die "no benchmark runs succeeded"
  avg=$((total_tps / runs))
  printf '\nAverage: %s tok/s over %s runs\n' "$avg" "$runs"

  # Compare against tier band
  tiers_file="$OC_PROJECT_ROOT/config/tiers.toml"
  min_tps=$(oc_toml_get "$tiers_file" "tier.$OC_TIER.expected_tps_min" 2> /dev/null || echo 0)
  max_tps=$(oc_toml_get "$tiers_file" "tier.$OC_TIER.expected_tps_max" 2> /dev/null || echo 0)
  printf 'Expected band for tier %s: %s..%s tok/s\n' "$OC_TIER" "$min_tps" "$max_tps"

  if [ "$avg" -lt "$min_tps" ]; then
    oc_log warn "below expected band; consider 'oc topology' for split-host, or override models to smaller tags"
  elif [ "$avg" -gt "$max_tps" ]; then
    oc_log info "above expected band; you may have headroom to bump heavy role to a larger model"
  else
    oc_log ok "within expected band"
  fi
}

_benchmark_one() {
  prompt="$1"
  body=$(printf '{"model":"tinyllama:1.1b","prompt":%s,"stream":false}' \
    "$(printf '%s' "$prompt" | _json_str)")
  resp=$(curl -fsS -X POST -H 'content-type: application/json' \
    -d "$body" "http://127.0.0.1:11434/api/generate" 2> /dev/null || echo '')
  # Ollama returns total_duration (ns) and eval_count
  eval_count=$(printf '%s' "$resp" | awk -F'[,:]' '
    {
      for (i = 1; i <= NF; i++) {
        if ($i ~ /"eval_count"/) { gsub(/[^0-9]/, "", $(i+1)); print $(i+1); exit }
      }
    }')
  eval_dur=$(printf '%s' "$resp" | awk -F'[,:]' '
    {
      for (i = 1; i <= NF; i++) {
        if ($i ~ /"eval_duration"/) { gsub(/[^0-9]/, "", $(i+1)); print $(i+1); exit }
      }
    }')
  [ -n "$eval_count" ] && [ -n "$eval_dur" ] && [ "$eval_dur" -gt 0 ] || return 1
  # tok/s = eval_count / (eval_dur in seconds) = eval_count * 1e9 / eval_dur
  awk -v c="$eval_count" -v d="$eval_dur" 'BEGIN{printf "%d", c * 1000000000 / d}'
}

# Quote a string for embedding into JSON
_json_str() {
  awk '
    BEGIN { ORS=""; printf "\"" }
    { gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); print }
    END { printf "\"" }
  '
}
