-- Set options
vim.g.mapleader = " "

local opt = vim.opt

opt.backspace = { "indent", "eol", "start" }
opt.backup = false
opt.writebackup = false
opt.swapfile = false
opt.history = 50
opt.ruler = true
opt.showcmd = true
opt.termguicolors = true
opt.incsearch = true
opt.laststatus = 2
opt.autowrite = true
opt.modeline = false

opt.tabstop = 2
opt.shiftwidth = 2
opt.shiftround = true
opt.expandtab = true
opt.softtabstop = 2

opt.list = true
opt.listchars = { tab = "»·", trail = "·", nbsp = "·" }
-- Use a subtle dot instead of the heavy '-' or '_' bars
-- vim.opt.fillchars:append({ diff = "·" })

opt.joinspaces = false

opt.textwidth = 80
opt.colorcolumn = "+1"

opt.number = true
opt.numberwidth = 5

opt.wildmode = { "list:longest", "list:full" }
opt.wildoptions = "pum"

opt.splitbelow = true
opt.splitright = true

opt.spellfile = vim.fn.expand("$HOME/.vim-spell-en.utf-8.add")
opt.complete:append("kspell")

opt.diffopt:append("vertical")

-- Global variables
vim.g.is_posix = 1
vim.g.html_indent_tags = "li\\|p"

-- ripgrep
if vim.fn.executable("rg") == 1 then
  opt.grepprg = "rg --vimgrep --no-heading --smart-case"
  vim.env.FZF_DEFAULT_COMMAND = 'rg --files --hidden --follow --glob "!.git/*"'
end

-- New Lua local config
local init_lua_local = vim.fn.expand("~/.config/nvim/init.local.lua")
if vim.fn.filereadable(init_lua_local) == 1 then
  dofile(init_lua_local)
end
