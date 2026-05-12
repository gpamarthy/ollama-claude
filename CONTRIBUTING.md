# Contributing

Thanks for considering a contribution. The most useful contributions right now are:

1. **New hardware fixtures** in `tests/fixtures/` - canned `nvidia-smi` / `rocm-smi` / `system_profiler` / `Get-CimInstance` outputs from real machines. These drive the unit tests for `lib/detect.sh`.
2. **Failure reports** for boxes where `oc install` or `oc doctor` does not produce a working setup. Open an issue with `oc version`, `oc status`, and the output of `oc doctor --verbose`.
3. **Profile bundles** for domains we have not covered yet (mobile, ML research, embedded, …).
4. **Documentation** - especially `docs/TROUBLESHOOTING.md` entries derived from real support requests.

## Dev setup

```sh
git clone https://github.com/gpamarthy/ollama-claude
cd ollama-claude

# Tools
sudo apt install shellcheck shfmt bats
# or: brew install shellcheck shfmt bats-core

make ci
```

## Code style

- POSIX `sh` for everything under `lib/` and `bin/lib/*.sh`. Bash only in `install.sh` (which re-execs under bash if it isn't already).
- Two-space indent. `shfmt -i 2 -ci -sr -d` must pass.
- `shellcheck` must pass.
- PowerShell scripts mirror their shell counterparts; `Invoke-ScriptAnalyzer` must pass.
- No emojis. No "AI written" markers. Plain prose in commits and comments.

## Commit messages

[Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/). Examples:

```
feat: add HSA_OVERRIDE for RX 6700 XT
fix: handle qwen tool-call loop detection on Ollama < 0.17.7
docs: clarify split-host firewall scoping
test: add fixture for M3 Pro 18 GB
```

## PRs

- Branch off `main`.
- Each PR should be reviewable in one sitting. Prefer a series of small PRs over a single large one.
- New code paths need at least one unit test. New hardware paths need a fixture.
- Update `CHANGELOG.md` under `[Unreleased]`.

## Testing your change

```sh
make ci         # static + unit + contract + integration
make nightly    # adds simulation + chaos + property layers (slow)
```

To test against a real hardware target you do not have, drop a fixture in `tests/fixtures/<probe>/<hardware-id>.txt` and reference it from a new test in `tests/unit/`.

## Security

Do not file security issues in public. See [SECURITY.md](SECURITY.md).
