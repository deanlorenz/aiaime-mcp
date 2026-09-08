BIN_DIR   ?= $(HOME)/.local/bin
SYSTEMD   ?= $(HOME)/.config/systemd/user
CMDS       = aiaimed aiaime-relay aiaime-hook aiaime-setup aiaime-dialogue aiaime-pub

.PHONY: build install uninstall clean health services enable-services disable-services

## Build all binaries into BIN_DIR
build:
	@echo "==> Building aiaime binaries -> $(BIN_DIR)"
	@mkdir -p $(BIN_DIR)
	@for cmd in $(CMDS); do \
		echo "    go build ./cmd/$$cmd -> $(BIN_DIR)/$$cmd"; \
		go build -o $(BIN_DIR)/$$cmd ./cmd/$$cmd; \
	done
	@echo "    Done."

## Full install: build + systemd services + Claude hook + Bob MCP entry
install:
	@bash scripts/install.sh

## Remove all aiaime binaries from BIN_DIR
uninstall:
	@echo "==> Removing aiaime binaries from $(BIN_DIR)"
	@for cmd in $(CMDS); do \
		rm -f $(BIN_DIR)/$$cmd && echo "    removed $$cmd" || true; \
	done

## Stop and disable systemd services
disable-services:
	@echo "==> Disabling aiaime services"
	-systemctl --user stop aiaime-relay nats-server
	-systemctl --user disable aiaime-relay nats-server
	@echo "    Done."

## Enable and start systemd services (nats-server + aiaime-relay)
enable-services:
	@echo "==> Installing and starting aiaime services"
	@mkdir -p $(SYSTEMD)
	cp systemd/nats-server.service  $(SYSTEMD)/
	cp systemd/aiaime-relay.service $(SYSTEMD)/
	systemctl --user daemon-reload
	systemctl --user enable --now nats-server aiaime-relay
	@echo "    Done."

## Check service health
health:
	@echo "==> aiaime service status"
	@systemctl --user is-active nats-server   && echo "  nats-server:   running" || echo "  nats-server:   STOPPED"
	@systemctl --user is-active aiaime-relay  && echo "  aiaime-relay:  running" || echo "  aiaime-relay:  STOPPED"
	@echo ""
	@echo "==> Registered projects"
	@cat $(HOME)/.aiaime/repos.json 2>/dev/null || echo "  (none — run: aiaime-setup <bus_id>)"
	@echo ""
	@echo "==> NATS connection"
	@$(BIN_DIR)/aiaime-pub -topic health.check -body "ping" -kind note 2>/dev/null \
		&& echo "  NATS: OK" || echo "  NATS: UNREACHABLE (is nats-server running?)"

## Remove all local state (markers, cursors, subs) — does NOT delete NATS stream data
clean:
	@echo "==> Removing aiaime local state (markers, cursors, subs)"
	@rm -rf $(HOME)/.aiaime/markers $(HOME)/.aiaime/cursors $(HOME)/.aiaime/subs
	@echo "    Done. repos.json and NATS data preserved."

## Remove ALL aiaime data including NATS JetStream storage
purge: disable-services uninstall
	@echo "==> Purging all aiaime data from $(HOME)/.aiaime"
	@rm -rf $(HOME)/.aiaime
	@echo "    Done."

help:
	@echo "aiaime-mcp Makefile targets:"
	@echo "  make build            — build all binaries to \$$BIN_DIR"
	@echo "  make install          — full install (build + services + Claude + Bob)"
	@echo "  make uninstall        — remove binaries"
	@echo "  make enable-services  — install and start systemd services"
	@echo "  make disable-services — stop and disable systemd services"
	@echo "  make health           — check service and NATS status"
	@echo "  make clean            — remove local state (markers/cursors/subs)"
	@echo "  make purge            — remove everything including NATS data"
	@echo ""
	@echo "  BIN_DIR=$(BIN_DIR)  (override with: make BIN_DIR=/usr/local/bin)"
