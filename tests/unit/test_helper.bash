# Shared test setup for bats tests.

# Resolve project root (tests/unit/ -> ../../)
TEST_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$TEST_DIR/../.." && pwd )"
FIXTURES_DIR="$PROJECT_ROOT/tests/fixtures"

export OC_PROJECT_ROOT="$PROJECT_ROOT"
export OC_LIB_DIR="$PROJECT_ROOT/lib"

# Make a per-test fakebin dir and prepend it to PATH. Tests register
# mock executables via `mock_cmd <name> <fixture-path-or-output>`.
setup_mock_path() {
  export OC_FAKEBIN="$BATS_TEST_TMPDIR/fakebin"
  mkdir -p "$OC_FAKEBIN"
  export PATH="$OC_FAKEBIN:$PATH"
  export OC_STATE_DIR="$BATS_TEST_TMPDIR/state"
  export OC_DETECTED_FILE="$OC_STATE_DIR/detected.json"
  export OC_REFRESH_DETECT=1
  mkdir -p "$OC_STATE_DIR"
}

# Mock a command: cat the fixture file when called.
# Usage: mock_cmd nvidia-smi tests/fixtures/nvidia-smi/rtx4090.txt
mock_cmd_file() {
  cmd="$1"
  fixture="$2"
  cat > "$OC_FAKEBIN/$cmd" <<EOF
#!/bin/sh
cat "$fixture"
EOF
  chmod +x "$OC_FAKEBIN/$cmd"
}

# Mock a command to print a literal string.
mock_cmd_echo() {
  cmd="$1"
  out="$2"
  cat > "$OC_FAKEBIN/$cmd" <<EOF
#!/bin/sh
printf '%s\n' "$out"
EOF
  chmod +x "$OC_FAKEBIN/$cmd"
}

# Mock a command to fail (always exit 1).
mock_cmd_fail() {
  cmd="$1"
  cat > "$OC_FAKEBIN/$cmd" <<'EOF'
#!/bin/sh
exit 1
EOF
  chmod +x "$OC_FAKEBIN/$cmd"
}

# Hide a command that may exist on the host (by mocking it to fail).
hide_cmd() {
  mock_cmd_fail "$1"
}
