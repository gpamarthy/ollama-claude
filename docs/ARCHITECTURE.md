# Architecture

This document describes the runtime shape of `ollama-claude`. For the rationale and trade-offs behind each design choice, see the plan at `/home/kali/.claude/plans/now-wor-on-creating-luminous-firefly.md` (or the equivalent in your checkout).

## We are not in the call path

`ollama-claude` is a **configurator**, not a proxy. It writes files and starts services. After install, the data plane looks like this:

```
   ┌──────────┐                  ┌─────────────────────────┐
   │  Claude  │ ── messages ──▶  │   Ollama (local)        │
   │   Code   │                  │   127.0.0.1:11434       │
   └────┬─────┘                  │   Anthropic-compatible  │
        │                        │   endpoint              │
        │                        └─────────────────────────┘
        │
        │ when ANTHROPIC_BASE_URL is unset:
        │
   ┌────▼───────────────┐
   │ api.anthropic.com  │
   └────────────────────┘
```

`oc switch local` exports `ANTHROPIC_BASE_URL` and points Claude Code at Ollama. `oc switch cloud` unsets it, and Claude Code talks to Anthropic directly. The switch is deterministic and visible (`oc status`). We never sit in the middle of a request.

## Subcommand dispatcher

```
oc <command> [args]
   │
   ├── bin/oc                       POSIX-sh dispatcher
   │     resolves OC_PROJECT_ROOT and OC_LIB_DIR
   │     sources bin/lib/<command>.sh
   │     calls oc_cmd_<command>
   │
   ├── bin/oc.ps1                   PowerShell dispatcher
   │     same flow, calls Invoke-Oc<Command>
   │
   └── bin/lib/<command>.{sh,ps1}   one file per subcommand
```

Subcommands share helpers from `lib/`:

- `lib/log.sh`     - colour-aware logging
- `lib/ui.sh`      - prompts, confirms (fail-closed without a TTY)
- `lib/detect.sh`  - hardware + OS detection, cached
- `lib/config.sh`  - minimal TOML reader; layered config merge
- `lib/ollama.sh`  - install / pull / digest wrappers
- `lib/claude.sh`  - render the env file; report wire-up state
- `lib/hooks.sh`   - run user lifecycle hooks

## Layered configuration

Five layers, deep-merged, later wins, lists append-with-dedupe:

1. **Built-in defaults** - embedded in `config/`
2. **Global** - `~/.config/ollama-claude/config.toml`
3. **Profile** - `~/.config/ollama-claude/profiles/<name>.toml`
4. **Project** - `.ollama-claude.toml` at git root
5. **Env vars** - `OC_*` prefix

Plus a 6th detection cache at `~/.local/state/ollama-claude/detected.json` with a 7-day freshness window.

## Topologies

- **same** - default. `OLLAMA_HOST=127.0.0.1:11434`. No firewall change.
- **split-host** - Ollama runs here; clients connect over LAN. Refuses to run without `--allow-from CIDR`. Firewall scoped to that CIDR only. `OLLAMA_ORIGINS=*` is never written.
- **split-client** - Ollama runs elsewhere. We only write `claude-code.env` pointing at `--host HOST:PORT` and run a connectivity probe.

State persisted to `~/.config/ollama-claude/topology` so re-runs and `oc status` stay coherent.

## Hardware tiering

`lib/detect.sh` probes vendors in this order (first hit wins): NVIDIA, AMD ROCm, Apple Metal (macOS only), Intel Vulkan, CPU fallback. Detection result is cached so subsequent commands don't re-run probes.

Tier is determined by **effective VRAM × total RAM**, not VRAM alone. Apple Silicon uses unified memory: `effective_vram = total_ram * 0.75`.

The tier → role → tag map lives in `config/models.toml`. The resolver verifies each tag exists in the Ollama registry before pulling, and walks one tier down on miss. Empty string (`heavy = ""` for cpu tier) is treated as intentional skip, not a failure.

## On-disk schema

```
~/.config/ollama-claude/
  config.toml          user overrides
  topology             current topology name
  profile              active profile
  claude-code.env      generated; sourceable
  profiles/<name>.toml user-forked profiles
  hooks/<event>        user lifecycle hooks

~/.local/state/ollama-claude/
  detected.json        cached hardware detection
  sessions.jsonl       Claude Code session audit log (opt-in)

~/.local/share/ollama-claude/
  <version>/           installed versions
    bin/ lib/ config/ platform/ docs/

~/.local/bin/oc        symlink into the active version
```

## Phase 1 vs Phase 2

This is the shell-script MVP. Subcommand tree, on-disk schema, and network shape match what the Phase 2 Go binary will ship. The install path will swap from "fetch shell-script tarball" to "fetch Go binary tarball" with no user-visible change.
