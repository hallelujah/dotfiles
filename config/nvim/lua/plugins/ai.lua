return {
  {
    "olimorris/codecompanion.nvim",
    version = "^19.12.0",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    opts = function()
      local opts = {
        -- ... [existing display, send_code, etc configuration] ...
        display = { chat = { show_history = true } },
        send_code = true,
        use_default_actions = true,
        use_default_prompts = true,
        prompt_library_dir = vim.fn.expand("~/.claude/prompts"),

        adapters = {
          acp = {
            claude_code = function()
              local mise_path = vim.fn.expand("~/.local/share/mise/shims/" .. "claude-agent-acp")
              return require("codecompanion.adapters").extend("claude_code", {
                commands = {
                  default = { mise_path },
                  yolo = { mise_path, "--yolo" },
                },
                defaults = {
                  mcpServers = {
                    {
                      name = "mcphub",
                      command = "npx",
                      args = { "-y", "mcp-remote", "http://localhost:37373/mcp" },
                      env = {},
                    },
                  },
                },
                env = {
                  CLAUDE_CODE_OAUTH_TOKEN = function()
                    local path = vim.fn.expand("~/.claude/.credentials.json")
                    local file = io.open(path, "r")
                    if not file then return nil end
                    local content = file:read("*a")
                    file:close()
                    local ok, data = pcall(vim.json.decode, content)
                    if ok and data.claudeAiOauth and data.claudeAiOauth.accessToken then
                      return data.claudeAiOauth.accessToken
                    end
                    return nil
                  end,
                },
              })
            end,
            gemini_cli = function()
              local mise_path = vim.fn.expand("~/.local/share/mise/shims/gemini")
              return require("codecompanion.adapters").extend("gemini_cli", {
                commands = {
                  default = { mise_path, "--acp" },
                  yolo = { mise_path, "--yolo", "--acp" },
                },
              })
            end,
          },
        },
        interactions = {
          chat = {
            adapter = "claude_code",
            slash_commands = {
              ["mcp"] = {
                description = "Pick an MCP capability from the hub",
                callback = function(chat) require("mcp-picker").open_for_chat(chat) end,
              },
            },
          },
          inline = { adapter = "claude_code" },
          cli = {
            agent = "claude_code",
            agents = {
              claude_code = { cmd = "claude", args = {}, description = "Claude Code CLI", provider = "terminal" },
              gemini_cli = { cmd = "gemini", args = {}, description = "Gemini CLI", provider = "terminal" },
            },
          },
        },
        opts = { log_level = "DEBUG" },
      }
      return opts
    end,
    keys = {
      { "<leader>ac", "<cmd>CodeCompanionChat Toggle<cr>", mode = { "n", "v" }, desc = "AI Chat" },
      { "<leader>ag", "<cmd>CodeCompanionActions<cr>", mode = { "n", "v" }, desc = "AI Actions" },
      { "<leader>ai", "<cmd>CodeCompanion<cr>", mode = "n", desc = "AI Inline Assistant" },
      { "<leader>at", "<cmd>CodeCompanionCLI<cr>", mode = "n", desc = "AI CLI Assistant" },
      {
        "<leader>aG",
        "<cmd>CodeCompanionChat Toggle adapter=gemini_cli<cr>",
        mode = { "n", "v" },
        desc = "AI Chat (Gemini)",
      },
    },
  },
}
