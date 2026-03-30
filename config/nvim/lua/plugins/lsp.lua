local function cmd_path(cmd)
  local is_nixos = vim.fn.filereadable("/etc/NIXOS") == 1
    or (
      vim.fn.filereadable("/etc/os-release") == 1
      and vim.fn.match(vim.fn.readfile("/etc/os-release"), "ID=nixos") >= 0
    )
  if is_nixos then
    return cmd
  else
    return vim.fn.expand("~/.local/share/mise/shims/" .. cmd)
  end
end

local capabilities = {
  offsetEncoding = { "utf-16" },
  positionEncodings = { "utf-16" },
}

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        ["*"] = {
          capabilities = capabilities,
        },
        taplo = {
          root_dir = require("lspconfig.util").root_pattern("*.toml", ".git", "Cargo.toml"),
        },
        ruby_lsp = {
          mason = false,
          cmd = { cmd_path("ruby-lsp") },
        },
        rubocop = {
          mason = false,
          cmd = { cmd_path("rubocop"), "--lsp" },
        },
      },
    },
  },
}
