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

-- Switch between the last two files
map("n", "<Leader><Leader>", "<C-^>", { noremap = true })

-- Quicker window movement
map("n", "<C-j>", "<C-w>j", { noremap = true })
map("n", "<C-k>", "<C-w>k", { noremap = true })
map("n", "<C-h>", "<C-w>h", { noremap = true })
map("n", "<C-l>", "<C-w>l", { noremap = true })

-- Move between linting errors (ALE)
map("n", "]r", ":ALENextWrap<CR>", { noremap = true })
map("n", "[r", ":ALEPreviousWrap<CR>", { noremap = true })

-- Load an existing chat (opens your fuzzy finder)
map("n", "<leader>al", "<cmd>CopilotChatLoad<cr>", { desc = "Copilot Chat - Load History" })

-- Save the current chat (leaves you in the command line to type a name)
map("n", "<leader>as", ":CopilotChatSave ", { desc = "Copilot Chat - Save History" })

-- Quick save (saves automatically with a timestamp without prompting for a name)
map("n", "<leader>aS", "<cmd>CopilotChatSave<cr>", { desc = "Copilot Chat - Quick Save" })
