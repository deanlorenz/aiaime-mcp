# Install guide

## Requirements

| Dependency | Version | Notes |
|---|---|---|
| Go | 1.22+ | `go version` to check |
| nats-server | any recent v2 | installed separately |
| jq | any | only needed for `scripts/install.sh` |
| systemd | user session | Linux only; macOS users start services manually |

## Install nats-server

```bash
curl -sf https://binaries.nats.dev/nats-io/nats-server/v2@latest | sh -s -- -b ~/.local/bin
```

Verify:
```bash
nats-server --version
```

## Install aiaime-mcp

```bash
git clone https://github.com/deanlorenz/aiaime-mcp.git
cd aiaime-mcp
make install
```

To install binaries to a custom location:
```bash
make install AIAIME_BIN_DIR=/usr/local/bin
```

## What `make install` does

1. Builds all six binaries and places them in `$AIAIME_BIN_DIR` (default `~/.local/bin`):
   - `aiaimed` — MCP server
   - `aiaime-relay` — NATS marker relay
   - `aiaime-hook` — PostToolBatch hook
   - `aiaime-setup` — project registration CLI
   - `aiaime-dialogue` — interactive human dialogue
   - `aiaime-pub` — one-shot publish CLI

2. Installs systemd user services:
   - `~/.config/systemd/user/nats-server.service`
   - `~/.config/systemd/user/aiaime-relay.service`
   - Both enabled and started immediately

3. Registers the PostToolBatch hook in `~/.claude/settings.json` (idempotent).

4. Adds the `aiaimed` MCP entry to `~/.bob/settings/mcp.json` (idempotent).

## Manual service management

```bash
# Status
systemctl --user status nats-server aiaime-relay

# Restart
systemctl --user restart nats-server aiaime-relay

# Stop
systemctl --user stop nats-server aiaime-relay

# View logs
journalctl --user -u nats-server -f
journalctl --user -u aiaime-relay -f
```

## macOS (without systemd)

Start services manually in background terminals or via launchd:

```bash
nats-server -js -sd ~/.aiaime/nats -p 4222 &
aiaime-relay &
```

## Registering a project

Run once from the project root:

```bash
cd /path/to/project
aiaime-setup my-bus-id
```

Check registration:
```bash
cat ~/.aiaime/repos.json
```

## MCP client configuration

### Claude Code
Automatically configured by `make install` via `~/.claude/settings.json`.

### IBM Bob
Automatically configured by `make install` via `~/.bob/settings/mcp.json`.

### Other MCP clients
Add to your MCP server list:
```json
{
  "name": "aiaime",
  "command": "/home/<you>/.local/bin/aiaimed",
  "env": {
    "AIAIME_NATS_URL": "nats://127.0.0.1:4222"
  }
}
```

`aiaimed` resolves the bus ID from `CLAUDE_PROJECT_DIR` (set by Claude Code), `AIAIME_CWD`, or the current working directory.

## Uninstall

```bash
make disable-services    # stop and disable systemd services
make uninstall           # remove binaries
make purge               # remove all local state (~/.aiaime/)
```

## Filesystem layout

```
~/.aiaime/
  repos.json                                     project-root → bus_id map
  nats/                                          JetStream storage
  subs/<bus_id>/<session_id>.json               subscribed topics + filters
  markers/<bus_id>/<session_id>/<topic>.marker  relay writes on new message
  cursors/<bus_id>/<session_id>/<topic>.cursor  hook writes after fetch
```
