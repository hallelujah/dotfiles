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

MCP servers are declared in `config/mcphub/servers.json` (tracked; symlinked to `~/.config/mcphub/servers.json`). The hub runs as a systemd `--user` service (`config/systemd/user/mcp-hub.service`). Secrets are resolved at startup via `bin/op-wrapper`, which uses a 1Password service account token (`OP_SERVICE_ACCOUNT_TOKEN` from `~/.config/environment.d/op-service-account.conf`). Claude and Gemini connect to the hub over SSE at `http://localhost:37373/mcp`. See `docs/centralized-mcp-config.md` for the full architecture and rollback steps.

## Guidelines

- Always reference Neovim configuration files relative to `config/nvim`.
- When generating, editing, or referencing Neovim configuration, use the structure and linking method described above.
- Ensure compatibility with the symlinked configuration approach for reproducible setups.
- Do not suggest storing secrets or API keys in tracked dotfiles. Use `~/.zshrc.local` or `~/.gemini/.env` for sensitive values.
