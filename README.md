# ollama-claude

Hardware-aware bridge between **Ollama** and **Claude Code**. One command. Detects your GPU. Picks a model that fits. Wires Claude Code to a local endpoint. No proxy, no daemon, no telemetry.

```sh
# Linux / macOS
curl -fsSL https://raw.githubusercontent.com/gpamarthy/ollama-claude/main/install.sh | sh

# Windows (PowerShell)
iwr -useb https://raw.githubusercontent.com/gpamarthy/ollama-claude/main/install.ps1 | iex
```

After it finishes:

```sh
source ~/.config/ollama-claude/claude-code.env
claude
```

Claude Code is now talking to a local Ollama running a model your hardware can actually handle.

## Why this exists

- **Ollama** runs local LLMs well, but it does not know which model fits your machine. You have to guess.
- **Claude Code** is a great agentic CLI, but it expects to talk to Anthropic. Pointing it at a local backend is a documented two-paragraph process, not a one-liner.

`ollama-claude` is the missing layer. It owns the hardware-detect-and-wire-up step so you can spend your time on the work, not the plumbing.

## Three things this does that nothing else does

1. **Hardware-tier autopilot.** Detects GPU vendor + VRAM + RAM, then picks a `{fast, tools, heavy}` model triple that fits. Falls back one tier down if a tag is not available. Works on NVIDIA, AMD, Apple Silicon, Intel Arc / iGPU, and CPU-only.
2. **AI dev environment as code.** Drop a `.ollama-claude.toml` in your repo with model digests pinned. Teammates run `oc sync` and get the same setup. Like `mise.toml`, but for local AI.
3. **Explicit local/cloud switching.** Default state is local-only. `oc switch cloud` flips Claude Code back to Anthropic's endpoint with one command. `oc status` always shows which mode is active. No magic routing, no surprise cloud calls.

## Hardware matrix

| Tier          | Effective VRAM   | Total RAM | fast              | tools                  | heavy                     |
|---------------|------------------|-----------|-------------------|------------------------|---------------------------|
| `cpu`         | none / < 4 GB    | any       | `llama3.2:3b`     | `qwen3:8b`             | _(skipped)_               |
| `low`         | 4–8 GB           | ≥ 8 GB    | `llama3.2:3b`     | `qwen3:8b`             | `qwen2.5-coder:7b`        |
| `mid`         | 8–16 GB          | ≥ 16 GB   | `qwen3:8b`        | `qwen3:14b`            | `qwen2.5-coder:14b`       |
| `high`        | 16–24 GB         | ≥ 24 GB   | `qwen3:8b`        | `qwen3:14b`            | `qwen2.5-coder:32b`       |
| `workstation` | 24 GB+           | ≥ 32 GB   | `qwen3:8b`        | `qwen3:30b`            | `qwen3.6:27b`             |

Apple Silicon uses unified memory: effective VRAM is roughly 75% of total RAM. Override anything in `~/.config/ollama-claude/config.toml`.

## Comparison

| Tool             | What it does                          | What `ollama-claude` adds                                           |
|------------------|---------------------------------------|---------------------------------------------------------------------|
| raw Ollama       | Runs local LLMs                       | Tells you _which_ model to run; wires Claude Code                   |
| ramalama         | Containerised local AI                | Bare-metal; Claude Code wire-up; reproducibility via `.toml`        |
| LM Studio        | GUI explorer for local models         | CLI-first; scriptable; works on headless boxes                      |
| LiteLLM          | Proxy + router across providers       | No proxy needed; uses Ollama's native Anthropic endpoint             |
| `curl|sh` Ollama | One-command Ollama install            | Hardware tiering, Claude Code integration, topology presets         |

See [docs/COMPARISONS.md](docs/COMPARISONS.md) for the long version.

## Customisation

Everything is overridable. Five layers, deep-merged, later wins:

1. Built-in defaults
2. Global: `~/.config/ollama-claude/config.toml`
3. Profile: `~/.config/ollama-claude/profiles/<name>.toml`
4. Project: `.ollama-claude.toml` at git root
5. Env vars: `OC_*`

Built-in profiles: `default`, `security-research`, `data-science`, `web-dev`, `minimalist`, `team`. Fork one with `oc profile new mine --from web-dev`.

See [docs/CUSTOMIZATION.md](docs/CUSTOMIZATION.md).

## Subcommands

```
oc install       # detect → install → pull → render
oc init          # 3-question wizard; writes .ollama-claude.toml
oc sync          # apply project config over global
oc status        # health, models, topology, wire-up, switch
oc doctor        # end-to-end probe with per-role inference
oc models        # list / set / override role→tag map
oc topology      # same | split-host | split-client
oc switch        # local | cloud
oc wire-up       # inject env-source into shell rc
oc claude-hooks  # session-backend audit hook for Claude Code
oc benchmark     # calibrate tier with tinyllama prompts
oc self-update   # fetch + verify newer release
oc uninstall     # remove service + configs (--purge for models)
oc version
```

## Privacy posture

- No telemetry. No phone-home. No anonymous stats. Not even crash uploads.
- `OLLAMA_HOST` defaults to `127.0.0.1:11434`. The only path that exposes Ollama on a non-loopback interface is `--topology split-host`, which refuses to run without a scoped CIDR.
- `OLLAMA_ORIGINS=*` is never written.
- The installer never modifies your shell rc files unless you explicitly run `oc wire-up`. It never modifies Claude Code's `settings.json` unless you explicitly run `oc wire-up --claude-settings`.

See [docs/SECURITY_POSTURE.md](docs/SECURITY_POSTURE.md).

## Status

Pre-1.0. The shell-script MVP (Phase 1) is the current shipping form. A Go single-binary rewrite (Phase 2) is on the roadmap for `v1.0`. The on-disk schema and subcommand tree are stable across the cutover.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). PRs welcome, especially for new hardware fixtures in `tests/fixtures/`.

## License

[MIT](LICENSE).
