local M = {}

-- Returns the MCP tool ID as Claude sees it: mcp__mcphub__<server>__<tool>
local function tool_id(server, name)
  return "mcp__mcphub__" .. server:gsub("-", "_") .. "__" .. name
end

local function make_reference(item)
  if item.kind == "tool" then
    return "`" .. tool_id(item.server, item.cap_name) .. "`"
  elseif item.kind == "prompt" then
    return item.cap_name
  else
    return item.uri_template ~= "" and item.uri_template or item.cap_name
  end
end

local function insert_at(text, bufnr, row, col)
  local lines = vim.split(text, "\n", { plain = true })
  if bufnr and row and col then
    vim.api.nvim_buf_set_text(bufnr, row - 1, col, row - 1, col, lines)
  else
    local r, c = unpack(vim.api.nvim_win_get_cursor(0))
    vim.api.nvim_buf_set_text(0, r - 1, c, r - 1, c, lines)
  end
end

local function collect_args(args_spec, cb)
  local required = vim.tbl_filter(function(a) return a.required end, args_spec)
  local values = {}
  local function ask(i)
    if i > #required then
      cb(values)
      return
    end
    local arg = required[i]
    local label = arg.name .. (arg.description and " (" .. arg.description .. ")" or "") .. ": "
    vim.ui.input({ prompt = label }, function(val)
      if val == nil then return end
      values[arg.name] = val
      ask(i + 1)
    end)
  end
  ask(1)
end

local function do_expand(item, hub_url, ins)
  if item.kind == "tool" then
    ins(item.description)
  elseif item.kind == "prompt" then
    collect_args(item.arguments, function(values)
      local msgs, err = require("mcp-picker.hub").fetch_prompt_content(hub_url, item.server, item.cap_name, values)
      if err then
        vim.notify("mcp-picker: expand error: " .. err, vim.log.levels.ERROR)
        return
      end
      local parts = {}
      for _, msg in ipairs(msgs) do
        local content = msg.content or {}
        if content.text then
          parts[#parts + 1] = "**" .. (msg.role or "?") .. ":** " .. content.text
        end
      end
      if #parts == 0 then
        vim.notify("mcp-picker: expand returned no messages", vim.log.levels.WARN)
        return
      end
      ins(table.concat(parts, "\n\n"))
    end)
  elseif item.kind == "resourceTemplate" then
    ins(item.uri_template)
  end
end

-- opts: { bufnr?, row?, col?, target_win? }
function M.open(opts, config)
  local hub_url = config.hub_url
  local categories = config.categories

  local items, err, disconnected = require("mcp-picker.hub").fetch_items(hub_url, categories)
  if err then
    vim.notify("mcp-picker: hub error: " .. err, vim.log.levels.ERROR)
    return
  end
  for _, name in ipairs(disconnected or {}) do
    vim.notify("mcp-picker: " .. name .. " is disconnected", vim.log.levels.WARN)
  end
  if #items == 0 then
    vim.notify("mcp-picker: no items (all servers disconnected?)", vim.log.levels.WARN)
    return
  end

  local target_win = opts.target_win or vim.api.nvim_get_current_win()
  local ins = function(text) insert_at(text, opts.bufnr, opts.row, opts.col) end

  local function restore_and(fn)
    return function(picker, item)
      picker:close()
      if vim.api.nvim_win_is_valid(target_win) then
        vim.api.nvim_set_current_win(target_win)
      end
      if item then fn(item) end
    end
  end

  Snacks.picker.pick({
    title = "MCP Capabilities",
    items = items,
    format = "text",
    preview = "preview",
    actions = {
      mcp_expand = restore_and(function(item) do_expand(item, hub_url, ins) end),
    },
    win = {
      input = {
        keys = { ["<C-e>"] = { "mcp_expand", mode = { "i", "n" } } },
      },
      list = {
        keys = { ["<C-e>"] = "mcp_expand" },
      },
    },
    confirm = restore_and(function(item) ins(make_reference(item)) end),
  })
end

return M
