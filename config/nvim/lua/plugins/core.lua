-- Use Snazzy as our default color scheme
return {
	{
		"LazyVim/LazyVim",
		opts = {
			colorscheme = "embark",
		},
	},

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

	-- surround
	{ "nvim-mini/mini.nvim", version = false },
}
