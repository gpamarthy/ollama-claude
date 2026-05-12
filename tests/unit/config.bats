#!/usr/bin/env bats
# Tiny TOML reader: scalar key access in tabled sections.

load test_helper

setup() {
  setup_mock_path
  source "$OC_LIB_DIR/log.sh"
  source "$OC_LIB_DIR/config.sh"
}

@test "toml_get reads a tier model tag" {
  result="$(oc_toml_get "$PROJECT_ROOT/config/models.toml" "tier.mid.fast")"
  [ "$result" = "qwen3:8b" ]
}

@test "toml_get reads the fallback tag" {
  result="$(oc_toml_get "$PROJECT_ROOT/config/models.toml" "fallback.tag")"
  [ "$result" = "llama3.2:3b" ]
}

@test "toml_get reads a tiers.toml integer" {
  result="$(oc_toml_get "$PROJECT_ROOT/config/tiers.toml" "tier.mid.expected_tps_min")"
  [ "$result" = "25" ]
}

@test "toml_get reads a topology.toml string" {
  result="$(oc_toml_get "$PROJECT_ROOT/config/topology.toml" "same.host")"
  [ "$result" = "127.0.0.1:11434" ]
}

@test "config_home produces correct path" {
  home="$(oc_config_home)"
  case "$home" in
    */ollama-claude) : ;;
    *) printf '%s\n' "$home" >&2; return 1 ;;
  esac
}
