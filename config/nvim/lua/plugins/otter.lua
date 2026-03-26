-- return {
--   {
--     "jmbuhr/otter.nvim",
--     dependencies = {
--       "nvim-treesitter/nvim-treesitter",
--     },
--     config = function()
--       vim.api.nvim_create_autocmd({ "FileType" }, {
--         pattern = { "toml" },
--         group = vim.api.nvim_create_augroup("EmbedToml", { clear = true }),
--         callback = function()
--           require("otter").activate()
--         end,
--       })
--     end,
--   },
-- }
return {
  {
    "jmbuhr/otter.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {
      -- Specify which languages you want otter to handle
      buffers = {
        set_filetype = true,
      },
    },
    config = function(_, opts)
      local otter = require("otter")
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "toml",
        callback = function()
          -- Only activate if the file looks like a mise config
          local file_name = vim.fn.expand("%:t")
          if file_name:match("mise.*%.toml") or file_name:match("config%.toml") then
            -- provide completion for the languages you use in 'run' scripts
            otter.activate()
          end
        end,
      })
    end,
  },
}
