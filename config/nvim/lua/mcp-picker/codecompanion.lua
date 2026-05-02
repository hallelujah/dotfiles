local M = {}

function M.open_for_chat(chat, config)
  local win = vim.api.nvim_get_current_win()
  local row, col = unpack(vim.api.nvim_win_get_cursor(win))
  require("mcp-picker.picker").open({
    bufnr = chat.bufnr,
    row = row,
    col = col,
    target_win = win,
  }, config)
end

return M
