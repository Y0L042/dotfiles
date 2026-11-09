-- ~/.config/nvim/lua/plugins/toggleterm.lua
return {
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    opts = {
      -- don’t override shell or shellcmdflag here
      open_mapping    = [[<C-\>]],
      start_in_insert = true,
      insert_mappings = false,
      direction       = "horizontal",
      persist_mode    = true,
      persist_size    = true,
      close_on_exit   = false,
      float_opts      = {
        border   = "curved",
        winblend = 5,
      },
      size            = function(term)
        if term.direction == "horizontal" then
          return 15
        else
          return vim.o.columns * 0.4
        end
      end,
    },
    config = function(_, opts)
      require("toggleterm").setup(opts)
      -- optional: keep terminal keymaps
      function _G.set_terminal_keymaps()
        local map = vim.keymap.set
        local opts = { buffer = 0, nowait = true }
        map("t", "<esc>", [[<C-\><C-n>]], opts)
        map("t", "jk", [[<C-\><C-n>]], opts)
        -- map("t", "<C-h>", [[<Cmd>wincmd h<CR>]], opts)
        -- map("t", "<C-j>", [[<Cmd>wincmd j<CR>]], opts)
        -- map("t", "<C-k>", [[<Cmd>wincmd k<CR>]], opts)
        -- map("t", "<C-l>", [[<Cmd>wincmd l<CR>]], opts)
        map("t", "<C-w>", [[<C-\><C-n><C-w>]], opts)
      end

      -- apply them whenever a new toggleterm buffer opens
      vim.cmd([[autocmd! TermOpen term://* lua set_terminal_keymaps()]])
    end,
  },
}
