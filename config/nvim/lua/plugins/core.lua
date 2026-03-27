-- Use Snazzy as our default color scheme
return {
  {
    "LazyVim/LazyVim",
  },

  -- start ruby lsp server right away
  { "neovim/nvim-lspconfig", opts = { servers = { ruby_lsp = {} } } },
}
