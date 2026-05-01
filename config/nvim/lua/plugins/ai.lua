return {
  -- Configure mcphub before codecompanion
  {
    "ravitemer/mcphub.nvim",
    dependencies = {
      { "nvim-lua/plenary.nvim", branch = "master" },
    },
    config = function()
      require("mcphub").setup({
        servers_path = vim.fn.expand("~/.config/mcphub/servers.json"),
      })
    end,
  },
  -- Claude via codecompanion.nvim
  {
    "olimorris/codecompanion.nvim",
    version = "^19.12.0",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "ravitemer/mcphub.nvim",
      { "stevearc/sqlite.lua" },
    },
    opts = function()
      local mcp_config = vim.fn.expand("~/.claude/.mcp.json")

      local opts = {
        display = {
          chat = {
            show_history = true,
          },
        },
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
                  default = {
                    mise_path,
                    "--mcp-config",
                    mcp_config,
                  },
                  yolo = {
                    mise_path,
                    "--yolo",
                    "--mcp-config",
                    mcp_config,
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
        -- List of providers
        interactions = {
          chat = {
            adapter = "claude_code",
          },
          inline = {
            adapter = "claude_code",
          },
          cli = {
            agent = "claude_code",
            agents = {
              claude_code = {
                cmd = "claude",
                args = {},
                description = "Claude Code CLI",
                provider = "terminal",
              },
              gemini_cli = {
                cmd = "gemini",
                args = {},
                description = "Gemini CLI",
                provider = "terminal",
              },
            },
          },
        },
        extensions = {
          mcphub = {
            callback = "mcphub.extensions.codecompanion",
            opts = {
              -- Tools disabled for ACP adapters: codecompanion filters tools out when adapter.type=="acp"
              -- (codecompanion.nvim/lua/codecompanion/providers/completion/init.lua:206-215).
              -- Instead, configure agents (claude-agent-acp, gemini) to connect to mcp-hub endpoint:
              --   claude mcp add --transport http mcphub http://localhost:37373/mcp --scope user
              --   gemini mcp add --transport http mcphub http://localhost:37373/mcp --scope user
              make_tools = false,
              show_server_tools_in_chat = false,
              add_mcp_prefix_to_tool_names = false,
              show_result_in_chat = false,
              format_tool = nil,
              -- Prompts and resources work over ACP (client-side text expansion)
              make_vars = true, -- Convert MCP resources to #variables for prompts
              make_slash_commands = true, -- Add MCP prompts as /slash commands
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
      {
        "<leader>aG",
        "<cmd>CodeCompanionChat Toggle adapter=gemini_cli<cr>",
        mode = { "n", "v" },
        desc = "AI Chat (Gemini)",
      },
    },
  },
}
