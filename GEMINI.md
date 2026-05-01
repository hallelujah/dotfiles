# AI Instructions

## Purpose

This file provides context for Gemini CLI when working in this repository,
following the [agents.md](https://agents.md/) specification.

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

## Guidelines

- Always reference Neovim configuration files relative to `config/nvim`.
- When generating, editing, or referencing Neovim configuration, use the structure and linking method described above.
- Ensure compatibility with the symlinked configuration approach for reproducible setups.
- Do not suggest storing secrets or API keys in tracked dotfiles. Use `~/.zshrc.local` or `~/.gemini/.env` for sensitive values.
