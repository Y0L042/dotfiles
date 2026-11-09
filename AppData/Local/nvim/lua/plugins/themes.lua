return {
  -- [[ Color Schemes ]]
  -- Add Gruvbox color scheme
  {
    'morhetz/gruvbox',
    as = 'gruvbox',
    config = function()
      -- Uncomment to set Gruvbox as the default colorscheme
      -- vim.cmd('colorscheme gruvbox')
    end,
  },
  -- Add Dracula color scheme
  {
    'dracula/vim',
    as = 'dracula',
    config = function()
      -- Uncomment to set Dracula as the default colorscheme
      -- vim.cmd('colorscheme dracula')
    end,
  },
  {
    "EdenEast/nightfox.nvim",
    as = 'nightfox',
    config = function()
      -- vim.cmd('colorscheme nightfox')
    end,
  },
  {
    "EdenEast/nightfox.nvim",
    config = function()
      -- vim.cmd('colorscheme carbonfox')
    end,
  },
  {
    "ayu-theme/ayu-vim",
    as = 'ayu',
    config = function()
      -- Enable true colors support
      vim.o.termguicolors = true

      -- Set the ayucolor variable to choose the theme variant
      vim.g.ayucolor = "dark" -- Options: "light", "mirage", "dark"

      -- Apply the colorscheme
      vim.cmd('colorscheme ayu')
    end,
  },
}
