return {
  {
    "hedyhli/markdown-toc.nvim",
    ft = "markdown", -- Lazy load on markdown filetype
    cmd = { "Mtoc" }, -- Or, lazy load on "Mtoc" command
    opts = {
      -- Enable auto-update to refresh the TOC on every save
      auto_update = {
        enabled = true,
        events = { "BufWritePre" },
        pattern = "*.{md,mdown,mkd,mkdn,markdown,mdwn}",
      },
    },
  },
}
