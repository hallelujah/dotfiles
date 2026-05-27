local function is_markdown_path(path)
  return path and path:match("%.[Mm][Dd]$") ~= nil
end

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

  {
    "iamcco/markdown-preview.nvim",
    keys = {
      {
        "<leader>md",
        ft = "markdown",
        "<cmd>MarkdownPreviewToggle<cr>",
        desc = "Markdown Preview",
      },
    },
  },

  {
    "folke/snacks.nvim",
    opts = function(_, opts)
      opts.picker = opts.picker or {}
      opts.picker.sources = opts.picker.sources or {}
      opts.picker.sources.explorer = vim.tbl_deep_extend("force", opts.picker.sources.explorer or {}, {
        win = {
          list = {
            keys = {
              ["<leader>md"] = "markdown_preview",
            },
          },
        },
        actions = {
          markdown_preview = function(picker, item)
            if not item then
              return
            end
            local path = item.file or item.path or item._path
            if not is_markdown_path(path) then
              vim.notify("Not a markdown file: " .. tostring(path), vim.log.levels.WARN)
              return
            end
            picker:close()
            vim.cmd("edit " .. vim.fn.fnameescape(path))
            vim.cmd("MarkdownPreviewToggle")
          end,
        },
      })
    end,
  },
}
