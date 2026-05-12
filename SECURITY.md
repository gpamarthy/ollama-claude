# Security policy

## Supported versions

While the project is pre-1.0, only the latest tagged release receives security fixes. Once `v1.0` ships, the most recent minor on each major line is supported.

## Reporting a vulnerability

**Do not file public issues for security problems.**

Email a description of the issue (and ideally a reproduction) to the maintainer. Expect an acknowledgement within 72 hours and a fix or mitigation plan within 14 days for issues that can be reproduced.

If the maintainer has not responded in 14 days, you are free to disclose publicly.

## Threat model

`ollama-claude` is an installer + configurator. It does not sit in the request path, does not run a daemon, and does not transmit data off the host. The threat surfaces we actively defend:

- **Tarball integrity** - `install.sh` verifies SHA256SUMS against the GitHub Release. Phase 2 binaries are cosign-signed.
- **Network exposure** - `OLLAMA_HOST` defaults to `127.0.0.1`. `--topology split-host` refuses to bind on a non-loopback interface without an explicit `--allow-from CIDR`. `OLLAMA_ORIGINS=*` is never written.
- **Shell rc / Claude settings mutation** - never modified without explicit `oc wire-up` / `oc wire-up --claude-settings`.
- **Pre-existing Ollama installs** - detected and reported; never overwritten without prompt.

Out of scope (will not be fixed via this project):

- Vulnerabilities in upstream Ollama, the model weights, or Claude Code itself. Report those to the respective projects.
- Local-attacker escalation when the user has chosen `--topology split-host` with a wide CIDR. We document the risk; the user owns the topology decision.
