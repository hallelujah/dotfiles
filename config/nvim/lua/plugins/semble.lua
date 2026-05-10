return {
  {
    dir = vim.fn.stdpath("config"),
    name = "semble",
    lazy = false,
    keys = {
      { "<leader>ss", function() require("semble").search() end, desc = "Semble search" },
      { "<leader>sr", function() require("semble").related() end, desc = "Semble find-related" },
    },
    config = function()
      require("semble").setup()
    end,
  },
}
