return {
  -- [[ Telescope Configuration ]]
  {
    -- Fuzzy Finder (files, lsp, etc)
    'nvim-telescope/telescope.nvim',
    event = 'VeryLazy',
    branch = '0.1.x',
    dependencies = {
      'nvim-lua/plenary.nvim',
      {                 -- Telescope FZF Native for better sorting
        'nvim-telescope/telescope-fzf-native.nvim',
        build = 'make', -- Only run `make` when installing/updating the plugin
        cond = function()
          return vim.fn.executable 'make' == 1
        end,
      },
      { 'nvim-telescope/telescope-ui-select.nvim' },
      {
        'nvim-tree/nvim-web-devicons',
        enabled = vim.g.have_nerd_font
      }, -- Requires a Nerd Font for icons
    },
    config = function()
      -- Define patterns to ignore (exclude)
      local ignore_patterns = {
        "%.exe$", "%.dll$", "%.so$", "%.dylib$",
        "%.o$", "%.obj$", "%.log$", "%.pdb$",
        "%.cmake$", "%.sln$", "%.vcxproj$", "%.vcxproj%.user$",
        "%.git/", "%.svn/", "%.idea/", "%.vscode/",
        "build/", "bin/", "out/", "dist/",
        "%.tmp$", "%.bak$", "%.tlog", "%.idb", "%.sarif",
        "%.claude/",
      }

      -- Glob exclusions passed directly to rg (applied before Telescope filtering)
      local rg_exclude_globs = {
        "!.claude/*",
        "!*/.claude/*",
        "!build/**",
        "!bin/**",
        "!out/**",
        "!dist/**",
        "!.git/**",
      }

      -- Merge project-specific ignore patterns from vim.g.project_ignore_patterns
      -- Set this in your project's .nvim.lua, e.g.:
      --   vim.g.project_ignore_patterns = { "vendor/", "third_party/" }
      local project_ignores = vim.g.project_ignore_patterns or {}
      for _, pat in ipairs(project_ignores) do
        table.insert(ignore_patterns, pat)
      end

      -- Define patterns to allow (include)
      local allow_patterns = {
        -- Source code files
        "*.lua", "*.py", "*.js", "*.ts", "*.html", "*.css", "*.scss",
        "*.cpp", "*.inl", "*.gd", "*.c", "*.h", "*.hpp", "*.inc",
        "*.java", "*.cs", "*.rb", "*.go", "*.rs", "*.sh",
        "*.bat", "*.php", "*.dart", "*.swift",
        "*.das", "*.das_module", "*.das_project", "*.das_package",

        -- Configuration files
        "*.json", "*.yaml", "*.yml", "*.toml", "*.ini",
        "*.cfg", "*.env",

        -- Documentation files
        "*.md", "*.txt", "*.rst", "*.adoc",

        -- Build files
        "Makefile", "*.mk", "*.cmake", "*.gradle", "*.pom",

        -- Version control and meta files
        ".gitignore", "*.gitattributes", "*.gitmodules",

        -- Miscellaneous
        "*.csv", "*.tsv", "*.xml", "*.sql", "*.log",
      }

      -- [[ Custom path_display Functions ]]
      local function normalize_path(path)
        return path:gsub("\\", "/")
      end

      -- Filename-first display: "name.ext               │ relative/dir"
      -- Uses fnamemodify so it handles both relative and absolute paths robustly on
      -- Windows; deep directories are shortened to their last 3 components.
      local path_width = 40
      local function path_display(_, path)
        local filename = vim.fn.fnamemodify(path, ":t")
        local parent   = normalize_path(vim.fn.fnamemodify(path, ":~:.:h"))

        if parent == "" or parent == "." then
          parent = "."
        else
          local parts = vim.split(parent, "/", { plain = true })
          if #parts > 3 then
            parent = "…/" .. table.concat(parts, "/", #parts - 2)
          end
        end

        if #filename > path_width then
          filename = "..." .. filename:sub(-(path_width - 3))
        end

        local padded_filename = filename .. string.rep(" ", math.max(0, path_width - #filename))
        return string.format("%s │ %s", padded_filename, parent)
      end

      -- [[ Configure Telescope ]]
      local actions = require('telescope.actions')
      local action_state = require('telescope.actions.state')

      require('telescope').setup {
        defaults = {
          prompt_prefix        = "🔍 ",
          selection_caret      = "➤ ",
          path_display         = path_display,    -- Use the custom path_display function
          file_ignore_patterns = ignore_patterns, -- Exclude unwanted files/directories

          -- Limit picker results to prevent memory bloat
          cache_picker = {
            num_pickers = 5,      -- Only cache 5 most recent pickers
            limit_entries = 100,  -- Max 100 entries per cached picker
          },

          mappings             = {
            i = {},                            -- Insert mode mappings
            n = {
              ["<A-v>"] = actions.file_vsplit, -- Open selected file in a vertical split
            },
          },

          vimgrep_arguments    = {
            "rg",
            "--color=never",
            "--no-heading",
            "--with-filename",
            "--line-number",
            "--column",
            "--smart-case",
            "--hidden",
            -- Exclude version control and common non-source directories
            "--glob", "!.git/*",
            "--glob", "!*/.claude/*",
            -- SAFETY: Exclude system directories to prevent memory issues when searching /
            -- (searching /proc on Linux or C:\Windows on Windows can cause pathological behavior)
            "--glob", "!/proc/*",
            "--glob", "!/sys/*",
            "--glob", "!/dev/*",
            "--glob", "!/run/*",
            "--glob", "!/tmp/*",
            "--glob", "!/var/*",
            -- Windows system directories
            "--glob", "!/Windows/*",
            "--glob", "!/Program Files/*",
            "--glob", "!/Program Files (x86)/*",
            "--glob", "!*/ProgramData/*",
            "--glob", "!*/AppData/*",
          },
          file_sorter          = require('telescope.sorters').get_fuzzy_file, -- FZF sorter
          generic_sorter       = require('telescope.sorters').get_generic_fuzzy_sorter(),
          file_previewer       = require('telescope.previewers').vim_buffer_cat.new,
          grep_previewer       = require('telescope.previewers').vim_buffer_vimgrep.new,
          qflist_previewer     = require('telescope.previewers').vim_buffer_qflist.new,
          -- disable previewer for big dirs
          previewer            = false,
        },
        pickers = {
          find_files = {
            find_command = { "fd", "--type", "f", "--hidden", "--strip-cwd-prefix" },
            previewer = false, -- skip the file preview
          },
          live_grep = {
            previewer = false, -- skip the file preview
          },
        },
        extensions = {
          ['ui-select'] = {
            require('telescope.themes').get_dropdown(),
          },
          fzf = { -- make sure fzf-native is loaded
            fuzzy                   = true,
            override_generic_sorter = true,
            override_file_sorter    = true,
            case_mode               = "smart_case",
          },
        },
      }

      -- Enable Telescope extensions if they are installed
      pcall(require('telescope').load_extension, 'fzf')
      pcall(require('telescope').load_extension, 'ui-select')

      -- Sorter that scores the query against the FILENAME only, so verbatim
      -- filename matches outrank deep-directory matches. If the query contains a
      -- path separator (/ or \), it scores against the full relative path instead,
      -- letting you narrow by directory when you want to.
      local function filename_first_sorter()
        local ok, fzf_ext = pcall(function()
          return require('telescope').extensions.fzf
        end)
        if not ok or not fzf_ext or not fzf_ext.native_fzf_sorter then
          -- Fallback: plain fuzzy file sorter (fzf-native not available)
          return require('telescope.sorters').get_fuzzy_file()
        end

        local sorter = fzf_ext.native_fzf_sorter({
          fuzzy = true,
          case_mode = "smart_case",
        })
        local orig_scoring = sorter.scoring_function
        sorter.scoring_function = function(self, prompt, line, entry)
          -- No separator in the query => match against the basename only.
          if prompt ~= "" and not prompt:find("[/\\]") then
            line = line:match("[^/\\]*$") or line
          end
          return orig_scoring(self, prompt, line, entry)
        end
        return sorter
      end

      -- Shortcut to access Telescope's built-in functions
      local builtin = require 'telescope.builtin'

      -- Keymaps for various Telescope functions
      vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
      vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
      vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
      vim.keymap.set('n', '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
      -- vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
      vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
      vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
      vim.keymap.set('n', '<leader><leader>', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
      vim.keymap.set('n', '<leader>sj', builtin.jumplist, { desc = '[S]earch [J]umps' })
      vim.keymap.set('n', '<leader>s.', builtin.buffers, { desc = '[ ] Find existing buffers' })

      vim.keymap.set('n', '<leader>sD', builtin.lsp_definitions, { desc = '[S]earch LSP [D]efinitions' })
      vim.keymap.set('n', '<leader>sT', builtin.lsp_type_definitions, { desc = '[S]earch LSP [T]ype definitions' })

      -- LSP references with memory-conscious settings to prevent buffer explosion
      vim.keymap.set('n', '<leader>sR', function()
        builtin.lsp_references({
          show_line = false,          -- Don't load full buffer content for each match
          include_declaration = false, -- Exclude declaration to reduce results
          fname_width = 50,           -- Limit filename display width
          trim_text = true,           -- Trim long lines instead of loading full content
        })
      end, { desc = '[S]earch LSP [R]eferences' })

      vim.keymap.set('n', '<leader>sI', builtin.lsp_implementations, { desc = '[S]earch LSP [I]mplementations' })

      -- Build the `rg --files` command with allow-only + exclude globs applied.
      -- Shared by <leader>sf and the solution-wide search keymaps below.
      local function build_find_command()
        local find_command = { "rg", "--files", "--hidden", "--no-ignore" }
        for _, pattern in ipairs(allow_patterns) do
          table.insert(find_command, "--glob")
          table.insert(find_command, pattern)
        end
        for _, pat in ipairs(rg_exclude_globs) do
          table.insert(find_command, "--glob")
          table.insert(find_command, pat)
        end
        -- Exclude project-specific dirs
        for _, pat in ipairs(project_ignores) do
          table.insert(find_command, "--glob")
          table.insert(find_command, "!" .. pat)
        end
        return find_command
      end

      -- Keymap for searching files with allow-only patterns using `rg --files`
      vim.keymap.set('n', '<leader>sf', function()
        require('telescope.builtin').find_files {
          find_command = build_find_command(),
          sorter = filename_first_sorter(),
        }
      end, { desc = '[S]earch [F]iles (allow-only)' })

      -- Keymap for live grep with allow-only patterns using `rg`
      -- SAFETY: Includes safeguards against searching root directory (/) which can cause memory issues
      vim.keymap.set('n', '<leader>sg', function()
        local grep_args = { "--hidden", "--no-ignore" }
        for _, pattern in ipairs(allow_patterns) do
          table.insert(grep_args, "--glob")
          table.insert(grep_args, pattern)
        end
        for _, pat in ipairs(rg_exclude_globs) do
          table.insert(grep_args, "--glob")
          table.insert(grep_args, pat)
        end
        -- Exclude project-specific dirs
        for _, pat in ipairs(project_ignores) do
          table.insert(grep_args, "--glob")
          table.insert(grep_args, "!" .. pat)
        end

        -- Get current working directory as default search root
        local cwd = vim.loop.cwd()

        require('telescope.builtin').live_grep {
          cwd = cwd,  -- Explicitly set search root to current working directory
          additional_args = function()
            return grep_args
          end,
        }
      end, { desc = '[S]earch by [G]rep (allow-only)' })

      -- Advanced example: Fuzzily search in the current buffer with a dropdown theme
      vim.keymap.set('n', '<leader>/', function()
        builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
          -- winblend = 10,
          previewer = true,
        })
      end, { desc = '[/] Fuzzily search in current buffer' })

      -- Search within open files - DISABLED to prevent memory bloat
      -- This feature loads ALL open buffers into memory which can cause 8GB+ RAM spikes
      -- Uncomment if needed, but use with caution:
      -- vim.keymap.set('n', '<leader>s/', function()
      --   builtin.live_grep {
      --     cwd = vim.loop.cwd(),
      --     grep_open_files = true,
      --     prompt_title = 'Live Grep in Open Files',
      --   }
      -- end, { desc = '[S]earch [/] in Open Files' })

      -- Shortcut for searching your Neovim configuration files
      vim.keymap.set('n', '<leader>sn', function()
        builtin.find_files {
          cwd = vim.fn.stdpath 'config',
          sorter = filename_first_sorter(),
        }
      end, { desc = '[S]earch [N]eovim files' })

      -- [[ Solution-wide search (multi-project) ]]

      -- Find the solution root: explicit override, else walk up for a marker, else cwd.
      local function find_solution_root()
        if vim.g.solution_root then
          return normalize_path(vim.g.solution_root)
        end
        local markers = { "*.sln", ".git", "CMakeLists.txt" }
        local dir = vim.fn.expand("%:p:h")
        for _ = 1, 10 do
          for _, marker in ipairs(markers) do
            if #vim.fn.glob(dir .. "/" .. marker) > 0 then
              return normalize_path(dir)
            end
          end
          local parent = vim.fn.fnamemodify(dir, ":h")
          if parent == dir then break end
          dir = parent
        end
        return normalize_path(vim.loop.cwd())
      end

      -- Display "name.ext   │ [Project] sub/path", where Project is the first path
      -- component under the solution root. Typing a project name filters results.
      -- Because the picker runs rg with cwd = root, `path` is normally already
      -- relative to root; we only strip the root prefix if rg handed us an absolute path.
      local function solution_path_display(root, _, path)
        local rel = normalize_path(path)
        local nroot = normalize_path(root) .. "/"
        if rel:match("^%a:/") or rel:match("^/") then -- absolute path: make it root-relative
          if string.lower(rel:sub(1, #nroot)) == string.lower(nroot) then
            rel = rel:sub(#nroot + 1)
          end
        end
        local parts = vim.split(rel, "/", { plain = true })
        local filename = parts[#parts]
        local project  = #parts > 1 and parts[1] or ""
        local subpath  = #parts > 2 and table.concat(parts, "/", 2, #parts - 1) or "."

        if #filename > path_width then
          filename = "..." .. filename:sub(-(path_width - 3))
        end
        local padded = filename .. string.rep(" ", math.max(0, path_width - #filename))
        if project ~= "" then
          return string.format("%s │ [%s] %s", padded, project, subpath)
        end
        return string.format("%s │ %s", padded, subpath)
      end

      -- <leader>sp — search files across the whole solution, tagged by project.
      vim.keymap.set('n', '<leader>sp', function()
        local root = find_solution_root()
        builtin.find_files {
          prompt_title = 'Solution Files',
          cwd          = root,
          find_command = build_find_command(),
          sorter       = filename_first_sorter(),
          path_display = function(opts, p) return solution_path_display(root, opts, p) end,
        }
      end, { desc = '[S]earch [P]roject (solution-wide)' })

      -- <leader>sP — pick a top-level project dir, then search files scoped to it.
      vim.keymap.set('n', '<leader>sP', function()
        local root = find_solution_root()
        local dirs = vim.fn.glob(root .. "/*/", false, true)
        local projects = {}
        for _, d in ipairs(dirs) do
          local name = vim.fn.fnamemodify(d:gsub("/$", ""), ":t")
          table.insert(projects, { name = name, dir = normalize_path(d:gsub("/$", "")) })
        end
        if #projects == 0 then
          vim.notify("No project directories found under " .. root, vim.log.levels.WARN)
          return
        end
        vim.ui.select(projects, {
          prompt = "Select project:",
          format_item = function(item) return item.name end,
        }, function(choice)
          if not choice then return end
          builtin.find_files {
            prompt_title = 'Files: ' .. choice.name,
            cwd          = choice.dir,
            find_command = build_find_command(),
            sorter       = filename_first_sorter(),
          }
        end)
      end, { desc = '[S]earch in [P]roject (pick first)' })
    end,
  },
}
