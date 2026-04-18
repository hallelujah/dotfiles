return {
  -- CopilotChat.nvim (optional, for chat interface)
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    build = "make tiktoken",
    dependencies = {
      { "nvim-lua/plenary.nvim", branch = "master" },
    },
  },
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
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "ravitemer/mcphub.nvim",
    },
    opts = function()
      local opts = {
        send_code = true,
        use_default_actions = true,
        use_default_prompts = true,

        adapters = {
          acp = {
            claude_code = function()
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
        interactions = {
          chat = { adapter = "claude_code" },
          inline = { adapter = "claude_code" },
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
        extensions = {
          mcphub = {
            callback = "mcphub.extensions.codecompanion",
            opts = {
              -- MCP Tools
              make_tools = true, -- Make individual tools (@server__tool) and server groups (@server) from MCP servers
              show_server_tools_in_chat = true, -- Show individual tools in chat completion (when make_tools=true)
              add_mcp_prefix_to_tool_names = false, -- Add mcp__ prefix (e.g `@mcp__github`, `@mcp__neovim__list_issues`)
              show_result_in_chat = true, -- Show tool results directly in chat buffer
              format_tool = nil, -- function(tool_name:string, tool: CodeCompanion.Agent.Tool) : string Function to format tool names to show in the chat buffer
              -- MCP Resources
              make_vars = false, -- Convert MCP resources to #variables for prompts
              -- MCP Prompts
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
    },
  },
}
