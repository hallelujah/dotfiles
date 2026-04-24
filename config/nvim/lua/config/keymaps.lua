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

-- DiffView
map("n", "<leader>gv", "<cmd>DiffviewOpen<cr>", { desc = "Open DiffView" })
map("n", "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", { desc = "Open DiffView File History" })
map(
  "n",
  "<leader>gB",
  "<cmd>DiffviewOpen origin/HEAD..HEAD --imply-local<cr>",
  { desc = "DiffView Review Branch changes" }
)

-- Load an existing chat (opens your fuzzy finder)
map("n", "<leader>al", "<cmd>CopilotChatLoad<cr>", { desc = "Copilot Chat - Load History" })

-- Save the current chat (leaves you in the command line to type a name)
map("n", "<leader>as", ":CopilotChatSave ", { desc = "Copilot Chat - Save History" })

-- Quick save (saves automatically with a timestamp without prompting for a name)
map("n", "<leader>aS", "<cmd>CopilotChatSave<cr>", { desc = "Copilot Chat - Quick Save" })

-- Useful when stuck in Terminal on insert mode
-- map("t", "<Esc>", [[<C-\><C-n>]], { desc = "Exit terminal mode" })
-- Define the function
local function copy_ruby_namespace()
  local node = vim.treesitter.get_node()
  local parts = {}

  while node do
    if node:type() == "class" or node:type() == "module" then
      -- The name is typically the first child of type 'constant' or 'scope_resolution'
      for child in node:iter_children() do
        if child:type() == "constant" or child:type() == "scope_resolution" then
          table.insert(parts, 1, vim.treesitter.get_node_text(child, 0))
          break
        end
      end
    end
    node = node:parent()
  end

  local full_namespace = table.concat(parts, "::")
  if full_namespace ~= "" then
    vim.fn.setreg("+", full_namespace) -- Yank to system clipboard
    print("Copied: " .. full_namespace)
  else
    print("No Ruby namespace found under cursor.")
  end
end

-- Set the keymap (Leader + c + r)
vim.keymap.set("n", "<leader>cy", copy_ruby_namespace, { desc = "Copy Ruby Namespace" })

vim.keymap.set("n", "<leader>gY", function()
  Snacks.gitbrowse({
    what = "permalink",
    open = function(url)
      vim.fn.setreg("+", url)
      Snacks.notify.info("Copied commit URL to clipboard: " .. url)
    end,
    return_sha1 = false, -- ensure this is false or omitted to get the URL, not just the SHA1
  })
end, { desc = "Git Browse (Copy Permalink)" })

-- Copy relative path and line number
vim.keymap.set("n", "<leader>cp", function()
  local path = vim.fn.expand("%")
  local line = vim.fn.line(".")
  local result = path .. ":" .. line
  vim.fn.setreg("+", result)
  vim.notify("Copied: " .. result)
end, { desc = "Copy File Path and Line" })

-- Wayfinder
vim.keymap.set("n", "<leader>wf", "<Plug>(WayfinderOpen)", { desc = "Wayfinder" })
