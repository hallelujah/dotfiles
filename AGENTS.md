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

## Guidelines

- Always reference Neovim configuration files relative to `config/nvim`.
- When generating, editing, or referencing Neovim configuration, use the structure and linking method described above.
- Ensure compatibility with the symlinked configuration approach for reproducible setups.
