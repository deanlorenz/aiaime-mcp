# Getting started with aiaime-mcp

This guide walks through a complete setup from scratch to a working multi-agent dialogue.

## Prerequisites

- Linux or macOS
- Go 1.22 or newer (`go version`)
- `jq` (`apt install jq` / `brew install jq`)

## Step 1 — Install nats-server

aiaime uses [NATS JetStream](https://docs.nats.io/nats-concepts/jetstream) as its transport. Install the server binary once per machine:

```bash
curl -sf https://binaries.nats.dev/nats-io/nats-server/v2@latest | sh -s -- -b ~/.local/bin
nats-server --version   # verify
```

## Step 2 — Build and install aiaime

Clone the repo and run the installer:

```bash
git clone https://github.com/deanlorenz/aiaime-mcp.git
cd aiaime-mcp
make install
```

`make install` does four things:
1. Builds all binaries into `~/.local/bin/`
2. Installs and enables the `nats-server` and `aiaime-relay` systemd user services
3. Registers `aiaime-hook` as a `PostToolBatch` hook in `~/.claude/settings.json`
4. Adds the `aiaimed` MCP server entry to `~/.bob/settings/mcp.json`

Verify services started:

```bash
make health
```

## Step 3 — Register your project

From your project's root directory, assign it a short bus ID:

```bash
cd /path/to/your/project
aiaime-setup my-project
```

This writes `/path/to/your/project → my-project` into `~/.aiaime/repos.json`. Any subdirectory of that path is automatically in scope.

## Step 4 — Open the dialogue terminal

Before starting any agent session that might ask you questions, open a dedicated terminal pane and run:

```bash
aiaime-dialogue
```

Keep this terminal visible. When an agent calls `aiaime_ask_user`, the question will appear here with a terminal bell and the tab title will change to `💬 [ACTION REQUIRED]`.

Type your reply and press **Enter** to send. Use a trailing `\` to continue onto the next line.

## Step 5 — Configure your agent

### Claude Code (automatic)
`make install` already registered the PostToolBatch hook. Claude Code will automatically surface new messages on subscribed topics at the start of each turn.

### IBM Bob
`make install` added `aiaimed` to `~/.bob/settings/mcp.json`. Restart Bob to pick it up.

### Other MCP clients
Add this to your MCP server config:
```json
{
  "command": "/home/<you>/.local/bin/aiaimed",
  "env": { "AIAIME_NATS_URL": "nats://127.0.0.1:4222" }
}
```

## Step 6 — First session

In your agent session, announce yourself and start working:

```
aiaime_subscribe(topic="my-mission", session_id="my-session-1")
aiaime_publish(topic="my-mission", from_session="my-session-1", kind="announce",
  body="session my-session-1 online")
```

To ask the developer a question (blocks until answered):

```
aiaime_ask_user(
  prompt="Should I proceed with the migration?",
  from_session="my-session-1"
)
```

To check what's happening on the bus:

```
aiaime_status()
```

## Naming convention for topics

Topics are free strings. A convention that works well:

```
<mission>                   — mission broadcast
<mission>.<session>         — session outbox
user.in                     — incoming questions to the developer
user.out                    — developer replies
```

## Restarting after a reboot

Services start automatically via systemd. After a reboot:

```bash
make health           # confirm running
aiaime-dialogue       # reopen in a terminal pane
```

## Troubleshooting

**`connect to NATS: no servers available`**
NATS server is not running. Check: `systemctl --user status nats-server` and restart if needed: `systemctl --user start nats-server`.

**`no aiaime registration found for ...`**
The current directory is not under a registered project root. Run `aiaime-setup <bus_id>` from the project root.

**Messages not appearing in Claude Code**
The hook may not be registered. Run `make install` again and check `~/.claude/settings.json` contains the `PostToolBatch` entry.
