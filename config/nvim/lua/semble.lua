-- semble.lua — minimal Neovim integration for semble (code search).
--
-- Provides:
--   :Semble <query>           Search current git root (or cwd) and populate
--                             the quickfix list.
--   :SembleRelated            Run `semble find-related` against the file/line
--                             under the cursor.
--
-- Output is parsed loosely: any "<path>:<line>" token in the CLI output
-- becomes a quickfix entry. Raw output is also dumped into a scratch buffer
-- for inspection.

local M = {}

local function semble_bin()
  if vim.fn.executable("semble") == 1 then
    return "semble"
  end
  -- `uv tool install` drops binaries here; nvim launched from GUIs / WSL
  -- often lacks ~/.local/bin on PATH.
  local fallback = vim.env.HOME .. "/.local/bin/semble"
  if vim.fn.executable(fallback) == 1 then
    return fallback
  end
  return nil
end

local function project_root()
  local out = vim.fn.systemlist({ "git", "rev-parse", "--show-toplevel" })
  if vim.v.shell_error == 0 and out[1] and out[1] ~= "" then
    return out[1]
  end
  return vim.loop.cwd()
end

local function open_scratch(lines, name)
  vim.cmd("botright new")
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.api.nvim_buf_set_name(buf, name)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

local function parse_qf(lines, root)
  local items = {}
  -- Match "<path>:<line>" where path may be absolute or relative.
  local pattern = "([%w%./_%-+]+%.[%w]+):(%d+)"
  for _, line in ipairs(lines) do
    for path, lnum in line:gmatch(pattern) do
      local full = path
      if not vim.startswith(path, "/") then
        full = root .. "/" .. path
      end
      if vim.fn.filereadable(full) == 1 then
        table.insert(items, {
          filename = full,
          lnum = tonumber(lnum),
          text = line,
        })
      end
    end
  end
  return items
end

local function run(args, title)
  local bin = semble_bin()
  if not bin then
    vim.notify(
      "semble: binary not found. Install with `uv tool install 'semble[mcp]'` or run rcup.",
      vim.log.levels.ERROR
    )
    return
  end
  local root = project_root()
  vim.notify("semble: " .. title .. " in " .. root, vim.log.levels.INFO)
  local result = vim.system({ bin, unpack(args) }, { text = true }):wait()
  local out = (result.stdout or "") .. (result.stderr or "")
  local lines = vim.split(out, "\n", { plain = true, trimempty = false })
  open_scratch(lines, "semble://" .. title)
  local items = parse_qf(lines, root)
  if #items > 0 then
    vim.fn.setqflist({}, " ", { title = "semble: " .. title, items = items })
    vim.cmd("copen")
  else
    vim.notify("semble: no file:line refs parsed; see scratch buffer", vim.log.levels.WARN)
  end
end

function M.search(query, top_k)
  if not query or query == "" then
    query = vim.fn.input("semble search: ")
    if query == "" then return end
  end
  run({ "search", query, project_root(), "--top-k", tostring(top_k or 10) }, query)
end

function M.related(top_k)
  local file = vim.fn.expand("%:p")
  local line = vim.fn.line(".")
  if file == "" then
    vim.notify("semble: no file under cursor", vim.log.levels.ERROR)
    return
  end
  run(
    { "find-related", file, tostring(line), project_root(), "--top-k", tostring(top_k or 10) },
    "related " .. vim.fn.fnamemodify(file, ":t") .. ":" .. line
  )
end

function M.setup()
  vim.api.nvim_create_user_command("Semble", function(opts)
    M.search(opts.args, tonumber(opts.fargs[2]))
  end, { nargs = "*", desc = "semble search <query>" })

  vim.api.nvim_create_user_command("SembleRelated", function()
    M.related()
  end, { desc = "semble find-related at cursor" })
end

return M
