return {
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      -- Add your required tools to the ensure_installed list
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, {
        "copilot-language-server",
        "prettier",
        "markdownlint-cli2",
        "markdown-toc",
        -- "fish" is usually a system package, but Mason can handle the LSP
        "fish-lsp",
        "erb-formatter",
      })
    end,
  },
}
