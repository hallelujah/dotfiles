local M = {}

local _config = {
  hub_url = "http://localhost:37373",
  categories = { "tools", "prompts", "resourceTemplates" },
  picker_backend = "snacks",
}

function M.setup(opts)
  _config = vim.tbl_deep_extend("force", _config, opts or {})
end

function M.open(opts)
  require("mcp-picker.picker").open(opts or {}, _config)
end

function M.open_for_chat(chat)
  require("mcp-picker.codecompanion").open_for_chat(chat, _config)
end

vim.api.nvim_create_user_command("McpPicker", function(args)
  if args.args == "health" then
    require("mcp-picker.hub").health(_config.hub_url)
  else
    M.open()
  end
end, { nargs = "?" })

return M
