#!/usr/bin/env bash
# install.sh — build and install aiaime binaries, hook, and MCP config.
#
# After running this once:
#   - aiaimed, aiaime-relay, aiaime-hook, aiaime-setup, aiaime-dialogue,
#     aiaime-pub are in ~/.local/bin/ (or $AIAIME_BIN_DIR)
#   - ~/.claude/settings.json has the PostToolBatch hook registered globally
#   - ~/.bob/settings/mcp.json has the aiaime MCP server entry
#
# Safe to re-run: all writes are idempotent.
#
# Requires: Go 1.22+, jq
# Install nats-server once:
#   curl -sf https://binaries.nats.dev/nats-io/nats-server/v2@latest | sh -s -- -b ~/.local/bin

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
BIN_DIR="${AIAIME_BIN_DIR:-$HOME/.local/bin}"

echo "==> Building aiaime binaries from $REPO_DIR"
(cd "$REPO_DIR" && go build -o "$BIN_DIR/aiaimed"          ./cmd/aiaimed)
(cd "$REPO_DIR" && go build -o "$BIN_DIR/aiaime-relay"     ./cmd/aiaime-relay)
(cd "$REPO_DIR" && go build -o "$BIN_DIR/aiaime-hook"      ./cmd/aiaime-hook)
(cd "$REPO_DIR" && go build -o "$BIN_DIR/aiaime-setup"     ./cmd/aiaime-setup)
(cd "$REPO_DIR" && go build -o "$BIN_DIR/aiaime-dialogue"  ./cmd/aiaime-dialogue)
(cd "$REPO_DIR" && go build -o "$BIN_DIR/aiaime-pub"       ./cmd/aiaime-pub)
echo "    all binaries -> $BIN_DIR/"

echo "==> Installing systemd user services"
SYSTEMD_DIR="$HOME/.config/systemd/user"
mkdir -p "$SYSTEMD_DIR"
cp "$REPO_DIR/systemd/nats-server.service"  "$SYSTEMD_DIR/"
cp "$REPO_DIR/systemd/aiaime-relay.service" "$SYSTEMD_DIR/"
systemctl --user daemon-reload
systemctl --user enable --now nats-server aiaime-relay
echo "    nats-server and aiaime-relay enabled and started"

echo "==> Registering PostToolBatch hook in ~/.claude/settings.json"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
if [ ! -f "$CLAUDE_SETTINGS" ]; then
    echo '{}' > "$CLAUDE_SETTINGS"
fi
HOOK_CMD="$BIN_DIR/aiaime-hook"
EXISTING=$(jq -r '(.hooks.PostToolBatch // []) | map(.hooks // []) | flatten | map(.command // "") | .[]' "$CLAUDE_SETTINGS" 2>/dev/null || true)
if echo "$EXISTING" | grep -qF "$HOOK_CMD"; then
    echo "    PostToolBatch hook already registered, skipping"
else
    TMP=$(mktemp)
    jq --arg cmd "$HOOK_CMD" '
      .hooks.PostToolBatch = ((.hooks.PostToolBatch // []) + [{
        "hooks": [{"type": "command", "command": $cmd, "timeout": 10}]
      }])
    ' "$CLAUDE_SETTINGS" > "$TMP" && mv "$TMP" "$CLAUDE_SETTINGS"
    echo "    PostToolBatch hook -> $CLAUDE_SETTINGS"
fi

echo "==> Registering aiaime in ~/.bob/settings/mcp.json"
BOB_MCP="$HOME/.bob/settings/mcp.json"
mkdir -p "$(dirname "$BOB_MCP")"
if [ ! -f "$BOB_MCP" ]; then
    echo '{"mcpServers":{}}' > "$BOB_MCP"
fi
AIAIME_IN_BOB=$(jq -r '.mcpServers.aiaime // empty' "$BOB_MCP" 2>/dev/null || true)
if [ -n "$AIAIME_IN_BOB" ]; then
    echo "    aiaime entry already in $BOB_MCP, skipping"
else
    TMP=$(mktemp)
    jq --arg bin "$BIN_DIR/aiaimed" '
      .mcpServers.aiaime = {"command": $bin, "env": {"AIAIME_NATS_URL": "nats://127.0.0.1:4222"}}
    ' "$BOB_MCP" > "$TMP" && mv "$TMP" "$BOB_MCP"
    echo "    aiaime entry -> $BOB_MCP"
fi

echo ""
echo "==> Done!"
echo ""
echo "    Next: register your project:"
echo "      cd /path/to/your/repo && aiaime-setup <bus_id>"
echo ""
echo "    Then open a terminal pane and run:"
echo "      aiaime-dialogue"
echo ""
echo "    See docs/getting-started.md for a walkthrough."
