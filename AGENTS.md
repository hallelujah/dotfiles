# AI Instructions

## Purpose

This file provides standardized instructions for AI agents and tools interacting with this repository, following the [agents.md](https://agents.md/) specification.

## Neovim Configuration Structure

- The Neovim configuration is located at `config/nvim` within this repository.
- When setting up on a system, link the `config` directory to your user config path with:

  ```sh
  ln -s $DOTFILES_PROJECT/config ~/.config
  ```

- All Neovim-related configuration and customizations should be referenced relative to `config/nvim`.

## Dotfiles Management

- This repository is managed with [rcm](https://github.com/thoughtbot/rcm).
- Run `rcup` to symlink all dotfiles from this repo to `~/`.
- The `config/` directory is symlinked to `~/.config/`.
- Local overrides go in `~/.zshrc.local`, `~/.zshenv.local`, etc. (not tracked here).

## MCP Configuration

MCP servers are declared in `config/mcphub/servers.json` (tracked; symlinked to `~/.config/mcphub/servers.json`). The hub is launched by `bin/mcp-hub-run`, a wrapper that loads `OP_SERVICE_ACCOUNT_TOKEN` from `~/.config/environment.d/op-service-account.conf` and execs `mcp-hub` against the registry. Both the Linux and macOS service definitions invoke this wrapper. Secrets are resolved at startup via `bin/op-wrapper`. Claude and Gemini connect to the hub over SSE at `http://localhost:37373/mcp`. See `docs/centralized-mcp-config.md` for the full architecture and rollback steps.

OAuth-based servers (e.g. Linear) require a one-time interactive bootstrap so the systemd/launchd unit can refresh tokens unattended. Run `bin/mcp-auth-bootstrap [URL]` from a terminal with browser access; it caches tokens under `~/.mcp-auth/` (lives in `$HOME`, not tracked) and the long-lived refresh token is what keeps the hub working headlessly thereafter.

### Service install

**Linux (systemd-user)** — `config/systemd/user/mcp-hub.service` is symlinked into `~/.config/systemd/user/` by `rcup`. Enable with:

```sh
systemctl --user daemon-reload
systemctl --user enable --now mcp-hub
```

**macOS (launchd)** — `config/launchd/com.user.mcp-hub.plist` is not auto-installed by `rcup` (Apple looks in `~/Library/LaunchAgents/`, which must not be a tracked symlink target). Install with:

```sh
ln -sfn "$HOME/.config/launchd/com.user.mcp-hub.plist" \
        "$HOME/Library/LaunchAgents/com.user.mcp-hub.plist"
launchctl bootstrap "gui/$(id -u)" \
        "$HOME/Library/LaunchAgents/com.user.mcp-hub.plist"
```

Unload with `launchctl bootout "gui/$(id -u)/com.user.mcp-hub"`. Logs go to `/tmp/mcp-hub.{out,err}.log`.

## Code Search (semble)

[semble](https://github.com/MinishLab/semble) is a fast, local, embedding-based code search tool optimized for AI agents (~98% fewer tokens than grep + read). It is exposed to Claude Code (and any other agent connected to the hub) as the `semble` MCP server in `config/mcphub/servers.json` and is auto-installed/upgraded by `hooks/post-up` via `uv tool install --upgrade 'semble[mcp]'`.

**Prefer semble over `grep` + `Read` when locating code by intent or concept.** Use `grep` only for exact-string lookups (literal identifiers, error messages, log lines).

CLI usage from a shell:

```sh
semble search "where is the auth middleware" .
semble find-related path/to/file.py 42 .
```

After editing `config/mcphub/servers.json`, restart the hub to pick up the new server: `systemctl --user restart mcp-hub` (Linux) or `launchctl kickstart -k "gui/$(id -u)/com.user.mcp-hub"` (macOS).

## Guidelines

- Always reference Neovim configuration files relative to `config/nvim`.
- When generating, editing, or referencing Neovim configuration, use the structure and linking method described above.
- Ensure compatibility with the symlinked configuration approach for reproducible setups.
- Do not suggest storing secrets or API keys in tracked dotfiles. Use `~/.zshrc.local` or `~/.gemini/.env` for sensitive values.
