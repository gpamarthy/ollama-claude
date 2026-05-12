# Hardware

`ollama-claude` aims to do something useful on whatever you run it on. This document spells out exactly what each hardware tier gets and why.

## Tier resolution

Tier is chosen by **effective VRAM** and **total RAM**, not VRAM alone. Apple Silicon uses unified memory: effective VRAM ≈ 75% of total RAM.

| Tier          | Effective VRAM   | Total RAM | Typical machine                                  |
|---------------|------------------|-----------|--------------------------------------------------|
| `cpu`         | none / < 4 GB    | any       | Laptop iGPU, very old GPU, headless server       |
| `low`         | 4–8 GB           | ≥ 8 GB    | GTX 1060 6 GB, GTX 1660, RTX 3050, RX 6600        |
| `mid`         | 8–16 GB          | ≥ 16 GB   | RTX 3060 12 GB, RTX 4060 Ti, RX 6700 XT, M1 16 GB |
| `high`        | 16–24 GB         | ≥ 24 GB   | RTX 4080, RTX 3090, RX 7900 XT, M2 Pro 32 GB      |
| `workstation` | 24 GB+           | ≥ 32 GB   | RTX 4090, RTX 6000 Ada, M3 Max 64 GB              |

## Default model picks (May 2026)

| Tier          | `fast`          | `tools`           | `heavy`              |
|---------------|-----------------|-------------------|----------------------|
| `cpu`         | `llama3.2:3b`   | `qwen3:8b`        | _(skipped)_          |
| `low`         | `llama3.2:3b`   | `qwen3:8b`        | `qwen2.5-coder:7b`   |
| `mid`         | `qwen3:8b`      | `qwen3:14b`       | `qwen2.5-coder:14b`  |
| `high`        | `qwen3:8b`      | `qwen3:14b`       | `qwen2.5-coder:32b`  |
| `workstation` | `qwen3:8b`      | `qwen3:30b`       | `qwen3.6:27b`        |

These are defaults in `config/models.toml`. Override per role with `oc models set <role> <tag>` or by editing `~/.config/ollama-claude/config.toml`.

## Vendor-specific notes

### NVIDIA

Detected via `nvidia-smi`. Works out of the box on modern drivers. If `nvidia-smi` is missing, install the NVIDIA proprietary driver for your distro.

### AMD (ROCm)

Detected via `rocm-smi`. Consumer RDNA cards (6000 and some 7000 series) need `HSA_OVERRIDE_GFX_VERSION` to work with Ollama. We ship a known-good table at `config/amd-hsa-overrides.toml` keyed by chip; the installer applies the override automatically when a match is found. If your chip isn't in the table:

1. Check the Ollama support matrix.
2. Run `rocm-smi --showproductname` and PR the chip + override to `config/amd-hsa-overrides.toml`.

### Apple Silicon

Detected by OS + arch. Apple Metal is automatic — Ollama uses unified memory. We compute effective VRAM as 75% of total RAM. Fanless M-series chassis (Air models) are flagged so sustained workloads warn about thermal throttling.

### Intel Arc / iGPU

Detected last via `vulkaninfo`. Requires `OLLAMA_VULKAN=1` and a recent Mesa stack. Performance varies widely; treat as experimental.

### WSL2

First-class: detected via `/proc/sys/kernel/osrelease`. GPU pass-through requires the host-side NVIDIA driver (≥ 535) and `nvidia-container-toolkit`. The installer refuses to install Linux NVIDIA drivers inside the WSL distro (the host owns them). If your AMD card needs ROCm under WSL2, prefer the `split-client` topology pointing at the Windows host's Ollama.

### CPU-only

Useful for testing and minimal setups. Skips the `heavy` role by default (multi-GB CPU inference is slow enough that pulling the model is rarely worth it). Run `oc benchmark` to see your actual tokens/sec.

## Overriding the resolver

Everything is overridable through the layered config:

```toml
# ~/.config/ollama-claude/config.toml
[overrides]
fast  = "qwen2.5:7b"
tools = "qwen2.5-coder:14b"
heavy = "deepseek-coder-v2:16b"
```

Or per project:

```toml
# .ollama-claude.toml in your repo
[[models]]
name     = "qwen2.5-coder:14b"
provider = "ollama"
roles    = ["heavy"]
digest   = "sha256:..."
```

When teammates run `oc sync` they get the same models — pinned by digest — every time.
