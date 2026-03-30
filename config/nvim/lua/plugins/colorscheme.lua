return {
  { "rktjmp/lush.nvim" },
  { "alexwu/nvim-snazzy" },
  {
    "navarasu/onedark.nvim",
    priority = 1000, -- make sure to load this before all the other start plugins
    config = function()
      require("onedark").setup({
        style = "deep",
        toggle_style_key = "<leader>ts", -- toggle style
      })
      require("onedark").load()
    end,
  },
  {
    "embark-theme/vim",
    lazy = false,
    priority = 1000,
    name = "embark",
  },
}
