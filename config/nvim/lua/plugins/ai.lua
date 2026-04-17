return {
  -- CopilotChat.nvim (optional, for chat interface)
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    build = "make tiktoken",
    dependencies = {
      { "nvim-lua/plenary.nvim", branch = "master" },
    },
  },
  -- Claude via codecompanion.nvim
  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    opts = function()
      local opts = {
        send_code = true,
        use_default_actions = true,
        use_default_prompts = true,

        adapters = {
          acp = {
            anthropic = function()
              local mise_path = vim.fn.expand("~/.local/share/mise/shims/" .. "claude-agent-acp")

              return require("codecompanion.adapters").extend("claude_code", {
                commands = {
                  default = {
                    mise_path,
                  },
                  yolo = {
                    mise_path,
                    "--yolo",
                  },
                },
                env = {
                  CLAUDE_CODE_OAUTH_TOKEN = function()
                    local path = vim.fn.expand("~/.claude/.credentials.json")
                    local file = io.open(path, "r")
                    if not file then
                      return nil
                    end

                    local content = file:read("*a")
                    file:close()

                    local ok, data = pcall(vim.json.decode, content)
                    -- Accessing the nested 'claudeAiOauth' table you mentioned
                    if ok and data.claudeAiOauth and data.claudeAiOauth.accessToken then
                      return data.claudeAiOauth.accessToken
                    end
                    return nil
                  end,
                },
              })
            end,
          },
        },
        -- List of providers
        providers = {},
        interactions = {
          chat = { adapter = "anthropic" },
          inline = { adapter = "anthropic" },
          cli = {
            agent = "claude_code",
            agents = {
              claude_code = {
                cmd = "claude",
                args = {},
                description = "Claude Code CLI",
                provider = "terminal",
              },
            },
          },
        },
        opts = {
          log_level = "DEBUG", -- or "TRACE"
        },
      }
      return opts
    end,
    keys = {
      { "<leader>ac", "<cmd>CodeCompanionChat Toggle<cr>", mode = { "n", "v" }, desc = "AI Chat" },
      { "<leader>ag", "<cmd>CodeCompanionActions<cr>", mode = { "n", "v" }, desc = "AI Actions" },
      { "<leader>ai", "<cmd>CodeCompanion<cr>", mode = "n", desc = "AI Inline Assistant" },
      { "<leader>at", "<cmd>CodeCompanionCLI<cr>", mode = "n", desc = "AI CLI Assistant" },
    },
  },
}
