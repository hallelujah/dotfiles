-- Automatically wrap at 72 characters and spell check commit messages
vim.opt_local.textwidth = 72
vim.opt_local.spell = true

vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
  pattern = "PULLREQ_EDITMSG",
  callback = function()
    vim.bo.syntax = "gitcommit"
  end,
})
