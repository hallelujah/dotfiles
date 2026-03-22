local function augroup(name)
  return vim.api.nvim_create_augroup("nvimrc_" .. name, { clear = true })
end

-- Jump to last known cursor position
vim.api.nvim_create_autocmd("BufReadPost", {
  group = augroup("last_loc"),
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Set filetype for specific patterns
vim.filetype.add({
  extension = {
    md = "markdown",
  },
  filename = {
    [".jscsrc"] = "json",
    [".jshintrc"] = "json",
    [".eslintrc"] = "json",
    ["aliases.local"] = "sh",
    ["zshenv.local"] = "sh",
    ["zlogin.local"] = "sh",
    ["zlogout.local"] = "sh",
    ["zshrc.local"] = "sh",
    ["zprofile.local"] = "sh",
    ["gitconfig.local"] = "gitconfig",
    ["tmux.conf.local"] = "tmux",
    ["PULLREQ_EDITMSG"] = "gitcommit",
  },
  pattern = {
    [".*/zsh/configs/.*"] = "sh",
    [".*/lua/plugins/.*%.lua"] = "lua",
  },
})

-- Load local ftplugins
vim.api.nvim_create_autocmd("FileType", {
  group = augroup("local_ftplugin"),
  callback = function(event)
    local ft = event.match
    local local_file = vim.fn.expand("~/.config/nvim/after/ftplugin/" .. ft .. ".local.lua")
    if vim.fn.filereadable(local_file) == 1 then
      dofile(local_file)
    end
  end,
})
