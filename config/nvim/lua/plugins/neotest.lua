return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      "nvim-treesitter/nvim-treesitter",
      "olimorris/neotest-rspec",
    },
    opts = {

      adapters = {
        ["neotest-rspec"] = {
          engine_support = false,
          rspec_cmd = function()
            return {
              "bundle",
              "exec",
              "rspec",
            }
          end,
        },
      },
      discovery = {
        -- Set to false to stop Neotest from parsing the whole project on startup.
        -- It will only parse the buffer you currently have open.
        enabled = false,
        -- Number of workers used to parse files. Set to 1 to prevent CPU/RAM spikes.
        concurrent = 1,
      },
      running = {
        -- Set to false if running multiple tests at once is slowing you down.
        concurrent = false,
      },
    },
  },
}
