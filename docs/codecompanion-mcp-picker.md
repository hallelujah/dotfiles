# CodeCompanion MCP Picker — Implementation Plan

> Status: proposed. Last revised: 2026-05-02.
> Audience: Claude Sonnet, working with the user incrementally.
> Hub assumption: `mcp-hub.service` is running on `http://localhost:37373`
> per `docs/centralized-mcp-config.md`. Do not restart it during this work.

## Goal

In a `CodeCompanionChat` buffer, the user invokes a Snacks.nvim picker
that lists MCP capabilities exposed by the hub, grouped by server
(figma, github, linear, future…). For each item the user can:

- **Add as reference** (default action): insert the item as a chat
  reference (e.g. `#github:repository/foo` or whatever syntax
  CodeCompanion processes at send time).
- **Expand content** (alternate action): fetch the actual prompt /
  resource body from the hub and insert it inline as expanded text.

Description of each item is visible inline as the user scrolls the
picker (Snacks preview pane).

## Hard requirements (locked)

- Picker = Snacks.nvim (already wired via LazyVim).
- Items grouped by MCP server.
- Two selection actions: "add reference" and "expand content".
  Distinct keybindings, no confirm dialog.
- Item description is visible in the picker (preview pane, not just a
  line of text).
- Adding new MCP servers to `config/mcphub/servers.json` should make
  them appear in the picker after a hub restart, without code changes.
- Don't reintroduce `mcphub.nvim` as a hub-spawner. If we reuse its
  CodeCompanion extension, run it in external-hub / `auto_start=false`
  mode and verify the daemon isn't re-spawned by Neovim.
- Don't break existing adapters: `claude_code` and `gemini_cli` ACP must
  keep working (`config/nvim/lua/plugins/ai.lua`).

## Open questions (Phase 0 — confirm with user before coding)

- **Q1 — What goes in the picker?**
  - (a) Prompts only — the classic `/mcp:<prompt>` UX.
  - (b) Resources only — the classic `#<resource>` UX.
  - (c) Prompts + Resources (recommended).
  - (d) Prompts + Resources + Tools (tools are usually agent-driven,
        not user-driven, but include them if discoverability matters
        more than ergonomics).
- **Q2 — Trigger?**
  - (a) New `/mcp` slash command (recommended — coexists with
        built-in `/buffer`, `/file`, etc.).
  - (b) Override `/` itself so it always opens the unified picker.
  - (c) Keybinding (e.g. `<leader>am`); leave `/` to native CodeCompanion.

Sonnet: ask the user once at the end of Phase 0; pick reasonable
defaults if they decline to answer. Don't ask again later.

---

## Phase 0 — Research and decisions (no code)

Goal: in ~30 minutes of investigation, know what we're building and
whether to reuse a plugin or write our own.

### Tasks

1. **Hub capability survey.** Confirm what the hub exposes per server:
   ```sh
   curl -fsS http://localhost:37373/api/servers \
     | jq '.servers[] | {name, status, caps: (.capabilities | keys)}'
   ```
   Capture which servers expose `prompts`, `resources`, `tools`. If a
   capability isn't returned at all by the REST endpoint, find the
   correct endpoint (try `/api/servers/{name}/prompts`, etc.) — we
   already verified `tools` work via this endpoint, but resources and
   prompts may need a different one or an SSE call.

2. **Existing plugin survey.** Check if anything already does this:
   - `ravitemer/mcphub.nvim` — known. Read its `lua/mcphub/extensions/codecompanion.lua`.
     Confirm whether it has `auto_start = false` or external-hub mode,
     what picker it uses (vim.ui.select / telescope / fzf-lua / snacks),
     and whether it groups by server. License?
   - Search GitHub for "mcp picker codecompanion" / "mcp.nvim" /
     "mcp-hub neovim" and list any other relevant projects with a
     one-line summary each.
   - `olimorris/codecompanion.nvim` extensions docs — does it have a
     first-party MCP integration we missed?

3. **Snacks API check.** Verify:
   - `require("snacks").picker` exists in this LazyVim setup.
   - Snacks supports section headers / grouped items, or whether
     grouping has to be faked via a `group` field per item.
   - Snacks supports a custom action map (different keys → different
     callbacks on the same item).
   - Snacks supports a preview pane fed by an arbitrary string (the
     description), not just a file path.

4. **Decision.** Write a "Phase 0 outcome" section at the bottom of
   this doc with three lines:
   - **Picker contents:** prompts | resources | both | all
   - **Trigger:** `/mcp` slash | `/` override | keybinding
   - **Path:** reuse `mcphub.nvim` (with config X) | reuse other
     plugin Y | custom build at `config/nvim/lua/mcp-picker/`

### Stop and confirm

After writing the decision, surface it to the user with a one-line
summary. Don't start Phase 1 until the user okays it.

---

## Phase 1 — Standalone proof of concept (no CodeCompanion yet)

Goal: a single Vim command, e.g. `:McpPicker`, opens a Snacks picker
showing items from **one** server (start with `github` — known to be
reliable), with a description preview pane. No CodeCompanion
integration yet.

### Acceptance

- `:McpPicker` opens the picker.
- Picker shows ≥ 1 item from the github MCP server.
- Highlighting an item populates the preview pane with its description.
- Pressing `<CR>` closes the picker and prints `selected: <item-name>`
  via `vim.notify` — nothing more.
- All code lives in **one new file**: `config/nvim/lua/mcp-picker/init.lua`.
  Wire it via a thin plugin spec in `config/nvim/lua/plugins/`.

### Test (Sonnet runs)

```vim
:source %    " or restart Neovim
:McpPicker
```

Sonnet: take a screenshot if possible, otherwise describe what you
see (item count, preview content). Ask the user to confirm the look
and feel before moving on.

### Stop and confirm

If the user wants different visual layout, sort order, item format —
iterate inside Phase 1, don't push to Phase 2.

---

## Phase 2 — Multi-server, grouped, two actions

Goal: feature-complete picker, still standalone (still triggered by
`:McpPicker`).

### Acceptance

- Picker queries all servers from the hub on open. Disconnected
  servers (e.g. linear without OAuth) appear as a section header
  "linear (disconnected)" with no items — no errors.
- Items grouped by server in the picker. Server name acts as a
  section header, or items show `[server] item-name` if Snacks doesn't
  do real headers.
- Two actions, distinct keybindings (suggest defaults; let user
  override):
  - `<CR>` → "add reference": insert reference syntax at cursor in
    the current buffer (whatever buffer; we wire to chat in Phase 3).
  - `<C-e>` → "expand content": fetch the prompt/resource body from
    the hub and insert the expanded text at cursor.
- Hub errors (network, 5xx, malformed JSON) surface via `vim.notify`
  with `vim.log.levels.ERROR`. Never `error()` out of a callback.
- Picker re-fetches items on every open (hub state can change).

### Test (Sonnet runs)

1. Open a scratch buffer (`:enew`).
2. `:McpPicker`.
3. Verify grouping in the picker.
4. `<CR>` on a github item → reference appears in scratch buffer.
5. `<C-e>` on a different github item → expanded body appears.
6. Stop the hub:
   ```sh
   sudo systemctl --user stop mcp-hub.service   # ON THE HOST
   ```
   Re-open `:McpPicker`. Confirm a notify appears, no traceback. Then
   restart the hub:
   ```sh
   sudo systemctl --user start mcp-hub.service
   ```
   Re-open `:McpPicker` and confirm normal operation.

### Stop and confirm

Sonnet: report what worked, what didn't, anything surprising.

---

## Phase 3 — Wire into CodeCompanion

Goal: invoke the Phase 2 picker from inside `CodeCompanionChat` via
the trigger chosen in Phase 0. Selection inserts at the chat prompt
cursor.

### Two implementation paths (pick one based on Phase 0 outcome)

- **Path A — reuse `mcphub.nvim`'s extension.** Re-add `mcphub.nvim`
  with `auto_start = false` and `port = 37373`. Confirm via journalctl
  that no second `mcp-hub` process spawns. Use its CodeCompanion
  extension. Override its picker by registering Snacks as the
  `vim.ui.select` handler (Snacks does this natively in LazyVim).
  Verify the result still meets all Phase 2 acceptance criteria,
  especially grouping.
- **Path B — custom slash command.** Register a CodeCompanion slash
  command via the plugin's `extensions` option (or its
  `register_slash_command` API; check the version we have). The
  command's callback opens the Phase 2 picker; selection writes into
  the CodeCompanion chat buffer at the appropriate position.

### Acceptance

- Open `CodeCompanionChat` via `<leader>ac`.
- Trigger picker per Phase 0 decision (e.g. type `/mcp` and Enter).
- Snacks picker opens with grouped items.
- `<CR>` inserts a chat reference at the prompt cursor; sending the
  chat causes the agent to actually invoke the MCP tool/resource
  (verify by sending a real message and seeing the tool call happen).
- `<C-e>` inserts expanded content at the prompt cursor.
- Both work in both `claude_code` and (if we kept it) `gemini_cli`
  adapters.

### Test (Sonnet + user)

End-to-end in Neovim:
1. `<leader>ac` to open chat.
2. Trigger picker, pick a `github` resource, "add reference".
3. Type a question that needs the resource, send.
4. Verify the agent fetches it (look for the tool call in the chat).
5. Repeat with "expand content" action.

### Stop and confirm

Sonnet: ask the user to drive the chat for 5 minutes. Capture
anything that feels off.

---

## Phase 4 — Stabilize and prepare for extraction

Goal: code is structured so it could become its own plugin without
restructuring later.

### Tasks

1. Re-arrange to a structure compatible with a standalone plugin:
   ```
   config/nvim/lua/mcp-picker/
     init.lua            (setup + entry points)
     hub.lua             (HTTP client to mcp-hub)
     picker.lua          (Snacks picker; abstract enough that
                          telescope/fzf-lua could swap in later)
     codecompanion.lua   (CodeCompanion glue)
   ```
2. `setup({...})` accepts:
   - `hub_url` (default `http://localhost:37373`)
   - `slash_command` (default `mcp`)
   - `categories` (default `{ "prompts", "resources" }`)
   - `actions` (table; default `{ ["<CR>"] = "reference", ["<C-e>"] = "expand" }`)
   - `picker_backend` (default `"snacks"`)
3. Light tests (no full test runner — just a `:checkhealth` style
   command):
   - `:McpPicker health` — pings the hub, lists configured servers,
     reports the action map. Useful for debugging.
4. `docs/codecompanion-mcp-picker.md` (this file) gets a "Usage"
   section appended once the API is stable.
5. License decision (default: MIT).

### Optional — extract to its own repo

Only on explicit user request:
- New repo `mcp-picker.nvim` (or similar — bikeshed later).
- Move `lua/mcp-picker/` over.
- Replace the local plugin spec with a `{ "user/mcp-picker.nvim" }`
  Lazy.nvim entry pointing at the new repo.
- Add README, LICENSE, CI for stylua + luacheck.

Do not perform extraction without the user saying so.

---

## Operating rules for Sonnet

- **Stop at every phase boundary.** Even when a phase passes the
  acceptance criteria, ask the user if the UX matches what they
  wanted. UX feedback is grounds for iterating inside the phase, not
  pushing forward.
- **Append progress to this doc** under a `## Progress` heading at
  the end. Each entry: phase, date, decisions made, gotchas. This
  way a later Sonnet session can resume cleanly.
- **Never restart the host `mcp-hub.service`** unless explicitly
  asked (Phase 2's hub-down test is the one exception, and you must
  restart it after).
- **Verify, don't assume.** When you write code that calls a hub
  endpoint, hit it with `curl` first to see the actual response
  shape. Don't infer from documentation that may be stale.
- **Ask before mutating.** Before adding/removing plugins, changing
  Lazy specs, or editing `ai.lua`, restate the plan and confirm.
- **Use `vim.notify` for user-facing errors,** never `error()` out
  of a callback. The picker should always close cleanly.
- **Test with the hub actually serving real data** — figma + github
  are connected; linear may be disconnected (OAuth). Don't mock the
  hub responses for development.

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

### `setup()` options (advanced)

```lua
require("mcp-picker").setup({
  hub_url   = "http://localhost:37373",  -- mcp-hub address
  categories = { "tools", "prompts", "resourceTemplates" },
  picker_backend = "snacks",             -- only snacks supported today
})
```

## Out of scope

- Replacing CodeCompanion's built-in slash commands (`/buffer`, `/file`).
- Live updates when `servers.json` changes (hub must be restarted
  manually; the picker picks up changes on next open).
- Per-server authentication UI (Linear OAuth flow).
- Multi-hub (we have one hub at a known URL).
- Telescope/fzf-lua picker backends — design for it (see Phase 4
  `picker_backend` option) but don't implement until someone needs it.

## Rollback

If at any point this becomes a tar pit:
1. `git revert` the commits that added `mcp-picker/` and the slash
   command wiring.
2. Remove any `mcphub.nvim` re-addition from `ai.lua`.
3. CodeCompanion goes back to working without the picker; agents
   still talk to the hub directly. Loss is only the editor-side UX.

## Phase 0 outcome

- **Picker contents:** tools + prompts + resourceTemplates (all three). Actual `resources` are 0 across all servers; the meaningful capabilities are tools (figma 7, github 41, linear 30), prompts (github 2: `AssignCodingAgent`, `issue_to_fix_workflow`), and resourceTemplates (github 5: `repository_content*`).
- **Trigger:** `/mcp` slash command inside `CodeCompanionChat`.
- **Path:** custom build at `config/nvim/lua/mcp-picker/`. `mcphub.nvim`'s CodeCompanion extension injects one slash command per prompt only — not a picker, not grouped, not tools/resourceTemplates. Snacks picker supports `preview.text` for description pane, named `actions` for multi-keybinding, and arbitrary `format` function. No native section headers; grouping via `[server] item-name` prefix text.

## Progress

### Phase 0 — 2026-05-02

- Hub has 0 actual `resources`; picker will show tools + prompts + resourceTemplates.
- `mcphub.nvim` extension rejected: only injects per-prompt slash commands, no picker.
- Snacks picker confirmed: `items` list, `preview.text` for description pane, `actions` table for named callbacks, `keys` maps keys → action names. Grouping via text prefix (no native headers).
- Decision: custom build, `/mcp` slash command trigger, all capability types in picker.

### Phase 4 — 2026-05-02

- Refactored into 4 files: `init.lua` (setup + entry), `hub.lua` (HTTP + item building), `picker.lua` (Snacks picker + actions), `codecompanion.lua` (CodeCompanion glue).
- `setup({})` accepts `hub_url`, `categories`, `picker_backend`.
- Reference format for tools changed to MCP tool ID: `` `mcp__mcphub__github__get_me` `` — the format the agent recognises.
- Prompts reference inserts the prompt name; resourceTemplate reference inserts the URI template.
- `:McpPicker health` pings the hub and reports per-server capability counts.
- Removed old `mcp-completion` module.

### Phase 3 — 2026-05-02

- `open_for_chat(chat)` captures cursor position before picker opens; inserts into `chat.bufnr` at that position after picking.
- Wired via `strategies.chat.slash_commands["mcp"].callback` in `ai.lua` (CodeCompanion maps `strategies` → `interactions` internally).
- Built-in CodeCompanion `/mcp` command is disabled when `config.mcp.servers` is empty — no conflict.
- User confirmed: picker opens from `/mcp` in CodeCompanion chat, insertion works.

### Phase 2 — 2026-05-02

- All servers queried on open; disconnected servers emit WARN notify and are skipped cleanly.
- Items prefixed `[server][kind] name`; all 78+ tools + 2 prompts + 5 resourceTemplates shown.
- `<CR>` inserts `@mcp:server:name` reference at cursor; `<C-e>` expands content.
- Prompt expand collects required args via `vim.ui.input`, POSTs to `/api/servers/prompts`, inserts messages.
- Tool expand inserts description; resourceTemplate expand inserts URI template.
- `restore_and()` helper captures `target_win` before picker opens and restores focus on action.
- User confirmed all acceptance criteria pass.

### Phase 1 — 2026-05-02

- `config/nvim/lua/mcp-picker/init.lua` + `config/nvim/lua/plugins/mcp-picker.lua` created.
- `:McpPicker` opens Snacks picker with github tools/prompts/resourceTemplates.
- Fix required: must set `format = "text"` explicitly; default falls back to `format.file` which renders nothing.
- Item format confirmed: `[github][tool] name`, `[github][prompt] name`, `[github][resource] name`.
- Preview pane renders markdown description. `<CR>` notifies `selected: name`. User confirmed.
