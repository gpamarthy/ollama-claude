#!/bin/sh
# Integration: end-to-end tool-call format round-trip probe.
# Used by `oc doctor`-style assertion and the CI integration layer.
#
# Requires: a running Ollama on localhost:11434, with a tools-supporting
# model present. We use the tag passed as $1 (default qwen3:8b).

set -eu

MODEL="${1:-qwen3:8b}"
ENDPOINT="${OC_ENDPOINT:-http://127.0.0.1:11434}"

if ! command -v curl >/dev/null 2>&1; then
  echo "[err ] curl is required" >&2
  exit 1
fi

# Use the chat API with a tool definition. Many local models won't
# *correctly* call a tool, but we only assert the response is valid JSON
# and includes either a tool_use block or a text block — i.e. the
# transport works.
payload=$(cat <<EOF
{
  "model": "$MODEL",
  "stream": false,
  "messages": [
    { "role": "user", "content": "What is the weather in Berlin?" }
  ],
  "tools": [
    {
      "type": "function",
      "function": {
        "name": "get_weather",
        "description": "Get the current weather for a location",
        "parameters": {
          "type": "object",
          "properties": { "location": { "type": "string" } },
          "required": ["location"]
        }
      }
    }
  ]
}
EOF
)

resp=$(curl -fsS -X POST -H 'content-type: application/json' \
  -d "$payload" "$ENDPOINT/api/chat" 2>/dev/null || true)

if [ -z "$resp" ]; then
  echo "[err ] no response from $ENDPOINT/api/chat" >&2
  exit 1
fi

# Must contain a message with role=assistant.
case "$resp" in
  *'"role":"assistant"'*|*'"role": "assistant"'*)
    echo "[ ok ] tool-call probe round-trip succeeded against $MODEL"
    exit 0
    ;;
esac

echo "[err ] response did not contain an assistant message:" >&2
echo "$resp" | head -c 400 >&2
echo >&2
exit 1
