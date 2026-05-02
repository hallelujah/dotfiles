# Centralized MCP Configuration Plan

> Status: proposed. Executor: any AI model, free to modify.
> Last revised: 2026-05-01.

## Why

Today MCP servers are wired into Neovim via `mcphub.nvim`, which owns the
lifecycle of the `mcp-hub` daemon (Node, port 37373). That couples a system
concern (which MCP servers exist, where their secrets live) to an editor
plugin. Goal: move the registry into tracked dotfiles, run the hub
independently, let every consumer (Claude Code, Gemini CLI, CodeCompanion)
read from one place.

## Current state (verified)

- Source of truth: `~/.config/mcphub/servers.json` — **not tracked**, lists
  `figma-mcp`, `github`, `linear`. Secrets are resolved via
  `${cmd: op.exe read 'op://...'}` (1Password CLI).
- `mcp-hub` binary installed at
  `~/.local/share/mise/installs/npm-mcp-hub/4.2.1/bin/mcp-hub`; spawned today
  by `mcphub.nvim` when Neovim starts.
- Already tracked and symlinked by `rcup`:
  - `claude/mcp.json` → `~/.claude/mcp.json` — points Claude at
    `http://localhost:37373/mcp`. Passed to `claude-agent-acp` via
    `--mcp-config` in `config/nvim/lua/plugins/ai.lua:24-48`.
  - `.gemini.json` (repo root) — same pointer for Gemini, auto-discovered
    when Gemini runs from the dotfiles directory.
- `op` CLI installed at
  `~/.local/share/mise/installs/1password-cli/2.34.0/op`.

## Target architecture

```
        config/mcphub/servers.json        (tracked)
                  │   rcup symlink
                  ▼
        ~/.config/mcphub/servers.json
                  │
                  ▼
   mcp-hub (systemd --user, port 37373)
                  │   http://localhost:37373/mcp
       ┌──────────┼──────────────┐
       ▼          ▼              ▼
   claude    gemini          CodeCompanionChat
   (uses     (uses           (ACP adapter; agent
   ~/.claude/ .gemini.json)  is the MCP client,
   mcp.json)                 not the editor)
```

Two consequences worth naming up front:

1. **Neovim no longer owns the hub.** `mcphub.nvim` is removed.
2. **The `/mcp:<prompt>` and `#<resource>` UX in CodeCompanionChat goes
   away** (it ships from the `mcphub.extensions.codecompanion` extension,
   which depends on `mcphub.nvim`). Tools still execute — the agent itself
   is the MCP client of the hub. If we want the UX back later, see
   "Open question: editor-side MCP UX" at the bottom.

## Decision: aggregator hub via systemd, not per-agent script

Two paths considered:

| Approach | One-line summary | Picked? |
|---|---|---|
| **A. Aggregator hub** | One config → `mcp-hub` daemon → all agents point at one URL | **Yes** |
| **B. Per-agent script** | Post-`rcup` script runs `claude mcp add` / `gemini mcp add` per server | No |

Why A:

- 80% already in place (`mcp-hub` installed, Claude/Gemini already configured
  to hit the URL).
- One 1Password resolution path. Secrets only need to be reachable by the
  hub process, not by every agent process.
- Adding a new MCP server is one edit to `servers.json` — no per-agent
  registration, no script reruns.
- A future MCP-aware tool (a third agent, a CLI, a CI job) just hits the
  same URL.

Why not B:

- Each agent has its own config schema (`claude mcp add`, `gemini mcp add`,
  …). Drift is guaranteed.
- `npx`-launched servers and 1Password lookups would run once per agent
  process, not once globally.
- Re-running the script becomes a manual step that's easy to forget.

`samanhappy/mcphub` was raised. It is a different project from the
`mcp-hub` Node binary already installed (which is what `mcphub.nvim` spawns)
and would be a net-new dependency. Skip it for now; reconsider only if
`mcp-hub` proves insufficient.

## Steps

Each step is independently testable. Stop and report if a verification
fails — do not paper over it in a later step.

### Step 1 — Track `servers.json` in dotfiles

1. Create the directory in the repo:
   ```sh
   mkdir -p ~/dotfiles/config/mcphub
   ```
2. Move the live config into the repo and replace it with a symlink (the
   `config/` dir is already symlinked to `~/.config/` per `AGENTS.md`, so
   moving the file into `config/mcphub/` is what wires it up):
   ```sh
   mv ~/.config/mcphub/servers.json ~/dotfiles/config/mcphub/servers.json
   rmdir ~/.config/mcphub  # should now be empty
   cd ~/dotfiles && rcup -v
   ```
3. Verify:
   ```sh
   readlink ~/.config/mcphub          # → .../dotfiles/config/mcphub
   cat ~/.config/mcphub/servers.json  # content present
   ```
4. Confirm `AGENTS.md` rule: secrets are referenced via
   `${cmd: op.exe read ...}`, not literal tokens. Tracking the file is safe.
   If any literal secret slipped in, abort and rotate before committing.

### Step 2 — Run `mcp-hub` as a systemd `--user` service

1. Resolve the absolute binary path once and reuse it (mise shim path is
   stable for the user):
   ```sh
   readlink -f ~/.local/share/mise/shims/mcp-hub
   # e.g. /home/hery/.local/share/mise/installs/npm-mcp-hub/4.2.1/bin/mcp-hub
   ```
2. Create `~/.config/systemd/user/mcp-hub.service`:
   ```ini
   [Unit]
   Description=MCP Hub (aggregator for MCP servers)
   After=default.target

   [Service]
   Type=simple
   # Ensure 1Password CLI is on PATH so ${cmd: op read ...} resolves.
   Environment=PATH=%h/.local/share/mise/shims:%h/.local/bin:/usr/local/bin:/usr/bin:/bin
   ExecStart=%h/.local/share/mise/shims/mcp-hub --port 37373 --config %h/.config/mcphub/servers.json
   Restart=on-failure
   RestartSec=3

   [Install]
   WantedBy=default.target
   ```
3. Decide whether to track the unit file. Recommended: yes —
   `config/systemd/user/mcp-hub.service` in dotfiles, symlinked by `rcup`.
   Reproducible across machines.
4. Enable and start:
   ```sh
   systemctl --user daemon-reload
   systemctl --user enable --now mcp-hub.service
   systemctl --user status mcp-hub.service --no-pager
   ```
5. Verify:
   ```sh
   curl -s http://localhost:37373/api/health | jq .status   # "ok"
   curl -s -X POST http://localhost:37373/mcp -H 'content-type: application/json' \
     -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | jq '.result.tools | length'
   # > 0 expected
   ```
6. WSL note: `systemctl --user` requires a user manager (`loginctl
   enable-linger $USER` once if needed). If systemd is unavailable in the
   WSL distro, fall back to a `tmux`-detached process or
   `~/.local/bin/mcp-hub-supervisor.sh` run from `.zprofile`. Document the
   fallback in `docs/` if used.

### Step 3 — Confirm Claude & Gemini still see the hub

These configs already exist; this step is verification only.

```sh
cd ~/dotfiles
claude mcp list      # should show "mcphub" → http://localhost:37373/mcp
gemini mcp list      # ditto
```

If either tool does not list `mcphub`:

- Claude: confirm `~/.claude/mcp.json` is the symlink to
  `dotfiles/claude/mcp.json` (`readlink ~/.claude/mcp.json`). The agent is
  invoked with `--mcp-config ~/.claude/mcp.json` from
  `config/nvim/lua/plugins/ai.lua:46`, so this file must resolve.
- Gemini: the CLI auto-discovers `.gemini.json` from the working directory.
  CodeCompanion launches `gemini --acp` (`config/nvim/lua/plugins/ai.lua:82`).
  Confirm the launch cwd is `~/dotfiles` (or move the config to
  `~/.gemini/settings.json`).

### Step 4 — Remove `mcphub.nvim` from Neovim

Edit `config/nvim/lua/plugins/ai.lua`:

1. Delete the `ravitemer/mcphub.nvim` plugin spec (lines 3-13 in current
   file).
2. Remove `"ravitemer/mcphub.nvim"` from the CodeCompanion `dependencies`
   list (line 21).
3. Remove the entire `extensions.mcphub` block (lines 115-134).
4. Leave the `adapters.acp.claude_code` and `adapters.acp.gemini_cli`
   blocks alone — those are independent of `mcphub.nvim`.

Resulting expectation: `:Lazy sync` removes `mcphub.nvim` and the extension
silently. CodeCompanionChat still works; it just no longer shows
`/mcp:<prompt>` or `#<resource>` completion.

### Step 5 — End-to-end verification

1. `:Lazy sync` in Neovim, restart.
2. `:CodeCompanionChat Toggle` — chat window opens with `claude_code`
   adapter (default).
3. Send: *"List the MCP tools you have available."* — response should
   enumerate Figma / GitHub / Linear tools (proves the agent is talking to
   the hub).
4. Send: *"Fetch the most recent issue assigned to me from Linear."* —
   should execute a real MCP tool call.
5. Repeat 2–4 with `:CodeCompanionChat Toggle adapter=gemini_cli`.
6. Reboot the machine; verify `mcp-hub.service` comes up automatically and
   step 5 still passes.

### Step 6 — Documentation hygiene

1. Update `docs/mcphub-codecompanion-integration.md` with a header note:
   *"Superseded by `centralized-mcp-config.md` once Step 4 is shipped."*
   Don't delete it — its rationale section about the ACP tool filter is
   still load-bearing context.
2. Add a one-paragraph note to `AGENTS.md` under "Dotfiles Management"
   pointing at this plan as the canonical place for MCP config.

## Rollback

If anything in steps 2–4 breaks usage, the path back is:

1. `systemctl --user disable --now mcp-hub.service` (Step 2 reversed).
2. `git revert` the commit(s) for steps 1, 4, 6.
3. `cd ~/dotfiles && rcup -v` to restore the previous symlinks.
4. Restart Neovim — `mcphub.nvim` returns and spawns its own hub on 37373.

The Claude and Gemini pointer configs (`claude/mcp.json`, `.gemini.json`)
do not need to change during rollback — they keep working as long as
something is listening on 37373.

## Open questions (do not block execution)

- **Editor-side MCP UX.** If the loss of `/mcp:<prompt>` + `#<resource>` in
  CodeCompanionChat is felt, options are: (a) keep `mcphub.nvim` installed
  but in a mode where it does *not* spawn the hub (check upstream for an
  `auto_start = false` or external-hub option); (b) live without it. Defer
  until after Step 5 ships and we see whether anyone misses the UX.
- **Always-on vs. editor-bound hub.** Step 2 picks always-on. If the hub
  proves flaky as a service, fall back to spawning it from `.zprofile` or
  a tmux session — same binary, same flags.
- **`samanhappy/mcphub`.** Re-evaluate only if `mcp-hub` (Node) hits a
  blocker we can't fix: e.g., we need a Web UI, multi-tenant auth, or
  per-server isolation. None are required today.

## Out of scope

- Switching CodeCompanionChat from ACP adapters to HTTP adapters.
- Patching CodeCompanion's ACP tool-completion filter.
- Multi-machine / remote-host MCP routing.
