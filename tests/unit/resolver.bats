#!/usr/bin/env bats
# Model resolver: walks tiers down on miss; respects explicit "".

load test_helper

setup() {
  setup_mock_path
  source "$OC_LIB_DIR/log.sh"
  source "$OC_LIB_DIR/config.sh"
}

@test "resolver returns the configured tag for an existing tier" {
  result="$(oc_resolve_model "$PROJECT_ROOT/config/models.toml" "mid" "fast")"
  [ "$result" = "qwen3:8b" ]
}

@test "resolver returns empty string for cpu tier heavy (intentional skip)" {
  result="$(oc_resolve_model "$PROJECT_ROOT/config/models.toml" "cpu" "heavy")"
  [ "$result" = "" ]
}

@test "resolver returns workstation heavy correctly" {
  result="$(oc_resolve_model "$PROJECT_ROOT/config/models.toml" "workstation" "heavy")"
  [ "$result" = "qwen3.6:27b" ]
}

@test "resolver returns low tier tools tag" {
  result="$(oc_resolve_model "$PROJECT_ROOT/config/models.toml" "low" "tools")"
  [ "$result" = "qwen3:8b" ]
}
