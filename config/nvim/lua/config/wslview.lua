-- Use $BROWSER environment variable for opening URLs
vim.ui.open = function(path)
  local browser = os.getenv("BROWSER")
  if browser then
    -- Run asynchronously to prevent WSL timeout errors
    vim.fn.jobstart({ browser, path }, { detach = true })
  else
    -- Fallback to default behavior if BROWSER is not set
    local opener = vim.fn.has("wsl") == 1 and "wslview" or "open"
    vim.fn.jobstart({ opener, path }, { detach = true })
  end
end
