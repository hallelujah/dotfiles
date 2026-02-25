local map = vim.keymap.set

-- Tab completion wrapper (preserving the logic from init.vim)
_G.InsertTabWrapper = function()
  local col = vim.fn.col(".") - 1
  if col == 0 or vim.fn.getline("."):sub(col, col):match("%s") then
    return vim.api.nvim_replace_termcodes("<Tab>", true, true, true)
  else
    return vim.api.nvim_replace_termcodes("<C-p>", true, true, true)
  end
end
map("i", "<Tab>", "v:lua.InsertTabWrapper()", { expr = true, noremap = true })
map("i", "<S-Tab>", "<C-n>", { noremap = true })

-- Switch between the last two files
map("n", "<Leader><Leader>", "<C-^>", { noremap = true })

-- vim-test mappings
map("n", "<Leader>t", ":TestFile<CR>", { silent = true })
map("n", "<Leader>s", ":TestNearest<CR>", { silent = true })
map("n", "<Leader>l", ":TestLast<CR>", { silent = true })
map("n", "<Leader>a", ":TestSuite<CR>", { silent = true })
map("n", "<Leader>gt", ":TestVisit<CR>", { silent = true })

-- Run commands that require an interactive shell
map("n", "<Leader>r", ":RunInInteractiveShell ", { noremap = true })

-- Quicker window movement
map("n", "<C-j>", "<C-w>j", { noremap = true })
map("n", "<C-k>", "<C-w>k", { noremap = true })
map("n", "<C-h>", "<C-w>h", { noremap = true })
map("n", "<C-l>", "<C-w>l", { noremap = true })

-- Move between linting errors (ALE)
map("n", "]r", ":ALENextWrap<CR>", { noremap = true })
map("n", "[r", ":ALEPreviousWrap<CR>", { noremap = true })

-- Map Ctrl + p to open fuzzy find (Files)
-- Note: LazyVim has its own picker, but keeping this for familiarity
map("n", "<C-p>", ":Files<CR>", { noremap = true })

-- Custom Rg mapping
if vim.fn.executable("rg") == 1 then
  map("n", "\\", ":Rg ", { noremap = true })
end
