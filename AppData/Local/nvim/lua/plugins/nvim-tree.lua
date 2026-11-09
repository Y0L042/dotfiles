return {

  {
    "nvim-tree/nvim-web-devicons"
  },

  {
    "nvim-tree/nvim-tree.lua",
    version = "*",
    lazy = false,
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      -- Custom file name formatter
      local function custom_name_formatter(name)
        local max_len = 20 -- Set the max length for file names
        if #name <= max_len then
          return name
        end
        local ext_index = name:find("%.[^%.]*$") or #name + 1
        local prefix = name:sub(1, math.floor(max_len / 2) - 3)            -- Beginning part
        local suffix = name:sub(ext_index - (math.floor(max_len / 2) - 3)) -- End part + extension
        return prefix .. "..." .. suffix
      end

      local function label(path)
        path = path:gsub(os.getenv 'HOME', '~', 1)
        return path:gsub('([a-zA-Z])[a-z0-9]+', '%1') ..
            (path:match '[a-zA-Z]([a-z0-9]*)$' or '')
      end
      local api = require 'nvim-tree.api'

      -- Custom C/C++ bundled sorter: groups header/source pairs together
      local function custom_cpp_bundled_sorter(nodes)
        -- Define extension priority for C/C++ files
        local cpp_extensions = {h = 1, hpp = 2, c = 3, cpp = 4}

        -- Extract base name (filename without extension)
        local function get_basename(name)
          local base = name:match("(.+)%.[^%.]+$")
          return base or name -- Return full name if no extension
        end

        -- Partition nodes into folders and files
        local folders = {}
        local cpp_files = {}
        local other_files = {}

        for _, node in ipairs(nodes) do
          if node.type == "directory" then
            table.insert(folders, node)
          else
            local ext = node.extension or ""
            if cpp_extensions[ext] then
              table.insert(cpp_files, node)
            else
              table.insert(other_files, node)
            end
          end
        end

        -- Sort folders alphabetically
        table.sort(folders, function(a, b)
          return a.name:lower() < b.name:lower()
        end)

        -- Sort C/C++ files by base name, then by extension priority
        table.sort(cpp_files, function(a, b)
          local a_base = get_basename(a.name):lower()
          local b_base = get_basename(b.name):lower()

          -- Compare base names first
          if a_base ~= b_base then
            return a_base < b_base
          end

          -- Same base name: sort by extension priority
          local a_ext = a.extension or ""
          local b_ext = b.extension or ""
          local a_priority = cpp_extensions[a_ext] or 999
          local b_priority = cpp_extensions[b_ext] or 999

          return a_priority < b_priority
        end)

        -- Sort other files alphabetically
        table.sort(other_files, function(a, b)
          return a.name:lower() < b.name:lower()
        end)

        -- Clear the original nodes array and repopulate it
        for i = #nodes, 1, -1 do
          nodes[i] = nil
        end

        -- Combine: folders first, then C/C++ bundles, then other files
        for _, folder in ipairs(folders) do
          table.insert(nodes, folder)
        end
        for _, file in ipairs(cpp_files) do
          table.insert(nodes, file)
        end
        for _, file in ipairs(other_files) do
          table.insert(nodes, file)
        end
      end

      require("nvim-web-devicons").set_icon({
        das = {
          icon = "\xF3\xB1\x90\x8B",
          color = "#FF7575",
          name = "Daslang",
        },
        das_module = {
          icon = "\xF3\xB1\x90\x8B",
          color = "#808080",
          name = "DaslangModule",
        },
        das_project = {
          icon = "\xF3\xB1\x90\x8B",
          color = "#808080",
          name = "DaslangProject",
        },
      })

      require("nvim-tree").setup {
        hijack_cursor = true,
        sync_root_with_cwd = true,
        filesystem_watchers = {
          enable = false,
        },
        -- Commented out experimental file watcher to prevent memory leaks
        -- experimental = {
        --   use_libuv_file_watcher = true,
        -- },
        filters = {
          dotfiles = false,
          custom = {
            -- "^.git$",
            "^node_modules$",
            "^build$",
            -- "^out$",
            -- "^bin$",
            "^target$",
            "^dist$",
            -- "^.claude$",
            "\\.o$",
            "\\.obj$",
            -- "\\.exe$",
            -- "\\.dll$",
            -- "\\.so$",
            "\\.dylib$",
            "\\.cache$",
            "\\.tmp$",
            "\\.inc$",
          },
        },
        git = {
          enable = false,
        },
        renderer = {
          root_folder_label = false,
          icons = {
            show = {
              git = false,
              file = true,
              folder = true,
              folder_arrow = true,
            },
          },
          highlight_opened_files = "name",
          highlight_git = false,
        },
        view = {
          adaptive_size = true,
          preserve_window_proportions = true,
          width = 35,
          side = "left",
          number = true,
          relativenumber = true,
        },
        sort_by = function(nodes)
          custom_cpp_bundled_sorter(nodes)
        end,
        on_attach = function(bufnr)
          local api = require("nvim-tree.api")

          -- Default mappings
          api.config.mappings.default_on_attach(bufnr)

          -- Custom mappings
          vim.keymap.set("n", "<A-v>", api.node.open.vertical, { buffer = bufnr, noremap = true, silent = true })
          vim.keymap.set("n", "<A-s>", api.node.open.horizontal, { buffer = bufnr, noremap = true, silent = true })

          -- Update status line with hovered file name
          local function update_statusline()
            local node = api.tree.get_node_under_cursor()
            if node and node.name then
              vim.cmd("echo '" .. node.name .. "'")
            else
              vim.cmd("echo ''")
            end
          end

          -- Hook into cursor movement
          -- vim.api.nvim_create_autocmd("CursorMoved", {
          --   buffer = bufnr,
          --   callback = update_statusline,
          -- })
        end,
      }

      vim.api.nvim_set_keymap("n", "<A-m>", ":NvimTreeToggle<CR>", { noremap = true, silent = true })
      -- Reveal (and open tree to) the current buffer's file
      vim.api.nvim_set_keymap("n", "<A-M>", ":NvimTreeFindFile<CR>", { noremap = true, silent = true })

      -- Use augroup to prevent duplicate autocmds on config reload
      vim.api.nvim_create_augroup('NvimTreeCustom', { clear = true })

      vim.api.nvim_create_autocmd("SessionLoadPost", {
        group = 'NvimTreeCustom',
        callback = function()
          vim.defer_fn(function()                               -- Defer to allow nvim-tree to initialize properly
            local first_buf = vim.fn.bufname(vim.fn.bufnr("%")) -- Get the name of the current (first) buffer
            if first_buf ~= "" then                             -- If there is a file open
              vim.cmd("NvimTreeFindFile")                       -- Run NvimTreeFindFile to highlight the file in nvim-tree
            end
          end, 500)                                             -- Adjust delay if necessary
        end,
      })
    end,
  },
}
