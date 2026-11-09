return {
	{
		'MeanderingProgrammer/render-markdown.nvim',
		lazy = true,
		opts = {},
		dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' }, -- if you prefer nvim-web-devicons

		-- Lazy load the plugin only when a Markdown file is opened
		ft = "markdown",

		config = function()
			-- Set up the keybinding to toggle reader mode
			vim.api.nvim_set_keymap('n', '<leader>rm', ':RenderMarkdown toggle<CR>', { noremap = true, silent = true })
		end,
	},
}
