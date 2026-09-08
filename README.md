# aiaime-mcp

A local, lightweight pub/sub message bus for coordinating AI agent sessions on a single developer machine. Built on [NATS JetStream](https://docs.nats.io/nats-concepts/jetstream) with a [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) server so any MCP-capable agent (Claude Code, IBM Bob, or any custom tool) can publish, subscribe, and replay messages across sessions.

## What it does

Multiple AI agent sessions working on the same project need to coordinate — hand off work, share status, ask the developer questions, and resume after restarts. aiaime gives them a durable, topic-based message bus:

- **Durable replay** — messages persist in NATS JetStream. A restarted session catches up from where it left off.
- **Topic-based routing** — free-form dot-separated topic names. No enforced hierarchy.
- **Silent wake** — the `aiaime-hook` PostToolBatch hook wakes Claude Code sessions when a new message arrives on a subscribed topic, without polling.
- **Human dialogue** — `aiaime-dialogue` is an interactive terminal CLI where the developer can read and reply to questions from agents in real time.
- **Multi-project** — one NATS server per machine, isolated per project via a short bus ID.

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│  Developer machine                                        │
│                                                           │
│  nats-server (JetStream)  ←→  aiaime-relay               │
│       ↑                            ↓                      │
│  aiaimed (MCP stdio)        ~/.aiaime/markers/            │
│  ┌──────────────────┐             ↓                       │
│  │  Agent session   │      aiaime-hook (PostToolBatch)    │
│  │  Claude / Bob    │                                     │
│  └──────────────────┘      aiaime-dialogue (terminal)    │
└──────────────────────────────────────────────────────────┘
```

| Binary | Role |
|---|---|
| `nats-server` | Message broker (external, installed separately) |
| `aiaime-relay` | Watches NATS, writes marker files for the hook |
| `aiaimed` | MCP server — exposes 6 tools to agent sessions |
| `aiaime-hook` | PostToolBatch hook — surfaces new messages each turn |
| `aiaime-dialogue` | Interactive terminal CLI for human ↔ agent dialogue |
| `aiaime-setup` | One-time project registration |
| `aiaime-pub` | One-shot CLI publish for scripting |

## Quick start

```bash
# 1. Install nats-server (once per machine)
curl -sf https://binaries.nats.dev/nats-io/nats-server/v2@latest | sh -s -- -b ~/.local/bin

# 2. Build and install
make install

# 3. Register your project (from repo root)
aiaime-setup my-project

# 4. Open a terminal pane for dialogue
aiaime-dialogue

# 5. Configure your MCP client — see docs/install.md
```

See [docs/getting-started.md](docs/getting-started.md) for a full walkthrough.

## MCP tools

Once registered, agents call these tools via MCP:

| Tool | Description |
|---|---|
| `aiaime_publish` | Publish a message to a topic |
| `aiaime_fetch_since` | Fetch messages newer than a sequence number |
| `aiaime_subscribe` | Subscribe to a topic (enables hook wake) |
| `aiaime_unsubscribe` | Unsubscribe from a topic |
| `aiaime_status` | List all active topics and optionally session state |
| `aiaime_ask_user` | Ask the developer a question via `aiaime-dialogue` |

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `AIAIME_NATS_URL` | `nats://127.0.0.1:4222` | NATS server URL |
| `AIAIME_CWD` | `os.Getwd()` | Override working directory for bus ID resolution |
| `AIAIME_AGENT_NAME` | `unknown` | Agent identity label in published messages |
| `AIAIME_BIN_DIR` | `~/.local/bin` | Install destination for `make install` |

## Requirements

- Go 1.22+
- `nats-server` with JetStream (installed separately — see above)
- `jq` (for `scripts/install.sh` only)
- Linux or macOS; systemd user services for autostart

## License

MIT
