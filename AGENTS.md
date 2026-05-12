# ollama-claude

Hardware-aware bridge between Ollama and Claude Code. One command to detect your GPU, pick a model that fits, and wire Claude Code to a local Ollama on Linux / macOS / Windows / WSL2.

## What it is

`ollama-claude` is the missing layer between two great tools:

- **Ollama** runs local LLMs well, but doesn't know which model fits your hardware.
- **Claude Code** is a great agentic CLI, but speaks the Anthropic API and won't help you point it at a local backend.

This installer detects your hardware tier, pulls a `{fast, tools, heavy}` model triple that actually fits, and writes an opt-in env file that wires Claude Code to the local endpoint. No proxy, no daemon, no telemetry.

## Layout

```
bin/         dispatcher + subcommands (shell + powershell)
lib/         shared helpers (detection, ollama, config, hooks)
config/      models.toml, tiers.toml, topology.toml, profiles/, schema/
platform/    linux systemd unit, macos launchd plist, windows service
tests/       unit, contract, integration, simulation, chaos, property
docs/        architecture, hardware, claude-code wire-up, customization, comparisons
.github/     CI matrix, nightly chaos, release workflow
scripts/     release tooling
```

## Build / test commands

```sh
make ci         # static + unit + contract + integration (PR gate)
make nightly    # + simulation + chaos + property
shellcheck $(git ls-files '*.sh')
shfmt -d $(git ls-files '*.sh')
bats tests/unit
```

## Conventions

- POSIX `sh` for `lib/` and `bin/lib/*.sh`. Bash only in `install.sh` (which re-execs under bash if it isn't already).
- Two-space indent in shell. `shfmt -i 2 -ci -sr`.
- PowerShell mirrors live next to their sh counterparts (`detect.sh` ↔ `detect.ps1`).
- Config files are TOML; every shipped TOML carries a `# $schema:` comment for editor auto-complete.
- Tests use `bats-core` for shell, `Pester` for PowerShell.
- No emojis in code or commits. Conventional Commits for messages (`feat:`, `fix:`, `docs:`, …).

## Subcommands

| Command         | Purpose                                                          |
|-----------------|------------------------------------------------------------------|
| `oc install`    | Detect → install Ollama → pull tier models → render config        |
| `oc init`       | 3-question wizard → writes `.ollama-claude.toml`                  |
| `oc sync`       | Apply current project `.ollama-claude.toml` over global config    |
| `oc status`     | Health, models, topology, wire-up state, switch state             |
| `oc doctor`     | End-to-end probe with per-role inference smoke                    |
| `oc models`     | List / set / override role→tag map                                |
| `oc topology`   | Switch `same` / `split-host` / `split-client`                     |
| `oc switch`     | `local` (sets `ANTHROPIC_BASE_URL`) / `cloud` (unsets)            |
| `oc wire-up`    | Inject env file source into shell rc; `--claude-settings` opts in |
| `oc claude-hooks` | Install/remove Claude Code session-backend audit hook           |
| `oc benchmark`  | Calibrate tier with tinyllama prompts                             |
| `oc self-update`| Fetch + verify newer release; keeps prior version                 |
| `oc uninstall`  | Remove service + configs; `--purge` for models                    |
| `oc version`    | Self + Ollama version + release notes URL                         |

## Design pointers

- §11 of the implementation plan (`/home/kali/.claude/plans/now-wor-on-creating-luminous-firefly.md`) is the canonical layout.
- §18 of the same plan is the self-audit catalogue — read it before touching anything subtle.
- Three load-bearing USPs: hardware-tier autopilot, AI dev environment as code (`.ollama-claude.toml` with model digests), explicit local/cloud switch with `oc switch`.

## Out of scope

- Runtime call interception / proxying (we are not in the call path)
- Telemetry of any kind
- Docker / Kubernetes packaging (ramalama owns that)
- GUI (LM Studio / Jan own that)
