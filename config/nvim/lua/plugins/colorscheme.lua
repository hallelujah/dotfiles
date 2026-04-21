return {
  { "rktjmp/lush.nvim" },
  { "alexwu/nvim-snazzy" },
  {
    "navarasu/onedark.nvim",
    priority = 996,
    config = function()
      require("onedark").setup({
        style = "deep",
        toggle_style_key = "<leader>ts", -- toggle style
      })
      -- require("onedark").load()
    end,
  },
  {
    "rebelot/kanagawa.nvim",
  },
  {
    "thesimonho/kanagawa-paper.nvim",
  },
  {
    "embark-theme/vim",
    priority = 997,
    name = "embark",
  },
  {
    "rmehri01/onenord.nvim",
    priority = 998,
  },
  {
    "sainnhe/gruvbox-material",
    priority = 999,
  },
  {
    "sainnhe/everforest",
    priority = 1000,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "kanagawa",
    },
  },
}
