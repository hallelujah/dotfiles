return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      sources = {
        lsp_workspace_symbols = {
          -- 1. Force the picker to prioritize results from your project over gems
          matcher = {
            filename_bonus = true,
            frecency = true,
            sort_empty = true,
          },
          -- 2. Use a stricter sort order: Score first, then text similarity
          sort = { fields = { "score:desc", "#text", "idx" } },
          -- 3. Live mode sends your query to Ruby LSP;
          -- Toggle this to 'false' if you want Snacks to fetch everything once and sort locally.
          live = true,
        },
      },
    },
  },
}
