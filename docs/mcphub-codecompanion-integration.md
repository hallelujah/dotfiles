# MCPHub × CodeCompanion Integration Plan

## Goal

- **Single source of truth** for MCP servers: `~/.config/mcphub/servers.json` (mcphub.nvim).
- **One chat UI**: CodeCompanionChat, talking to agents over ACP (Claude Code, Gemini CLI).
- **No per-agent MCP duplication**: do not configure Figma / GitHub / Linear inside Claude Code, then again inside Gemini CLI, then again in any future agent.
- In CodeCompanionChat, get completion for MCP **prompts** (`/`) and **resources** (`#`) directly from the hub. Tools (`@`) is the trade-off documented below.

## What works today vs. what doesn't

| Surface in CodeCompanionChat (ACP) | Status | Mechanism |
|---|---|---|
| `@server` / `@server__tool` | **Does not work** | CodeCompanion filters tools out for ACP adapters |
| `/mcp:<prompt>` (MCP prompts) | Works | mcphub extension registers them as slash commands; client-side text expansion |
| `#<resource>` (MCP resources) | Works | mcphub extension registers them as variables; client-side text expansion |
| Agent actually *executing* MCP tools mid-conversation | **Not yet** — needs the work below | The ACP agent (Claude Code / Gemini) must itself be an MCP client of the hub |

## Root cause for `@tool` not appearing

`codecompanion.nvim/lua/codecompanion/providers/completion/init.lua:206-215`:

```lua
function M.tools()
  local bufnr = api.nvim_get_current_buf()
  local adapter_info = adapter_cache[bufnr]
  -- Only show tools for HTTP adapters
  if not adapter_info or adapter_info.type == "acp" then
    return {}
  end
```

ACP delegates tool execution to the agent process. CodeCompanion's tool registry (where mcphub registers `@figma__…`, `@github__…`, `@linear__…`) is never consulted when the chat is bound to an ACP adapter. The mcphub options `make_tools = true` and `show_server_tools_in_chat = true` are no-ops in this configuration.

That filter is intentional and not a bug to patch. The right fix is architectural: stop pushing tools through CodeCompanion at all, and instead make the **agent itself** an MCP client of the hub.

## Architecture

```
            ┌──────────────────────────────────────────────────┐
            │  ~/.config/mcphub/servers.json                   │
            │  figma-mcp · github · linear  (single source)    │
            └───────────────────────┬──────────────────────────┘
                                    │
                          managed by mcphub.nvim
                                    ▼
            ┌──────────────────────────────────────────────────┐
            │  mcp-hub  (Node, port 37373)                     │
            │  - /api/*  → mcphub.nvim management              │
            │  - /mcp    → unified MCP endpoint (streamable-   │
            │              HTTP), aggregates all servers       │
            └───────────────────────┬──────────────────────────┘
                                    │ http://localhost:37373/mcp
            ┌───────────────────────┼──────────────────────────┐
            │                       │                          │
            ▼                       ▼                          ▼
       claude-agent-acp        gemini --acp              CodeCompanionChat
       (MCP client of hub)     (MCP client of hub)       (UI only — uses mcphub
                                                          extension for /prompts
                                                          and #resources)
```

Two consumers, one config:

1. **Agent side (where tools actually execute)**: each ACP agent registers a single remote MCP server pointed at `http://localhost:37373/mcp`. The agent now sees every tool / resource / prompt the hub aggregates.
2. **Editor side (CodeCompanionChat UX)**: the existing mcphub extension keeps registering MCP **prompts** as `/mcp:<name>` slash commands and MCP **resources** as `#<name>` variables, so the user gets completion for those in the chat buffer. Tool completion (`@`) is dropped — see trade-offs.

## Plan

### Step 1 — Confirm the hub endpoint

`mcphub.nvim` already spawns `mcp-hub` on the default port (37373). Verify:

```sh
curl -s http://localhost:37373/api/health | jq
# Expect: { ..., "status": "ok" }
```

If it isn't running, open Neovim once (any `:MCPHub` command starts it) or start it standalone:

```sh
mcp-hub --port 37373 --config ~/.config/mcphub/servers.json
```

### Step 2 — Decide on a lifecycle

`mcp-hub` is a Neovim-managed process by default. For agents to use it outside an editing session, pick one:

- **A. Editor-bound (simplest)**: bump `shutdown_delay` in mcphub.nvim so the hub stays alive between Neovim sessions.

  ```lua
  require("mcphub").setup({
    servers_path = vim.fn.expand("~/.config/mcphub/servers.json"),
    shutdown_delay = 60 * 60 * 1000, -- 1h
  })
  ```

- **B. Always-on (systemd user unit)**: run `mcp-hub` as a user service, independent of Neovim. Recommended once the dotfiles flow is stable. Sketch:

  ```ini
  # ~/.config/systemd/user/mcp-hub.service
  [Unit]
  Description=MCP Hub (aggregator for MCP servers)

  [Service]
  ExecStart=%h/.local/share/mise/shims/mcp-hub --port 37373 --config %h/.config/mcphub/servers.json
  Restart=on-failure

  [Install]
  WantedBy=default.target
  ```

  Then `systemctl --user enable --now mcp-hub`. Decide later — start with option A.

### Step 3 — Automated: Claude and Gemini configs (tracked in dotfiles)

**Already done** — the configs are now baked into the dotfiles:

- **Claude**: `config/claude/.mcp.json` (tracked) → passed to `claude-agent-acp` via `--mcp-config` flag in `config/nvim/lua/plugins/ai.lua:40-41`
- **Gemini**: `.gemini.json` (project root, tracked) → auto-discovered by Gemini when running from dotfiles dir

When you launch CodeCompanionChat (`:CodeCompanionChat Toggle`), the agents are invoked from the dotfiles directory and automatically pick up the MCP hub config. No manual `mcp add` command needed.

**Verify**:
```sh
claude mcp list           # Should show mcphub (if invoked with --mcp-config)
gemini mcp list           # Should show mcphub (running from dotfiles dir)
```

### Step 4 — Local experiments (isolated from tracked config)

The tracked MCP config **will not be modified** by local `claude` or `gemini` commands.

**For Claude Code** (local-only experiments):
- Tracked: `config/claude/.mcp.json` → `~/.claude/.mcp.json` (injected via `--mcp-config`)
- Local override: `~/.claude/settings.local.json` (git-ignored, loaded after user `settings.json`)

```bash
# Add local experimental server (writes to ~/.claude/settings.local.json, NOT tracked)
claude config set mcpServers.experimental '{"type":"http","url":"http://localhost:8080/mcp"}'
```

**For Gemini CLI** (local-only experiments):
- Tracked: `.gemini.json` (project scope, in dotfiles repo)
- Local override: `~/.gemini/settings.json` (user scope, git-ignored)

```bash
# Add local experimental server (writes to ~/.gemini/settings.json, NOT tracked)
gemini mcp add --scope user experimental http://localhost:8080/mcp
```

In both cases, project/tracked config takes precedence, so your mcphub setup is never clobbered by local experiments.

### Step 5 — Keep CodeCompanion's mcphub extension, but tune it for ACP

In `config/nvim/lua/plugins/ai.lua`, the extension config is currently set up to register tools too. With ACP that's dead weight. Slim it to the surfaces that actually work over ACP:

```lua
extensions = {
  mcphub = {
    callback = "mcphub.extensions.codecompanion",
    opts = {
      -- Tools: ignored over ACP. Leaving false makes intent clear and
      -- avoids registering @server entries that never appear in completion.
      make_tools = false,
      show_server_tools_in_chat = false,
      add_mcp_prefix_to_tool_names = false,
      show_result_in_chat = false,
      format_tool = nil,

      -- Prompts → /mcp:<name>  (works over ACP, client-side expansion)
      make_slash_commands = true,

      -- Resources → #<name>  (works over ACP, client-side expansion)
      make_vars = true,
    },
  },
},
```

Reference for the filter that justifies turning the tool options off:
- `codecompanion.nvim/lua/codecompanion/providers/completion/init.lua:206-215`

### Step 6 — Verify end to end

1. Restart Neovim, confirm `:MCPHub` shows figma-mcp / github / linear as connected.
2. `curl -s http://localhost:37373/mcp` → server responds (streamable-HTTP handshake; a 405 / 400 with a JSON body is fine).
3. In CodeCompanionChat (`:CodeCompanionChat Toggle`): 
   - Type `/` → see `mcp:<prompt>` entries (e.g. `/mcp:commit` for MCP prompts)
   - Type `#` → see `#<resource>` variables from MCP servers
4. Ask Claude in CodeCompanionChat to "list available MCP tools" — it should enumerate Figma / GitHub / Linear tools because it's connected to the hub via the config.
5. Ask it to perform a real action (e.g. "fetch issue X from Linear") to confirm the tools actually execute.

**Optional verification (direct CLI)**:
```bash
# These will show mcphub if run from the dotfiles directory
cd ~/dotfiles
claude mcp list    # Should show mcphub (passed via --mcp-config)
gemini mcp list    # Should show mcphub (reads .gemini.json)
```

## Architecture decision: CodeCompanion as MCP client (or not)

CodeCompanion v19.12.0+ supports configuring MCP servers directly via `mcp.servers` and `mcp.opts.default_servers`. You might ask: should we add the mcphub hub as a CodeCompanion MCP server too?

**Answer: No, for ACP adapters.**

**Why not**:
1. **Redundant**: Agents already connect to mcphub. CodeCompanion as a separate MCP client adds no value.
2. **Tools still filtered out for ACP**: Even if CodeCompanion registers mcphub tools, the `@tool` picker is disabled for ACP adapters (intentional design, not a bug). Tools won't appear in completion.
3. **mcphub extension already handles what works**: Slash commands (`/mcp:<prompt>`) and variables (`#<resource>`) are exposed via the extension. That's sufficient for ACP.
4. **Config duplication**: You'd maintain MCP config in two places (agent configs + CodeCompanion config) for the same hub.

**Current architecture (correct for ACP)**:
```
Agents (Claude, Gemini) ──→ mcphub (MCP client) ──→ [tools, resources, prompts]
CodeCompanionChat (UI) ──→ mcphub extension ──→ [prompts as /, resources as #]
```

**Worth reconsidering IF**:
- You add HTTP adapters (Anthropic, OpenRouter) to CodeCompanionChat alongside ACP.
- HTTP adapters *do* support tool completion (`@`), so a dual setup might make sense:
  - Agents stay with direct mcphub connections.
  - CodeCompanion becomes an MCP client for its own tool picker, covering HTTP adapters.
- This lets you keep one agent config + one CodeCompanion config for the same hub.

Until then, leave CodeCompanion's `mcp.servers` empty and rely on the mcphub extension.

## Trade-offs and open questions

- **No `@tool` picker over ACP**. The user cannot explicitly mention a tool to force the agent to call it. The agent picks tools autonomously. If explicit tool routing matters later, the only way to recover it is to switch that chat to an HTTP adapter (Anthropic / OpenRouter / etc.). Worth re-evaluating when CodeCompanion adds tool support to ACP — track upstream.
- **Server name in `/` tooltip**. `mcphub.nvim/lua/mcphub/extensions/codecompanion/slash_commands.lua:24-29` reads `prompt.server_name` but discards it from the description. Surfacing it requires either a small local override or an upstream PR adding a `format_prompt` opt symmetrical with `format_tool`. Out of scope for this plan; track separately.
- **Auth tokens**. Today each MCP server in `~/.config/mcphub/servers.json` reads its secret via `${cmd: op.exe read ...}`. Once agents connect through the hub, only the hub needs those secrets — the agent configs only carry the hub URL. Confirm 1Password CLI is available in the environment that runs `mcp-hub` if you move to the systemd unit (Step 2B).
- **Local hub bound to localhost**. `mcp-hub` listens on 127.0.0.1:37373. If multi-user / WSL networking edge cases appear, document them here.
- **Port conflict**. If 37373 is taken, set `port` in `mcphub.setup{}` and update agent config URLs to match.

## Out of scope

- Patching CodeCompanion to enable tool completion for ACP adapters.
- Server-name annotation in slash command completions.
- Always-on systemd unit (deferred until editor-bound lifecycle proves insufficient).
