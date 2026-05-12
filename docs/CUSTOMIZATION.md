# Customization

Five config layers and a detection cache. Deep merge, later wins.

## Layers

```
1. Built-in defaults     (config/*.toml in the installed version)
2. Global                (~/.config/ollama-claude/config.toml)
3. Profile bundle        (~/.config/ollama-claude/profiles/<name>.toml)
4. Project               (.ollama-claude.toml at git root)
5. Environment vars      (OC_*  — override anything)

Cache:
   Hardware detection    (~/.local/state/ollama-claude/detected.json)
```

Lists append-with-dedupe. Dicts deep-merge. Project layer can opt in to inheriting from a profile with `inherit = true`.

## Profiles

Six bundles ship out of the box:

| Profile               | Tweaks                                                                        |
|-----------------------|-------------------------------------------------------------------------------|
| `default`             | Tier autopilot, local-only, no telemetry                                       |
| `security-research`   | Code-review system prompts, **refuses** `oc switch cloud`                      |
| `data-science`        | `tools` role context boosted to 32k                                            |
| `web-dev`             | Demote `heavy` one tier so browser + node have headroom                        |
| `minimalist`          | Pull only the `fast` role                                                      |
| `team`                | Refuse to install unless `.ollama-claude.toml` is present in cwd               |

```sh
oc init --profile security-research      # bootstrap a project with this profile
oc profile new mine --from web-dev       # fork web-dev
```

## Environment as code

Drop `.ollama-claude.toml` at your repo root. Teammates run `oc sync` and get the same setup.

```toml
# $schema: https://ollama-claude.dev/schema/config-v1.json

[active]
profile = "default"

[topology]
default = "same"

# Pin by digest for reproducibility (run `oc models pin` once the
# models are pulled to fill these in).
[[models]]
name     = "qwen3:8b"
provider = "ollama"
roles    = ["fast", "tools"]
digest   = "sha256:abc...def"

[[models]]
name     = "qwen2.5-coder:14b"
provider = "ollama"
roles    = ["heavy"]
digest   = "sha256:..."
```

## Env-var overrides

Every config key has an `OC_*` env-var equivalent. The ones you reach for most:

| Variable                  | Meaning                                                |
|---------------------------|--------------------------------------------------------|
| `OC_TOPOLOGY`             | `same` / `split-host` / `split-client`                  |
| `OC_ALLOW_FROM`           | CIDR for split-host                                     |
| `OC_HOST`                 | `HOST:PORT` for split-client                            |
| `OC_PROFILE`              | Profile name                                           |
| `OC_ASSUME_YES`           | Skip prompts (`1`)                                     |
| `OC_REFRESH_DETECT`       | Force re-run of hardware detection                     |
| `OC_VERBOSE`              | Debug logging                                          |
| `OC_QUIET`                | Suppress info/ok lines                                 |
| `OC_OLLAMA_MIN_VERSION`   | Override the Ollama version pin                        |

## Hooks

Drop executables at `~/.config/ollama-claude/hooks/<event>` (global) or `<project>/.ollama-claude/hooks/<event>` (project). Both fire if both exist.

| Hook            | Fires when                              | Env passed                          |
|-----------------|------------------------------------------|-------------------------------------|
| `pre-install`   | Before any package operation             | `OC_TIER OC_OS OC_GPU`              |
| `pre-pull`      | Before each `ollama pull`                | `OC_MODEL OC_ROLE OC_DISK_FREE`     |
| `post-pull`     | After each successful pull               | `OC_MODEL OC_DIGEST`                |
| `post-install`  | After everything is wired                | `OC_TOPOLOGY OC_MODELS_JSON`        |
| `pre-doctor`    | Top of `oc doctor`                       | (none)                              |
| `post-doctor`   | End of `oc doctor`                       | `OC_DOCTOR_FAIL`                    |
| `pre-switch`    | Before `oc switch <mode>`                | `OC_SWITCH_FROM OC_SWITCH_TO`        |
| `post-switch`   | After `oc switch <mode>`                 | `OC_SWITCH_TO`                       |
| `pre-cloud`     | Right before `oc switch cloud` flips     | `OC_SWITCH_FROM`                     |

Example: a `pre-pull` hook that aborts when free disk is low.

```sh
#!/bin/sh
# ~/.config/ollama-claude/hooks/pre-pull
free_gb=$(df -BG "$HOME" | awk 'NR==2 {gsub(/G/, "", $4); print $4}')
if [ "$free_gb" -lt 10 ]; then
  echo "[hook] aborting pull of $OC_MODEL: only ${free_gb}G free" >&2
  exit 1
fi
```

## Editor auto-complete

Every shipped TOML has a `# $schema:` comment pointing at the published JSON Schema. VSCode and Zed pick this up automatically via the Even Better TOML / TOML LSP extensions.

## Per-role model routing

```toml
[roles.fast]
description = "Snappy chat, short prompts"
context     = 8192

[roles.tools]
description = "Tool calling"
context     = 16384

[roles.heavy]
description = "Deep refactors"
context     = 65536

[[models]]
name           = "qwen3:14b"
provider       = "ollama"
roles          = ["tools"]
supports_tools = true
context_safe   = 32768
```

The resolver refuses to route a `tools`-role request to a model whose `supports_tools` is `false`, even if you ask it to. Set `supports_tools = true` explicitly if you're sure.
