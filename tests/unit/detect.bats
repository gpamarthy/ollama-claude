#!/usr/bin/env bats
# Hardware detection: tier resolution from mocked nvidia-smi / rocm-smi.

load test_helper

setup() {
  setup_mock_path
  # shellcheck source=../../lib/log.sh
  source "$OC_LIB_DIR/log.sh"
  # shellcheck source=../../lib/detect.sh
  source "$OC_LIB_DIR/detect.sh"
}

@test "nvidia 24 GB resolves to workstation tier" {
  mock_cmd_file nvidia-smi "$FIXTURES_DIR/nvidia-smi/rtx4090.txt"
  hide_cmd rocm-smi
  hide_cmd vulkaninfo

  # Force linux-style RAM detection by mocking /proc/meminfo via env override
  # The detector reads /proc/meminfo directly; set RAM via the OC_RAM_GB override
  # path: write the cache manually after running.
  # Simpler: run detect and assert based on what it produced.

  oc_detect_os
  OC_RAM_GB=64
  oc_detect_gpu

  [ "$OC_GPU_VENDOR" = "nvidia" ]
  [ "$OC_VRAM_GB" -eq 24 ]

  oc_compute_effective_vram
  oc_compute_tier

  [ "$OC_TIER" = "workstation" ]
}

@test "nvidia 12 GB resolves to mid tier" {
  mock_cmd_file nvidia-smi "$FIXTURES_DIR/nvidia-smi/rtx3060-12gb.txt"
  hide_cmd rocm-smi
  hide_cmd vulkaninfo

  oc_detect_os
  OC_RAM_GB=32
  oc_detect_gpu
  oc_compute_effective_vram
  oc_compute_tier

  [ "$OC_GPU_VENDOR" = "nvidia" ]
  [ "$OC_VRAM_GB" -eq 12 ]
  [ "$OC_TIER" = "mid" ]
}

@test "nvidia 6 GB laptop resolves to low tier" {
  mock_cmd_file nvidia-smi "$FIXTURES_DIR/nvidia-smi/rtx3060-laptop-6gb.txt"
  hide_cmd rocm-smi
  hide_cmd vulkaninfo

  oc_detect_os
  OC_RAM_GB=16
  oc_detect_gpu
  oc_compute_effective_vram
  oc_compute_tier

  [ "$OC_VRAM_GB" -eq 6 ]
  [ "$OC_TIER" = "low" ]
}

@test "amd rocm 8 GB resolves to low tier" {
  hide_cmd nvidia-smi
  mock_cmd_file rocm-smi "$FIXTURES_DIR/rocm-smi/rx6600xt.txt"
  hide_cmd vulkaninfo

  oc_detect_os
  OC_RAM_GB=16
  oc_detect_gpu
  oc_compute_effective_vram
  oc_compute_tier

  [ "$OC_GPU_VENDOR" = "amd" ]
  [ "$OC_VRAM_GB" -eq 8 ]
  [ "$OC_TIER" = "low" ]
}

@test "no GPU resolves to cpu tier" {
  hide_cmd nvidia-smi
  hide_cmd rocm-smi
  hide_cmd vulkaninfo

  oc_detect_os
  OC_RAM_GB=8
  oc_detect_gpu
  oc_compute_effective_vram
  oc_compute_tier

  [ "$OC_GPU_VENDOR" = "cpu" ]
  [ "$OC_VRAM_GB" -eq 0 ]
  [ "$OC_TIER" = "cpu" ]
}

@test "tier is monotonic with VRAM" {
  hide_cmd rocm-smi
  hide_cmd vulkaninfo

  prev_rank=-1
  rank_of() {
    case "$1" in
      cpu) echo 0 ;;
      low) echo 1 ;;
      mid) echo 2 ;;
      high) echo 3 ;;
      workstation) echo 4 ;;
    esac
  }

  for mb in 2048 6144 12288 20480 32768; do
    mock_cmd_echo nvidia-smi "$mb"
    oc_detect_os
    OC_RAM_GB=64
    oc_detect_gpu
    oc_compute_effective_vram
    oc_compute_tier
    rank=$(rank_of "$OC_TIER")
    [ "$rank" -ge "$prev_rank" ]
    prev_rank=$rank
  done
}
