return {
	{
		'nvim-lualine/lualine.nvim',
        event = "VeryLazy",
		dependencies = { 'nvim-tree/nvim-web-devicons' },
		config = function()
			require('lualine').setup({
				options = {
					theme = 'ayu_dark'
				},
			})
		end,
	},
}
