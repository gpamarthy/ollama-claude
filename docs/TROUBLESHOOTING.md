# Troubleshooting

Common problems, ordered by how often they come up.

## "Claude Code is still talking to the cloud"

After running `oc install`:

```sh
oc status
```

If "Switch state" reports `cloud`, the env file is not sourced in the shell that ran `claude`. Either:

```sh
source ~/.config/ollama-claude/claude-code.env
# or:
oc wire-up           # makes it permanent
```

You also need to restart Claude Code if it was already running - it reads `ANTHROPIC_BASE_URL` once at startup.

## "GPU detected but `ollama ps` shows 0 GPU layers"

```sh
oc doctor
```

`oc doctor` runs a probe and asserts GPU layers > 0 if we detected a GPU. Common causes:

- **CUDA driver/runtime mismatch.** Update your NVIDIA driver to ≥535; Ollama bundles its own CUDA but needs a recent driver.
- **AMD ROCm consumer card.** Run `rocm-smi --showproductname`. If your chip isn't in `config/amd-hsa-overrides.toml`, please PR an entry. As a workaround, `export HSA_OVERRIDE_GFX_VERSION=10.3.0` (or 11.0.0 for RDNA3) before starting Ollama.
- **WSL2 without host driver.** GPU pass-through needs the Windows-side NVIDIA driver ≥ 535 and `nvidia-container-toolkit`. Don't install Linux NVIDIA drivers inside the WSL distro.

## "Model pull restarts at 0% after a network blip"

Known Ollama issue. `oc install` wraps pulls with retry + exponential backoff; if it gives up after 3 tries, run it again - partial downloads are usually resumable on the second attempt with a recent Ollama.

## "Qwen tool calls loop forever"

Affected Ollama versions had a missing presence-penalty parameter for Qwen models. Upgrade to Ollama ≥ v0.17.7. `oc doctor` warns if your version is below the patched minor.

## "Apple Silicon: I have 16 GB RAM but `oc status` shows 12 GB effective VRAM"

That's intentional. Apple Silicon uses unified memory, and we cap effective VRAM at 75% of RAM to leave headroom for the OS and apps. Override with `OC_EFFECTIVE_VRAM_GB=16` if you know what you're doing.

## "Apple Silicon: fans aren't spinning but the laptop is slow after 10 minutes"

You're on a fanless chassis (M-series Air). `oc status` flags this. Either pull smaller models (Q4 quant) or accept the throttle for longer-running tasks.

## "Install fails on macOS with `tar: Unrecognized archive format`"

You're hitting GNU tar vs BSD tar differences. macOS ships BSD tar by default and our installer uses `--strip-components`, which works on both but some early macOS 13 betas had an issue. `brew install gnu-tar` and re-run.

## "Windows says `installer.ps1` is blocked"

Two layers:

1. **Execution policy.** `Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned` for the current session.
2. **Defender/AV quarantine.** Unsigned installers are flagged. Our Phase 2 releases are Authenticode-signed. For Phase 1, verify the SHA256 of the tarball against the published `SHA256SUMS` and restore from quarantine.

## "Behind a corporate proxy / MITM TLS"

Set `HTTPS_PROXY`, `HTTP_PROXY`, and either `SSL_CERT_FILE` or `CURL_CA_BUNDLE` pointing at your corp CA bundle. We never pin certificates in the installer.

## "I don't have sudo"

`oc install` falls back to user-mode install: binaries in `~/.local/bin`, user-mode systemd unit. Service won't start on boot in this mode - start it with `systemctl --user start ollama` after login.

## "Pre-existing Ollama install detected"

We don't overwrite. By default we **keep & supplement**: we use your existing Ollama, write only our own config under `~/.config/ollama-claude/`, and leave your service file alone. If that's not what you want:

```sh
oc install --reclaim    # not implemented yet; PRs welcome
```

For now, uninstall your existing Ollama and re-run `oc install`.

## "I want to file a bug"

Open an issue on https://github.com/gpamarthy/ollama-claude/issues with:

```sh
oc version
oc status
oc doctor --verbose 2>&1 | head -100
```

The bug-report template asks for these.
