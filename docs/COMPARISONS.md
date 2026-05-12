# How `ollama-claude` compares to the alternatives

| Tool                          | What it does                                                    | What `ollama-claude` adds                                                       |
|-------------------------------|------------------------------------------------------------------|---------------------------------------------------------------------------------|
| **Raw Ollama (`ollama install`)** | Installs Ollama, lets you pull models                           | Hardware tiering, Claude Code wire-up, reproducibility via `.ollama-claude.toml` |
| **ramalama**                  | Containerized local AI with rootless security                    | Bare-metal default, no container runtime requirement, Claude Code integration   |
| **llamafile**                 | Single-file portable AI executables                              | Multi-machine setup, model sharing across roles, IDE integration                |
| **LM Studio**                 | GUI explorer for local models                                    | CLI-first, scriptable, works headless and in CI                                 |
| **Open WebUI**                | Web chat frontend for Ollama                                     | Targeted at Claude Code, not at building your own chat UI                       |
| **LiteLLM**                   | Proxy/router across LLM providers                                | No proxy needed; uses Ollama's native Anthropic endpoint                        |
| **GPT4All**                   | Desktop app with pre-optimised models                            | Multi-model setup, role-based routing, dev-loop integration                     |
| **Jan**                       | Offline-first desktop with cloud fallback                        | CLI-first, scriptable, integrates with terminal-based dev workflows             |
| **Tabby**                     | IDE-integrated code completion                                   | Different scope — we're a setup tool, Tabby is an autocomplete engine            |
| **continue.dev**              | IDE extension for AI coding                                      | We complement, not replace — you can use continue.dev with our Ollama setup     |
| **aider**                     | Terminal AI pair programming                                      | We complement — aider can use our Ollama setup as its model backend              |
| **OpenCode**                  | Open-source Claude Code alternative                              | We wire up the **real** Claude Code; if you prefer OpenCode, use it on top      |
| **Manual setup**              | `curl https://ollama.com/install.sh + Claude Code docs`         | Hardware detection, model picking, topology presets, repeatable config           |

## What we **don't** try to be

- **A GUI** — LM Studio and Jan already do that well; we stay CLI-first.
- **A proxy** — Ollama exposes the Anthropic-compatible endpoint natively; LiteLLM exists if you need provider sprawl.
- **A container runtime** — ramalama owns that ground. Use it if you want isolation by default.
- **A fleet management tool** — `.ollama-claude.toml` checked into git is enough coordination for most teams. If you need a control plane, that's a different product.

## When to **not** use `ollama-claude`

- You enjoy manual setup and want to learn how each piece works. Just install Ollama and read the Claude Code docs — it's a 20-minute job and you'll understand more.
- You're deploying to a Kubernetes cluster. Use ramalama or build your own Helm chart.
- You only ever use Claude in the browser. None of this is relevant to you.
- You have a non-standard Anthropic enterprise setup (custom endpoints, SSO). The Anthropic LLM-gateway docs are the right starting point.

## When **to** use `ollama-claude`

- You want Claude Code working with a local Ollama and you don't want to pick the model yourself.
- Your team needs everyone on the same local model set, pinned by digest.
- You move between machines (laptop / workstation / VM) and want the same `claude` command to do the right thing on each.
- You want the option to flip between local and cloud Claude with one command.
