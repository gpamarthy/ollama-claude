# shellcheck shell=sh
# Hardware + OS detection. Output is written as a JSON-ish flat KV store
# to ~/.local/state/ollama-claude/detected.json so subsequent commands
# don't re-run probes. Force rerun with OC_REFRESH_DETECT=1.

# shellcheck source=./log.sh
. "$OC_LIB_DIR/log.sh"

OC_STATE_DIR="${OC_STATE_DIR:-$HOME/.local/state/ollama-claude}"
OC_DETECTED_FILE="$OC_STATE_DIR/detected.json"

# Result variables (set by oc_detect_all). Treated as global.
OC_OS=""
OC_ARCH=""
OC_GPU_VENDOR=""
OC_VRAM_GB=0
OC_RAM_GB=0
OC_TIER=""
OC_EFFECTIVE_VRAM_GB=0
OC_FANLESS=0
OC_ROSETTA=0
OC_WSL2=0
OC_HSA_OVERRIDE=""

# Cache freshness: 7 days
_OC_CACHE_MAX_AGE_SECS=604800

oc_detect_os() {
  case "$(uname -s 2>/dev/null)" in
    Linux)
      OC_OS="linux"
      if [ -r /proc/sys/kernel/osrelease ]; then
        case "$(cat /proc/sys/kernel/osrelease)" in
          *[Mm]icrosoft*) OC_WSL2=1 ;;
        esac
      fi
      ;;
    Darwin)
      OC_OS="macos"
      # Rosetta check (Apple Silicon native vs translated x86_64)
      if [ "$(sysctl -n sysctl.proc_translated 2>/dev/null || echo 0)" = "1" ]; then
        OC_ROSETTA=1
      fi
      ;;
    *)
      OC_OS="unknown"
      ;;
  esac
  OC_ARCH="$(uname -m 2>/dev/null || echo unknown)"
}

oc_detect_ram_gb() {
  case "$OC_OS" in
    linux)
      if [ -r /proc/meminfo ]; then
        kb=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
        OC_RAM_GB=$((kb / 1024 / 1024))
      fi
      ;;
    macos)
      bytes=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
      OC_RAM_GB=$((bytes / 1024 / 1024 / 1024))
      ;;
  esac
}

oc_detect_gpu_nvidia() {
  command -v nvidia-smi >/dev/null 2>&1 || return 1
  vram_mb=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null \
    | head -n1 | tr -d ' ')
  case "$vram_mb" in
    ''|*[!0-9]*) return 1 ;;
  esac
  OC_GPU_VENDOR="nvidia"
  # Round to nearest GB; a 24 GB card reports ~24564 MB and we want 24, not 23.
  OC_VRAM_GB=$(( (vram_mb + 512) / 1024 ))
  return 0
}

oc_detect_gpu_amd() {
  command -v rocm-smi >/dev/null 2>&1 || return 1
  # `rocm-smi --showmeminfo vram` outputs include lines like
  # "GPU[0] : VRAM Total Memory (B): 17163091968"
  bytes=$(rocm-smi --showmeminfo vram 2>/dev/null \
    | awk -F: '/VRAM Total Memory/ {gsub(/[^0-9]/, "", $NF); print $NF; exit}')
  case "$bytes" in
    ''|*[!0-9]*) return 1 ;;
  esac
  OC_GPU_VENDOR="amd"
  # Round to nearest GB
  OC_VRAM_GB=$(( (bytes + 536870912) / 1073741824 ))
  # Look up HSA override by chip name
  chip=$(rocm-smi --showproductname 2>/dev/null | awk -F: '/Card series|Card SKU|Card Model|Card vendor/ {print $NF; exit}' | sed 's/^ *//;s/ *$//')
  OC_HSA_OVERRIDE=$(_oc_amd_override_for "$chip")
  return 0
}

# Look up HSA_OVERRIDE_GFX_VERSION for a chip identifier from
# config/amd-hsa-overrides.toml. Prints the override or empty.
_oc_amd_override_for() {
  chip="$1"
  override_file="$OC_PROJECT_ROOT/config/amd-hsa-overrides.toml"
  [ -r "$override_file" ] || return 0
  awk -v c="$chip" '
    /^\[\[chip\]\]/   { in_block = 1; match_str = ""; override = ""; next }
    in_block && /^match[[:space:]]*=/ {
      gsub(/[" ]/, "", $0)
      sub(/^match=/, "", $0)
      match_str = $0
    }
    in_block && /^override[[:space:]]*=/ {
      gsub(/[" ]/, "", $0)
      sub(/^override=/, "", $0)
      override = $0
    }
    in_block && /^\[/ && !/^\[\[chip\]\]/ { in_block = 0 }
    END {
      # Re-scan to do substring match (simpler than a streaming version)
    }
  ' "$override_file" >/dev/null
  # Simpler: streaming scan
  awk -v c="$chip" '
    /^\[\[chip\]\]/ { m=""; o=""; in_b=1; next }
    in_b && /^match[[:space:]]*=/ {
      sub(/^match[[:space:]]*=[[:space:]]*"/, ""); sub(/"[[:space:]]*$/, "")
      m=$0
    }
    in_b && /^override[[:space:]]*=/ {
      sub(/^override[[:space:]]*=[[:space:]]*"/, ""); sub(/"[[:space:]]*$/, "")
      o=$0
    }
    in_b && length(m) > 0 && length(o) > 0 && index(c, m) > 0 { print o; exit }
  ' "$override_file"
}

oc_detect_gpu_apple() {
  [ "$OC_OS" = "macos" ] || return 1
  OC_GPU_VENDOR="apple_metal"
  # Unified memory: effective VRAM ≈ 75% of total RAM
  OC_VRAM_GB=$((OC_RAM_GB * 75 / 100))
  # Fanless models (M-series Air) get a thermal-throttle flag
  if system_profiler SPHardwareDataType 2>/dev/null | grep -qi 'MacBook Air'; then
    OC_FANLESS=1
  fi
  return 0
}

oc_detect_gpu_intel() {
  # Intel Arc / iGPU via Vulkan probe — last in the order
  command -v vulkaninfo >/dev/null 2>&1 || return 1
  vk_summary=$(vulkaninfo --summary 2>/dev/null || true)
  case "$vk_summary" in
    *Intel*)
      OC_GPU_VENDOR="intel_vulkan"
      # Best-effort VRAM: parse first deviceLocalMemory line
      mb=$(printf '%s\n' "$vk_summary" \
        | awk '/deviceLocalMemory|deviceMemoryBudget/ {gsub(/[^0-9]/, "", $NF); print $NF; exit}')
      case "$mb" in
        ''|*[!0-9]*) OC_VRAM_GB=0 ;;
        *)           OC_VRAM_GB=$((mb / 1024 / 1024)) ;;
      esac
      return 0
      ;;
  esac
  return 1
}

oc_detect_gpu() {
  OC_GPU_VENDOR=""
  OC_VRAM_GB=0
  OC_HSA_OVERRIDE=""

  oc_detect_gpu_nvidia && return 0
  oc_detect_gpu_amd && return 0
  oc_detect_gpu_apple && return 0
  oc_detect_gpu_intel && return 0

  OC_GPU_VENDOR="cpu"
  OC_VRAM_GB=0
}

# Compute effective VRAM (Apple Silicon uses unified-memory formula)
oc_compute_effective_vram() {
  if [ "$OC_GPU_VENDOR" = "apple_metal" ]; then
    OC_EFFECTIVE_VRAM_GB=$((OC_RAM_GB * 75 / 100))
  else
    OC_EFFECTIVE_VRAM_GB="$OC_VRAM_GB"
  fi
}

# Determine tier from effective VRAM × RAM gates.
# Boundaries are inclusive at the upper end: 8 GB → low, 16 GB → mid,
# 24 GB → high, > 24 GB → workstation. Matches the table in
# docs/HARDWARE.md and config/tiers.toml.
oc_compute_tier() {
  vram="$OC_EFFECTIVE_VRAM_GB"
  ram="$OC_RAM_GB"
  if   [ "$vram" -lt 4 ]; then
    OC_TIER="cpu"
  elif [ "$vram" -le 8  ] && [ "$ram" -ge 8  ]; then
    OC_TIER="low"
  elif [ "$vram" -le 16 ] && [ "$ram" -ge 16 ]; then
    OC_TIER="mid"
  elif [ "$vram" -lt 24 ] && [ "$ram" -ge 24 ]; then
    OC_TIER="high"
  elif [ "$vram" -ge 24 ] && [ "$ram" -ge 32 ]; then
    OC_TIER="workstation"
  else
    # Fallback: pick by VRAM alone if the RAM gate misses (rare on dev boxes)
    if   [ "$vram" -le 8 ];  then OC_TIER="low"
    elif [ "$vram" -le 16 ]; then OC_TIER="mid"
    elif [ "$vram" -lt 24 ]; then OC_TIER="high"
    else                          OC_TIER="workstation"
    fi
  fi
}

# Run the whole probe pipeline.
oc_detect_all() {
  oc_detect_os
  oc_detect_ram_gb
  oc_detect_gpu
  oc_compute_effective_vram
  oc_compute_tier
}

# Load cached detection if recent enough.
oc_load_detection_cache() {
  [ -r "$OC_DETECTED_FILE" ] || return 1
  [ "${OC_REFRESH_DETECT:-0}" = "1" ] && return 1

  # Age check
  now=$(date +%s 2>/dev/null || echo 0)
  generated=$(awk -F'"' '/"generated_at_unix"/ {print $4}' "$OC_DETECTED_FILE" 2>/dev/null \
    | head -n1)
  case "$generated" in
    ''|*[!0-9]*) return 1 ;;
  esac
  age=$((now - generated))
  if [ "$age" -gt "$_OC_CACHE_MAX_AGE_SECS" ]; then
    return 1
  fi

  # Crude parse: source like a KV file
  OC_OS=$(_oc_json_get "$OC_DETECTED_FILE" os)
  OC_ARCH=$(_oc_json_get "$OC_DETECTED_FILE" arch)
  OC_GPU_VENDOR=$(_oc_json_get "$OC_DETECTED_FILE" gpu_vendor)
  OC_VRAM_GB=$(_oc_json_get "$OC_DETECTED_FILE" vram_gb)
  OC_EFFECTIVE_VRAM_GB=$(_oc_json_get "$OC_DETECTED_FILE" effective_vram_gb)
  OC_RAM_GB=$(_oc_json_get "$OC_DETECTED_FILE" ram_gb)
  OC_TIER=$(_oc_json_get "$OC_DETECTED_FILE" tier)
  OC_FANLESS=$(_oc_json_get "$OC_DETECTED_FILE" fanless)
  OC_ROSETTA=$(_oc_json_get "$OC_DETECTED_FILE" rosetta)
  OC_WSL2=$(_oc_json_get "$OC_DETECTED_FILE" wsl2)
  OC_HSA_OVERRIDE=$(_oc_json_get "$OC_DETECTED_FILE" hsa_override)
  return 0
}

# Tiny JSON value reader: matches "key" : "value" or "key" : number
_oc_json_get() {
  awk -v k="\"$2\"" '
    {
      i = index($0, k)
      if (i > 0) {
        rest = substr($0, i + length(k))
        sub(/^[[:space:]]*:[[:space:]]*/, "", rest)
        if (substr(rest, 1, 1) == "\"") {
          sub(/^"/, "", rest)
          sub(/".*/, "", rest)
          print rest
        } else {
          sub(/[[:space:]]*,.*/, "", rest)
          sub(/[[:space:]]*}.*/, "", rest)
          print rest
        }
        exit
      }
    }
  ' "$1"
}

oc_save_detection_cache() {
  mkdir -p "$OC_STATE_DIR"
  now=$(date +%s 2>/dev/null || echo 0)
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)
  cat > "$OC_DETECTED_FILE" <<EOF
{
  "schema_version": 1,
  "generated_at": "$ts",
  "generated_at_unix": $now,
  "os": "$OC_OS",
  "arch": "$OC_ARCH",
  "gpu_vendor": "$OC_GPU_VENDOR",
  "vram_gb": $OC_VRAM_GB,
  "effective_vram_gb": $OC_EFFECTIVE_VRAM_GB,
  "ram_gb": $OC_RAM_GB,
  "tier": "$OC_TIER",
  "fanless": $OC_FANLESS,
  "rosetta": $OC_ROSETTA,
  "wsl2": $OC_WSL2,
  "hsa_override": "$OC_HSA_OVERRIDE"
}
EOF
}

# Public entry: load cache or run probes, then persist.
oc_detect() {
  if oc_load_detection_cache; then
    oc_log debug "detection cache hit ($OC_DETECTED_FILE)"
    return 0
  fi
  oc_log debug "running hardware detection"
  oc_detect_all
  oc_save_detection_cache
}

# Print the current detection as a short human report (for `oc status`).
oc_detect_report() {
  printf '  OS:                %s (%s)\n' "$OC_OS" "$OC_ARCH"
  printf '  GPU:               %s\n' "$OC_GPU_VENDOR"
  printf '  VRAM:              %s GB\n' "$OC_VRAM_GB"
  printf '  Effective VRAM:    %s GB\n' "$OC_EFFECTIVE_VRAM_GB"
  printf '  RAM:               %s GB\n' "$OC_RAM_GB"
  printf '  Tier:              %s\n' "$OC_TIER"
  [ "$OC_WSL2" = "1" ]    && printf '  WSL2:              yes\n'
  [ "$OC_ROSETTA" = "1" ] && printf '  Rosetta:           yes (run natively for best results)\n'
  [ "$OC_FANLESS" = "1" ] && printf '  Fanless chassis:   yes (consider --battery-friendly)\n'
  [ -n "$OC_HSA_OVERRIDE" ] && printf '  HSA_OVERRIDE:      %s\n' "$OC_HSA_OVERRIDE"
  return 0
}
