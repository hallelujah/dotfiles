# mcp-picker

A Snacks.nvim picker that lists capabilities exposed by the centralized
`mcp-hub` (see `docs/centralized-mcp-config.md`), grouped by server, and
inserts them into a `CodeCompanionChat` buffer either as a reference or
as expanded content.

Hub assumption: `mcp-hub.service` is running on `http://localhost:37373`.

Code lives in `config/nvim/lua/mcp-picker/`:
- `init.lua` — setup + entry points
- `hub.lua` — HTTP client to mcp-hub
- `picker.lua` — Snacks picker + actions
- `codecompanion.lua` — CodeCompanion glue

For the design history and per-phase build log, see
`docs/codecompanion-mcp-picker.md`.

## Usage

### Opening the picker

- **From CodeCompanionChat:** type `/mcp` and confirm from the completion popup.
- **From anywhere:** `:McpPicker`
- **Health check:** `:McpPicker health`

### Actions

| Key | Action |
|-----|--------|
| `<CR>` | **Add reference** — inserts the capability identifier at cursor |
| `<C-e>` | **Expand content** — inserts the full content at cursor |
| `<a-p>` | Toggle preview pane (standard Snacks binding) |

### Reference format by kind

| Kind | Inserted text | Example |
|------|--------------|---------|
| tool | MCP tool ID in backticks | `` `mcp__mcphub__github__get_me` `` |
| prompt | prompt name | `AssignCodingAgent` |
| resource template | URI template | `repo://{owner}/{repo}/contents{/path*}` |

### Typical chat workflow

```
/mcp  →  pick `mcp__mcphub__github__get_me`

Use `mcp__mcphub__github__get_me` to tell me who I am on GitHub.
```

For prompts, prefer `<C-e>` (expand) — it fetches and inserts the full
prompt template, which the agent treats as structured context.

### `setup()` options

```lua
require("mcp-picker").setup({
  hub_url   = "http://localhost:37373",  -- mcp-hub address
  categories = { "tools", "prompts", "resourceTemplates" },
  picker_backend = "snacks",             -- only snacks supported today
})
```

## Design decisions

- **All capability kinds in the picker** — tools, prompts, and
  resourceTemplates. Actual `resources` are 0 across all servers; the
  meaningful capabilities are tools (figma, github, linear), prompts
  (github), and resourceTemplates (github).
- **`/mcp` slash command trigger** inside `CodeCompanionChat`. Coexists
  with built-in `/buffer`, `/file`, etc. CodeCompanion's own `/mcp`
  command is disabled when `config.mcp.servers` is empty, so no conflict.
- **Custom build, not `mcphub.nvim`.** That plugin's CodeCompanion
  extension only injects one slash command per prompt — not a picker,
  not grouped, no tools or resourceTemplates.
- **Snacks picker** — supports `preview.text` for the description pane,
  named `actions` for multi-keybinding, and an arbitrary `format`
  function. No native section headers, so grouping is done via
  `[server][kind] name` text prefix.

## Out of scope

- Replacing CodeCompanion's built-in slash commands (`/buffer`, `/file`).
- Live updates when `servers.json` changes — hub must be restarted
  manually; the picker re-fetches on every open.
- Per-server authentication UI (e.g. Linear OAuth flow).
- Multi-hub (we have one hub at a known URL).
- Telescope/fzf-lua picker backends — `picker_backend` setup option
  exists for future use; only Snacks is implemented today.
