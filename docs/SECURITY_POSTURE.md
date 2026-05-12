# Security posture

`ollama-claude` is a configurator. It does not run a daemon, does not sit in the request path, and does not transmit data off the host. This document spells out exactly what we promise and what we don't.

## Promises

- **No telemetry.** Not opt-in, not opt-out — none. No phone-home, no anonymous stats, no crash uploads.
- **No silent network calls.** The installer fetches a tarball + checksum at install time, and afterwards `oc self-update` will fetch newer releases on demand. Nothing else.
- **No silent dotfile edits.** `oc wire-up` is the only path that touches shell rc files. `oc wire-up --claude-settings` is the only path that touches `~/.config/claude/settings.json`. Neither runs automatically.
- **`OLLAMA_HOST` defaults to loopback.** `127.0.0.1:11434`. The only path that binds on a non-loopback interface is `--topology split-host`, which refuses to run without an explicit `--allow-from CIDR`.
- **`OLLAMA_ORIGINS=*` is never written.** Even in `split-host`, origins are either unset or scoped to specific entries.
- **Pre-existing Ollama installs are never overwritten without prompt.** `oc install` scans for them and asks before touching state.
- **Tarball integrity.** `install.sh` verifies `SHA256SUMS` against the GitHub Release. Phase 2 binaries are cosign-signed.

## Default invariants (asserted by tests)

| Invariant                                                                | Enforced where                            |
|--------------------------------------------------------------------------|-------------------------------------------|
| `OLLAMA_HOST = 127.0.0.1:11434` unless `--topology split-host` + CIDR     | `bin/lib/install.sh`, `tests/property/`   |
| `OLLAMA_ORIGINS=*` never written                                          | `lib/claude.sh`, `tests/property/`        |
| Shell rc never modified without explicit `oc wire-up`                     | `bin/lib/wire-up.sh`                       |
| Claude `settings.json` never modified without `oc wire-up --claude-settings` | `bin/lib/wire-up.sh`                  |
| No model marked installed until digest is confirmed via `ollama show`     | `lib/ollama.sh:oc_ollama_pull`             |
| `cpu` tier has `heavy = ""`; doctor reports skip, not failure              | `bin/lib/doctor.sh`                        |
| `security-research` profile rejects `oc switch cloud`                     | `bin/lib/switch.sh`                        |

## Threat model

What we defend against:

- **Tarball tampering.** SHA256 verification (Phase 1); cosign signature (Phase 2).
- **Accidental LAN exposure.** Default loopback bind; CIDR-scoped firewall in split-host.
- **Surprise cloud calls.** `oc switch` is the only path that flips Claude Code between local and cloud. `oc status` always shows current mode. Profiles can forbid cloud.
- **Dotfile drift.** Never edited unless the user runs `oc wire-up`.

What we **don't** defend against:

- **Vulnerabilities in upstream Ollama or Claude Code.** Report those to the respective projects.
- **A local attacker on the same machine.** They have your shell; they have your dotfiles.
- **A local attacker on the LAN when you chose `split-host` with a wide CIDR.** We document the risk; the topology decision is yours.
- **Sophisticated supply chain attacks** beyond SHA256 (e.g. compromise of the GitHub Release process itself). Phase 2 cosign signing improves this.

## Reporting vulnerabilities

See [SECURITY.md](../SECURITY.md). Do not file public issues for security problems.

## Audit log

`oc claude-hooks install` installs an opt-in Claude Code session hook that logs which backend (local, cloud, custom) each session used to `~/.local/state/ollama-claude/sessions.jsonl`. This is observational only — we never sit in the request path. Tail it with:

```sh
oc claude-hooks tail
```
