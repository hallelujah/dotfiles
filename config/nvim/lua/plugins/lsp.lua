return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        taplo = {
          root_dir = require("lspconfig.util").root_pattern("*.toml", ".git", "Cargo.toml"),
        },
      },
    },
  },
}
