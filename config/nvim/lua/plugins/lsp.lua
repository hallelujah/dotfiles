local function cmd_path(cmd, ...)
  return { vim.fn.expand("~/.local/share/mise/shims/" .. cmd), ... }
  -- if vim.fn.filereadable("Gemfile") == 1 then
  --   return { "bundle", "exec", cmd, ... }
  -- end
  -- local is_nixos = vim.fn.filereadable("/etc/NIXOS") == 1
  --   or (
  --     vim.fn.filereadable("/etc/os-release") == 1
  --     and vim.fn.match(vim.fn.readfile("/etc/os-release"), "ID=nixos") >= 0
  --   )
  -- if is_nixos then
  --   return { cmd, ... }
  -- else
  --   return { vim.fn.expand("~/.local/share/mise/shims/" .. cmd), ... }
  -- end
end

local capabilities = {
  offsetEncoding = { "utf-16" },
  positionEncodings = { "utf-16" },
}

-- Helper to check if the command is available
local function has_gem_or_cmd(cmd)
  -- 1. Check if it's in the Gemfile.lock (for "bundle exec" projects)
  if vim.fn.filereadable("Gemfile.lock") == 1 then
    local lockfile_content = table.concat(vim.fn.readfile("Gemfile.lock"), "\n")
    -- Look for the gem name in the specs section
    if lockfile_content:find("%s" .. cmd .. "%s") then
      return true
    end
  end

  -- 2. Fallback: Check if it's executable via mise or system path
  local path = cmd_path(cmd)
  return vim.fn.executable(path[1]) == 1 or vim.fn.executable(cmd) == 1
end

-- Logic to determine which server to use
local ruby_server = "ruby_lsp"
local ruby_server_cmd = cmd_path("ruby-lsp")

if has_gem_or_cmd("solargraph") and vim.g.lazyvim_ruby_lsp and vim.g.lazyvim_ruby_lsp == "solargraph" then
  ruby_server = "solargraph"
  ruby_server_cmd = cmd_path("solargraph", "stdio")
end
vim.notify("ruby lsp server: " .. ruby_server, vim.log.levels.INFO)

return {
  {
    "neovim/nvim-lspconfig",
    init = function()
      -- This tells LazyVim's Ruby extra which server to use globally
      vim.g.lazyvim_ruby_lsp = ruby_server
      vim.g.lazyvim_ruby_formatter = "rubocop"
    end,
    opts = {
      servers = {
        ["*"] = {
          capabilities = capabilities,
        },
        taplo = {
          root_dir = require("lspconfig.util").root_pattern("*.toml", ".git", "Cargo.toml"),
        },
        [ruby_server] = {
          mason = false,
          cmd = ruby_server_cmd,
          enabled = true,
        },
        [ruby_server == "solargraph" and "ruby_lsp" or "solargraph"] = { enabled = false },

        rubocop = {
          mason = false,
          cmd = cmd_path("rubocop", "--lsp"),
        },
      },
    },
  },
}
