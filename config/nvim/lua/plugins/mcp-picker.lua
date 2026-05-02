return {
  {
    dir = vim.fn.stdpath("config"),
    name = "mcp-picker",
    lazy = false,
    config = function()
      require("mcp-picker")
    end,
  },
}
