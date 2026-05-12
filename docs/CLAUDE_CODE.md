# Claude Code wire-up

Claude Code has supported `ANTHROPIC_BASE_URL` as a first-party feature since 2025; Ollama added a native Anthropic-compatible endpoint in v0.14 (January 2026). Together they let you point Claude Code at a local Ollama with no proxy.

## The minimum

After `oc install`, this is the file we wrote for you:

```sh
# ~/.config/ollama-claude/claude-code.env
export ANTHROPIC_BASE_URL="http://127.0.0.1:11434"
export ANTHROPIC_AUTH_TOKEN="ollama"
unset ANTHROPIC_API_KEY
```

To use it once:

```sh
source ~/.config/ollama-claude/claude-code.env
claude
```

To make it persistent:

```sh
oc wire-up                  # appends a `source` line to ~/.bashrc or ~/.zshrc
oc wire-up --dry-run        # see what would change
oc wire-up --shell zsh      # override shell detection
oc wire-up --claude-settings  # ALSO write Claude Code settings.json (off by default)
```

## Why `unset` and not `=""`

Some Claude Code releases treat `ANTHROPIC_API_KEY=""` as "missing key" and fail before the request goes out. `unset ANTHROPIC_API_KEY` is the safe form on every version. If `oc doctor` reports your version handles the empty string fine, you can override with `OC_ANTHROPIC_API_KEY_FORM=empty`.

## Flipping back to cloud

```sh
oc switch cloud
```

This rewrites `claude-code.env` to *unset* `ANTHROPIC_BASE_URL` and `ANTHROPIC_AUTH_TOKEN`, so Claude Code falls through to its default endpoint with your real `ANTHROPIC_API_KEY`. `oc status` always shows whether you're in local or cloud mode.

To go back:

```sh
oc switch local
```

The `security-research` profile explicitly forbids `oc switch cloud` - fork the profile if you intend to switch.

## settings.json fragment

If you'd rather configure Claude Code via its settings file:

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://127.0.0.1:11434",
    "ANTHROPIC_AUTH_TOKEN": "ollama"
  }
}
```

`oc wire-up --claude-settings` will copy `config/claude-code.settings.example.json` to `~/.config/claude/settings.json` (refusing to overwrite if you already have one - merge manually in that case).

## Attribution-header gotcha

Claude Code adds a per-request `attribution` header that, in some Ollama versions, defeats prefix caching. If you see slow first-token times that don't make sense, try:

```json
{ "env": { "CLAUDE_CODE_ATTRIBUTION_HEADER": "0" } }
```

We don't set this for you - it's a documented behaviour change in a third-party tool and you should make the decision consciously.

## Fallbacks

If the Ollama-native Anthropic endpoint doesn't work for your version:

### LiteLLM proxy

```sh
pip install 'litellm[proxy]'
litellm --model ollama/qwen3:8b --port 4000
export ANTHROPIC_BASE_URL="http://127.0.0.1:4000"
```

### Ollama's OpenAI `/v1` endpoint

For tools that speak OpenAI rather than Anthropic, Ollama also exposes `http://127.0.0.1:11434/v1`. Not used by Claude Code itself but useful for Aider, OpenCode, etc.
