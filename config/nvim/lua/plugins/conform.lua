return {
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        -- * matches all filetypes
        ["*"] = { "trim_whitespace" },
      },
    },
  },
}
