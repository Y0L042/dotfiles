return {
	{
		'm4xshen/autoclose.nvim',
		event = "VeryLazy",
		config = function()
			require("autoclose").setup({
				keys = {
				},
			})
			--vim.api.nvim_set_keymap('i', '/*', '/*  */<Left><Left><Left>', { noremap = true, silent = true })
		end,
	},

	{
		'tpope/vim-surround',
		event = "VeryLazy",
		config = function()
			-- Optional: Add any custom configuration for vim-surround here
		end,
	},

	{
		"numToStr/Comment.nvim",
		event = "VeryLazy",
		config = function()
			require('Comment').setup({
				opts = {
					-- add any options here
				},
				lazy = false,
			})
		end,
	},

	{
		"folke/flash.nvim"
	},

	{
		"lewis6991/gitsigns.nvim",
		event = "VeryLazy",
		config = function()
			require('gitsigns').setup({

			})
		end,
	},

	{
		"chentoast/marks.nvim",
		event = "VeryLazy",
		opts = {},
	},
}
