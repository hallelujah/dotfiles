local function cmd_path(cmd, ...)
  -- return { vim.fn.expand("~/.local/share/mise/shims/" .. cmd), ... }
  if vim.fn.filereadable("Gemfile") == 1 then
    return { "bundle", "exec", cmd, ... }
  end
  local is_nixos = vim.fn.filereadable("/etc/NIXOS") == 1
    or (
      vim.fn.filereadable("/etc/os-release") == 1
      and vim.fn.match(vim.fn.readfile("/etc/os-release"), "ID=nixos") >= 0
    )
  if is_nixos then
    return { cmd, ... }
  else
    return { vim.fn.expand("~/.local/share/mise/shims/" .. cmd), ... }
  end
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

local function debounce_ruby_symbols_on_init(client)
  local log = require("vim.lsp.log")

  log.info("--- Ruby LSP: Debounce patch active ---")

  local original_request = client.request
  local timer = vim.uv.new_timer()

  client.request = function(self, param1, ...)
    local args = { ... }

    -- 1. Log EVERYTHING at the start using debug level
    log.debug("INCOMING REQUEST:")
    log.debug("Param1: " .. vim.inspect(param1))
    if #args > 0 then
      log.debug("Other args: " .. vim.inspect(args))
    end

    -- 2. Safely extract the method and query
    local method_name, query
    if type(param1) == "table" then
      method_name = param1.method
      query = param1.params and param1.params.query or ""
    else
      method_name = param1
      local params = args[1]
      query = params and type(params) == "table" and params.query or ""
    end

    -- 3. Apply the debounce logic ONLY if it's a workspace symbol request
    if method_name == "workspace/symbol" then
      log.info("INTERCEPTED: typing... (query: '" .. query .. "')")

      timer:stop()
      timer:start(
        300,
        0,
        vim.schedule_wrap(function()
          log.info("DISPATCHED:  Sending request! (query: '" .. query .. "')")
          original_request(self, param1, unpack(args))
        end)
      )

      return true, -1
    end

    -- 4. Pass all other requests through instantly
    return original_request(self, param1, unpack(args))
  end
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
          on_init = debounce_ruby_symbols_on_init,
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
