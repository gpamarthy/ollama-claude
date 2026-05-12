#!/usr/bin/env bats
# Contract: the rendered claude-code.env exports exactly the three keys,
# in the right order, with `unset ANTHROPIC_API_KEY` as the third line.

load ../unit/test_helper

setup() {
  setup_mock_path
  source "$OC_LIB_DIR/log.sh"
  source "$OC_LIB_DIR/config.sh"
  source "$OC_LIB_DIR/claude.sh"
}

@test "env file uses correct base URL and unsets ANTHROPIC_API_KEY by default" {
  out="$BATS_TEST_TMPDIR/env"
  oc_render_claude_env "http://127.0.0.1:11434" "$out"

  grep -q '^export ANTHROPIC_BASE_URL="http://127.0.0.1:11434"$' "$out"
  grep -q '^export ANTHROPIC_AUTH_TOKEN="ollama"$' "$out"
  grep -q '^unset ANTHROPIC_API_KEY$' "$out"
}

@test "env file honours OC_ANTHROPIC_API_KEY_FORM=empty" {
  out="$BATS_TEST_TMPDIR/env"
  OC_ANTHROPIC_API_KEY_FORM=empty oc_render_claude_env "http://127.0.0.1:11434" "$out"

  grep -q '^export ANTHROPIC_API_KEY=""$' "$out"
  ! grep -q '^unset ANTHROPIC_API_KEY$' "$out"
}

@test "env file is mode 0600" {
  out="$BATS_TEST_TMPDIR/env"
  oc_render_claude_env "http://127.0.0.1:11434" "$out"

  perms=$(stat -c '%a' "$out" 2>/dev/null || stat -f '%A' "$out")
  [ "$perms" = "600" ]
}
