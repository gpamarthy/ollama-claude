# Changelog

All notable changes to ollama-claude are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial Phase 1 shell-script scaffolding
- `oc install / init / sync / status / doctor / models / topology / switch / wire-up / claude-hooks / benchmark / self-update / uninstall / version` subcommands
- Hardware-tier autopilot for NVIDIA, AMD, Apple Silicon, Intel iGPU/Arc, CPU-only
- Same-machine and split (host/client) topology presets
- Layered TOML config: built-in defaults → global → profile → project → env vars
- Profile bundles: `default`, `security-research`, `data-science`, `web-dev`, `minimalist`, `team`
- Claude Code session-backend audit hook (opt-in)
- Unit tests with mocked CLI fixtures (`bats-core`)
- Integration smoke against real Ollama on Linux runners
- AMD `HSA_OVERRIDE_GFX_VERSION` chip table

## [0.1.0] - TBD

First public release. See README for what works.

[Unreleased]: https://github.com/gpamarthy/ollama-claude/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/gpamarthy/ollama-claude/releases/tag/v0.1.0
