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
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  group = augroup("filetypes"),
  pattern = { "*.md" },
  command = "set filetype=markdown",
})

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  group = augroup("filetypes_json"),
  pattern = { ".jscsrc", ".jshintrc", ".eslintrc" },
  command = "set filetype=json",
})

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  group = augroup("filetypes_sh"),
  pattern = {
    "aliases.local",
    "zshenv.local",
    "zlogin.local",
    "zlogout.local",
    "zshrc.local",
    "zprofile.local",
    "*/zsh/configs/*",
  },
  command = "set filetype=sh",
})

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  group = augroup("filetypes_gitconfig"),
  pattern = { "gitconfig.local" },
  command = "set filetype=gitconfig",
})

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  group = augroup("filetypes_tmux"),
  pattern = { "tmux.conf.local" },
  command = "set filetype=tmux",
})

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  group = augroup("filetypes_vim"),
  pattern = { "init.vim.local", "plugins.vim.local" },
  command = "set filetype=vim",
})
