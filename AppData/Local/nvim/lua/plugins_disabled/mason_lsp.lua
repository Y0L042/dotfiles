return {

  -- [[ Mason ]]
  {
    "williamboman/mason.nvim",
    event = "VeryLazy",
    config = function()
      require("mason").setup {}
    end,
  },
  -- Add mason-lspconfig to automatically install LSP servers
  {
    "williamboman/mason-lspconfig.nvim",
    event = "VeryLazy",
    dependencies = {
      "williamboman/mason.nvim",
    },
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = { "lua_ls", "clangd" },
      })
    end,
  },

  {
    'nvim-java/nvim-java',
    lazy = true,
    config = function()
      require('java').setup()
    end
  },
  -- LSP Configuration using built-in vim.lsp.config (Neovim 0.11+)
  {
    "neovim/nvim-lspconfig", -- LSP configuration plugin
    event = "VeryLazy",
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
    },
    config = function()
      local capabilities = require('cmp_nvim_lsp').default_capabilities()

      -- LUA
      vim.lsp.config('lua_ls', {})

      -- JAVA
      -- vim.lsp.config('jdtls', {})

      -- C/CPP
      vim.lsp.config('clangd', {
        cmd = {
          "clangd",
          '--background-index=false', -- Disable background indexing to save memory
          '--clang-tidy=false',       -- Disable clang-tidy to reduce memory usage
          '--limit-results=50',       -- Limit completion results
          '--header-insertion=never', -- Prevent header insertion memory overhead
        },
        capabilities = require('cmp_nvim_lsp').default_capabilities(),
        settings = {
          clangd = {
            InlayHints = {
              Designators = true,
              Enabled = true,
              ParameterNames = true,
              DeducedTypes = true,
            },
            fallbackFlags = { "-std=c99" },
          },
        },
        root_dir = vim.fs.root(0, { 'compile_commands.json', '.git', '.clangd', '.clang-format' }),
      })

      -- MATLAB
      -- vim.lsp.config('matlab_ls', {
      --  single_file_support = true,
      -- settings = {
      -- 	matlab = {
      -- 		installPath = '/path/to/MATLAB',  -- Example: '/Applications/MATLAB_R2023b.app'
      -- 		telemetry = false,
      -- 	},
      -- },
      -- })

      -- GDSCRIPT
      --   local gdscript_config = {
      --       capabilities = capabilities,
      --       settings = {},
      --   }
      --   if vim.fn.has 'win32' == 1 then
      --       gdscript_config['cmd'] = { 'ncat', 'localhost', os.getenv 'GDScript_Port' or '6005' }
      --   end
      -- vim.lsp.config('gdscript', gdscript_config)

      -- keymap to start/stop LSP on demand
      vim.keymap.set('n', '<leader>ls', ':LspStart<CR>', {
        noremap = true, silent = true, desc = "Start LSP" -- added
      })
      vim.keymap.set('n', '<leader>lS', ':LspStop<CR>', {
        noremap = true, silent = true, desc = "Stop LSP" -- added
      })

      -- Key mappings for diagnostics
      local diagnostics_enabled = false -- False by default
      vim.keymap.set('n', '<leader>td', function()
        if diagnostics_enabled then
          vim.diagnostic.disable() -- Disable diagnostics
        else
          vim.diagnostic.enable()  -- Enable diagnostics
        end
        diagnostics_enabled = not diagnostics_enabled
      end, { silent = false, noremap = true })
      -- Additional diagnostics config if needed
      vim.diagnostic.config({
        virtual_text = true,
        signs = false,
        update_in_insert = false,
        underline = true,
        severity_sort = true,
      })

      vim.keymap.set('i', '<C-A>', vim.lsp.buf.signature_help, { silent = false, noremap = true })
      vim.keymap.set('n', '<C-A>', vim.lsp.buf.signature_help, { silent = false, noremap = true })

      -- Go to definition (function definition in C)
      -- vim.keymap.set('n', 'gd', vim.lsp.buf.definition, { silent = true, noremap = true })

      -- Go to definition (redundant with 'gd', but provided as per request)
      vim.keymap.set('n', '<leader>gdd', vim.lsp.buf.definition, { silent = true, noremap = true })

      -- Go to definition in horizontal split below
      vim.keymap.set('n', '<leader>gds', function()
        vim.cmd('split') -- Open a horizontal split
        vim.lsp.buf.definition()
      end, { silent = true, noremap = true })

      -- Go to definition in vertical split to the right
      vim.keymap.set('n', '<leader>gdv', function()
        vim.cmd('vsplit') -- Open a vertical split
        vim.lsp.buf.definition()
      end, { silent = true, noremap = true })

      vim.keymap.set("n", "]ge", vim.diagnostic.goto_next)
      vim.keymap.set("n", "[ge", vim.diagnostic.goto_prev)

      -- Key mappings for manual formatting and style checking
      vim.api.nvim_set_keymap("n", "<leader>cf", ":lua vim.lsp.buf.format()<CR>", { noremap = true, silent = false }) -- Manual format

      -- Function to populate the location list with diagnostics
      local function PopulateLocationList()
        vim.diagnostic.setloclist({ open = true })
        vim.cmd("botright 10lopen")
        vim.cmd("wincmd J")
      end
      -- Map <leader>l to populate and open the location list
      vim.keymap.set('n', '<leader>l', PopulateLocationList, { noremap = true, silent = true })



      -- ==== Basic Rename Function Start ====
      -- Basic Rename Function with Confirmation
      local function RenameWithConfirmation()
        -- Prompt the user for the new name
        vim.ui.input({ prompt = "Rename to: " }, function(new_name)
          -- Check if the user provided a non-empty name
          if new_name and new_name ~= "" then
            -- Perform the rename using LSP
            vim.lsp.buf.rename(new_name)
          else
            -- Notify the user that the rename was cancelled
            vim.notify("Rename cancelled.", vim.log.levels.WARN)
          end
        end)
      end

      -- Map the Rename function to a keybinding
      vim.keymap.set('n', '<leader>rn', RenameWithConfirmation, {
        noremap = true,
        silent = true,
        desc = "Rename Symbol with Confirmation",
      })
      -- ==== Basic Rename Function End ====
    end
  },


  -- Add nvim-cmp and its dependencies
  {
    "hrsh7th/nvim-cmp", -- Completion plugin
    -- lazy = true,
    event = "VeryLazy",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp", -- LSP source for nvim-cmp
      "hrsh7th/cmp-buffer",   -- Buffer completion source
      "hrsh7th/cmp-path",     -- Path completion source
      "hrsh7th/cmp-cmdline",  -- Command line completion source
      "hrsh7th/cmp-vsnip",    -- Snippet completion source
      "hrsh7th/vim-vsnip",    -- Snippet engine
    },
    config = function()
      -- Set up nvim-cmp
      local cmp = require 'cmp'

      cmp.setup({
        completion = {
          autocomplete = false,
        },
        snippet = {
          expand = function(args)
            require('vsnip').expand(args.body) -- For vsnip users.
          end,
        },
        mapping = {
          ['<C-N>'] = cmp.mapping(cmp.mapping.complete(), { 'i', 'c' }),
          ['<C-k>'] = cmp.mapping.select_prev_item(),        -- Navigate to previous completion item
          ['<C-j>'] = cmp.mapping.select_next_item(),        -- Navigate to next completion item
          ['<C-e>'] = cmp.mapping.close(),                   -- Close completion window
          ['<CR>'] = cmp.mapping.confirm({ select = true }), -- Confirm completion
        },
        sources = {
          { name = 'nvim_lsp' }, -- LSP completion
          { name = 'buffer' },   -- Buffer completion
          { name = 'path' },     -- Path completion
        },
      })

      -- Configure command line completion
      cmp.setup.cmdline(':', {
        sources = {
          { name = 'cmdline' }
        }
      })
    end,
  },
}
