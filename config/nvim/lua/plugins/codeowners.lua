local owners_cache = {}

local function get_codeowners()
  local bufnr = vim.api.nvim_get_current_buf()
  if owners_cache[bufnr] then
    return owners_cache[bufnr]
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr)
  if filepath == "" then
    return ""
  end

  local ok, CO = pcall(require, "gh-co.co")
  if not ok then
    return ""
  end

  local owners = CO.matchFilesToCodeowner({ filepath })
  if not owners then
    owners_cache[bufnr] = ""
    return ""
  end
  local filtered = vim.tbl_filter(function(o)
    return o ~= ""
  end, owners)
  local result = #filtered > 0 and ("󰀎 " .. table.concat(filtered, ", ")) or ""
  owners_cache[bufnr] = result
  return result
end

vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
  callback = function(ev)
    owners_cache[ev.buf] = nil
  end,
})

return {
  {
    "comatory/gh-co.nvim",
    config = function()
      vim.keymap.set("n", "<leader>go", ":GhCoWho<CR>", { desc = "Show CODEOWNER" })
    end,
  },
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      table.insert(opts.sections.lualine_x, {
        get_codeowners,
        cond = function()
          return package.loaded["gh-co.co"] ~= nil and get_codeowners() ~= ""
        end,
        color = { fg = "#ff9e64" },
      })
    end,
  },
}
