return {
  {
    dir = vim.fn.stdpath("config"),
    name = "semble",
    lazy = false,
    keys = {
      { "<leader>hs", function() require("semble").search() end, desc = "Semble search" },
      { "<leader>hr", function() require("semble").related() end, desc = "Semble find-related" },
    },
    config = function()
      require("semble").setup()
    end,
  },
}
