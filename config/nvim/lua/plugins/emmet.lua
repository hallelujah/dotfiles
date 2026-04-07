return {
  {
    "olrtg/nvim-emmet",
    config = function()
      vim.keymap.set({ "n", "v" }, "<leader>me", require("nvim-emmet").wrap_with_abbreviation)
    end,
  },
}
