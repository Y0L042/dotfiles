return {
  {
    'dyng/ctrlsf.vim',
		lazy = true,
    config = function()
      -- Configure ctrlsf.vim here
      if is_env_laptop_win or is_env_laptop_wsl2 then
        vim.g.ctrlsf_backend = 'rg'
        vim.g.ctrlsf_backend_program = 'C:\\msys64\\ucrt64\\bin\\rg.exe'  -- Update this path to your rg.exe location
      end
      vim.g.ctrlsf_default_root = 'project'
      vim.g.ctrlsf_auto_close = 1
      vim.g.ctrlsf_position = 'bottom'
      vim.g.ctrlsf_winsize = '40%'
      vim.g.ctrlsf_extra_root_markers = { '.git', '.hg', '.svn', 'Makefile', 'package.json' }
      vim.g.ctrlsf_auto_focus = { at = 'done', duration_less_than = 1000 }

      -- Ignore tags file
      vim.g.ctrlsf_ignore_file = { 'tags' }

      -- Key mappings for ctrlsf.vim
      vim.api.nvim_set_keymap('n', 'SF', ':CtrlSF ', { noremap = true, silent = false })
      vim.api.nvim_set_keymap('n', 'SO', ':CtrlSFOpen<CR>', { noremap = true, silent = true })
      vim.api.nvim_set_keymap('n', 'SC', ':CtrlSFClose<CR>', { noremap = true, silent = true })
      vim.api.nvim_set_keymap('n', 'ST', ':CtrlSFToggle<CR>', { noremap = true, silent = true })
      vim.api.nvim_set_keymap('n', 'SR', ':CtrlSFRefresh<CR>', { noremap = true, silent = true })
    end
  },
}
