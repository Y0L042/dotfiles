-- Register daslang filetype
vim.filetype.add({
  extension = {
    das = "dascript",
    das_project = "dascript",
    das_module = "dascript",
    das_package = "dascript"
  },
})

-- Register the precompiled daslang tree-sitter parser
vim.treesitter.language.add("daslang", {
  path = "C:/Programs/daslang/tree-sitter-daslang/daslang.dll",
})

-- Map the `dascript` filetype to the `daslang` parser. This (plus highlighting below) was
-- previously provided by the generic `daslang-lsp` plugin's treesitter.setup(); since that
-- plugin is now disabled (it false-flags dn_* bindings), highlighting is wired here so it no
-- longer depends on it.
vim.treesitter.language.register("daslang", "dascript")

-- The daslang queries live at queries/highlights.scm (no `daslang/` language subdir), so the
-- standard runtimepath lookup (<rtp>/queries/daslang/highlights.scm) won't find them. Load the
-- highlights query explicitly instead.
do
  local hl = "C:/Programs/daslang/tree-sitter-daslang/queries/highlights.scm"
  local f = io.open(hl, "r")
  if f then
    local q = f:read("*a"); f:close()
    vim.treesitter.query.set("daslang", "highlights", q)
  else
    vim.notify("daslang: highlights.scm not found at " .. hl, vim.log.levels.WARN)
  end
end

-- Start treesitter highlighting on daslang buffers (independent of the LSP).
-- Errors are reported rather than swallowed so a stale daslang.dll / highlights.scm mismatch
-- (query references a node type the parser doesn't know) shows up in :messages instead of
-- silently leaving the buffer unhighlighted.
local function das_start_highlight(buf)
  if not vim.api.nvim_buf_is_valid(buf) or vim.treesitter.highlighter.active[buf] then return end
  local ok, err = pcall(vim.treesitter.start, buf, "daslang")
  if not ok then
    vim.notify("daslang treesitter highlighting failed:\n" .. tostring(err), vim.log.levels.WARN)
  end
end

local das_hl_group = vim.api.nvim_create_augroup("daslang_highlight", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
  group = das_hl_group,
  pattern = "dascript",
  callback = function(ev) das_start_highlight(ev.buf) end,
})
-- Belt and braces: buffers that reach a window without having gone through the FileType path
-- with our autocmd in place (e.g. session restore ordering) get attached by extension.
vim.api.nvim_create_autocmd("BufWinEnter", {
  group = das_hl_group,
  pattern = { "*.das", "*.das_project", "*.das_module", "*.das_package" },
  callback = function(ev) das_start_highlight(ev.buf) end,
})

return {
  -- [[ TreeSitter  ]]
  {
    'nvim-treesitter/nvim-treesitter',
    event = "VeryLazy",
    run = ':TSUpdate',
    config = function()
      require 'nvim-treesitter.configs'.setup {
        -- Ensure these parsers are installed
        ensure_installed = { "c", "cpp", "lua", "rust", "ron" },

        -- Install parsers synchronously (only applied to `ensure_installed`)
        sync_install = false,

        -- Disabled auto_install to prevent unexpected parser downloads and memory issues
        auto_install = false,

        highlight = {
          -- `false` will disable the whole extension
          enable = true,

          -- Setting this to true will run `:h syntax` and tree-sitter at the same time.
          -- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
          -- Using this option may slow down your editor, and you may see some duplicate highlights.
          -- Instead of true it can also be a list of languages
          additional_vim_regex_highlighting = false,
        },
      }
    end,
  },
  {
    'nvim-treesitter/nvim-treesitter-textobjects',
    event = "VeryLazy",
    config = function()
      require 'nvim-treesitter.configs'.setup {
        textobjects = {
          move = {
            enable = true,
            set_jumps = true,   -- Record jumps for easier navigation

            goto_next_start = {
              ["]f"] = "@function.outer",   -- Added: jump to the start of the next function
            },
            goto_previous_start = {
              ["[f"] = "@function.outer",   -- Added: jump to the start of the previous function
            },

            goto_next_start = {
              ["]c"] = "@class.outer",   -- Added: jump to the start of the next class
            },
            goto_previous_start = {
              ["[c"] = "@class.outer",   -- Added: jump to the start of the previous class
            },
          },
          select = {
            enable = true,

            -- Automatically jump forward to textobj, similar to targets.vim
            lookahead = true,

            keymaps = {
              -- You can use the capture groups defined in textobjects.scm
              ["af"] = "@function.outer",
              ["if"] = "@function.inner",
              ["ac"] = "@class.outer",
              -- You can optionally set descriptions to the mappings (used in the desc parameter of
              -- nvim_buf_set_keymap) which plugins like which-key display
              ["ic"] = { query = "@class.inner", desc = "Select inner part of a class region" },
              -- You can also use captures from other query groups like `locals.scm`
              ["as"] = { query = "@local.scope", query_group = "locals", desc = "Select language scope" },
            },
            -- You can choose the select mode (default is charwise 'v')
            --
            -- Can also be a function which gets passed a table with the keys
            -- * query_string: eg '@function.inner'
            -- * method: eg 'v' or 'o'
            -- and should return the mode ('v', 'V', or '<c-v>') or a table
            -- mapping query_strings to modes.
            selection_modes = {
              ['@parameter.outer'] = 'v',   -- charwise
              ['@function.outer'] = 'V',    -- linewise
              ['@class.outer'] = '<c-v>',   -- blockwise
            },
            -- If you set this to `true` (default is `false`) then any textobject is
            -- extended to include preceding or succeeding whitespace. Succeeding
            -- whitespace has priority in order to act similarly to eg the built-in
            -- `ap`.
            --
            -- Can also be a function which gets passed a table with the keys
            -- * query_string: eg '@function.inner'
            -- * selection_mode: eg 'v'
            -- and should return true or false
            include_surrounding_whitespace = true,
          },
        },
      }
      -- Override the default behavior of "]f" by explicitly mapping it
      vim.api.nvim_set_keymap(
        'n',                                                                                           -- mode: normal mode
        ']f',                                                                                          -- key combination to override
        "<cmd>lua require'nvim-treesitter.textobjects.move'.goto_next_start('@function.outer')<CR>",   -- call Treesitter function for next function
        { noremap = true, silent = true }                                                              -- Options: no recursive mapping and silent execution
      )

      vim.api.nvim_set_keymap(
        'n',                                                                                               -- mode: normal mode
        '[f',                                                                                              -- key combination to override
        "<cmd>lua require'nvim-treesitter.textobjects.move'.goto_previous_start('@function.outer')<CR>",   -- call Treesitter function for previous function
        { noremap = true, silent = true }                                                                  -- Options: no recursive mapping and silent execution
      )

      -- Override the default behavior of "]f" by explicitly mapping it
      vim.api.nvim_set_keymap(
        'n',                                                                                        -- mode: normal mode
        ']c',                                                                                       -- key combination to override
        "<cmd>lua require'nvim-treesitter.textobjects.move'.goto_next_start('@class.outer')<CR>",   -- call Treesitter function for next function
        { noremap = true, silent = false }                                                          -- Options: no recursive mapping and silent execution
      )

      vim.api.nvim_set_keymap(
        'n',                                                                                            -- mode: normal mode
        '[c',                                                                                           -- key combination to override
        "<cmd>lua require'nvim-treesitter.textobjects.move'.goto_previous_start('@class.outer')<CR>",   -- call Treesitter function for previous function
        { noremap = true, silent = false }                                                              -- Options: no recursive mapping and silent execution
      )
    end
  }
}
