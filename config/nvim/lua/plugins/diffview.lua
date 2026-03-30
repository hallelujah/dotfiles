return {
  "sindrets/diffview.nvim",
  opts = {
    enhanced_diff_hl = true, -- Uses treesitter for better, softer colors
    use_icons = true, -- Requires nvim-web-devicons
    view = {
      default = {
        winbar_info = true, -- Adds a clean info bar at the top
      },
    },
  },
}
