# Changelog

All notable changes to ollama-claude are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.1] - 2026-05-12

### Fixed
- CI: pinned `shfmt` download URL so it stops 404-ing on the version-bearing asset
- CI: PowerShell `Invoke-ScriptAnalyzer` now loops over files instead of passing an array to `-Path`
- `lib/detect.sh`: `oc_detect_gpu_apple` actually probes `system_profiler` instead of claiming success on every Darwin host, so PATH-mocked tests can simulate "no GPU" on macOS runners
- `bin/oc`: `OC_VERSION` bumped to `0.1.1` (was `0.1.0-dev`)

## [0.1.0] - 2026-05-12

First public release. Phase 1 shell-script MVP.

### Added
- `oc install / init / sync / status / doctor / models / topology / switch / wire-up / claude-hooks / benchmark / self-update / uninstall / version` subcommands
- Hardware-tier autopilot for NVIDIA, AMD ROCm, Apple Metal, Intel iGPU/Arc, CPU-only, WSL2
- Five hardware tiers (`cpu`, `low`, `mid`, `high`, `workstation`) chosen from effective VRAM and total RAM
- Same-machine and split (host/client) topology presets
- Layered TOML config: built-in defaults, global, profile, project, env vars
- Profile bundles: `default`, `security-research`, `data-science`, `web-dev`, `minimalist`, `team`
- Claude Code session-backend audit hook (opt-in)
- AMD `HSA_OVERRIDE_GFX_VERSION` chip table
- PowerShell mirror of `install`, `status`, `doctor`, `switch`, `wire-up`, `version`
- 18 bats unit + contract tests, 50-iteration property test, integration smoke
- `oc --version` / `oc -V` aliases for `oc version`
- `oc doctor` reports warnings separately from failures; clean install with no models pulled exits 0
- `oc models set` overrides honoured by the resolver
- Pre-existing Ollama install detection is logged explicitly
- `oc switch` and `oc status` show both the env-file intent and the current-shell state
- CI matrix (Ubuntu, macOS, Windows) and nightly distro-container matrix

### Known limitations
- Phase 2 Go binary not yet started; `install.sh` runs shell scripts directly
- macOS launchd plist not yet tested on a real Apple Silicon box
- AMD `HSA_OVERRIDE_GFX_VERSION` table needs PRs to cover more chips
- `oc self-update` is a stub until releases exist

[Unreleased]: https://github.com/gpamarthy/ollama-claude/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/gpamarthy/ollama-claude/releases/tag/v0.1.1
[0.1.0]: https://github.com/gpamarthy/ollama-claude/releases/tag/v0.1.0
