#!/bin/sh
# Integration smoke: oc version + status + a no-op install dry-pass.
# Designed to run on a CI runner with no GPU. Doesn't actually install Ollama
# unless OC_INTEGRATION_FULL=1.

set -eu

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OC="$PROJECT_ROOT/bin/oc"

if [ ! -x "$OC" ]; then
  chmod +x "$OC"
fi

echo "[smoke] oc version"
"$OC" version

echo "[smoke] oc status (no Ollama installed is fine)"
"$OC" status || true

echo "[smoke] oc models (read-only, no install)"
OC_REFRESH_DETECT=1 "$OC" models list

if [ "${OC_INTEGRATION_FULL:-0}" = "1" ]; then
  echo "[smoke] OC_INTEGRATION_FULL=1; running full install"
  OC_ASSUME_YES=1 OC_TOPOLOGY=same OC_SKIP_PULL=1 "$OC" install
  "$OC" doctor || true
fi

echo "[smoke] all checks ok"
