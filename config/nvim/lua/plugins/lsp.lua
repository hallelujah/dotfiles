return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        ["*"] = {
          capabilities = {
            general = {
              positionEncodings = { "utf-8", "utf-16" },
            },
          },
        },
        taplo = {
          root_dir = require("lspconfig.util").root_pattern("*.toml", ".git", "Cargo.toml"),
        },
        ruby_lsp = {
          mason = false,
          cmd = { vim.fn.expand("~/.local/share/mise/shims/ruby-lsp") },
        },
        rubocop = {
          mason = false,
          cmd = { vim.fn.expand("~/.local/share/mise/shims/rubocop"), "--lsp" },
        },
      },
    },
  },
}
