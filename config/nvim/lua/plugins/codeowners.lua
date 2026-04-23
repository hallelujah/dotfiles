return {

  {
    "comatory/gh-co.nvim",
    config = function()
      -- Keymap to show the codeowner for the current file
      vim.keymap.set("n", "<leader>go", ":GhCoWho<CR>", { desc = "Show CODEOWNER" })
    end,
  },
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      -- Custom component to get the owners
      local function get_codeowners()
        -- Only run if gh-co is loaded and has data for the file
        local status, ghco = pcall(require, "gh-co")
        if not status then
          return ""
        end

        -- Fetch owners (this varies slightly by plugin API)
        -- gh-co provides owner data which we can format
        local owners = ghco.get_owners(vim.api.nvim_get_current_buf())
        if not owners or #owners == 0 then
          return ""
        end
        return "👤 " .. table.concat(owners, ", ")
      end

      -- Insert into lualine_c (middle section) or lualine_x (right side)
      table.insert(opts.sections.lualine_c, {
        get_codeowners,
        cond = function()
          -- Only show if the plugin is available
          return package.loaded["gh-co"] ~= nil
        end,
        color = { fg = "#ff9e64" }, -- Optional: set a specific color
      })
    end,
  },
}
