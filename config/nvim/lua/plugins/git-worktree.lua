-- Snacks-native git worktree picker.
-- <leader>gw  list worktrees; <Enter> switches cwd + opens/refreshes the explorer.
-- Lazygit (<leader>gg) still owns create/update; this owns the in-editor switch.
local ICON_MAIN = "󰋜" -- home (primary worktree)
local ICON_TREE = "󰙅" -- file-tree (linked worktrees)

local function worktree_items()
  local raw, cur = {}, {}
  local function flush()
    if cur.path then
      cur.branch = cur.branch or "?"
      cur.name = vim.fn.fnamemodify(cur.path, ":t")
      table.insert(raw, cur)
    end
    cur = {}
  end
  for _, line in ipairs(vim.fn.systemlist("git worktree list --porcelain")) do
    if line:match("^worktree ") then
      flush()
      cur.path = line:sub(10)
    elseif line:match("^branch ") then
      cur.branch = line:gsub("^branch refs/heads/", "")
    elseif line:match("^detached") then
      cur.branch = "(detached)"
    elseif line:match("^bare") then
      cur.branch = "(bare)"
    end
  end
  flush()

  local function norm(path)
    return (vim.fn.fnamemodify(path, ":p"):gsub("/$", ""))
  end
  local current = norm(vim.fn.systemlist("git rev-parse --show-toplevel")[1] or "")

  local width = 0
  for _, wt in ipairs(raw) do
    width = math.max(width, #wt.branch)
  end

  local items = {}
  for idx, wt in ipairs(raw) do
    table.insert(items, {
      text = wt.branch .. " " .. wt.name, -- used by the matcher only
      cwd = wt.path,
      branch = wt.branch,
      name = wt.name,
      pad = width - #wt.branch + 2,
      is_main = idx == 1, -- porcelain lists the primary worktree first
      is_current = norm(wt.path) == current,
    })
  end
  return items
end

local function format_item(item)
  return {
    { item.is_current and "● " or "  ", "DiagnosticOk" },
    { (item.is_main and ICON_MAIN or ICON_TREE) .. "  ", item.is_main and "Directory" or "Special" },
    { item.branch, item.is_current and "Title" or "Identifier" },
    { string.rep(" ", item.pad), "" },
    { item.name, item.is_current and "Title" or "Comment" },
  }
end

local function open_explorer(dir)
  local explorer = Snacks.picker.get({ source = "explorer" })[1]
  if explorer then
    explorer:set_cwd(dir)
    explorer:find()
    explorer:show()
  else
    Snacks.explorer({ cwd = dir })
  end
end

local function pick_worktree()
  Snacks.picker.pick({
    title = "Git Worktrees",
    finder = worktree_items,
    format = format_item,
    layout = { preset = "select" },
    confirm = function(picker, item)
      picker:close()
      if not item then
        return
      end
      vim.cmd.cd(vim.fn.fnameescape(item.cwd))
      Snacks.notify.info("Worktree: " .. item.branch)
      open_explorer(item.cwd)
    end,
  })
end

return {
  "folke/snacks.nvim",
  keys = {
    { "<leader>gw", pick_worktree, desc = "Git Worktrees" },
  },
}
