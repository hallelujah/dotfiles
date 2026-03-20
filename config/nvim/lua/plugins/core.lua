-- Use Snazzy as our default color scheme
return {
	{
		"LazyVim/LazyVim",
		opts = {
			colorscheme = "embark",
		},
	},
	-- Additional plugins from the original plugins.vim
	{ "christoomey/vim-run-interactive" },
	{ "elixir-lang/vim-elixir" },
	{ "fatih/vim-go" },
	{ "tpope/vim-bundler" },
	{ "tpope/vim-endwise" },
	{ "tpope/vim-eunuch" },
	{ "tpope/vim-projectionist" },
	{ "tpope/vim-rails" },
	{ "tpope/vim-rake" },
	{ "tpope/vim-repeat" },
	{ "tpope/vim-rhubarb" },
	{ "vim-ruby/vim-ruby" },
	{ "vim-scripts/tComment" },

	-- ALE (LazyVim uses conform/nvim-lint by default, but keeping ALE if explicitly requested or preferred)
	-- Actually, LazyVim's default linting/formatting is better, but let's keep ALE for compatibility as a start
	{ "dense-analysis/ale" },
	{ "neovim/nvim-lspconfig", opts = { servers = { ruby_lsp = {} } } },

	-- fzf
	{
		"ibhagwan/fzf-lua",
		-- optional for icon support
		dependencies = { "nvim-tree/nvim-web-devicons" },
		-- or if using mini.icons/mini.nvim
		-- dependencies = { "nvim-mini/mini.icons" },
		---@module "fzf-lua"
		---@type fzf-lua.Config|{}
		---@diagnostic disable: missing-fields
		opts = {},
		---@diagnostic enable: missing-fields
	},
	-- Local plugins
	(function()
		local plugins_local = vim.fn.expand("~/.config/nvim/plugins.vim.local")
		if vim.fn.filereadable(plugins_local) == 1 then
			-- This is a bit tricky since plugins.vim.local is Vimscript and uses vim-plug
			-- For now, we'll just note that it's not directly compatible without manual migration
			-- or a shim.
			return {}
		end
		return {}
	end)(),
}
